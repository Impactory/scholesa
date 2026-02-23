const path = require('path');
const { REPO_ROOT, reportPath, writeJson, nowIso, readTextSafe } = require('../utils');

function safeJson(filePath) {
  const raw = readTextSafe(filePath);
  if (!raw) return null;
  try {
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

function runRuntimeEgressProof() {
  const findings = [];

  const srcGuardPath = path.join(REPO_ROOT, 'src/lib/ai/egressGuard.ts');
  const fnGuardPath = path.join(REPO_ROOT, 'functions/src/security/egressGuard.ts');
  const srcGuard = readTextSafe(srcGuardPath);
  const fnGuard = readTextSafe(fnGuardPath);

  if (!srcGuard || !srcGuard.includes('SECURITY_EGRESS_BLOCKED')) {
    findings.push('src egress guard missing or missing SECURITY_EGRESS_BLOCKED emission');
  }
  if (!fnGuard || !fnGuard.includes('SECURITY_EGRESS_BLOCKED')) {
    findings.push('functions egress guard missing or missing SECURITY_EGRESS_BLOCKED emission');
  }

  const aiEgressReport = safeJson(path.join(REPO_ROOT, 'audit-pack/reports/ai-egress-none.json'));
  if (!aiEgressReport || aiEgressReport.passed !== true) {
    findings.push('ai-egress-none report missing or failing');
  }

  const voiceEgressReport = safeJson(path.join(REPO_ROOT, 'audit-pack/reports/voice-egress.json'));
  if (!voiceEgressReport || voiceEgressReport.passed !== true) {
    findings.push('voice-egress report missing or failing');
  }

  const passed = findings.length === 0;
  const report = {
    report: 'vendor-egress-proof',
    generatedAt: nowIso(),
    passed,
    findings,
    checks: {
      srcGuardPresent: Boolean(srcGuard),
      srcGuardHasSecurityEvent: Boolean(srcGuard && srcGuard.includes('SECURITY_EGRESS_BLOCKED')),
      functionsGuardPresent: Boolean(fnGuard),
      functionsGuardHasSecurityEvent: Boolean(fnGuard && fnGuard.includes('SECURITY_EGRESS_BLOCKED')),
      aiEgressReportPassed: Boolean(aiEgressReport && aiEgressReport.passed === true),
      voiceEgressReportPassed: Boolean(voiceEgressReport && voiceEgressReport.passed === true),
    },
  };

  const outputPath = reportPath('vendor-egress-proof');
  writeJson(outputPath, report);

  return {
    checkId: 'runtime_egress_proof',
    passed,
    findings,
    evidencePath: outputPath,
    details: report.checks,
  };
}

module.exports = {
  runRuntimeEgressProof,
};
