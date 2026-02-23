#!/usr/bin/env node

const { finish } = require('./vibe_report_utils');
const { loadVoiceFixtures, parseArgs, runFixture, defaultVoiceApiBaseUrl, ROLE_ALLOWED_TOOLS } = require('./voice_vibe_shared');

async function main() {
  const options = parseArgs();
  if (!options.baseUrl) options.baseUrl = defaultVoiceApiBaseUrl().replace(/\/+$/g, '');

  const failures = [];
  const details = {
    mode: options.live ? 'live' : 'simulated',
    baseUrl: options.baseUrl || null,
    checks: [],
  };

  if (options.live && !options.baseUrl) failures.push('live_mode_requires_base_url');

  const fixtures = loadVoiceFixtures().filter(({ fixture }) =>
    fixture.role === 'student' || fixture.role === 'teacher' || fixture.role === 'admin'
  );
  if (fixtures.length === 0) failures.push('no_role_fixtures_found');

  for (const { fixture, filePath } of fixtures) {
    const role = fixture.role;
    const check = {
      id: fixture.id,
      role,
      filePath,
      passed: false,
      toolsInvoked: [],
      failures: [],
      traceId: null,
    };
    try {
      const response = await runFixture(fixture, options);
      const toolsInvoked = Array.isArray(response?.metadata?.toolsInvoked) ? response.metadata.toolsInvoked : [];
      check.toolsInvoked = toolsInvoked;
      check.traceId = response?.metadata?.traceId || null;
      const allowed = ROLE_ALLOWED_TOOLS[role] || [];
      for (const toolId of toolsInvoked) {
        if (!allowed.includes(toolId)) {
          check.failures.push(`tool_not_permitted_for_role:${toolId}`);
        }
      }
      if ((response?.metadata?.safetyOutcome === 'blocked' || response?.metadata?.safetyOutcome === 'escalated') &&
        toolsInvoked.length > 0) {
        check.failures.push('blocked_or_escalated_should_not_invoke_tools');
      }
      check.passed = check.failures.length === 0;
    } catch (error) {
      check.failures.push(error instanceof Error ? error.message : String(error));
    }
    details.checks.push(check);
    if (!check.passed) failures.push(`role_policy_failed:${check.id}`);
  }

  if (options.strict && !options.live) failures.push('strict_mode_requires_live_execution');

  finish('voice-role-policy', failures, details);
}

main().catch((error) => {
  finish('voice-role-policy', ['runner_crash'], {
    error: error instanceof Error ? error.message : String(error),
  });
});

