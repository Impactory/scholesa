#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const cp = require('child_process');
const { finish } = require('./vibe_report_utils');

const suites = [
  { name: 'voice:fixtures-run', script: 'scripts/vibe_voice_fixtures.js', report: 'voice-fixtures-run.json' },
  { name: 'voice:tenant-isolation', script: 'scripts/vibe_voice_tenant_isolation.js', report: 'voice-tenant-isolation.json' },
  { name: 'voice:role-policy', script: 'scripts/vibe_voice_role_policy.js', report: 'voice-role-policy.json' },
  { name: 'voice:egress-none', script: 'scripts/vibe_voice_egress.js', report: 'voice-egress.json' },
  { name: 'stt:locale-accuracy-smoke', script: 'scripts/vibe_stt_smoke.js', report: 'stt-smoke.json' },
  { name: 'voice:trace-continuity', script: 'scripts/vibe_voice_trace_continuity.js', report: 'voice-trace-continuity.json' },
  { name: 'tts:pronunciation-regression', script: 'scripts/vibe_tts_pronunciation.js', report: 'tts-pronunciation.json' },
  { name: 'tts:prosody-policy', script: 'scripts/vibe_tts_prosody_policy.js', report: 'tts-prosody-policy.json' },
  { name: 'voice:utf8-integrity', script: 'scripts/vibe_voice_utf8.js', report: 'voice-utf8.json' },
  { name: 'voice:quiet-mode', script: 'scripts/vibe_voice_quiet_mode.js', report: 'voice-quiet-mode.json' },
  { name: 'voice:abuse-and-safety-refusals', script: 'scripts/vibe_voice_abuse_safety.js', report: 'voice-abuse-safety-refusals.json' },
];

function collectForwardedArgs(argv = process.argv.slice(2)) {
  return argv.filter((arg) => arg === '--live' || arg === '--strict' || arg.startsWith('--base-url='));
}

function main() {
  const failures = [];
  const details = { suites: [] };
  const forwardedArgs = collectForwardedArgs();

  for (const suite of suites) {
    const result = cp.spawnSync(process.execPath, [suite.script, ...forwardedArgs], {
      cwd: process.cwd(),
      env: process.env,
      stdio: 'pipe',
      encoding: 'utf8',
      maxBuffer: 1024 * 1024 * 32,
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
      signal: result.signal || null,
      error: result.error ? String(result.error.message || result.error) : null,
      stdoutTail: (result.stdout || '').trim().split('\n').slice(-6),
      stderrTail: (result.stderr || '').trim().split('\n').slice(-6),
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
          `[vibe:voice:all] suite failed: ${suite.name}`,
          `  exitCode: ${suite.exitCode}`,
          `  signal: ${suite.signal || 'none'}`,
          `  error: ${suite.error || 'none'}`,
          `  stdoutTail: ${(suite.stdoutTail || []).join(' | ') || '(empty)'}`,
          `  stderrTail: ${(suite.stderrTail || []).join(' | ') || '(empty)'}`,
        ].join('\n') + '\n',
      );
    }
  }

  finish('vibe-voice-all-report', failures, details);
}

main();
