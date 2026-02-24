#!/usr/bin/env node
'use strict';

const path = require('path');
const {
  buildCanonicalReport,
  extractPass,
  readJsonSafe,
  reportPath,
  resolveEnv,
  validateCanonicalReport,
  writeCanonicalReport,
} = require('./vibe_audit_report_schema');

const REQUIRED_BLOCKERS = [
  'vendor-dependency-ban',
  'vendor-domain-ban',
  'vendor-secret-ban',
  'vendor-egress-proof',
  'tenant-isolation',
  'safety-fixtures',
  'voice-retention-ttl',
  'logging-no-raw-content',
  'telemetry-schema-valid',
  'inference-authz',
  'inference-ingress-private',
  'infra-drift',
  'i18n-coverage',
];

function parseArgs(argv) {
  const args = {
    env: process.env.VIBE_ENV || process.env.NODE_ENV || 'dev',
    strict: false,
  };

  for (const arg of argv) {
    if (arg === '--strict') {
      args.strict = true;
      continue;
    }
    if (!arg.startsWith('--')) continue;
    const [rawKey, rawValue] = arg.slice(2).split('=');
    if (rawValue === undefined) continue;
    if (rawKey === 'env') args.env = rawValue;
  }

  args.env = resolveEnv(args.env);
  return args;
}

function main() {
  const args = parseArgs(process.argv.slice(2));

  const checks = [];

  for (const reportName of REQUIRED_BLOCKERS) {
    const filePath = reportPath(reportName);
    const report = readJsonSafe(filePath);

    if (!report) {
      checks.push({
        id: `blocker_${reportName}`,
        pass: false,
        details: {
          reason: 'missing_report_file',
          filePath: path.relative(process.cwd(), filePath),
        },
      });
      continue;
    }

    const schema = validateCanonicalReport(report);
    const pass = extractPass(report);

    checks.push({
      id: `blocker_${reportName}`,
      pass: schema.ok && pass,
      details: {
        filePath: path.relative(process.cwd(), filePath),
        schemaOk: schema.ok,
        reportPass: pass,
        errors: schema.errors,
      },
    });
  }

  const allPassed = checks.every((check) => check.pass);

  const gateReport = buildCanonicalReport({
    reportName: 'vibe-ci-blocker-gate',
    env: args.env,
    pass: allPassed,
    checks,
    metadata: {
      requiredBlockers: REQUIRED_BLOCKERS,
    },
  });

  const outputPath = writeCanonicalReport('vibe-ci-blocker-gate', gateReport);

  const output = {
    status: allPassed ? 'PASS' : 'FAIL',
    report: path.relative(process.cwd(), outputPath),
    failedChecks: checks.filter((check) => !check.pass).map((check) => check.id),
  };

  process.stdout.write(JSON.stringify(output, null, 2) + '\n');

  if (!allPassed && args.strict) {
    process.exitCode = 1;
  } else if (!allPassed) {
    process.exitCode = 1;
  }
}

main();
