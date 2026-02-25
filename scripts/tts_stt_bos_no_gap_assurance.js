#!/usr/bin/env node
'use strict';

const fs = require('node:fs');
const path = require('node:path');
const cp = require('node:child_process');
const {
  buildCanonicalReport,
  extractPass,
  readJsonSafe,
  resolveEnv,
  writeCanonicalReport,
} = require('./vibe_audit_report_schema');

const ROOT = path.resolve(__dirname, '..');
const DEFAULT_PROJECT = 'studio-3328096157-e3f79';
const DEFAULT_CREDENTIALS = 'firebase-service-account.json';
const DEFAULT_REPORT_NAME = 'tts-stt-bos-no-gap-assurance';
const DEFAULT_VOICE_BASE_URL = 'https://voiceapi-gu5vyrn2tq-uc.a.run.app';
const RETRYABLE_ERROR_PATTERNS = [
  'UNAVAILABLE: Name resolution failed',
  'fetch failed',
  'ETIMEDOUT',
  'EAI_AGAIN',
];

function parseArgs(argv) {
  const args = {
    env: resolveEnv(process.env.VIBE_ENV || process.env.NODE_ENV || 'prod'),
    strict: false,
    hours: 168,
    limit: 25000,
    project: process.env.FIREBASE_PROJECT_ID || DEFAULT_PROJECT,
    credentials: process.env.GOOGLE_APPLICATION_CREDENTIALS || DEFAULT_CREDENTIALS,
    baseUrl: process.env.VOICE_API_BASE_URL || DEFAULT_VOICE_BASE_URL,
    reportName: DEFAULT_REPORT_NAME,
    wiringReportName: 'firebase-ui-field-wiring-bulk-bos-noncore-latest',
  };

  for (const arg of argv) {
    if (arg === '--strict') {
      args.strict = true;
      continue;
    }
    if (!arg.startsWith('--')) {
      continue;
    }
    const [rawKey, rawValue] = arg.slice(2).split('=');
    if (rawValue === undefined) {
      continue;
    }
    if (rawKey === 'env') args.env = resolveEnv(rawValue);
    if (rawKey === 'hours') args.hours = Number(rawValue);
    if (rawKey === 'limit') args.limit = Number(rawValue);
    if (rawKey === 'project') args.project = rawValue.trim();
    if (rawKey === 'credentials') args.credentials = rawValue.trim();
    if (rawKey === 'base-url' || rawKey === 'baseUrl') args.baseUrl = rawValue.trim();
    if (rawKey === 'report-name' || rawKey === 'reportName') args.reportName = rawValue.trim() || DEFAULT_REPORT_NAME;
    if (rawKey === 'wiring-report-name' || rawKey === 'wiringReportName') {
      args.wiringReportName = rawValue.trim() || args.wiringReportName;
    }
  }

  if (!Number.isFinite(args.hours) || args.hours <= 0) {
    throw new Error(`Invalid --hours value: ${args.hours}`);
  }
  if (!Number.isFinite(args.limit) || args.limit <= 0) {
    throw new Error(`Invalid --limit value: ${args.limit}`);
  }
  if (!args.project) {
    throw new Error('Missing --project value.');
  }
  if (!args.credentials) {
    throw new Error('Missing --credentials value.');
  }
  if (!args.reportName) {
    throw new Error('Missing --report-name value.');
  }

  return args;
}

function tailLines(value, limit = 10) {
  if (!value) return [];
  return String(value)
    .trim()
    .split('\n')
    .filter(Boolean)
    .slice(-limit);
}

