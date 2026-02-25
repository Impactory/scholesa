import { createHash, createHmac, randomUUID } from 'crypto';
import type { Request, Response } from 'express';
import * as admin from 'firebase-admin';
import { HttpsError } from 'firebase-functions/v2/https';
import {
  callInternalInferenceJson,
  isInternalInferenceRequired,
  type InternalInferenceAuthMode,
  type InternalInferenceCallResult,
} from './internalInferenceGateway';

export const SUPPORTED_VOICE_LOCALES = ['en', 'zh-CN', 'zh-TW', 'th'] as const;
export type VoiceLocale = (typeof SUPPORTED_VOICE_LOCALES)[number];
type VoiceRole = 'student' | 'teacher' | 'admin';
type SafetyOutcome = 'allowed' | 'blocked' | 'modified' | 'escalated';
type GradeBand = 'K-5' | '6-8' | '9-12' | 'All';
type VoiceIntent =
  | 'hint_request'
  | 'explain_request'
  | 'translation_request'
  | 'planning_request'
  | 'reflection'
  | 'safety_support'
  | 'general_support';
type VoiceComplexity = 'low' | 'medium' | 'high';
type VoiceEmotionalState = 'frustrated' | 'neutral' | 'confident';
type VoiceResponseMode = 'hint' | 'explain' | 'translate' | 'plan' | 'safety';

const VOICE_POLICY_VERSION = 'voice-policy-2026-02-23';
const VOICE_MODEL_VERSION = 'voice-orchestrator-v1';
const STT_MODEL_VERSION = 'scholesa-stt-internal-v1';
const TTS_MODEL_VERSION = 'scholesa-tts-internal-v1';
const AUDIO_TOKEN_TTL_MS = 5 * 60 * 1000;
const TELEMETRY_COLLECTION = 'telemetryEvents';
const BOS_INTERACTION_COLLECTION = 'interactionEvents';
const TELEMETRY_UNSCOPED_SITE_ID = 'unscoped';

type VoiceTelemetryEvent =
  | 'voice.transcribe'
  | 'voice.message'
  | 'voice.tts'
  | 'voice.blocked'
  | 'voice.escalated';

type BosCompatibilityTelemetryEvent =
  | 'ai_help_opened'
  | 'ai_help_used'
  | 'ai_coach_response';

type BosInteractionEvent =
  | 'ai_help_opened'
  | 'ai_help_used'
  | 'ai_coach_response';

type SupportedTelemetryEvent = VoiceTelemetryEvent | BosCompatibilityTelemetryEvent;

interface VoiceSettings {
  voiceEnabled: boolean;
  studentVoiceDefaultOn: boolean;
  teacherVoiceEnabled: boolean;
  adminVoiceEnabled: boolean;
  allowedLocales: VoiceLocale[];
  quietModeEnabled: boolean;
  quietHours?: {
    enabled: boolean;
    timezone?: string;
    windows: Array<{
      days?: number[];
      start: string;
      end: string;
    }>;
  };
}

interface VoiceAuthContext {
  uid: string;
  role: VoiceRole;
  siteId: string;
  siteIds: string[];
  gradeBand: GradeBand;
}

interface SafetyDecision {
  safetyOutcome: SafetyOutcome;
  safetyReasonCode: string;
  localizedMessage: string;
  category: 'focus_nudge' | 'teacher_productivity' | 'admin_setup' | 'generic';
}

interface SpeechPreparation {
  speechText: string;
  redactionApplied: boolean;
  redactionCount: number;
}

interface VoiceUnderstandingSignal {
  intent: VoiceIntent;
  complexity: VoiceComplexity;
  needsScaffold: boolean;
  emotionalState: VoiceEmotionalState;
  confidence: number;
  responseMode: VoiceResponseMode;
  topicTags: string[];
}

interface PartialVoiceUnderstandingSignal {
  intent?: VoiceIntent;
  complexity?: VoiceComplexity;
  needsScaffold?: boolean;
  emotionalState?: VoiceEmotionalState;
  confidence?: number;
  responseMode?: VoiceResponseMode;
  topicTags?: string[];
}

interface AudioTokenPayload {
  traceId: string;
  locale: VoiceLocale;
  voiceProfile: string;
  text: string;
  expMs: number;
  checksum: string;
}

interface VoiceInferenceMeta {
  service: 'llm' | 'stt' | 'tts';
  route: 'internal' | 'local';
  authMode: InternalInferenceAuthMode;
  statusCode?: number;
  errorCode?: string;
  reason?: string;
  endpoint?: string;
}

class VoiceHttpError extends Error {
  readonly status: number;
  readonly code: string;
  readonly details?: Record<string, unknown>;

  constructor(status: number, code: string, message: string, details?: Record<string, unknown>) {
    super(message);
    this.status = status;
    this.code = code;
    this.details = details;
  }
}

const DEFAULT_VOICE_SETTINGS: VoiceSettings = {
  voiceEnabled: true,
  studentVoiceDefaultOn: true,
  teacherVoiceEnabled: true,
  adminVoiceEnabled: true,
  allowedLocales: [...SUPPORTED_VOICE_LOCALES],
  quietModeEnabled: false,
};

