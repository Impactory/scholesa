const path = require('path');
const {
  REPO_ROOT,
  reportPath,
  writeJson,
  nowIso,
  readTextSafe,
  toCanonicalReport,
} = require('../utils');

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
  const checkMap = {
    telemetryPath,
    voicePath,
    telemetryPiiBlocklistPresent: Boolean(telemetry && telemetry.includes('TELEMETRY_PII_KEY_BLOCKLIST')),
    voiceRedactionPresent: Boolean(voice && voice.includes('redactTextForSpeech')),
  };

  const legacyReport = {
    report: 'log-privacy-safety',
    generatedAt: nowIso(),
    passed,
    findings,
    checks: checkMap,
  };

  const report = toCanonicalReport({
    reportName: 'log-privacy-safety',
    passed,
    generatedAt: legacyReport.generatedAt,
    checks: [
      {
        id: 'telemetry_pii_blocklist_present',
        pass: checkMap.telemetryPiiBlocklistPresent,
        details: { telemetryPath },
      },
      {
        id: 'voice_redaction_present',
        pass: checkMap.voiceRedactionPresent,
        details: { voicePath },
      },
      {
        id: 'no_transcript_console_logging',
        pass: !(voice && /console\.log\(.*transcript/i.test(voice)),
        details: { voicePath },
      },
      {
        id: 'no_raw_voice_collection_logging',
        pass: !(voice && /collection\(['"]voiceRawLogs['"]\)/i.test(voice)),
        details: { voicePath },
      },
    ],
    legacy: legacyReport,
  });

  const outputPath = reportPath('log-privacy-safety');
  writeJson(outputPath, report);

  return {
    checkId: 'log_privacy_safety',
    passed,
    findings,
    evidencePath: outputPath,
    details: checkMap,
  };
}

module.exports = {
  runLogPrivacySafety,
};
