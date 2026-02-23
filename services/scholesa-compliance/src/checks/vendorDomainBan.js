const fs = require('fs');
const path = require('path');
const { REPO_ROOT, reportPath, writeJson, nowIso, walkFiles, relativeRepoPath, lineMatches } = require('../utils');

const BANNED_PATTERNS = [
  { label: 'generativelanguage.googleapis.com', regex: /generativelanguage\.googleapis\.com/i },
  { label: 'ai.google.dev', regex: /ai\.google\.dev/i },
  { label: 'vertexai.googleapis.com', regex: /vertexai\.googleapis\.com/i },
  { label: 'aiplatform.googleapis.com', regex: /aiplatform\.googleapis\.com/i },
  { label: 'gemini keyword', regex: /\bgemini\b/i },
  { label: 'gemini-tts docs reference', regex: /text-to-speech\/docs\/gemini-tts/i },
];

const TEXT_EXTENSIONS = new Set([
  '.ts', '.tsx', '.js', '.jsx', '.mjs', '.cjs', '.json', '.yaml', '.yml', '.sh', '.py', '.toml', '.ini', '.cfg', '.conf', '.txt',
]);

const SCANNER_ALLOWLIST = new Set([
  'services/scholesa-compliance/src/checks/vendorDomainBan.js',
  'services/scholesa-compliance/src/checks/vendorDependencyBan.js',
  'services/scholesa-compliance/src/checks/runtimeEgressProof.js',
  'src/lib/ai/egressGuard.ts',
  'functions/src/security/egressGuard.ts',
  'scripts/ai_dependency_ban.js',
  'scripts/ai_import_ban.js',
  'scripts/ai_domain_ban.js',
  'scripts/ai_egress_none.js',
]);

function shouldInclude(fullPath, relPath) {
  if (relPath.startsWith('node_modules/')) return false;
  if (relPath.startsWith('.git/')) return false;
  if (relPath.startsWith('audit-pack/reports/')) return false;
  if (SCANNER_ALLOWLIST.has(relPath)) return false;
  const ext = path.extname(fullPath).toLowerCase();
  if (TEXT_EXTENSIONS.has(ext)) return true;
  const base = path.basename(fullPath);
  if (base.startsWith('.env')) return true;
  if (base === 'Dockerfile' || base === 'firebase.json' || base === 'firestore.rules' || base === 'storage.rules') return true;
  return false;
}

function runVendorDomainBan() {
  const files = walkFiles(REPO_ROOT, {
    include: shouldInclude,
  });

  const findings = [];
  const hits = [];

  for (const filePath of files) {
    const rel = relativeRepoPath(filePath);
    const content = fs.readFileSync(filePath, 'utf8');

    for (const pattern of BANNED_PATTERNS) {
      const matches = lineMatches(content, pattern.regex);
      for (const match of matches) {
        hits.push({ file: rel, line: match.line, pattern: pattern.label, snippet: match.text });
        findings.push(`${pattern.label} in ${rel}:${match.line}`);
      }
    }
  }

  const passed = findings.length === 0;
  const report = {
    report: 'vendor-domain-ban',
    generatedAt: nowIso(),
    passed,
    bannedPatterns: BANNED_PATTERNS.map((p) => p.label),
    scannedFiles: files.map(relativeRepoPath),
    hits,
    findings,
  };

  const outputPath = reportPath('vendor-domain-ban');
  writeJson(outputPath, report);

  return {
    checkId: 'vendor_domain_ban',
    passed,
    findings,
    evidencePath: outputPath,
    details: {
      scannedFiles: files.length,
      hitCount: hits.length,
    },
  };
}

module.exports = {
  runVendorDomainBan,
};