const LOCALE_ALIASES: Record<string, VoiceLocale> = {
  en: 'en',
  'en-us': 'en',
  'en-gb': 'en',
  zh: 'zh-CN',
  'zh-cn': 'zh-CN',
  'zh-hans': 'zh-CN',
  'zh-sg': 'zh-CN',
  'zh-tw': 'zh-TW',
  'zh-hant': 'zh-TW',
  'zh-hk': 'zh-TW',
  th: 'th',
  'th-th': 'th',
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

const HINT_REQUEST_PATTERNS = [
  /\bhint\b/i,
  /\bnext step\b/i,
  /give me a clue/i,
  /提示|線索/,
  /ช่วยใบ้/,
];

const EXPLAIN_REQUEST_PATTERNS = [
  /\bexplain\b/i,
  /\bwhy\b/i,
  /break this down/i,
  /講解|解释|解釋|原因/,
  /อธิบาย/,
];

const TRANSLATION_PATTERNS = [
  /\btranslate\b/i,
  /\bin (english|chinese|thai)\b/i,
  /翻译|翻譯|轉成/,
  /แปล/,
];

const PLANNING_PATTERNS = [
  /\bplan\b/i,
  /\bchecklist\b/i,
  /\bnext\b.*\bdo\b/i,
  /步骤|步驟|清单|清單/,
  /แผน|ขั้นตอน/,
];

const REFLECTION_PATTERNS = [
  /\bi learned\b/i,
  /\bi understood\b/i,
  /\bsummary\b/i,
  /我学会|我學會|总结|總結/,
  /ฉันเรียนรู้|สรุป/,
];

const FRUSTRATION_PATTERNS = [
  /\bstuck\b/i,
  /\bconfused\b/i,
  /\bfrustrat(ed|ing)\b/i,
  /\bcan'?t\b/i,
  /卡住|不会|不會|好难|好難/,
  /งง|ยากมาก|ทำไม่ได้/,
];

const CONFIDENCE_PATTERNS = [
  /\bI can\b/i,
  /\bgot it\b/i,
  /\bunderstand now\b/i,
  /我会了|我會了|我懂了/,
  /เข้าใจแล้ว|ทำได้/,
];

const HIGH_COMPLEXITY_PATTERNS = [
  /\bproof\b/i,
  /\bderive\b/i,
  /\banaly(s|z)e\b/i,
  /\bcompare\b/i,
  /证明|證明|推导|推導|分析|比較/,
  /พิสูจน์|วิเคราะห์/,
];

const LOW_COMPLEXITY_PATTERNS = [
  /\bread\b/i,
  /\bspell\b/i,
  /\bcount\b/i,
  /\bwhat is\b/i,
  /朗读|朗讀|拼写|拼寫|数数|數數/,
  /อ่าน|สะกด|นับ/,
];

const TOPIC_TAG_PATTERNS: Array<{ tag: string; patterns: RegExp[] }> = [
  { tag: 'math', patterns: [/\bmath\b/i, /\balgebra\b/i, /\bgeometry\b/i, /数学|數學|คณิต/] },
  { tag: 'science', patterns: [/\bscience\b/i, /\bphysics\b/i, /\bchemistry\b/i, /科学|科學|วิทยา/] },
  { tag: 'language', patterns: [/\breading\b/i, /\bwriting\b/i, /\bgrammar\b/i, /阅读|閱讀|写作|寫作|ภาษา/] },
  { tag: 'coding', patterns: [/\bcod(e|ing)\b/i, /\bpython\b/i, /\bjavascript\b/i, /编程|程式|เขียนโค้ด/] },
  { tag: 'history', patterns: [/\bhistory\b/i, /\bcivilization\b/i, /历史|歷史|ประวัติ/] },
];

const EMAIL_PATTERN = /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b/g;
const PHONE_PATTERN = /(\+\d{1,3}[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}/g;
const ADDRESS_PATTERN = /\b\d+\s+[A-Za-z0-9.\s]+(?:Street|St|Avenue|Ave|Road|Rd|Boulevard|Blvd|Drive|Dr|Lane|Ln)\b/gi;
const ID_PATTERN = /\b(?:site|learner|submission|attempt|session)[-_]?[A-Za-z0-9]{4,}\b/gi;

const ROLE_ALLOWED_TOOLS: Record<VoiceRole, readonly string[]> = {
  student: ['glossary', 'hint_ladder', 'read_aloud', 'translate'],
  teacher: ['class_summary', 'rubric_feedback_draft', 'differentiate_lesson', 'read_aloud', 'translate'],
  admin: ['setup_help', 'troubleshooting_guide', 'read_aloud', 'translate'],
};

const LOCALE_TEXT: Record<VoiceLocale, {
  blocked: string;
  escalated: string;
  focusNudge: string;
  studentGeneric: string;
  teacherProductive: string;
  teacherGeneric: string;
  adminGeneric: string;
}> = {
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

const LOCALE_INTELLIGENCE_TEXT: Record<VoiceLocale, {
  hintStep: string;
  explainStep: string;
  translationStep: string;
  planningStep: string;
  reflectionStep: string;
  frustrationSupport: string;
  scaffoldPrompt: string;
}> = {
  en: {
    hintStep: 'Try one concrete move, then tell me what changed.',
    explainStep: 'I can explain with a short reason, then a quick check question.',
    translationStep: 'I can keep the same meaning and switch to your preferred language.',
    planningStep: 'Let us make a three-step plan and complete step one first.',
    reflectionStep: 'Share one thing you learned and one thing you still want to improve.',
    frustrationSupport: 'You are not behind. We can shrink this into a smaller step.',
    scaffoldPrompt: 'I will keep each step short so you can respond quickly.',
  },
  'zh-CN': {
    hintStep: '先做一个具体小步骤，然后告诉我发生了什么变化。',
    explainStep: '我可以先给简短原因，再给一个快速检查题。',
    translationStep: '我可以保持原意并切换到你偏好的语言。',
    planningStep: '我们先做三步计划，先完成第一步。',
    reflectionStep: '说一件你已经学会的，再说一件还想加强的。',
    frustrationSupport: '你没有落后。我们可以把任务再拆小一点。',
    scaffoldPrompt: '我会把每一步都说短一些，方便你快速回应。',
  },
  'zh-TW': {
    hintStep: '先做一個具體小步驟，再告訴我有什麼變化。',
    explainStep: '我可以先給簡短原因，再給一題快速檢核。',
    translationStep: '我可以保留原意並切換到你偏好的語言。',
    planningStep: '我們先做三步計畫，先完成第一步。',
    reflectionStep: '說一件你已經學會的，再說一件想加強的。',
    frustrationSupport: '你沒有落後。我們可以把任務再拆小一點。',
    scaffoldPrompt: '我會把每一步都講短一些，方便你快速回應。',
  },
  th: {
    hintStep: 'ลองทำหนึ่งขั้นที่ชัดเจนก่อน แล้วบอกว่ามีอะไรเปลี่ยนไปบ้าง',
    explainStep: 'ฉันอธิบายเหตุผลสั้น ๆ แล้วให้คำถามเช็กความเข้าใจได้',
    translationStep: 'ฉันคงความหมายเดิมและสลับเป็นภาษาที่ต้องการได้',
    planningStep: 'มาวางแผน 3 ขั้นและเริ่มจากขั้นแรกก่อน',
    reflectionStep: 'บอกสิ่งที่ได้เรียนรู้ 1 อย่าง และสิ่งที่ยังอยากพัฒนาอีก 1 อย่าง',
    frustrationSupport: 'คุณไม่ได้ตามหลังนะ เราแบ่งเป็นขั้นเล็กลงได้',
    scaffoldPrompt: 'ฉันจะตอบเป็นขั้นสั้น ๆ เพื่อให้คุณตามได้ทันที',
  },
};

function normalizeVoiceLocale(rawLocale: string | null | undefined): VoiceLocale {
  if (!rawLocale) return 'en';
  const trimmed = rawLocale.trim();
  if (!trimmed) return 'en';
  if (SUPPORTED_VOICE_LOCALES.includes(trimmed as VoiceLocale)) return trimmed as VoiceLocale;
  const alias = LOCALE_ALIASES[trimmed.toLowerCase()];
  if (alias) return alias;
  const short = trimmed.split('-')[0]?.toLowerCase();
  if (short && LOCALE_ALIASES[short]) return LOCALE_ALIASES[short];
  return 'en';
}

function firstAcceptLanguage(acceptLanguage: string | undefined): string | undefined {
  if (!acceptLanguage) return undefined;
  return acceptLanguage.split(',').map((v) => v.trim().split(';')[0]?.trim()).find((v) => Boolean(v));
}

function resolveLocale(preferred: unknown, req: Request, allowedLocales: VoiceLocale[]): VoiceLocale {
  const preferredRaw = typeof preferred === 'string' ? preferred : undefined;
  const explicitHeader = req.header('x-scholesa-locale');
  const acceptLanguage = firstAcceptLanguage(req.header('accept-language') ?? undefined);
  const normalized = normalizeVoiceLocale(preferredRaw ?? explicitHeader ?? acceptLanguage);
  if (allowedLocales.includes(normalized)) return normalized;
  return allowedLocales.includes('en') ? 'en' : allowedLocales[0] ?? 'en';
}

function normalizeString(value: unknown): string | undefined {
  if (typeof value !== 'string') return undefined;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : undefined;
}

function normalizeStringArray(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value.filter((entry): entry is string => typeof entry === 'string' && entry.trim().length > 0).map((entry) => entry.trim());
}

function normalizeBoolean(value: unknown, fallback: boolean): boolean {
  if (typeof value === 'boolean') return value;
  return fallback;
}

function dedupeStrings(values: string[]): string[] {
  const out: string[] = [];
  const seen = new Set<string>();
  for (const value of values) {
    if (seen.has(value)) continue;
    seen.add(value);
    out.push(value);
  }
  return out;
}

function toHeaderString(value: string | string[] | undefined): string | undefined {
  if (typeof value === 'string') {
    const trimmed = value.trim();
    return trimmed.length > 0 ? trimmed : undefined;
  }
  if (Array.isArray(value) && value.length > 0) {
    return toHeaderString(value[0]);
  }
  return undefined;
}

function extractTraceIdFromHeader(headerValue: string | undefined): string | undefined {
  if (!headerValue) return undefined;
  const traceId = headerValue.split('/')[0]?.trim();
  return traceId && traceId.length > 0 ? traceId : undefined;
}

function resolveTelemetryEnv(): 'dev' | 'staging' | 'prod' {
  const raw = String(process.env.VIBE_ENV || process.env.APP_ENV || process.env.NODE_ENV || '')
    .trim()
    .toLowerCase();
  if (raw === 'production' || raw === 'prod') return 'prod';
  if (raw === 'staging' || raw === 'stage') return 'staging';
  return 'dev';
}

function toCanonicalGradeBand(gradeBand: GradeBand): 'k5' | 'ms' | 'hs' {
  if (gradeBand === 'K-5') return 'k5';
  if (gradeBand === '6-8') return 'ms';
  if (gradeBand === '9-12') return 'hs';
  return 'ms';
}

function toBosGradeBand(gradeBand: GradeBand): 'K_5' | 'G6_8' | 'G9_12' {
  if (gradeBand === 'K-5') return 'K_5';
  if (gradeBand === '6-8') return 'G6_8';
  if (gradeBand === '9-12') return 'G9_12';
  return 'G6_8';
}

function toBosActorRole(role: VoiceRole): 'learner' | 'educator' | 'admin' {
  if (role === 'student') return 'learner';
  if (role === 'teacher') return 'educator';
  return 'admin';
}

type BosContextMode = 'in_class' | 'homework' | 'unknown';

interface BosInteractionContext {
  actorId: string;
  actorRole: 'learner' | 'educator' | 'admin';
  sessionOccurrenceId?: string;
  missionId?: string;
  checkpointId?: string;
  contextMode: BosContextMode;
  conceptTags: string[];
}

function normalizeBosContextMode(value: unknown): BosContextMode {
  const normalized = normalizeString(value)?.toLowerCase();
  if (normalized === 'in_class' || normalized === 'in-class' || normalized === 'class') return 'in_class';
  if (normalized === 'homework' || normalized === 'home_work' || normalized === 'home-work') return 'homework';
  return 'unknown';
}

function resolveBosInteractionContext(
  body: Record<string, unknown>,
  authContext: VoiceAuthContext,
): BosInteractionContext {
  const context = body.context && typeof body.context === 'object'
    ? body.context as Record<string, unknown>
    : undefined;

  const selectedLearnerId = normalizeString(context?.selectedLearnerId);
  const actorId = authContext.role === 'teacher' && selectedLearnerId
    ? selectedLearnerId
    : authContext.uid;
  const actorRole = authContext.role === 'teacher' && selectedLearnerId
    ? 'learner'
    : toBosActorRole(authContext.role);

  const rawTags = normalizeStringArray(
    (Array.isArray(context?.conceptTags) ? context?.conceptTags : body.conceptTags) as unknown,
  ).slice(0, 10);

  return {
    actorId,
    actorRole,
    sessionOccurrenceId: normalizeString(body.sessionOccurrenceId) ?? normalizeString(context?.sessionOccurrenceId),
    missionId: normalizeString(body.missionId) ?? normalizeString(context?.missionId),
    checkpointId: normalizeString(body.checkpointId) ?? normalizeString(context?.checkpointId),
    contextMode: normalizeBosContextMode(body.contextMode ?? context?.contextMode),
    conceptTags: rawTags,
  };
}

function resolveRequestId(req: Request): string {
  const headerRequestId = toHeaderString(req.header('x-request-id'));
  return headerRequestId ?? `voice-${randomUUID()}`;
}

function resolveTraceId(req: Request, body: Record<string, unknown>): string {
  const context = body.context && typeof body.context === 'object'
    ? body.context as Record<string, unknown>
    : undefined;

  const candidates = [
    normalizeString(body.traceId),
    normalizeString(context?.traceId),
    normalizeString(context?.voiceTraceId),
    normalizeString(context?.voiceInputTraceId),
    normalizeString(toHeaderString(req.header('x-trace-id'))),
    extractTraceIdFromHeader(toHeaderString(req.header('x-cloud-trace-context'))),
  ];

  for (const candidate of candidates) {
    if (candidate) return candidate;
  }
  return randomUUID();
}

function normalizeGradeBand(rawBand: unknown, rawGrade: unknown): GradeBand {
  const band = typeof rawBand === 'string' ? rawBand.trim().toUpperCase() : '';
  if (band === 'K-5' || band === 'K_5' || band === 'K5' || band === 'GRADES_1_3' || band === 'GRADES_4_6') return 'K-5';
  if (band === '6-8' || band === 'G6_8' || band === 'GRADES_7_9') return '6-8';
  if (band === '9-12' || band === 'G9_12' || band === 'GRADES_10_12') return '9-12';
  if (band === 'ALL') return 'All';
  const grade = typeof rawGrade === 'number' ? rawGrade : Number(rawGrade);
  if (!Number.isFinite(grade)) return '6-8';
  if (grade <= 5) return 'K-5';
  if (grade <= 8) return '6-8';
  return '9-12';
}

function normalizeRole(rawRole: unknown): VoiceRole {
  const role = typeof rawRole === 'string' ? rawRole.trim().toLowerCase() : '';
  if (role === 'learner' || role === 'student') return 'student';
  if (role === 'educator' || role === 'teacher') return 'teacher';
  if (role === 'hq' || role === 'site' || role === 'partner' || role === 'admin') return 'admin';
  return 'student';
}

function parseJsonBody(req: Request): Record<string, unknown> {
  if (req.body && typeof req.body === 'object' && !Buffer.isBuffer(req.body)) {
    return req.body as Record<string, unknown>;
  }
  if (typeof req.body === 'string') {
    try {
      return JSON.parse(req.body) as Record<string, unknown>;
    } catch {
      return {};
    }
  }
  const rawBody = (req as Request & { rawBody?: Buffer }).rawBody;
  if (rawBody && rawBody.length > 0) {
    try {
      return JSON.parse(rawBody.toString('utf8')) as Record<string, unknown>;
    } catch {
      return {};
    }
  }
  return {};
}

function extractBearerToken(authorizationHeader: string | undefined): string | undefined {
  if (!authorizationHeader) return undefined;
  const match = authorizationHeader.match(/^Bearer\s+(.+)$/i);
  return match ? match[1] : undefined;
}

function collectSiteIdsFromClaims(decoded: admin.auth.DecodedIdToken): string[] {
  const claims = decoded as admin.auth.DecodedIdToken & Record<string, unknown>;
  const values: string[] = [];
  const pushMaybe = (value: unknown) => {
    if (typeof value === 'string' && value.trim().length > 0) values.push(value.trim());
  };
  pushMaybe(claims.siteId);
  pushMaybe(claims.activeSiteId);
  const siteIds = normalizeStringArray(claims.siteIds);
  values.push(...siteIds);
  return dedupeStrings(values);
}

async function fetchUserProfile(uid: string): Promise<Record<string, unknown>> {
  const userSnap = await admin.firestore().collection('users').doc(uid).get();
  return (userSnap.exists ? (userSnap.data() as Record<string, unknown>) : {});
}

function validateSiteAccess(requestedSiteId: string | undefined, context: VoiceAuthContext): void {
  if (!requestedSiteId) return;
  if (!context.siteIds.includes(requestedSiteId)) {
    throw new VoiceHttpError(403, 'permission_denied', 'Requested site is outside the authenticated tenant scope.', {
      requestedSiteId,
      allowedSiteIds: context.siteIds,
    });
  }
}

async function resolveAuthContext(req: Request, body: Record<string, unknown>): Promise<VoiceAuthContext> {
  const token = extractBearerToken(req.header('authorization') ?? undefined);
  if (!token) {
    throw new VoiceHttpError(401, 'unauthenticated', 'Authorization bearer token is required.');
  }

  let decoded: admin.auth.DecodedIdToken;
  try {
    decoded = await admin.auth().verifyIdToken(token, true);
  } catch (error) {
    throw new VoiceHttpError(401, 'unauthenticated', 'Token verification failed.', {
      message: error instanceof Error ? error.message : 'unknown',
    });
  }

  const profile = await fetchUserProfile(decoded.uid);
  const role = normalizeRole((decoded as Record<string, unknown>).role ?? profile.role);
  const siteIds = dedupeStrings([
    ...collectSiteIdsFromClaims(decoded),
    ...normalizeStringArray(profile.siteIds),
    ...(normalizeString(profile.activeSiteId) ? [String(profile.activeSiteId)] : []),
  ]);
  const siteIdFromBody = normalizeString(body.siteId) ??
    normalizeString((body.context as Record<string, unknown> | undefined)?.siteId);
  const siteId = siteIdFromBody ?? siteIds[0];
  if (!siteId) {
    throw new VoiceHttpError(403, 'permission_denied', 'No tenant site context available.');
  }
  if (!siteIds.includes(siteId)) {
    siteIds.push(siteId);
  }
  const gradeBand = normalizeGradeBand(
    (decoded as Record<string, unknown>).gradeBand ?? profile.gradeBand ?? body.gradeBand,
    (decoded as Record<string, unknown>).grade ?? profile.grade ?? body.grade,
  );
  const context: VoiceAuthContext = {
    uid: decoded.uid,
    role,
    siteId,
    siteIds,
    gradeBand,
  };
  validateSiteAccess(siteIdFromBody, context);
  return context;
}

function parseVoiceSettings(data: Record<string, unknown> | undefined): VoiceSettings {
  if (!data) return { ...DEFAULT_VOICE_SETTINGS };
  const allowedLocalesRaw = Array.isArray(data.allowedLocales) ? data.allowedLocales : [];
  const allowedLocales = dedupeStrings(
    allowedLocalesRaw
      .map((entry) => normalizeVoiceLocale(typeof entry === 'string' ? entry : undefined))
      .filter((entry) => Boolean(entry)),
  ) as VoiceLocale[];

  const windowsRaw = (data.quietHours as Record<string, unknown> | undefined)?.windows;
  const windows = Array.isArray(windowsRaw)
    ? windowsRaw
        .map((windowEntry): { days?: number[]; start: string; end: string } | null => {
          if (!windowEntry || typeof windowEntry !== 'object') return null;
          const raw = windowEntry as Record<string, unknown>;
          const start = normalizeString(raw.start);
          const end = normalizeString(raw.end);
          if (!start || !end) return null;
          const days = Array.isArray(raw.days)
            ? raw.days.filter((day): day is number => typeof day === 'number' && day >= 0 && day <= 6)
            : undefined;
          return { start, end, days };
        })
        .filter((entry): entry is { days?: number[]; start: string; end: string } => Boolean(entry))
    : [];

  return {
    voiceEnabled: normalizeBoolean(data.voiceEnabled, DEFAULT_VOICE_SETTINGS.voiceEnabled),
    studentVoiceDefaultOn: normalizeBoolean(data.studentVoiceDefaultOn, DEFAULT_VOICE_SETTINGS.studentVoiceDefaultOn),
    teacherVoiceEnabled: normalizeBoolean(data.teacherVoiceEnabled, DEFAULT_VOICE_SETTINGS.teacherVoiceEnabled),
    adminVoiceEnabled: normalizeBoolean(data.adminVoiceEnabled, DEFAULT_VOICE_SETTINGS.adminVoiceEnabled),
    allowedLocales: allowedLocales.length > 0 ? allowedLocales : [...SUPPORTED_VOICE_LOCALES],
    quietModeEnabled: normalizeBoolean(
      (data.quietMode as Record<string, unknown> | undefined)?.enabled ?? data.quietModeEnabled,
      false,
    ),
    quietHours: windows.length > 0
      ? {
          enabled: normalizeBoolean((data.quietHours as Record<string, unknown> | undefined)?.enabled, true),
          timezone: normalizeString((data.quietHours as Record<string, unknown> | undefined)?.timezone),
          windows,
        }
      : undefined,
  };
}

async function loadVoiceSettings(siteId: string): Promise<VoiceSettings> {
  const doc = await admin.firestore()
    .collection('sites')
    .doc(siteId)
    .collection('settings')
    .doc('voice')
    .get();
  return parseVoiceSettings(doc.exists ? (doc.data() as Record<string, unknown>) : undefined);
}

function parseTimeToMinutes(time: string): number | null {
  const match = /^(\d{1,2}):(\d{2})$/.exec(time.trim());
  if (!match) return null;
  const hours = Number(match[1]);
  const minutes = Number(match[2]);
  if (!Number.isInteger(hours) || !Number.isInteger(minutes)) return null;
  if (hours < 0 || hours > 23 || minutes < 0 || minutes > 59) return null;
  return hours * 60 + minutes;
}

function isWithinWindow(nowMinutes: number, startMinutes: number, endMinutes: number): boolean {
  if (startMinutes === endMinutes) return true;
  if (startMinutes < endMinutes) return nowMinutes >= startMinutes && nowMinutes < endMinutes;
  return nowMinutes >= startMinutes || nowMinutes < endMinutes;
}

function isQuietModeActive(settings: VoiceSettings, now: Date): boolean {
  if (settings.quietModeEnabled) return true;
  if (!settings.quietHours || !settings.quietHours.enabled || settings.quietHours.windows.length === 0) return false;
  const nowDay = now.getUTCDay();
  const nowMinutes = now.getUTCHours() * 60 + now.getUTCMinutes();
  return settings.quietHours.windows.some((windowEntry) => {
    const startMinutes = parseTimeToMinutes(windowEntry.start);
    const endMinutes = parseTimeToMinutes(windowEntry.end);
    if (startMinutes === null || endMinutes === null) return false;
    if (windowEntry.days && windowEntry.days.length > 0 && !windowEntry.days.includes(nowDay)) return false;
    return isWithinWindow(nowMinutes, startMinutes, endMinutes);
  });
}

function isRoleEnabled(settings: VoiceSettings, role: VoiceRole): boolean {
  if (!settings.voiceEnabled) return false;
  if (role === 'student') return settings.studentVoiceDefaultOn;
  if (role === 'teacher') return settings.teacherVoiceEnabled;
  return settings.adminVoiceEnabled;
}

function inferCategory(message: string, role: VoiceRole): SafetyDecision['category'] {
  if (role === 'student' && FOCUS_NUDGE_PATTERNS.some((pattern) => pattern.test(message))) return 'focus_nudge';
  if (role === 'teacher' && TEACHER_PRODUCTIVITY_PATTERNS.some((pattern) => pattern.test(message))) {
    return 'teacher_productivity';
  }
  if (role === 'admin') return 'admin_setup';
  return 'generic';
}

function evaluateSafetyDecision(message: string, role: VoiceRole, locale: VoiceLocale): SafetyDecision {
  const normalized = message.trim();
  const category = inferCategory(normalized, role);
  if (SELF_HARM_PATTERNS.some((pattern) => pattern.test(normalized))) {
    return {
      safetyOutcome: 'escalated',
      safetyReasonCode: 'self_harm_risk',
      localizedMessage: LOCALE_TEXT[locale].escalated,
      category,
    };
  }
  if (INJECTION_PATTERNS.some((pattern) => pattern.test(normalized))) {
    return {
      safetyOutcome: 'blocked',
      safetyReasonCode: 'prompt_injection_attempt',
      localizedMessage: LOCALE_TEXT[locale].blocked,
      category,
    };
  }
  if (CROSS_TENANT_PATTERNS.some((pattern) => pattern.test(normalized)) ||
      TOOL_ESCALATION_PATTERNS.some((pattern) => pattern.test(normalized))) {
    return {
      safetyOutcome: 'blocked',
      safetyReasonCode: 'cross_tenant_data_request',
      localizedMessage: LOCALE_TEXT[locale].blocked,
      category,
    };
  }
  if (HARMFUL_CONTENT_PATTERNS.some((pattern) => pattern.test(normalized))) {
    return {
      safetyOutcome: 'blocked',
      safetyReasonCode: 'disallowed_content_request',
      localizedMessage: LOCALE_TEXT[locale].blocked,
      category,
    };
  }
  return {
    safetyOutcome: 'allowed',
    safetyReasonCode: 'none',
    localizedMessage: '',
    category,
  };
}

function clampProbability(value: number): number {
  if (!Number.isFinite(value)) return 0;
  return Math.max(0, Math.min(1, value));
}

function inferVoiceIntent(message: string, role: VoiceRole, safetyOutcome: SafetyOutcome): VoiceIntent {
  if (safetyOutcome !== 'allowed' && safetyOutcome !== 'modified') return 'safety_support';
  if (TRANSLATION_PATTERNS.some((pattern) => pattern.test(message))) return 'translation_request';
  if (HINT_REQUEST_PATTERNS.some((pattern) => pattern.test(message))) return 'hint_request';
  if (EXPLAIN_REQUEST_PATTERNS.some((pattern) => pattern.test(message))) return 'explain_request';
  if (PLANNING_PATTERNS.some((pattern) => pattern.test(message))) return 'planning_request';
  if (REFLECTION_PATTERNS.some((pattern) => pattern.test(message))) return 'reflection';
  if (role === 'student') return 'hint_request';
  return 'general_support';
}

function inferVoiceComplexity(message: string): VoiceComplexity {
  if (!message) return 'low';
  if (HIGH_COMPLEXITY_PATTERNS.some((pattern) => pattern.test(message))) return 'high';
  if (LOW_COMPLEXITY_PATTERNS.some((pattern) => pattern.test(message))) return 'low';
  const tokenCount = message.split(/\s+/).filter(Boolean).length;
  if (tokenCount >= 18 || /[,;:]/.test(message)) return 'high';
  if (tokenCount <= 7) return 'low';
  if (/[\u4e00-\u9fff\u0E00-\u0E7F]/.test(message) && message.length >= 28) return 'high';
  return 'medium';
}

function inferVoiceEmotionalState(message: string): VoiceEmotionalState {
  if (FRUSTRATION_PATTERNS.some((pattern) => pattern.test(message))) return 'frustrated';
  if (CONFIDENCE_PATTERNS.some((pattern) => pattern.test(message))) return 'confident';
  return 'neutral';
}

function inferTopicTags(message: string): string[] {
  const tags: string[] = [];
  for (const candidate of TOPIC_TAG_PATTERNS) {
    if (candidate.patterns.some((pattern) => pattern.test(message))) {
      tags.push(candidate.tag);
    }
  }
  return tags.slice(0, 4);
}

function responseModeForIntent(intent: VoiceIntent): VoiceResponseMode {
  if (intent === 'translation_request') return 'translate';
  if (intent === 'planning_request') return 'plan';
  if (intent === 'explain_request' || intent === 'reflection') return 'explain';
  if (intent === 'safety_support') return 'safety';
  return 'hint';
}

function deriveUnderstandingSignal(input: {
  message: string;
  role: VoiceRole;
  safety: SafetyDecision;
}): VoiceUnderstandingSignal {
  const intent = inferVoiceIntent(input.message, input.role, input.safety.safetyOutcome);
  const complexity = inferVoiceComplexity(input.message);
  const emotionalState = inferVoiceEmotionalState(input.message);
  const topicTags = inferTopicTags(input.message);
  const responseMode = responseModeForIntent(intent);
  const needsScaffold = input.role === 'student'
    ? (complexity !== 'low' || emotionalState === 'frustrated' || intent === 'hint_request' || intent === 'explain_request')
    : (emotionalState === 'frustrated' || complexity === 'high');

  let confidence = 0.55;
  if (intent !== 'general_support') confidence += 0.17;
  if (topicTags.length > 0) confidence += 0.1;
  if (complexity === 'medium') confidence += 0.05;
  if (complexity === 'high') confidence -= 0.08;
  if (emotionalState === 'frustrated') confidence -= 0.08;
  if (input.safety.category !== 'generic') confidence += 0.05;
  if (input.safety.safetyOutcome !== 'allowed' && input.safety.safetyOutcome !== 'modified') {
    confidence = Math.max(confidence, 0.92);
  }

  return {
    intent,
    complexity,
    needsScaffold,
    emotionalState,
    confidence: clampProbability(confidence),
    responseMode,
    topicTags,
  };
}

function normalizeVoiceIntentValue(value: unknown): VoiceIntent | undefined {
  const normalized = normalizeString(value)?.toLowerCase();
  if (!normalized) return undefined;
  if (normalized === 'hint_request' || normalized === 'hint') return 'hint_request';
  if (normalized === 'explain_request' || normalized === 'explain') return 'explain_request';
  if (normalized === 'translation_request' || normalized === 'translate') return 'translation_request';
  if (normalized === 'planning_request' || normalized === 'plan') return 'planning_request';
  if (normalized === 'reflection' || normalized === 'reflect') return 'reflection';
  if (normalized === 'safety_support' || normalized === 'safety') return 'safety_support';
  if (normalized === 'general_support' || normalized === 'general') return 'general_support';
  return undefined;
}

function normalizeVoiceComplexityValue(value: unknown): VoiceComplexity | undefined {
  const normalized = normalizeString(value)?.toLowerCase();
  if (normalized === 'low' || normalized === 'medium' || normalized === 'high') {
    return normalized;
  }
  return undefined;
}

function normalizeVoiceEmotionalStateValue(value: unknown): VoiceEmotionalState | undefined {
  const normalized = normalizeString(value)?.toLowerCase();
  if (normalized === 'frustrated' || normalized === 'neutral' || normalized === 'confident') {
    return normalized;
  }
  return undefined;
}

function normalizeVoiceResponseModeValue(value: unknown): VoiceResponseMode | undefined {
  const normalized = normalizeString(value)?.toLowerCase();
  if (
    normalized === 'hint' ||
    normalized === 'explain' ||
    normalized === 'translate' ||
    normalized === 'plan' ||
    normalized === 'safety'
  ) {
    return normalized;
  }
  return undefined;
}

function parsePartialUnderstanding(input: unknown): PartialVoiceUnderstandingSignal | undefined {
  const source = asRecord(input);
  if (!source) return undefined;
  const intent = normalizeVoiceIntentValue(source.intent ?? source.understandingIntent);
  const complexity = normalizeVoiceComplexityValue(source.complexity);
  const emotionalState = normalizeVoiceEmotionalStateValue(source.emotionalState);
  const responseMode = normalizeVoiceResponseModeValue(source.responseMode);
  const confidenceRaw = firstNumber(source.confidence, source.understandingConfidence);
  const confidence = confidenceRaw !== undefined ? clampProbability(confidenceRaw) : undefined;
  const topicTags = normalizeStringArray(source.topicTags);
  const needsScaffoldRaw = source.needsScaffold;
  const needsScaffold = typeof needsScaffoldRaw === 'boolean' ? needsScaffoldRaw : undefined;

  const out: PartialVoiceUnderstandingSignal = {};
  if (intent) out.intent = intent;
  if (complexity) out.complexity = complexity;
  if (emotionalState) out.emotionalState = emotionalState;
  if (responseMode) out.responseMode = responseMode;
  if (confidence !== undefined) out.confidence = confidence;
  if (needsScaffold !== undefined) out.needsScaffold = needsScaffold;
  if (topicTags.length > 0) out.topicTags = topicTags.slice(0, 6);

  return Object.keys(out).length > 0 ? out : undefined;
}

function mergeUnderstandingSignal(
  base: VoiceUnderstandingSignal,
  override?: PartialVoiceUnderstandingSignal,
): VoiceUnderstandingSignal {
  if (!override) return base;
  const confidence = override.confidence !== undefined
    ? clampProbability((base.confidence * 0.55) + (override.confidence * 0.45))
    : base.confidence;
  return {
    intent: override.intent ?? base.intent,
    complexity: override.complexity ?? base.complexity,
    needsScaffold: override.needsScaffold ?? base.needsScaffold,
    emotionalState: override.emotionalState ?? base.emotionalState,
    responseMode: override.responseMode ?? base.responseMode,
    confidence,
    topicTags: dedupeStrings([...(base.topicTags ?? []), ...((override.topicTags ?? []).slice(0, 6))]).slice(0, 6),
  };
}

function buildAdaptiveLocalizedResponse(
  role: VoiceRole,
  locale: VoiceLocale,
  category: SafetyDecision['category'],
  understanding: VoiceUnderstandingSignal,
): string {
  const base = generateLocalizedResponse(role, locale, category);
  const localized = LOCALE_INTELLIGENCE_TEXT[locale];
  let nextStep = localized.hintStep;
  if (understanding.responseMode === 'explain') nextStep = localized.explainStep;
  if (understanding.responseMode === 'translate') nextStep = localized.translationStep;
  if (understanding.responseMode === 'plan') nextStep = localized.planningStep;
  if (understanding.intent === 'reflection') nextStep = localized.reflectionStep;
  const pieces = [base];
  if (understanding.emotionalState === 'frustrated') pieces.push(localized.frustrationSupport);
  pieces.push(nextStep);
  if (understanding.needsScaffold && understanding.responseMode !== 'safety') {
    pieces.push(localized.scaffoldPrompt);
  }
  return pieces.filter(Boolean).join(' ').replace(/\s+/g, ' ').trim();
}

function generateLocalizedResponse(role: VoiceRole, locale: VoiceLocale, category: SafetyDecision['category']): string {
  const localized = LOCALE_TEXT[locale];
  if (role === 'student' && category === 'focus_nudge') return localized.focusNudge;
  if (role === 'student') return localized.studentGeneric;
  if (role === 'teacher' && category === 'teacher_productivity') return localized.teacherProductive;
  if (role === 'teacher') return localized.teacherGeneric;
  return localized.adminGeneric;
}

function selectToolCalls(
  role: VoiceRole,
  category: SafetyDecision['category'],
  safetyOutcome: SafetyOutcome,
  understanding?: VoiceUnderstandingSignal,
  modelToolHints?: string[],
): string[] {
  if (safetyOutcome !== 'allowed' && safetyOutcome !== 'modified') return [];
  const allowedTools = ROLE_ALLOWED_TOOLS[role];
  const hinted = dedupeStrings((modelToolHints ?? []).map((tool) => tool.trim()).filter(Boolean))
    .filter((tool) => allowedTools.includes(tool));
  if (hinted.length > 0) {
    return hinted.slice(0, 3);
  }
  if (understanding?.responseMode === 'translate' && allowedTools.includes('translate')) {
    return ['translate'];
  }
  if (understanding?.responseMode === 'explain' && role === 'student') {
    return ['hint_ladder', 'read_aloud'];
  }
  if (understanding?.responseMode === 'plan' && role === 'teacher') {
    return ['differentiate_lesson', 'class_summary'];
  }
  if (role === 'student' && category === 'focus_nudge') return ['hint_ladder', 'read_aloud'];
  if (role === 'teacher' && category === 'teacher_productivity') return ['differentiate_lesson', 'rubric_feedback_draft'];
  if (role === 'admin') return ['setup_help'];
  return [allowedTools[0]];
}

function detectLanguageCompatibility(text: string, locale: VoiceLocale): boolean {
  if (!text.trim()) return false;
  if (locale === 'en') return /[A-Za-z]/.test(text);
  if (locale === 'zh-CN') return /[\u4e00-\u9fff]/.test(text);
  if (locale === 'zh-TW') return /[\u4e00-\u9fff]/.test(text);
  if (locale === 'th') return /[\u0E00-\u0E7F]/.test(text);
  return false;
}

function buildInferenceContextHeaders(input: {
  traceId: string;
  requestId: string;
  authContext: VoiceAuthContext;
  locale: VoiceLocale;
  callerService: string;
}): {
  traceId: string;
  siteId: string;
  role: string;
  gradeBand: string;
  locale: string;
  policyVersion: string;
  requestId: string;
  callerService: string;
} {
  return {
    traceId: input.traceId,
    siteId: input.authContext.siteId,
    role: input.authContext.role,
    gradeBand: toCanonicalGradeBand(input.authContext.gradeBand),
    locale: input.locale,
    policyVersion: VOICE_POLICY_VERSION,
    requestId: input.requestId,
    callerService: input.callerService,
  };
}

function normalizeInferenceAuthMode(value: unknown): InternalInferenceAuthMode {
  if (value === 'metadata' || value === 'none' || value === 'static') return value;
  return 'none';
}

function buildLocalInferenceMeta(service: VoiceInferenceMeta['service'], reason?: string): VoiceInferenceMeta {
  return {
    service,
    route: 'local',
    authMode: 'none',
    ...(reason ? { reason } : {}),
  };
}

function buildInferenceMeta(
  service: VoiceInferenceMeta['service'],
  result: InternalInferenceCallResult<Record<string, unknown>>,
  fallbackReason?: string,
): VoiceInferenceMeta {
  return {
    service,
    route: result.meta.route,
    authMode: normalizeInferenceAuthMode(result.meta.authMode),
    ...(result.meta.statusCode ? { statusCode: result.meta.statusCode } : {}),
    ...(result.meta.endpoint ? { endpoint: result.meta.endpoint } : {}),
    ...(result.errorCode ? { errorCode: result.errorCode } : {}),
    ...(fallbackReason ? { reason: fallbackReason } : {}),
  };
}

function asRecord(value: unknown): Record<string, unknown> | undefined {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return undefined;
  return value as Record<string, unknown>;
}

function firstString(...values: unknown[]): string | undefined {
  for (const value of values) {
    const normalized = normalizeString(value);
    if (normalized) return normalized;
  }
  return undefined;
}

function firstNumber(...values: unknown[]): number | undefined {
  for (const value of values) {
    const numeric = typeof value === 'number' ? value : Number(value);
    if (Number.isFinite(numeric)) return numeric;
  }
  return undefined;
}

function extractInternalLlmPayload(data: unknown): {
  text?: string;
  modelVersion?: string;
  understanding?: PartialVoiceUnderstandingSignal;
  toolSuggestions: string[];
} {
  const root = asRecord(data);
  const response = asRecord(root?.response);
  const output = asRecord(root?.output);
  const choices = Array.isArray(root?.choices) ? root?.choices : [];
  const firstChoice = asRecord(choices[0]);
  const firstMessage = asRecord(firstChoice?.message);
  const text = firstString(
    root?.text,
    root?.responseText,
    root?.outputText,
    root?.message,
    response?.text,
    output?.text,
    firstChoice?.text,
    firstMessage?.content,
  );
  const toolCandidates = [
    ...(Array.isArray(root?.toolSuggestions) ? root?.toolSuggestions : []),
    ...(Array.isArray(root?.tools) ? root?.tools : []),
    ...(Array.isArray(response?.toolSuggestions) ? response?.toolSuggestions : []),
    ...(Array.isArray(response?.tools) ? response?.tools : []),
  ];
  const toolSuggestions = dedupeStrings(
    toolCandidates
      .map((entry) => normalizeString(entry))
      .filter((entry): entry is string => Boolean(entry)),
  ).slice(0, 6);
  const understanding = parsePartialUnderstanding(
    root?.understanding ??
      response?.understanding ??
      output?.understanding ??
      firstChoice?.understanding ??
      firstMessage?.understanding,
  );

  return {
    text: text ? normalizeSpeechText(text) : undefined,
    modelVersion: firstString(root?.modelVersion, root?.model, response?.modelVersion, output?.modelVersion),
    understanding,
    toolSuggestions,
  };
}

function extractInternalSttPayload(data: unknown): {
  transcript?: string;
  confidence?: number;
  modelVersion?: string;
  understanding?: PartialVoiceUnderstandingSignal;
} {
  const root = asRecord(data);
  const metadata = asRecord(root?.metadata);
  const result = asRecord(root?.result);
  const transcript = firstString(
    root?.transcript,
    root?.text,
    result?.transcript,
    result?.text,
    metadata?.transcript,
  );
  const confidenceRaw = firstNumber(root?.confidence, result?.confidence, metadata?.confidence);
  const confidence = confidenceRaw !== undefined ? clampProbability(confidenceRaw) : undefined;

  return {
    transcript,
    confidence,
    modelVersion: firstString(root?.modelVersion, root?.model, metadata?.modelVersion, result?.modelVersion),
    understanding: parsePartialUnderstanding(
      root?.understanding ??
        result?.understanding ??
        metadata?.understanding,
    ),
  };
}

function extractInternalTtsPayload(data: unknown): { audioUrl?: string; voiceProfile?: string; modelVersion?: string } {
  const root = asRecord(data);
  const metadata = asRecord(root?.metadata);
  const result = asRecord(root?.result);
  const audio = asRecord(root?.audio);
  const audioUrl = firstString(root?.audioUrl, result?.audioUrl, audio?.url, metadata?.audioUrl);

  return {
    audioUrl,
    voiceProfile: firstString(root?.voiceProfile, result?.voiceProfile, metadata?.voiceProfile),
    modelVersion: firstString(root?.modelVersion, root?.model, result?.modelVersion, metadata?.modelVersion),
  };
}

function internalAudioHostAllowlist(): string[] {
  const defaults = ['scholesa-ai', 'scholesa-tts', 'scholesa-stt', 'cloudfunctions.net', 'a.run.app', 'localhost', '127.0.0.1'];
  const fromEnv = normalizeString(process.env.INTERNAL_AI_HOST_ALLOWLIST);
  if (!fromEnv) return defaults;
  const parsed = fromEnv.split(',').map((entry) => entry.trim().toLowerCase()).filter(Boolean);
  return parsed.length > 0 ? parsed : defaults;
}

function isInternalAudioUrl(urlValue: string): boolean {
  const trimmed = urlValue.trim();
  if (!trimmed) return false;
  if (trimmed.startsWith('/') && !trimmed.startsWith('//')) return true;
  try {
    const parsed = new URL(trimmed);
    const host = parsed.hostname.toLowerCase();
    return internalAudioHostAllowlist().some((marker) =>
      host === marker || host.endsWith(`.${marker}`) || host.includes(marker));
  } catch {
    return false;
  }
}

function chooseVoiceProfile(locale: VoiceLocale, role: VoiceRole, gradeBand: GradeBand): string {
  if (role === 'student' && gradeBand === 'K-5') return `${locale}.k5_safe_neutral`;
  if (role === 'teacher' || role === 'admin') return `${locale}.professional_concise`;
  return `${locale}.student_neutral`;
}

function prosodyPolicyTag(role: VoiceRole, gradeBand: GradeBand): string {
  if (role === 'student' && gradeBand === 'K-5') return 'k5_safe_mode';
  if (role === 'student') return 'student_standard_mode';
  return 'professional_mode';
}

function redactTextForSpeech(text: string, knownNames: string[]): SpeechPreparation {
  let redacted = text;
  let redactionCount = 0;
  for (const name of knownNames) {
    const escaped = name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const regex = new RegExp(`\\b${escaped}\\b`, 'gi');
    if (regex.test(redacted)) {
      redacted = redacted.replace(regex, '[NAME]');
      redactionCount += 1;
    }
  }
  redacted = redacted.replace(EMAIL_PATTERN, () => {
    redactionCount += 1;
    return '[EMAIL]';
  });
  redacted = redacted.replace(PHONE_PATTERN, () => {
    redactionCount += 1;
    return '[PHONE]';
  });
  redacted = redacted.replace(ADDRESS_PATTERN, () => {
    redactionCount += 1;
    return '[ADDRESS]';
  });
  redacted = redacted.replace(ID_PATTERN, () => {
    redactionCount += 1;
    return '[ID]';
  });
  return {
    speechText: redacted,
    redactionApplied: redactionCount > 0,
    redactionCount,
  };
}

function normalizeSpeechText(text: string): string {
  const collapsed = text.replace(/\s+/g, ' ').trim();
  if (!collapsed) return '';
  return collapsed.slice(0, 2000);
}

function tokenSecret(): string {
  return process.env.VOICE_SIGNING_SECRET || process.env.GOOGLE_CLOUD_PROJECT || 'scholesa-voice-secret';
}

function encodeBase64Url(input: string): string {
  return Buffer.from(input, 'utf8')
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/g, '');
}

function decodeBase64Url(input: string): string {
  const normalized = input.replace(/-/g, '+').replace(/_/g, '/');
  const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, '=');
  return Buffer.from(padded, 'base64').toString('utf8');
}

function signPayload(payloadBase64: string): string {
  return createHmac('sha256', tokenSecret())
    .update(payloadBase64)
    .digest('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/g, '');
}

function createAudioToken(payload: AudioTokenPayload): string {
  const json = JSON.stringify(payload);
  const encoded = encodeBase64Url(json);
  const signature = signPayload(encoded);
  return `${encoded}.${signature}`;
}

function verifyAudioToken(token: string): AudioTokenPayload {
  const [encoded, signature] = token.split('.');
  if (!encoded || !signature) throw new VoiceHttpError(400, 'invalid_token', 'Malformed audio token.');
  const expectedSignature = signPayload(encoded);
  if (signature !== expectedSignature) throw new VoiceHttpError(403, 'invalid_token', 'Audio token signature mismatch.');
  let parsed: AudioTokenPayload;
  try {
    parsed = JSON.parse(decodeBase64Url(encoded)) as AudioTokenPayload;
  } catch {
    throw new VoiceHttpError(400, 'invalid_token', 'Unable to decode audio token.');
  }
  if (!parsed.expMs || Date.now() > parsed.expMs) {
    throw new VoiceHttpError(410, 'expired_token', 'Audio token has expired.');
  }
  const checksum = createHash('sha256')
    .update(`${parsed.traceId}|${parsed.locale}|${parsed.voiceProfile}|${parsed.text}|${parsed.expMs}`)
    .digest('hex');
  if (parsed.checksum !== checksum) {
    throw new VoiceHttpError(403, 'invalid_token', 'Audio token payload checksum mismatch.');
  }
  return parsed;
}

function functionBasePath(req: Request): string {
  const originalUrl = req.originalUrl || req.url || '';
  const path = req.path || '';
  if (path && originalUrl.includes(path)) {
    return originalUrl.slice(0, originalUrl.indexOf(path));
  }
  return originalUrl;
}

function buildAudioUrl(req: Request, token: string): string {
  const explicitBase = normalizeString(process.env.VOICE_PUBLIC_BASE_URL);
  if (explicitBase) {
    return `${explicitBase.replace(/\/+$/g, '')}/voice/audio/${encodeURIComponent(token)}`;
  }
  const host = req.get('host');
  if (!host) {
    throw new VoiceHttpError(500, 'internal', 'Unable to build audio URL because host header is missing.');
  }
  const protoHeader = req.get('x-forwarded-proto') || req.protocol || 'https';
  const proto = protoHeader.split(',')[0]?.trim() || 'https';
  const basePath = functionBasePath(req);
  return `${proto}://${host}${basePath}/voice/audio/${encodeURIComponent(token)}`;
}

function buildWavHeader(dataLength: number, sampleRate: number): Buffer {
  const blockAlign = 2;
  const byteRate = sampleRate * blockAlign;
  const buffer = Buffer.alloc(44);
  buffer.write('RIFF', 0, 4, 'ascii');
  buffer.writeUInt32LE(36 + dataLength, 4);
  buffer.write('WAVE', 8, 4, 'ascii');
  buffer.write('fmt ', 12, 4, 'ascii');
  buffer.writeUInt32LE(16, 16);
  buffer.writeUInt16LE(1, 20);
  buffer.writeUInt16LE(1, 22);
  buffer.writeUInt32LE(sampleRate, 24);
  buffer.writeUInt32LE(byteRate, 28);
  buffer.writeUInt16LE(blockAlign, 32);
  buffer.writeUInt16LE(16, 34);
  buffer.write('data', 36, 4, 'ascii');
  buffer.writeUInt32LE(dataLength, 40);
  return buffer;
}

function synthesizeAudioWave(text: string, locale: VoiceLocale): Buffer {
  const sampleRate = 16_000;
  const normalized = text.length > 0 ? text : locale;
  const durationSeconds = Math.min(6, Math.max(1, normalized.length * 0.04));
  const sampleCount = Math.max(1, Math.floor(sampleRate * durationSeconds));
  const pcm = Buffer.alloc(sampleCount * 2);
  const localeBias = locale === 'th' ? 30 : locale === 'zh-CN' ? 45 : locale === 'zh-TW' ? 60 : 0;
  for (let i = 0; i < sampleCount; i += 1) {
    const charCode = normalized.charCodeAt(i % normalized.length);
    const frequency = 200 + ((charCode + localeBias) % 180);
    const amplitude = Math.floor(9000 * (0.6 + (charCode % 20) / 100));
    const sample = Math.floor(amplitude * Math.sin((2 * Math.PI * frequency * i) / sampleRate));
    pcm.writeInt16LE(sample, i * 2);
  }
  const header = buildWavHeader(pcm.length, sampleRate);
  return Buffer.concat([header, pcm]);
}

function cleanTranscript(input: string): string {
  const trimmed = input.replace(/\s+/g, ' ').trim();
  if (!trimmed) return '';
  if (/[.!?。！？]$/.test(trimmed)) return trimmed;
  if (/[\u4e00-\u9fff\u0E00-\u0E7F]/.test(trimmed)) return `${trimmed}`;
  return `${trimmed}.`;
}

function defaultTranscriptByLocale(locale: VoiceLocale): string {
  if (locale === 'zh-CN') return '请给我一个下一步的提示';
  if (locale === 'zh-TW') return '請給我下一步提示';
  if (locale === 'th') return 'ช่วยบอกใบ้ขั้นตอนถัดไปหน่อย';
  return 'Please give me a hint for the next step';
}

function parseMultipartForm(req: Request): {
  fields: Record<string, string>;
  files: Record<string, { filename: string; contentType: string; data: Buffer }>;
} {
  const contentType = req.header('content-type') || '';
  const boundaryMatch = /boundary=(?:"([^"]+)"|([^;]+))/i.exec(contentType);
  if (!boundaryMatch) return { fields: {}, files: {} };
  const boundaryValue = boundaryMatch[1] || boundaryMatch[2];
  if (!boundaryValue) return { fields: {}, files: {} };

  const rawBody = (req as Request & { rawBody?: Buffer }).rawBody;
  if (!rawBody || rawBody.length === 0) return { fields: {}, files: {} };

  const boundary = `--${boundaryValue}`;
  const raw = rawBody.toString('latin1');
  const parts = raw.split(boundary);
  const fields: Record<string, string> = {};
  const files: Record<string, { filename: string; contentType: string; data: Buffer }> = {};

  for (const part of parts) {
    const normalizedPart = part.trim();
    if (!normalizedPart || normalizedPart === '--') continue;
    const separatorIndex = part.indexOf('\r\n\r\n');
    if (separatorIndex < 0) continue;
    const headerBlock = part.slice(0, separatorIndex);
    let bodyBlock = part.slice(separatorIndex + 4);
    bodyBlock = bodyBlock.replace(/\r\n--$/, '').replace(/\r\n$/, '');

    const dispositionMatch = /content-disposition:\s*form-data;\s*name="([^"]+)"(?:;\s*filename="([^"]+)")?/i.exec(headerBlock);
    if (!dispositionMatch) continue;
    const fieldName = dispositionMatch[1];
    const filename = dispositionMatch[2];
    const contentTypeMatch = /content-type:\s*([^\r\n]+)/i.exec(headerBlock);
    const partContentType = contentTypeMatch ? contentTypeMatch[1].trim() : 'application/octet-stream';

    if (filename) {
      files[fieldName] = {
        filename,
        contentType: partContentType,
        data: Buffer.from(bodyBlock, 'latin1'),
      };
    } else {
      fields[fieldName] = Buffer.from(bodyBlock, 'latin1').toString('utf8').trim();
    }
  }
  return { fields, files };
}

