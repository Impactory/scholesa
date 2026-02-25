#!/usr/bin/env node
'use strict';

const fs = require('node:fs');
const path = require('node:path');
const cp = require('node:child_process');
const admin = require('firebase-admin');
const {
  buildCanonicalReport,
  resolveEnv,
  reportPath,
  writeCanonicalReport,
} = require('./vibe_audit_report_schema');

const SINGLE_AUDIT_SCRIPT = path.resolve(__dirname, 'audit_firebase_ui_field_wiring.js');
const DEFAULT_SITE_LIMIT = Number(process.env.FIREBASE_UI_FIELD_AUDIT_SITE_LIMIT || 30);
const DEFAULT_REPORT_NAME = 'firebase-ui-field-wiring-bulk';

const SERVICE_ACCOUNT_PATHS = [
  process.env.GOOGLE_APPLICATION_CREDENTIALS,
  path.resolve(process.cwd(), 'firebase-service-account.json'),
  path.resolve(process.cwd(), 'studio-service-account.json'),
].filter(Boolean);

function parseArgs(argv) {
  const args = {
    env: resolveEnv(process.env.VIBE_ENV || process.env.NODE_ENV || 'prod'),
    strict: false,
    includeInactive: false,
    siteLimit: Number.isFinite(DEFAULT_SITE_LIMIT) && DEFAULT_SITE_LIMIT > 0 ? DEFAULT_SITE_LIMIT : 30,
    siteIds: [],
    reportName: DEFAULT_REPORT_NAME,
  };

  for (const arg of argv) {
    if (arg === '--strict') {
      args.strict = true;
      continue;
    }
    if (arg === '--include-inactive') {
      args.includeInactive = true;
      continue;
    }
    if (!arg.startsWith('--')) continue;
    const [rawKey, rawValue] = arg.slice(2).split('=');
    if (rawValue === undefined) continue;

    if (rawKey === 'env') args.env = resolveEnv(rawValue);
    if (rawKey === 'site-limit' || rawKey === 'siteLimit') {
      const parsedLimit = Number(rawValue);
      if (Number.isFinite(parsedLimit) && parsedLimit > 0) {
        args.siteLimit = Math.floor(parsedLimit);
      }
    }
    if (rawKey === 'site-ids' || rawKey === 'siteIds') {
      args.siteIds = rawValue
        .split(',')
        .map((value) => value.trim())
        .filter(Boolean);
    }
    if (rawKey === 'report-name' || rawKey === 'reportName') {
      const cleaned = rawValue.trim();
      if (cleaned) args.reportName = cleaned;
    }
  }

  return args;
}

function resolveServiceAccount() {
  for (const candidate of SERVICE_ACCOUNT_PATHS) {
    if (!candidate) continue;
    if (!fs.existsSync(candidate)) continue;
    return {
      credentialPath: candidate,
      json: JSON.parse(fs.readFileSync(candidate, 'utf8')),
    };
  }
  throw new Error(`No service account JSON found. Checked: ${SERVICE_ACCOUNT_PATHS.join(', ')}`);
}

function initializeAdmin() {
  const serviceAccount = resolveServiceAccount();
  if (!admin.apps.length) {
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount.json),
      projectId: serviceAccount.json.project_id,
    });
  }
  return {
    db: admin.firestore(),
    credentialPath: path.relative(process.cwd(), serviceAccount.credentialPath),
    projectId: serviceAccount.json.project_id,
  };
}

function sanitizeFileSegment(input) {
  return String(input || '')
    .trim()
    .replace(/[^A-Za-z0-9._-]+/g, '_')
    .replace(/^_+|_+$/g, '');
}

function extractFailedChecks(report) {
  if (!report || !Array.isArray(report.checks)) return [];
  return report.checks
    .filter((check) => check && typeof check === 'object' && check.pass === false)
    .map((check) => String(check.id || '').trim())
    .filter(Boolean);
}

