const fs = require('fs');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..', '..', '..');
const REPORT_DIR = path.join(REPO_ROOT, 'audit-pack', 'reports');

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

function writeJson(filePath, payload) {
  ensureDir(path.dirname(filePath));
  fs.writeFileSync(filePath, JSON.stringify(payload, null, 2) + '\n', 'utf8');
}

function nowIso() {
  return new Date().toISOString();
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
  ensureDir,
  lineMatches,
  nowIso,
  readText,
  readTextSafe,
  relativeRepoPath,
  reportPath,
  walkFiles,
  writeJson,
};
