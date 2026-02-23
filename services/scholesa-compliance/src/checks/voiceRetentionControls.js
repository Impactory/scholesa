const path = require('path');
const { REPO_ROOT, reportPath, writeJson, nowIso, readTextSafe } = require('../utils');

function runVoiceRetentionControls() {
  const findings = [];

  const voiceSystemPath = path.join(REPO_ROOT, 'functions/src/voiceSystem.ts');
  const voiceSystem = readTextSafe(voiceSystemPath);

  if (!voiceSystem) {
    findings.push('voiceSystem.ts not found');
  } else {
    if (!voiceSystem.includes('AUDIO_TOKEN_TTL_MS')) {
      findings.push('missing AUDIO_TOKEN_TTL_MS control for ephemeral audio URLs');
    }
    if (!voiceSystem.includes('K-5') && !voiceSystem.includes('K_5')) {
      findings.push('missing K-5 safe mode markers');
    }

    const rawAudioPersistenceMarkers = [
      'bucket.upload',
      'file.save(',
      'collection(\'rawAudio\')',
      'collection("rawAudio")',
      'rawAudio',
    ];

    const persistentHits = rawAudioPersistenceMarkers.filter((marker) => voiceSystem.includes(marker));
    if (persistentHits.length > 0) {
      findings.push(`raw audio persistence marker(s) present: ${persistentHits.join(', ')}`);
    }
  }

  const passed = findings.length === 0;
  const report = {
    report: 'voice-retention-controls',
    generatedAt: nowIso(),
    passed,
    findings,
    checks: {
      voiceSystemPath,
      hasAudioTokenTtl: Boolean(voiceSystem && voiceSystem.includes('AUDIO_TOKEN_TTL_MS')),
      hasK5Policy: Boolean(voiceSystem && (voiceSystem.includes('K-5') || voiceSystem.includes('K_5'))),
      storesRawAudio: Boolean(
        voiceSystem && (
          voiceSystem.includes('bucket.upload') ||
          voiceSystem.includes('file.save(') ||
          voiceSystem.includes('collection(\'rawAudio\')') ||
          voiceSystem.includes('collection("rawAudio")')
        )
      ),
    },
  };

  const outputPath = reportPath('voice-retention-controls');
  writeJson(outputPath, report);

  return {
    checkId: 'voice_retention_controls',
    passed,
    findings,
    evidencePath: outputPath,
    details: report.checks,
  };
}

module.exports = {
  runVoiceRetentionControls,
};
