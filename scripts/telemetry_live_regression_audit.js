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
const UNMAPPED_SITE_ID = 'unscoped';

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

  const eventCounts = new Map();
  const roleCounts = new Map();
  const schemaErrors = [];
  const correlationErrors = [];
  const tenantTagErrors = [];
  const piiKeyErrors = [];
  const unknownEventCounts = new Map();

  const allowedEventSet = new Set(registries.backendAllowedEvents);

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

  const missingRequiredLiveCoverage = registries.canonicalRequiredEvents.filter(
    (event) => !eventCounts.has(event),
  );

  return {
    docsScanned: snapshot.docs.length,
    docsAfterSiteFilter: docs.length,
    distinctEventsSeen: eventCounts.size,
    eventCounts,
    roleCounts,
    missingRequiredLiveCoverage,
    schemaErrors,
    correlationErrors,
    tenantTagErrors,
    piiKeyErrors,
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
    `distinctEventsSeen=${live.distinctEventsSeen}`,
  ]);

  printMapSection('Live Role Counts', live.roleCounts);
  printMapSection('Live Unknown Event Counts', live.unknownEventCounts);

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
