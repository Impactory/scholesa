import type { SupportedLocale } from '@/src/lib/i18n/config';

export type SafetyOutcome = 'allowed' | 'blocked' | 'modified' | 'escalated';

export interface GuardrailDecision {
  blocked: boolean;
  safetyOutcome: SafetyOutcome;
  safetyReasonCode: string;
  localizedMessage: string;
  policyVersion: string;
  toolCallIds: string[];
}

const POLICY_VERSION = 'i18n-guardrails-2026-02-23';

const REFUSAL_BY_LOCALE: Record<SupportedLocale, string> = {
  en: 'I cannot help with that request. I can support safe, school-appropriate learning instead.',
  'zh-CN': '我无法协助该请求。我可以改为提供安全、适合学校场景的学习帮助。',
  'zh-TW': '我無法協助該請求。我可以改為提供安全、適合校園情境的學習協助。',
  th: 'ฉันไม่สามารถช่วยตามคำขอนี้ได้ แต่สามารถช่วยในบทเรียนที่ปลอดภัยและเหมาะสมกับโรงเรียนแทนได้'
};

const NEUTRAL_FALLBACK_BY_LOCALE: Record<SupportedLocale, string> = {
  en: 'Let\'s focus on your learning goal. What part would you like to understand first?',
  'zh-CN': '我们先聚焦你的学习目标。你想先理解哪一部分？',
  'zh-TW': '我們先聚焦你的學習目標。你想先理解哪一部分？',
  th: 'เรามาโฟกัสที่เป้าหมายการเรียนรู้ของคุณกันก่อน คุณอยากเริ่มจากส่วนไหน?'
};

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

function refusal(locale: SupportedLocale): string {
  return REFUSAL_BY_LOCALE[locale];
}

function allow(locale: SupportedLocale): GuardrailDecision {
  return {
    blocked: false,
    safetyOutcome: 'allowed',
    safetyReasonCode: 'none',
    localizedMessage: NEUTRAL_FALLBACK_BY_LOCALE[locale],
    policyVersion: POLICY_VERSION,
    toolCallIds: [],
  };
}

function blocked(locale: SupportedLocale, reasonCode: string): GuardrailDecision {
  return {
    blocked: true,
    safetyOutcome: 'blocked',
    safetyReasonCode: reasonCode,
    localizedMessage: refusal(locale),
    policyVersion: POLICY_VERSION,
    toolCallIds: [],
  };
}

export function evaluateGuardrailInput(prompt: string, locale: SupportedLocale): GuardrailDecision {
  const text = prompt || '';
  if (INJECTION_PATTERNS.some((pattern) => pattern.test(text))) {
    return blocked(locale, 'prompt_injection_attempt');
  }
  if (CROSS_TENANT_PATTERNS.some((pattern) => pattern.test(text))) {
    return blocked(locale, 'cross_tenant_data_request');
  }
  if (DISALLOWED_CONTENT_PATTERNS.some((pattern) => pattern.test(text))) {
    return blocked(locale, 'disallowed_content_request');
  }
  if (IMPERSONATION_PATTERNS.some((pattern) => pattern.test(text))) {
    return blocked(locale, 'impersonation_attempt');
  }
  return allow(locale);
}

export function evaluateGuardrailOutput(output: string, locale: SupportedLocale): GuardrailDecision {
  const text = output || '';
  if (INJECTION_PATTERNS.some((pattern) => pattern.test(text))) {
    return blocked(locale, 'output_policy_leak');
  }
  if (CROSS_TENANT_PATTERNS.some((pattern) => pattern.test(text))) {
    return blocked(locale, 'output_cross_tenant_reference');
  }
  return allow(locale);
}

export function languageLooksCompatible(text: string, locale: SupportedLocale): boolean {
  if (!text) return false;
  switch (locale) {
    case 'en':
      return /[A-Za-z]/.test(text);
    case 'zh-CN':
      return /[\u4e00-\u9fff]/.test(text) && /我们|学习|请|你/.test(text);
    case 'zh-TW':
      return /[\u4e00-\u9fff]/.test(text) && /我們|學習|請|你/.test(text);
    case 'th':
      return /[\u0E00-\u0E7F]/.test(text);
    default:
      return false;
  }
}

export function localizedTutorFallback(locale: SupportedLocale): string {
  return NEUTRAL_FALLBACK_BY_LOCALE[locale];
}

export function localizedRefusal(locale: SupportedLocale): string {
  return REFUSAL_BY_LOCALE[locale];
}

export function policyVersion(): string {
  return POLICY_VERSION;
}
