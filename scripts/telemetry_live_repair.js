#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const { initializeApp, applicationDefault, cert, getApps } = require('firebase-admin/app');
const { getFirestore, Timestamp, FieldValue } = require('firebase-admin/firestore');

const ROOT = path.resolve(__dirname, '..');
const TELEMETRY_COLLECTION = 'telemetryEvents';
const UNMAPPED_SITE_ID = 'unscoped';
const VALID_ENVS = new Set(['dev', 'staging', 'prod']);
const VALID_LOCALES = new Set(['en', 'zh-CN', 'zh-TW', 'th']);
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
    'Telemetry live repair (schema/correlation backfill for malformed telemetry rows)',
    '',
    'Usage:',
    '  node scripts/telemetry_live_repair.js [options]',
    '',
    'Options:',
    '  --hours=N                   Lookback window in hours. Default: 336',
    '  --limit=N                   Max telemetry documents to scan. Default: 5000',
    '  --site=SITE_ID              Optional site filter applied in-memory',
    '  --project=PROJECT_ID        Firebase project override',
    '  --credentials=PATH          Service account JSON path override',
    '  --apply                     Apply updates (default is dry run)',
    '  --strict                    Exit 1 if malformed docs are found (dry run) or if updates fail',
    '  --help                      Show this help',
    '',
    'Environment:',
    '  GOOGLE_APPLICATION_CREDENTIALS=path/to/service-account.json',
    '  FIREBASE_PROJECT_ID=project-id',
  ].join('\n');
}

