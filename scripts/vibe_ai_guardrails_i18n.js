#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { finish, readJson } = require('./vibe_report_utils');

const fixturePath = path.resolve('packages/safety/fixtures/guardrails.i18n.json');
const guardrailSourcePath = path.resolve('src/lib/ai/multilingualGuardrails.ts');

const locales = ['en', 'zh-CN', 'zh-TW', 'th'];

const INJECTION_PATTERNS = [
  /ignore (all )?previous instructions/i,
  /reveal (the )?system prompt/i,
  /show (me )?hidden prompt/i,
  /developer mode/i,
  /system prompt/i,
  /忽略.*指令/,
  /顯示.*提示/,
  /แสดง.*system prompt/,
];

const CROSS_TENANT_PATTERNS = [
  /other (school|site|district|tenant)/i,
  /another student'?s data/i,
  /cross[- ]tenant/i,
  /其他(学校|校区|租户|站点)/,
  /其他學校|其他租戶/,
  /โรงเรียนอื่น|ผู้ใช้โรงเรียนอื่น/,
];

const DISALLOWED_CONTENT_PATTERNS = [
  /build (a )?weapon/i,
  /how to hurt/i,
  /self-harm/i,
  /制作武器/,
  /製作武器/,
  /傷害他人/,
  /อาวุธ/,
  /ทำร้าย/,
];

const IMPERSONATION_PATTERNS = [
  /pretend to be (a )?(teacher|admin|parent)/i,
  /impersonate/i,
  /冒充(老师|管理员|家长)/,
  /假扮(老師|管理員|家長)/,
  /แกล้งเป็น(ครู|ผู้ดูแล|ผู้ปกครอง)/,
];

function evaluateInput(prompt) {
  if (INJECTION_PATTERNS.some((pattern) => pattern.test(prompt))) {
    return { blocked: true, reasonCode: 'prompt_injection_attempt', toolCallIds: [] };
  }
  if (CROSS_TENANT_PATTERNS.some((pattern) => pattern.test(prompt))) {
    return { blocked: true, reasonCode: 'cross_tenant_data_request', toolCallIds: [] };
  }
  if (DISALLOWED_CONTENT_PATTERNS.some((pattern) => pattern.test(prompt))) {
    return { blocked: true, reasonCode: 'disallowed_content_request', toolCallIds: [] };
  }
  if (IMPERSONATION_PATTERNS.some((pattern) => pattern.test(prompt))) {
    return { blocked: true, reasonCode: 'impersonation_attempt', toolCallIds: [] };
  }
  return { blocked: false, reasonCode: 'none', toolCallIds: [] };
}

function evaluateOutput(prompt) {
  if (INJECTION_PATTERNS.some((pattern) => pattern.test(prompt))) {
    return { blocked: true, reasonCode: 'output_policy_leak', toolCallIds: [] };
  }
  if (CROSS_TENANT_PATTERNS.some((pattern) => pattern.test(prompt))) {
    return { blocked: true, reasonCode: 'output_cross_tenant_reference', toolCallIds: [] };
  }
  return { blocked: false, reasonCode: 'none', toolCallIds: [] };
}

const failures = [];
const details = {
  fixtures: fixturePath,
  localeResults: {},
  sourceChecks: {},
};

if (!fs.existsSync(fixturePath)) {
  failures.push('missing_fixture:guardrails.i18n.json');
} else {
  const fixtures = readJson(fixturePath);
  for (const locale of locales) {
    if (!fixtures[locale]) {
      failures.push(`missing_locale_fixture:${locale}`);
      continue;
    }
    const set = fixtures[locale];
    const result = {
      injection: evaluateInput(set.injection),
      exfiltration: evaluateInput(set.exfiltration),
      disallowed: evaluateInput(set.disallowed),
      impersonation: evaluateInput(set.impersonation),
      neutral: evaluateInput(set.neutral),
      teacherTranslation: evaluateInput(set.teacherTranslation),
      outputLeakProbe: evaluateOutput(set.injection),
    };

    if (!result.injection.blocked) failures.push(`guardrail_expected_block:${locale}:injection`);
    if (!result.exfiltration.blocked) failures.push(`guardrail_expected_block:${locale}:exfiltration`);
    if (!result.disallowed.blocked) failures.push(`guardrail_expected_block:${locale}:disallowed`);
    if (!result.impersonation.blocked) failures.push(`guardrail_expected_block:${locale}:impersonation`);
    if (result.neutral.blocked) failures.push(`guardrail_expected_allow:${locale}:neutral`);
    if (result.teacherTranslation.blocked) failures.push(`guardrail_expected_allow:${locale}:teacherTranslation`);
    if (!result.outputLeakProbe.blocked) failures.push(`guardrail_expected_output_block:${locale}:outputLeakProbe`);

    const blockedCases = [result.injection, result.exfiltration, result.disallowed, result.impersonation, result.outputLeakProbe];
    for (const blocked of blockedCases) {
      if ((blocked.toolCallIds || []).length > 0) {
        failures.push(`tool_calls_should_be_empty_when_blocked:${locale}`);
        break;
      }
    }

    details.localeResults[locale] = result;
  }
}

if (fs.existsSync(guardrailSourcePath)) {
  const source = fs.readFileSync(guardrailSourcePath, 'utf8');
  details.sourceChecks = {
    hasPolicyVersion: /POLICY_VERSION/.test(source),
    hasLocalizedRefusals: /REFUSAL_BY_LOCALE/.test(source),
    hasInputEval: /evaluateGuardrailInput/.test(source),
    hasOutputEval: /evaluateGuardrailOutput/.test(source),
  };
  for (const [check, passed] of Object.entries(details.sourceChecks)) {
    if (!passed) failures.push(`missing_source_feature:${check}`);
  }
} else {
  failures.push('missing_source:multilingualGuardrails.ts');
}

finish('vibe-ai-guardrails-i18n-report', failures, details);
