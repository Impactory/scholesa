#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const cp = require('child_process');

const REPORT_DIR = path.resolve(process.cwd(), 'audit-pack', 'reports');
const VALID_ENVS = new Set(['dev', 'staging', 'prod']);

function ensureReportDir() {
  fs.mkdirSync(REPORT_DIR, { recursive: true });
}

function reportPath(reportName) {
  return path.join(REPORT_DIR, `${reportName}.json`);
}

function nowIso() {
  return new Date().toISOString();
}

function gitSha() {
  try {
    return cp.execSync('git rev-parse HEAD', {
      cwd: process.cwd(),
      stdio: ['ignore', 'pipe', 'ignore'],
      encoding: 'utf8',
    }).trim();
  } catch {
    return 'unknown';
  }
}

function resolveEnv(raw) {
  const normalized = String(raw || '').trim().toLowerCase();
  if (VALID_ENVS.has(normalized)) return normalized;
  return 'dev';
}

function readJsonSafe(filePath) {
  try {
    if (!fs.existsSync(filePath)) return null;
    return JSON.parse(fs.readFileSync(filePath, 'utf8'));
  } catch {
    return null;
  }
}

function extractPass(report) {
  if (!report || typeof report !== 'object') return false;
  if (typeof report.pass === 'boolean') return report.pass;
  if (typeof report.passed === 'boolean') return report.passed;
  return false;
}

function normalizeCheck(check, index = 0) {
  if (!check || typeof check !== 'object') {
    return {
      id: `check_${index + 1}`,
      pass: false,
      details: { error: 'invalid_check_shape' },
    };
  }

  const id =
    typeof check.id === 'string' && check.id.trim()
      ? check.id.trim()
      : typeof check.checkId === 'string' && check.checkId.trim()
      ? check.checkId.trim()
      : `check_${index + 1}`;

  const pass =
    typeof check.pass === 'boolean'
      ? check.pass
      : typeof check.passed === 'boolean'
      ? check.passed
      : false;

  const normalized = {
    id,
    pass,
  };

  if (typeof check.name === 'string' && check.name.trim()) {
    normalized.name = check.name.trim();
  }

  if (check.details !== undefined) {
    normalized.details = check.details;
  } else if (check.findings !== undefined) {
    normalized.details = { findings: check.findings };
  }

  if (typeof check.evidencePath === 'string' && check.evidencePath.trim()) {
    normalized.evidencePath = check.evidencePath.trim();
  }

  return normalized;
}

function buildCanonicalReport({
  reportName,
  env,
  pass,
  checks = [],
  sourceReports = [],
  metadata = {},
  generatedAt,
  gitShaValue,
}) {
  const canonicalChecks = Array.isArray(checks)
    ? checks.map((check, index) => normalizeCheck(check, index))
    : [];

  const payload = {
    reportName,
    generatedAt: generatedAt || nowIso(),
    gitSha: gitShaValue || gitSha(),
    env: resolveEnv(env),
    pass: Boolean(pass),
    // Compatibility during migration from legacy report format.
    passed: Boolean(pass),
    checks: canonicalChecks,
  };

  if (Array.isArray(sourceReports) && sourceReports.length > 0) {
    payload.sourceReports = sourceReports;
  }

  if (metadata && typeof metadata === 'object' && Object.keys(metadata).length > 0) {
    payload.metadata = metadata;
  }

  return payload;
}

function writeCanonicalReport(reportName, report) {
  ensureReportDir();
  const filePath = reportPath(reportName);
  fs.writeFileSync(filePath, JSON.stringify(report, null, 2) + '\n', 'utf8');
  return filePath;
}

function validateCanonicalReport(report) {
  const errors = [];

  if (!report || typeof report !== 'object') {
    return {
      ok: false,
      errors: ['report_not_object'],
    };
  }

  if (typeof report.reportName !== 'string' || !report.reportName.trim()) {
    errors.push('missing_reportName');
  }

  if (typeof report.generatedAt !== 'string' || Number.isNaN(Date.parse(report.generatedAt))) {
    errors.push('missing_or_invalid_generatedAt');
  }

  if (typeof report.gitSha !== 'string' || !report.gitSha.trim()) {
    errors.push('missing_gitSha');
  }

  if (typeof report.env !== 'string' || !VALID_ENVS.has(report.env)) {
    errors.push('missing_or_invalid_env');
  }

  if (typeof report.pass !== 'boolean' && typeof report.passed !== 'boolean') {
    errors.push('missing_pass_or_passed_boolean');
  }

  if (!Array.isArray(report.checks)) {
    errors.push('missing_checks_array');
  } else {
    report.checks.forEach((check, index) => {
      if (!check || typeof check !== 'object') {
        errors.push(`check_${index}_not_object`);
        return;
      }
      if (typeof check.id !== 'string' || !check.id.trim()) {
        errors.push(`check_${index}_missing_id`);
      }
      if (typeof check.pass !== 'boolean') {
        errors.push(`check_${index}_missing_pass_boolean`);
      }
    });
  }

  return {
    ok: errors.length === 0,
    errors,
  };
}

function legacyFailuresToChecks(failures) {
  if (!Array.isArray(failures) || failures.length === 0) {
    return [
      {
        id: 'legacy_failures',
        pass: true,
        details: { failures: [] },
      },
    ];
  }

  return failures.map((failure, index) => ({
    id: `legacy_failure_${index + 1}`,
    pass: false,
    details: { failure },
  }));
}

module.exports = {
  REPORT_DIR,
  VALID_ENVS,
  buildCanonicalReport,
  ensureReportDir,
  extractPass,
  gitSha,
  legacyFailuresToChecks,
  readJsonSafe,
  reportPath,
  resolveEnv,
  validateCanonicalReport,
  writeCanonicalReport,
};
