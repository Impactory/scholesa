#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const { initializeApp, applicationDefault, cert, getApps } = require('firebase-admin/app');
const { getFirestore, Timestamp, FieldValue } = require('firebase-admin/firestore');

const ROOT = path.resolve(__dirname, '..');
const TELEMETRY_COLLECTION = 'telemetryEvents';
const UNMAPPED_SITE_ID = 'unscoped';

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

function computePatch(row) {
  const patch = {};
  const metadata = asObject(row.metadata);
  const nextMetadata = { ...metadata };
  let metadataChanged = false;

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

  const requestId = toSafeString(metadata.requestId);
  if (!requestId) {
    nextMetadata.requestId = `repair-${row.id}`;
    metadataChanged = true;
  }

  const traceId = toSafeString(metadata.traceId);
  if (!traceId) {
    nextMetadata.traceId = nextMetadata.requestId || `repair-${row.id}`;
    metadataChanged = true;
  }

  if (typeof metadata.redactionApplied !== 'boolean') {
    nextMetadata.redactionApplied = false;
    metadataChanged = true;
  }
  if (!Number.isFinite(metadata.redactedPathCount)) {
    nextMetadata.redactedPathCount = 0;
    metadataChanged = true;
  }

  if (metadataChanged || metadata !== row.metadata) {
    patch.metadata = nextMetadata;
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
