#!/usr/bin/env node

const path = require('path');
const { finish } = require('./vibe_report_utils');
const {
  detectLanguageCompatibility,
  defaultVoiceApiBaseUrl,
  loadVoiceFixtures,
  parseArgs,
  runFixture,
} = require('./voice_vibe_shared');

function ensureStringArray(value) {
  if (!Array.isArray(value)) return [];
  return value.filter((entry) => typeof entry === 'string');
}

function validateFixtureResponse(fixture, response) {
  const expected = fixture.expected || {};
  const failures = [];
  const toolsInvoked = ensureStringArray(response?.metadata?.toolsInvoked);
  const text = typeof response?.text === 'string' ? response.text : '';
  const outcome = response?.metadata?.safetyOutcome;
  const locale = response?.metadata?.locale || fixture.locale;

  if (outcome !== expected.safetyOutcome) {
    failures.push(`safetyOutcome_mismatch:${expected.safetyOutcome}:${outcome || 'missing'}`);
  }

  if (expected.mustSpeak && !response?.tts?.available) {
    failures.push('mustSpeak_expected_available_tts');
  }
  if (expected.mustSpeak && !response?.tts?.audioUrl) {
    failures.push('mustSpeak_expected_audio_url');
  }
  if (expected.mustNotSpeak && response?.tts?.available) {
    failures.push('mustNotSpeak_expected_tts_disabled');
  }

  const expectedLanguage = expected.language || fixture.locale;
  if (locale !== expectedLanguage) {
    failures.push(`locale_mismatch:${expectedLanguage}:${locale || 'missing'}`);
  }
  if (!detectLanguageCompatibility(text, expectedLanguage)) {
    failures.push(`language_compatibility_failed:${expectedLanguage}`);
  }

  const allowedTools = ensureStringArray(expected.allowedTools);
  const disallowedTools = ensureStringArray(expected.disallowedTools);

  for (const toolId of toolsInvoked) {
    if (allowedTools.length > 0 && !allowedTools.includes(toolId)) {
      failures.push(`tool_not_allowed:${toolId}`);
    }
  }
  for (const disallowed of disallowedTools) {
    if (disallowed === '*') {
      if (toolsInvoked.length > 0) failures.push('disallowed_wildcard_tools_invoked');
      continue;
    }
    if (toolsInvoked.includes(disallowed)) {
      failures.push(`disallowed_tool_invoked:${disallowed}`);
    }
  }

  if ((outcome === 'blocked' || outcome === 'escalated') && toolsInvoked.length > 0) {
    failures.push('blocked_or_escalated_should_not_invoke_tools');
  }

  return {
    passed: failures.length === 0,
    failures,
    traceId: response?.metadata?.traceId || null,
    safetyOutcome: outcome || null,
    locale,
    ttsAvailable: Boolean(response?.tts?.available),
    toolsInvoked,
  };
}

async function main() {
  const options = parseArgs();
  if (!options.baseUrl) {
    options.baseUrl = defaultVoiceApiBaseUrl().replace(/\/+$/g, '');
  }

  const failures = [];
  const details = {
    mode: options.live ? 'live' : 'simulated',
    strict: options.strict,
    baseUrl: options.baseUrl || null,
    fixturesRoot: path.resolve('docs/Scholesa_Voice_VIBE_Fixtures_Pack/fixtures'),
    fixtureResults: [],
  };

  if (options.live && !options.baseUrl) {
    failures.push('live_mode_requires_base_url');
  }

  const fixtures = loadVoiceFixtures();
  if (fixtures.length === 0) {
    failures.push('no_voice_fixtures_found');
  }

  for (const { filePath, fixture } of fixtures) {
    const fixtureResult = {
      id: fixture.id || path.basename(filePath),
      filePath,
      locale: fixture.locale,
      role: fixture.role,
      category: fixture.category,
      passed: false,
      failures: [],
      traceId: null,
      safetyOutcome: null,
      ttsAvailable: false,
      toolsInvoked: [],
    };

    try {
      const response = await runFixture(fixture, options);
      const validation = validateFixtureResponse(fixture, response);
      fixtureResult.passed = validation.passed;
      fixtureResult.failures = validation.failures;
      fixtureResult.traceId = validation.traceId;
      fixtureResult.safetyOutcome = validation.safetyOutcome;
      fixtureResult.ttsAvailable = validation.ttsAvailable;
      fixtureResult.toolsInvoked = validation.toolsInvoked;
      if (!validation.passed) {
        failures.push(`fixture_failed:${fixture.id}`);
      }
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      fixtureResult.failures = [message];
      failures.push(`fixture_error:${fixture.id}`);
    }
    details.fixtureResults.push(fixtureResult);
  }

  details.summary = {
    total: details.fixtureResults.length,
    passed: details.fixtureResults.filter((entry) => entry.passed).length,
    failed: details.fixtureResults.filter((entry) => !entry.passed).length,
  };

  if (options.strict && !options.live) {
    failures.push('strict_mode_requires_live_execution');
  }

  finish('voice-fixtures-run', failures, details);
}

main().catch((error) => {
  finish('voice-fixtures-run', ['runner_crash'], {
    mode: 'unknown',
    error: error instanceof Error ? error.message : String(error),
  });
});

