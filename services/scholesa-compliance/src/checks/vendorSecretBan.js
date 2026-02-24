const fs = require('fs');
const path = require('path');
const { REPO_ROOT, reportPath, writeJson, nowIso, walkFiles, relativeRepoPath, lineMatches } = require('../utils');

const SECRET_BAN_PATTERNS = [
  { label: 'GEMINI_API_KEY', regex: /\bGEMINI_API_KEY\b/i },
  { label: 'GOOGLE_GENERATIVE_AI', regex: /\bGOOGLE_GENERATIVE_AI\b/i },
  { label: 'GENAI_API_KEY', regex: /\bGENAI_API_KEY\b/i },
  { label: 'AI_GOOGLE_DEV_KEY', regex: /\bAI_GOOGLE_DEV_KEY\b/i },
];

const TEXT_EXTENSIONS = new Set(['.env', '.yaml', '.yml', '.json', '.ts', '.tsx', '.js', '.jsx', '.mjs', '.cjs', '.sh']);

const FILE_ALLOWLIST = new Set([
  'services/scholesa-compliance/src/checks/vendorSecretBan.js',
  'scripts/ai_egress_none.js',
  'scripts/compliance/ai_policy_gates.mjs',
]);

function shouldInclude(fullPath, relPath) {
  if (relPath.startsWith('.git/')) return false;
  if (relPath.startsWith('node_modules/')) return false;
  if (relPath.startsWith('docs/')) return false;
  if (relPath.startsWith('audit-pack/')) return false;
  if (relPath.startsWith('functions/lib/')) return false;
  if (relPath.includes('/.dart_tool/')) return false;
  if (relPath.includes('/ios/Pods/')) return false;
  if (relPath.includes('/macos/Pods/')) return false;
  if (FILE_ALLOWLIST.has(relPath)) return false;

  const base = path.basename(fullPath);
  if (base.startsWith('.env')) return true;
  if (base === 'firebase.json' || base === '.firebaserc') return true;
  if (base.toLowerCase().includes('cloudbuild')) return true;
  if (relPath.startsWith('.github/workflows/')) return true;

  const ext = path.extname(fullPath).toLowerCase();
  return TEXT_EXTENSIONS.has(ext);
}

function runVendorSecretBan() {
  const files = walkFiles(REPO_ROOT, {
    include: shouldInclude,
  });

  const hits = [];
  const findings = [];

  for (const filePath of files) {
    const rel = relativeRepoPath(filePath);
    const content = fs.readFileSync(filePath, 'utf8');
    for (const pattern of SECRET_BAN_PATTERNS) {
      const matches = lineMatches(content, pattern.regex);
      for (const match of matches) {
        hits.push({ file: rel, line: match.line, pattern: pattern.label, snippet: match.text });
        findings.push(`${pattern.label} reference found in ${rel}:${match.line}`);
      }
    }
  }

  const passed = findings.length === 0;
  const report = {
    report: 'vendor-secret-ban',
    generatedAt: nowIso(),
    passed,
    bannedSecretPatterns: SECRET_BAN_PATTERNS.map((p) => p.label),
    scannedFiles: files.map(relativeRepoPath),
    hits,
    findings,
  };

  const outputPath = reportPath('vendor-secret-ban');
  writeJson(outputPath, report);

  return {
    checkId: 'vendor_secret_ban',
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
  runVendorSecretBan,
};
