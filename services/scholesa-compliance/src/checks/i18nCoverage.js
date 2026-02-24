const cp = require('child_process');
const fs = require('fs');
const path = require('path');
const {
  REPO_ROOT,
  reportPath,
  writeJson,
  nowIso,
  readTextSafe,
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

  const localeConfig = readTextSafe(localeConfigPath) || '';
  const localeHeaders = readTextSafe(localeHeadersPath) || '';
  const aiContracts = readTextSafe(aiContractsPath) || '';
  const voiceSystem = readTextSafe(voiceSystemPath) || '';

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
  const report = {
    report: 'i18n-coverage',
    generatedAt: nowIso(),
    passed,
    findings,
    checks,
    requiredLocales: REQUIRED_LOCALES,
  };

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
