#!/usr/bin/env node

const { finish } = require('./vibe_report_utils');
const { LOCALES, parseArgs, defaultVoiceApiBaseUrl } = require('./voice_vibe_shared');

async function callLiveTts({ baseUrl, token, locale, gradeBand, text }) {
  const response = await fetch(`${baseUrl}/tts/speak`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      text,
      locale,
      gradeBand,
    }),
  });
  const json = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(json.message || json.error || `HTTP ${response.status}`);
  }
  return json;
}

function simulateTts({ locale, gradeBand, role }) {
  const isK5 = role === 'student' && gradeBand === 'K-5';
  return {
    audioUrl: `https://example.invalid/${locale}/${gradeBand}.wav`,
    metadata: {
      traceId: `sim-prosody-${locale}-${gradeBand}-${Date.now()}`,
      locale,
      voiceProfile: isK5 ? `${locale}.k5_safe_neutral` : role === 'teacher' ? `${locale}.professional_concise` : `${locale}.student_neutral`,
      prosodyPolicy: isK5 ? 'k5_safe_mode' : role === 'teacher' ? 'professional_mode' : 'student_standard_mode',
      modelVersion: 'scholesa-tts-internal-v1',
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
    checks: [],
  };

  if (options.live && !options.baseUrl) failures.push('live_mode_requires_base_url');
  const studentToken = process.env.VOICE_API_TOKEN_STUDENT;
  const teacherToken = process.env.VOICE_API_TOKEN_TEACHER || process.env.VOICE_API_TOKEN_ADMIN;
  if (options.live && !studentToken) failures.push('missing_voice_api_token_student');
  if (options.live && !teacherToken) failures.push('missing_voice_api_token_teacher');

  for (const locale of LOCALES) {
    const k5Check = {
      locale,
      scenario: 'student_k5',
      passed: false,
      voiceProfile: null,
      prosodyPolicy: null,
      failures: [],
    };
    try {
      const response = options.live
        ? await callLiveTts({
            baseUrl: options.baseUrl,
            token: studentToken,
            locale,
            gradeBand: 'K-5',
            text: 'Read this in a calm and clear way for a younger learner.',
          })
        : simulateTts({ locale, gradeBand: 'K-5', role: 'student' });
      k5Check.voiceProfile = response?.metadata?.voiceProfile || null;
      k5Check.prosodyPolicy = response?.metadata?.prosodyPolicy || null;
      if (!response?.audioUrl) k5Check.failures.push('missing_audio_url');
      if (!String(response?.metadata?.voiceProfile || '').includes('k5_safe')) {
        k5Check.failures.push('expected_k5_safe_voice_profile');
      }
      if (response?.metadata?.prosodyPolicy !== 'k5_safe_mode') {
        k5Check.failures.push(`expected_k5_safe_mode:${response?.metadata?.prosodyPolicy || 'missing'}`);
      }
      k5Check.passed = k5Check.failures.length === 0;
    } catch (error) {
      k5Check.failures.push(error instanceof Error ? error.message : String(error));
    }
    details.checks.push(k5Check);
    if (!k5Check.passed) failures.push(`prosody_failed:${locale}:student_k5`);

    const teacherCheck = {
      locale,
      scenario: 'teacher_professional',
      passed: false,
      voiceProfile: null,
      prosodyPolicy: null,
      failures: [],
    };
    try {
      const response = options.live
        ? await callLiveTts({
            baseUrl: options.baseUrl,
            token: teacherToken,
            locale,
            gradeBand: '9-12',
            text: 'Provide a concise class update in professional tone.',
          })
        : simulateTts({ locale, gradeBand: '9-12', role: 'teacher' });
      teacherCheck.voiceProfile = response?.metadata?.voiceProfile || null;
      teacherCheck.prosodyPolicy = response?.metadata?.prosodyPolicy || null;
      if (!response?.audioUrl) teacherCheck.failures.push('missing_audio_url');
      if (!String(response?.metadata?.voiceProfile || '').includes('professional')) {
        teacherCheck.failures.push('expected_professional_voice_profile');
      }
      if (response?.metadata?.prosodyPolicy !== 'professional_mode') {
        teacherCheck.failures.push(`expected_professional_mode:${response?.metadata?.prosodyPolicy || 'missing'}`);
      }
      teacherCheck.passed = teacherCheck.failures.length === 0;
    } catch (error) {
      teacherCheck.failures.push(error instanceof Error ? error.message : String(error));
    }
    details.checks.push(teacherCheck);
    if (!teacherCheck.passed) failures.push(`prosody_failed:${locale}:teacher_professional`);
  }

  if (options.strict && !options.live) failures.push('strict_mode_requires_live_execution');
  finish('tts-prosody-policy', failures, details);
}

main().catch((error) => {
  finish('tts-prosody-policy', ['runner_crash'], {
    error: error instanceof Error ? error.message : String(error),
  });
});

