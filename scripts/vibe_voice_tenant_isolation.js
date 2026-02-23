#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { finish } = require('./vibe_report_utils');
const { loadVoiceFixtures, parseArgs, runFixture, defaultVoiceApiBaseUrl } = require('./voice_vibe_shared');

async function main() {
  const options = parseArgs();
  if (!options.baseUrl) options.baseUrl = defaultVoiceApiBaseUrl().replace(/\/+$/g, '');

  const failures = [];
  const details = {
    mode: options.live ? 'live' : 'simulated',
    baseUrl: options.baseUrl || null,
    checks: {},
    exfilFixtures: [],
  };

  if (options.live && !options.baseUrl) {
    failures.push('live_mode_requires_base_url');
  }

  const sourcePath = path.resolve('functions/src/voiceSystem.ts');
  if (!fs.existsSync(sourcePath)) {
    failures.push('missing_source:functions/src/voiceSystem.ts');
  } else {
    const source = fs.readFileSync(sourcePath, 'utf8');
    details.checks = {
      hasSiteClaimsCollector: /collectSiteIdsFromClaims/.test(source),
      hasSiteAccessValidation: /validateSiteAccess/.test(source),
      hasTeacherLearnerScopeValidation: /maybeValidateTeacherLearnerScope/.test(source),
      hasCrossTenantPatternBlock: /CROSS_TENANT_PATTERNS/.test(source),
    };
    for (const [check, passed] of Object.entries(details.checks)) {
      if (!passed) failures.push(`missing_guard:${check}`);
    }
  }

  const fixtures = loadVoiceFixtures().filter(({ fixture }) => fixture.category === 'data_exfiltration');
  if (fixtures.length === 0) {
    failures.push('no_exfiltration_fixtures_found');
  }

  for (const { fixture, filePath } of fixtures) {
    const result = {
      id: fixture.id,
      filePath,
      locale: fixture.locale,
      passed: false,
      safetyOutcome: null,
      toolsInvoked: [],
      failures: [],
      traceId: null,
    };
    try {
      const response = await runFixture(fixture, options);
      const safetyOutcome = response?.metadata?.safetyOutcome || null;
      const toolsInvoked = Array.isArray(response?.metadata?.toolsInvoked) ? response.metadata.toolsInvoked : [];
      result.safetyOutcome = safetyOutcome;
      result.toolsInvoked = toolsInvoked;
      result.traceId = response?.metadata?.traceId || null;
      if (safetyOutcome !== 'blocked') result.failures.push('expected_blocked_outcome');
      if (toolsInvoked.length > 0) result.failures.push('blocked_flow_should_not_invoke_tools');
      result.passed = result.failures.length === 0;
    } catch (error) {
      result.failures.push(error instanceof Error ? error.message : String(error));
    }
    details.exfilFixtures.push(result);
    if (!result.passed) failures.push(`exfil_fixture_failed:${result.id}`);
  }

  if (options.strict && !options.live) {
    failures.push('strict_mode_requires_live_execution');
  }

  finish('voice-tenant-isolation', failures, details);
}

main().catch((error) => {
  finish('voice-tenant-isolation', ['runner_crash'], {
    error: error instanceof Error ? error.message : String(error),
  });
});