function pickResultLine(stdout, stderr) {
  const lines = `${stdout || ''}\n${stderr || ''}`
    .split('\n')
    .map((line) => line.trim())
    .filter(Boolean);
  const patterns = [/^Result:\s/i, /^PASS\b/i, /^FAIL\b/i, /^{"status":/i];
  for (const pattern of patterns) {
    const match = lines.find((line) => pattern.test(line));
    if (match) return match;
  }
  return lines[lines.length - 1] || '';
}

function isRetryableFailure(output) {
  const joined = String(output || '');
  return RETRYABLE_ERROR_PATTERNS.some((pattern) => joined.includes(pattern));
}

function sleepMs(ms) {
  const sharedBuffer = new SharedArrayBuffer(4);
  const int32 = new Int32Array(sharedBuffer);
  Atomics.wait(int32, 0, 0, ms);
}

function runNodeCommand({ id, scriptPath, args = [], env = {}, retries = 0, retryDelayMs = 2000 }) {
  const startedAt = Date.now();
  const resolvedScriptPath = path.resolve(ROOT, scriptPath);
  let attempt = 0;
  let result = null;
  let stdout = '';
  let stderr = '';
  let pass = false;

  while (attempt <= retries) {
    result = cp.spawnSync(process.execPath, [resolvedScriptPath, ...args], {
      cwd: ROOT,
      env: { ...process.env, ...env },
      encoding: 'utf8',
      maxBuffer: 1024 * 1024 * 64,
    });

    stdout = String(result.stdout || '');
    stderr = String(result.stderr || '');
    pass = result.status === 0;
    if (pass) {
      break;
    }
    if (attempt >= retries) {
      break;
    }
    if (!isRetryableFailure(`${stdout}\n${stderr}`)) {
      break;
    }
    sleepMs(retryDelayMs);
    attempt += 1;
  }

  return {
    id,
    pass,
    details: {
      command: `node ${scriptPath}${args.length > 0 ? ` ${args.join(' ')}` : ''}`,
      exitCode: typeof result.status === 'number' ? result.status : 1,
      durationMs: Date.now() - startedAt,
      attempts: attempt + 1,
      resultLine: pickResultLine(stdout, stderr),
      stdoutTail: tailLines(stdout),
      stderrTail: tailLines(stderr),
    },
  };
}

function readReportCheck({ id, reportName, relativePath }) {
  const absolutePath = path.resolve(ROOT, relativePath);
  const report = readJsonSafe(absolutePath);
  const exists = fs.existsSync(absolutePath);
  const pass = exists && extractPass(report);
  const hasCanonicalName = report && typeof report.reportName === 'string' && report.reportName.trim();
  const reportNameMatches = !reportName || !hasCanonicalName || report.reportName === reportName;

  return {
    id,
    pass: Boolean(pass && reportNameMatches),
    details: {
      exists,
      path: relativePath,
      reportName: report && typeof report.reportName === 'string' ? report.reportName : null,
      generatedAt: report && typeof report.generatedAt === 'string' ? report.generatedAt : null,
      reportNameMatches,
    },
  };
}

function sourceContainsCheck({ id, relativePath, requiredSnippets }) {
  const absolutePath = path.resolve(ROOT, relativePath);
  const exists = fs.existsSync(absolutePath);
  const source = exists ? fs.readFileSync(absolutePath, 'utf8') : '';
  const missingSnippets = requiredSnippets.filter((snippet) => !source.includes(snippet));
  return {
    id,
    pass: exists && missingSnippets.length === 0,
    details: {
      exists,
      path: relativePath,
      requiredSnippetCount: requiredSnippets.length,
      missingSnippets,
    },
  };
}

function summarizeResult(checks) {
  const failed = checks.filter((check) => !check.pass);
  return {
    pass: failed.length === 0,
    failedChecks: failed.map((check) => check.id),
  };
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  const credentialsPath = path.resolve(ROOT, args.credentials);
  if (!fs.existsSync(credentialsPath)) {
    throw new Error(`Credentials file not found: ${credentialsPath}`);
  }

  const checks = [];

  checks.push(
    runNodeCommand({
      id: 'telemetry_smoke_full_168h',
      scriptPath: 'scripts/telemetry_smoke_check.js',
      args: ['--mode=full', `--hours=${args.hours}`, `--limit=${args.limit}`, '--strict'],
      env: {
        GOOGLE_APPLICATION_CREDENTIALS: credentialsPath,
        FIREBASE_PROJECT_ID: args.project,
      },
      retries: 2,
    }),
  );

  checks.push(
    runNodeCommand({
      id: 'telemetry_live_regression_168h',
      scriptPath: 'scripts/telemetry_live_regression_audit.js',
      args: [
        `--hours=${args.hours}`,
        `--limit=${args.limit}`,
        `--credentials=${args.credentials}`,
        `--project=${args.project}`,
        '--strict',
      ],
      retries: 2,
    }),
  );

  checks.push(
    runNodeCommand({
      id: 'voice_trace_continuity',
      scriptPath: 'scripts/vibe_voice_trace_continuity.js',
    }),
  );

  checks.push(
    runNodeCommand({
      id: 'stt_smoke',
      scriptPath: 'scripts/vibe_stt_smoke.js',
    }),
  );

  checks.push(
    runNodeCommand({
      id: 'tts_prosody_policy',
      scriptPath: 'scripts/vibe_tts_prosody_policy.js',
    }),
  );

  const liveRunnerArgs = ['--strict'];
  if (args.baseUrl) {
    liveRunnerArgs.push(`--base-url=${args.baseUrl}`);
  }
  checks.push(
    runNodeCommand({
      id: 'voice_live_runner',
      scriptPath: 'scripts/vibe_voice_live_runner.js',
      args: liveRunnerArgs,
      retries: 1,
    }),
  );

  checks.push(
    runNodeCommand({
      id: 'firebase_wiring_bos_noncore',
      scriptPath: 'scripts/audit_firebase_ui_field_wiring_bulk.js',
      args: [
        `--env=${args.env}`,
        '--strict',
        `--report-name=${args.wiringReportName}`,
      ],
      retries: 2,
    }),
  );

  checks.push(
    runNodeCommand({
      id: 'master_telemetry_audit',
      scriptPath: 'scripts/vibe_telemetry_audit_master.js',
      args: [
        `--env=${args.env}`,
        '--strict',
        `--hours=${args.hours}`,
        `--limit=${args.limit}`,
        `--project=${args.project}`,
        `--credentials=${args.credentials}`,
      ],
      retries: 2,
    }),
  );

  checks.push(
    runNodeCommand({
      id: 'ci_blocker_gate',
      scriptPath: 'scripts/vibe_ci_blocker_gate.js',
      args: ['--strict'],
    }),
  );

  checks.push(
    sourceContainsCheck({
      id: 'voice_bos_learning_intelligence_wiring',
      relativePath: 'functions/src/voiceSystem.ts',
      requiredSnippets: [
        'deriveUnderstandingSignal',
        'buildAdaptiveLocalizedResponse',
        "collection('bosLearningProfiles')",
        'upsertBosLearningProfile',
        'understandingIntent',
      ],
    }),
  );
  checks.push(
    sourceContainsCheck({
      id: 'bos_runtime_voice_understanding_fusion',
      relativePath: 'functions/src/bosRuntime.ts',
      requiredSnippets: [
        'readVoiceUnderstandingObservation',
        'understandingConfidence',
        'voice_understanding',
        'avgUnderstandingConfidence',
      ],
    }),
  );

  checks.push(
    readReportCheck({
      id: 'report_voice_trace_continuity',
      reportName: 'voice-trace-continuity',
      relativePath: 'audit-pack/reports/voice-trace-continuity.json',
    }),
  );
  checks.push(
    readReportCheck({
      id: 'report_stt_smoke',
      reportName: 'stt-smoke',
      relativePath: 'audit-pack/reports/stt-smoke.json',
    }),
  );
  checks.push(
    readReportCheck({
      id: 'report_tts_prosody_policy',
      reportName: 'tts-prosody-policy',
      relativePath: 'audit-pack/reports/tts-prosody-policy.json',
    }),
  );
  checks.push(
    readReportCheck({
      id: 'report_voice_live_runner',
      reportName: 'vibe-voice-all-report',
      relativePath: 'audit-pack/reports/vibe-voice-all-report.json',
    }),
  );
  checks.push(
    readReportCheck({
      id: 'report_firebase_wiring_bos_noncore',
      reportName: args.wiringReportName,
      relativePath: `audit-pack/reports/${args.wiringReportName}.json`,
    }),
  );
  checks.push(
    readReportCheck({
      id: 'report_master_telemetry_audit',
      reportName: 'vibe-telemetry-audit-master',
      relativePath: 'audit-pack/reports/vibe-telemetry-audit-master.json',
    }),
  );
  checks.push(
    readReportCheck({
      id: 'report_ci_blocker_gate',
      reportName: 'vibe-ci-blocker-gate',
      relativePath: 'audit-pack/reports/vibe-ci-blocker-gate.json',
    }),
  );

  const summary = summarizeResult(checks);
  const report = buildCanonicalReport({
    reportName: args.reportName,
    env: args.env,
    pass: summary.pass,
    checks,
    metadata: {
      project: args.project,
      credentials: args.credentials,
      hours: args.hours,
      limit: args.limit,
      baseUrl: args.baseUrl || '(default)',
      wiringReportName: args.wiringReportName,
      failedChecks: summary.failedChecks,
    },
  });
  const reportFile = writeCanonicalReport(args.reportName, report);

  console.log(
    JSON.stringify(
      {
        status: summary.pass ? 'PASS' : 'FAIL',
        report: path.relative(ROOT, reportFile),
        failedChecks: summary.failedChecks,
      },
      null,
      2,
    ),
  );

  if (!summary.pass && args.strict) {
    process.exitCode = 1;
  }
}

try {
  main();
} catch (error) {
  const message = error && error.message ? error.message : String(error);
  console.error(`FATAL: ${message}`);
  process.exit(1);
}