function parseArgs(argv) {
  const args = {
    hours: 336,
    limit: 5000,
    site: undefined,
    project: process.env.FIREBASE_PROJECT_ID,
    credentials: process.env.GOOGLE_APPLICATION_CREDENTIALS,
    apply: false,
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
    if (arg === '--apply') {
      args.apply = true;
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

function asObject(value) {
  return value && typeof value === 'object' && !Array.isArray(value) ? value : {};
}

function toSafeString(value) {
  return typeof value === 'string' ? value.trim() : '';
}

function normalizeKey(key) {
  return String(key || '')
    .replace(/[^a-zA-Z0-9]/g, '')
    .toLowerCase();
}

function normalizeTelemetryRole(value) {
  const normalized = toSafeString(value).toLowerCase();
  if (!normalized) return null;
  if (normalized === 'system') return 'system';
  if (normalized === 'student' || normalized === 'learner') return 'student';
  if (normalized === 'teacher' || normalized === 'educator') return 'teacher';
  if (
    normalized === 'admin' ||
    normalized === 'hq' ||
    normalized === 'site' ||
    normalized === 'sitelead' ||
    normalized === 'site_lead' ||
    normalized === 'partner' ||
    normalized === 'parent' ||
    normalized === 'guardian'
  ) {
    return 'admin';
  }
  return null;
}

function normalizeTelemetryGradeBand(value, role) {
  if (typeof value === 'number' && Number.isFinite(value)) {
    if (value <= 5) return 'k5';
    if (value <= 8) return 'ms';
    if (value <= 12) return 'hs';
  }

  const normalized = toSafeString(value)
    .toLowerCase()
    .replace(/[\s_-]/g, '');

  if (
    normalized === 'k5' ||
    normalized === 'k-5' ||
    normalized === 'gk5' ||
    normalized === 'grades16' ||
    normalized === 'grades1to6'
  ) {
    return 'k5';
  }
  if (
    normalized === 'ms' ||
    normalized === '68' ||
    normalized === 'g68' ||
    normalized === 'grades79' ||
    normalized === 'grades7to9'
  ) {
    return 'ms';
  }
  if (
    normalized === 'hs' ||
    normalized === '912' ||
    normalized === 'g912' ||
    normalized === 'grades1012' ||
    normalized === 'grades10to12'
  ) {
    return 'hs';
  }
  return role === 'student' ? 'ms' : 'hs';
}

function normalizeTelemetryLocale(value) {
  const raw = toSafeString(value);
  if (!raw) return 'en';
  if (VALID_LOCALES.has(raw)) return raw;
  const lowered = raw.toLowerCase();
  if (lowered.startsWith('zh-tw') || lowered.startsWith('zh-hk') || lowered.startsWith('zh-hant')) return 'zh-TW';
  if (lowered.startsWith('zh')) return 'zh-CN';
  if (lowered.startsWith('th')) return 'th';
  return 'en';
}

function toIsoTimestamp(value) {
  if (value instanceof Date) {
    return value.toISOString();
  }
  if (typeof value === 'string' && value.trim().length > 0 && !Number.isNaN(Date.parse(value))) {
    return new Date(value).toISOString();
  }
  if (value && typeof value === 'object' && typeof value.toDate === 'function') {
    try {
      const date = value.toDate();
      if (date instanceof Date && !Number.isNaN(date.getTime())) {
        return date.toISOString();
      }
    } catch {
      return '';
    }
  }
  return '';
}

function resolveIsoTimestamp(...candidates) {
  for (const candidate of candidates) {
    const iso = toIsoTimestamp(candidate);
    if (iso) return iso;
  }
  return new Date().toISOString();
}

function sanitizeMetadata(value, pathPrefix = '', redactedPaths = []) {
  if (Array.isArray(value)) {
    return value.map((item, index) =>
      sanitizeMetadata(item, `${pathPrefix}[${index}]`, redactedPaths),
    );
  }
  if (!value || typeof value !== 'object') {
    return value;
  }
  if (value instanceof Date) {
    return value.toISOString();
  }
  if (typeof value.toDate === 'function') {
    const maybeIso = toIsoTimestamp(value);
    return maybeIso || null;
  }

  const sanitized = {};
  for (const [key, nested] of Object.entries(value)) {
    const keyPath = pathPrefix ? `${pathPrefix}.${key}` : key;
    if (PII_KEY_BLOCKLIST.has(normalizeKey(key))) {
      redactedPaths.push(keyPath);
      continue;
    }
    sanitized[key] = sanitizeMetadata(nested, keyPath, redactedPaths);
  }
  return sanitized;
}

function setMetadataValue(target, key, value) {
  if (target[key] !== value) {
    target[key] = value;
    return true;
  }
  return false;
}

function computePatch(row) {
  const patch = {};
  const metadata = asObject(row.metadata);
  const redactedPaths = [];
  const sanitizedMetadata = sanitizeMetadata(metadata, '', redactedPaths);
  const nextMetadata = { ...asObject(sanitizedMetadata) };
  let metadataChanged = JSON.stringify(nextMetadata) !== JSON.stringify(metadata) || redactedPaths.length > 0;

  const role = toSafeString(row.role);
  if (!role) {
    patch.role = 'system';
  }

  const userId = toSafeString(row.userId);
  if (!userId) {
    patch.userId = 'system';
  }

  const siteId = toSafeString(row.siteId);
  if (!siteId) {
    patch.siteId = UNMAPPED_SITE_ID;
  }

  const canonicalRole =
    normalizeTelemetryRole(nextMetadata.role) ||
    normalizeTelemetryRole(role) ||
    ((toSafeString(row.userId) === 'system' || toSafeString(row.userId) === 'anonymous') ? 'system' : 'admin');
  const effectiveSiteId = siteId || UNMAPPED_SITE_ID;
  const requestId = toSafeString(nextMetadata.requestId) || toSafeString(row.requestId) || `repair-${row.id}`;
  const traceId = toSafeString(nextMetadata.traceId) || toSafeString(row.traceId) || requestId;
  const eventType = toSafeString(nextMetadata.eventType) || toSafeString(row.eventType) || toSafeString(row.event);
  const locale = normalizeTelemetryLocale(nextMetadata.locale || nextMetadata.targetLocale || row.locale);
  const gradeBand = normalizeTelemetryGradeBand(
    nextMetadata.gradeBand ?? nextMetadata.grade ?? row.gradeBand,
    canonicalRole,
  );
  const envCandidate = toSafeString(nextMetadata.env) || toSafeString(row.env);
  const env = VALID_ENVS.has(envCandidate) ? envCandidate : 'prod';
  let service = toSafeString(nextMetadata.service) || toSafeString(row.service);
  if (!service) {
    const endpoint = toSafeString(nextMetadata.endpoint) || toSafeString(row.endpoint);
    if (endpoint === 'voice_transcribe') {
      service = 'scholesa-stt';
    } else if (endpoint === 'tts_speak') {
      service = 'scholesa-tts';
    } else {
      service = 'scholesa-api';
    }
  }
  const metadataSiteId = toSafeString(nextMetadata.siteId) || effectiveSiteId;
  const timestampIso = resolveIsoTimestamp(
    nextMetadata.timestamp,
    nextMetadata.timestampIso,
    row.timestampIso,
    row.createdAt,
    row.timestamp,
  );

  metadataChanged = setMetadataValue(nextMetadata, 'requestId', requestId) || metadataChanged;
  metadataChanged = setMetadataValue(nextMetadata, 'traceId', traceId) || metadataChanged;
  metadataChanged = setMetadataValue(nextMetadata, 'siteId', metadataSiteId) || metadataChanged;
  metadataChanged = setMetadataValue(nextMetadata, 'role', canonicalRole) || metadataChanged;
  metadataChanged = setMetadataValue(nextMetadata, 'gradeBand', gradeBand) || metadataChanged;
  metadataChanged = setMetadataValue(nextMetadata, 'locale', locale) || metadataChanged;
  metadataChanged = setMetadataValue(nextMetadata, 'env', env) || metadataChanged;
  metadataChanged = setMetadataValue(nextMetadata, 'service', service) || metadataChanged;
  metadataChanged = setMetadataValue(nextMetadata, 'eventType', eventType) || metadataChanged;
  metadataChanged = setMetadataValue(nextMetadata, 'timestamp', timestampIso) || metadataChanged;
  metadataChanged = setMetadataValue(nextMetadata, 'timestampIso', timestampIso) || metadataChanged;

  const priorRedactedPathCount = Number(nextMetadata.redactedPathCount);
  const resolvedRedactedPathCount = Number.isFinite(priorRedactedPathCount)
    ? Math.max(priorRedactedPathCount, redactedPaths.length)
    : redactedPaths.length;
  metadataChanged = setMetadataValue(nextMetadata, 'redactionApplied', resolvedRedactedPathCount > 0) || metadataChanged;
  metadataChanged = setMetadataValue(nextMetadata, 'redactedPathCount', resolvedRedactedPathCount) || metadataChanged;

  if (metadataChanged) {
    patch.metadata = nextMetadata;
  }
  if (!toSafeString(row.eventType) && eventType) {
    patch.eventType = eventType;
  }
  if (!toSafeString(row.traceId) && traceId) {
    patch.traceId = traceId;
  }
  if (!toSafeString(row.env)) {
    patch.env = env;
  }
  if (!toSafeString(row.service)) {
    patch.service = service;
  }
  if (!toSafeString(row.locale)) {
    patch.locale = locale;
  }
  if (!toSafeString(row.gradeBand)) {
    patch.gradeBand = gradeBand;
  }

  if (Object.keys(patch).length) {
    patch.updatedAt = FieldValue.serverTimestamp();
  }

  return patch;
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

async function applyPatches(db, patches) {
  let applied = 0;
  for (let i = 0; i < patches.length; i += 400) {
    const batchSlice = patches.slice(i, i + 400);
    const batch = db.batch();
    for (const item of batchSlice) {
      batch.update(db.collection(TELEMETRY_COLLECTION).doc(item.id), item.patch);
      applied += 1;
    }
    await batch.commit();
  }
  return applied;
}

async function run() {
  const args = parseArgs(process.argv.slice(2));
  if (args.help) {
    console.log(usage());
    return;
  }
  validateArgs(args);

  const db = initializeAdmin(args);
  const since = new Date(Date.now() - args.hours * 60 * 60 * 1000);

  const snapshot = await db
    .collection(TELEMETRY_COLLECTION)
    .where('createdAt', '>=', Timestamp.fromDate(since))
    .orderBy('createdAt', 'desc')
    .limit(args.limit)
    .get();

  const rows = snapshot.docs
    .map((doc) => ({ id: doc.id, ...doc.data() }))
    .filter((row) => !args.site || row.siteId === args.site);

  const patches = [];
  for (const row of rows) {
    const patch = computePatch(row);
    if (Object.keys(patch).length > 0) {
      patches.push({
        id: row.id,
        event: row.event || null,
        patch,
      });
    }
  }

  printSection('Telemetry Live Repair Input', [
    `hours=${args.hours}`,
    `limit=${args.limit}`,
    `siteFilter=${args.site || '(none)'}`,
    `project=${args.project || '(from credentials/default)'}`,
    `credentials=${args.credentials || '(applicationDefault)'}`,
    `apply=${args.apply}`,
    `strict=${args.strict}`,
  ]);

  printSection('Dataset', [
    `docsScanned=${snapshot.docs.length}`,
    `docsAfterSiteFilter=${rows.length}`,
    `docsNeedingRepair=${patches.length}`,
  ]);

  printSection(
    'Repair Preview (sample)',
    sample(patches, 15).map((item) =>
      JSON.stringify({
        id: item.id,
        event: item.event,
        patch: item.patch,
      }),
    ),
  );

  if (!args.apply) {
    console.log('');
    console.log('Result: DRY RUN');
    if (args.strict && patches.length > 0) {
      process.exitCode = 1;
    }
    return;
  }

  const applied = await applyPatches(db, patches);
  console.log('');
  console.log(`Result: APPLIED (${applied} updated docs)`);

  if (args.strict && applied !== patches.length) {
    process.exitCode = 1;
  }
}

run().catch((error) => {
  console.error('Telemetry live repair failed:', error.message || error);
  process.exitCode = 1;
});
