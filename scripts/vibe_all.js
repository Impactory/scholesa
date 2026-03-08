#!/usr/bin/env node

const path = require('path');
const cp = require('child_process');
const fs = require('fs');
const { finish } = require('./vibe_report_utils');

const suites = [
  { name: 'qa:coppa:guards', command: 'npm', args: ['run', 'qa:coppa:guards'], report: null },
  { name: 'vibe:i18n:lint', script: 'scripts/vibe_i18n_lint.js', report: 'vibe-i18n-lint-report.json' },
  { name: 'vibe:i18n:keys', script: 'scripts/vibe_i18n_keys.js', report: 'vibe-i18n-keys-report.json' },
  { name: 'vibe:ui:screens:i18n', script: 'scripts/vibe_ui_screens_i18n.js', report: 'vibe-ui-screens-i18n-report.json' },
  { name: 'vibe:api:locale', script: 'scripts/vibe_api_locale.js', report: 'vibe-api-locale-report.json' },
  { name: 'vibe:ai:guardrails:i18n', script: 'scripts/vibe_ai_guardrails_i18n.js', report: 'vibe-ai-guardrails-i18n-report.json' },
  { name: 'vibe:ai:language', script: 'scripts/vibe_ai_language.js', report: 'vibe-ai-language-report.json' },
  { name: 'ai:dependency-ban', script: 'scripts/ai_dependency_ban.js', report: 'ai-dependency-ban.json' },
  { name: 'ai:import-ban', script: 'scripts/ai_import_ban.js', report: 'ai-import-ban.json' },
  { name: 'ai:domain-ban', script: 'scripts/ai_domain_ban.js', report: 'ai-domain-ban.json' },
  { name: 'ai:egress-none', script: 'scripts/ai_egress_none.js', report: 'ai-egress-none.json' },
  { name: 'vibe:data:utf8', script: 'scripts/vibe_data_utf8.js', report: 'vibe-data-utf8-report.json' },
  { name: 'vibe:voice:all', script: 'scripts/vibe_voice_all.js', report: 'vibe-voice-all-report.json' },
  { name: 'vibe:compliance:notice:i18n', script: 'scripts/vibe_compliance_notice_i18n.js', report: 'vibe-compliance-notice-i18n-report.json' },
];

function resolveSuiteProcess(suite) {
  if (suite.command === 'npm') {
    const npmExecPath = process.env.npm_execpath;
    if (npmExecPath) {
      return {
        bin: process.execPath,
        args: [npmExecPath, ...(suite.args || [])],
      };
    }
    return {
      bin: process.platform === 'win32' ? 'npm.cmd' : 'npm',
      args: suite.args || [],
    };
  }

  return {
    bin: suite.command || process.execPath,
    args: suite.args || [suite.script],
  };
}

const failures = [];
const details = { suites: [] };

for (const suite of suites) {
  const { bin, args } = resolveSuiteProcess(suite);
  const result = cp.spawnSync(bin, args, {
    cwd: process.cwd(),
    env: process.env,
    stdio: 'pipe',
    encoding: 'utf8',
    maxBuffer: 1024 * 1024 * 32,
  });

  const reportPath = suite.report ? path.resolve('audit-pack/reports', suite.report) : null;
  let reportSummary = null;
  if (reportPath && fs.existsSync(reportPath)) {
    reportSummary = JSON.parse(fs.readFileSync(reportPath, 'utf8'));
  }

  details.suites.push({
    name: suite.name,
    script: suite.script,
    exitCode: result.status,
    signal: result.signal || null,
    error: result.error ? String(result.error.message || result.error) : null,
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

if (failures.length > 0) {
  for (const suite of details.suites.filter((item) => item.exitCode !== 0 || item.error)) {
    process.stderr.write(
      [
        `[vibe:all] suite failed: ${suite.name}`,
        `  exitCode: ${suite.exitCode}`,
        `  signal: ${suite.signal || 'none'}`,
        `  error: ${suite.error || 'none'}`,
        `  stdoutTail: ${(suite.stdoutTail || []).join(' | ') || '(empty)'}`,
        `  stderrTail: ${(suite.stderrTail || []).join(' | ') || '(empty)'}`,
      ].join('\n') + '\n',
    );
  }
}

finish('vibe-all-report', failures, details);