function parseJsonObjectField(rawValue: string | undefined): Record<string, unknown> | undefined {
  if (!rawValue) return undefined;
  try {
    const parsed = JSON.parse(rawValue);
    if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) {
      return parsed as Record<string, unknown>;
    }
    return undefined;
  } catch {
    return undefined;
  }
}

async function maybeValidateTeacherLearnerScope(
  context: VoiceAuthContext,
  body: Record<string, unknown>,
): Promise<void> {
  if (context.role !== 'teacher') return;
  const selectedLearnerId = normalizeString((body.context as Record<string, unknown> | undefined)?.selectedLearnerId);
  if (!selectedLearnerId) return;
  const learnerSnap = await admin.firestore().collection('users').doc(selectedLearnerId).get();
  if (!learnerSnap.exists) {
    throw new VoiceHttpError(403, 'permission_denied', 'selectedLearnerId is not accessible in this tenant scope.');
  }
  const learner = learnerSnap.data() as Record<string, unknown>;
  const learnerRole = normalizeRole(learner.role);
  if (learnerRole !== 'student') {
    throw new VoiceHttpError(403, 'permission_denied', 'selectedLearnerId must refer to a student.');
  }
  const learnerSiteIds = dedupeStrings([
    ...normalizeStringArray(learner.siteIds),
    ...(normalizeString(learner.activeSiteId) ? [String(learner.activeSiteId)] : []),
  ]);
  if (!learnerSiteIds.includes(context.siteId)) {
    throw new VoiceHttpError(403, 'permission_denied', 'selectedLearnerId is outside the teacher tenant scope.');
  }
}

