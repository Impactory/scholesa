#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

const DEFAULT_EXCLUDE_DIRS = new Set([
  '.git',
  'node_modules',
  '.next',
  'dist',
  'build',
  'coverage',
  'lib',
  'audit-pack',
]);

function walkProjectFiles(rootDir, options = {}) {
  const {
    includeExtensions = null,
    excludeDirs = DEFAULT_EXCLUDE_DIRS,
    includePredicate = null,
  } = options;

  const out = [];

  function visit(currentDir) {
    if (!fs.existsSync(currentDir)) return;
    const entries = fs.readdirSync(currentDir, { withFileTypes: true });
    for (const entry of entries) {
      const fullPath = path.join(currentDir, entry.name);
      const relPath = path.relative(process.cwd(), fullPath);
      if (entry.isDirectory()) {
        if (excludeDirs.has(entry.name)) continue;
        visit(fullPath);
        continue;
      }
      if (includeExtensions && !includeExtensions.has(path.extname(entry.name))) {
        continue;
      }
      if (includePredicate && !includePredicate(fullPath, relPath)) {
        continue;
      }
      out.push(fullPath);
    }
  }

  visit(rootDir);
  return out;
}

function lineHits(content, regex) {
  const hits = [];
  const lines = content.split(/\r?\n/);
  for (let i = 0; i < lines.length; i += 1) {
    const line = lines[i];
    if (regex.test(line)) {
      hits.push({
        line: i + 1,
        text: line.trim().slice(0, 220),
      });
    }
    regex.lastIndex = 0;
  }
  return hits;
}

function readIfExists(filePath) {
  if (!fs.existsSync(filePath)) return null;
  return fs.readFileSync(filePath, 'utf8');
}

module.exports = {
  DEFAULT_EXCLUDE_DIRS,
  lineHits,
  readIfExists,
  walkProjectFiles,
};
