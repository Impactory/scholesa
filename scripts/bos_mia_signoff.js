#!/usr/bin/env node

const cp = require('child_process');
const { finish } = require('./vibe_report_utils');

function runStep(name, command, args) {
  process.stdout.write(`\n=== SIGNOFF STEP: ${name} ===\n`);
  const startedAt = Date.now();
  const result = cp.spawnSync(command, args, {
    encoding: 'utf8',
    stdio: 'pipe',
  });
  const durationMs = Date.now() - startedAt;
  return {
    name,
    command: [command, ...args].join(' '),
    exitCode: result.status,
    durationMs,
    stdoutTail: (result.stdout || '').trim().split('\n').slice(-20),
    stderrTail: (result.stderr || '').trim().split('\n').slice(-20),
  };
}

function main() {
  const steps = [
    {
      name: 'Big-bang release artifact verification',
      command: 'npm',
      args: ['run', 'qa:release:big-bang-docs'],
    },
    {
      name: 'BOS MIA completion gate',
      command: 'npm',
      args: ['run', 'qa:bos:mia:complete'],
    },
    {
      name: 'Voice live COPPA gate chain',
      command: 'npm',
      args: ['run', 'vibe:voice:all:live'],
    },
  ];

  const results = [];
  const failures = [];

  for (const step of steps) {
    const res = runStep(step.name, step.command, step.args);
    results.push(res);
    if (res.exitCode !== 0) {
      failures.push(`step_failed:${step.name}`);
      break;
    }
  }

  const details = {
    summary: {
      totalSteps: steps.length,
      executedSteps: results.length,
      passedSteps: results.filter((r) => r.exitCode === 0).length,
    },
    steps: results,
  };

  const output = finish('bos-mia-signoff', failures, details);
  if (output.failed) {
    process.exitCode = 1;
    return;
  }
  process.stdout.write('✅ BOS+MIA sign-off report generated.\n');
  process.stdout.write('Manual release control remains RC3_BIG_BANG_OPERATOR_SCRIPT_MARCH_12_2026.md + RC3_BIG_BANG_CUTOVER_CHECKLIST_MARCH_12_2026.md\n');
}

main();
