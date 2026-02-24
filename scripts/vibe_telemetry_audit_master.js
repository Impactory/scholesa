#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const cp = require('child_process');
const {
  buildCanonicalReport,
  ensureReportDir,
  extractPass,
  legacyFailuresToChecks,
  readJsonSafe,
  reportPath,
  resolveEnv,
  validateCanonicalReport,
  writeCanonicalReport,
} = require('./vibe_audit_report_schema');

const { runVendorDependencyBan } = require('../services/scholesa-compliance/src/checks/vendorDependencyBan');
const { runVendorDomainBan } = require('../services/scholesa-compliance/src/checks/vendorDomainBan');
const { runVendorSecretBan } = require('../services/scholesa-compliance/src/checks/vendorSecretBan');
const { runRuntimeEgressProof } = require('../services/scholesa-compliance/src/checks/runtimeEgressProof');
const { runLogPrivacySafety } = require('../services/scholesa-compliance/src/checks/logPrivacySafety');
const { runVoiceRetentionControls } = require('../services/scholesa-compliance/src/checks/voiceRetentionControls');
const { runTenantIsolation } = require('../services/scholesa-compliance/src/checks/tenantIsolation');
const { runInferenceAuthz } = require('../services/scholesa-compliance/src/checks/inferenceAuthz');
const { runInferenceIngressPrivate } = require('../services/scholesa-compliance/src/checks/inferenceIngressPrivate');
const { runInfraDrift } = require('../services/scholesa-compliance/src/checks/infraDrift');
const { runI18nCoverage } = require('../services/scholesa-compliance/src/checks/i18nCoverage');

const BLOCKER_REPORTS = [
  'vendor-dependency-ban',
  'vendor-domain-ban',
  'vendor-secret-ban',
  'vendor-egress-proof',
  'tenant-isolation',
  'safety-fixtures',
  'voice-retention-ttl',
  'logging-no-raw-content',
  'telemetry-schema-valid',
  'inference-authz',
  'inference-ingress-private',
  'infra-drift',
  'i18n-coverage',
];

function parseArgs(argv) {
  const defaultCredentialsPath = path.resolve(process.cwd(), 'firebase-service-account.json');
  const hasDefaultCredentials = fs.existsSync(defaultCredentialsPath);

  const args = {
    env: process.env.VIBE_ENV || process.env.NODE_ENV || 'dev',
    strict: false,
    hours: 168,
    limit: 20000,
    project: process.env.FIREBASE_PROJECT_ID,
    credentials: process.env.GOOGLE_APPLICATION_CREDENTIALS || (hasDefaultCredentials ? 'firebase-service-account.json' : undefined),
  };

  for (const arg of argv) {
    if (arg === '--strict') {
      args.strict = true;
      continue;
    }
    if (!arg.startsWith('--')) continue;
    const [rawKey, rawValue] = arg.slice(2).split('=');
    if (rawValue === undefined) continue;
    if (rawKey === 'env') args.env = rawValue;
    if (rawKey === 'hours') args.hours = Number(rawValue);
    if (rawKey === 'limit') args.limit = Number(rawValue);
    if (rawKey === 'project') args.project = rawValue;
    if (rawKey === 'credentials') args.credentials = rawValue;
  }

  args.env = resolveEnv(args.env);

  if (!args.project && args.credentials) {
    try {
      const credentialsPath = path.resolve(process.cwd(), args.credentials);
      const credentialsJson = JSON.parse(fs.readFileSync(credentialsPath, 'utf8'));
      if (typeof credentialsJson.project_id === 'string' && credentialsJson.project_id.trim()) {
        args.project = credentialsJson.project_id.trim();
      }
    } catch {
      // Ignore and let downstream checks handle missing/invalid project credentials.
    }
  }

  return args;
}

function runCommand(command) {
  try {
    const stdout = cp.execSync(command, {
      cwd: process.cwd(),
      stdio: 'pipe',
      encoding: 'utf8',
      maxBuffer: 1024 * 1024 * 64,
      shell: '/bin/zsh',
    });
    return {
      command,
      pass: true,
      stdout: String(stdout || '').trim(),
      stderr: '',
    };
  } catch (error) {
    return {
      command,
      pass: false,
      stdout: String(error.stdout || '').trim().slice(0, 8000),
      stderr: String(error.stderr || '').trim().slice(0, 8000),
      exitCode: typeof error.status === 'number' ? error.status : 1,
    };
  }
}

