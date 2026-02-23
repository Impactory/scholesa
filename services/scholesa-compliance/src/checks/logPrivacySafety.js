const path = require('path');
const { REPO_ROOT, reportPath, writeJson, nowIso, readTextSafe } = require('../utils');

function runLogPrivacySafety() {
  const findings = [];

  const telemetryPath = path.join(REPO_ROOT, 'functions/src/index.ts');
  const voicePath = path.join(REPO_ROOT, 'functions/src/voiceSystem.ts');

  const telemetry = readTextSafe(telemetryPath);
  const voice = readTextSafe(voicePath);

  if (!telemetry || !telemetry.includes('TELEMETRY_PII_KEY_BLOCKLIST')) {
    findings.push('telemetry PII key blocklist missing');
  }

  if (!voice || !voice.includes('redactTextForSpeech')) {
    findings.push('voice redaction function missing');
  }

  if (voice && /console\.log\(.*transcript/i.test(voice)) {
    findings.push('raw transcript logging detected in voice system');
  }

  if (voice && /collection\(['"]voiceRawLogs['"]\)/i.test(voice)) {
    findings.push('raw voice logging collection detected');
  }

  const passed = findings.length === 0;
  const report = {
    report: 'log-privacy-safety',
    generatedAt: nowIso(),
    passed,
    findings,
    checks: {
      telemetryPath,
      voicePath,
      telemetryPiiBlocklistPresent: Boolean(telemetry && telemetry.includes('TELEMETRY_PII_KEY_BLOCKLIST')),
      voiceRedactionPresent: Boolean(voice && voice.includes('redactTextForSpeech')),
    },
  };

  const outputPath = reportPath('log-privacy-safety');
  writeJson(outputPath, report);

  return {
    checkId: 'log_privacy_safety',
    passed,
    findings,
    evidencePath: outputPath,
    details: report.checks,
  };
}

module.exports = {
  runLogPrivacySafety,
};
