#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');

const ROOT = process.cwd();

const TARGETS = [
  'src/features/workflows',
  'app/[locale]/(protected)',
  'apps/empire_flutter/app/lib/modules',
  'apps/empire_flutter/app/lib/dashboards',
  'apps/empire_flutter/app/lib/router',
  'functions/src/workflowOps.ts',
];

const ALLOWED_EXTENSIONS = new Set(['.ts', '.tsx', '.js', '.jsx', '.dart']);

const CHECKS = [
  {
    id: 'todo_fixme',
    description: 'TODO/FIXME markers are not allowed in production workflow paths.',
    regex: /\b(?:TODO|FIXME)\b/g,
  },
  {
    id: 'mock_stub_fake_dummy',
    description: 'Mock/stub/fake/dummy markers are not allowed in production workflow paths.',
    regex: /\b(?:mock|stub|fake|dummy)\b/gi,
  },
  {
    id: 'synthetic_marker',
    description: 'Synthetic markers are not allowed in production workflow paths.',
    regex: /\bsynthetic\b/gi,
  },
  {
    id: 'template_id_from_time_or_random',
    description: 'ID generation from Date.now/Math.random/millisecondsSinceEpoch is not allowed.',
    regex: /`[^`]*(?:id|invoice|payment|flag|manual|local|inv)[^`]*\$\{[^}]*?(?:Date\.now\(|Math\.random\(|millisecondsSinceEpoch)[^}]*\}[^`]*`/g,
  },
  {
    id: 'id_assignment_from_time_or_random',
    description: 'ID assignment from Date.now/Math.random/millisecondsSinceEpoch is not allowed.',
    regex: /\bid\s*[:=][^\n]*(?:Date\.now\(|Math\.random\(|millisecondsSinceEpoch)/g,
  },
];

function walk(dirPath, sink) {
  const entries = fs.readdirSync(dirPath, { withFileTypes: true });
  for (const entry of entries) {
    if (entry.name === '.git' || entry.name === 'node_modules' || entry.name === 'build') {
      continue;
    }
    const fullPath = path.join(dirPath, entry.name);
    if (entry.isDirectory()) {
      walk(fullPath, sink);
      continue;
    }
    const ext = path.extname(entry.name);
    if (ALLOWED_EXTENSIONS.has(ext)) {
      sink.push(fullPath);
    }
  }
}

function collectTargetFiles() {
  const files = [];
  for (const target of TARGETS) {
    const absolute = path.resolve(ROOT, target);
    if (!fs.existsSync(absolute)) continue;
    const stat = fs.statSync(absolute);
    if (stat.isDirectory()) {
      walk(absolute, files);
    } else if (stat.isFile()) {
      const ext = path.extname(absolute);
      if (ALLOWED_EXTENSIONS.has(ext)) {
        files.push(absolute);
      }
    }
  }
  return files;
}

function toLine(source, index) {
  let line = 1;
  for (let i = 0; i < index; i += 1) {
    if (source.charCodeAt(i) === 10) line += 1;
  }
  return line;
}

function scanFile(filePath) {
  const source = fs.readFileSync(filePath, 'utf8');
  const violations = [];

  for (const check of CHECKS) {
    check.regex.lastIndex = 0;
    let match = check.regex.exec(source);
    while (match) {
      violations.push({
        checkId: check.id,
        description: check.description,
        line: toLine(source, match.index),
        snippet: match[0].slice(0, 140),
      });
      if (match.index === check.regex.lastIndex) {
        check.regex.lastIndex += 1;
      }
      match = check.regex.exec(source);
    }
  }

  return violations;
}

function main() {
  const files = collectTargetFiles();
  const findings = [];

  for (const file of files) {
    const fileFindings = scanFile(file);
    if (fileFindings.length === 0) continue;
    findings.push({
      file: path.relative(ROOT, file),
      violations: fileFindings,
    });
  }

  const summary = {
    status: findings.length === 0 ? 'PASS' : 'FAIL',
    scannedFileCount: files.length,
    findingCount: findings.reduce((sum, row) => sum + row.violations.length, 0),
    findings,
  };

  process.stdout.write(`${JSON.stringify(summary, null, 2)}\n`);

  if (findings.length > 0) {
    process.exitCode = 1;
  }
}

main();
