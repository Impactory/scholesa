#!/usr/bin/env node

const { finish } = require('./vibe_report_utils');
const { LOCALES, detectLanguageCompatibility, parseArgs, defaultVoiceApiBaseUrl } = require('./voice_vibe_shared');

const SAMPLE_TRANSCRIPTS = {
  en: 'Please give me a hint for this math step',
  'zh-CN': '请给我这个步骤的提示',
  'zh-TW': '請給我這個步驟的提示',
  th: 'ช่วยบอกคำใบ้สำหรับขั้นตอนนี้',
};

async function runLiveSmoke(locale, baseUrl, token) {
  const formData = new FormData();
  formData.append('locale', locale);
  formData.append('partial', 'false');
  formData.append('transcript', SAMPLE_TRANSCRIPTS[locale]);
  formData.append('audio', new Blob([Buffer.from('voice-smoke')], { type: 'audio/webm' }), `smoke-${locale}.webm`);
  const response = await fetch(`${baseUrl}/voice/transcribe`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
    },
    body: formData,
  });
  const json = await response.json().catch(() => ({}));
  if (!response.ok) {
    const errorMessage = json.message || json.error || `HTTP ${response.status}`;
    throw new Error(errorMessage);
  }
  return json;
}

function runSimulatedSmoke(locale) {
  return {
    transcript: SAMPLE_TRANSCRIPTS[locale],
    confidence: 0.96,
    metadata: {
      traceId: `sim-stt-${locale}-${Date.now()}`,
      locale,
      latencyMs: 8,
      partial: false,
      modelVersion: 'scholesa-stt-internal-v1',
    },
  };
}

async function main() {
  const options = parseArgs();
  if (!options.baseUrl) options.baseUrl = defaultVoiceApiBaseUrl().replace(/\/+$/g, '');

  const failures = [];
  const details = {
    mode: options.live ? 'live' : 'simulated',
    baseUrl: options.baseUrl || null,
    localeChecks: [],
  };

  if (options.live && !options.baseUrl) {
    failures.push('live_mode_requires_base_url');
  }

  const token = process.env.VOICE_API_TOKEN_STUDENT;
  if (options.live && !token) {
    failures.push('missing_voice_api_token_student');
  }

  for (const locale of LOCALES) {
    const result = {
      locale,
      passed: false,
      transcriptLength: 0,
      confidence: 0,
      traceId: null,
      failures: [],
      metadataLocale: null,
    };
    try {
      const response = options.live
        ? await runLiveSmoke(locale, options.baseUrl, token)
        : runSimulatedSmoke(locale);
      const transcript = typeof response.transcript === 'string' ? response.transcript : '';
      const metadataLocale = response?.metadata?.locale;
      result.transcriptLength = transcript.length;
      result.confidence = Number(response.confidence || 0);
      result.traceId = response?.metadata?.traceId || null;
      result.metadataLocale = metadataLocale || null;

      if (!transcript) result.failures.push('missing_transcript');
      if (!detectLanguageCompatibility(transcript, locale)) result.failures.push('language_mismatch');
      if (metadataLocale !== locale) result.failures.push(`metadata_locale_mismatch:${metadataLocale || 'missing'}`);
      if (!(result.confidence > 0.5 && result.confidence <= 1)) result.failures.push('confidence_out_of_range');

      result.passed = result.failures.length === 0;
    } catch (error) {
      result.failures.push(error instanceof Error ? error.message : String(error));
    }

    details.localeChecks.push(result);
    if (!result.passed) failures.push(`stt_smoke_failed:${locale}`);
  }

  if (options.strict && !options.live) {
    failures.push('strict_mode_requires_live_execution');
  }

  finish('stt-smoke', failures, details);
}

main().catch((error) => {
  finish('stt-smoke', ['runner_crash'], {
    error: error instanceof Error ? error.message : String(error),
  });
});

