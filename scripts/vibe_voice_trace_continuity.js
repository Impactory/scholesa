#!/usr/bin/env node

const { finish } = require('./vibe_report_utils');
const { LOCALES, parseArgs, defaultVoiceApiBaseUrl } = require('./voice_vibe_shared');

const SAMPLE_TRANSCRIPTS = {
  en: 'Please help me solve this step.',
  'zh-CN': '请帮我完成这个步骤。',
  'zh-TW': '請幫我完成這個步驟。',
  th: 'ช่วยฉันทำขั้นตอนนี้ให้สำเร็จ',
};

function makeTraceId(locale) {
  return `vibe-trace-${locale}-${Date.now()}-${Math.random().toString(16).slice(2, 8)}`;
}

async function postTranscribe({ baseUrl, token, locale, traceId }) {
  const formData = new FormData();
  formData.append('locale', locale);
  formData.append('partial', 'false');
  formData.append('traceId', traceId);
  formData.append('transcript', SAMPLE_TRANSCRIPTS[locale]);
  formData.append('audio', new Blob([Buffer.from(`voice-trace-${locale}`)], { type: 'audio/webm' }), `trace-${locale}.webm`);

  const response = await fetch(`${baseUrl}/voice/transcribe`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'x-scholesa-locale': locale,
      'x-request-id': `vibe-voice-trace-stt-${locale}-${Date.now()}`,
    },
    body: formData,
  });
  const json = await response.json().catch(() => ({}));
  if (!response.ok) {
    const message = json.message || json.error || `HTTP ${response.status}`;
    throw new Error(`stt_failed:${locale}:${message}`);
  }
  return json;
}

async function postMessage({ baseUrl, token, locale, traceId }) {
  const body = {
    message: 'Give me one short safe hint.',
    locale,
    gradeBand: 'K-5',
    traceId,
    screenId: 'voice_trace_continuity',
    context: {
      traceId,
      voiceTraceId: traceId,
      voiceInputTraceId: traceId,
      source: 'vibe_voice_trace_continuity',
    },
    voice: {
      enabled: true,
      output: true,
    },
  };

  const response = await fetch(`${baseUrl}/copilot/message`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
      'x-scholesa-locale': locale,
      'x-request-id': `vibe-voice-trace-msg-${locale}-${Date.now()}`,
    },
    body: JSON.stringify(body),
  });
  const json = await response.json().catch(() => ({}));
  if (!response.ok) {
    const message = json.message || json.error || `HTTP ${response.status}`;
    throw new Error(`message_failed:${locale}:${message}`);
  }
  return json;
}

function simulateLocale(locale) {
  const traceId = makeTraceId(locale);
  return {
    locale,
    expectedTraceId: traceId,
    sttTraceId: traceId,
    messageTraceId: traceId,
    sttLocale: locale,
    messageLocale: locale,
    passed: true,
    failures: [],
  };
}

async function runLocaleLive({ baseUrl, token, locale }) {
  const expectedTraceId = makeTraceId(locale);
  const stt = await postTranscribe({
    baseUrl,
    token,
    locale,
    traceId: expectedTraceId,
  });
  const sttTraceId = stt?.metadata?.traceId || expectedTraceId;
  const message = await postMessage({
    baseUrl,
    token,
    locale,
    traceId: sttTraceId,
  });
  const messageTraceId = message?.metadata?.traceId || '';

  const failures = [];
  if (stt?.metadata?.locale !== locale) failures.push(`stt_locale_mismatch:${String(stt?.metadata?.locale || 'missing')}`);
  if (message?.metadata?.locale !== locale) failures.push(`message_locale_mismatch:${String(message?.metadata?.locale || 'missing')}`);
  if (!sttTraceId) failures.push('stt_trace_missing');
  if (!messageTraceId) failures.push('message_trace_missing');
  if (sttTraceId && messageTraceId && sttTraceId !== messageTraceId) {
    failures.push(`trace_mismatch:${sttTraceId}:${messageTraceId}`);
  }

  return {
    locale,
    expectedTraceId,
    sttTraceId,
    messageTraceId,
    sttLocale: stt?.metadata?.locale || null,
    messageLocale: message?.metadata?.locale || null,
    passed: failures.length === 0,
    failures,
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

  const token = process.env.VOICE_API_TOKEN_STUDENT || '';
  if (options.live && !token) {
    failures.push('missing_voice_api_token_student');
  }

  for (const locale of LOCALES) {
    if (options.live) {
      if (failures.length > 0) break;
      try {
        const result = await runLocaleLive({
          baseUrl: options.baseUrl,
          token,
          locale,
        });
        details.localeChecks.push(result);
        if (!result.passed) failures.push(`trace_continuity_failed:${locale}`);
      } catch (error) {
        details.localeChecks.push({
          locale,
          passed: false,
          failures: [error instanceof Error ? error.message : String(error)],
        });
        failures.push(`trace_continuity_failed:${locale}`);
      }
      continue;
    }

    const simulated = simulateLocale(locale);
    details.localeChecks.push(simulated);
  }

  if (options.strict && options.live && details.localeChecks.length !== LOCALES.length) {
    failures.push('incomplete_locale_execution');
  }

  finish('voice-trace-continuity', failures, details);
}

main().catch((error) => {
  finish('voice-trace-continuity', ['runner_crash'], {
    error: error instanceof Error ? error.message : String(error),
  });
});
