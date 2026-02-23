const path = require('path');
const cp = require('child_process');
const { REPO_ROOT, reportPath, writeJson, nowIso, readTextSafe } = require('../utils');

function readAiDomainReport() {
  const reportFile = path.join(REPO_ROOT, 'audit-pack/reports/ai-domain-ban.json');
  const raw = readTextSafe(reportFile);
  if (raw) {
    try {
      return JSON.parse(raw);
    } catch {
      // Fall through to rerun below.
    }
  }

  try {
    cp.execSync('node scripts/ai_domain_ban.js', {
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

function runVendorDomainBan() {
  const aiReport = readAiDomainReport();

  const findings = aiReport?.failures || ['ai-domain-ban report missing or unreadable'];
  const passed = Boolean(aiReport && aiReport.passed === true);

  const report = {
    report: 'vendor-domain-ban',
    generatedAt: nowIso(),
    passed,
    findings,
    sourceReport: 'audit-pack/reports/ai-domain-ban.json',
    sourceSummary: aiReport
      ? {
          passed: aiReport.passed,
          runtimeHitCount: Array.isArray(aiReport.runtimeHits) ? aiReport.runtimeHits.length : 0,
          docsWarningCount: Array.isArray(aiReport.docHits) ? aiReport.docHits.length : 0,
          scannedFiles: aiReport.scannedFileCount || 0,
        }
      : null,
  };

  const outputPath = reportPath('vendor-domain-ban');
  writeJson(outputPath, report);

  return {
    checkId: 'vendor_domain_ban',
    passed,
    findings,
    evidencePath: outputPath,
    details: report.sourceSummary || {
      runtimeHitCount: 0,
      docsWarningCount: 0,
      scannedFiles: 0,
    },
  };
}

module.exports = {
  runVendorDomainBan,
};
