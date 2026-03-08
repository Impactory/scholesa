const fs = require('fs');
const path = require('path');
const cp = require('child_process');

const REPO_ROOT = path.resolve(__dirname, '..', '..', '..');
const REPORT_DIR = path.join(REPO_ROOT, 'audit-pack', 'reports');
const VALID_AUDIT_ENVS = new Set(['dev', 'staging', 'prod']);

function ensureDir(dirPath) {
  fs.mkdirSync(dirPath, { recursive: true });
}

function readText(filePath) {
  return fs.readFileSync(filePath, 'utf8');
}

function readTextSafe(filePath) {
  if (!fs.existsSync(filePath)) return null;
  return fs.readFileSync(filePath, 'utf8');
}

function resolveExecShell() {
  if (process.platform === 'win32') {
    return process.env.ComSpec || 'cmd.exe';
  }
  if (typeof process.env.SHELL === 'string' && process.env.SHELL.trim()) {
    return process.env.SHELL.trim();
  }
  if (fs.existsSync('/bin/bash')) return '/bin/bash';
  return '/bin/sh';
}

function writeJson(filePath, payload) {
  ensureDir(path.dirname(filePath));
  fs.writeFileSync(filePath, JSON.stringify(payload, null, 2) + '\n', 'utf8');
}

function nowIso() {
  return new Date().toISOString();
}

function gitSha() {
  try {
    return cp.execSync('git rev-parse HEAD', {
      cwd: REPO_ROOT,
      stdio: ['ignore', 'pipe', 'ignore'],
      encoding: 'utf8',
    }).trim();
  } catch {
    return 'unknown';
  }
}

function resolveAuditEnv(rawValue) {
  const value = String(
    rawValue || process.env.VIBE_ENV || process.env.NODE_ENV || 'dev',
  ).trim().toLowerCase();
  return VALID_AUDIT_ENVS.has(value) ? value : 'dev';
}

function normalizeChecksArray(checks, fallbackId = 'check') {
  if (!Array.isArray(checks)) return [];
  return checks.map((check, index) => ({
    id:
      (typeof check?.id === 'string' && check.id) ||
      (typeof check?.checkId === 'string' && check.checkId) ||
      `${fallbackId}_${index + 1}`,
    pass:
      typeof check?.pass === 'boolean'
        ? check.pass
        : typeof check?.passed === 'boolean'
        ? check.passed
        : false,
    ...(check && typeof check === 'object' && check.details !== undefined
      ? { details: check.details }
      : {}),
  }));
}

function toCanonicalReport({
  reportName,
  passed,
  checks = [],
  generatedAt = nowIso(),
  legacy = {},
  env,
}) {
  return {
    ...legacy,
    reportName,
    generatedAt,
    gitSha: gitSha(),
    env: resolveAuditEnv(env),
    pass: Boolean(passed),
    // Compatibility with legacy consumers.
    passed: Boolean(passed),
    checks: normalizeChecksArray(checks, reportName),
  };
}

function reportPath(name) {
  return path.join(REPORT_DIR, `${name}.json`);
}

function relativeRepoPath(filePath) {
  return path.relative(REPO_ROOT, filePath);
}

function walkFiles(rootDir, opts = {}, out = []) {
  const excludeDirs = new Set(opts.excludeDirs || ['.git', 'node_modules', '.next', 'coverage', 'dist', 'build']);
  if (!fs.existsSync(rootDir)) return out;

  const entries = fs.readdirSync(rootDir, { withFileTypes: true });
  for (const entry of entries) {
    const fullPath = path.join(rootDir, entry.name);
    if (entry.isDirectory()) {
      if (excludeDirs.has(entry.name)) continue;
      walkFiles(fullPath, opts, out);
      continue;
    }

    if (opts.extensions) {
      const ext = path.extname(entry.name).toLowerCase();
      if (!opts.extensions.has(ext)) continue;
    }

    if (typeof opts.include === 'function') {
      const rel = relativeRepoPath(fullPath);
      if (!opts.include(fullPath, rel)) continue;
    }

    out.push(fullPath);
  }

  return out;
}

function lineMatches(content, regex) {
  const lines = content.split(/\r?\n/);
  const hits = [];
  for (let i = 0; i < lines.length; i += 1) {
    const line = lines[i];
    if (regex.test(line)) {
      hits.push({ line: i + 1, text: line.trim().slice(0, 240) });
    }
    regex.lastIndex = 0;
  }
  return hits;
}

module.exports = {
  REPO_ROOT,
  REPORT_DIR,
  VALID_AUDIT_ENVS,
  ensureDir,
  gitSha,
  lineMatches,
  normalizeChecksArray,
  nowIso,
  readText,
  readTextSafe,
  relativeRepoPath,
  resolveExecShell,
  resolveAuditEnv,
  reportPath,
  toCanonicalReport,
  walkFiles,
  writeJson,
};
