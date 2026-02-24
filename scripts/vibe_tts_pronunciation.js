#!/usr/bin/env node

const { finish } = require('./vibe_report_utils');
const { LOCALES, parseArgs, defaultVoiceApiBaseUrl } = require('./voice_vibe_shared');

const STEM_TERMS = {
  en: ['photosynthesis', 'numerator', 'denominator', 'evaporation'],
  'zh-CN': ['光合作用', '分子', '分母', '蒸发'],
  'zh-TW': ['光合作用', '分子', '分母', '蒸發'],
  th: ['สังเคราะห์แสง', 'ตัวเศษ', 'ตัวส่วน', 'การระเหย'],
};

async function runLivePronunciation(locale, baseUrl, token) {
  const text = `Pronunciation check: ${STEM_TERMS[locale].join(', ')}`;
  const response = await fetch(`${baseUrl}/tts/speak`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
      'x-scholesa-locale': locale,
      'x-request-id': `vibe-tts-pronunciation-${locale}-${Date.now()}`,
    },
    body: JSON.stringify({
      text,
      locale,
      gradeBand: '6-8',
      voiceProfile: `${locale}.student_neutral`,
    }),
  });
  const json = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(json.message || json.error || `HTTP ${response.status}`);
  }
  return json;
}

function runSimulatedPronunciation(locale) {
  return {
    audioUrl: `https://example.invalid/tts/${locale}.wav`,
    metadata: {
      traceId: `sim-tts-pron-${locale}-${Date.now()}`,
      modelVersion: 'scholesa-tts-internal-v1',
      latencyMs: 11,
      locale,
      voiceProfile: `${locale}.student_neutral`,
      prosodyPolicy: 'student_standard_mode',
      redactionApplied: false,
      redactionCount: 0,
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

  if (options.live && !options.baseUrl) failures.push('live_mode_requires_base_url');
  const token = process.env.VOICE_API_TOKEN_STUDENT;
  if (options.live && !token) failures.push('missing_voice_api_token_student');

  for (const locale of LOCALES) {
    const result = {
      locale,
      terms: STEM_TERMS[locale],
      passed: false,
      audioUrl: null,
      traceId: null,
      voiceProfile: null,
      failures: [],
    };
    try {
      const response = options.live
        ? await runLivePronunciation(locale, options.baseUrl, token)
        : runSimulatedPronunciation(locale);
      result.audioUrl = response.audioUrl || null;
      result.traceId = response?.metadata?.traceId || null;
      result.voiceProfile = response?.metadata?.voiceProfile || null;

      if (!response.audioUrl) result.failures.push('missing_audio_url');
      if (!response?.metadata?.locale || response.metadata.locale !== locale) {
        result.failures.push(`metadata_locale_mismatch:${response?.metadata?.locale || 'missing'}`);
      }
      if (!response?.metadata?.voiceProfile || !String(response.metadata.voiceProfile).startsWith(locale)) {
        result.failures.push('voice_profile_locale_mismatch');
      }
      if (!response?.metadata?.modelVersion) result.failures.push('missing_model_version');

      result.passed = result.failures.length === 0;
    } catch (error) {
      result.failures.push(error instanceof Error ? error.message : String(error));
    }
    details.localeChecks.push(result);
    if (!result.passed) failures.push(`tts_pronunciation_failed:${locale}`);
  }

  if (options.strict && !options.live) failures.push('strict_mode_requires_live_execution');

  finish('tts-pronunciation', failures, details);
}

main().catch((error) => {
  finish('tts-pronunciation', ['runner_crash'], {
    error: error instanceof Error ? error.message : String(error),
  });
});
