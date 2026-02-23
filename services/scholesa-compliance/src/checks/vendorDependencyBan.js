const fs = require('fs');
const path = require('path');
const { REPO_ROOT, reportPath, writeJson, nowIso, walkFiles, relativeRepoPath } = require('../utils');

const BANNED_DEPENDENCIES = [
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

function runVendorDependencyBan() {
  const lockfiles = walkFiles(REPO_ROOT, {
    include: (fullPath) => LOCKFILE_NAMES.has(path.basename(fullPath)),
  });

  const findings = [];
  const hits = [];

  for (const filePath of lockfiles) {
    const rel = relativeRepoPath(filePath);
    if (rel.startsWith('node_modules/')) continue;
    const content = fs.readFileSync(filePath, 'utf8').toLowerCase();
    for (const marker of BANNED_DEPENDENCIES) {
      if (content.includes(marker.toLowerCase())) {
        hits.push({ file: rel, marker });
        findings.push(`banned dependency marker '${marker}' in ${rel}`);
      }
    }
  }

  const passed = findings.length === 0;
  const report = {
    report: 'vendor-dependency-ban',
    generatedAt: nowIso(),
    passed,
    bannedDependencies: BANNED_DEPENDENCIES,
    scannedFiles: lockfiles.map(relativeRepoPath).filter((p) => !p.startsWith('node_modules/')),
    hits,
    findings,
  };

  const outputPath = reportPath('vendor-dependency-ban');
  writeJson(outputPath, report);

  return {
    checkId: 'vendor_dependency_ban',
    passed,
    findings,
    evidencePath: outputPath,
    details: {
      scannedFiles: report.scannedFiles.length,
      hitCount: hits.length,
    },
  };
}

module.exports = {
  runVendorDependencyBan,
};
