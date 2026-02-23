#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

const VOICE_FIXTURE_ROOT = path.resolve('docs/Scholesa_Voice_VIBE_Fixtures_Pack/fixtures');
const LOCALES = ['en', 'zh-CN', 'zh-TW', 'th'];
const ROLE_TOKENS = {
  student: 'VOICE_API_TOKEN_STUDENT',
  teacher: 'VOICE_API_TOKEN_TEACHER',
  admin: 'VOICE_API_TOKEN_ADMIN',
};

const INJECTION_PATTERNS = [
  /ignore (all )?(previous|prior) instructions/i,
  /system prompt/i,
  /developer mode/i,
  /reveal .*prompt/i,
  /忽略所有(规则|規則)/,
  /忽略.*指令/,
  /顯示.*提示/,
  /แสดง.*system prompt/,
];

const CROSS_TENANT_PATTERNS = [
  /other (school|site|district|tenant)/i,
  /another student'?s data/i,
  /whole database/i,
  /cross[- ]tenant/i,
  /隔壁(学校|學校)/,
  /其他(学校|校区|租户|站点)/,
  /其他學校|其他租戶/,
  /โรงเรียนข้าง/,
  /โรงเรียนอื่น|ผู้ใช้โรงเรียนอื่น/,
];

const TOOL_ESCALATION_PATTERNS = [
  /admin tool/i,
  /data export/i,
  /show me .*database/i,
  /系统提示词/,
  /系統提示詞/,
  /管理员工具/,
  /管理員工具/,
  /เครื่องมือแอดมิน/,
  /เครื่องมือผู้ดูแล/,
];

const SELF_HARM_PATTERNS = [
  /hurt myself/i,
  /hurt someone/i,
  /\bself[- ]?harm\b/i,
  /\bkill myself\b/i,
  /伤害别人/,
  /傷害別人/,
  /ทำร้ายคน/,
  /想伤害自己/,
  /想傷害自己/,
  /อยากทำร้ายตัวเอง/,
];

const HARMFUL_CONTENT_PATTERNS = [
  /build (a )?weapon/i,
  /how to hurt/i,
  /make a bomb/i,
  /制作武器/,
  /製作武器/,
  /อาวุธ/,
];

