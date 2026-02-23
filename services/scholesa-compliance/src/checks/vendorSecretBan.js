const fs = require('fs');
const path = require('path');
const { REPO_ROOT, reportPath, writeJson, nowIso, walkFiles, relativeRepoPath, lineMatches } = require('../utils');

const SECRET_BAN_PATTERNS = [
  { label: 'GEMINI_API_KEY', regex: /GEMINI_API_KEY/i },
  { label: 'GOOGLE_GENERATIVE_AI', regex: /GOOGLE_GENERATIVE_AI/i },
  { label: 'GENAI_API_KEY', regex: /GENAI_API_KEY/i },
  { label: 'AI_GOOGLE_DEV_KEY', regex: /AI_GOOGLE_DEV_KEY/i },
];

const TEXT_EXTENSIONS = new Set(['.env', '.yaml', '.yml', '.json', '.ts', '.tsx', '.js', '.jsx', '.mjs', '.cjs', '.md', '.txt']);

function shouldInclude(fullPath, relPath) {
  if (relPath.startsWith('node_modules/')) return false;
  if (relPath.startsWith('.git/')) return false;
  if (relPath.startsWith('audit-pack/reports/')) return false;
  const base = path.basename(fullPath);
  if (base.startsWith('.env')) return true;
  if (base.includes('cloudbuild') || base.includes('workflow')) return true;
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
