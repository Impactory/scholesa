#!/usr/bin/env node
'use strict';

const path = require('path');
const { initializeApp, applicationDefault, cert } = require('firebase-admin/app');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');
const {
  initializeFirestoreRestFallback,
  isCredentialAuthError,
  isServiceAccountPayload,
  readJsonFileSafe,
  resolveCredentialPath,
  resolveProjectId,
} = require('./firebase_runtime_auth');

const UNMAPPED_SITE_ID = 'unscoped';

const CORE_AND_EXTENDED_EVENTS = [
  'auth.login',
  'auth.logout',
  'attendance.recorded',
  'mission.attempt.submitted',
  'message.sent',
  'order.paid',
  'cms.page.viewed',
  'popup.shown',
  'popup.dismissed',
  'popup.completed',
  'nudge.snoozed',
  'insight.viewed',
  'support.applied',
  'support.outcome.logged',
  'voice.transcribe',
  'voice.message',
  'voice.tts',
  'site.checkin',
  'site.checkout',
  'site.late_pickup.flagged',
  'schedule.viewed',
  'room.conflict.detected',
  'substitute.requested',
  'substitute.assigned',
  'mission.snapshot.created',
  'rubric.applied',
  'rubric.shared_to_parent_summary',
];

const NON_CORE_EVENTS = [
  'lead.submitted',
  'contract.created',
  'contract.approved',
  'deliverable.submitted',
  'deliverable.accepted',
  'payout.approved',
  'aiDraft.requested',
  'aiDraft.reviewed',
  'order.intent',
  'cta.clicked',
  'notification.requested',
  'educator.review.completed',
];

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
    'Telemetry smoke validator',
    '',
    'Usage:',
    '  node scripts/telemetry_smoke_check.js [options]',
    '',
    'Options:',
    '  --mode=core|full        Validate only core+extended or full (core+non-core). Default: full',
    '  --hours=N               Lookback window in hours. Default: 24',
    '  --limit=N               Max telemetry documents to scan. Default: 5000',
    '  --site=SITE_ID          Optional site filter applied in-memory',
    '  --strict                Exit 1 on any failed validation',
    '  --help                  Show this help',
    '',
    'Environment:',
    '  GOOGLE_APPLICATION_CREDENTIALS=path/to/service-account.json (recommended)',
    '  FIREBASE_PROJECT_ID=your-project-id (optional if in service account)',
  ].join('\n');
}

function parseArgs(argv) {
  const args = {
    mode: 'full',
    hours: 24,
    limit: 5000,
    site: undefined,
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
    if (!arg.startsWith('--')) {
      continue;
    }
    const [rawKey, rawValue] = arg.slice(2).split('=');
    if (rawValue === undefined) {
      continue;
    }
    if (rawKey === 'mode') {
      args.mode = rawValue;
      continue;
    }
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
  }

  return args;
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
  for (const line of lines) {
    console.log(line);
  }
}

function validateOptions(args) {
  const validModes = new Set(['core', 'full']);
  if (!validModes.has(args.mode)) {
    throw new Error(`Invalid --mode "${args.mode}". Use core or full.`);
  }
  if (!Number.isFinite(args.hours) || args.hours <= 0) {
    throw new Error(`Invalid --hours "${args.hours}". Use a positive number.`);
  }
  if (!Number.isFinite(args.limit) || args.limit <= 0) {
    throw new Error(`Invalid --limit "${args.limit}". Use a positive number.`);
  }
}

function initializeAdminApp() {
  const credentialPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  const projectId = process.env.FIREBASE_PROJECT_ID;
  if (credentialPath) {
    const resolvedCredentialPath = path.resolve(credentialPath);
    const payload = readJsonFileSafe(resolvedCredentialPath);
    if (isServiceAccountPayload(payload)) {
      return initializeApp({
        credential: cert(payload),
        ...(projectId ? { projectId } : {}),
      });
    }
    process.env.GOOGLE_APPLICATION_CREDENTIALS = resolvedCredentialPath;
    return initializeApp({
      credential: applicationDefault(),
      ...(projectId ? { projectId } : {}),
    });
  }

  return initializeApp({
    credential: applicationDefault(),
    ...(projectId ? { projectId } : {}),
  });
}