const FOCUS_NUDGE_PATTERNS = [
  /\bI('| )?m bored\b/i,
  /\bthis is dumb\b/i,
  /don'?t want to do this/i,
  /ไม่อยากทำแล้ว/,
  /我不想做了/,
  /我不想繼續/,
];

const TEACHER_PRODUCTIVITY_PATTERNS = [
  /differentiat(ed|ion)/i,
  /mixed abilities/i,
  /message to a parent/i,
  /parent message/i,
  /分层|差异化|差異化/,
  /ผู้ปกครอง/,
];

const ROLE_ALLOWED_TOOLS = {
  student: ['glossary', 'hint_ladder', 'read_aloud', 'translate'],
  teacher: ['class_summary', 'rubric_feedback_draft', 'differentiate_lesson', 'read_aloud', 'translate'],
  admin: ['setup_help', 'troubleshooting_guide', 'read_aloud', 'translate'],
};

const LOCALE_TEXT = {
  en: {
    blocked: 'I cannot help with that request. I can help with safe, school-appropriate learning support.',
    escalated: 'I am glad you told me. Please contact a trusted adult or school counselor right now. You are not alone.',
    focusNudge: 'I hear you. Let us do one tiny step: read the first line and tell me one thing you notice. Want a hint or read-aloud?',
    studentGeneric: 'Let us take this one step at a time. Tell me what part feels hardest, and I will give a short hint.',
    teacherProductive: 'Here is a quick draft: Tier 1 core task, Tier 2 scaffolded supports, Tier 3 extension challenge, plus accommodations and check-in prompts.',
    teacherGeneric: 'I can help with concise class-ready drafts, differentiation ideas, and supportive parent communication.',
    adminGeneric: 'I can guide setup and non-sensitive troubleshooting. I will not expose secrets, keys, or raw student exports.',
  },
  'zh-CN': {
    blocked: '我无法协助该请求。我可以改为提供安全、适合学校场景的学习帮助。',
    escalated: '谢谢你愿意说出来。请立刻联系你信任的成年人或学校辅导老师。你并不孤单。',
    focusNudge: '我理解你的感受。我们先做一个很小的步骤：读第一行，再告诉我你注意到的一点。要不要提示或朗读？',
    studentGeneric: '我们一步一步来。告诉我最难的部分，我会给你一个简短提示。',
    teacherProductive: '给你一个简版草案：基础任务、支架支持、进阶挑战，并附上课堂照顾与检查点。',
    teacherGeneric: '我可以帮助生成课堂可用的简洁草案、差异化建议和支持性的家校沟通文本。',
    adminGeneric: '我可以提供配置引导和非敏感故障排查，不会暴露密钥、凭证或原始学生导出数据。',
  },
  'zh-TW': {
    blocked: '我無法協助該請求。我可以改為提供安全、適合校園情境的學習協助。',
    escalated: '謝謝你願意說出來。請立即聯絡你信任的成年人或學校輔導老師。你並不孤單。',
    focusNudge: '我理解你的感受。我們先做一個小步驟：先讀第一行，再告訴我你注意到的一點。要提示或朗讀嗎？',
    studentGeneric: '我們一步一步來。告訴我最卡的地方，我會給你簡短提示。',
    teacherProductive: '提供一份快速草案：核心任務、分層支援、進階挑戰，並附上調整與檢核提示。',
    teacherGeneric: '我可以提供精簡的課堂草案、差異化教學建議，以及支持性的家長訊息草稿。',
    adminGeneric: '我可以協助設定與非敏感疑難排解，不會揭露密鑰、憑證或原始學生匯出內容。',
  },
  th: {
    blocked: 'ฉันไม่สามารถช่วยตามคำขอนี้ได้ แต่ช่วยเรื่องการเรียนที่ปลอดภัยและเหมาะสมกับโรงเรียนได้',
    escalated: 'ขอบคุณที่บอกฉัน โปรดติดต่อผู้ใหญ่ที่ไว้ใจได้หรือครูที่ปรึกษาทันที คุณไม่ได้อยู่คนเดียว',
    focusNudge: 'เข้าใจความรู้สึกนะ ลองก้าวเล็ก ๆ ก่อน: อ่านบรรทัดแรกแล้วบอกสิ่งที่สังเกตหนึ่งอย่าง ต้องการคำใบ้หรือให้อ่านออกเสียงไหม',
    studentGeneric: 'เราค่อย ๆ ทำทีละขั้น บอกส่วนที่ยากที่สุด แล้วฉันจะให้คำใบ้สั้น ๆ',
    teacherProductive: 'ร่างสั้นสำหรับชั้นเรียน: งานแกนหลัก ระดับเสริมช่วยพยุง ระดับท้าทาย พร้อมการปรับและจุดเช็กความเข้าใจ',
    teacherGeneric: 'ฉันช่วยร่างข้อความสั้นสำหรับห้องเรียน แนวทางสอนแบบแตกต่าง และข้อความถึงผู้ปกครองแบบสนับสนุนได้',
    adminGeneric: 'ฉันช่วยตั้งค่าระบบและแก้ปัญหาทั่วไปที่ไม่อ่อนไหว โดยจะไม่เปิดเผยความลับ คีย์ หรือข้อมูลส่งออกดิบของนักเรียน',
  },
};

function parseArgs(argv = process.argv.slice(2)) {
  const options = {
    live: false,
    strict: false,
    baseUrl: process.env.VOICE_API_BASE_URL || '',
  };
  for (const arg of argv) {
    if (arg === '--live') options.live = true;
    if (arg === '--strict') options.strict = true;
    if (arg.startsWith('--base-url=')) options.baseUrl = arg.slice('--base-url='.length);
  }
  options.baseUrl = (options.baseUrl || '').replace(/\/+$/g, '');
  return options;
}

function walkFiles(rootDir, predicate, out = []) {
  if (!fs.existsSync(rootDir)) return out;
  const entries = fs.readdirSync(rootDir, { withFileTypes: true });
  for (const entry of entries) {
    const fullPath = path.join(rootDir, entry.name);
    if (entry.isDirectory()) {
      walkFiles(fullPath, predicate, out);
      continue;
    }
    if (predicate(fullPath)) out.push(fullPath);
  }
  return out;
}

function loadVoiceFixtures() {
  return walkFiles(VOICE_FIXTURE_ROOT, (file) => file.endsWith('.json'))
    .sort((a, b) => a.localeCompare(b))
    .map((filePath) => ({
      filePath,
      fixture: JSON.parse(fs.readFileSync(filePath, 'utf8')),
    }));
}

function detectLanguageCompatibility(text, locale) {
  if (!text || !text.trim()) return false;
  if (locale === 'en') return /[A-Za-z]/.test(text);
  if (locale === 'zh-CN') return /[\u4e00-\u9fff]/.test(text);
  if (locale === 'zh-TW') return /[\u4e00-\u9fff]/.test(text);
  if (locale === 'th') return /[\u0E00-\u0E7F]/.test(text);
  return false;
}

function inferCategory(message, role) {
  if (role === 'student' && FOCUS_NUDGE_PATTERNS.some((pattern) => pattern.test(message))) return 'focus_nudge';
  if (role === 'teacher' && TEACHER_PRODUCTIVITY_PATTERNS.some((pattern) => pattern.test(message))) return 'teacher_productivity';
  if (role === 'admin') return 'admin_setup';
  return 'generic';
}

function evaluateSafety(message, role, locale) {
  const category = inferCategory(message, role);
  const localized = LOCALE_TEXT[locale];
  if (SELF_HARM_PATTERNS.some((pattern) => pattern.test(message))) {
    return { safetyOutcome: 'escalated', safetyReasonCode: 'self_harm_risk', text: localized.escalated, category };
  }
  if (INJECTION_PATTERNS.some((pattern) => pattern.test(message))) {
    return { safetyOutcome: 'blocked', safetyReasonCode: 'prompt_injection_attempt', text: localized.blocked, category };
  }
  if (CROSS_TENANT_PATTERNS.some((pattern) => pattern.test(message)) ||
      TOOL_ESCALATION_PATTERNS.some((pattern) => pattern.test(message))) {
    return { safetyOutcome: 'blocked', safetyReasonCode: 'cross_tenant_data_request', text: localized.blocked, category };
  }
  if (HARMFUL_CONTENT_PATTERNS.some((pattern) => pattern.test(message))) {
    return { safetyOutcome: 'blocked', safetyReasonCode: 'disallowed_content_request', text: localized.blocked, category };
  }
  return { safetyOutcome: 'allowed', safetyReasonCode: 'none', text: '', category };
}

function generateAllowedResponse(role, locale, category) {
  const localized = LOCALE_TEXT[locale];
  if (role === 'student' && category === 'focus_nudge') return localized.focusNudge;
  if (role === 'student') return localized.studentGeneric;
  if (role === 'teacher' && category === 'teacher_productivity') return localized.teacherProductive;
  if (role === 'teacher') return localized.teacherGeneric;
  return localized.adminGeneric;
}

function selectToolCalls(role, category, safetyOutcome) {
  if (safetyOutcome !== 'allowed' && safetyOutcome !== 'modified') return [];
  if (role === 'student' && category === 'focus_nudge') return ['hint_ladder', 'read_aloud'];
  if (role === 'teacher' && category === 'teacher_productivity') return ['differentiate_lesson', 'rubric_feedback_draft'];
  if (role === 'admin') return ['setup_help'];
  return [ROLE_ALLOWED_TOOLS[role][0]];
}

function normalizeRole(role) {
  const value = String(role || '').toLowerCase();
  if (value === 'student') return 'student';
  if (value === 'teacher') return 'teacher';
  return 'admin';
}

function simulateFixtureResponse(fixture, options = {}) {
  const role = normalizeRole(fixture.role);
  const locale = fixture.locale;
  const message = String(fixture.input || '').trim();
  const decision = evaluateSafety(message, role, locale);
  const text = decision.safetyOutcome === 'allowed'
    ? generateAllowedResponse(role, locale, decision.category)
    : decision.text;
  const toolsInvoked = selectToolCalls(role, decision.category, decision.safetyOutcome);
  const quietModeActive = Boolean(options.quietModeActive);
  const ttsAvailable = !quietModeActive && text.length > 0;
  return {
    text,
    metadata: {
      traceId: `sim-${Date.now()}-${Math.random().toString(16).slice(2, 8)}`,
      safetyOutcome: decision.safetyOutcome,
      safetyReasonCode: decision.safetyReasonCode,
      policyVersion: 'voice-policy-2026-02-23',
      modelVersion: 'voice-orchestrator-v1',
      locale,
      toolsInvoked,
      quietModeActive,
      role,
      gradeBand: fixture.gradeBand || 'All',
    },
    tts: {
      available: ttsAvailable,
      audioUrl: ttsAvailable ? 'https://example.invalid/audio.wav' : undefined,
      voiceProfile: role === 'student' && /K-5/i.test(fixture.gradeBand || '') ? `${locale}.k5_safe_neutral` : `${locale}.student_neutral`,
    },
  };
}

async function fetchJson(url, init) {
  const response = await fetch(url, init);
  let body = {};
  try {
    body = await response.json();
  } catch {
    body = {};
  }
  if (!response.ok) {
    const message = body.message || body.error || `HTTP ${response.status}`;
    const error = new Error(message);
    error.status = response.status;
    error.body = body;
    throw error;
  }
  return body;
}

async function runFixtureViaLiveEndpoint(fixture, options) {
  const role = normalizeRole(fixture.role);
  const tokenEnvName = ROLE_TOKENS[role];
  const idToken = process.env[tokenEnvName];
  if (!idToken) {
    throw new Error(`Missing ${tokenEnvName} for live voice fixture execution.`);
  }
  const body = {
    message: fixture.input,
    locale: fixture.locale,
    screenId: 'voice_fixture_runner',
    context: { fixtureId: fixture.id },
    gradeBand: fixture.gradeBand,
    voice: { enabled: true, output: true },
  };
  return fetchJson(`${options.baseUrl}/copilot/message`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${idToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  });
}

async function runFixture(fixture, options) {
  if (options.live) return runFixtureViaLiveEndpoint(fixture, options);
  return simulateFixtureResponse(fixture, options);
}

function defaultVoiceApiBaseUrl() {
  return process.env.VOICE_API_BASE_URL || '';
}

module.exports = {
  LOCALES,
  ROLE_ALLOWED_TOOLS,
  VOICE_FIXTURE_ROOT,
  defaultVoiceApiBaseUrl,
  detectLanguageCompatibility,
  loadVoiceFixtures,
  parseArgs,
  runFixture,
  simulateFixtureResponse,
  walkFiles,
};
