const cp = require('child_process');
const fs = require('fs');
const path = require('path');
const {
  REPO_ROOT,
  reportPath,
  writeJson,
  nowIso,
  readTextSafe,
  toCanonicalReport,
} = require('../utils');

const REQUIRED_LOCALES = ['en', 'zh-CN', 'zh-TW', 'th'];

function readJsonSafe(filePath) {
  const raw = readTextSafe(filePath);
  if (!raw) return null;
  try {
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

function runCommand(command) {
  try {
    cp.execSync(command, {
      cwd: REPO_ROOT,
      stdio: 'pipe',
      encoding: 'utf8',
      maxBuffer: 1024 * 1024 * 16,
      shell: '/bin/zsh',
    });
    return { passed: true, command };
  } catch (error) {
    return {
      passed: false,
      command,
      exitCode: typeof error.status === 'number' ? error.status : 1,
      stdout: String(error.stdout || '').slice(0, 4000),
      stderr: String(error.stderr || '').slice(0, 4000),
    };
  }
}

function runI18nCoverage() {
  const findings = [];

  const localeConfigPath = path.join(REPO_ROOT, 'src/lib/i18n/config.ts');
  const localeHeadersPath = path.join(REPO_ROOT, 'src/lib/i18n/localeHeaders.ts');
  const aiContractsPath = path.join(REPO_ROOT, 'docs/infrastructure/blueprints/hybrid-cloudrun-gke-gpu/03-ai/01-internal-ai-service-contracts.md');
  const voiceSystemPath = path.join(REPO_ROOT, 'functions/src/voiceSystem.ts');
  const voiceClientPath = path.join(REPO_ROOT, 'src/lib/voice/voiceService.ts');
  const sttSmokePath = path.join(REPO_ROOT, 'scripts/vibe_stt_smoke.js');
  const ttsPronunciationPath = path.join(REPO_ROOT, 'scripts/vibe_tts_pronunciation.js');
  const ttsProsodyPath = path.join(REPO_ROOT, 'scripts/vibe_tts_prosody_policy.js');
  const voiceFixturesPath = path.join(REPO_ROOT, 'scripts/voice_vibe_shared.js');

  const localeConfig = readTextSafe(localeConfigPath) || '';
  const localeHeaders = readTextSafe(localeHeadersPath) || '';
  const aiContracts = readTextSafe(aiContractsPath) || '';
  const voiceSystem = readTextSafe(voiceSystemPath) || '';
  const voiceClient = readTextSafe(voiceClientPath) || '';
  const sttSmokeScript = readTextSafe(sttSmokePath) || '';
  const ttsPronunciationScript = readTextSafe(ttsPronunciationPath) || '';
  const ttsProsodyScript = readTextSafe(ttsProsodyPath) || '';
  const voiceFixturesScript = readTextSafe(voiceFixturesPath) || '';

  const localePackChecks = REQUIRED_LOCALES.map((locale) => {
    const filePath = path.join(REPO_ROOT, `packages/i18n/locales/${locale}.json`);
    return {
      id: `locale_pack_${locale}`,
      pass: fs.existsSync(filePath),
      details: { filePath: path.relative(REPO_ROOT, filePath) },
    };
  });

  const complianceNoticeChecks = REQUIRED_LOCALES.map((locale) => {
    const fileKey = locale === 'en' ? 'en' : locale;
    const filePath = path.join(REPO_ROOT, `docs/compliance/notices/parent_notice_${fileKey}.md`);
    return {
      id: `compliance_notice_${locale}`,
      pass: fs.existsSync(filePath),
      details: { filePath: path.relative(REPO_ROOT, filePath) },
    };
  });

  const apiLocaleScriptResult = runCommand('node scripts/vibe_api_locale.js');
  const apiLocaleReportPath = path.join(REPO_ROOT, 'audit-pack/reports/vibe-api-locale-report.json');
  const apiLocaleReport = readJsonSafe(apiLocaleReportPath);

  const checks = [
    {
      id: 'supported_locales_include_required',
      pass: REQUIRED_LOCALES.every((locale) => localeConfig.includes(`'${locale}'`)),
      details: { localeConfigPath: path.relative(REPO_ROOT, localeConfigPath) },
    },
    {
      id: 'api_locale_headers_enforced',
      pass:
        localeHeaders.includes('Accept-Language') &&
        localeHeaders.includes('X-Scholesa-Locale') &&
        localeHeaders.includes('resolveRequestLocale'),
      details: { localeHeadersPath: path.relative(REPO_ROOT, localeHeadersPath) },
    },
    {
      id: 'ai_contracts_include_locale_header',
      pass: aiContracts.includes('X-Locale'),
      details: { aiContractsPath: path.relative(REPO_ROOT, aiContractsPath) },
    },
    {
      id: 'voice_system_supports_required_locales',
      pass: REQUIRED_LOCALES.every((locale) => voiceSystem.includes(`'${locale}'`)),
      details: { voiceSystemPath: path.relative(REPO_ROOT, voiceSystemPath) },
    },
    {
      id: 'voice_client_includes_locale_headers',
      pass:
        voiceClient.includes("'x-scholesa-locale'") &&
        voiceClient.includes("'x-request-id'") &&
        voiceClient.includes("formData.append('locale', locale)"),
      details: { voiceClientPath: path.relative(REPO_ROOT, voiceClientPath) },
    },
    {
      id: 'voice_live_checks_send_locale_headers',
      pass:
        sttSmokeScript.includes("'x-scholesa-locale'") &&
        ttsPronunciationScript.includes("'x-scholesa-locale'") &&
        ttsProsodyScript.includes("'x-scholesa-locale'") &&
        voiceFixturesScript.includes("'x-scholesa-locale'"),
      details: {
        sttSmokePath: path.relative(REPO_ROOT, sttSmokePath),
        ttsPronunciationPath: path.relative(REPO_ROOT, ttsPronunciationPath),
        ttsProsodyPath: path.relative(REPO_ROOT, ttsProsodyPath),
        voiceFixturesPath: path.relative(REPO_ROOT, voiceFixturesPath),
      },
    },
    {
      id: 'vibe_api_locale_report_passed',
      pass:
        apiLocaleScriptResult.passed &&
        Boolean(apiLocaleReport && (apiLocaleReport.passed === true || apiLocaleReport.pass === true)),
      details: {
        command: apiLocaleScriptResult.command,
        commandPassed: apiLocaleScriptResult.passed,
        apiLocaleReportPath: path.relative(REPO_ROOT, apiLocaleReportPath),
      },
    },
    ...localePackChecks,
    ...complianceNoticeChecks,
  ];

  for (const check of checks) {
    if (!check.pass) findings.push(`failed_check:${check.id}`);
  }

  const passed = findings.length === 0;
  const legacyReport = {
    report: 'i18n-coverage',
    generatedAt: nowIso(),
    passed,
    findings,
    checks,
    requiredLocales: REQUIRED_LOCALES,
  };

  const report = toCanonicalReport({
    reportName: 'i18n-coverage',
    passed,
    generatedAt: legacyReport.generatedAt,
    checks: checks.map((check) => ({ id: check.id, pass: check.pass, details: check.details })),
    legacy: legacyReport,
  });

  const outputPath = reportPath('i18n-coverage');
  writeJson(outputPath, report);

  return {
    checkId: 'i18n_coverage',
    passed,
    findings,
    evidencePath: outputPath,
    details: { localeCount: REQUIRED_LOCALES.length },
  };
}

module.exports = {
  runI18nCoverage,
};
