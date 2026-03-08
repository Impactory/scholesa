#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const cp = require('child_process');
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
const VOICE_EVENTS_REQUIRING_UNDERSTANDING = new Set([
  'voice.transcribe',
  'voice.message',
  'voice.tts',
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

function isServiceAccountCredentialPath(candidate) {
  if (typeof candidate !== 'string' || !candidate.trim()) return false;
  const credentialPath = path.resolve(ROOT, candidate);
  if (!fs.existsSync(credentialPath)) return false;
  try {
    const payload = JSON.parse(fs.readFileSync(credentialPath, 'utf8'));
    return (
      payload &&
      typeof payload === 'object' &&
      payload.type === 'service_account' &&
      typeof payload.private_key === 'string' &&
      payload.private_key.length > 0 &&
      typeof payload.project_id === 'string' &&
      payload.project_id.trim().length > 0
    );
  } catch {
    return false;
  }
}

function parseArgs(argv) {
  const envCredentials = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  const args = {
    hours: 168,
    limit: 20000,
    site: undefined,
    project: process.env.FIREBASE_PROJECT_ID,
    credentials: isServiceAccountCredentialPath(envCredentials) ? envCredentials : undefined,
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
    normalized === 'parent' ||
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

function isCredentialAuthError(error) {
  const message = error instanceof Error ? error.message : String(error || '');
  return (
    /unable to impersonate/i.test(message) ||
    /Could not refresh access token/i.test(message) ||
    /iam\.serviceAccounts\.getAccessToken/i.test(message) ||
    /\bUNAUTHENTICATED\b/i.test(message) ||
    /invalid authentication credentials/i.test(message)
  );
}

function resolveProjectIdForRest(args) {
  if (typeof args.project === 'string' && args.project.trim()) {
    return args.project.trim();
  }
  try {
    const value = cp.execSync('gcloud config get-value project', {
      stdio: ['ignore', 'pipe', 'ignore'],
      encoding: 'utf8',
    });
    const normalized = String(value || '').trim();
    if (normalized && normalized !== '(unset)') {
      return normalized;
    }
  } catch {
    return undefined;
  }
  return undefined;
}

function getGcloudAccessToken() {
  try {
    const token = cp.execSync('gcloud auth print-access-token', {
      stdio: ['ignore', 'pipe', 'pipe'],
      encoding: 'utf8',
    });
    const normalized = String(token || '').trim();
    if (!normalized) {
      throw new Error('gcloud auth print-access-token returned an empty token.');
    }
    return normalized;
  } catch (error) {
    const stderr =
      error && typeof error === 'object' && typeof error.stderr === 'string'
        ? error.stderr.trim()
        : '';
    throw new Error(
      stderr ||
        'Unable to obtain a gcloud access token. Run `gcloud auth login` and ensure the signed-in user can read Firestore.',
    );
  }
}

function encodeFirestoreValue(value) {
  if (value instanceof Timestamp) return { timestampValue: value.toDate().toISOString() };
  if (value instanceof Date) return { timestampValue: value.toISOString() };
  if (value === null) return { nullValue: null };
  if (Array.isArray(value)) {
    return {
      arrayValue: {
        values: value.map((entry) => encodeFirestoreValue(entry)),
      },
    };
  }
  if (typeof value === 'string') return { stringValue: value };
  if (typeof value === 'boolean') return { booleanValue: value };
  if (typeof value === 'number') {
    if (Number.isInteger(value)) return { integerValue: String(value) };
    return { doubleValue: value };
  }
  if (value && typeof value === 'object') {
    const fields = {};
    for (const [key, entry] of Object.entries(value)) {
      fields[key] = encodeFirestoreValue(entry);
    }
    return { mapValue: { fields } };
  }
  return { stringValue: String(value) };
}

function decodeFirestoreValue(value) {
  if (!value || typeof value !== 'object') return undefined;
  if (Object.prototype.hasOwnProperty.call(value, 'nullValue')) return null;
  if (Object.prototype.hasOwnProperty.call(value, 'stringValue')) return value.stringValue;
  if (Object.prototype.hasOwnProperty.call(value, 'booleanValue')) return value.booleanValue;
  if (Object.prototype.hasOwnProperty.call(value, 'integerValue')) return Number(value.integerValue);
  if (Object.prototype.hasOwnProperty.call(value, 'doubleValue')) return value.doubleValue;
  if (Object.prototype.hasOwnProperty.call(value, 'timestampValue')) return new Date(value.timestampValue);
  if (Object.prototype.hasOwnProperty.call(value, 'referenceValue')) return value.referenceValue;
  if (Object.prototype.hasOwnProperty.call(value, 'bytesValue')) return value.bytesValue;
  if (Object.prototype.hasOwnProperty.call(value, 'arrayValue')) {
    const entries = Array.isArray(value.arrayValue && value.arrayValue.values)
      ? value.arrayValue.values
      : [];
    return entries.map((entry) => decodeFirestoreValue(entry));
  }
  if (Object.prototype.hasOwnProperty.call(value, 'mapValue')) {
    const fields = (value.mapValue && value.mapValue.fields) || {};
    const record = {};
    for (const [key, entry] of Object.entries(fields)) {
      record[key] = decodeFirestoreValue(entry);
    }
    return record;
  }
  return undefined;
}

function decodeFirestoreDocument(document) {
  const data = {};
  const fields = (document && document.fields) || {};
  for (const [key, value] of Object.entries(fields)) {
    data[key] = decodeFirestoreValue(value);
  }
  return data;
}

function normalizeRestOperator(operator) {
  if (operator === '==') return 'EQUAL';
  if (operator === '>=') return 'GREATER_THAN_OR_EQUAL';
  throw new Error(`Unsupported Firestore REST operator: ${operator}`);
}

function buildStructuredWhere(filters) {
  if (!Array.isArray(filters) || filters.length === 0) return undefined;
  const entries = filters.map(({ field, operator, value }) => ({
    fieldFilter: {
      field: { fieldPath: field },
      op: normalizeRestOperator(operator),
      value: encodeFirestoreValue(value),
    },
  }));
  if (entries.length === 1) return entries[0];
  return {
    compositeFilter: {
      op: 'AND',
      filters: entries,
    },
  };
}

function normalizeRestDirection(direction) {
  const normalized = String(direction || 'asc').trim().toLowerCase();
  return normalized === 'desc' ? 'DESCENDING' : 'ASCENDING';
}

async function firestoreRestJson(url, accessToken, options = {}) {
  const response = await fetch(url, {
    ...options,
    headers: {
      Authorization: `Bearer ${accessToken}`,
      ...(options.body ? { 'Content-Type': 'application/json' } : {}),
      ...(options.headers || {}),
    },
  });
  const text = await response.text();
  const payload = text ? JSON.parse(text) : null;
  if (!response.ok) {
    const message = (payload && payload.error && payload.error.message) || `${response.status} ${response.statusText}`;
    const error = new Error(`${response.status} ${message}`);
    error.status = response.status;
    error.payload = payload;
    throw error;
  }
  return payload;
}

async function runFirestoreRestQuery({ projectId, accessToken, collection, filters = [], orderBy = [], limit }) {
  const baseUrl = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:runQuery`;
  const structuredQuery = {
    from: [{ collectionId: collection }],
  };
  const where = buildStructuredWhere(filters);
  if (where) structuredQuery.where = where;
  if (Array.isArray(orderBy) && orderBy.length > 0) {
    structuredQuery.orderBy = orderBy.map(({ field, direction }) => ({
      field: { fieldPath: field },
      direction: normalizeRestDirection(direction),
    }));
  }
  if (typeof limit === 'number' && Number.isFinite(limit)) {
    structuredQuery.limit = Math.max(0, Math.trunc(limit));
  }

  const responses = await firestoreRestJson(baseUrl, accessToken, {
    method: 'POST',
    body: JSON.stringify({ structuredQuery }),
  });

  return Array.isArray(responses)
    ? responses
        .filter((entry) => entry && entry.document)
        .map((entry) => {
          const name = String(entry.document.name || '');
          const id = name.split('/').pop() || '';
          return { id, ...decodeFirestoreDocument(entry.document) };
        })
    : [];
}

async function queryFirestoreCollectionsWithAdmin(db, args, since) {
  const snapshot = await db
    .collection(TELEMETRY_COLLECTION)
    .where('createdAt', '>=', Timestamp.fromDate(since))
    .orderBy('createdAt', 'desc')
    .limit(args.limit)
    .get();

  const allDocs = snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
  const docs = allDocs.filter((row) => !args.site || row.siteId === args.site);

  const interactionQueryErrors = [];
  const learningProfileQueryErrors = [];
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

  const allInteractionDocs = interactionSnapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
  const interactionDocs = allInteractionDocs.filter((row) => !args.site || row.siteId === args.site);

  let learningProfilesSnapshot = { docs: [] };
  try {
    learningProfilesSnapshot = await db
      .collection('bosLearningProfiles')
      .orderBy('updatedAt', 'desc')
      .limit(Math.max(200, Math.min(args.limit, 2000)))
      .get();
  } catch (error) {
    learningProfileQueryErrors.push(
      `bos_learning_profiles_query_failed:${error instanceof Error ? error.message : String(error)}`,
    );
  }

  const allLearningProfileDocs = learningProfilesSnapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
  const learningProfileDocs = allLearningProfileDocs.filter((row) => !args.site || row.siteId === args.site);

  return {
    transport: 'firebaseAdmin',
    docs,
    docsScanned: allDocs.length,
    interactionDocs,
    interactionDocsScanned: allInteractionDocs.length,
    learningProfileDocs,
    learningProfilesScanned: allLearningProfileDocs.length,
    interactionQueryErrors,
    learningProfileQueryErrors,
  };
}

async function queryFirestoreCollectionsWithGcloudRest(args, since) {
  const projectId = resolveProjectIdForRest(args);
  if (!projectId) {
    throw new Error('Unable to resolve project ID for Firestore REST fallback.');
  }
  const accessToken = getGcloudAccessToken();

  const allDocs = await runFirestoreRestQuery({
    projectId,
    accessToken,
    collection: TELEMETRY_COLLECTION,
    filters: [{ field: 'createdAt', operator: '>=', value: since }],
    orderBy: [{ field: 'createdAt', direction: 'desc' }],
    limit: args.limit,
  });
  const docs = allDocs.filter((row) => !args.site || row.siteId === args.site);

  const interactionQueryErrors = [];
  const learningProfileQueryErrors = [];
  let allInteractionDocs = [];
  let interactionDocs = [];
  try {
    allInteractionDocs = await runFirestoreRestQuery({
      projectId,
      accessToken,
      collection: INTERACTION_COLLECTION,
      filters: [{ field: 'timestamp', operator: '>=', value: since }],
      orderBy: [{ field: 'timestamp', direction: 'desc' }],
      limit: args.limit,
    });
    interactionDocs = allInteractionDocs.filter((row) => !args.site || row.siteId === args.site);
  } catch (error) {
    interactionQueryErrors.push(
      `interaction_query_failed:${error instanceof Error ? error.message : String(error)}`,
    );
  }

  let allLearningProfileDocs = [];
  let learningProfileDocs = [];
  try {
    allLearningProfileDocs = await runFirestoreRestQuery({
      projectId,
      accessToken,
      collection: 'bosLearningProfiles',
      orderBy: [{ field: 'updatedAt', direction: 'desc' }],
      limit: Math.max(200, Math.min(args.limit, 2000)),
    });
    learningProfileDocs = allLearningProfileDocs.filter((row) => !args.site || row.siteId === args.site);
  } catch (error) {
    learningProfileQueryErrors.push(
      `bos_learning_profiles_query_failed:${error instanceof Error ? error.message : String(error)}`,
    );
  }

  return {
    transport: 'firestoreRestOAuth',
    docs,
    docsScanned: allDocs.length,
    interactionDocs,
    interactionDocsScanned: allInteractionDocs.length,
    learningProfileDocs,
    learningProfilesScanned: allLearningProfileDocs.length,
    interactionQueryErrors,
    learningProfileQueryErrors,
  };
}

async function loadLiveDatasets(args, since) {
  try {
    const db = initializeAdmin(args);
    return await queryFirestoreCollectionsWithAdmin(db, args, since);
  } catch (error) {
    if (!isCredentialAuthError(error)) {
      throw error;
    }
    return queryFirestoreCollectionsWithGcloudRest(args, since);
  }
}

function hasValidUnderstandingShape(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return false;
  const metadata = value;
  const intentOk = typeof metadata.understandingIntent === 'string' && metadata.understandingIntent.trim().length > 0;
  const responseModeOk = typeof metadata.responseMode === 'string' && metadata.responseMode.trim().length > 0;
  const complexityOk = typeof metadata.complexity === 'string' && metadata.complexity.trim().length > 0;
  const emotionalStateOk = typeof metadata.emotionalState === 'string' && metadata.emotionalState.trim().length > 0;
  const needsScaffoldOk = typeof metadata.needsScaffold === 'boolean';
  const confidenceOk = typeof metadata.understandingConfidence === 'number' &&
    Number.isFinite(metadata.understandingConfidence) &&
    metadata.understandingConfidence >= 0 &&
    metadata.understandingConfidence <= 1;
  return intentOk && responseModeOk && complexityOk && emotionalStateOk && needsScaffoldOk && confidenceOk;
}

function initializeAdmin(args) {
  const appOptions = {};
  if (args.project) {
    appOptions.projectId = args.project;
  }
  if (isServiceAccountCredentialPath(args.credentials)) {
    const credentialPath = path.resolve(ROOT, args.credentials);
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
  const since = new Date(Date.now() - args.hours * 60 * 60 * 1000);
  const {
    transport,
    docs,
    docsScanned,
    interactionDocs,
    interactionDocsScanned,
    learningProfileDocs,
    learningProfilesScanned,
    interactionQueryErrors,
    learningProfileQueryErrors,
  } = await loadLiveDatasets(args, since);

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
  const voiceUnderstandingCompatibilityErrors = [];
  const bosVoiceUnderstandingCompatibilityErrors = [];
  const bosLearningProfileCompatibilityErrors = [];
  const bosEventCounts = new Map();
  const voiceUnderstandingCoverage = {
    'voice.transcribe': { total: 0, withSignals: 0 },
    'voice.message': { total: 0, withSignals: 0 },
    'voice.tts': { total: 0, withSignals: 0 },
  };
  const bosVoiceUnderstandingCoverage = {
    ai_help_opened: { total: 0, withSignals: 0 },
    ai_help_used: { total: 0, withSignals: 0 },
    ai_coach_response: { total: 0, withSignals: 0 },
  };
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
      const metadataRoleCanonical = normalizeTelemetryRole(metadata.role);
      const rowRoleCanonical = normalizeTelemetryRole(role);
      if (typeof metadata.eventType !== 'string' || metadata.eventType !== event) {
        invalids.push(`eventType_mismatch:${String(metadata.eventType || 'missing')}`);
      }
      if (typeof metadata.service !== 'string' || metadata.service.trim().length === 0) {
        invalids.push('service_missing_or_invalid');
      }
      if (typeof metadata.env !== 'string' || !VALID_VOICE_ENVS.has(metadata.env)) {
        invalids.push(`env_invalid:${String(metadata.env || 'missing')}`);
      }
      if (!metadataRoleCanonical || !VALID_VOICE_ROLES.has(metadataRoleCanonical)) {
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
      if (!rowRoleCanonical) {
        invalids.push(`role_invalid_row:${String(role || 'missing')}`);
      }
      if (metadataRoleCanonical && rowRoleCanonical && metadataRoleCanonical !== rowRoleCanonical) {
        invalids.push(`role_mismatch:${metadataRoleCanonical}:${rowRoleCanonical}`);
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

      if (VOICE_EVENTS_REQUIRING_UNDERSTANDING.has(event)) {
        const coverage = voiceUnderstandingCoverage[event];
        if (coverage) {
          coverage.total += 1;
          if (hasValidUnderstandingShape(metadata)) {
            coverage.withSignals += 1;
          }
        }
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
      if (Object.prototype.hasOwnProperty.call(bosVoiceUnderstandingCoverage, eventType)) {
        const coverage = bosVoiceUnderstandingCoverage[eventType];
        coverage.total += 1;
        if (hasValidUnderstandingShape(payload)) {
          coverage.withSignals += 1;
        }
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

  const voiceUnderstandingCandidateErrors = [];
  for (const [eventName, coverage] of Object.entries(voiceUnderstandingCoverage)) {
    if (coverage.total > 0 && coverage.withSignals === 0) {
      voiceUnderstandingCandidateErrors.push({
        reason: `voice_understanding_signals_missing_for_${eventName.replace(/\./g, '_')}`,
        total: coverage.total,
        withSignals: coverage.withSignals,
      });
    }
  }

  const bosVoiceUnderstandingCandidateErrors = [];
  for (const [eventName, coverage] of Object.entries(bosVoiceUnderstandingCoverage)) {
    if (coverage.total > 0 && coverage.withSignals === 0) {
      bosVoiceUnderstandingCandidateErrors.push({
        reason: `bos_voice_understanding_signals_missing_for_${eventName}`,
        total: coverage.total,
        withSignals: coverage.withSignals,
      });
    }
  }

  const learningProfilesWithSignals = learningProfileDocs.filter((row) => {
    const learning = row.learning && typeof row.learning === 'object' && !Array.isArray(row.learning)
      ? row.learning
      : {};
    const metrics = row.metrics && typeof row.metrics === 'object' && !Array.isArray(row.metrics)
      ? row.metrics
      : {};
    return (
      typeof learning.lastIntent === 'string' &&
      learning.lastIntent.trim().length > 0 &&
      typeof learning.lastUnderstandingConfidence === 'number' &&
      Number.isFinite(learning.lastUnderstandingConfidence) &&
      typeof metrics.totalInteractions === 'number' &&
      Number.isFinite(metrics.totalInteractions)
    );
  });

  const totalVoiceUnderstandingEvents = Object.values(voiceUnderstandingCoverage)
    .reduce((sum, coverage) => sum + coverage.withSignals, 0);
  const totalBosVoiceUnderstandingEvents = Object.values(bosVoiceUnderstandingCoverage)
    .reduce((sum, coverage) => sum + coverage.withSignals, 0);
  const voiceUnderstandingRolloutActive =
    totalVoiceUnderstandingEvents > 0 ||
    totalBosVoiceUnderstandingEvents > 0 ||
    learningProfilesWithSignals.length > 0;

  if (voiceUnderstandingRolloutActive) {
    voiceUnderstandingCompatibilityErrors.push(...voiceUnderstandingCandidateErrors);
    bosVoiceUnderstandingCompatibilityErrors.push(...bosVoiceUnderstandingCandidateErrors);
    if (totalVoiceUnderstandingEvents > 0 && learningProfilesWithSignals.length === 0) {
      bosLearningProfileCompatibilityErrors.push({
        reason: 'bos_learning_profiles_missing_understanding_state',
        totalVoiceUnderstandingEvents,
        learningProfilesScanned: learningProfileDocs.length,
        learningProfilesWithSignals: 0,
      });
    }
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
    transport,
    docsScanned,
    docsAfterSiteFilter: docs.length,
    interactionDocsScanned,
    interactionDocsAfterSiteFilter: interactionDocs.length,
    learningProfilesScanned,
    learningProfilesAfterSiteFilter: learningProfileDocs.length,
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
    voiceUnderstandingCompatibilityErrors,
    bosVoiceUnderstandingCompatibilityErrors,
    bosLearningProfileCompatibilityErrors,
    bosInteractionSchemaErrors,
    bosVoiceTraceContinuityErrors,
    voiceUnderstandingCoverage,
    bosVoiceUnderstandingCoverage,
    voiceUnderstandingRolloutActive,
    voiceUnderstandingSignalCounts: {
      telemetry: totalVoiceUnderstandingEvents,
      interaction: totalBosVoiceUnderstandingEvents,
      learningProfiles: learningProfilesWithSignals.length,
    },
    traceOverlap: {
      sttToMessage: sttToMessageTraceOverlap.length,
      sttToBosOpened: sttToBosTraceOverlap.length,
      messageToBosUsed: messageToBosTraceOverlap.length,
      ttsToBosResponse: ttsToBosTraceOverlap.length,
    },
    interactionQueryErrors,
    learningProfileQueryErrors,
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
    `transport=${live.transport || 'firebaseAdmin'}`,
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
    `learningProfilesScanned=${live.learningProfilesScanned}`,
    `learningProfilesAfterSiteFilter=${live.learningProfilesAfterSiteFilter}`,
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
  printSection(
    'Voice Understanding Coverage',
    Object.entries(live.voiceUnderstandingCoverage).map(([eventName, coverage]) =>
      `${eventName}=with_signals:${coverage.withSignals}/total:${coverage.total}`,
    ),
  );
  printSection(
    'BOS Voice Understanding Coverage',
    Object.entries(live.bosVoiceUnderstandingCoverage).map(([eventName, coverage]) =>
      `${eventName}=with_signals:${coverage.withSignals}/total:${coverage.total}`,
    ),
  );
  printSection('Voice Understanding Rollout', [
    `rolloutActive=${live.voiceUnderstandingRolloutActive}`,
    `telemetrySignalDocs=${live.voiceUnderstandingSignalCounts.telemetry}`,
    `interactionSignalDocs=${live.voiceUnderstandingSignalCounts.interaction}`,
    `learningProfilesWithSignals=${live.voiceUnderstandingSignalCounts.learningProfiles}`,
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

  if (live.voiceUnderstandingCompatibilityErrors.length > 0) {
    failures.push(`liveVoiceUnderstandingCompatibilityErrors=${live.voiceUnderstandingCompatibilityErrors.length}`);
    printSection(
      'Live Voice Understanding Compatibility Errors',
      live.voiceUnderstandingCompatibilityErrors.map((row) => JSON.stringify(row)),
    );
  }

  if (live.bosVoiceUnderstandingCompatibilityErrors.length > 0) {
    failures.push(`liveBosVoiceUnderstandingCompatibilityErrors=${live.bosVoiceUnderstandingCompatibilityErrors.length}`);
    printSection(
      'Live BOS Voice Understanding Compatibility Errors',
      live.bosVoiceUnderstandingCompatibilityErrors.map((row) => JSON.stringify(row)),
    );
  }

  if (live.bosLearningProfileCompatibilityErrors.length > 0) {
    failures.push(`liveBosLearningProfileCompatibilityErrors=${live.bosLearningProfileCompatibilityErrors.length}`);
    printSection(
      'Live BOS Learning Profile Compatibility Errors',
      live.bosLearningProfileCompatibilityErrors.map((row) => JSON.stringify(row)),
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

  if (live.learningProfileQueryErrors.length > 0) {
    failures.push(`learningProfileQueryErrors=${live.learningProfileQueryErrors.length}`);
    printSection('Learning Profile Query Errors', live.learningProfileQueryErrors);
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
