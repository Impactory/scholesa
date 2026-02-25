#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const { initializeApp, applicationDefault, cert, getApps } = require('firebase-admin/app');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');

const ROOT = path.resolve(__dirname, '..');
const BACKEND_TELEMETRY_FILE = path.join(ROOT, 'functions/src/index.ts');
const FLUTTER_TELEMETRY_FILE = path.join(ROOT, 'apps/empire_flutter/app/lib/services/telemetry_service.dart');
const SMOKE_FILE = path.join(ROOT, 'scripts/telemetry_smoke_check.js');
const DOCS_TELEMETRY_SPEC_FILE = path.join(ROOT, 'docs/18_ANALYTICS_TELEMETRY_SPEC.md');
const TELEMETRY_COLLECTION = 'telemetryEvents';
const INTERACTION_COLLECTION = 'interactionEvents';
const UNMAPPED_SITE_ID = 'unscoped';
const VOICE_EVENTS = new Set([
  'voice.transcribe',
  'voice.message',
  'voice.tts',
  'voice.blocked',
  'voice.escalated',
]);
const BOS_COMPATIBILITY_EVENTS = [
  'ai_help_opened',
  'ai_help_used',
  'ai_coach_response',
];
const VOICE_REQUIRED_METADATA_KEYS = [
  'traceId',
  'service',
  'env',
  'siteId',
  'role',
  'gradeBand',
  'locale',
  'eventType',
  'timestamp',
];
const BOS_COMPATIBILITY_EVENT_SET = new Set(BOS_COMPATIBILITY_EVENTS);
const VALID_VOICE_LOCALES = new Set(['en', 'zh-CN', 'zh-TW', 'th']);
const VALID_VOICE_ROLES = new Set(['student', 'teacher', 'admin']);
const VALID_VOICE_GRADE_BANDS = new Set(['k5', 'ms', 'hs']);
const VALID_VOICE_ENVS = new Set(['dev', 'staging', 'prod']);

const PII_KEY_BLOCKLIST = new Set([
  'name',
  'firstname',
  'lastname',
  'fullname',
  'displayname',
  'email',
  'phone',
  'phonenumber',
  'message',
  'messagebody',
  'body',
  'prompt',
  'response',
  'question',
  'query',
  'transcript',
  'audio',
  'audiobase64',
  'audiobytes',
  'rawtext',
  'rawprompt',
  'content',
  'text',
  'address',
]);

function usage() {
  return [
    'Telemetry live regression audit (core + non-core + observability/privacy invariants)',
    '',
    'Usage:',
    '  node scripts/telemetry_live_regression_audit.js [options]',
    '',
    'Options:',
    '  --hours=N                   Lookback window in hours. Default: 168',
    '  --limit=N                   Max telemetry documents to scan. Default: 20000',
    '  --site=SITE_ID              Optional site filter applied in-memory',
    '  --project=PROJECT_ID        Firebase project override',
    '  --credentials=PATH          Service account JSON path override',
    '  --strict                    Exit 1 on any failed validation',
    '  --help                      Show this help',
    '',
    'Environment:',
    '  GOOGLE_APPLICATION_CREDENTIALS=path/to/service-account.json',
    '  FIREBASE_PROJECT_ID=project-id',
  ].join('\n');
}

function parseArgs(argv) {
  const args = {
    hours: 168,
    limit: 20000,
    site: undefined,
    project: process.env.FIREBASE_PROJECT_ID,
    credentials: process.env.GOOGLE_APPLICATION_CREDENTIALS,
    strict: false,
    help: false,
  };

  for (const arg of argv) {
    if (arg === '--help' || arg === '-h') {
      args.help = true;
      continue;
    }
    if (arg === '--strict') {
      args.strict = true;
      continue;
    }
    if (!arg.startsWith('--')) continue;
    const [rawKey, rawValue] = arg.slice(2).split('=');
    if (rawValue === undefined) continue;
    if (rawKey === 'hours') {
      args.hours = Number(rawValue);
      continue;
    }
    if (rawKey === 'limit') {
      args.limit = Number(rawValue);
      continue;
    }
    if (rawKey === 'site') {
      args.site = rawValue.trim();
      continue;
    }
    if (rawKey === 'project') {
      args.project = rawValue.trim();
      continue;
    }
    if (rawKey === 'credentials') {
      args.credentials = rawValue.trim();
    }
  }
  return args;
}

function validateArgs(args) {
  if (!Number.isFinite(args.hours) || args.hours <= 0) {
    throw new Error(`Invalid --hours "${args.hours}". Use a positive number.`);
  }
  if (!Number.isFinite(args.limit) || args.limit <= 0) {
    throw new Error(`Invalid --limit "${args.limit}". Use a positive number.`);
  }
}

function ensureFile(filePath) {
  if (!fs.existsSync(filePath)) {
    throw new Error(`Required file not found: ${path.relative(ROOT, filePath)}`);
  }
}

