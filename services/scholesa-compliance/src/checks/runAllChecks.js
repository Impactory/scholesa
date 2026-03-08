const cp = require('child_process');
const path = require('path');
const {
  REPO_ROOT,
  reportPath,
  writeJson,
  nowIso,
  readTextSafe,
  resolveExecShell,
} = require('../utils');
const { runRepoScan } = require('./repoScan');
const { runVendorDependencyBan } = require('./vendorDependencyBan');
const { runVendorDomainBan } = require('./vendorDomainBan');
const { runVendorSecretBan } = require('./vendorSecretBan');
const { runRuntimeEgressProof } = require('./runtimeEgressProof');
const { runTenantIsolationInvariants } = require('./tenantIsolationInvariants');
const { runVoiceRetentionControls } = require('./voiceRetentionControls');
const { runLogPrivacySafety } = require('./logPrivacySafety');
const { runStudentDataTrainingBan } = require('./studentDataTrainingBan');
const { runTenantIsolation } = require('./tenantIsolation');
const { runInferenceAuthz } = require('./inferenceAuthz');
const { runInferenceIngressPrivate } = require('./inferenceIngressPrivate');
const { runInfraDrift } = require('./infraDrift');
const { runI18nCoverage } = require('./i18nCoverage');

function runCommand(command) {
  try {
    cp.execSync(command, {
      cwd: REPO_ROOT,
      stdio: 'pipe',
      encoding: 'utf8',
      maxBuffer: 1024 * 1024 * 32,
      shell: resolveExecShell(),
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
    'npm run vibe:all',
    'npm run qa:vibe-telemetry:audit',
    'npm run qa:vibe-telemetry:blockers',
    'npm run audit:coppa:no-ads',
  ];
  if (process.env.COMPLIANCE_RUN_RC2_INLINE === '1') {
    commands.splice(2, 0, 'npm run rc2:regression');
  }
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

function emitExternalSuiteFailures(externalSuiteResults) {
  for (const suite of externalSuiteResults.filter((item) => !item.passed)) {
    process.stderr.write(
      [
        `[compliance] external suite failed: ${suite.command}`,
        `  exitCode: ${suite.exitCode ?? 1}`,
        `  stdoutTail: ${String(suite.stdout || '').trim().split('\n').slice(-10).join(' | ') || '(empty)'}`,
        `  stderrTail: ${String(suite.stderr || '').trim().split('\n').slice(-10).join(' | ') || '(empty)'}`,
      ].join('\n') + '\n',
    );
  }
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
    runTenantIsolation(),
    runInferenceAuthz(),
    runInferenceIngressPrivate(),
    runVoiceRetentionControls(),
    runLogPrivacySafety(),
    runStudentDataTrainingBan(),
    runInfraDrift(),
    runI18nCoverage(),
  ];

  const failures = summarizeChecks(checks, externalSuites);
  emitExternalSuiteFailures(externalSuites);
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
      tenantIsolation: 'audit-pack/reports/tenant-isolation.json',
      safetyFixtures: 'audit-pack/reports/safety-fixtures.json',
      inferenceAuthz: 'audit-pack/reports/inference-authz.json',
      inferenceIngressPrivate: 'audit-pack/reports/inference-ingress-private.json',
      voiceRetentionControls: 'audit-pack/reports/voice-retention-controls.json',
      voiceRetentionTtl: 'audit-pack/reports/voice-retention-ttl.json',
      logPrivacySafety: 'audit-pack/reports/log-privacy-safety.json',
      loggingNoRawContent: 'audit-pack/reports/logging-no-raw-content.json',
      telemetrySchemaValid: 'audit-pack/reports/telemetry-schema-valid.json',
      studentDataTrainingBan: 'audit-pack/reports/student-data-training-ban.json',
      infraDrift: 'audit-pack/reports/infra-drift.json',
      i18nCoverage: 'audit-pack/reports/i18n-coverage.json',
      vibeTelemetryAuditMaster: 'audit-pack/reports/vibe-telemetry-audit-master.json',
      vibeCiBlockerGate: 'audit-pack/reports/vibe-ci-blocker-gate.json',
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
      tenantIsolation: checks.find((item) => item.checkId === 'tenant_isolation')?.passed === true,
      inferenceAuthz: checks.find((item) => item.checkId === 'inference_authz')?.passed === true,
      inferenceIngressPrivate: checks.find((item) => item.checkId === 'inference_ingress_private')?.passed === true,
      voiceRetentionControls: checks.find((item) => item.checkId === 'voice_retention_controls')?.passed === true,
      logPrivacySafety: checks.find((item) => item.checkId === 'log_privacy_safety')?.passed === true,
      studentDataTrainingBan: checks.find((item) => item.checkId === 'student_data_training_ban')?.passed === true,
      infraDrift: checks.find((item) => item.checkId === 'infra_drift')?.passed === true,
      i18nCoverage: checks.find((item) => item.checkId === 'i18n_coverage')?.passed === true,
      safetyFixtures: latestJson('safety-fixtures.json')?.pass === true || latestJson('safety-fixtures.json')?.passed === true,
      telemetrySchemaValid: latestJson('telemetry-schema-valid.json')?.pass === true || latestJson('telemetry-schema-valid.json')?.passed === true,
      vibeCiBlockerGate: latestJson('vibe-ci-blocker-gate.json')?.pass === true || latestJson('vibe-ci-blocker-gate.json')?.passed === true,
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
