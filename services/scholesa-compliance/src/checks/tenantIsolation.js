const cp = require('child_process');
const path = require('path');
const {
  REPO_ROOT,
  reportPath,
  writeJson,
  nowIso,
  readTextSafe,
  resolveExecShell,
  toCanonicalReport,
} = require('../utils');
const { runTenantIsolationInvariants } = require('./tenantIsolationInvariants');

function readJsonSafe(filePath) {
  const raw = readTextSafe(filePath);
  if (!raw) return null;
  try {
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

function runCommand(command) {
  try {
    cp.execSync(command, {
      cwd: REPO_ROOT,
      stdio: 'pipe',
      encoding: 'utf8',
      maxBuffer: 1024 * 1024 * 16,
      shell: resolveExecShell(),
    });
    return { passed: true, command };
  } catch (error) {
    return {
      passed: false,
      command,
      exitCode: typeof error.status === 'number' ? error.status : 1,
      stdout: String(error.stdout || '').slice(0, 4000),
      stderr: String(error.stderr || '').slice(0, 4000),
    };
  }
}

function runTenantIsolation() {
  const findings = [];
  const checks = [];

  const voiceRuntimeResult = runCommand('node scripts/vibe_voice_tenant_isolation.js');
  const voiceRuntimePath = path.join(REPO_ROOT, 'audit-pack/reports/voice-tenant-isolation.json');
  const voiceRuntimeReport = readJsonSafe(voiceRuntimePath);

  const voiceRuntimePassed =
    voiceRuntimeResult.passed &&
    Boolean(voiceRuntimeReport && (voiceRuntimeReport.passed === true || voiceRuntimeReport.pass === true));

  checks.push({
    id: 'voice_runtime_cross_tenant_protection',
    pass: voiceRuntimePassed,
    details: {
      command: voiceRuntimeResult.command,
      commandPassed: voiceRuntimeResult.passed,
      reportPath: path.relative(REPO_ROOT, voiceRuntimePath),
      reportPassed: Boolean(voiceRuntimeReport && (voiceRuntimeReport.passed === true || voiceRuntimeReport.pass === true)),
    },
  });

  if (!voiceRuntimePassed) {
    findings.push('runtime_voice_tenant_isolation_failed');
  }

  const invariants = runTenantIsolationInvariants();
  checks.push({
    id: 'tenant_isolation_invariants',
    pass: invariants.passed,
    details: {
      evidencePath: path.relative(REPO_ROOT, invariants.evidencePath),
      findings: invariants.findings,
    },
  });

  if (!invariants.passed) {
    findings.push(...(invariants.findings || []).map((finding) => `invariant:${finding}`));
  }

  const passed = findings.length === 0;

  const legacyReport = {
    report: 'tenant-isolation',
    generatedAt: nowIso(),
    passed,
    findings,
    checks,
  };

  const report = toCanonicalReport({
    reportName: 'tenant-isolation',
    passed,
    generatedAt: legacyReport.generatedAt,
    checks: checks.map((check) => ({ id: check.id, pass: check.pass, details: check.details })),
    legacy: legacyReport,
  });

  const outputPath = reportPath('tenant-isolation');
  writeJson(outputPath, report);

  return {
    checkId: 'tenant_isolation',
    passed,
    findings,
    evidencePath: outputPath,
    details: { checks: checks.length },
  };
}

module.exports = {
  runTenantIsolation,
};