async function recordVoiceAuditEvent(payload: {
  eventType: VoiceTelemetryEvent;
  endpoint: string;
  requestId: string;
  traceId: string;
  authContext: VoiceAuthContext;
  locale: VoiceLocale;
  safetyOutcome: SafetyOutcome;
  redactionApplied?: boolean;
  redactionCount?: number;
  quietModeActive?: boolean;
  toolCount?: number;
  latencyMs: number;
}) {
  const canonicalGradeBand = toCanonicalGradeBand(payload.authContext.gradeBand);
  const telemetryEnv = resolveTelemetryEnv();

  await admin.firestore().collection('voiceAuditEvents').add({
    eventType: payload.eventType,
    endpoint: payload.endpoint,
    requestId: payload.requestId,
    traceId: payload.traceId,
    service: payload.endpoint === 'voice_transcribe'
      ? 'scholesa-stt'
      : payload.endpoint === 'tts_speak'
      ? 'scholesa-tts'
      : 'scholesa-ai',
    env: telemetryEnv,
    uid: payload.authContext.uid,
    role: payload.authContext.role,
    siteId: payload.authContext.siteId,
    gradeBand: payload.authContext.gradeBand,
    gradeBandCanonical: canonicalGradeBand,
    locale: payload.locale,
    safetyOutcome: payload.safetyOutcome,
    redactionApplied: payload.redactionApplied ?? false,
    redactionCount: payload.redactionCount ?? 0,
    quietModeActive: payload.quietModeActive ?? false,
    toolCount: payload.toolCount ?? 0,
    latencyMs: payload.latencyMs,
    timestamp: new Date().toISOString(),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

async function recordVoiceTelemetryEvent(payload: {
  event: SupportedTelemetryEvent;
  endpoint: string;
  requestId: string;
  traceId: string;
  authContext: VoiceAuthContext;
  locale: VoiceLocale;
  latencyMs: number;
  safetyOutcome?: SafetyOutcome;
  redactionApplied?: boolean;
  redactionCount?: number;
  quietModeActive?: boolean;
  toolCount?: number;
  transcriptProvided?: boolean;
  transcriptLength?: number;
  partial?: boolean;
  audioBytes?: number;
  textLength?: number;
  understanding?: VoiceUnderstandingSignal;
  modelVersionOverride?: string;
  inference?: VoiceInferenceMeta;
}) {
  const canonicalGradeBand = toCanonicalGradeBand(payload.authContext.gradeBand);
  const telemetryEnv = resolveTelemetryEnv();
  const service = payload.endpoint === 'voice_transcribe'
    ? 'scholesa-stt'
    : payload.endpoint === 'tts_speak'
    ? 'scholesa-tts'
    : 'scholesa-ai';
  const timestampIso = new Date().toISOString();

  await admin.firestore().collection(TELEMETRY_COLLECTION).add({
    event: payload.event,
    eventType: payload.event,
    userId: payload.authContext.uid || 'system',
    role: payload.authContext.role || 'system',
    siteId: payload.authContext.siteId || TELEMETRY_UNSCOPED_SITE_ID,
    service,
    env: telemetryEnv,
    traceId: payload.traceId,
    gradeBand: canonicalGradeBand,
    locale: payload.locale,
    timestampIso,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    metadata: {
      requestId: payload.requestId,
      traceId: payload.traceId,
      service,
      env: telemetryEnv,
      siteId: payload.authContext.siteId,
      role: payload.authContext.role,
      gradeBand: canonicalGradeBand,
      locale: payload.locale,
      eventType: payload.event,
      endpoint: payload.endpoint,
      timestamp: timestampIso,
      timestampIso,
      latencyMs: payload.latencyMs,
      safetyOutcome: payload.safetyOutcome ?? 'allowed',
      redactionApplied: payload.redactionApplied ?? false,
      redactionCount: payload.redactionCount ?? 0,
      quietModeActive: payload.quietModeActive ?? false,
      toolCount: payload.toolCount ?? 0,
      transcriptProvided: payload.transcriptProvided ?? false,
      transcriptLength: payload.transcriptLength ?? 0,
      partial: payload.partial ?? false,
      audioPresent: (payload.audioBytes ?? 0) > 0,
      textLength: payload.textLength ?? 0,
      understandingIntent: payload.understanding?.intent ?? 'general_support',
      understandingConfidence: payload.understanding?.confidence ?? 0,
      responseMode: payload.understanding?.responseMode ?? 'hint',
      needsScaffold: payload.understanding?.needsScaffold ?? false,
      emotionalState: payload.understanding?.emotionalState ?? 'neutral',
      complexity: payload.understanding?.complexity ?? 'medium',
      topicTags: payload.understanding?.topicTags ?? [],
      modelVersion: payload.modelVersionOverride ??
        (payload.event === 'voice.transcribe'
          ? STT_MODEL_VERSION
          : payload.event === 'voice.tts'
          ? TTS_MODEL_VERSION
          : VOICE_MODEL_VERSION),
      policyVersion: VOICE_POLICY_VERSION,
      redactedPathCount: 0,
      inferenceService: payload.inference?.service ?? null,
      inferenceRoute: payload.inference?.route ?? 'local',
      inferenceAuthMode: payload.inference?.authMode ?? 'none',
      inferenceStatusCode: payload.inference?.statusCode ?? null,
      inferenceErrorCode: payload.inference?.errorCode ?? null,
      inferenceReason: payload.inference?.reason ?? null,
    },
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

async function recordBosInteractionEvent(payload: {
  eventType: BosInteractionEvent;
  endpoint: string;
  requestId: string;
  traceId: string;
  authContext: VoiceAuthContext;
  body: Record<string, unknown>;
  locale: VoiceLocale;
  safetyOutcome: SafetyOutcome;
  latencyMs: number;
  toolCount?: number;
  textLength?: number;
  transcriptLength?: number;
  audioBytes?: number;
  ttsAvailable?: boolean;
  understanding?: VoiceUnderstandingSignal;
  inference?: VoiceInferenceMeta;
}) {
  const bosContext = resolveBosInteractionContext(payload.body, payload.authContext);
  const telemetryEnv = resolveTelemetryEnv();
  const service = payload.endpoint === 'voice_transcribe'
    ? 'scholesa-stt'
    : payload.endpoint === 'tts_speak'
    ? 'scholesa-tts'
    : 'scholesa-ai';
  const gradeBandCanonical = toCanonicalGradeBand(payload.authContext.gradeBand);

  await admin.firestore().collection(BOS_INTERACTION_COLLECTION).add({
    event: payload.eventType,
    eventType: payload.eventType,
    requestId: payload.requestId,
    traceId: payload.traceId,
    service,
    env: telemetryEnv,
    siteId: payload.authContext.siteId,
    actorId: bosContext.actorId,
    actorRole: bosContext.actorRole,
    role: payload.authContext.role,
    gradeBand: toBosGradeBand(payload.authContext.gradeBand),
    gradeBandCanonical,
    locale: payload.locale,
    sessionOccurrenceId: bosContext.sessionOccurrenceId ?? null,
    missionId: bosContext.missionId ?? null,
    checkpointId: bosContext.checkpointId ?? null,
    context: {
      source: 'voice',
      endpoint: payload.endpoint,
      locale: payload.locale,
      requestId: payload.requestId,
      traceId: payload.traceId,
      role: payload.authContext.role,
      gradeBand: gradeBandCanonical,
    },
    payload: {
      source: 'voice',
      endpoint: payload.endpoint,
      requestId: payload.requestId,
      traceId: payload.traceId,
      locale: payload.locale,
      safetyOutcome: payload.safetyOutcome,
      latencyMs: payload.latencyMs,
      toolCount: payload.toolCount ?? 0,
      textLength: payload.textLength ?? 0,
      transcriptLength: payload.transcriptLength ?? 0,
      audioPresent: (payload.audioBytes ?? 0) > 0,
      ttsAvailable: payload.ttsAvailable ?? false,
      requesterRole: payload.authContext.role,
      contextMode: bosContext.contextMode,
      conceptTags: bosContext.conceptTags,
      understandingIntent: payload.understanding?.intent ?? 'general_support',
      understandingConfidence: payload.understanding?.confidence ?? 0,
      responseMode: payload.understanding?.responseMode ?? 'hint',
      needsScaffold: payload.understanding?.needsScaffold ?? false,
      emotionalState: payload.understanding?.emotionalState ?? 'neutral',
      complexity: payload.understanding?.complexity ?? 'medium',
      topicTags: payload.understanding?.topicTags ?? [],
      inferenceService: payload.inference?.service ?? null,
      inferenceRoute: payload.inference?.route ?? 'local',
      inferenceAuthMode: payload.inference?.authMode ?? 'none',
      inferenceStatusCode: payload.inference?.statusCode ?? null,
      inferenceErrorCode: payload.inference?.errorCode ?? null,
      inferenceReason: payload.inference?.reason ?? null,
    },
    timestampIso: new Date().toISOString(),
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

async function upsertBosLearningProfile(payload: {
  endpoint: string;
  traceId: string;
  authContext: VoiceAuthContext;
  body: Record<string, unknown>;
  locale: VoiceLocale;
  safetyOutcome: SafetyOutcome;
  understanding?: VoiceUnderstandingSignal;
  textLength?: number;
  transcriptLength?: number;
}) {
  const bosContext = resolveBosInteractionContext(payload.body, payload.authContext);
  const profileId = `${payload.authContext.siteId}__${bosContext.actorId}`;
  const profileRef = admin.firestore().collection('bosLearningProfiles').doc(profileId);
  const nowIso = new Date().toISOString();

  const metrics: Record<string, unknown> = {
    totalInteractions: admin.firestore.FieldValue.increment(1),
  };
  if (payload.endpoint === 'voice_transcribe') {
    metrics.voiceTranscribeCount = admin.firestore.FieldValue.increment(1);
  } else if (payload.endpoint === 'tts_speak') {
    metrics.voiceTtsCount = admin.firestore.FieldValue.increment(1);
  } else {
    metrics.voiceMessageCount = admin.firestore.FieldValue.increment(1);
  }
  if (payload.safetyOutcome === 'blocked' || payload.safetyOutcome === 'modified') {
    metrics.blockedCount = admin.firestore.FieldValue.increment(1);
  }
  if (payload.safetyOutcome === 'escalated') {
    metrics.escalatedCount = admin.firestore.FieldValue.increment(1);
  }
  if ((payload.textLength ?? 0) > 0) {
    metrics.totalTextLength = admin.firestore.FieldValue.increment(payload.textLength ?? 0);
  }
  if ((payload.transcriptLength ?? 0) > 0) {
    metrics.totalTranscriptLength = admin.firestore.FieldValue.increment(payload.transcriptLength ?? 0);
  }

  const learning: Record<string, unknown> = {};
  if (payload.understanding) {
    metrics.intentCounts = {
      [payload.understanding.intent]: admin.firestore.FieldValue.increment(1),
    };
    metrics.understandingConfidence = {
      sum: admin.firestore.FieldValue.increment(payload.understanding.confidence),
      count: admin.firestore.FieldValue.increment(1),
    };
    if (payload.understanding.needsScaffold) {
      metrics.needsScaffoldCount = admin.firestore.FieldValue.increment(1);
    }
    if (payload.understanding.emotionalState === 'frustrated') {
      metrics.frustrationSignalCount = admin.firestore.FieldValue.increment(1);
    }
    learning.lastIntent = payload.understanding.intent;
    learning.lastComplexity = payload.understanding.complexity;
    learning.lastResponseMode = payload.understanding.responseMode;
    learning.lastNeedsScaffold = payload.understanding.needsScaffold;
    learning.lastEmotionalState = payload.understanding.emotionalState;
    learning.lastUnderstandingConfidence = payload.understanding.confidence;
    learning.lastTopicTags = payload.understanding.topicTags;
  }

  const updateDoc: Record<string, unknown> = {
    profileId,
    siteId: payload.authContext.siteId,
    actorId: bosContext.actorId,
    actorRole: bosContext.actorRole,
    roleCanonical: payload.authContext.role,
    locale: payload.locale,
    lastTraceId: payload.traceId,
    lastEndpoint: payload.endpoint,
    lastSafetyOutcome: payload.safetyOutcome,
    lastContextMode: bosContext.contextMode,
    updatedAtIso: nowIso,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    metrics,
  };
  if (Object.keys(learning).length > 0) {
    updateDoc.learning = learning;
  }

  await admin.firestore().runTransaction(async (transaction) => {
    const profileSnap = await transaction.get(profileRef);
    if (!profileSnap.exists) {
      transaction.set(profileRef, {
        ...updateDoc,
        createdAtIso: nowIso,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
      return;
    }
    transaction.set(profileRef, updateDoc, { merge: true });
  });
}

function normalizePath(pathValue: string): string {
  if (!pathValue) return '/';
  const trimmed = pathValue.trim();
  if (!trimmed) return '/';
  const normalized = trimmed.startsWith('/') ? trimmed : `/${trimmed}`;
  return normalized.replace(/\/+$/g, '') || '/';
}

function responseError(res: Response, error: unknown): void {
  if (error instanceof VoiceHttpError) {
    res.status(error.status).json({
      error: error.code,
      message: error.message,
      details: error.details ?? null,
    });
    return;
  }
  if (error instanceof HttpsError) {
    res.status(500).json({ error: error.code, message: error.message });
    return;
  }
  const fallbackMessage = error instanceof Error ? error.message : 'Unknown voice endpoint error';
  res.status(500).json({ error: 'internal', message: fallbackMessage });
}

async function enforceVoiceAccess(
  authContext: VoiceAuthContext,
  settings: VoiceSettings,
): Promise<void> {
  if (!isRoleEnabled(settings, authContext.role)) {
    throw new VoiceHttpError(403, 'permission_denied', 'Voice is disabled for this role or tenant.');
  }
  if (!settings.voiceEnabled) {
    throw new VoiceHttpError(403, 'permission_denied', 'Voice is disabled for this tenant.');
  }
}

function extractKnownNames(body: Record<string, unknown>): string[] {
  const context = body.context as Record<string, unknown> | undefined;
  const candidateLists: unknown[] = [
    context?.knownNames,
    context?.studentNames,
    context?.learnerNames,
  ];
  const merged = candidateLists.flatMap((candidate) => normalizeStringArray(candidate));
  return dedupeStrings(merged).slice(0, 20);
}

export async function handleCopilotMessage(req: Request, res: Response): Promise<void> {
  const startedAt = Date.now();
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'method_not_allowed', message: 'Use POST.' });
    return;
  }

  try {
    const body = parseJsonBody(req);
    const authContext = await resolveAuthContext(req, body);
    const settings = await loadVoiceSettings(authContext.siteId);
    await enforceVoiceAccess(authContext, settings);
    await maybeValidateTeacherLearnerScope(authContext, body);

    const locale = resolveLocale(body.locale, req, settings.allowedLocales);
    const message = normalizeSpeechText(normalizeString(body.message) ?? '');
    if (!message) {
      throw new VoiceHttpError(400, 'invalid_argument', 'message is required.');
    }

    const requestId = resolveRequestId(req);
    const traceId = resolveTraceId(req, body);
    const safety = evaluateSafetyDecision(message, authContext.role, locale);
    const heuristicUnderstanding = deriveUnderstandingSignal({
      message,
      role: authContext.role,
      safety,
    });
    let understanding = heuristicUnderstanding;
    let modelToolHints: string[] = [];
    const baselineCandidateText = safety.safetyOutcome === 'allowed'
      ? buildAdaptiveLocalizedResponse(authContext.role, locale, safety.category, understanding)
      : safety.localizedMessage;
    let candidateText = baselineCandidateText;
    let llmModelVersion = VOICE_MODEL_VERSION;
    let inferenceMeta: VoiceInferenceMeta = buildLocalInferenceMeta(
      'llm',
      safety.safetyOutcome === 'allowed' ? 'not_attempted' : 'safety_blocked',
    );
    if (safety.safetyOutcome === 'allowed') {
      const llmResult = await callInternalInferenceJson<Record<string, unknown>, Record<string, unknown>>({
        service: 'llm',
        body: {
          message,
          locale,
          role: authContext.role,
          gradeBand: authContext.gradeBand,
          safety: {
            outcome: safety.safetyOutcome,
            category: safety.category,
            reasonCode: safety.safetyReasonCode,
          },
          understanding: {
            intent: heuristicUnderstanding.intent,
            complexity: heuristicUnderstanding.complexity,
            needsScaffold: heuristicUnderstanding.needsScaffold,
            emotionalState: heuristicUnderstanding.emotionalState,
            confidence: heuristicUnderstanding.confidence,
            responseMode: heuristicUnderstanding.responseMode,
            topicTags: heuristicUnderstanding.topicTags,
          },
          maxTokens: 220,
        },
        context: buildInferenceContextHeaders({
          traceId,
          requestId,
          authContext,
          locale,
          callerService: 'scholesa-ai',
        }),
      });
      if (isInternalInferenceRequired() && !llmResult.ok) {
        throw new VoiceHttpError(503, 'inference_unavailable', 'Internal LLM inference is required but unavailable.');
      }

      const llmPayload = llmResult.ok ? extractInternalLlmPayload(llmResult.data) : undefined;
      const suggestedText = llmPayload?.text ? normalizeSpeechText(llmPayload.text) : undefined;
      if (llmPayload?.modelVersion) {
        llmModelVersion = llmPayload.modelVersion;
      }
      if (llmPayload?.understanding) {
        understanding = mergeUnderstandingSignal(understanding, llmPayload.understanding);
      }
      if ((llmPayload?.toolSuggestions?.length ?? 0) > 0) {
        modelToolHints = llmPayload?.toolSuggestions ?? [];
      }
      if (llmResult.ok && suggestedText) {
        const outputSafety = evaluateSafetyDecision(suggestedText, authContext.role, locale);
        if (outputSafety.safetyOutcome === 'allowed') {
          candidateText = suggestedText;
          inferenceMeta = buildInferenceMeta('llm', llmResult);
        } else if (outputSafety.safetyOutcome === 'modified') {
          candidateText = outputSafety.localizedMessage;
          inferenceMeta = buildInferenceMeta('llm', llmResult, 'model_output_modified');
        } else {
          inferenceMeta = buildInferenceMeta('llm', llmResult, 'model_output_blocked');
        }
      } else if (llmResult.ok) {
        if (isInternalInferenceRequired()) {
          throw new VoiceHttpError(503, 'inference_unavailable', 'Internal LLM response was empty.');
        }
        inferenceMeta = buildInferenceMeta('llm', llmResult, 'empty_model_text');
      } else {
        inferenceMeta = buildInferenceMeta('llm', llmResult, 'internal_call_failed');
      }
    }

    const toolsInvoked = selectToolCalls(
      authContext.role,
      safety.category,
      safety.safetyOutcome,
      understanding,
      modelToolHints,
    );
    const voiceInput = body.voice as Record<string, unknown> | undefined;
    const voiceOutputEnabled = normalizeBoolean(voiceInput?.enabled, true) && normalizeBoolean(voiceInput?.output, true);
    const quietModeActive = isQuietModeActive(settings, new Date());
    const knownNames = extractKnownNames(body);
    const preparedSpeech = redactTextForSpeech(candidateText, knownNames);
    const voiceProfile = chooseVoiceProfile(locale, authContext.role, authContext.gradeBand);
    const shouldSpeak = voiceOutputEnabled && !quietModeActive && preparedSpeech.speechText.length > 0;

    let audioUrl: string | undefined;
    if (shouldSpeak) {
      const expMs = Date.now() + AUDIO_TOKEN_TTL_MS;
      const checksum = createHash('sha256')
        .update(`${traceId}|${locale}|${voiceProfile}|${preparedSpeech.speechText}|${expMs}`)
        .digest('hex');
      const token = createAudioToken({
        traceId,
        locale,
        voiceProfile,
        text: preparedSpeech.speechText,
        expMs,
        checksum,
      });
      audioUrl = buildAudioUrl(req, token);
    }

    const adaptiveFallback = buildAdaptiveLocalizedResponse(authContext.role, locale, 'generic', understanding);
    const responseText = detectLanguageCompatibility(candidateText, locale)
      ? candidateText
      : adaptiveFallback;
    const latencyMs = Date.now() - startedAt;
    const supplementalSafetyEvent: VoiceTelemetryEvent | null =
      safety.safetyOutcome === 'escalated'
        ? 'voice.escalated'
        : (safety.safetyOutcome === 'blocked' || safety.safetyOutcome === 'modified')
        ? 'voice.blocked'
        : null;

    const telemetryWrites: Promise<unknown>[] = [
      recordVoiceAuditEvent({
        eventType: 'voice.message',
        endpoint: 'copilot_message',
        requestId,
        traceId,
        authContext,
        locale,
        safetyOutcome: safety.safetyOutcome,
        redactionApplied: preparedSpeech.redactionApplied,
        redactionCount: preparedSpeech.redactionCount,
        quietModeActive,
        toolCount: toolsInvoked.length,
        latencyMs,
      }),
      recordVoiceTelemetryEvent({
        event: 'voice.message',
        endpoint: 'copilot_message',
        requestId,
        traceId,
        authContext,
        locale,
        latencyMs,
        safetyOutcome: safety.safetyOutcome,
        redactionApplied: preparedSpeech.redactionApplied,
        redactionCount: preparedSpeech.redactionCount,
        quietModeActive,
        toolCount: toolsInvoked.length,
        textLength: message.length,
        understanding,
        modelVersionOverride: llmModelVersion,
        inference: inferenceMeta,
      }),
    ];

    const compatibilityWrites: Promise<unknown>[] = [
      upsertBosLearningProfile({
        endpoint: 'copilot_message',
        traceId,
        authContext,
        body,
        locale,
        safetyOutcome: safety.safetyOutcome,
        understanding,
        textLength: message.length,
      }),
      recordVoiceTelemetryEvent({
        event: 'ai_help_opened',
        endpoint: 'copilot_message',
        requestId,
        traceId,
        authContext,
        locale,
        latencyMs,
        safetyOutcome: safety.safetyOutcome,
        toolCount: toolsInvoked.length,
        textLength: message.length,
        understanding,
        modelVersionOverride: llmModelVersion,
        inference: inferenceMeta,
      }),
      recordVoiceTelemetryEvent({
        event: 'ai_help_used',
        endpoint: 'copilot_message',
        requestId,
        traceId,
        authContext,
        locale,
        latencyMs,
        safetyOutcome: safety.safetyOutcome,
        toolCount: toolsInvoked.length,
        textLength: message.length,
        understanding,
        modelVersionOverride: llmModelVersion,
        inference: inferenceMeta,
      }),
      recordVoiceTelemetryEvent({
        event: 'ai_coach_response',
        endpoint: 'copilot_message',
        requestId,
        traceId,
        authContext,
        locale,
        latencyMs,
        safetyOutcome: safety.safetyOutcome,
        toolCount: toolsInvoked.length,
        textLength: responseText.length,
        understanding,
        modelVersionOverride: llmModelVersion,
        inference: inferenceMeta,
      }),
      recordBosInteractionEvent({
        eventType: 'ai_help_opened',
        endpoint: 'copilot_message',
        requestId,
        traceId,
        authContext,
        body,
        locale,
        safetyOutcome: safety.safetyOutcome,
        latencyMs,
        toolCount: toolsInvoked.length,
        textLength: message.length,
        ttsAvailable: Boolean(audioUrl),
        understanding,
        inference: inferenceMeta,
      }),
      recordBosInteractionEvent({
        eventType: 'ai_help_used',
        endpoint: 'copilot_message',
        requestId,
        traceId,
        authContext,
        body,
        locale,
        safetyOutcome: safety.safetyOutcome,
        latencyMs,
        toolCount: toolsInvoked.length,
        textLength: message.length,
        ttsAvailable: Boolean(audioUrl),
        understanding,
        inference: inferenceMeta,
      }),
      recordBosInteractionEvent({
        eventType: 'ai_coach_response',
        endpoint: 'copilot_message',
        requestId,
        traceId,
        authContext,
        body,
        locale,
        safetyOutcome: safety.safetyOutcome,
        latencyMs,
        toolCount: toolsInvoked.length,
        textLength: responseText.length,
        ttsAvailable: Boolean(audioUrl),
        understanding,
        inference: inferenceMeta,
      }),
    ];

    if (supplementalSafetyEvent) {
      telemetryWrites.push(
        recordVoiceTelemetryEvent({
          event: supplementalSafetyEvent,
          endpoint: 'copilot_message',
          requestId,
          traceId,
          authContext,
          locale,
          latencyMs,
          safetyOutcome: safety.safetyOutcome,
          redactionApplied: preparedSpeech.redactionApplied,
          redactionCount: preparedSpeech.redactionCount,
          quietModeActive,
          toolCount: toolsInvoked.length,
          textLength: message.length,
          understanding,
          modelVersionOverride: llmModelVersion,
          inference: inferenceMeta,
        }),
      );
    }

    await Promise.all(telemetryWrites);
    await Promise.allSettled(compatibilityWrites);

    res.status(200).json({
      text: responseText,
      metadata: {
        requestId,
        traceId,
        safetyOutcome: safety.safetyOutcome,
        safetyReasonCode: safety.safetyReasonCode,
        policyVersion: VOICE_POLICY_VERSION,
        modelVersion: llmModelVersion,
        locale,
        role: authContext.role,
        gradeBand: authContext.gradeBand,
        toolsInvoked,
        quietModeActive,
        redactionApplied: preparedSpeech.redactionApplied,
        redactionCount: preparedSpeech.redactionCount,
        inference: {
          service: inferenceMeta.service,
          route: inferenceMeta.route,
          authMode: inferenceMeta.authMode,
          statusCode: inferenceMeta.statusCode ?? null,
          errorCode: inferenceMeta.errorCode ?? null,
          reason: inferenceMeta.reason ?? null,
          endpoint: inferenceMeta.endpoint ?? null,
        },
        understanding: {
          intent: understanding.intent,
          complexity: understanding.complexity,
          needsScaffold: understanding.needsScaffold,
          emotionalState: understanding.emotionalState,
          confidence: understanding.confidence,
          responseMode: understanding.responseMode,
          topicTags: understanding.topicTags,
        },
      },
      tts: {
        available: Boolean(audioUrl),
        audioUrl,
        voiceProfile: shouldSpeak ? voiceProfile : undefined,
      },
    });
  } catch (error) {
    responseError(res, error);
  }
}

export async function handleVoiceTranscribe(req: Request, res: Response): Promise<void> {
  const startedAt = Date.now();
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'method_not_allowed', message: 'Use POST.' });
    return;
  }

  try {
    const contentType = req.header('content-type') || '';
    const body = contentType.includes('multipart/form-data') ? {} : parseJsonBody(req);

    let transcriptRaw: string | undefined;
    let localeHint: unknown = body.locale;
    let partialHint: unknown = body.partial;
    let uploadedAudioLength = 0;
    let uploadedAudioBase64: string | undefined;
    let resolvedBody: Record<string, unknown> = body;

    if (contentType.includes('multipart/form-data')) {
      const { fields, files } = parseMultipartForm(req);
      transcriptRaw = normalizeString(fields.transcript);
      localeHint = fields.locale;
      partialHint = fields.partial;
      const contextFromField = parseJsonObjectField(fields.context);
      const contextFromHints: Record<string, unknown> = {
        ...(contextFromField ?? {}),
      };
      const voiceTraceId = normalizeString(fields.voiceTraceId);
      const voiceInputTraceId = normalizeString(fields.voiceInputTraceId);
      if (voiceTraceId) contextFromHints.voiceTraceId = voiceTraceId;
      if (voiceInputTraceId) contextFromHints.voiceInputTraceId = voiceInputTraceId;
      const hasContextHints = Object.keys(contextFromHints).length > 0;
      resolvedBody = {
        ...body,
        ...(normalizeString(fields.siteId) ? { siteId: normalizeString(fields.siteId) } : {}),
        ...(normalizeString(fields.traceId) ? { traceId: normalizeString(fields.traceId) } : {}),
        ...(hasContextHints ? { context: contextFromHints } : {}),
      };
      if (files.audio) {
        uploadedAudioLength = files.audio.data.length;
        uploadedAudioBase64 = files.audio.data.toString('base64');
      }
    } else {
      transcriptRaw = normalizeString(body.transcript);
      const audioBase64 = normalizeString(body.audioBase64);
      if (audioBase64) {
        uploadedAudioBase64 = audioBase64;
        try {
          uploadedAudioLength = Buffer.from(audioBase64, 'base64').length;
        } catch {
          uploadedAudioLength = 0;
        }
      }
    }

    const authContext = await resolveAuthContext(req, resolvedBody);
    const settings = await loadVoiceSettings(authContext.siteId);
    await enforceVoiceAccess(authContext, settings);

    if (!transcriptRaw && uploadedAudioLength === 0) {
      throw new VoiceHttpError(400, 'invalid_argument', 'audio or transcript input is required.');
    }

    const locale = resolveLocale(localeHint, req, settings.allowedLocales);
    const requestId = resolveRequestId(req);
    const traceId = resolveTraceId(req, resolvedBody);
    const partial = normalizeBoolean(partialHint, false);
    let transcriptCandidate = transcriptRaw;
    let confidence = transcriptRaw ? 0.96 : undefined;
    let sttModelVersion = STT_MODEL_VERSION;
    let sttModelUnderstanding: PartialVoiceUnderstandingSignal | undefined;
    let inferenceMeta: VoiceInferenceMeta = buildLocalInferenceMeta(
      'stt',
      transcriptRaw ? 'transcript_supplied' : 'not_attempted',
    );
    if (!transcriptCandidate && uploadedAudioBase64) {
      const sttResult = await callInternalInferenceJson<Record<string, unknown>, Record<string, unknown>>({
        service: 'stt',
        body: {
          audioBase64: uploadedAudioBase64,
          locale,
          partial,
          role: authContext.role,
          gradeBand: authContext.gradeBand,
        },
        context: buildInferenceContextHeaders({
          traceId,
          requestId,
          authContext,
          locale,
          callerService: 'scholesa-stt',
        }),
      });
      if (isInternalInferenceRequired() && !sttResult.ok) {
        throw new VoiceHttpError(503, 'inference_unavailable', 'Internal STT inference is required but unavailable.');
      }
      const sttPayload = sttResult.ok ? extractInternalSttPayload(sttResult.data) : undefined;
      if (sttPayload?.modelVersion) {
        sttModelVersion = sttPayload.modelVersion;
      }
      if (sttPayload?.understanding) {
        sttModelUnderstanding = sttPayload.understanding;
      }
      if (sttResult.ok && sttPayload?.transcript) {
        transcriptCandidate = sttPayload.transcript;
        inferenceMeta = buildInferenceMeta('stt', sttResult);
        confidence = sttPayload.confidence ?? confidence;
      } else if (sttResult.ok) {
        if (isInternalInferenceRequired()) {
          throw new VoiceHttpError(503, 'inference_unavailable', 'Internal STT returned an empty transcript.');
        }
        inferenceMeta = buildInferenceMeta('stt', sttResult, 'empty_transcript');
      } else {
        inferenceMeta = buildInferenceMeta('stt', sttResult, 'internal_call_failed');
      }
    }
    const transcript = cleanTranscript(transcriptCandidate ?? defaultTranscriptByLocale(locale));
    if (confidence === undefined) {
      confidence = Math.max(0.72, Math.min(0.93, 0.72 + transcript.length / 500));
    }
    const transcribeSafety = evaluateSafetyDecision(transcript, authContext.role, locale);
    const heuristicUnderstanding = deriveUnderstandingSignal({
      message: transcript,
      role: authContext.role,
      safety: transcribeSafety,
    });
    const understanding = mergeUnderstandingSignal(heuristicUnderstanding, sttModelUnderstanding);
    const latencyMs = Date.now() - startedAt;
    await Promise.all([
      recordVoiceAuditEvent({
        eventType: 'voice.transcribe',
        endpoint: 'voice_transcribe',
        requestId,
        traceId,
        authContext,
        locale,
        safetyOutcome: transcribeSafety.safetyOutcome,
        latencyMs,
      }),
      recordVoiceTelemetryEvent({
        event: 'voice.transcribe',
        endpoint: 'voice_transcribe',
        requestId,
        traceId,
        authContext,
        locale,
        latencyMs,
        transcriptProvided: Boolean(transcriptRaw),
        transcriptLength: transcript.length,
        partial,
        audioBytes: uploadedAudioLength,
        safetyOutcome: transcribeSafety.safetyOutcome,
        understanding,
        modelVersionOverride: sttModelVersion,
        inference: inferenceMeta,
      }),
    ]);
    await Promise.allSettled([
      upsertBosLearningProfile({
        endpoint: 'voice_transcribe',
        traceId,
        authContext,
        body: resolvedBody,
        locale,
        safetyOutcome: transcribeSafety.safetyOutcome,
        understanding,
        transcriptLength: transcript.length,
      }),
      recordVoiceTelemetryEvent({
        event: 'ai_help_opened',
        endpoint: 'voice_transcribe',
        requestId,
        traceId,
        authContext,
        locale,
        latencyMs,
        transcriptProvided: Boolean(transcriptRaw),
        transcriptLength: transcript.length,
        partial,
        audioBytes: uploadedAudioLength,
        safetyOutcome: transcribeSafety.safetyOutcome,
        understanding,
        modelVersionOverride: sttModelVersion,
        inference: inferenceMeta,
      }),
      recordBosInteractionEvent({
        eventType: 'ai_help_opened',
        endpoint: 'voice_transcribe',
        requestId,
        traceId,
        authContext,
        body: resolvedBody,
        locale,
        safetyOutcome: transcribeSafety.safetyOutcome,
        latencyMs,
        transcriptLength: transcript.length,
        audioBytes: uploadedAudioLength,
        understanding,
        inference: inferenceMeta,
      }),
    ]);

    res.status(200).json({
      transcript,
      confidence,
      metadata: {
        requestId,
        traceId,
        locale,
        latencyMs,
        partial,
        modelVersion: sttModelVersion,
        inference: {
          service: inferenceMeta.service,
          route: inferenceMeta.route,
          authMode: inferenceMeta.authMode,
          statusCode: inferenceMeta.statusCode ?? null,
          errorCode: inferenceMeta.errorCode ?? null,
          reason: inferenceMeta.reason ?? null,
          endpoint: inferenceMeta.endpoint ?? null,
        },
        understanding: {
          intent: understanding.intent,
          complexity: understanding.complexity,
          needsScaffold: understanding.needsScaffold,
          emotionalState: understanding.emotionalState,
          confidence: understanding.confidence,
          responseMode: understanding.responseMode,
          topicTags: understanding.topicTags,
        },
      },
    });
  } catch (error) {
    responseError(res, error);
  }
}

export async function handleTtsSpeak(req: Request, res: Response): Promise<void> {
  const startedAt = Date.now();
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'method_not_allowed', message: 'Use POST.' });
    return;
  }

  try {
    const body = parseJsonBody(req);
    const authContext = await resolveAuthContext(req, body);
    const settings = await loadVoiceSettings(authContext.siteId);
    await enforceVoiceAccess(authContext, settings);
    const locale = resolveLocale(body.locale, req, settings.allowedLocales);

    const rawText = normalizeSpeechText(normalizeString(body.text) ?? '');
    if (!rawText) {
      throw new VoiceHttpError(400, 'invalid_argument', 'text is required.');
    }
    const ttsSafety = evaluateSafetyDecision(rawText, authContext.role, locale);
    const understanding = deriveUnderstandingSignal({
      message: rawText,
      role: authContext.role,
      safety: ttsSafety,
    });
    const ttsInputText =
      ttsSafety.safetyOutcome === 'blocked' || ttsSafety.safetyOutcome === 'escalated'
        ? ttsSafety.localizedMessage
        : rawText;
    const requestedGradeBand = normalizeGradeBand(body.gradeBand, body.grade);
    const effectiveGradeBand = authContext.role === 'student' ? authContext.gradeBand : requestedGradeBand;
    const knownNames = extractKnownNames(body);
    const speech = redactTextForSpeech(ttsInputText, knownNames);
    const voiceProfile = chooseVoiceProfile(locale, authContext.role, effectiveGradeBand);
    const requestId = resolveRequestId(req);
    const traceId = resolveTraceId(req, body);
    const expMs = Date.now() + AUDIO_TOKEN_TTL_MS;
    const checksum = createHash('sha256')
      .update(`${traceId}|${locale}|${voiceProfile}|${speech.speechText}|${expMs}`)
      .digest('hex');
    const token = createAudioToken({
      traceId,
      locale,
      voiceProfile,
      text: speech.speechText,
      expMs,
      checksum,
    });
    const fallbackAudioUrl = buildAudioUrl(req, token);
    let audioUrl = fallbackAudioUrl;
    let effectiveVoiceProfile = voiceProfile;
    let ttsModelVersion = TTS_MODEL_VERSION;
    let inferenceMeta: VoiceInferenceMeta = buildLocalInferenceMeta('tts', 'not_attempted');
    const ttsResult = await callInternalInferenceJson<Record<string, unknown>, Record<string, unknown>>({
      service: 'tts',
      body: {
        text: speech.speechText,
        locale,
        role: authContext.role,
        gradeBand: effectiveGradeBand,
        voiceProfile,
        prosodyPolicy: prosodyPolicyTag(authContext.role, effectiveGradeBand),
      },
      context: buildInferenceContextHeaders({
        traceId,
        requestId,
        authContext,
        locale,
        callerService: 'scholesa-tts',
      }),
    });
    if (isInternalInferenceRequired() && !ttsResult.ok) {
      throw new VoiceHttpError(503, 'inference_unavailable', 'Internal TTS inference is required but unavailable.');
    }
    const ttsPayload = ttsResult.ok ? extractInternalTtsPayload(ttsResult.data) : undefined;
    if (ttsPayload?.modelVersion) {
      ttsModelVersion = ttsPayload.modelVersion;
    }
    if (ttsResult.ok && ttsPayload?.audioUrl) {
      if (isInternalAudioUrl(ttsPayload.audioUrl)) {
        audioUrl = ttsPayload.audioUrl;
        if (ttsPayload.voiceProfile) {
          effectiveVoiceProfile = ttsPayload.voiceProfile;
        }
        inferenceMeta = buildInferenceMeta('tts', ttsResult);
      } else {
        if (isInternalInferenceRequired()) {
          throw new VoiceHttpError(503, 'inference_unavailable', 'Internal TTS returned a non-internal audio URL.');
        }
        inferenceMeta = buildInferenceMeta('tts', ttsResult, 'non_internal_audio_url_rejected');
      }
    } else if (ttsResult.ok) {
      if (isInternalInferenceRequired()) {
        throw new VoiceHttpError(503, 'inference_unavailable', 'Internal TTS response did not include audioUrl.');
      }
      inferenceMeta = buildInferenceMeta('tts', ttsResult, 'missing_audio_url');
    } else {
      inferenceMeta = buildInferenceMeta('tts', ttsResult, 'internal_call_failed');
    }
    const latencyMs = Date.now() - startedAt;
    await Promise.all([
      recordVoiceAuditEvent({
        eventType: 'voice.tts',
        endpoint: 'tts_speak',
        requestId,
        traceId,
        authContext,
        locale,
        safetyOutcome: ttsSafety.safetyOutcome,
        redactionApplied: speech.redactionApplied,
        redactionCount: speech.redactionCount,
        latencyMs,
      }),
      recordVoiceTelemetryEvent({
        event: 'voice.tts',
        endpoint: 'tts_speak',
        requestId,
        traceId,
        authContext,
        locale,
        latencyMs,
        safetyOutcome: ttsSafety.safetyOutcome,
        redactionApplied: speech.redactionApplied,
        redactionCount: speech.redactionCount,
        textLength: speech.speechText.length,
        understanding,
        modelVersionOverride: ttsModelVersion,
        inference: inferenceMeta,
      }),
    ]);
    await Promise.allSettled([
      upsertBosLearningProfile({
        endpoint: 'tts_speak',
        traceId,
        authContext,
        body,
        locale,
        safetyOutcome: ttsSafety.safetyOutcome,
        understanding,
        textLength: speech.speechText.length,
      }),
      recordVoiceTelemetryEvent({
        event: 'ai_coach_response',
        endpoint: 'tts_speak',
        requestId,
        traceId,
        authContext,
        locale,
        latencyMs,
        safetyOutcome: ttsSafety.safetyOutcome,
        redactionApplied: speech.redactionApplied,
        redactionCount: speech.redactionCount,
        textLength: speech.speechText.length,
        understanding,
        modelVersionOverride: ttsModelVersion,
        inference: inferenceMeta,
      }),
      recordBosInteractionEvent({
        eventType: 'ai_coach_response',
        endpoint: 'tts_speak',
        requestId,
        traceId,
        authContext,
        body,
        locale,
        safetyOutcome: ttsSafety.safetyOutcome,
        latencyMs,
        textLength: speech.speechText.length,
        ttsAvailable: true,
        understanding,
        inference: inferenceMeta,
      }),
    ]);

    res.status(200).json({
      audioUrl,
      metadata: {
        requestId,
        traceId,
        modelVersion: ttsModelVersion,
        latencyMs,
        locale,
        voiceProfile: effectiveVoiceProfile,
        prosodyPolicy: prosodyPolicyTag(authContext.role, effectiveGradeBand),
        safetyOutcome: ttsSafety.safetyOutcome,
        redactionApplied: speech.redactionApplied,
        redactionCount: speech.redactionCount,
        inference: {
          service: inferenceMeta.service,
          route: inferenceMeta.route,
          authMode: inferenceMeta.authMode,
          statusCode: inferenceMeta.statusCode ?? null,
          errorCode: inferenceMeta.errorCode ?? null,
          reason: inferenceMeta.reason ?? null,
          endpoint: inferenceMeta.endpoint ?? null,
        },
        understanding: {
          intent: understanding.intent,
          complexity: understanding.complexity,
          needsScaffold: understanding.needsScaffold,
          emotionalState: understanding.emotionalState,
          confidence: understanding.confidence,
          responseMode: understanding.responseMode,
          topicTags: understanding.topicTags,
        },
      },
    });
  } catch (error) {
    responseError(res, error);
  }
}

export async function handleVoiceAudio(req: Request, res: Response): Promise<void> {
  if (req.method !== 'GET') {
    res.status(405).json({ error: 'method_not_allowed', message: 'Use GET.' });
    return;
  }
  try {
    const normalizedPath = normalizePath(req.path || '/');
    const tokenFromPath = normalizedPath.startsWith('/voice/audio/')
      ? decodeURIComponent(normalizedPath.slice('/voice/audio/'.length))
      : undefined;
    const tokenFromQuery = normalizeString(req.query.token);
    const token = tokenFromPath ?? tokenFromQuery;
    if (!token) {
      throw new VoiceHttpError(400, 'invalid_argument', 'token is required.');
    }
    const payload = verifyAudioToken(token);
    const wav = synthesizeAudioWave(payload.text, payload.locale);
    res.setHeader('Content-Type', 'audio/wav');
    res.setHeader('Cache-Control', 'private, max-age=60');
    res.status(200).send(wav);
  } catch (error) {
    responseError(res, error);
  }
}

export async function handleVoiceApi(req: Request, res: Response): Promise<void> {
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }
  const path = normalizePath(req.path || '/');
  if (path === '/copilot/message') {
    await handleCopilotMessage(req, res);
    return;
  }
  if (path === '/voice/transcribe') {
    await handleVoiceTranscribe(req, res);
    return;
  }
  if (path === '/tts/speak') {
    await handleTtsSpeak(req, res);
    return;
  }
  if (path.startsWith('/voice/audio/')) {
    await handleVoiceAudio(req, res);
    return;
  }
  res.status(404).json({
    error: 'not_found',
    message: 'Unknown voice endpoint.',
    path,
    supported: ['/copilot/message', '/voice/transcribe', '/tts/speak', '/voice/audio/:token'],
  });
}

export const __voiceSystemInternals = {
  buildAdaptiveLocalizedResponse,
  cleanTranscript,
  createAudioToken,
  deriveUnderstandingSignal,
  detectLanguageCompatibility,
  evaluateSafetyDecision,
  normalizeVoiceLocale,
  redactTextForSpeech,
  resolveLocale,
  selectToolCalls,
  synthesizeAudioWave,
  verifyAudioToken,
};