async function loadTelemetrySnapshot(args, since) {
  initializeAdminApp();
  const db = getFirestore();

  try {
    const snapshot = await db
      .collection('telemetryEvents')
      .where('createdAt', '>=', Timestamp.fromDate(since))
      .orderBy('createdAt', 'desc')
      .limit(args.limit)
      .get();
    return { snapshot, transport: 'firebaseAdmin' };
  } catch (error) {
    if (!isCredentialAuthError(error)) {
      throw error;
    }
    const projectId = resolveProjectId(
      process.env.FIREBASE_PROJECT_ID,
      resolveCredentialPath(process.env.GOOGLE_APPLICATION_CREDENTIALS),
    );
    const fallback = initializeFirestoreRestFallback(projectId);
    const snapshot = await fallback.db
      .collection('telemetryEvents')
      .where('createdAt', '>=', since)
      .orderBy('createdAt', 'desc')
      .limit(args.limit)
      .get();
    return { snapshot, transport: fallback.transport };
  }
}

async function run() {
  const args = parseArgs(process.argv.slice(2));

  if (args.help) {
    console.log(usage());
    return;
  }

  validateOptions(args);

  const requiredEvents =
    args.mode === 'core'
      ? CORE_AND_EXTENDED_EVENTS
      : [...CORE_AND_EXTENDED_EVENTS, ...NON_CORE_EVENTS];
  const since = new Date(Date.now() - args.hours * 60 * 60 * 1000);
  const { snapshot, transport } = await loadTelemetrySnapshot(args, since);

  const docs = snapshot.docs
    .map((doc) => ({ id: doc.id, ...doc.data() }))
    .filter((row) => !args.site || row.siteId === args.site);

  const eventCounts = new Map();
  const roleCounts = new Map();
  const schemaErrors = [];
  const correlationErrors = [];
  const tenantTagErrors = [];
  const piiKeyErrors = [];

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

    if (role !== 'hq' && role !== 'system' && siteId === UNMAPPED_SITE_ID) {
      tenantTagErrors.push({
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

    const piiPaths = hasPiiKeys(metadata);
    if (piiPaths.length > 0) {
      piiKeyErrors.push({
        id: row.id,
        event,
        piiPaths: sample(piiPaths, 5),
      });
    }

    if (event) {
      eventCounts.set(event, (eventCounts.get(event) ?? 0) + 1);
    }
    if (role) {
      roleCounts.set(role, (roleCounts.get(role) ?? 0) + 1);
    }
  }

  const missingEvents = requiredEvents.filter((event) => !eventCounts.has(event));

  printSection('Telemetry Smoke Input', [
    `mode=${args.mode}`,
    `hours=${args.hours}`,
    `limit=${args.limit}`,
    `siteFilter=${args.site || '(none)'}`,
    `strict=${args.strict}`,
    `transport=${transport}`,
  ]);

  printSection('Dataset', [
    `docsScanned=${snapshot.docs.length}`,
    `docsAfterSiteFilter=${docs.length}`,
    `distinctEventsSeen=${eventCounts.size}`,
  ]);

  printSection(
    'Role Counts',
    Array.from(roleCounts.entries())
      .sort((a, b) => a[0].localeCompare(b[0]))
      .map(([role, count]) => `${role}=${count}`),
  );

  printSection(
    'Required Event Coverage',
    requiredEvents.map((event) => `${event}=${eventCounts.get(event) ?? 0}`),
  );

  const failures = [];
  if (missingEvents.length > 0) {
    failures.push(`missingRequiredEvents=${missingEvents.length}`);
    printSection(
      'Missing Required Events',
      missingEvents.map((event) => `- ${event}`),
    );
  }
  if (schemaErrors.length > 0) {
    failures.push(`schemaErrors=${schemaErrors.length}`);
    printSection(
      'Schema Errors (sample)',
      sample(schemaErrors, 10).map((row) => JSON.stringify(row)),
    );
  }
  if (correlationErrors.length > 0) {
    failures.push(`correlationErrors=${correlationErrors.length}`);
    printSection(
      'Correlation Errors (sample)',
      sample(correlationErrors, 10).map((row) => JSON.stringify(row)),
    );
  }
  if (tenantTagErrors.length > 0) {
    failures.push(`tenantTagErrors=${tenantTagErrors.length}`);
    printSection(
      'Tenant Tag Errors (sample)',
      sample(tenantTagErrors, 10).map((row) => JSON.stringify(row)),
    );
  }
  if (piiKeyErrors.length > 0) {
    failures.push(`piiKeyErrors=${piiKeyErrors.length}`);
    printSection(
      'PII Key Errors (sample)',
      sample(piiKeyErrors, 10).map((row) => JSON.stringify(row)),
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
  console.error('Telemetry smoke validator failed:', error.message || error);
  process.exitCode = 1;
});
