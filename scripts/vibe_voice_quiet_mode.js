#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { finish } = require('./vibe_report_utils');
const { loadVoiceFixtures, simulateFixtureResponse } = require('./voice_vibe_shared');

function main() {
  const failures = [];
  const details = {
    mode: 'simulated',
    checks: [],
    sourceChecks: {},
  };

  const sourcePath = path.resolve('functions/src/voiceSystem.ts');
  if (!fs.existsSync(sourcePath)) {
    failures.push('missing_source:functions/src/voiceSystem.ts');
  } else {
    const source = fs.readFileSync(sourcePath, 'utf8');
    details.sourceChecks = {
      hasQuietModeFunction: /isQuietModeActive/.test(source),
      hasQuietModeMetadata: /quietModeActive/.test(source),
      hasQuietHoursConfig: /quietHours/.test(source),
    };
    for (const [check, passed] of Object.entries(details.sourceChecks)) {
      if (!passed) failures.push(`missing_quiet_mode_guard:${check}`);
    }
  }

  const focusFixtures = loadVoiceFixtures().filter(({ fixture }) => fixture.category === 'focus_nudge');
  if (focusFixtures.length === 0) {
    failures.push('no_focus_fixtures_found');
  }

  for (const { fixture, filePath } of focusFixtures) {
    const check = {
      id: fixture.id,
      locale: fixture.locale,
      filePath,
      passed: false,
      failures: [],
      ttsAvailable: null,
      quietModeActive: null,
    };
    const response = simulateFixtureResponse(fixture, { quietModeActive: true });
    check.ttsAvailable = Boolean(response?.tts?.available);
    check.quietModeActive = Boolean(response?.metadata?.quietModeActive);
    if (check.ttsAvailable) check.failures.push('quiet_mode_should_disable_tts');
    if (!check.quietModeActive) check.failures.push('quiet_mode_flag_missing');
    if (!response?.text) check.failures.push('quiet_mode_should_keep_text_response');
    check.passed = check.failures.length === 0;
    details.checks.push(check);
    if (!check.passed) failures.push(`quiet_mode_failed:${check.id}`);
  }

  finish('voice-quiet-mode', failures, details);
}

main();

