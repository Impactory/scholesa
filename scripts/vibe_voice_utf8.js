#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { finish } = require('./vibe_report_utils');
const { parseArgs, defaultVoiceApiBaseUrl, detectLanguageCompatibility } = require('./voice_vibe_shared');

const UTF8_FIXTURES = [
  { locale: 'en', text: 'STEM terms: numerator, denominator, photosynthesis, façade, résumé.' },
  { locale: 'zh-CN', text: '数学词汇：分子、分母、函数；学习提示保持简洁。' },
  { locale: 'zh-TW', text: '數學詞彙：分子、分母、函數；學習提示保持精簡。' },
  { locale: 'th', text: 'ภาษาไทยทดสอบเครื่องหมายผสม: กำลังใจ, การเรียนรู้, ตัวเศษ/ตัวส่วน' },
];

function toCsvRow(entry) {
  const escaped = entry.text.replace(/"/g, '""');
  return `"${entry.locale}","${escaped}"`;
}

async function runLiveRoundTrip(baseUrl, token, fixture) {
  const response = await fetch(`${baseUrl}/copilot/message`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
      'x-scholesa-locale': fixture.locale,
      'x-request-id': `vibe-voice-utf8-${fixture.locale}-${Date.now()}`,
    },
    body: JSON.stringify({
      message: fixture.text,
      locale: fixture.locale,
      screenId: 'voice_utf8_integrity',
      gradeBand: '6-8',
      voice: { enabled: true, output: false },
    }),
  });
  const json = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(json.message || json.error || `HTTP ${response.status}`);
  }
  return json;
}

async function main() {
  const options = parseArgs();
  if (!options.baseUrl) options.baseUrl = defaultVoiceApiBaseUrl().replace(/\/+$/g, '');

  const failures = [];
  const details = {
    mode: options.live ? 'live' : 'simulated',
    baseUrl: options.baseUrl || null,
    utf8RoundTrip: [],
  };

  const reportDir = path.resolve('audit-pack/reports');
  fs.mkdirSync(reportDir, { recursive: true });
  const jsonPath = path.join(reportDir, 'voice-utf8-fixture.json');
  const csvPath = path.join(reportDir, 'voice-utf8-fixture.csv');
  fs.writeFileSync(jsonPath, JSON.stringify(UTF8_FIXTURES, null, 2) + '\n', 'utf8');
  fs.writeFileSync(csvPath, ['locale,text', ...UTF8_FIXTURES.map(toCsvRow)].join('\n') + '\n', 'utf8');

  const jsonRoundTrip = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));
  const csvRaw = fs.readFileSync(csvPath, 'utf8');
  const hasUtf8Bom = csvRaw.charCodeAt(0) === 0xfeff;
  details.jsonFixturePath = jsonPath;
  details.csvFixturePath = csvPath;
  details.csvUtf8BomPresent = hasUtf8Bom;

  if (!Array.isArray(jsonRoundTrip) || jsonRoundTrip.length !== UTF8_FIXTURES.length) {
    failures.push('json_round_trip_count_mismatch');
  }
  for (let i = 0; i < UTF8_FIXTURES.length; i += 1) {
    if (jsonRoundTrip[i]?.text !== UTF8_FIXTURES[i].text) {
      failures.push(`json_round_trip_text_mismatch:${UTF8_FIXTURES[i].locale}`);
    }
  }

  const token = process.env.VOICE_API_TOKEN_STUDENT;
  if (options.live && !options.baseUrl) failures.push('live_mode_requires_base_url');
  if (options.live && !token) failures.push('missing_voice_api_token_student');

  for (const fixture of UTF8_FIXTURES) {
    const check = {
      locale: fixture.locale,
      inputLength: fixture.text.length,
      passed: false,
      responseLocale: null,
      traceId: null,
      failures: [],
    };

    try {
      const response = options.live
        ? await runLiveRoundTrip(options.baseUrl, token, fixture)
        : {
            text: fixture.text,
            metadata: {
              locale: fixture.locale,
              traceId: `sim-utf8-${fixture.locale}-${Date.now()}`,
            },
          };

      check.responseLocale = response?.metadata?.locale || null;
      check.traceId = response?.metadata?.traceId || null;
      if (check.responseLocale !== fixture.locale) {
        check.failures.push(`metadata_locale_mismatch:${check.responseLocale || 'missing'}`);
      }
      const responseText = typeof response?.text === 'string' ? response.text : '';
      if (!detectLanguageCompatibility(responseText || fixture.text, fixture.locale)) {
        check.failures.push('language_compatibility_failed');
      }
      check.passed = check.failures.length === 0;
    } catch (error) {
      check.failures.push(error instanceof Error ? error.message : String(error));
    }

    details.utf8RoundTrip.push(check);
    if (!check.passed) failures.push(`utf8_round_trip_failed:${fixture.locale}`);
  }

  if (options.strict && !options.live) failures.push('strict_mode_requires_live_execution');
  finish('voice-utf8', failures, details);
}

main().catch((error) => {
  finish('voice-utf8', ['runner_crash'], {
    error: error instanceof Error ? error.message : String(error),
  });
});