function legacyChecks(legacyReport) {
  if (!legacyReport || typeof legacyReport !== 'object') {
    return [
      {
        id: 'missing_legacy_report',
        pass: false,
        details: { reason: 'legacy_report_unavailable' },
      },
    ];
  }

  if (Array.isArray(legacyReport.checks) && legacyReport.checks.length > 0) {
    return legacyReport.checks.map((check, index) => ({
      id:
        (typeof check.id === 'string' && check.id) ||
        (typeof check.checkId === 'string' && check.checkId) ||
        `legacy_check_${index + 1}`,
      pass:
        typeof check.pass === 'boolean'
          ? check.pass
          : typeof check.passed === 'boolean'
          ? check.passed
          : false,
      details:
        check.details !== undefined
          ? check.details
          : {
              findings: check.findings,
              name: check.name,
            },
    }));
  }

  if (Array.isArray(legacyReport.failures)) {
    return legacyFailuresToChecks(legacyReport.failures);
  }

  if (Array.isArray(legacyReport.findings)) {
    return legacyFailuresToChecks(legacyReport.findings);
  }

  return [
    {
      id: 'legacy_summary',
      pass: extractPass(legacyReport),
      details: {
        report: legacyReport.report,
      },
    },
  ];
}

function writeFromLegacy({ reportName, env, commandResult, legacyName, extraChecks = [], metadata = {} }) {
  const legacyPath = reportPath(legacyName);
  const legacyReport = readJsonSafe(legacyPath);

  const checks = [
    {
      id: 'command_execution',
      pass: commandResult.pass,
      details: {
        command: commandResult.command,
        exitCode: commandResult.exitCode || 0,
        stderrTail: commandResult.stderr ? commandResult.stderr.split('\n').slice(-20) : [],
      },
    },
    ...legacyChecks(legacyReport),
    ...extraChecks,
  ];
  const pass = checks.every((check) => check && check.pass === true);

  const report = buildCanonicalReport({
    reportName,
    env,
    pass,
    checks,
    sourceReports: [path.relative(process.cwd(), legacyPath)],
    metadata,
  });

  return writeCanonicalReport(reportName, report);
}

function writeFromModule({ reportName, env, moduleResult, legacyName }) {
  const legacyPath = reportPath(legacyName);
  const legacyReport = readJsonSafe(legacyPath);

  const checks = [
    {
      id: 'module_execution',
      pass: moduleResult.passed,
      details: {
        checkId: moduleResult.checkId,
        findings: moduleResult.findings,
      },
    },
    ...legacyChecks(legacyReport),
  ];
  const pass = checks.every((check) => check && check.pass === true);

  const report = buildCanonicalReport({
    reportName,
    env,
    pass,
    checks,
    sourceReports: [
      path.relative(process.cwd(), legacyPath),
      typeof moduleResult.evidencePath === 'string' ? path.relative(process.cwd(), moduleResult.evidencePath) : undefined,
    ].filter(Boolean),
  });

  return writeCanonicalReport(reportName, report);
}

function parseNumberAfterName(content, variableName) {
  if (!content) return null;
  const regex = new RegExp(`${variableName}[^\\n]*\\n(?:\\s*-\\s*name:[^\\n]*\\n)?\\s*value:\\s*"(\\d+)"`, 'i');
  const match = content.match(regex);
  if (!match) return null;
  return Number(match[1]);
}

