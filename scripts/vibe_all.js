#!/usr/bin/env node

const path = require('path');
const cp = require('child_process');
const fs = require('fs');
const { finish } = require('./vibe_report_utils');

const suites = [
  { name: 'vibe:i18n:lint', script: 'scripts/vibe_i18n_lint.js', report: 'vibe-i18n-lint-report.json' },
  { name: 'vibe:i18n:keys', script: 'scripts/vibe_i18n_keys.js', report: 'vibe-i18n-keys-report.json' },
  { name: 'vibe:ui:screens:i18n', script: 'scripts/vibe_ui_screens_i18n.js', report: 'vibe-ui-screens-i18n-report.json' },
  { name: 'vibe:api:locale', script: 'scripts/vibe_api_locale.js', report: 'vibe-api-locale-report.json' },
  { name: 'vibe:ai:guardrails:i18n', script: 'scripts/vibe_ai_guardrails_i18n.js', report: 'vibe-ai-guardrails-i18n-report.json' },
  { name: 'vibe:ai:language', script: 'scripts/vibe_ai_language.js', report: 'vibe-ai-language-report.json' },
  { name: 'vibe:data:utf8', script: 'scripts/vibe_data_utf8.js', report: 'vibe-data-utf8-report.json' },
  { name: 'vibe:voice:all', script: 'scripts/vibe_voice_all.js', report: 'vibe-voice-all-report.json' },
  { name: 'vibe:compliance:notice:i18n', script: 'scripts/vibe_compliance_notice_i18n.js', report: 'vibe-compliance-notice-i18n-report.json' },
];

const failures = [];
const details = { suites: [] };

for (const suite of suites) {
  const result = cp.spawnSync('node', [suite.script], {
    stdio: 'pipe',
    encoding: 'utf8',
  });

  const reportPath = path.resolve('audit-pack/reports', suite.report);
  let reportSummary = null;
  if (fs.existsSync(reportPath)) {
    reportSummary = JSON.parse(fs.readFileSync(reportPath, 'utf8'));
  }

  details.suites.push({
    name: suite.name,
    script: suite.script,
    exitCode: result.status,
    stdoutTail: (result.stdout || '').trim().split('\n').slice(-5),
    stderrTail: (result.stderr || '').trim().split('\n').slice(-5),
    report: reportSummary ? {
      passed: reportSummary.passed,
      failures: reportSummary.failures?.length || 0,
      timestamp: reportSummary.timestamp,
    } : null,
  });

  if (result.status !== 0) {
    failures.push(`suite_failed:${suite.name}`);
  }
}

finish('vibe-all-report', failures, details);
