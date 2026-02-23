#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { finish } = require('./vibe_report_utils');

const BANNED_DEPENDENCY_MARKERS = [
  '@google/generative-ai',
  'google-genai',
  '@google-cloud/vertexai',
  'generativelanguage',
  'gemini',
];

const LOCKFILE_NAMES = new Set([
  'package.json',
  'package-lock.json',
  'pnpm-lock.yaml',
  'yarn.lock',
  'npm-shrinkwrap.json',
]);

function collectCandidateFiles(rootDir) {
  const files = [];

  function walk(dir) {
    const entries = fs.readdirSync(dir, { withFileTypes: true });
    for (const entry of entries) {
      const fullPath = path.join(dir, entry.name);
      if (entry.isDirectory()) {
        if (entry.name === '.git' || entry.name === 'node_modules' || entry.name === '.next') {
          continue;
        }
        walk(fullPath);
        continue;
      }
      if (LOCKFILE_NAMES.has(entry.name)) {
        files.push(fullPath);
      }
    }
  }

  walk(rootDir);
  return files;
}

function main() {
  const failures = [];
  const details = {
    scannedFiles: [],
    bannedDependencyMarkers: BANNED_DEPENDENCY_MARKERS,
    hits: [],
  };

  const files = collectCandidateFiles(process.cwd());
  for (const filePath of files) {
    const relativePath = path.relative(process.cwd(), filePath);
    details.scannedFiles.push(relativePath);

    const content = fs.readFileSync(filePath, 'utf8').toLowerCase();
    for (const marker of BANNED_DEPENDENCY_MARKERS) {
      if (content.includes(marker.toLowerCase())) {
        const hit = `${relativePath}:${marker}`;
        failures.push(`banned_dependency_marker:${hit}`);
        details.hits.push({ file: relativePath, marker });
      }
    }
  }

  finish('ai-dependency-ban', failures, details);
}

main();