function runLoggingNoRawContent(env) {
  const moduleResult = runLogPrivacySafety();
  const legacyPath = reportPath('log-privacy-safety');
  const legacyReport = readJsonSafe(legacyPath);

  const telemetrySourcePath = path.resolve('functions/src/index.ts');
  const voiceSourcePath = path.resolve('functions/src/voiceSystem.ts');
  const telemetrySource = fs.existsSync(telemetrySourcePath) ? fs.readFileSync(telemetrySourcePath, 'utf8') : '';
  const voiceSource = fs.existsSync(voiceSourcePath) ? fs.readFileSync(voiceSourcePath, 'utf8') : '';

  const forbiddenPatterns = [
    { id: 'forbid_raw_transcript_console_log', regex: /console\.log\([^\n]*transcript/i },
    { id: 'forbid_raw_prompt_console_log', regex: /console\.log\([^\n]*prompt/i },
    { id: 'forbid_audio_mime_logging', regex: /console\.log\([^\n]*audio\/(wav|mpeg|mp3|ogg)/i },
    { id: 'forbid_email_logging_pattern', regex: /console\.log\([^\n]*[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i },
  ];

  const patternChecks = forbiddenPatterns.map((pattern) => ({
    id: pattern.id,
    pass: !pattern.regex.test(`${voiceSource}\n${telemetrySource}`),
    details: { pattern: pattern.regex.toString() },
  }));

  const checks = [
    {
      id: 'base_log_privacy_safety_check',
      pass: moduleResult.passed && extractPass(legacyReport),
      details: {
        evidencePath: path.relative(process.cwd(), moduleResult.evidencePath),
      },
    },
    {
      id: 'telemetry_pii_blocklist_includes_coppa_forbidden_keys',
      pass:
        telemetrySource.includes('TELEMETRY_PII_KEY_BLOCKLIST') &&
        telemetrySource.includes("'prompt'") &&
        telemetrySource.includes("'response'") &&
        telemetrySource.includes("'content'") &&
        telemetrySource.includes("'text'"),
      details: {
        telemetrySourcePath: path.relative(process.cwd(), telemetrySourcePath),
      },
    },
    ...patternChecks,
  ];

  const pass = checks.every((check) => check.pass);
  const report = buildCanonicalReport({
    reportName: 'logging-no-raw-content',
    env,
    pass,
    checks,
    sourceReports: [path.relative(process.cwd(), legacyPath)],
  });

  writeCanonicalReport('logging-no-raw-content', report);
}

function runTelemetrySchemaValid(env, args) {
  const bosSchemaPath = path.resolve('docs/BOS_MIA_EVENT_SCHEMA.md');
  const contractsPath = path.resolve('docs/infrastructure/blueprints/hybrid-cloudrun-gke-gpu/03-ai/01-internal-ai-service-contracts.md');
  const telemetryAuditScriptPath = path.resolve('scripts/telemetry_live_regression_audit.js');
  const serviceMapPath = path.resolve('docs/infrastructure/blueprints/hybrid-cloudrun-gke-gpu/00-architecture/02-service-map.md');

  const bosSchema = fs.existsSync(bosSchemaPath) ? fs.readFileSync(bosSchemaPath, 'utf8') : '';
  const contracts = fs.existsSync(contractsPath) ? fs.readFileSync(contractsPath, 'utf8') : '';
  const telemetryAuditScript = fs.existsSync(telemetryAuditScriptPath)
    ? fs.readFileSync(telemetryAuditScriptPath, 'utf8')
    : '';
  const serviceMap = fs.existsSync(serviceMapPath) ? fs.readFileSync(serviceMapPath, 'utf8') : '';

  const roleMap = {
    learner: 'student',
    educator: 'teacher',
    site: 'admin',
    hq: 'admin',
    partner: 'admin',
  };

  const gradeBandMap = {
    'K-5': 'k5',
    K_5: 'k5',
    G1_3: 'k5',
    G4_6: 'k5',
    '6-8': 'ms',
    G6_8: 'ms',
    G7_9: 'ms',
    '9-12': 'hs',
    G9_12: 'hs',
    G10_12: 'hs',
  };

  const requiredFieldChecks = [
    {
      id: 'required_schema_fields_documented',
      pass:
        bosSchema.includes('eventType') &&
        bosSchema.includes('timestamp') &&
        bosSchema.includes('siteId') &&
        bosSchema.includes('actorRole') &&
        bosSchema.includes('gradeBand') &&
        bosSchema.includes('locale'),
      details: { bosSchemaPath: path.relative(process.cwd(), bosSchemaPath) },
    },
    {
      id: 'trace_continuity_markers_present',
      pass:
        contracts.includes('X-Trace-Id') &&
        telemetryAuditScript.includes('traceId') &&
        serviceMap.includes('scholesa-api') &&
        serviceMap.includes('scholesa-ai') &&
        serviceMap.includes('scholesa-guard') &&
        serviceMap.includes('scholesa-stt') &&
        serviceMap.includes('scholesa-tts'),
      details: {
        contractsPath: path.relative(process.cwd(), contractsPath),
        telemetryAuditScriptPath: path.relative(process.cwd(), telemetryAuditScriptPath),
        serviceMapPath: path.relative(process.cwd(), serviceMapPath),
      },
    },
    {
      id: 'normalization_maps_defined',
      pass: Object.keys(roleMap).length > 0 && Object.keys(gradeBandMap).length > 0,
      details: { roleMap, gradeBandMap },
    },
  ];

  let liveAuditResult = {
    pass: false,
    command: 'node scripts/telemetry_live_regression_audit.js',
    skipped: false,
    reason: '',
  };

  const commandParts = [
    'node scripts/telemetry_live_regression_audit.js',
    '--strict',
    `--hours=${Number.isFinite(args.hours) ? args.hours : 168}`,
    `--limit=${Number.isFinite(args.limit) ? args.limit : 20000}`,
  ];
  if (args.project) commandParts.push(`--project=${args.project}`);
  if (args.credentials) commandParts.push(`--credentials=${args.credentials}`);

  const liveResult = runCommand(commandParts.join(' '));
  if (!liveResult.pass) {
    liveAuditResult = {
      pass: false,
      command: liveResult.command,
      skipped: !args.credentials,
      reason: args.credentials ? 'live_audit_command_failed' : 'missing_credentials',
      stderrTail: liveResult.stderr ? liveResult.stderr.split('\n').slice(-20) : [],
    };
  } else {
    liveAuditResult = {
      pass: /Result:\s+PASS/i.test(liveResult.stdout),
      command: liveResult.command,
      skipped: false,
      reason: '',
      stdoutTail: liveResult.stdout.split('\n').slice(-20),
    };
  }

  const evidencePath = path.resolve(
    'docs/Scholesa_Enterprise_Audit_MD_Pack/EVIDENCE/telemetry-live-audit.txt',
  );
  let evidenceFallback = {
    pass: false,
    reason: 'missing_evidence_file',
    ageHours: null,
  };
  if (fs.existsSync(evidencePath)) {
    const content = fs.readFileSync(evidencePath, 'utf8');
    const stats = fs.statSync(evidencePath);
    const ageHours = (Date.now() - stats.mtimeMs) / (1000 * 60 * 60);
    const hasPassMarker = /Result:\s+PASS/i.test(content);
    const maxEvidenceAgeHours = 24 * 45;
    const recentEnough = ageHours <= maxEvidenceAgeHours;
    evidenceFallback = {
      pass: hasPassMarker && recentEnough,
      reason: hasPassMarker
        ? recentEnough
          ? 'pass_marker_and_recent'
          : 'pass_marker_but_stale'
        : 'missing_pass_marker',
      ageHours: Number(ageHours.toFixed(2)),
      maxEvidenceAgeHours,
      evidencePath: path.relative(process.cwd(), evidencePath),
    };
  }

  const liveOrEvidencePass = liveAuditResult.pass;

  const checks = [
    ...requiredFieldChecks,
    {
      id: 'live_telemetry_schema_and_trace_validation',
      pass: liveOrEvidencePass,
      details: {
        liveAudit: liveAuditResult,
        evidenceFallback,
      },
    },
  ];

  const pass = checks.every((check) => check.pass);
  const report = buildCanonicalReport({
    reportName: 'telemetry-schema-valid',
    env,
    pass,
    checks,
    metadata: {
      normalization: {
        roleMap,
        gradeBandMap,
      },
    },
  });

  writeCanonicalReport('telemetry-schema-valid', report);
}

function runVoiceRetentionTtl(env) {
  const moduleResult = runVoiceRetentionControls();
  const legacyPath = reportPath('voice-retention-controls');
  const legacyReport = readJsonSafe(legacyPath);

  const sttDeploymentPath = path.resolve('docs/k8s/20-stt-inference-deployment.yaml');
  const ttsDeploymentPath = path.resolve('docs/k8s/30-tts-inference-deployment.yaml');
  const retentionDocPath = path.resolve('docs/infrastructure/blueprints/hybrid-cloudrun-gke-gpu/02-data/01-storage-and-retention.md');
  const opsRunbookPath = path.resolve('docs/infrastructure/blueprints/hybrid-cloudrun-gke-gpu/06-ops/01-runbooks.md');

  const sttDeployment = fs.existsSync(sttDeploymentPath) ? fs.readFileSync(sttDeploymentPath, 'utf8') : '';
  const ttsDeployment = fs.existsSync(ttsDeploymentPath) ? fs.readFileSync(ttsDeploymentPath, 'utf8') : '';
  const retentionDoc = fs.existsSync(retentionDocPath) ? fs.readFileSync(retentionDocPath, 'utf8') : '';
  const opsRunbook = fs.existsSync(opsRunbookPath) ? fs.readFileSync(opsRunbookPath, 'utf8') : '';

  const sttTtl = parseNumberAfterName(sttDeployment, 'AUDIO_TTL_MINUTES');
  const ttsTtl = parseNumberAfterName(ttsDeployment, 'TTS_TTL_MINUTES');

  const checks = [
    {
      id: 'base_voice_retention_controls_check',
      pass: moduleResult.passed && extractPass(legacyReport),
      details: {
        evidencePath: path.relative(process.cwd(), moduleResult.evidencePath),
      },
    },
    {
      id: 'stt_ttl_le_60_minutes',
      pass: typeof sttTtl === 'number' && sttTtl <= 60,
      details: { sttTtl, sttDeploymentPath: path.relative(process.cwd(), sttDeploymentPath) },
    },
    {
      id: 'tts_ttl_le_60_minutes',
      pass: typeof ttsTtl === 'number' && ttsTtl <= 60,
      details: { ttsTtl, ttsDeploymentPath: path.relative(process.cwd(), ttsDeploymentPath) },
    },
    {
      id: 'voice_buckets_excluded_from_long_term_backups',
      pass:
        retentionDoc.includes('Not included in long-term backups') &&
        retentionDoc.includes('TTL: 1 hour'),
      details: { retentionDocPath: path.relative(process.cwd(), retentionDocPath) },
    },
    {
      id: 'voice_ttl_runbook_present',
      pass:
        opsRunbook.includes('RUNBOOK 2 — Voice TTL Failure') &&
        opsRunbook.includes('Verify bucket lifecycle policy'),
      details: { opsRunbookPath: path.relative(process.cwd(), opsRunbookPath) },
    },
  ];

  const pass = checks.every((check) => check.pass);
  const report = buildCanonicalReport({
    reportName: 'voice-retention-ttl',
    env,
    pass,
    checks,
    sourceReports: [path.relative(process.cwd(), legacyPath)],
  });

  writeCanonicalReport('voice-retention-ttl', report);
}

function runMasterAudit(args) {
  ensureReportDir();

  const phaseReports = {};

  // Phase 1 — Static Scan
  const depCommand = runCommand('node scripts/ai_dependency_ban.js');
  runVendorDependencyBan();
  phaseReports.vendorDependencyBan = writeFromLegacy({
    reportName: 'vendor-dependency-ban',
    env: args.env,
    commandResult: depCommand,
    legacyName: 'ai-dependency-ban',
    metadata: { phase: 1 },
  });

  const domainCommand = runCommand('node scripts/ai_domain_ban.js');
  runVendorDomainBan();
  phaseReports.vendorDomainBan = writeFromLegacy({
    reportName: 'vendor-domain-ban',
    env: args.env,
    commandResult: domainCommand,
    legacyName: 'ai-domain-ban',
    metadata: { phase: 1 },
  });

  const vendorSecretResult = runVendorSecretBan();
  phaseReports.vendorSecretBan = writeFromModule({
    reportName: 'vendor-secret-ban',
    env: args.env,
    moduleResult: vendorSecretResult,
    legacyName: 'vendor-secret-ban',
  });

  // Phase 2 — Runtime Integration Tests
  const tenantIsolationResult = runTenantIsolation();
  phaseReports.tenantIsolation = writeFromModule({
    reportName: 'tenant-isolation',
    env: args.env,
    moduleResult: tenantIsolationResult,
    legacyName: 'tenant-isolation',
  });

  const inferenceAuthzResult = runInferenceAuthz();
  phaseReports.inferenceAuthz = writeFromModule({
    reportName: 'inference-authz',
    env: args.env,
    moduleResult: inferenceAuthzResult,
    legacyName: 'inference-authz',
  });

  const inferenceIngressPrivateResult = runInferenceIngressPrivate();
  phaseReports.inferenceIngressPrivate = writeFromModule({
    reportName: 'inference-ingress-private',
    env: args.env,
    moduleResult: inferenceIngressPrivateResult,
    legacyName: 'inference-ingress-private',
  });

  const aiEgressCommand = runCommand('node scripts/ai_egress_none.js');
  const voiceEgressCommand = runCommand('node scripts/vibe_voice_egress.js');
  const runtimeEgressResult = runRuntimeEgressProof();
  phaseReports.vendorEgressProof = writeFromModule({
    reportName: 'vendor-egress-proof',
    env: args.env,
    moduleResult: runtimeEgressResult,
    legacyName: 'vendor-egress-proof',
  });

  const safetyCommand = runCommand('node scripts/vibe_voice_abuse_safety.js');
  phaseReports.safetyFixtures = writeFromLegacy({
    reportName: 'safety-fixtures',
    env: args.env,
    commandResult: safetyCommand,
    legacyName: 'voice-abuse-safety-refusals',
    extraChecks: [
      {
        id: 'ai_egress_none_command',
        pass: aiEgressCommand.pass,
        details: {
          command: aiEgressCommand.command,
          exitCode: aiEgressCommand.exitCode || 0,
        },
      },
      {
        id: 'voice_egress_command',
        pass: voiceEgressCommand.pass,
        details: {
          command: voiceEgressCommand.command,
          exitCode: voiceEgressCommand.exitCode || 0,
        },
      },
    ],
    metadata: { phase: 2 },
  });

  // Phase 3 — Telemetry Inspection
  runLoggingNoRawContent(args.env);
  phaseReports.loggingNoRawContent = reportPath('logging-no-raw-content');

  runTelemetrySchemaValid(args.env, args);
  phaseReports.telemetrySchemaValid = reportPath('telemetry-schema-valid');

  // Phase 4 — Voice Retention Verification
  runVoiceRetentionTtl(args.env);
  phaseReports.voiceRetentionTtl = reportPath('voice-retention-ttl');

  // Phase 5 — Infrastructure Drift Detection
  const infraDriftResult = runInfraDrift();
  phaseReports.infraDrift = writeFromModule({
    reportName: 'infra-drift',
    env: args.env,
    moduleResult: infraDriftResult,
    legacyName: 'infra-drift',
  });

  // Phase 6 — i18n Coverage
  const i18nCoverageResult = runI18nCoverage();
  phaseReports.i18nCoverage = writeFromModule({
    reportName: 'i18n-coverage',
    env: args.env,
    moduleResult: i18nCoverageResult,
    legacyName: 'i18n-coverage',
  });

  const blockerResults = BLOCKER_REPORTS.map((reportName) => {
    const report = readJsonSafe(reportPath(reportName));
    const schema = validateCanonicalReport(report || {});
    const pass = extractPass(report || {});
    return {
      reportName,
      filePath: path.relative(process.cwd(), reportPath(reportName)),
      schemaOk: schema.ok,
      pass,
      errors: schema.errors,
    };
  });

  const failedBlockers = blockerResults.filter((result) => !result.schemaOk || !result.pass);

  const summaryReport = buildCanonicalReport({
    reportName: 'vibe-telemetry-audit-master',
    env: args.env,
    pass: failedBlockers.length === 0,
    checks: blockerResults.map((result) => ({
      id: `blocker_${result.reportName}`,
      pass: result.schemaOk && result.pass,
      details: {
        filePath: result.filePath,
        schemaOk: result.schemaOk,
        reportPass: result.pass,
        errors: result.errors,
      },
    })),
    metadata: {
      phases: {
        phase1: ['vendor-dependency-ban', 'vendor-domain-ban', 'vendor-secret-ban'],
        phase2: ['tenant-isolation', 'inference-authz', 'inference-ingress-private', 'vendor-egress-proof', 'safety-fixtures'],
        phase3: ['logging-no-raw-content', 'telemetry-schema-valid'],
        phase4: ['voice-retention-ttl'],
        phase5: ['infra-drift'],
        phase6: ['i18n-coverage'],
      },
      failedBlockers,
    },
  });

  const summaryPath = writeCanonicalReport('vibe-telemetry-audit-master', summaryReport);

  const output = {
    status: failedBlockers.length === 0 ? 'PASS' : 'FAIL',
    env: args.env,
    summaryReport: path.relative(process.cwd(), summaryPath),
    blockerResults,
    failedBlockers,
  };

  process.stdout.write(JSON.stringify(output, null, 2) + '\n');

  if (failedBlockers.length > 0 && args.strict) {
    process.exitCode = 1;
  }
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  runMasterAudit(args);
}

main();
