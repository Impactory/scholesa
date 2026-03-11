#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { finish } = require('./vibe_report_utils');
const { walkProjectFiles, lineHits } = require('./ai_policy_common');

const TEXT_EXTENSIONS = new Set([
  '.ts', '.tsx', '.js', '.jsx', '.mjs', '.cjs',
  '.json', '.yaml', '.yml', '.sh', '.py', '.toml', '.ini', '.cfg', '.conf', '.txt',
]);

const BANNED_PATTERNS = [
  { label: 'generativelanguage.googleapis.com', regex: /generativelanguage\.googleapis\.com/i },
  { label: 'ai.google.dev', regex: /ai\.google\.dev/i },
  { label: 'vertexai.googleapis.com', regex: /vertexai\.googleapis\.com/i },
  { label: 'aiplatform.googleapis.com', regex: /aiplatform\.googleapis\.com/i },
  { label: 'gemini-tts docs reference', regex: /text-to-speech\/docs\/gemini-tts/i },
  { label: 'gemini keyword', regex: /\bgemini\b/i },
];

const POLICY_FILE_ALLOWLIST = new Set([
  'scripts/ai_dependency_ban.js',
  'scripts/ai_import_ban.js',
  'scripts/ai_domain_ban.js',
  'scripts/ai_egress_none.js',
  'scripts/ai_policy_common.js',
  'src/lib/ai/egressGuard.ts',
  'functions/src/security/egressGuard.ts',
  'services/scholesa-compliance/src/checks/vendorDependencyBan.js',
  'services/scholesa-compliance/src/checks/vendorDomainBan.js',
  'services/scholesa-compliance/src/checks/vendorSecretBan.js',
  'services/scholesa-compliance/src/checks/runtimeEgressProof.js',
]);

function includeByName(fullPath, relativePath) {
  if (POLICY_FILE_ALLOWLIST.has(relativePath)) return false;
  // Compliance scanners intentionally contain banned markers for detection logic.
  if (relativePath.startsWith('scripts/compliance/')) return false;
  if (relativePath === 'scripts/scan.sh') return false;
  // Ignore generated iOS Ruby/Bundler trees. They are tooling artifacts, not app runtime code.
  if (relativePath.startsWith('apps/empire_flutter/app/ios/vendor/')) return false;
  if (relativePath.startsWith('apps/empire_flutter/app/ios/.bundle/')) return false;
  const base = path.basename(fullPath);
  if (base.startsWith('.env')) return true;
  if (base === 'Dockerfile' || base === 'dockerfile') return true;
  if (base === 'firebase.json' || base === 'firestore.rules' || base === 'firestore.indexes.json') return true;
  const ext = path.extname(fullPath);
  if (!TEXT_EXTENSIONS.has(ext)) return false;
  if (relativePath.includes('/.firebase/')) return false;
  if (relativePath.startsWith('audit-pack/')) return false;
  return true;
}

function isWhitelistedDocsPath(relativePath) {
  return relativePath.startsWith('docs/archive/') || relativePath.startsWith('docs/vendor-analysis/');
}

function main() {
  const failures = [];
  const details = {
    scannedFileCount: 0,
    bannedPatterns: BANNED_PATTERNS.map((p) => p.label),
    runtimeHits: [],
    docHits: [],
    docsWhitelist: ['docs/archive/**', 'docs/vendor-analysis/**'],
  };

  const files = walkProjectFiles(process.cwd(), {
    includePredicate: includeByName,
  });

  details.scannedFileCount = files.length;

  for (const filePath of files) {
    const relativePath = path.relative(process.cwd(), filePath);
    const content = fs.readFileSync(filePath, 'utf8');

    for (const pattern of BANNED_PATTERNS) {
      const hits = lineHits(content, pattern.regex);
      for (const hit of hits) {
        const hitRecord = {
          file: relativePath,
          line: hit.line,
          pattern: pattern.label,
          snippet: hit.text,
        };

        if (relativePath.startsWith('docs/')) {
          if (isWhitelistedDocsPath(relativePath)) continue;
          details.docHits.push(hitRecord);
          failures.push(`docs_policy_violation:${relativePath}:${hit.line}:${pattern.label}`);
        } else {
          details.runtimeHits.push(hitRecord);
          failures.push(`banned_domain_or_keyword:${relativePath}:${hit.line}:${pattern.label}`);
        }
      }
    }
  }

  finish('ai-domain-ban', failures, details);
}

main();
