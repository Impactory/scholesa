#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { finish } = require('./vibe_report_utils');
const { walkProjectFiles, lineHits } = require('./ai_policy_common');

const CODE_EXTENSIONS = new Set(['.ts', '.tsx', '.js', '.jsx', '.mjs', '.cjs']);

const BANNED_IMPORT_PATTERNS = [
  { label: '@google/generative-ai import', regex: /(?:from|require\()\s*['"]@google\/generative-ai['"]/i },
  { label: 'google-genai import', regex: /(?:from|require\()\s*['"]google-genai['"]/i },
  { label: '@google-cloud/vertexai import', regex: /(?:from|require\()\s*['"]@google-cloud\/vertexai['"]/i },
  { label: 'GenerativeModel symbol', regex: /\bGenerativeModel\b/i },
  { label: 'Gemini symbol', regex: /\bGemini\b/i },
  { label: 'generativelanguage symbol', regex: /generativelanguage/i },
];

function shouldInclude(_fullPath, relativePath) {
  if (relativePath.startsWith('docs/')) return false;
  if (relativePath.startsWith('audit-pack/')) return false;
  if (relativePath.startsWith('scripts/ai_')) return false;
  if (relativePath.endsWith('.d.ts')) return false;
  return true;
}

function main() {
  const failures = [];
  const details = {
    scannedFileCount: 0,
    bannedPatterns: BANNED_IMPORT_PATTERNS.map((p) => p.label),
    hits: [],
  };

  const files = walkProjectFiles(process.cwd(), {
    includeExtensions: CODE_EXTENSIONS,
    includePredicate: shouldInclude,
  });

  details.scannedFileCount = files.length;

  for (const filePath of files) {
    const relativePath = path.relative(process.cwd(), filePath);
    const content = fs.readFileSync(filePath, 'utf8');

    for (const pattern of BANNED_IMPORT_PATTERNS) {
      const hits = lineHits(content, pattern.regex);
      for (const hit of hits) {
        failures.push(`banned_import:${relativePath}:${hit.line}:${pattern.label}`);
        details.hits.push({
          file: relativePath,
          line: hit.line,
          pattern: pattern.label,
          snippet: hit.text,
        });
      }
    }
  }

  finish('ai-import-ban', failures, details);
}

main();
