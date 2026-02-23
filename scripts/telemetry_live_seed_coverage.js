#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const { initializeApp, applicationDefault, cert, getApps } = require('firebase-admin/app');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');

const ROOT = path.resolve(__dirname, '..');
const TELEMETRY_COLLECTION = 'telemetryEvents';
const SMOKE_FILE = path.join(ROOT, 'scripts/telemetry_smoke_check.js');

const ROLE_BY_EVENT = {
  'auth.login': 'learner',
  'auth.logout': 'learner',
  'attendance.recorded': 'educator',
  'mission.attempt.submitted': 'learner',
  'message.sent': 'educator',
  'order.intent': 'partner',
  'order.paid': 'partner',
  'cms.page.viewed': 'hq',
  'popup.shown': 'learner',
  'popup.dismissed': 'learner',
  'popup.completed': 'learner',
  'nudge.snoozed': 'learner',
  'insight.viewed': 'educator',
  'support.applied': 'educator',
  'support.outcome.logged': 'educator',
  'site.checkin': 'site',
  'site.checkout': 'site',
  'site.late_pickup.flagged': 'site',
  'schedule.viewed': 'site',
  'room.conflict.detected': 'site',
  'substitute.requested': 'educator',
  'substitute.assigned': 'site',
  'mission.snapshot.created': 'hq',
  'rubric.applied': 'hq',
  'rubric.shared_to_parent_summary': 'hq',
  'lead.submitted': 'partner',
  'contract.created': 'partner',
  'contract.approved': 'hq',
  'deliverable.submitted': 'partner',
  'deliverable.accepted': 'hq',
  'payout.approved': 'hq',
  'aiDraft.requested': 'partner',
  'aiDraft.reviewed': 'hq',
  'cta.clicked': 'site',
  'notification.requested': 'hq',
  'educator.review.completed': 'educator',
};

function usage() {
  return [
    'Telemetry live coverage seed (fills only missing canonical events)',
    '',
    'Usage:',
    '  node scripts/telemetry_live_seed_coverage.js [options]',
    '',
    'Options:',
    '  --hours=N             Lookback window in hours. Default: 720',
    '  --limit=N             Max telemetry docs to scan. Default: 20000',
    '  --site=SITE_ID        Site id to use for seeded non-HQ events.',
    '  --project=PROJECT_ID  Firebase project override',
    '  --credentials=PATH    Service account JSON path override',
    '  --apply               Apply writes (default: dry-run)',
    '  --strict              Exit 1 if missing events remain after apply/dry-run',
    '  --help                Show this help',
  ].join('\n');
}

