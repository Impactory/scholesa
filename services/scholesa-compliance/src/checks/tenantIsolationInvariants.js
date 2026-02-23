const path = require('path');
const { REPO_ROOT, reportPath, writeJson, nowIso, readTextSafe } = require('../utils');

function mustContain(content, needle, findings, label) {
  if (!content || !content.includes(needle)) {
    findings.push(`missing invariant: ${label}`);
  }
}

function runTenantIsolationInvariants() {
  const findings = [];

  const voiceSystemPath = path.join(REPO_ROOT, 'functions/src/voiceSystem.ts');
  const functionsIndexPath = path.join(REPO_ROOT, 'functions/src/index.ts');
  const rulesPath = path.join(REPO_ROOT, 'firestore.rules');

  const voiceSystem = readTextSafe(voiceSystemPath);
  const functionsIndex = readTextSafe(functionsIndexPath);
  const rules = readTextSafe(rulesPath);

  mustContain(voiceSystem, 'resolveAuthContext', findings, 'voice API auth context resolution');
  mustContain(voiceSystem, 'validateSiteAccess', findings, 'voice API tenant scope validation');
  mustContain(voiceSystem, 'siteId', findings, 'voice API siteId scoping');

  mustContain(functionsIndex, 'requireRoleAndSite', findings, 'functions requireRoleAndSite gate');
  mustContain(functionsIndex, 'siteId', findings, 'functions site-scoped operations');

  mustContain(rules, 'request.auth != null', findings, 'firestore auth gate');

  const firestoreHasSiteScope = Boolean(
    rules &&
    (
      rules.includes('isSiteScopedRead') ||
      rules.includes('isSiteScopedWrite') ||
      rules.includes('siteId')
    )
  );
  if (!firestoreHasSiteScope) {
    findings.push('missing invariant: firestore site scope checks');
  }

  const passed = findings.length === 0;
  const report = {
    report: 'tenant-isolation-invariants',
    generatedAt: nowIso(),
    passed,
    findings,
    checks: {
      voiceSystemPath,
      functionsIndexPath,
      rulesPath,
    },
  };

  const outputPath = reportPath('tenant-isolation-invariants');
  writeJson(outputPath, report);

  return {
    checkId: 'tenant_isolation_invariants',
    passed,
    findings,
    evidencePath: outputPath,
    details: report.checks,
  };
}

module.exports = {
  runTenantIsolationInvariants,
};
