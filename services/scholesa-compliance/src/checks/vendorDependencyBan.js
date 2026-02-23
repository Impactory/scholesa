const path = require('path');
const cp = require('child_process');
const { REPO_ROOT, reportPath, writeJson, nowIso, readTextSafe } = require('../utils');

function readAiDependencyReport() {
  const reportFile = path.join(REPO_ROOT, 'audit-pack/reports/ai-dependency-ban.json');
  const raw = readTextSafe(reportFile);
  if (raw) {
    try {
      return JSON.parse(raw);
    } catch {
      // Fall through to rerun below.
    }
  }

  try {
    cp.execSync('node scripts/ai_dependency_ban.js', {
      cwd: REPO_ROOT,
      stdio: 'pipe',
      encoding: 'utf8',
      maxBuffer: 1024 * 1024 * 16,
      shell: '/bin/zsh',
    });
  } catch {
    // The script exits non-zero when violations are detected. We still read the report artifact.
  }

  const rerunRaw = readTextSafe(reportFile);
  if (!rerunRaw) return null;
  try {
    return JSON.parse(rerunRaw);
  } catch {
    return null;
  }
}

function runVendorDependencyBan() {
  const aiReport = readAiDependencyReport();

  const findings = aiReport?.failures || ['ai-dependency-ban report missing or unreadable'];
  const passed = Boolean(aiReport && aiReport.passed === true);

  const report = {
    report: 'vendor-dependency-ban',
    generatedAt: nowIso(),
    passed,
    findings,
    sourceReport: 'audit-pack/reports/ai-dependency-ban.json',
    sourceSummary: aiReport
      ? {
          passed: aiReport.passed,
          scannedFiles: Array.isArray(aiReport.scannedFiles) ? aiReport.scannedFiles.length : 0,
          hitCount: Array.isArray(aiReport.hits) ? aiReport.hits.length : 0,
        }
      : null,
  };

  const outputPath = reportPath('vendor-dependency-ban');
  writeJson(outputPath, report);

  return {
    checkId: 'vendor_dependency_ban',
    passed,
    findings,
    evidencePath: outputPath,
    details: report.sourceSummary || {
      scannedFiles: 0,
      hitCount: 0,
    },
  };
}

module.exports = {
  runVendorDependencyBan,
};