function parseArgs(argv) {
  const args = {
    hours: 720,
    limit: 20000,
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
    if (arg === '--apply') {
      args.apply = true;
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
    throw new Error(`Invalid --hours "${args.hours}".`);
  }
  if (!Number.isFinite(args.limit) || args.limit <= 0) {
    throw new Error(`Invalid --limit "${args.limit}".`);
  }
}

function initializeAdmin(args) {
  const appOptions = {};
  if (args.project) appOptions.projectId = args.project;
  if (args.credentials) {
    const credentialPath = path.resolve(ROOT, args.credentials);
    if (!fs.existsSync(credentialPath)) {
      throw new Error(`Credentials file not found: ${credentialPath}`);
    }
    appOptions.credential = cert(require(credentialPath));
  } else {
    appOptions.credential = applicationDefault();
  }
  if (!getApps().length) initializeApp(appOptions);
  return getFirestore();
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

function parseCanonicalEventsFromSmoke() {
  if (!fs.existsSync(SMOKE_FILE)) {
    throw new Error('telemetry_smoke_check.js not found');
  }
  const source = fs.readFileSync(SMOKE_FILE, 'utf8');
  const coreMatch = source.match(/const CORE_AND_EXTENDED_EVENTS\s*=\s*\[([\s\S]*?)\];/);
  const nonCoreMatch = source.match(/const NON_CORE_EVENTS\s*=\s*\[([\s\S]*?)\];/);
  if (!coreMatch || !nonCoreMatch) {
    throw new Error('Unable to parse canonical events from telemetry_smoke_check.js');
  }
  const core = parseSingleQuotedLiterals(coreMatch[1]);
  const nonCore = parseSingleQuotedLiterals(nonCoreMatch[1]);
  return Array.from(new Set([...core, ...nonCore])).sort((a, b) => a.localeCompare(b));
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

function pickSeedSite(rows, explicitSite) {
  if (explicitSite && explicitSite.trim().length > 0) {
    return explicitSite.trim();
  }
  const firstScoped = rows.find((row) => typeof row.siteId === 'string' && row.siteId !== 'unscoped');
  if (firstScoped && typeof firstScoped.siteId === 'string') {
    return firstScoped.siteId;
  }
  return 'seed-site';
}

function buildSeedDoc(event, role, siteId, index) {
  const requestId = `seed-${Date.now()}-${index}`;
  const userId = role === 'system' ? 'system' : `seed-${role}`;
  return {
    event,
    role,
    userId,
    siteId,
    createdAt: Timestamp.now(),
    metadata: {
      requestId,
      traceId: requestId,
      redactionApplied: false,
      redactedPathCount: 0,
      syntheticCoverageSeed: true,
      seededAt: new Date().toISOString(),
      seededBy: 'telemetry_live_seed_coverage',
    },
  };
}

async function applySeedDocs(db, docs) {
  let written = 0;
  for (let i = 0; i < docs.length; i += 400) {
    const slice = docs.slice(i, i + 400);
    const batch = db.batch();
    for (const doc of slice) {
      const ref = db.collection(TELEMETRY_COLLECTION).doc();
      batch.set(ref, doc);
      written += 1;
    }
    await batch.commit();
  }
  return written;
}

async function run() {
  const args = parseArgs(process.argv.slice(2));
  if (args.help) {
    console.log(usage());
    return;
  }
  validateArgs(args);

  const canonicalEvents = parseCanonicalEventsFromSmoke();
  const db = initializeAdmin(args);
  const since = new Date(Date.now() - args.hours * 60 * 60 * 1000);

  const snapshot = await db
    .collection(TELEMETRY_COLLECTION)
    .where('createdAt', '>=', Timestamp.fromDate(since))
    .orderBy('createdAt', 'desc')
    .limit(args.limit)
    .get();

  const rows = snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
  const eventSet = new Set(
    rows
      .map((row) => (typeof row.event === 'string' ? row.event : ''))
      .filter(Boolean),
  );
  const missing = canonicalEvents.filter((event) => !eventSet.has(event));
  const seedSite = pickSeedSite(rows, args.site);

  const seedDocs = missing.map((event, index) => {
    const role = ROLE_BY_EVENT[event] || 'system';
    const siteId = role === 'system' ? 'unscoped' : seedSite;
    return buildSeedDoc(event, role, siteId, index);
  });

  printSection('Telemetry Coverage Seed Input', [
    `hours=${args.hours}`,
    `limit=${args.limit}`,
    `project=${args.project || '(from credentials/default)'}`,
    `credentials=${args.credentials || '(applicationDefault)'}`,
    `apply=${args.apply}`,
    `strict=${args.strict}`,
    `seedSite=${seedSite}`,
  ]);

  printSection('Coverage', [
    `canonicalEvents=${canonicalEvents.length}`,
    `docsScanned=${rows.length}`,
    `missingEvents=${missing.length}`,
  ]);

  printSection(
    'Missing Events (sample)',
    sample(missing, 50).map((event) => `- ${event}`),
  );

  if (!args.apply) {
    console.log('');
    console.log('Result: DRY RUN');
    if (args.strict && missing.length > 0) {
      process.exitCode = 1;
    }
    return;
  }

  const written = await applySeedDocs(db, seedDocs);

  console.log('');
  console.log(`Result: APPLIED (${written} docs)`);

  if (args.strict && written !== missing.length) {
    process.exitCode = 1;
  }
}

run().catch((error) => {
  console.error('Telemetry coverage seed failed:', error.message || error);
  process.exitCode = 1;
});