async function discoverSiteIds(db, args) {
  if (Array.isArray(args.siteIds) && args.siteIds.length > 0) {
    return Array.from(new Set(args.siteIds));
  }

  const snapshot = await db.collection('sites').limit(args.siteLimit).get();
  const siteIds = [];
  for (const doc of snapshot.docs) {
    const data = doc.data() || {};
    const status = typeof data.status === 'string' ? data.status.trim().toLowerCase() : 'active';
    if (!args.includeInactive && status === 'inactive') continue;
    siteIds.push(doc.id);
  }
  return Array.from(new Set(siteIds));
}

function runSingleAudit(siteId, args) {
  const commandArgs = [
    SINGLE_AUDIT_SCRIPT,
    `--env=${args.env}`,
    '--strict',
    `--site-id=${siteId}`,
  ];
  const result = cp.spawnSync('node', commandArgs, {
    cwd: process.cwd(),
    encoding: 'utf8',
    stdio: 'pipe',
  });

  const genericReportPath = reportPath('firebase-ui-field-wiring');
  const generatedReport = fs.existsSync(genericReportPath)
    ? JSON.parse(fs.readFileSync(genericReportPath, 'utf8'))
    : null;

  const safeSiteId = sanitizeFileSegment(siteId);
  const siteReportName = `firebase-ui-field-wiring.${safeSiteId}`;
  const siteReportPath = reportPath(siteReportName);
  if (generatedReport) {
    fs.writeFileSync(siteReportPath, JSON.stringify(generatedReport, null, 2) + '\n', 'utf8');
  }

  const failedChecks = extractFailedChecks(generatedReport);
  const passFromReport = Boolean(generatedReport && (generatedReport.pass === true || generatedReport.passed === true));
  const pass = result.status === 0 && passFromReport;

  return {
    siteId,
    pass,
    failedChecks,
    exitCode: result.status,
    stdoutTail: String(result.stdout || '').trim().split('\n').slice(-6),
    stderrTail: String(result.stderr || '').trim().split('\n').slice(-6),
    reportPath: path.relative(process.cwd(), siteReportPath),
    counts: generatedReport?.metadata?.counts || null,
  };
}

async function run() {
  const args = parseArgs(process.argv.slice(2));
  const { db, credentialPath, projectId } = initializeAdmin();
  const siteIds = await discoverSiteIds(db, args);

  if (siteIds.length === 0) {
    throw new Error('No siteIds resolved for bulk audit.');
  }

  const checks = [];
  const siteResults = [];

  for (const siteId of siteIds) {
    const result = runSingleAudit(siteId, args);
    siteResults.push(result);
    checks.push({
      id: `site_${sanitizeFileSegment(siteId)}_firebase_ui_field_wiring`,
      pass: result.pass,
      details: {
        siteId: result.siteId,
        exitCode: result.exitCode,
        failedChecks: result.failedChecks,
        reportPath: result.reportPath,
        counts: result.counts,
      },
    });
  }

  const pass = checks.every((check) => check.pass === true);
  const report = buildCanonicalReport({
    reportName: args.reportName,
    env: args.env,
    pass,
    checks,
    metadata: {
      siteCount: siteIds.length,
      auditedSiteIds: siteIds,
      includeInactive: args.includeInactive,
      siteLimit: args.siteLimit,
      strict: args.strict,
      projectId,
      credentialPath,
      siteResults,
    },
  });

  const outputPath = writeCanonicalReport(args.reportName, report);
  const output = {
    status: pass ? 'PASS' : 'FAIL',
    env: args.env,
    report: path.relative(process.cwd(), outputPath),
    auditedSites: siteIds.length,
    failedSites: siteResults.filter((result) => !result.pass).map((result) => result.siteId),
  };
  process.stdout.write(JSON.stringify(output, null, 2) + '\n');

  if (!pass) {
    process.exitCode = 1;
  }
}

run().catch((error) => {
  process.stderr.write(
    JSON.stringify(
      {
        status: 'FAIL',
        error: error instanceof Error ? error.message : String(error),
      },
      null,
      2,
    ) + '\n',
  );
  process.exit(1);
});
