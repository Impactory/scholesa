#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const cp = require('child_process');

const REPORT_DIR = path.resolve(process.cwd(), 'audit-pack/reports');

function ensureReportDir() {
  fs.mkdirSync(REPORT_DIR, { recursive: true });
}

function gitSha() {
  try {
    return cp.execSync('git rev-parse HEAD', { stdio: ['ignore', 'pipe', 'ignore'] }).toString().trim();
  } catch {
    return 'unknown';
  }
}

function runId() {
  return process.env.VIBE_RUN_ID || `${Date.now()}`;
}

function environment() {
  return process.env.VIBE_ENV || process.env.NODE_ENV || 'local';
}

function writeReport(reportName, payload) {
  ensureReportDir();
  const base = {
    gitSha: gitSha(),
    runId: runId(),
    timestamp: new Date().toISOString(),
    environment: environment(),
  };
  const merged = { ...base, ...payload };
  const filePath = path.join(REPORT_DIR, `${reportName}.json`);
  fs.writeFileSync(filePath, JSON.stringify(merged, null, 2) + '\n', 'utf8');
  return filePath;
}

function finish(reportName, failures, details = {}, warnings = []) {
  const failed = failures.length > 0;
  const reportPath = writeReport(reportName, {
    passed: !failed,
    failures,
    warnings,
    ...details,
  });
  process.stdout.write(`${failed ? 'FAIL' : 'PASS'} ${reportName} -> ${reportPath}\n`);
  if (failed) process.exitCode = 1;
  return { failed, reportPath };
}

function walkFiles(rootDir, predicate, out = []) {
  if (!fs.existsSync(rootDir)) return out;
  const entries = fs.readdirSync(rootDir, { withFileTypes: true });
  for (const entry of entries) {
    const fullPath = path.join(rootDir, entry.name);
    if (entry.isDirectory()) {
      walkFiles(fullPath, predicate, out);
      continue;
    }
    if (predicate(fullPath)) out.push(fullPath);
  }
  return out;
}

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, 'utf8'));
}

function flattenKeys(obj, prefix = '', keys = []) {
  for (const [key, value] of Object.entries(obj || {})) {
    const next = prefix ? `${prefix}.${key}` : key;
    if (value && typeof value === 'object' && !Array.isArray(value)) {
      flattenKeys(value, next, keys);
    } else {
      keys.push(next);
    }
  }
  return keys.sort((a, b) => a.localeCompare(b));
}

module.exports = {
  REPORT_DIR,
  finish,
  flattenKeys,
  readJson,
  walkFiles,
  writeReport,
};