function readUtf8(filePath) {
  ensureFile(filePath);
  return fs.readFileSync(filePath, 'utf8');
}

function parseSingleQuotedLiterals(source) {
  const values = [];
  const re = /'([^'\\]*(?:\\.[^'\\]*)*)'/g;
  let match;
  while ((match = re.exec(source)) !== null) {
    values.push(match[1]);
  }
  return values;
}

function parseEventsFromAssignment(source, assignmentRegex, label) {
  const match = source.match(assignmentRegex);
  if (!match) {
    throw new Error(`Unable to parse ${label}`);
  }
  return parseSingleQuotedLiterals(match[1]);
}

function toSortedArray(values) {
  return Array.from(new Set(values)).sort((a, b) => a.localeCompare(b));
}

function parseBackendAllowedEvents() {
  const source = readUtf8(BACKEND_TELEMETRY_FILE);
  return toSortedArray(
    parseEventsFromAssignment(
      source,
      /const ALLOWED_TELEMETRY_EVENTS:\s*Set<string>\s*=\s*new Set\(\[([\s\S]*?)\]\);/,
      'ALLOWED_TELEMETRY_EVENTS',
    ),
  );
}

function parseSmokeEvents() {
  const source = readUtf8(SMOKE_FILE);
  const coreExtended = toSortedArray(
    parseEventsFromAssignment(
      source,
      /const CORE_AND_EXTENDED_EVENTS\s*=\s*\[([\s\S]*?)\];/,
      'CORE_AND_EXTENDED_EVENTS',
    ),
  );
  const nonCore = toSortedArray(
    parseEventsFromAssignment(
      source,
      /const NON_CORE_EVENTS\s*=\s*\[([\s\S]*?)\];/,
      'NON_CORE_EVENTS',
    ),
  );
  return { coreExtended, nonCore };
}

function parseFlutterKnownEvents() {
  const source = readUtf8(FLUTTER_TELEMETRY_FILE);
  return toSortedArray(
    parseEventsFromAssignment(
      source,
      /static const Set<String> knownCoreEvents = \{([\s\S]*?)\};/,
      'TelemetryService.knownCoreEvents',
    ),
  );
}

function parseDocsRequiredEvents() {
  const source = readUtf8(DOCS_TELEMETRY_SPEC_FILE);
  const requiredSectionSplit = source.split('## Required events');
  if (requiredSectionSplit.length < 2) {
    throw new Error('Unable to parse docs required events section');
  }
  const requiredSection = requiredSectionSplit[1].split('## ')[0];
  const events = [];
  for (const rawLine of requiredSection.split('\n')) {
    const line = rawLine.trim();
    if (!line.startsWith('-')) continue;
    const chunk = line.slice(1).trim();
    for (const event of chunk.split(',')) {
      const normalized = event.trim();
      if (normalized) events.push(normalized);
    }
  }
  return toSortedArray(events);
}

function walkFiles(dirPath, exts, collector) {
  const entries = fs.readdirSync(dirPath, { withFileTypes: true });
  for (const entry of entries) {
    if (entry.name === 'node_modules' || entry.name === '.git' || entry.name === 'build') {
      continue;
    }
    const fullPath = path.join(dirPath, entry.name);
    if (entry.isDirectory()) {
      walkFiles(fullPath, exts, collector);
      continue;
    }
    if (exts.has(path.extname(entry.name))) {
      collector.push(fullPath);
    }
  }
}

function buildEmitterIndex() {
  const files = [];
  walkFiles(path.join(ROOT, 'functions/src'), new Set(['.ts']), files);
  walkFiles(path.join(ROOT, 'apps/empire_flutter/app/lib'), new Set(['.dart']), files);

  const emitterIndex = new Map();
  const patterns = [
    /event\s*:\s*['"]([^'"]+)['"]/g,
    /trackEvent\(\s*['"]([^'"]+)['"]/g,
  ];

  for (const filePath of files) {
    const source = fs.readFileSync(filePath, 'utf8');
    for (const pattern of patterns) {
      let match;
      while ((match = pattern.exec(source)) !== null) {
        const event = match[1];
        if (!emitterIndex.has(event)) {
          emitterIndex.set(event, new Set());
        }
        emitterIndex.get(event).add(path.relative(ROOT, filePath));
      }
    }
  }
  return emitterIndex;
}

function normalizeKey(key) {
  return key.replace(/[^a-zA-Z0-9]/g, '').toLowerCase();
}

function hasPiiKeys(value, keyPath = '') {
  if (Array.isArray(value)) {
    const findings = [];
    for (let i = 0; i < value.length; i += 1) {
      findings.push(...hasPiiKeys(value[i], `${keyPath}[${i}]`));
    }
    return findings;
  }

  if (value && typeof value === 'object') {
    const findings = [];
    for (const [key, nested] of Object.entries(value)) {
      const nextPath = keyPath ? `${keyPath}.${key}` : key;
      const normalized = normalizeKey(key);
      if (PII_KEY_BLOCKLIST.has(normalized)) {
        findings.push(nextPath);
      }
      findings.push(...hasPiiKeys(nested, nextPath));
    }
    return findings;
  }

  return [];
}

function sample(values, limit = 10) {
  return values.slice(0, limit);
}

function printSection(title, lines) {
  console.log('');
  console.log(title);
  if (!lines.length) {
    console.log('(none)');
    return;
  }
  for (const line of lines) {
    console.log(line);
  }
}

function isIsoTimestamp(value) {
  return typeof value === 'string' && !Number.isNaN(Date.parse(value));
}

function normalizeTelemetryRole(value) {
  if (typeof value !== 'string') return null;
  const normalized = value.trim().toLowerCase();
  if (normalized === 'student' || normalized === 'learner') return 'student';
  if (normalized === 'teacher' || normalized === 'educator') return 'teacher';
  if (
    normalized === 'admin' ||
    normalized === 'site' ||
    normalized === 'hq' ||
    normalized === 'partner'
  ) {
    return 'admin';
  }
  if (normalized === 'system') return 'system';
  return null;
}

function normalizeTelemetryGradeBand(value) {
  if (typeof value === 'number' && Number.isFinite(value)) {
    if (value <= 5) return 'k5';
    if (value <= 8) return 'ms';
    return 'hs';
  }
  if (typeof value !== 'string') return null;
  const normalized = value.trim().toLowerCase();
  if (
    normalized === 'k5' ||
    normalized === 'k-5' ||
    normalized === 'k_5' ||
    normalized === 'grades_1_3' ||
    normalized === 'grades_4_6'
  ) {
    return 'k5';
  }
  if (
    normalized === 'ms' ||
    normalized === '6-8' ||
    normalized === 'g6_8' ||
    normalized === 'grades_7_9'
  ) {
    return 'ms';
  }
  if (
    normalized === 'hs' ||
    normalized === '9-12' ||
    normalized === 'g9_12' ||
    normalized === 'grades_10_12'
  ) {
    return 'hs';
  }
  return null;
}

function normalizeTelemetryLocale(value) {
  if (typeof value !== 'string') return null;
  const normalized = value.trim();
  if (VALID_VOICE_LOCALES.has(normalized)) return normalized;
  const lowered = normalized.toLowerCase();
  if (lowered.startsWith('zh-tw') || lowered.startsWith('zh-hk') || lowered.startsWith('zh-hant')) {
    return 'zh-TW';
  }
  if (lowered.startsWith('zh')) return 'zh-CN';
  if (lowered.startsWith('th')) return 'th';
  if (lowered.startsWith('en')) return 'en';
  return null;
}

function overlap(leftSet, rightSet) {
  const out = [];
  for (const value of leftSet) {
    if (rightSet.has(value)) out.push(value);
  }
  return out;
}

function initializeAdmin(args) {
  const appOptions = {};
  if (args.project) {
    appOptions.projectId = args.project;
  }
  if (args.credentials) {
    const credentialPath = path.resolve(ROOT, args.credentials);
    if (!fs.existsSync(credentialPath)) {
      throw new Error(`Credentials file not found: ${credentialPath}`);
    }
    appOptions.credential = cert(require(credentialPath));
  } else {
    appOptions.credential = applicationDefault();
  }
  if (!getApps().length) {
    initializeApp(appOptions);
  }
  return getFirestore();
}

async function runLiveAudit(args, registries) {
  const db = initializeAdmin(args);
  const since = new Date(Date.now() - args.hours * 60 * 60 * 1000);

  const snapshot = await db
    .collection(TELEMETRY_COLLECTION)
    .where('createdAt', '>=', Timestamp.fromDate(since))
    .orderBy('createdAt', 'desc')
    .limit(args.limit)
    .get();

  const docs = snapshot.docs
    .map((doc) => ({ id: doc.id, ...doc.data() }))
    .filter((row) => !args.site || row.siteId === args.site);

  const interactionQueryErrors = [];
  let interactionSnapshot = { docs: [] };
  try {
    interactionSnapshot = await db
      .collection(INTERACTION_COLLECTION)
      .where('timestamp', '>=', Timestamp.fromDate(since))
      .orderBy('timestamp', 'desc')
      .limit(args.limit)
      .get();
  } catch (error) {
    interactionQueryErrors.push(
      `interaction_query_failed:${error instanceof Error ? error.message : String(error)}`,
    );
  }

  const interactionDocs = interactionSnapshot.docs
    .map((doc) => ({ id: doc.id, ...doc.data() }))
    .filter((row) => !args.site || row.siteId === args.site);

  const eventCounts = new Map();
  const roleCounts = new Map();
  const schemaErrors = [];
  const correlationErrors = [];
  const tenantTagErrors = [];
  const piiKeyErrors = [];
  const unknownEventCounts = new Map();
  const voiceMetadataErrors = [];
  const voiceTraceEvents = new Map();
  const nonCoreMetadataErrors = [];
  const bosCompatibilityErrors = [];
  const bosInteractionSchemaErrors = [];
  const bosVoiceTraceContinuityErrors = [];
  const bosEventCounts = new Map();
  const voiceTraceByEvent = {
    transcribe: new Set(),
    message: new Set(),
    tts: new Set(),
  };
  const bosVoiceTraceByEvent = {
    ai_help_opened: new Set(),
    ai_help_used: new Set(),
    ai_coach_response: new Set(),
  };

  const allowedEventSet = new Set(registries.backendAllowedEvents);
  const nonCoreEventSet = new Set(registries.nonCoreRequiredEvents);

  for (const row of docs) {
    const event = typeof row.event === 'string' ? row.event : '';
    const role = typeof row.role === 'string' ? row.role : '';
    const siteId = typeof row.siteId === 'string' ? row.siteId : '';
    const metadata =
      row.metadata && typeof row.metadata === 'object' && !Array.isArray(row.metadata)
        ? row.metadata
        : {};

    if (!event || !role || !row.userId || !siteId || !row.createdAt) {
      schemaErrors.push({
        id: row.id,
        event,
        role,
        siteId,
      });
    }

    if (!metadata.requestId || !metadata.traceId) {
      correlationErrors.push({
        id: row.id,
        event,
        role,
      });
    }

    if (role !== 'hq' && role !== 'system' && siteId === UNMAPPED_SITE_ID) {
      tenantTagErrors.push({
        id: row.id,
        event,
        role,
        siteId,
      });
    }

    const piiPaths = hasPiiKeys(metadata);
    if (piiPaths.length > 0) {
      piiKeyErrors.push({
        id: row.id,
        event,
        piiPaths: sample(piiPaths, 5),
      });
    }

    if (VOICE_EVENTS.has(event)) {
      const missingKeys = VOICE_REQUIRED_METADATA_KEYS.filter((key) => metadata[key] === undefined || metadata[key] === null);
      const invalids = [];
      if (typeof metadata.eventType !== 'string' || metadata.eventType !== event) {
        invalids.push(`eventType_mismatch:${String(metadata.eventType || 'missing')}`);
      }
      if (typeof metadata.service !== 'string' || metadata.service.trim().length === 0) {
        invalids.push('service_missing_or_invalid');
      }
      if (typeof metadata.env !== 'string' || !VALID_VOICE_ENVS.has(metadata.env)) {
        invalids.push(`env_invalid:${String(metadata.env || 'missing')}`);
      }
      if (typeof metadata.role !== 'string' || !VALID_VOICE_ROLES.has(metadata.role)) {
        invalids.push(`role_invalid:${String(metadata.role || 'missing')}`);
      }
      if (typeof metadata.gradeBand !== 'string' || !VALID_VOICE_GRADE_BANDS.has(metadata.gradeBand)) {
        invalids.push(`gradeBand_invalid:${String(metadata.gradeBand || 'missing')}`);
      }
      if (typeof metadata.locale !== 'string' || !VALID_VOICE_LOCALES.has(metadata.locale)) {
        invalids.push(`locale_invalid:${String(metadata.locale || 'missing')}`);
      }
      if (!isIsoTimestamp(metadata.timestamp)) {
        invalids.push(`timestamp_invalid:${String(metadata.timestamp || 'missing')}`);
      }
      if (typeof metadata.siteId !== 'string' || metadata.siteId !== siteId) {
        invalids.push(`siteId_mismatch:${String(metadata.siteId || 'missing')}:${siteId}`);
      }
      if (typeof metadata.role === 'string' && metadata.role !== role) {
        invalids.push(`role_mismatch:${metadata.role}:${role}`);
      }

      if (missingKeys.length > 0 || invalids.length > 0) {
        voiceMetadataErrors.push({
          id: row.id,
          event,
          missingKeys,
          invalids,
        });
      }

      if (typeof metadata.traceId === 'string' && metadata.traceId.trim().length > 0) {
        const traceId = metadata.traceId.trim();
        if (!voiceTraceEvents.has(traceId)) {
          voiceTraceEvents.set(traceId, new Set());
        }
        voiceTraceEvents.get(traceId).add(event);
        if (event === 'voice.transcribe') voiceTraceByEvent.transcribe.add(traceId);
        if (event === 'voice.message') voiceTraceByEvent.message.add(traceId);
        if (event === 'voice.tts') voiceTraceByEvent.tts.add(traceId);
      }
    }

    if (nonCoreEventSet.has(event)) {
      const invalids = [];
      const metadataTraceId = typeof metadata.traceId === 'string' ? metadata.traceId.trim() : '';
      const metadataRequestId = typeof metadata.requestId === 'string' ? metadata.requestId.trim() : '';
      const metadataSiteId = typeof metadata.siteId === 'string' ? metadata.siteId.trim() : '';
      const metadataRole = normalizeTelemetryRole(metadata.role);
      const metadataGradeBand = normalizeTelemetryGradeBand(metadata.gradeBand);
      const metadataLocale = normalizeTelemetryLocale(metadata.locale);
      const metadataEnv = typeof metadata.env === 'string' ? metadata.env.trim() : '';
      const metadataEventType = typeof metadata.eventType === 'string' ? metadata.eventType.trim() : '';
      const metadataTimestamp = metadata.timestamp || metadata.timestampIso;
      const rowRoleCanonical = normalizeTelemetryRole(role);

      if (!metadataRequestId) invalids.push('requestId_missing');
      if (!metadataTraceId) invalids.push('traceId_missing');
      if (!metadataSiteId && !siteId) invalids.push('siteId_missing');
      if (metadataSiteId && siteId && metadataSiteId !== siteId) {
        invalids.push(`siteId_mismatch:${metadataSiteId}:${siteId}`);
      }
      if (!metadataRole && !rowRoleCanonical) invalids.push('role_missing');
      if (metadataRole && rowRoleCanonical && metadataRole !== rowRoleCanonical) {
        invalids.push(`role_mismatch:${metadataRole}:${rowRoleCanonical}`);
      }
      if (!metadataGradeBand) invalids.push(`gradeBand_invalid:${String(metadata.gradeBand || 'missing')}`);
      if (!metadataLocale) invalids.push(`locale_invalid:${String(metadata.locale || 'missing')}`);
      if (!metadataEnv || !VALID_VOICE_ENVS.has(metadataEnv)) {
        invalids.push(`env_invalid:${String(metadata.env || 'missing')}`);
      }
      if (!metadataEventType || metadataEventType !== event) {
        invalids.push(`eventType_mismatch:${String(metadata.eventType || 'missing')}`);
      }
      if (!isIsoTimestamp(metadataTimestamp)) {
        invalids.push(`timestamp_invalid:${String(metadataTimestamp || 'missing')}`);
      }
      if (typeof metadata.service !== 'string' || metadata.service.trim().length === 0) {
        invalids.push('service_missing_or_invalid');
      }

      if (invalids.length > 0) {
        nonCoreMetadataErrors.push({
          id: row.id,
          event,
          invalids,
        });
      }
    }

    if (!allowedEventSet.has(event)) {
      unknownEventCounts.set(event, (unknownEventCounts.get(event) ?? 0) + 1);
    }

    if (event) {
      eventCounts.set(event, (eventCounts.get(event) ?? 0) + 1);
    }
    if (role) {
      roleCounts.set(role, (roleCounts.get(role) ?? 0) + 1);
    }
  }

  for (const row of interactionDocs) {
    const eventType = typeof row.eventType === 'string' ? row.eventType.trim() : '';
    if (eventType) {
      bosEventCounts.set(eventType, (bosEventCounts.get(eventType) ?? 0) + 1);
    }
    if (!BOS_COMPATIBILITY_EVENT_SET.has(eventType)) {
      continue;
    }

    const payload = row.payload && typeof row.payload === 'object' && !Array.isArray(row.payload)
      ? row.payload
      : {};
    const traceIdFromPayload = typeof payload.traceId === 'string' ? payload.traceId.trim() : '';
    const traceIdFromEvent = typeof row.traceId === 'string' ? row.traceId.trim() : '';
    const traceId = traceIdFromPayload || traceIdFromEvent;
    const payloadLocale = normalizeTelemetryLocale(payload.locale || row.locale);

    if (typeof row.siteId !== 'string' || row.siteId.trim().length === 0) {
      bosInteractionSchemaErrors.push({ id: row.id, reason: 'siteId_missing', eventType });
    }
    if (typeof row.actorId !== 'string' || row.actorId.trim().length === 0) {
      bosInteractionSchemaErrors.push({ id: row.id, reason: 'actorId_missing', eventType });
    }
    if (typeof row.actorRole !== 'string' || row.actorRole.trim().length === 0) {
      bosInteractionSchemaErrors.push({ id: row.id, reason: 'actorRole_missing', eventType });
    }
    if (!normalizeTelemetryGradeBand(row.gradeBand)) {
      bosInteractionSchemaErrors.push({
        id: row.id,
        reason: `gradeBand_invalid:${String(row.gradeBand || 'missing')}`,
        eventType,
      });
    }
    if (!row.timestamp) {
      bosInteractionSchemaErrors.push({ id: row.id, reason: 'timestamp_missing', eventType });
    }

    const source = typeof payload.source === 'string' ? payload.source.trim() : '';
    if (source === 'voice') {
      if (!traceId) {
        bosInteractionSchemaErrors.push({ id: row.id, reason: 'voice_trace_missing', eventType });
      }
      if (!payloadLocale) {
        bosInteractionSchemaErrors.push({ id: row.id, reason: 'voice_locale_missing_or_invalid', eventType });
      }
      if (traceId && Object.prototype.hasOwnProperty.call(bosVoiceTraceByEvent, eventType)) {
        bosVoiceTraceByEvent[eventType].add(traceId);
      }
    }
  }

  const missingRequiredLiveCoverage = registries.canonicalRequiredEvents.filter(
    (event) => !eventCounts.has(event),
  );

  const tracesWithSttAndMessage = Array.from(voiceTraceEvents.values()).filter(
    (events) => events.has('voice.transcribe') && events.has('voice.message'),
  ).length;
  const voiceTraceContinuityErrors = [];
  if (eventCounts.has('voice.transcribe') && eventCounts.has('voice.message') && tracesWithSttAndMessage === 0) {
    voiceTraceContinuityErrors.push({
      reason: 'no_shared_trace_between_stt_and_message',
      tracesObserved: voiceTraceEvents.size,
    });
  }

  const voiceMessageCount = eventCounts.get('voice.message') ?? 0;
  const voiceTranscribeCount = eventCounts.get('voice.transcribe') ?? 0;
  const voiceTtsCount = eventCounts.get('voice.tts') ?? 0;
  const aiHelpOpenedCount = eventCounts.get('ai_help_opened') ?? 0;
  const aiHelpUsedCount = eventCounts.get('ai_help_used') ?? 0;
  const aiCoachResponseCount = eventCounts.get('ai_coach_response') ?? 0;

  if (voiceTranscribeCount > 0 && aiHelpOpenedCount === 0) {
    bosCompatibilityErrors.push({
      reason: 'voice_transcribe_without_ai_help_opened',
      voiceTranscribeCount,
      aiHelpOpenedCount,
    });
  }
  if (voiceMessageCount > 0 && aiHelpUsedCount === 0) {
    bosCompatibilityErrors.push({
      reason: 'voice_message_without_ai_help_used',
      voiceMessageCount,
      aiHelpUsedCount,
    });
  }
  if (voiceTtsCount > 0 && aiCoachResponseCount === 0) {
    bosCompatibilityErrors.push({
      reason: 'voice_tts_without_ai_coach_response',
      voiceTtsCount,
      aiCoachResponseCount,
    });
  }

  const sttToMessageTraceOverlap = overlap(voiceTraceByEvent.transcribe, voiceTraceByEvent.message);
  const sttToBosTraceOverlap = overlap(voiceTraceByEvent.transcribe, bosVoiceTraceByEvent.ai_help_opened);
  const messageToBosTraceOverlap = overlap(voiceTraceByEvent.message, bosVoiceTraceByEvent.ai_help_used);
  const ttsToBosTraceOverlap = overlap(voiceTraceByEvent.tts, bosVoiceTraceByEvent.ai_coach_response);

  if (
    voiceTraceByEvent.transcribe.size > 0 &&
    bosVoiceTraceByEvent.ai_help_opened.size > 0 &&
    sttToBosTraceOverlap.length === 0
  ) {
    bosVoiceTraceContinuityErrors.push({
      reason: 'voice_transcribe_to_bos_opened_trace_gap',
      voiceTraceCount: voiceTraceByEvent.transcribe.size,
      bosTraceCount: bosVoiceTraceByEvent.ai_help_opened.size,
    });
  }

  if (
    voiceTraceByEvent.message.size > 0 &&
    bosVoiceTraceByEvent.ai_help_used.size > 0 &&
    messageToBosTraceOverlap.length === 0
  ) {
    bosVoiceTraceContinuityErrors.push({
      reason: 'voice_message_to_bos_used_trace_gap',
      voiceTraceCount: voiceTraceByEvent.message.size,
      bosTraceCount: bosVoiceTraceByEvent.ai_help_used.size,
    });
  }

  if (
    voiceTraceByEvent.tts.size > 0 &&
    bosVoiceTraceByEvent.ai_coach_response.size > 0 &&
    ttsToBosTraceOverlap.length === 0
  ) {
    bosVoiceTraceContinuityErrors.push({
      reason: 'voice_tts_to_bos_response_trace_gap',
      voiceTraceCount: voiceTraceByEvent.tts.size,
      bosTraceCount: bosVoiceTraceByEvent.ai_coach_response.size,
    });
  }

  return {
    docsScanned: snapshot.docs.length,
    docsAfterSiteFilter: docs.length,
    interactionDocsScanned: interactionSnapshot.docs.length,
    interactionDocsAfterSiteFilter: interactionDocs.length,
    distinctEventsSeen: eventCounts.size,
    eventCounts,
    bosEventCounts,
    roleCounts,
    missingRequiredLiveCoverage,
    schemaErrors,
    correlationErrors,
    tenantTagErrors,
    piiKeyErrors,
    voiceMetadataErrors,
    nonCoreMetadataErrors,
    voiceTraceContinuityErrors,
    bosCompatibilityErrors,
    bosInteractionSchemaErrors,
    bosVoiceTraceContinuityErrors,
    traceOverlap: {
      sttToMessage: sttToMessageTraceOverlap.length,
      sttToBosOpened: sttToBosTraceOverlap.length,
      messageToBosUsed: messageToBosTraceOverlap.length,
      ttsToBosResponse: ttsToBosTraceOverlap.length,
    },
    interactionQueryErrors,
    unknownEventCounts,
  };
}

function printMapSection(title, map) {
  printSection(
    title,
    Array.from(map.entries())
      .sort((a, b) => a[0].localeCompare(b[0]))
      .map(([key, value]) => `${key}=${value}`),
  );
}

async function run() {
  const args = parseArgs(process.argv.slice(2));
  if (args.help) {
    console.log(usage());
    return;
  }
  validateArgs(args);

  const backendAllowedEvents = parseBackendAllowedEvents();
  const flutterKnownEvents = parseFlutterKnownEvents();
  const smokeEvents = parseSmokeEvents();
  const docsRequiredEvents = parseDocsRequiredEvents();
  const emitterIndex = buildEmitterIndex();

  const canonicalRequiredEvents = toSortedArray([
    ...docsRequiredEvents,
    ...smokeEvents.coreExtended,
    ...smokeEvents.nonCore,
  ]);

  const backendSet = new Set(backendAllowedEvents);
  const flutterSet = new Set(flutterKnownEvents);

  const docsMissingInBackend = docsRequiredEvents.filter((event) => !backendSet.has(event));
  const smokeMissingInBackend = canonicalRequiredEvents.filter((event) => !backendSet.has(event));
  const smokeMissingInFlutter = canonicalRequiredEvents.filter((event) => !flutterSet.has(event));
  const missingEmitters = canonicalRequiredEvents.filter((event) => !emitterIndex.has(event));

  const registries = {
    backendAllowedEvents,
    flutterKnownEvents,
    canonicalRequiredEvents,
    nonCoreRequiredEvents: smokeEvents.nonCore,
  };
  const live = await runLiveAudit(args, registries);

  printSection('Telemetry Live Regression Input', [
    `hours=${args.hours}`,
    `limit=${args.limit}`,
    `siteFilter=${args.site || '(none)'}`,
    `project=${args.project || '(from credentials/default)'}`,
    `credentials=${args.credentials || '(applicationDefault)'}`,
    `strict=${args.strict}`,
  ]);

  printSection('Registry Sizes', [
    `docsRequiredEvents=${docsRequiredEvents.length}`,
    `smokeCoreExtendedEvents=${smokeEvents.coreExtended.length}`,
    `smokeNonCoreEvents=${smokeEvents.nonCore.length}`,
    `canonicalRequiredEvents=${canonicalRequiredEvents.length}`,
    `backendAllowedEvents=${backendAllowedEvents.length}`,
    `flutterKnownEvents=${flutterKnownEvents.length}`,
  ]);

  printSection(
    'Canonical Required Event Coverage (live)',
    canonicalRequiredEvents.map((event) => `${event}=${live.eventCounts.get(event) ?? 0}`),
  );

  printSection('Live Dataset', [
    `docsScanned=${live.docsScanned}`,
    `docsAfterSiteFilter=${live.docsAfterSiteFilter}`,
    `interactionDocsScanned=${live.interactionDocsScanned}`,
    `interactionDocsAfterSiteFilter=${live.interactionDocsAfterSiteFilter}`,
    `distinctEventsSeen=${live.distinctEventsSeen}`,
  ]);

  printMapSection('Live Role Counts', live.roleCounts);
  printMapSection('Live Unknown Event Counts', live.unknownEventCounts);
  printMapSection('Live BOS Event Counts', live.bosEventCounts);
  printSection(
    'BOS Compatibility Event Coverage (live)',
    BOS_COMPATIBILITY_EVENTS.map((event) => `${event}=${live.eventCounts.get(event) ?? 0}`),
  );
  printSection('Voice/BOS Trace Overlap', [
    `stt_to_message=${live.traceOverlap.sttToMessage}`,
    `stt_to_bos_opened=${live.traceOverlap.sttToBosOpened}`,
    `message_to_bos_used=${live.traceOverlap.messageToBosUsed}`,
    `tts_to_bos_response=${live.traceOverlap.ttsToBosResponse}`,
  ]);

  const failures = [];

  if (docsMissingInBackend.length > 0) {
    failures.push(`docsMissingInBackend=${docsMissingInBackend.length}`);
    printSection(
      'Docs Required Events Missing In Backend Allowlist',
      docsMissingInBackend.map((event) => `- ${event}`),
    );
  }

  if (smokeMissingInBackend.length > 0) {
    failures.push(`canonicalMissingInBackend=${smokeMissingInBackend.length}`);
    printSection(
      'Canonical Required Events Missing In Backend Allowlist',
      smokeMissingInBackend.map((event) => `- ${event}`),
    );
  }

  if (smokeMissingInFlutter.length > 0) {
    failures.push(`canonicalMissingInFlutterRegistry=${smokeMissingInFlutter.length}`);
    printSection(
      'Canonical Required Events Missing In Flutter Telemetry Registry',
      smokeMissingInFlutter.map((event) => `- ${event}`),
    );
  }

  if (missingEmitters.length > 0) {
    failures.push(`canonicalMissingEmitters=${missingEmitters.length}`);
    printSection(
      'Canonical Required Events Missing Emitter Paths',
      missingEmitters.map((event) => `- ${event}`),
    );
  }

  if (live.docsAfterSiteFilter === 0) {
    failures.push('liveDatasetEmpty=1');
  }

  if (live.schemaErrors.length > 0) {
    failures.push(`liveSchemaErrors=${live.schemaErrors.length}`);
    printSection(
      'Live Schema Errors (sample)',
      sample(live.schemaErrors, 10).map((row) => JSON.stringify(row)),
    );
  }

  if (live.correlationErrors.length > 0) {
    failures.push(`liveCorrelationErrors=${live.correlationErrors.length}`);
    printSection(
      'Live Correlation Errors (sample)',
      sample(live.correlationErrors, 10).map((row) => JSON.stringify(row)),
    );
  }

  if (live.tenantTagErrors.length > 0) {
    failures.push(`liveTenantTagErrors=${live.tenantTagErrors.length}`);
    printSection(
      'Live Tenant Tag Errors (sample)',
      sample(live.tenantTagErrors, 10).map((row) => JSON.stringify(row)),
    );
  }

  if (live.piiKeyErrors.length > 0) {
    failures.push(`livePiiKeyErrors=${live.piiKeyErrors.length}`);
    printSection(
      'Live PII Key Errors (sample)',
      sample(live.piiKeyErrors, 10).map((row) => JSON.stringify(row)),
    );
  }

  if (live.voiceMetadataErrors.length > 0) {
    failures.push(`liveVoiceMetadataErrors=${live.voiceMetadataErrors.length}`);
    printSection(
      'Live Voice Metadata Schema Errors (sample)',
      sample(live.voiceMetadataErrors, 10).map((row) => JSON.stringify(row)),
    );
  }

  if (live.nonCoreMetadataErrors.length > 0) {
    failures.push(`liveNonCoreMetadataErrors=${live.nonCoreMetadataErrors.length}`);
    printSection(
      'Live Non-Core Metadata Schema Errors (sample)',
      sample(live.nonCoreMetadataErrors, 10).map((row) => JSON.stringify(row)),
    );
  }

  if (live.voiceTraceContinuityErrors.length > 0) {
    failures.push(`liveVoiceTraceContinuityErrors=${live.voiceTraceContinuityErrors.length}`);
    printSection(
      'Live Voice Trace Continuity Errors',
      live.voiceTraceContinuityErrors.map((row) => JSON.stringify(row)),
    );
  }

  if (live.bosCompatibilityErrors.length > 0) {
    failures.push(`liveBosCompatibilityErrors=${live.bosCompatibilityErrors.length}`);
    printSection(
      'Live BOS Compatibility Errors',
      live.bosCompatibilityErrors.map((row) => JSON.stringify(row)),
    );
  }

  if (live.bosInteractionSchemaErrors.length > 0) {
    failures.push(`liveBosInteractionSchemaErrors=${live.bosInteractionSchemaErrors.length}`);
    printSection(
      'Live BOS Interaction Schema Errors (sample)',
      sample(live.bosInteractionSchemaErrors, 10).map((row) => JSON.stringify(row)),
    );
  }

  if (live.bosVoiceTraceContinuityErrors.length > 0) {
    failures.push(`liveBosVoiceTraceContinuityErrors=${live.bosVoiceTraceContinuityErrors.length}`);
    printSection(
      'Live BOS Voice Trace Continuity Errors',
      live.bosVoiceTraceContinuityErrors.map((row) => JSON.stringify(row)),
    );
  }

  if (live.interactionQueryErrors.length > 0) {
    failures.push(`interactionQueryErrors=${live.interactionQueryErrors.length}`);
    printSection('Interaction Query Errors', live.interactionQueryErrors);
  }

  if (live.unknownEventCounts.size > 0) {
    failures.push(`liveUnknownEvents=${live.unknownEventCounts.size}`);
  }

  if (live.missingRequiredLiveCoverage.length > 0) {
    failures.push(`liveMissingCanonicalCoverage=${live.missingRequiredLiveCoverage.length}`);
    printSection(
      'Canonical Required Events Missing In Live Window',
      live.missingRequiredLiveCoverage.map((event) => `- ${event}`),
    );
  }

  if (failures.length === 0) {
    console.log('');
    console.log('Result: PASS');
    return;
  }

  console.log('');
  console.log(`Result: FAIL (${failures.join(', ')})`);
  if (args.strict) {
    process.exitCode = 1;
  }
}

run().catch((error) => {
  console.error('Telemetry live regression audit failed:', error.message || error);
  process.exitCode = 1;
});
