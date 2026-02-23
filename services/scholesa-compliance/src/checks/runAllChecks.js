const cp = require('child_process');
const path = require('path');
const {
  REPO_ROOT,
  reportPath,
  writeJson,
  nowIso,
  readTextSafe,
} = require('../utils');
const { runRepoScan } = require('./repoScan');
const { runVendorDependencyBan } = require('./vendorDependencyBan');
const { runVendorDomainBan } = require('./vendorDomainBan');
const { runVendorSecretBan } = require('./vendorSecretBan');
const { runRuntimeEgressProof } = require('./runtimeEgressProof');
const { runTenantIsolationInvariants } = require('./tenantIsolationInvariants');
const { runVoiceRetentionControls } = require('./voiceRetentionControls');
const { runLogPrivacySafety } = require('./logPrivacySafety');

function runCommand(command) {
  try {
    cp.execSync(command, {
      cwd: REPO_ROOT,
      stdio: 'pipe',
      encoding: 'utf8',
      maxBuffer: 1024 * 1024 * 32,
      shell: '/bin/zsh',
    });
    return { command, passed: true };
  } catch (error) {
    return {
      command,
      passed: false,
      exitCode: typeof error.status === 'number' ? error.status : 1,
      stderr: String(error.stderr || '').slice(0, 6000),
      stdout: String(error.stdout || '').slice(0, 6000),
    };
  }
}

function executeExternalSuites() {
  const commands = [
    'npm run ai:internal-only:all',
    'npm run vibe:voice:all',
    'npm run audit:coppa:no-ads',
  ];
  return commands.map(runCommand);
}

function summarizeChecks(checkResults, externalSuiteResults) {
  const failures = [];

  for (const suite of externalSuiteResults) {
    if (!suite.passed) failures.push(`external_suite_failed:${suite.command}`);
  }

  for (const result of checkResults) {
    if (!result.passed) {
      if (result.findings && result.findings.length > 0) {
        for (const finding of result.findings) {
          failures.push(`${result.checkId}:${finding}`);
        }
      } else {
        failures.push(`${result.checkId}:failed`);
      }
    }
  }

  return failures;
}

function latestJson(fileName) {
  const content = readTextSafe(path.join(REPO_ROOT, 'audit-pack', 'reports', fileName));
  if (!content) return null;
  try {
    return JSON.parse(content);
  } catch {
    return null;
  }
}

function runComplianceSuite(trigger = 'manual') {
  const startedAt = nowIso();
  const reportId = `${Date.now()}`;

  const externalSuites = executeExternalSuites();

  const checks = [
    runRepoScan(),
    runVendorDependencyBan(),
    runVendorDomainBan(),
    runVendorSecretBan(),
    runRuntimeEgressProof(),
    runTenantIsolationInvariants(),
    runVoiceRetentionControls(),
    runLogPrivacySafety(),
  ];

  const failures = summarizeChecks(checks, externalSuites);
  const passed = failures.length === 0;

  const policyPath = path.join(REPO_ROOT, 'services/scholesa-compliance/policies/controls.yaml');
  const policyRaw = readTextSafe(policyPath) || '';

  const report = {
    report: 'compliance-operator-run',
    reportId,
    generatedAt: nowIso(),
    startedAt,
    trigger,
    passed,
    policyVersion: (() => {
      const match = policyRaw.match(/policyVersion:\s*"([^"]+)"/);
      return match ? match[1] : 'unknown';
    })(),
    policyPath: path.relative(REPO_ROOT, policyPath),
    externalSuites,
    checks,
    failures,
    evidence: {
      repoStructureScan: 'audit-pack/reports/repo-structure-scan.json',
      vendorDependencyBan: 'audit-pack/reports/vendor-dependency-ban.json',
      vendorDomainBan: 'audit-pack/reports/vendor-domain-ban.json',
      vendorSecretBan: 'audit-pack/reports/vendor-secret-ban.json',
      vendorEgressProof: 'audit-pack/reports/vendor-egress-proof.json',
      tenantIsolationInvariants: 'audit-pack/reports/tenant-isolation-invariants.json',
      voiceRetentionControls: 'audit-pack/reports/voice-retention-controls.json',
      logPrivacySafety: 'audit-pack/reports/log-privacy-safety.json',
      aiDependencyBan: 'audit-pack/reports/ai-dependency-ban.json',
      aiImportBan: 'audit-pack/reports/ai-import-ban.json',
      aiDomainBan: 'audit-pack/reports/ai-domain-ban.json',
      aiEgressNone: 'audit-pack/reports/ai-egress-none.json',
      voiceTenantIsolation: 'audit-pack/reports/voice-tenant-isolation.json',
      voiceRolePolicy: 'audit-pack/reports/voice-role-policy.json',
      voiceEgress: 'audit-pack/reports/voice-egress.json',
      sttSmoke: 'audit-pack/reports/stt-smoke.json',
      ttsPronunciation: 'audit-pack/reports/tts-pronunciation.json',
      ttsProsodyPolicy: 'audit-pack/reports/tts-prosody-policy.json',
      voiceUtf8: 'audit-pack/reports/voice-utf8.json',
      voiceQuietMode: 'audit-pack/reports/voice-quiet-mode.json',
      voiceAbuseSafety: 'audit-pack/reports/voice-abuse-safety.json',
      coppaNoAds: 'audit-pack/reports/coppa-no-ads.txt',
    },
  };

  const runReportPath = reportPath(`compliance-run-${reportId}`);
  writeJson(runReportPath, report);

  const latestPath = reportPath('compliance-latest');
  writeJson(latestPath, {
    reportId,
    generatedAt: report.generatedAt,
    passed,
    failures,
    reportPath: path.relative(REPO_ROOT, runReportPath),
  });

  const dashboardPath = reportPath('compliance-dashboard');
  writeJson(dashboardPath, {
    updatedAt: report.generatedAt,
    reportId,
    status: passed ? 'PASS' : 'FAIL',
    blockerCount: failures.length,
    keySignals: {
      aiDependencyBan: latestJson('ai-dependency-ban.json')?.passed === true,
      aiImportBan: latestJson('ai-import-ban.json')?.passed === true,
      aiDomainBan: latestJson('ai-domain-ban.json')?.passed === true,
      aiEgressNone: latestJson('ai-egress-none.json')?.passed === true,
      voiceTenantIsolation: latestJson('voice-tenant-isolation.json')?.passed === true,
      tenantIsolationInvariants: checks.find((item) => item.checkId === 'tenant_isolation_invariants')?.passed === true,
      voiceRetentionControls: checks.find((item) => item.checkId === 'voice_retention_controls')?.passed === true,
      logPrivacySafety: checks.find((item) => item.checkId === 'log_privacy_safety')?.passed === true,
    },
    reportPath: path.relative(REPO_ROOT, runReportPath),
  });

  return {
    passed,
    reportId,
    reportPath: runReportPath,
    failures,
    checks,
    externalSuites,
  };
}

module.exports = {
  runComplianceSuite,
};
