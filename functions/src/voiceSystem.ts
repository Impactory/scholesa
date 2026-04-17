import { createHash, createHmac, randomUUID } from 'crypto';
import type { Request, Response } from 'express';
import * as admin from 'firebase-admin';
import { HttpsError } from 'firebase-functions/v2/https';
import {
  callInternalInferenceJson,
  callInternalInferenceStream,
  isInternalInferenceRequired,
  type InternalInferenceAuthMode,
  type InternalInferenceCallResult,
} from './internalInferenceGateway';
import { isCoppaConsentActive } from './coppaGuards';

export const SUPPORTED_VOICE_LOCALES = ['en', 'es', 'zh-CN', 'zh-TW', 'th'] as const;
export type VoiceLocale = (typeof SUPPORTED_VOICE_LOCALES)[number];
type VoiceRole = 'student' | 'teacher' | 'admin';
export type VoiceRequesterRole = VoiceRole | 'parent';
type SafetyOutcome = 'allowed' | 'blocked' | 'modified' | 'escalated';
type GradeBand = 'K-5' | '6-8' | '9-12' | 'All';
type VoiceIntent =
  | 'hint_request'
  | 'explain_request'
  | 'translation_request'
  | 'planning_request'
  | 'reflection'
  | 'safety_support'
  | 'general_support'
  | 'checkpoint_help'
  | 'portfolio_review'
  | 'capability_inquiry'
  | 'peer_feedback'
  | 'revision_inquiry';
type VoiceComplexity = 'low' | 'medium' | 'high';
type VoiceEmotionalState = 'frustrated' | 'confused' | 'bored' | 'neutral' | 'curious' | 'confident' | 'excited';
type VoiceResponseMode = 'hint' | 'explain' | 'translate' | 'plan' | 'safety';
type UnderstandingSource = 'heuristic' | 'model' | 'blended';
type ResponseGenerationSource = 'local' | 'model' | 'guardrail';

const VOICE_POLICY_VERSION = 'voice-policy-2026-02-23';
const _VOICE_MODEL_VERSION = 'voice-orchestrator-v2';
const _STT_MODEL_VERSION = 'scholesa-stt-v2';
const _TTS_MODEL_VERSION = 'scholesa-tts-v2';
const MIN_AUTONOMOUS_STUDENT_CONFIDENCE = 0.97;
const MIN_AUTONOMOUS_POLICY_CONFIDENCE = 0.97;
const AUDIO_TOKEN_TTL_MS = 5 * 60 * 1000;
const TELEMETRY_COLLECTION = 'telemetryEvents';
const BOS_INTERACTION_COLLECTION = 'interactionEvents';
const TELEMETRY_UNSCOPED_SITE_ID = 'unscoped';
const SCHOOL_CONSENT_COLLECTION = 'coppaSchoolConsents';

const LOW_CONFIDENCE_STUDENT_SUPPORT: Record<VoiceLocale, string> = {
  en: 'I want to be careful here. Tell me what you have already tried, and I can help with the next safe step. If you need a full check, ask your educator to review it with you.',
  es: 'Quiero ser cuidadoso aquí. Dime qué has intentado ya y puedo ayudarte con el siguiente paso seguro. Si necesitas una revisión completa, pide a tu profesor que lo revise contigo.',
  'zh-CN': '我想更谨慎一点。先告诉我你已经试过什么，我可以帮你想下一步更安全的做法。如果你需要完整检查，请老师和你一起看。',
  'zh-TW': '我想更謹慎一點。先告訴我你已經試過什麼，我可以幫你想下一步更安全的做法。如果你需要完整檢查，請老師和你一起看。',
  th: 'ฉันอยากระวังให้มากขึ้น ลองบอกก่อนว่าคุณได้ลองอะไรไปแล้วบ้าง แล้วฉันจะช่วยคิดขั้นต่อไปที่ปลอดภัยให้ ถ้าต้องการตรวจแบบครบถ้วน ให้ครูช่วยดูไปด้วยกัน',
};

const UNAVAILABLE_STUDENT_SUPPORT: Record<VoiceLocale, string> = {
  en: 'MiloOS is not ready to give a reliable answer right now. Share your work so far, or ask your educator to review the next step with you.',
  es: 'MiloOS no está listo para dar una respuesta confiable ahora. Comparte tu trabajo hasta ahora, o pide a tu profesor que revise el siguiente paso contigo.',
  'zh-CN': 'MiloOS 现在还不能提供足够可靠的回答。你可以先分享你目前的思路，或者请老师陪你一起看下一步。',
  'zh-TW': 'MiloOS 現在還不能提供足夠可靠的回答。你可以先分享你目前的思路，或者請老師陪你一起看下一步。',
  th: 'MiloOS ยังไม่พร้อมให้คำตอบที่เชื่อถือได้ในตอนนี้ ลองเล่าสิ่งที่ทำมาถึงตอนนี้ หรือให้ครูช่วยดูขั้นต่อไปกับคุณ',
};

const HEURISTIC_ONLY_STUDENT_SUPPORT: Record<VoiceLocale, string> = {
  en: 'I may not have understood your voice request well enough yet. Tell me the exact step you are stuck on, and I will help with one small next move.',
  es: 'Puede que aún no haya entendido bien tu solicitud de voz. Dime exactamente en qué paso estás atascado y te ayudaré con un pequeño avance.',
  'zh-CN': '我现在可能还没有足够准确地理解你的语音请求。请告诉我你具体卡在哪一步，我会先帮你想一个小的下一步。',
  'zh-TW': '我現在可能還沒有足夠準確地理解你的語音請求。請告訴我你具體卡在哪一步，我會先幫你想一個小的下一步。',
  th: 'ตอนนี้ฉันอาจยังเข้าใจคำขอเสียงของคุณได้ไม่ชัดพอ ลองบอกว่าคุณติดอยู่ตรงขั้นไหน แล้วฉันจะช่วยคิดก้าวเล็ก ๆ ถัดไปให้',
};

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
  requesterRole: VoiceRequesterRole;
  siteId: string;
  siteIds: string[];
  gradeBand: GradeBand;
}

export interface SafetyDecision {
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
  service: 'llm' | 'stt' | 'tts' | 'bos';
  route: 'internal' | 'local';
  authMode: InternalInferenceAuthMode;
  statusCode?: number;
  errorCode?: string;
  reason?: string;
  endpoint?: string;
}

interface BosPolicyHint {
  mode?: 'hint' | 'verify' | 'explain' | 'debug';
  type?: 'nudge' | 'scaffold' | 'handoff' | 'revisit' | 'pace';
  salience?: 'low' | 'medium' | 'high';
  triggerMvl: boolean;
  confidence?: number;
  reasonCodes: string[];
}

interface VoiceRecentTurn {
  intent: string;
  responseMode: string;
  emotionalState: string;
  timestamp: number;
}

interface VoiceLearningSnapshot {
  profileId: string;
  actorId: string;
  actorRole: 'learner' | 'educator' | 'admin';
  lastIntent: string | null;
  lastResponseMode: string | null;
  lastNeedsScaffold: boolean;
  lastEmotionalState: string | null;
  lastUnderstandingConfidence?: number;
  needsScaffoldCount: number;
  frustrationSignalCount: number;
  recentTurns?: VoiceRecentTurn[];
}

interface RoleIntelligenceLearnerProfile {
  learnerId: string;
  linkedEducatorCount: number;
  linkedParentCount: number;
  assignedMissionCount: number;
  recentInteractionCount: number;
  lastIntent?: string;
  lastResponseMode?: string;
  lastNeedsScaffold?: boolean;
  lastEmotionalState?: string;
  lastUnderstandingConfidence?: number;
}

interface RoleSiteIntelligenceProfile {
  learnerCount: number;
  educatorCount: number;
  parentCount: number;
  openMvlCount: number;
  activeMissionCount: number;
}

interface RoleIntelligenceContext {
  version: 'role-intel-v2';
  role: VoiceRole;
  requesterRole: VoiceRequesterRole;
  siteId: string;
  actorId: string;
  selectedLearnerId?: string;
  signalCount: number;
  siteProfile?: RoleSiteIntelligenceProfile;
  selectedLearnerProfile?: RoleIntelligenceLearnerProfile;
  learnerProfile?: {
    linkedEducatorCount: number;
    linkedParentCount: number;
    assignedMissionCount: number;
    recentInteractionCount: number;
  };
  educatorProfile?: {
    rosterCount: number;
    selectedLearnerLinkedParentCount: number;
    selectedLearnerMissionCount: number;
    selectedLearnerRecentInteractionCount: number;
  };
  parentProfile?: {
    linkedLearnerCount: number;
    selectedLearnerLinkedEducatorCount: number;
    selectedLearnerMissionCount: number;
    selectedLearnerRecentInteractionCount: number;
  };
  adminProfile?: {
    learnerCount: number;
    educatorCount: number;
    parentCount: number;
    openMvlCount: number;
    activeMissionCount: number;
  };
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
  es: 'es',
  'es-es': 'es',
  'es-mx': 'es',
  'es-419': 'es',
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
  /ignor(a|ar) (todas? las? )?instrucciones/i,
  /modo desarrollador/i,
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
  /otra? (escuela|sitio|distrito)/i,
  /datos de otro estudiante/i,
  /toda la base de datos/i,
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
  /herramienta de admin/i,
  /exportar datos/i,
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
  /hacerme da[ñn]o/i,
  /hacerle da[ñn]o a alguien/i,
  /\bsuicid(io|arme)\b/i,
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
  /construir (un )?arma/i,
  /c[óo]mo hacer da[ñn]o/i,
  /hacer una bomba/i,
  /制作武器/,
  /製作武器/,
  /อาวุธ/,
];

const FOCUS_NUDGE_PATTERNS = [
  /\bI('| )?m bored\b/i,
  /\bthis is dumb\b/i,
  /don'?t want to do this/i,
  /estoy aburrido/i,
  /esto es tonto/i,
  /no quiero hacer esto/i,
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
  /diferenciaci[óo]n/i,
  /habilidades mixtas/i,
  /mensaje (a|para) (un )?padre/i,
  /分层|差异化|差異化/,
  /ผู้ปกครอง/,
];

const HINT_REQUEST_PATTERNS = [
  /\bhint\b/i,
  /\bnext step\b/i,
  /give me a clue/i,
  /\bpista\b/i,
  /siguiente paso/i,
  /dame una pista/i,
  /提示|線索/,
  /ช่วยใบ้/,
];

const EXPLAIN_REQUEST_PATTERNS = [
  /\bexplain\b/i,
  /\bwhy\b/i,
  /break this down/i,
  /\bexplica\b/i,
  /\bpor qu[ée]\b/i,
  /desgl[óo]same esto/i,
  /講解|解释|解釋|原因/,
  /อธิบาย/,
];

const TRANSLATION_PATTERNS = [
  /\btranslate\b/i,
  /\bin (english|chinese|thai|spanish)\b/i,
  /\btraduc(e|ir)\b/i,
  /en (ingl[ée]s|chino|tailand[ée]s|espa[ñn]ol)/i,
  /翻译|翻譯|轉成/,
  /แปล/,
];

const PLANNING_PATTERNS = [
  /\bplan\b/i,
  /\bchecklist\b/i,
  /\bnext\b.*\bdo\b/i,
  /\bplan(ear|ificar)\b/i,
  /lista de pasos/i,
  /qu[ée] hago (ahora|despu[ée]s)/i,
  /步骤|步驟|清单|清單/,
  /แผน|ขั้นตอน/,
];

const REFLECTION_PATTERNS = [
  /\bi learned\b/i,
  /\bi understood\b/i,
  /\bsummary\b/i,
  /\baprend[íi]\b/i,
  /\bentend[íi]\b/i,
  /\bresumen\b/i,
  /我学会|我學會|总结|總結/,
  /ฉันเรียนรู้|สรุป/,
];

const FRUSTRATION_PATTERNS = [
  /\bstuck\b/i,
  /\bconfused\b/i,
  /\bfrustrat(ed|ing)\b/i,
  /\bcan'?t\b/i,
  /\batascad[oa]\b/i,
  /\bconfundid[oa]\b/i,
  /\bfrustrad[oa]\b/i,
  /no puedo/i,
  /卡住|不会|不會|好难|好難/,
  /งง|ยากมาก|ทำไม่ได้/,
];

const CONFIDENCE_PATTERNS = [
  /\bI can\b/i,
  /\bgot it\b/i,
  /\bunderstand now\b/i,
  /\bya puedo\b/i,
  /\bya entend[íi]\b/i,
  /\blo tengo\b/i,
  /我会了|我會了|我懂了/,
  /เข้าใจแล้ว|ทำได้/,
];

const HIGH_COMPLEXITY_PATTERNS = [
  /\bproof\b/i,
  /\bderive\b/i,
  /\banaly(s|z)e\b/i,
  /\bcompare\b/i,
  /\bdemostra(r|ci[óo]n)\b/i,
  /\bderiva(r)?\b/i,
  /\banali(z|s)ar\b/i,
  /\bcomparar\b/i,
  /证明|證明|推导|推導|分析|比較/,
  /พิสูจน์|วิเคราะห์/,
];

const LOW_COMPLEXITY_PATTERNS = [
  /\bread\b/i,
  /\bspell\b/i,
  /\bcount\b/i,
  /\bwhat is\b/i,
  /\bleer\b/i,
  /\bdeletrear\b/i,
  /\bcontar\b/i,
  /\bqu[ée] es\b/i,
  /朗读|朗讀|拼写|拼寫|数数|數數/,
  /อ่าน|สะกด|นับ/,
];

const TOPIC_TAG_PATTERNS: Array<{ tag: string; patterns: RegExp[] }> = [
  { tag: 'math', patterns: [/\bmath\b/i, /\balgebra\b/i, /\bgeometry\b/i, /\bmatem[áa]ticas?\b/i, /\b[áa]lgebra\b/i, /\bgeometr[íi]a\b/i, /数学|數學|คณิต/] },
  { tag: 'science', patterns: [/\bscience\b/i, /\bphysics\b/i, /\bchemistry\b/i, /\bciencias?\b/i, /\bf[íi]sica\b/i, /\bqu[íi]mica\b/i, /科学|科學|วิทยา/] },
  { tag: 'language', patterns: [/\breading\b/i, /\bwriting\b/i, /\bgrammar\b/i, /\blectura\b/i, /\bescritura\b/i, /\bgram[áa]tica\b/i, /阅读|閱讀|写作|寫作|ภาษา/] },
  { tag: 'coding', patterns: [/\bcod(e|ing)\b/i, /\bpython\b/i, /\bjavascript\b/i, /\bprogramaci[óo]n\b/i, /编程|程式|เขียนโค้ด/] },
  { tag: 'history', patterns: [/\bhistory\b/i, /\bcivilization\b/i, /\bhistoria\b/i, /\bcivilizaci[óo]n\b/i, /历史|歷史|ประวัติ/] },
];

const CHECKPOINT_HELP_PATTERNS = [
  /\bcheckpoint\b/i,
  /help (me )?(with|on|at) (the |this )?checkpoint/i,
  /\bpunto de control\b/i,
  /ayuda (con|en) (el )?checkpoint/i,
  /检查点|檢查點/,
  /จุดตรวจ/,
];

const PORTFOLIO_REVIEW_PATTERNS = [
  /\bportfolio\b/i,
  /show my (portfolio|work)/i,
  /\bportafolio\b/i,
  /muestra mi (portafolio|trabajo)/i,
  /作品集|作品夹/,
  /พอร์ตโฟลิโอ|ผลงาน/,
];

const CAPABILITY_INQUIRY_PATTERNS = [
  /what (capability|skill) am I/i,
  /which (capability|strand)/i,
  /what am I (working on|learning|building)/i,
  /qu[ée] (habilidad|competencia) estoy/i,
  /qu[ée] estoy (aprendiendo|trabajando)/i,
  /我在学什么|我在學什麼|正在学的|正在學的/,
  /ฉันกำลังเรียนรู้อะไร|ทักษะอะไร/,
];

const PEER_FEEDBACK_PATTERNS = [
  /peer (feedback|review)/i,
  /give feedback to/i,
  /review (a |my )?classmate/i,
  /retroalimentaci[óo]n (de|entre) pares/i,
  /revisar (al|el trabajo del) compa[ñn]ero/i,
  /同伴反馈|同儕回饋|互评|互評/,
  /เพื่อนให้ความเห็น|รีวิวเพื่อน/,
];

const REVISION_INQUIRY_PATTERNS = [
  /what (do I )?need to (fix|revise|redo)/i,
  /revision(s)? needed/i,
  /what('| i)?s wrong/i,
  /qu[ée] (tengo que|debo) (corregir|revisar)/i,
  /revisiones necesarias/i,
  /需要修改什么|需要修改什麼|要改什么|要改什麼/,
  /ต้องแก้ไขอะไร|แก้ไขตรงไหน/,
];

const CONFUSED_PATTERNS = [
  /\bI don'?t (understand|get it)\b/i,
  /\bwhat do you mean\b/i,
  /\bI('| a)?m lost\b/i,
  /no (entiendo|comprendo)/i,
  /qu[ée] quieres decir/i,
  /不明白|不懂|什么意思|什麼意思/,
  /ไม่เข้าใจ|หมายความว่าอะไร/,
];

const BORED_PATTERNS = [
  /\bso boring\b/i,
  /\bwhen (is|does) (this|it) end\b/i,
  /\bI('| a)?m bored\b/i,
  /\bqu[ée] aburrido\b/i,
  /\bcu[áa]ndo termina\b/i,
  /好无聊|好無聊|什么时候结束|什麼時候結束/,
  /น่าเบื่อมาก|เมื่อไหร่จะจบ/,
];

const CURIOUS_PATTERNS = [
  /\bwhy does\b/i,
  /\bhow come\b/i,
  /\btell me more\b/i,
  /\bI('| a)?m curious\b/i,
  /\bpor qu[ée]\b.*\bfunciona\b/i,
  /cu[ée]ntame m[áa]s/i,
  /为什么会|為什麼會|想多了解/,
  /อยากรู้เพิ่ม|ทำไมถึง/,
];

const EXCITED_PATTERNS = [
  /\bthis is (so |really )?(cool|awesome|amazing)\b/i,
  /\bI love this\b/i,
  /\bso (fun|exciting)\b/i,
  /\bqu[ée] (genial|increíble)\b/i,
  /\bme encanta\b/i,
  /太棒了|好酷|好厉害|好厲害/,
  /เจ๋งมาก|สนุกมาก/,
];

const EMAIL_PATTERN = /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b/g;
const PHONE_PATTERN = /(\+\d{1,3}[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}/g;
const ADDRESS_PATTERN = /\b\d+\s+[A-Za-z0-9.\s]+(?:Street|St|Avenue|Ave|Road|Rd|Boulevard|Blvd|Drive|Dr|Lane|Ln)\b/gi;
const ID_PATTERN = /\b(?:site|learner|submission|attempt|session)[-_]?[A-Za-z0-9]{4,}\b/gi;

const ROLE_ALLOWED_TOOLS: Record<VoiceRequesterRole, readonly string[]> = {
  student: ['glossary', 'hint_ladder', 'read_aloud', 'translate'],
  teacher: ['class_summary', 'rubric_feedback_draft', 'differentiate_lesson', 'read_aloud', 'translate'],
  parent: ['class_summary', 'read_aloud', 'translate'],
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
  es: {
    blocked: 'No puedo ayudar con esa solicitud. Puedo ayudarte con apoyo de aprendizaje seguro y apropiado para la escuela.',
    escalated: 'Me alegra que me lo hayas dicho. Por favor contacta a un adulto de confianza o al consejero escolar ahora. No estás solo.',
    focusNudge: 'Te escucho. Hagamos un paso pequeño: lee la primera línea y dime algo que notes. ¿Quieres una pista o que lo lea en voz alta?',
    studentGeneric: 'Vamos paso a paso. Dime qué parte te parece más difícil y te daré una pista corta.',
    teacherProductive: 'Aquí tienes un borrador rápido: tarea base Nivel 1, apoyos con andamiaje Nivel 2, desafío de extensión Nivel 3, más adaptaciones y preguntas de verificación.',
    teacherGeneric: 'Puedo ayudar con borradores listos para clase, ideas de diferenciación y comunicación de apoyo con padres.',
    adminGeneric: 'Puedo guiar la configuración y la resolución de problemas no sensibles. No expondré secretos, claves ni exportaciones de datos de estudiantes.',
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
  es: {
    hintStep: 'Intenta un paso concreto y luego dime qué cambió.',
    explainStep: 'Puedo explicar con una razón corta y luego una pregunta rápida.',
    translationStep: 'Puedo mantener el mismo significado y cambiar a tu idioma preferido.',
    planningStep: 'Hagamos un plan de tres pasos y completemos el primero.',
    reflectionStep: 'Comparte algo que aprendiste y algo que aún quieres mejorar.',
    frustrationSupport: 'No estás atrasado. Podemos dividir esto en un paso más pequeño.',
    scaffoldPrompt: 'Mantendré cada paso corto para que puedas responder rápido.',
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

/**
 * Extract client-sent orchestration state (EMA xHat estimates) from the
 * request context. Returns null if the context doesn't include valid data.
 */
function resolveClientOrchestrationState(
  context: Record<string, unknown> | undefined,
): { xHat: { cognition: number; engagement: number; integrity: number }; confidence?: number; stateStatus?: string } | null {
  if (!context) return null;
  const orch = context.orchestrationState;
  if (!orch || typeof orch !== 'object') return null;
  const orchObj = orch as Record<string, unknown>;
  const xHat = orchObj.xHat;
  if (!xHat || typeof xHat !== 'object') return null;
  const xHatObj = xHat as Record<string, unknown>;
  const cognition = typeof xHatObj.cognition === 'number' ? xHatObj.cognition : undefined;
  const engagement = typeof xHatObj.engagement === 'number' ? xHatObj.engagement : undefined;
  const integrity = typeof xHatObj.integrity === 'number' ? xHatObj.integrity : undefined;
  if (cognition === undefined || engagement === undefined || integrity === undefined) return null;
  const result: { xHat: { cognition: number; engagement: number; integrity: number }; confidence?: number; stateStatus?: string } = {
    xHat: { cognition, engagement, integrity },
  };
  if (typeof orchObj.confidence === 'number' && isFinite(orchObj.confidence)) {
    result.confidence = orchObj.confidence;
  }
  if (typeof orchObj.stateStatus === 'string') {
    result.stateStatus = orchObj.stateStatus;
  }
  return result;
}

/**
 * Extract client-sent active MVL context from the request context.
 * Returns null if no active MVL gate is reported.
 */
function resolveClientMvlContext(
  context: Record<string, unknown> | undefined,
): { active: boolean; triggerReason?: string; evidenceCount?: number } | null {
  if (!context) return null;
  const mvl = context.activeMvl;
  if (!mvl || typeof mvl !== 'object') return null;
  const mvlObj = mvl as Record<string, unknown>;
  if (mvlObj.active !== true) return null;
  const result: { active: boolean; triggerReason?: string; evidenceCount?: number } = { active: true };
  if (typeof mvlObj.triggerReason === 'string') {
    result.triggerReason = mvlObj.triggerReason;
  }
  if (typeof mvlObj.evidenceCount === 'number') {
    result.evidenceCount = mvlObj.evidenceCount;
  }
  return result;
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

function normalizeRequesterRole(rawRole: unknown): VoiceRequesterRole {
  const role = typeof rawRole === 'string' ? rawRole.trim().toLowerCase() : '';
  if (role === 'learner' || role === 'student') return 'student';
  if (role === 'educator' || role === 'teacher') return 'teacher';
  if (role === 'parent' || role === 'guardian') return 'parent';
  if (role === 'hq' || role === 'site' || role === 'partner' || role === 'admin') return 'admin';
  return 'student';
}

function normalizeRole(rawRole: unknown): VoiceRole {
  const requesterRole = normalizeRequesterRole(rawRole);
  return requesterRole === 'parent' ? 'admin' : requesterRole;
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

async function assertActiveSchoolConsent(siteId: string): Promise<void> {
  const consentDoc = await admin.firestore().collection(SCHOOL_CONSENT_COLLECTION).doc(siteId).get();
  if (!consentDoc.exists) {
    throw new VoiceHttpError(412, 'failed_precondition', 'School consent record is required before voice AI access.');
  }
  const consent = consentDoc.data() as Record<string, unknown>;
  if (!isCoppaConsentActive(consent)) {
    throw new VoiceHttpError(412, 'failed_precondition', 'School consent record is incomplete or inactive.');
  }
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
  const requesterRole = normalizeRequesterRole((decoded as Record<string, unknown>).role ?? profile.role);
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
    requesterRole,
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

function inferCategory(message: string, role: VoiceRequesterRole): SafetyDecision['category'] {
  if (role === 'student' && FOCUS_NUDGE_PATTERNS.some((pattern) => pattern.test(message))) return 'focus_nudge';
  if (role === 'teacher' && TEACHER_PRODUCTIVITY_PATTERNS.some((pattern) => pattern.test(message))) {
    return 'teacher_productivity';
  }
  if (role === 'admin') return 'admin_setup';
  return 'generic';
}

export function evaluateSafetyDecision(message: string, role: VoiceRequesterRole, locale: VoiceLocale): SafetyDecision {
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

function inferVoiceIntent(message: string, role: VoiceRequesterRole, safetyOutcome: SafetyOutcome): VoiceIntent {
  if (safetyOutcome !== 'allowed' && safetyOutcome !== 'modified') return 'safety_support';
  if (TRANSLATION_PATTERNS.some((pattern) => pattern.test(message))) return 'translation_request';
  if (CHECKPOINT_HELP_PATTERNS.some((pattern) => pattern.test(message))) return 'checkpoint_help';
  if (PORTFOLIO_REVIEW_PATTERNS.some((pattern) => pattern.test(message))) return 'portfolio_review';
  if (CAPABILITY_INQUIRY_PATTERNS.some((pattern) => pattern.test(message))) return 'capability_inquiry';
  if (PEER_FEEDBACK_PATTERNS.some((pattern) => pattern.test(message))) return 'peer_feedback';
  if (REVISION_INQUIRY_PATTERNS.some((pattern) => pattern.test(message))) return 'revision_inquiry';
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
  if (CONFUSED_PATTERNS.some((pattern) => pattern.test(message))) return 'confused';
  if (BORED_PATTERNS.some((pattern) => pattern.test(message))) return 'bored';
  if (EXCITED_PATTERNS.some((pattern) => pattern.test(message))) return 'excited';
  if (CURIOUS_PATTERNS.some((pattern) => pattern.test(message))) return 'curious';
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
  if (intent === 'capability_inquiry' || intent === 'portfolio_review') return 'explain';
  if (intent === 'checkpoint_help' || intent === 'revision_inquiry') return 'hint';
  if (intent === 'peer_feedback') return 'explain';
  if (intent === 'safety_support') return 'safety';
  return 'hint';
}

function deriveUnderstandingSignal(input: {
  message: string;
  role: VoiceRequesterRole;
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
  role: VoiceRequesterRole,
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
  if (understanding.emotionalState === 'frustrated' || understanding.emotionalState === 'confused') {
    pieces.push(localized.frustrationSupport);
  }
  pieces.push(nextStep);
  if (understanding.needsScaffold && understanding.responseMode !== 'safety') {
    pieces.push(localized.scaffoldPrompt);
  }
  return pieces.filter(Boolean).join(' ').replace(/\s+/g, ' ').trim();
}

function requiresStrictStudentConfidence(role: VoiceRequesterRole): boolean {
  return role === 'student';
}

function buildStudentConfidenceGuardResponse(locale: VoiceLocale): string {
  return LOW_CONFIDENCE_STUDENT_SUPPORT[locale] ?? LOW_CONFIDENCE_STUDENT_SUPPORT.en;
}

function buildStudentInferenceUnavailableResponse(locale: VoiceLocale): string {
  return UNAVAILABLE_STUDENT_SUPPORT[locale] ?? UNAVAILABLE_STUDENT_SUPPORT.en;
}

function buildHeuristicOnlyStudentResponse(locale: VoiceLocale): string {
  return HEURISTIC_ONLY_STUDENT_SUPPORT[locale] ?? HEURISTIC_ONLY_STUDENT_SUPPORT.en;
}

function generateLocalizedResponse(role: VoiceRequesterRole, locale: VoiceLocale, category: SafetyDecision['category']): string {
  const localized = LOCALE_TEXT[locale];
  if (role === 'student' && category === 'focus_nudge') return localized.focusNudge;
  if (role === 'student') return localized.studentGeneric;
  if (role === 'teacher' && category === 'teacher_productivity') return localized.teacherProductive;
  if (role === 'teacher' || role === 'parent') return localized.teacherGeneric;
  return localized.adminGeneric;
}

function applyStudentConversationalTone(
  text: string,
  locale: VoiceLocale,
): string {
  const normalized = normalizeSpeechText(text);
  if (!normalized) return normalized;
  if (locale !== 'en') return normalized;

  const hasEncouragement = /\b(great|good|nice|awesome|you can do this|you've got this|well done)\b/i.test(normalized);
  const hasQuestion = /\?/.test(normalized);

  let out = hasEncouragement ? normalized : `Nice effort. ${normalized}`;
  if (!hasQuestion) {
    out = `${out} What should we try first?`;
  }
  return out;
}

/** Adapt response text based on BOS policy type/salience recommendation. */
function applyBosPolicyModeStyle(
  text: string,
  policyHint: BosPolicyHint,
  locale: VoiceLocale,
  role: VoiceRequesterRole,
): string {
  if (!text || role !== 'student') return text;
  const interventionType = policyHint.type;
  if (!interventionType) return text;

  // Adapt the response phrasing to match the BOS-recommended intervention type.
  // Only applies to English for now — other locales pass through unchanged.
  if (locale !== 'en') return text;

  const hasQuestion = /\?/.test(text);
  switch (interventionType) {
    case 'scaffold': {
      // Structured scaffolding: break down into steps.
      const prefix = policyHint.salience === 'high'
        ? 'Let me break this down for you.'
        : 'Let us work through this together.';
      return hasQuestion ? `${prefix} ${text}` : `${prefix} ${text} What part would you like to explore first?`;
    }
    case 'nudge': {
      // Minimal support: gentle encouragement only.
      const hasEncouragement = /\b(great|good|nice|keep going|awesome)\b/i.test(text);
      return hasEncouragement ? text : `You are on the right track. ${text}`;
    }
    case 'revisit': {
      // Suggest going back to review a concept.
      return `It might help to revisit what we covered earlier. ${text}`;
    }
    case 'pace': {
      // Slow down pacing signal.
      return hasQuestion ? text : `Take your time with this one. ${text}`;
    }
    case 'handoff': {
      // Escalate to educator.
      return `This is a great question for your educator. ${text}`;
    }
    default:
      return text;
  }
}

function selectToolCalls(
  role: VoiceRequesterRole,
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
  if (understanding?.responseMode === 'plan' && role === 'parent') {
    return ['class_summary'];
  }
  if (role === 'student' && category === 'focus_nudge') return ['hint_ladder', 'read_aloud'];
  if (role === 'teacher' && category === 'teacher_productivity') return ['differentiate_lesson', 'rubric_feedback_draft'];
  if (role === 'parent') return ['class_summary'];
  if (role === 'admin') return ['setup_help'];
  return [allowedTools[0]];
}

function deriveBosModeToolHints(role: VoiceRequesterRole, policyHint: BosPolicyHint): string[] {
  if (!policyHint.mode) return [];
  if (role === 'student') {
    if (policyHint.mode === 'hint') return ['hint_ladder'];
    if (policyHint.mode === 'verify') return ['glossary'];
    if (policyHint.mode === 'explain') return ['read_aloud'];
    if (policyHint.mode === 'debug') return ['hint_ladder'];
    return [];
  }
  if (role === 'teacher') {
    if (policyHint.mode === 'hint') return ['differentiate_lesson'];
    if (policyHint.mode === 'verify') return ['rubric_feedback_draft'];
    if (policyHint.mode === 'explain') return ['class_summary'];
    if (policyHint.mode === 'debug') return ['rubric_feedback_draft'];
    return [];
  }
  if (role === 'parent') {
    if (policyHint.mode === 'hint') return ['read_aloud'];
    if (policyHint.mode === 'verify') return ['class_summary'];
    if (policyHint.mode === 'explain') return ['class_summary'];
    if (policyHint.mode === 'debug') return ['translate'];
    return [];
  }
  return ['setup_help'];
}

function detectLanguageCompatibility(text: string, locale: VoiceLocale): boolean {
  if (!text.trim()) return false;
  if (locale === 'en') return /[A-Za-z]/.test(text);
  if (locale === 'es') return /[A-Za-z\u00C0-\u024F]/.test(text);
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

function toFiniteNumber(value: unknown, fallback: number = 0): number {
  const numeric = typeof value === 'number' ? value : Number(value);
  if (!Number.isFinite(numeric)) return fallback;
  return numeric;
}

async function safeQueryCount(query: FirebaseFirestore.Query): Promise<number | undefined> {
  try {
    const snapshot = await (query as unknown as { count: () => { get: () => Promise<{ data: () => { count?: number } }> } })
      .count()
      .get();
    const data = snapshot.data();
    if (typeof data?.count === 'number') return data.count;
    return undefined;
  } catch {
    return undefined;
  }
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
    ...((Array.isArray(root?.toolSuggestions) ? root?.toolSuggestions : []) as unknown[]),
    ...((Array.isArray(root?.tools) ? root?.tools : []) as unknown[]),
    ...((Array.isArray(response?.toolSuggestions) ? response?.toolSuggestions : []) as unknown[]),
    ...((Array.isArray(response?.tools) ? response?.tools : []) as unknown[]),
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

function extractInternalTtsPayload(data: unknown): {
  audioUrl?: string;
  voiceProfile?: string;
  modelVersion?: string;
  understanding?: PartialVoiceUnderstandingSignal;
} {
  const root = asRecord(data);
  const metadata = asRecord(root?.metadata);
  const result = asRecord(root?.result);
  const audio = asRecord(root?.audio);
  const audioUrl = firstString(root?.audioUrl, result?.audioUrl, audio?.url, metadata?.audioUrl);

  return {
    audioUrl,
    voiceProfile: firstString(root?.voiceProfile, result?.voiceProfile, metadata?.voiceProfile),
    modelVersion: firstString(root?.modelVersion, root?.model, result?.modelVersion, metadata?.modelVersion),
    understanding: parsePartialUnderstanding(
      root?.understanding ??
      result?.understanding ??
      metadata?.understanding,
    ),
  };
}

function extractInternalBosPayload(data: unknown): BosPolicyHint | undefined {
  const root = asRecord(data);
  const intervention = asRecord(root?.intervention) ??
    asRecord(root?.policy) ??
    asRecord(root?.recommendation) ??
    root;
  if (!intervention) return undefined;

  const modeCandidate = normalizeString(intervention.mode)?.toLowerCase();
  const typeCandidate = normalizeString(intervention.type)?.toLowerCase();
  const salienceCandidate = normalizeString(intervention.salience)?.toLowerCase();
  const confidenceRaw = firstNumber(
    intervention.confidence,
    asRecord(intervention.metadata)?.confidence,
  );
  const confidence = confidenceRaw === undefined
    ? undefined
    : clampProbability(confidenceRaw);

  const mode = modeCandidate === 'hint' || modeCandidate === 'verify' || modeCandidate === 'explain' || modeCandidate === 'debug'
    ? modeCandidate
    : undefined;
  const type = typeCandidate === 'nudge' || typeCandidate === 'scaffold' || typeCandidate === 'handoff' || typeCandidate === 'revisit' || typeCandidate === 'pace'
    ? typeCandidate
    : undefined;
  const salience = salienceCandidate === 'low' || salienceCandidate === 'medium' || salienceCandidate === 'high'
    ? salienceCandidate
    : undefined;
  const reasonCodes = dedupeStrings(
    (Array.isArray(intervention.reasonCodes) ? intervention.reasonCodes : [])
      .map((reason) => normalizeString(reason))
      .filter((reason): reason is string => Boolean(reason)),
  ).slice(0, 6);

  return {
    mode,
    type,
    salience,
    triggerMvl: intervention.triggerMvl === true,
    confidence,
    reasonCodes,
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

function chooseVoiceProfile(locale: VoiceLocale, role: VoiceRequesterRole, gradeBand: GradeBand): string {
  if (role === 'student' && gradeBand === 'K-5') return `${locale}.k5_warm_mentor`;
  if (role === 'student' && gradeBand === '6-8') return `${locale}.ms_peer_coach`;
  if (role === 'student' && gradeBand === '9-12') return `${locale}.hs_direct_tutor`;
  if (role === 'teacher') return `${locale}.educator_assistant`;
  if (role === 'parent') return `${locale}.guardian_narrator`;
  if (role === 'admin') return `${locale}.educator_assistant`;
  return `${locale}.student_neutral`;
}

function prosodyPolicyTag(role: VoiceRequesterRole, gradeBand: GradeBand): string {
  if (role === 'student' && gradeBand === 'K-5') return 'k5_safe_mode';
  if (role === 'student') return 'student_standard_mode';
  return 'professional_mode';
}

function buildTtsStyleHints(input: {
  understanding: VoiceUnderstandingSignal;
  learningSnapshot: VoiceLearningSnapshot | null;
  role: VoiceRequesterRole;
}): Record<string, unknown> {
  const hasPersistentSupportSignal = Boolean(input.learningSnapshot) && (
    input.learningSnapshot!.lastNeedsScaffold ||
    input.learningSnapshot!.lastEmotionalState === 'frustrated' ||
    ((input.learningSnapshot!.lastUnderstandingConfidence ?? 1) < 0.6)
  );
  const speechRate = hasPersistentSupportSignal || input.understanding.needsScaffold
    ? 'slow'
    : input.understanding.complexity === 'high'
    ? 'measured'
    : 'normal';
  const emotionalState = input.understanding.emotionalState;
  const tone = emotionalState === 'frustrated' || emotionalState === 'confused'
    ? 'supportive'
    : emotionalState === 'bored'
    ? 'engaging'
    : emotionalState === 'excited' || emotionalState === 'curious'
    ? 'encouraging'
    : input.role === 'teacher' || input.role === 'parent' || input.role === 'admin'
    ? 'professional'
    : 'encouraging';

  return {
    speechRate,
    tone,
    responseMode: input.understanding.responseMode,
    emotionalState: input.understanding.emotionalState,
    needsScaffold: input.understanding.needsScaffold,
    confidence: input.understanding.confidence,
  };
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
  const secret = process.env.VOICE_SIGNING_SECRET || process.env.GOOGLE_CLOUD_PROJECT;
  if (!secret) {
    throw new Error('VOICE_SIGNING_SECRET or GOOGLE_CLOUD_PROJECT must be set for token signing');
  }
  return secret;
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
  const localeBias = locale === 'th' ? 30 : locale === 'zh-CN' ? 45 : locale === 'zh-TW' ? 60 : locale === 'es' ? 15 : 0;
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

function userHasSiteAccess(profile: Record<string, unknown>, siteId: string): boolean {
  const siteIds = dedupeStrings([
    ...normalizeStringArray(profile.siteIds),
    ...(normalizeString(profile.activeSiteId) ? [String(profile.activeSiteId)] : []),
  ]);
  return siteIds.includes(siteId);
}

async function collectParentLinkedLearnerIds(parentId: string, siteId: string): Promise<string[]> {
  const learnerIds = new Set<string>();
  const parentSnap = await admin.firestore().collection('users').doc(parentId).get().catch(() => null);
  const parentData = parentSnap?.exists ? (parentSnap.data() as Record<string, unknown>) : {};
  normalizeStringArray(parentData?.learnerIds).forEach((learnerId) => learnerIds.add(learnerId));

  try {
    const guardianLinks = await admin.firestore()
      .collection('guardianLinks')
      .where('parentId', '==', parentId)
      .where('siteId', '==', siteId)
      .get();
    for (const doc of guardianLinks.docs) {
      const learnerId = normalizeString(doc.data().learnerId);
      if (learnerId) learnerIds.add(learnerId);
    }
  } catch {
    // Keep deterministic fallback behavior for legacy schemas.
  }

  try {
    const learnersByParent = await admin.firestore()
      .collection('users')
      .where('parentIds', 'array-contains', parentId)
      .get();
    for (const doc of learnersByParent.docs) {
      if (!userHasSiteAccess(doc.data() as Record<string, unknown>, siteId)) continue;
      if (normalizeRequesterRole(doc.data().role) === 'student') {
        learnerIds.add(doc.id);
      }
    }
  } catch {
    // Legacy fallback is best effort only.
  }

  return Array.from(learnerIds.values());
}

async function collectEducatorLinkedLearnerIds(educatorId: string, siteId: string): Promise<string[]> {
  const learnerIds = new Set<string>();
  const educatorSnap = await admin.firestore().collection('users').doc(educatorId).get().catch(() => null);
  const educatorData = educatorSnap?.exists ? (educatorSnap.data() as Record<string, unknown>) : {};
  dedupeStrings([
    ...normalizeStringArray(educatorData?.learnerIds),
    ...normalizeStringArray(educatorData?.studentIds),
  ]).forEach((learnerId) => learnerIds.add(learnerId));

  try {
    const links = await admin.firestore()
      .collection('educatorLearnerLinks')
      .where('educatorId', '==', educatorId)
      .where('siteId', '==', siteId)
      .get();
    for (const doc of links.docs) {
      const learnerId = normalizeString(doc.data().learnerId);
      if (learnerId) learnerIds.add(learnerId);
    }
  } catch {
    // Keep deterministic fallback behavior.
  }

  for (const field of ['educatorIds', 'teacherIds']) {
    try {
      const linkedLearners = await admin.firestore()
        .collection('users')
        .where(field, 'array-contains', educatorId)
        .get();
      for (const doc of linkedLearners.docs) {
        if (!userHasSiteAccess(doc.data() as Record<string, unknown>, siteId)) continue;
        if (normalizeRequesterRole(doc.data().role) === 'student') {
          learnerIds.add(doc.id);
        }
      }
    } catch {
      // Continue with the remaining sources.
    }
  }

  return Array.from(learnerIds.values());
}

async function maybeValidateSelectedLearnerScope(
  context: VoiceAuthContext,
  body: Record<string, unknown>,
): Promise<void> {
  const selectedLearnerId = normalizeString((body.context as Record<string, unknown> | undefined)?.selectedLearnerId);
  if (!selectedLearnerId) return;
  const learnerSnap = await admin.firestore().collection('users').doc(selectedLearnerId).get();
  if (!learnerSnap.exists) {
    throw new VoiceHttpError(403, 'permission_denied', 'selectedLearnerId is not accessible in this tenant scope.');
  }
  const learner = learnerSnap.data() as Record<string, unknown>;
  const learnerRole = normalizeRequesterRole(learner.role);
  if (learnerRole !== 'student') {
    throw new VoiceHttpError(403, 'permission_denied', 'selectedLearnerId must refer to a student.');
  }
  if (!userHasSiteAccess(learner, context.siteId)) {
    throw new VoiceHttpError(403, 'permission_denied', 'selectedLearnerId is outside the authenticated tenant scope.');
  }
  if (context.requesterRole === 'student' && selectedLearnerId !== context.uid) {
    throw new VoiceHttpError(403, 'permission_denied', 'Students may only scope voice context to their own learner record.');
  }
  if (context.requesterRole === 'teacher') {
    const learnerIds = await collectEducatorLinkedLearnerIds(context.uid, context.siteId);
    if (!learnerIds.includes(selectedLearnerId)) {
      throw new VoiceHttpError(403, 'permission_denied', 'selectedLearnerId is outside the teacher roster scope.');
    }
  }
  if (context.requesterRole === 'parent') {
    const learnerIds = await collectParentLinkedLearnerIds(context.uid, context.siteId);
    if (!learnerIds.includes(selectedLearnerId)) {
      throw new VoiceHttpError(403, 'permission_denied', 'selectedLearnerId is outside the parent linkage scope.');
    }
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
    requesterRole: payload.authContext.requesterRole,
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
  modelVersionOverride?: string | null;
  inference?: VoiceInferenceMeta;
  understandingSource?: UnderstandingSource;
  modelToolHintCount?: number;
  personalizationContextUsed?: boolean;
  roleIntelligenceSignals?: number;
  roleIntelligenceRole?: VoiceRequesterRole;
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
      requesterRole: payload.authContext.requesterRole,
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
      understandingIntent: payload.understanding?.intent ?? null,
      ...(payload.understanding?.confidence !== undefined
        ? { understandingConfidence: payload.understanding.confidence }
        : {}),
      responseMode: payload.understanding?.responseMode ?? null,
      needsScaffold: payload.understanding?.needsScaffold ?? null,
      emotionalState: payload.understanding?.emotionalState ?? null,
      complexity: payload.understanding?.complexity ?? null,
      topicTags: payload.understanding?.topicTags ?? null,
      modelVersion: payload.modelVersionOverride ?? null,
      policyVersion: VOICE_POLICY_VERSION,
      redactedPathCount: 0,
      inferenceService: payload.inference?.service ?? null,
      inferenceRoute: payload.inference?.route ?? 'local',
      inferenceAuthMode: payload.inference?.authMode ?? 'none',
      inferenceStatusCode: payload.inference?.statusCode ?? null,
      inferenceErrorCode: payload.inference?.errorCode ?? null,
      inferenceReason: payload.inference?.reason ?? null,
      understandingSource: payload.understandingSource ?? null,
      modelToolHintCount: payload.modelToolHintCount ?? 0,
      personalizationContextUsed: payload.personalizationContextUsed ?? false,
      roleIntelligenceSignals: payload.roleIntelligenceSignals ?? 0,
      roleIntelligenceRole: payload.roleIntelligenceRole ?? payload.authContext.requesterRole,
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
  understandingSource?: UnderstandingSource;
  modelToolHintCount?: number;
  personalizationContextUsed?: boolean;
  roleIntelligenceSignals?: number;
  roleIntelligenceRole?: VoiceRequesterRole;
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
      requesterRole: payload.authContext.requesterRole,
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
      requesterRole: payload.authContext.requesterRole,
      contextMode: bosContext.contextMode,
      conceptTags: bosContext.conceptTags,
      understandingIntent: payload.understanding?.intent ?? null,
      ...(payload.understanding?.confidence !== undefined
        ? { understandingConfidence: payload.understanding.confidence }
        : {}),
      responseMode: payload.understanding?.responseMode ?? null,
      needsScaffold: payload.understanding?.needsScaffold ?? null,
      emotionalState: payload.understanding?.emotionalState ?? null,
      complexity: payload.understanding?.complexity ?? null,
      topicTags: payload.understanding?.topicTags ?? null,
      inferenceService: payload.inference?.service ?? null,
      inferenceRoute: payload.inference?.route ?? 'local',
      inferenceAuthMode: payload.inference?.authMode ?? 'none',
      inferenceStatusCode: payload.inference?.statusCode ?? null,
      inferenceErrorCode: payload.inference?.errorCode ?? null,
      inferenceReason: payload.inference?.reason ?? null,
      understandingSource: payload.understandingSource ?? null,
      modelToolHintCount: payload.modelToolHintCount ?? 0,
      personalizationContextUsed: payload.personalizationContextUsed ?? false,
      roleIntelligenceSignals: payload.roleIntelligenceSignals ?? 0,
      roleIntelligenceRole: payload.roleIntelligenceRole ?? payload.authContext.requesterRole,
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
  understandingSource?: UnderstandingSource;
  modelToolHintCount?: number;
  personalizationContextUsed?: boolean;
  roleIntelligenceSignals?: number;
  roleIntelligenceRole?: VoiceRequesterRole;
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
  if (payload.understandingSource === 'model' || payload.understandingSource === 'blended') {
    metrics.modelAugmentedCount = admin.firestore.FieldValue.increment(1);
  }
  if ((payload.modelToolHintCount ?? 0) > 0) {
    metrics.modelToolHintsApplied = admin.firestore.FieldValue.increment(payload.modelToolHintCount ?? 0);
  }
  if (payload.personalizationContextUsed) {
    metrics.personalizedContextCount = admin.firestore.FieldValue.increment(1);
  }
  if ((payload.roleIntelligenceSignals ?? 0) > 0) {
    metrics.roleIntelligenceSignalCount = admin.firestore.FieldValue.increment(payload.roleIntelligenceSignals ?? 0);
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
    if (payload.understanding.emotionalState === 'frustrated' || payload.understanding.emotionalState === 'confused') {
      metrics.frustrationSignalCount = admin.firestore.FieldValue.increment(1);
    }
    learning.lastIntent = payload.understanding.intent;
    learning.lastComplexity = payload.understanding.complexity;
    learning.lastResponseMode = payload.understanding.responseMode;
    learning.lastNeedsScaffold = payload.understanding.needsScaffold;
    learning.lastEmotionalState = payload.understanding.emotionalState;
    learning.lastUnderstandingConfidence = payload.understanding.confidence;
    learning.lastTopicTags = payload.understanding.topicTags;
    learning.recentTurnEntry = {
      intent: payload.understanding.intent,
      responseMode: payload.understanding.responseMode,
      emotionalState: payload.understanding.emotionalState,
      timestamp: Date.now(),
    };
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
    lastUnderstandingSource: payload.understandingSource ?? null,
    lastRoleIntelligenceRole: payload.roleIntelligenceRole ?? payload.authContext.requesterRole,
    updatedAtIso: nowIso,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    metrics,
  };
  if (Object.keys(learning).length > 0) {
    updateDoc.learning = learning;
  }

  await admin.firestore().runTransaction(async (transaction) => {
    const profileSnap = await transaction.get(profileRef);
    const recentTurnEntry = learning.recentTurnEntry as VoiceRecentTurn | undefined;
    delete learning.recentTurnEntry;

    if (!profileSnap.exists) {
      const initDoc = {
        ...updateDoc,
        createdAtIso: nowIso,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      if (recentTurnEntry && Object.keys(learning).length > 0) {
        (initDoc as Record<string, unknown>).learning = { ...learning, recentTurns: [recentTurnEntry] };
      }
      transaction.set(profileRef, initDoc, { merge: true });
      return;
    }
    if (recentTurnEntry) {
      const existing = profileSnap.data()?.learning?.recentTurns;
      const turns: VoiceRecentTurn[] = Array.isArray(existing) ? existing.slice(0, 4) : [];
      turns.unshift(recentTurnEntry);
      if (Object.keys(learning).length > 0) {
        learning.recentTurns = turns;
      }
      if (updateDoc.learning && typeof updateDoc.learning === 'object') {
        (updateDoc.learning as Record<string, unknown>).recentTurns = turns;
      }
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
  if (authContext.requesterRole === 'parent') {
    if (!settings.voiceEnabled || (!settings.teacherVoiceEnabled && !settings.adminVoiceEnabled)) {
      throw new VoiceHttpError(403, 'permission_denied', 'Voice is disabled for this role or tenant.');
    }
    return;
  }
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

function toInferenceLearningSnapshot(snapshot: VoiceLearningSnapshot | null): Record<string, unknown> | null {
  if (!snapshot) return null;
  return {
    actorRole: snapshot.actorRole,
    lastIntent: snapshot.lastIntent,
    lastResponseMode: snapshot.lastResponseMode,
    lastNeedsScaffold: snapshot.lastNeedsScaffold,
    lastEmotionalState: snapshot.lastEmotionalState,
    lastUnderstandingConfidence: snapshot.lastUnderstandingConfidence,
    needsScaffoldCount: snapshot.needsScaffoldCount,
    frustrationSignalCount: snapshot.frustrationSignalCount,
    recentTurns: snapshot.recentTurns?.slice(0, 5) ?? [],
  };
}

async function loadVoiceLearningSnapshot(
  authContext: VoiceAuthContext,
  body: Record<string, unknown>,
): Promise<VoiceLearningSnapshot | null> {
  const bosContext = resolveBosInteractionContext(body, authContext);
  if (!authContext.siteId || !bosContext.actorId) return null;
  const profileId = `${authContext.siteId}__${bosContext.actorId}`;
  const snapshot = await admin.firestore().collection('bosLearningProfiles').doc(profileId).get();
  if (!snapshot.exists) return null;
  const data = snapshot.data() ?? {};
  const learning = asRecord(data.learning) ?? {};
  const metrics = asRecord(data.metrics) ?? {};
  return {
    profileId,
    actorId: bosContext.actorId,
    actorRole: bosContext.actorRole,
    lastIntent: normalizeString(learning.lastIntent) ?? null,
    lastResponseMode: normalizeString(learning.lastResponseMode) ?? null,
    lastNeedsScaffold: Boolean(learning.lastNeedsScaffold),
    lastEmotionalState: normalizeString(learning.lastEmotionalState) ?? null,
    lastUnderstandingConfidence:
      firstNumber(learning.lastUnderstandingConfidence) === undefined
        ? undefined
        : clampProbability(firstNumber(learning.lastUnderstandingConfidence)!),
    needsScaffoldCount: Math.max(0, Math.floor(toFiniteNumber(metrics.needsScaffoldCount, 0))),
    frustrationSignalCount: Math.max(0, Math.floor(toFiniteNumber(metrics.frustrationSignalCount, 0))),
    recentTurns: parseRecentTurns(learning.recentTurns),
  };
}

function parseRecentTurns(raw: unknown): VoiceRecentTurn[] {
  if (!Array.isArray(raw)) return [];
  return raw
    .filter((t): t is Record<string, unknown> => t !== null && typeof t === 'object')
    .slice(0, 5)
    .map((t) => ({
      intent: typeof t.intent === 'string' ? t.intent : 'general_support',
      responseMode: typeof t.responseMode === 'string' ? t.responseMode : 'hint',
      emotionalState: typeof t.emotionalState === 'string' ? t.emotionalState : 'neutral',
      timestamp: typeof t.timestamp === 'number' ? t.timestamp : 0,
    }));
}

function nonZeroSignalCount(values: number[]): number {
  return values.filter((value) => Number.isFinite(value) && value > 0).length;
}

async function buildRoleIntelligenceLearnerProfile(
  siteId: string,
  learnerId: string,
): Promise<RoleIntelligenceLearnerProfile> {
  const learnerSnap = await admin.firestore().collection('users').doc(learnerId).get().catch(() => null);
  const learnerData = learnerSnap?.exists ? (learnerSnap.data() as Record<string, unknown>) : {};
  const linkedEducatorCount = dedupeStrings([
    ...normalizeStringArray(learnerData?.educatorIds),
    ...normalizeStringArray(learnerData?.teacherIds),
  ]).length;
  const linkedParentCount = dedupeStrings([
    ...normalizeStringArray(learnerData?.parentIds),
    ...normalizeStringArray(learnerData?.guardianIds),
  ]).length;
  const assignedMissionCount = dedupeStrings([
    ...normalizeStringArray(learnerData?.missionIds),
    ...normalizeStringArray(learnerData?.activeMissionIds),
  ]).length;
  const recentInteractionCount = await safeQueryCount(
    admin.firestore()
      .collection(BOS_INTERACTION_COLLECTION)
      .where('siteId', '==', siteId)
      .where('actorId', '==', learnerId)
      .limit(30),
  ) ?? 0;
  const learningSnapshot = await admin.firestore()
    .collection('bosLearningProfiles')
    .doc(`${siteId}__${learnerId}`)
    .get()
    .catch(() => null);
  const learning = learningSnapshot?.exists
    ? asRecord(learningSnapshot.data()?.learning) ?? {}
    : {};

  return {
    learnerId,
    linkedEducatorCount,
    linkedParentCount,
    assignedMissionCount,
    recentInteractionCount,
    lastIntent: normalizeString(learning.lastIntent),
    lastResponseMode: normalizeString(learning.lastResponseMode),
    lastNeedsScaffold: typeof learning.lastNeedsScaffold === 'boolean' ? learning.lastNeedsScaffold : undefined,
    lastEmotionalState: normalizeString(learning.lastEmotionalState),
    lastUnderstandingConfidence:
      typeof learning.lastUnderstandingConfidence === 'number'
        ? clampProbability(learning.lastUnderstandingConfidence)
        : undefined,
  };
}

async function loadRoleIntelligenceContext(
  authContext: VoiceAuthContext,
  body: Record<string, unknown>,
): Promise<RoleIntelligenceContext> {
  const bosContext = resolveBosInteractionContext(body, authContext);
  const requestedSelectedLearnerId = normalizeString((body.context as Record<string, unknown> | undefined)?.selectedLearnerId);
  const siteRef = admin.firestore().collection('sites').doc(authContext.siteId);
  const siteSnap = await siteRef.get().catch(() => null);
  const siteData = siteSnap?.exists ? (siteSnap.data() as Record<string, unknown>) : {};

  const siteLearnerCount = dedupeStrings([
    ...normalizeStringArray(siteData?.learnerIds),
    ...normalizeStringArray(siteData?.studentIds),
  ]).length;
  const siteEducatorCount = dedupeStrings([
    ...normalizeStringArray(siteData?.educatorIds),
    ...normalizeStringArray(siteData?.teacherIds),
    ...normalizeStringArray(siteData?.siteLeadIds),
  ]).length;
  const siteParentCount = normalizeStringArray(siteData?.parentIds).length;
  const openMvlCount = await safeQueryCount(
    admin.firestore()
      .collection('mvlEpisodes')
      .where('siteId', '==', authContext.siteId)
      .where('resolution', '==', null)
      .limit(100),
  ) ?? 0;
  const activeMissionCount = await safeQueryCount(
    admin.firestore()
      .collection('missions')
      .where('siteId', '==', authContext.siteId)
      .where('status', '==', 'active')
      .limit(100),
  ) ?? 0;
  const siteProfile: RoleSiteIntelligenceProfile = {
    learnerCount: siteLearnerCount,
    educatorCount: siteEducatorCount,
    parentCount: siteParentCount,
    openMvlCount,
    activeMissionCount,
  };

  const context: RoleIntelligenceContext = {
    version: 'role-intel-v2',
    role: authContext.role,
    requesterRole: authContext.requesterRole,
    siteId: authContext.siteId,
    actorId: bosContext.actorId,
    siteProfile,
    signalCount: 0,
  };

  if (authContext.requesterRole === 'student') {
    const learnerProfile = await buildRoleIntelligenceLearnerProfile(authContext.siteId, bosContext.actorId);
    context.learnerProfile = {
      linkedEducatorCount: learnerProfile.linkedEducatorCount,
      linkedParentCount: learnerProfile.linkedParentCount,
      assignedMissionCount: learnerProfile.assignedMissionCount,
      recentInteractionCount: learnerProfile.recentInteractionCount,
    };
    context.selectedLearnerProfile = learnerProfile;
    context.signalCount = nonZeroSignalCount([
      learnerProfile.linkedEducatorCount,
      learnerProfile.linkedParentCount,
      learnerProfile.assignedMissionCount,
      learnerProfile.recentInteractionCount,
      siteProfile.activeMissionCount,
    ]);
    return context;
  }

  if (authContext.requesterRole === 'teacher') {
    const learnerIds = await collectEducatorLinkedLearnerIds(authContext.uid, authContext.siteId);
    const selectedLearnerId = requestedSelectedLearnerId ?? (learnerIds.length === 1 ? learnerIds[0] : undefined);
    const selectedLearnerProfile = selectedLearnerId
      ? await buildRoleIntelligenceLearnerProfile(authContext.siteId, selectedLearnerId)
      : undefined;
    if (selectedLearnerId) context.selectedLearnerId = selectedLearnerId;
    if (selectedLearnerProfile) context.selectedLearnerProfile = selectedLearnerProfile;

    context.educatorProfile = {
      rosterCount: learnerIds.length,
      selectedLearnerLinkedParentCount: selectedLearnerProfile?.linkedParentCount ?? 0,
      selectedLearnerMissionCount: selectedLearnerProfile?.assignedMissionCount ?? 0,
      selectedLearnerRecentInteractionCount: selectedLearnerProfile?.recentInteractionCount ?? 0,
    };
    context.signalCount = nonZeroSignalCount([
      learnerIds.length,
      selectedLearnerProfile?.linkedParentCount ?? 0,
      selectedLearnerProfile?.assignedMissionCount ?? 0,
      selectedLearnerProfile?.recentInteractionCount ?? 0,
      siteProfile.learnerCount,
    ]);
    return context;
  }

  if (authContext.requesterRole === 'parent') {
    const learnerIds = await collectParentLinkedLearnerIds(authContext.uid, authContext.siteId);
    const selectedLearnerId = requestedSelectedLearnerId ?? (learnerIds.length === 1 ? learnerIds[0] : undefined);
    const selectedLearnerProfile = selectedLearnerId
      ? await buildRoleIntelligenceLearnerProfile(authContext.siteId, selectedLearnerId)
      : undefined;
    if (selectedLearnerId) context.selectedLearnerId = selectedLearnerId;
    if (selectedLearnerProfile) context.selectedLearnerProfile = selectedLearnerProfile;
    context.parentProfile = {
      linkedLearnerCount: learnerIds.length,
      selectedLearnerLinkedEducatorCount: selectedLearnerProfile?.linkedEducatorCount ?? 0,
      selectedLearnerMissionCount: selectedLearnerProfile?.assignedMissionCount ?? 0,
      selectedLearnerRecentInteractionCount: selectedLearnerProfile?.recentInteractionCount ?? 0,
    };
    context.signalCount = nonZeroSignalCount([
      learnerIds.length,
      selectedLearnerProfile?.linkedEducatorCount ?? 0,
      selectedLearnerProfile?.assignedMissionCount ?? 0,
      selectedLearnerProfile?.recentInteractionCount ?? 0,
      siteProfile.learnerCount,
    ]);
    return context;
  }

  context.adminProfile = {
    learnerCount: siteProfile.learnerCount,
    educatorCount: siteProfile.educatorCount,
    parentCount: siteProfile.parentCount,
    openMvlCount: siteProfile.openMvlCount,
    activeMissionCount: siteProfile.activeMissionCount,
  };
  context.signalCount = nonZeroSignalCount([
    siteProfile.learnerCount,
    siteProfile.educatorCount,
    siteProfile.parentCount,
    siteProfile.openMvlCount,
    siteProfile.activeMissionCount,
  ]);
  return context;
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
    await assertActiveSchoolConsent(authContext.siteId);
    const settings = await loadVoiceSettings(authContext.siteId);
    await enforceVoiceAccess(authContext, settings);
    await maybeValidateSelectedLearnerScope(authContext, body);

    const locale = resolveLocale(body.locale, req, settings.allowedLocales);
    const message = normalizeSpeechText(normalizeString(body.message) ?? '');
    if (!message) {
      throw new VoiceHttpError(400, 'invalid_argument', 'message is required.');
    }

    const requestId = resolveRequestId(req);
    const traceId = resolveTraceId(req, body);
    const safety = evaluateSafetyDecision(message, authContext.requesterRole, locale);
    const heuristicUnderstanding = deriveUnderstandingSignal({
      message,
      role: authContext.requesterRole,
      safety,
    });
    let understanding = heuristicUnderstanding;
    let understandingSource: UnderstandingSource = 'heuristic';
    let modelToolHints: string[] = [];
    const [learningSnapshot, roleIntelligence] = await Promise.all([
      loadVoiceLearningSnapshot(authContext, body),
      loadRoleIntelligenceContext(authContext, body),
    ]);
    const requestContext = asRecord(body.context);
    const bosContext = resolveBosInteractionContext(body, authContext);
    const personaInstructions = normalizeString(requestContext?.personaInstructions);

    // Extract client-side orchestration state (live Firestore EMA estimates).
    const clientOrchState = resolveClientOrchestrationState(requestContext);
    const clientMvlContext = resolveClientMvlContext(requestContext);
    const personalizationContextUsed = Boolean(learningSnapshot) || roleIntelligence.signalCount > 0;
    const roleIntelligenceSignals = roleIntelligence.signalCount;
    const baselineCandidateText = safety.safetyOutcome === 'allowed'
      ? buildAdaptiveLocalizedResponse(authContext.requesterRole, locale, safety.category, understanding)
      : safety.localizedMessage;
    let candidateText = baselineCandidateText;
    let responseGenerationSource: ResponseGenerationSource = safety.safetyOutcome === 'allowed' ? 'local' : 'guardrail';
    let llmModelVersion: string | null = null;
    let inferenceMeta: VoiceInferenceMeta = buildLocalInferenceMeta(
      'llm',
      safety.safetyOutcome === 'allowed' ? 'not_attempted' : 'safety_blocked',
    );
    let _bosInferenceMeta: VoiceInferenceMeta = buildLocalInferenceMeta(
      'bos',
      safety.safetyOutcome === 'allowed' ? 'not_attempted' : 'safety_blocked',
    );
    let _bosPolicyHint: BosPolicyHint | null = null;
    if (safety.safetyOutcome === 'allowed') {
      const llmResult = await callInternalInferenceJson<Record<string, unknown>, Record<string, unknown>>({
        service: 'llm',
        body: {
          message,
          locale,
          role: authContext.role,
          requesterRole: authContext.requesterRole,
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
          learningSnapshot: toInferenceLearningSnapshot(learningSnapshot),
          roleIntelligenceContext: roleIntelligence,
          ...(clientOrchState ? { orchestrationState: clientOrchState } : {}),
          ...(clientMvlContext ? { activeMvl: clientMvlContext } : {}),
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
      const certifiedModelConfidenceRaw = firstNumber(llmPayload?.understanding?.confidence);
      const certifiedModelConfidence = certifiedModelConfidenceRaw === undefined
        ? undefined
        : clampProbability(certifiedModelConfidenceRaw);
      if (llmPayload?.modelVersion) {
        llmModelVersion = llmPayload.modelVersion;
      }
      if (llmPayload?.understanding) {
        understanding = mergeUnderstandingSignal(understanding, llmPayload.understanding);
        understandingSource = 'blended';
      }
      if ((llmPayload?.toolSuggestions?.length ?? 0) > 0) {
        modelToolHints = llmPayload?.toolSuggestions ?? [];
      }
      if (llmResult.ok && suggestedText) {
        if (
          requiresStrictStudentConfidence(authContext.requesterRole) &&
          (certifiedModelConfidence === undefined ||
            certifiedModelConfidence < MIN_AUTONOMOUS_STUDENT_CONFIDENCE)
        ) {
          candidateText = buildStudentConfidenceGuardResponse(locale);
          responseGenerationSource = 'guardrail';
          inferenceMeta = buildInferenceMeta('llm', llmResult, 'child_low_confidence_guard');
        } else {
          const outputSafety = evaluateSafetyDecision(suggestedText, authContext.requesterRole, locale);
          if (outputSafety.safetyOutcome === 'allowed') {
            candidateText = suggestedText;
            responseGenerationSource = 'model';
            inferenceMeta = buildInferenceMeta('llm', llmResult);
          } else if (outputSafety.safetyOutcome === 'modified') {
            candidateText = outputSafety.localizedMessage;
            responseGenerationSource = 'guardrail';
            inferenceMeta = buildInferenceMeta('llm', llmResult, 'model_output_modified');
          } else {
            responseGenerationSource = 'guardrail';
            inferenceMeta = buildInferenceMeta('llm', llmResult, 'model_output_blocked');
          }
        }
      } else if (llmResult.ok) {
        if (requiresStrictStudentConfidence(authContext.requesterRole)) {
          candidateText = buildStudentInferenceUnavailableResponse(locale);
          responseGenerationSource = 'guardrail';
          inferenceMeta = buildInferenceMeta('llm', llmResult, 'child_empty_inference_response');
        } else {
          if (isInternalInferenceRequired()) {
            throw new VoiceHttpError(503, 'inference_unavailable', 'Internal LLM response was empty.');
          }
          inferenceMeta = buildInferenceMeta('llm', llmResult, 'empty_model_text');
        }
      } else {
        if (requiresStrictStudentConfidence(authContext.requesterRole)) {
          candidateText = buildStudentInferenceUnavailableResponse(locale);
          responseGenerationSource = 'guardrail';
          inferenceMeta = buildInferenceMeta('llm', llmResult, 'child_inference_unavailable');
        } else {
          inferenceMeta = buildInferenceMeta('llm', llmResult, 'internal_call_failed');
        }
      }

      if (
        authContext.requesterRole === 'student' &&
        responseGenerationSource === 'local' &&
        understandingSource === 'heuristic'
      ) {
        candidateText = buildHeuristicOnlyStudentResponse(locale);
        responseGenerationSource = 'guardrail';
        inferenceMeta = buildLocalInferenceMeta('llm', 'heuristic_only_clarification');
      }

      const bosResult = await callInternalInferenceJson<Record<string, unknown>, Record<string, unknown>>({
        service: 'bos',
        body: {
          message,
          locale,
          role: authContext.role,
          requesterRole: authContext.requesterRole,
          gradeBand: authContext.gradeBand,
          actorId: bosContext.actorId,
          actorRole: bosContext.actorRole,
          sessionOccurrenceId: bosContext.sessionOccurrenceId,
          missionId: bosContext.missionId,
          checkpointId: bosContext.checkpointId,
          contextMode: bosContext.contextMode,
          conceptTags: bosContext.conceptTags,
          understanding,
          learningSnapshot: toInferenceLearningSnapshot(learningSnapshot),
          roleIntelligenceContext: roleIntelligence,
          ...(clientOrchState ? { orchestrationState: clientOrchState } : {}),
          ...(clientMvlContext ? { activeMvl: clientMvlContext } : {}),
        },
        context: buildInferenceContextHeaders({
          traceId,
          requestId,
          authContext,
          locale,
          callerService: 'scholesa-ai-bos',
        }),
      });

      if (isInternalInferenceRequired() && !bosResult.ok) {
        throw new VoiceHttpError(503, 'inference_unavailable', 'Internal BOS inference is required but unavailable.');
      }

      if (bosResult.ok) {
        const policyHint = extractInternalBosPayload(bosResult.data);
        if (policyHint) {
          _bosPolicyHint = policyHint;
          const applyPolicyHint =
            policyHint.confidence !== undefined &&
            policyHint.confidence >= MIN_AUTONOMOUS_POLICY_CONFIDENCE;
          if (applyPolicyHint) {
            const bosModeToolHints = deriveBosModeToolHints(authContext.requesterRole, policyHint);
            modelToolHints = dedupeStrings([...modelToolHints, ...bosModeToolHints]).slice(0, 6);
          }
          _bosInferenceMeta = buildInferenceMeta(
            'bos',
            bosResult,
            applyPolicyHint ? 'policy_hint_applied' : 'policy_hint_low_confidence',
          );
        } else {
          _bosInferenceMeta = buildInferenceMeta('bos', bosResult, 'no_policy_payload');
        }
      } else {
        _bosInferenceMeta = buildInferenceMeta('bos', bosResult, 'internal_call_failed');
      }
    }

    if (authContext.requesterRole === 'student') {
      candidateText = applyStudentConversationalTone(candidateText, locale);
    }
    if (personaInstructions && /kid|child|friendly|conversational|spoken/i.test(personaInstructions)) {
      candidateText = applyStudentConversationalTone(candidateText, locale);
    }

    // BOS policy mode shapes the response style when confidence is high enough.
    if (_bosPolicyHint && _bosPolicyHint.confidence !== undefined &&
        _bosPolicyHint.confidence >= MIN_AUTONOMOUS_POLICY_CONFIDENCE) {
      candidateText = applyBosPolicyModeStyle(candidateText, _bosPolicyHint, locale, authContext.requesterRole);
    }

    const toolsInvoked = selectToolCalls(
      authContext.requesterRole,
      safety.category,
      safety.safetyOutcome,
      understanding,
      modelToolHints,
    );
    const modelToolHintCount = modelToolHints.length > 0
      ? toolsInvoked.filter((tool) => modelToolHints.includes(tool)).length
      : 0;
    const voiceInput = body.voice as Record<string, unknown> | undefined;
    const voiceOutputEnabled = normalizeBoolean(voiceInput?.enabled, true) && normalizeBoolean(voiceInput?.output, true);
    const quietModeActive = isQuietModeActive(settings, new Date());
    const knownNames = extractKnownNames(body);
    const preparedSpeech = redactTextForSpeech(candidateText, knownNames);
    const voiceProfile = chooseVoiceProfile(locale, authContext.requesterRole, authContext.gradeBand);
    const shouldSpeak = voiceOutputEnabled && !quietModeActive && preparedSpeech.speechText.length > 0;

    let effectiveSafetyOutcome: SafetyOutcome = safety.safetyOutcome;
    let effectiveSafetyReasonCode = safety.safetyReasonCode;
    if (inferenceMeta.reason === 'child_low_confidence_guard') {
      effectiveSafetyOutcome = 'escalated';
      effectiveSafetyReasonCode = 'child_low_confidence_guard';
    } else if (inferenceMeta.reason === 'child_empty_inference_response') {
      effectiveSafetyOutcome = 'escalated';
      effectiveSafetyReasonCode = 'child_empty_inference_response';
    } else if (inferenceMeta.reason === 'child_inference_unavailable') {
      effectiveSafetyOutcome = 'escalated';
      effectiveSafetyReasonCode = 'child_inference_unavailable';
    }

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

    const languageCompatible = detectLanguageCompatibility(candidateText, locale);
    const responseText = languageCompatible
      ? candidateText
      : requiresStrictStudentConfidence(authContext.requesterRole)
      ? buildStudentConfidenceGuardResponse(locale)
      : buildAdaptiveLocalizedResponse(authContext.requesterRole, locale, 'generic', understanding);
    if (!languageCompatible && requiresStrictStudentConfidence(authContext.requesterRole)) {
      effectiveSafetyOutcome = 'escalated';
      effectiveSafetyReasonCode = 'output_language_mismatch_guard';
    }
    const latencyMs = Date.now() - startedAt;
    const supplementalSafetyEvent: VoiceTelemetryEvent | null =
      effectiveSafetyOutcome === 'escalated'
        ? 'voice.escalated'
        : (effectiveSafetyOutcome === 'blocked' || effectiveSafetyOutcome === 'modified')
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
        safetyOutcome: effectiveSafetyOutcome,
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
        safetyOutcome: effectiveSafetyOutcome,
        redactionApplied: preparedSpeech.redactionApplied,
        redactionCount: preparedSpeech.redactionCount,
        quietModeActive,
        toolCount: toolsInvoked.length,
        textLength: message.length,
        understanding,
        modelVersionOverride: llmModelVersion,
        inference: inferenceMeta,
        understandingSource,
        modelToolHintCount,
        personalizationContextUsed,
        roleIntelligenceSignals,
        roleIntelligenceRole: roleIntelligence.requesterRole,
      }),
    ];

    const compatibilityWrites: Promise<unknown>[] = [
      upsertBosLearningProfile({
        endpoint: 'copilot_message',
        traceId,
        authContext,
        body,
        locale,
        safetyOutcome: effectiveSafetyOutcome,
        understanding,
        textLength: message.length,
        understandingSource,
        modelToolHintCount,
        personalizationContextUsed,
        roleIntelligenceSignals,
        roleIntelligenceRole: roleIntelligence.requesterRole,
      }),
      recordVoiceTelemetryEvent({
        event: 'ai_help_opened',
        endpoint: 'copilot_message',
        requestId,
        traceId,
        authContext,
        locale,
        latencyMs,
        safetyOutcome: effectiveSafetyOutcome,
        toolCount: toolsInvoked.length,
        textLength: message.length,
        understanding,
        modelVersionOverride: llmModelVersion,
        inference: inferenceMeta,
        understandingSource,
        modelToolHintCount,
        personalizationContextUsed,
        roleIntelligenceSignals,
        roleIntelligenceRole: roleIntelligence.requesterRole,
      }),
      recordVoiceTelemetryEvent({
        event: 'ai_help_used',
        endpoint: 'copilot_message',
        requestId,
        traceId,
        authContext,
        locale,
        latencyMs,
        safetyOutcome: effectiveSafetyOutcome,
        toolCount: toolsInvoked.length,
        textLength: message.length,
        understanding,
        modelVersionOverride: llmModelVersion,
        inference: inferenceMeta,
        understandingSource,
        modelToolHintCount,
        personalizationContextUsed,
        roleIntelligenceSignals,
        roleIntelligenceRole: roleIntelligence.requesterRole,
      }),
      recordVoiceTelemetryEvent({
        event: 'ai_coach_response',
        endpoint: 'copilot_message',
        requestId,
        traceId,
        authContext,
        locale,
        latencyMs,
        safetyOutcome: effectiveSafetyOutcome,
        toolCount: toolsInvoked.length,
        textLength: responseText.length,
        understanding,
        modelVersionOverride: llmModelVersion,
        inference: inferenceMeta,
        understandingSource,
        modelToolHintCount,
        personalizationContextUsed,
        roleIntelligenceSignals,
        roleIntelligenceRole: roleIntelligence.requesterRole,
      }),
      recordBosInteractionEvent({
        eventType: 'ai_help_opened',
        endpoint: 'copilot_message',
        requestId,
        traceId,
        authContext,
        body,
        locale,
        safetyOutcome: effectiveSafetyOutcome,
        latencyMs,
        toolCount: toolsInvoked.length,
        textLength: message.length,
        ttsAvailable: Boolean(audioUrl),
        understanding,
        inference: inferenceMeta,
        understandingSource,
        modelToolHintCount,
        personalizationContextUsed,
        roleIntelligenceSignals,
        roleIntelligenceRole: roleIntelligence.requesterRole,
      }),
      recordBosInteractionEvent({
        eventType: 'ai_help_used',
        endpoint: 'copilot_message',
        requestId,
        traceId,
        authContext,
        body,
        locale,
        safetyOutcome: effectiveSafetyOutcome,
        latencyMs,
        toolCount: toolsInvoked.length,
        textLength: message.length,
        ttsAvailable: Boolean(audioUrl),
        understanding,
        inference: inferenceMeta,
        understandingSource,
        modelToolHintCount,
        personalizationContextUsed,
        roleIntelligenceSignals,
        roleIntelligenceRole: roleIntelligence.requesterRole,
      }),
      recordBosInteractionEvent({
        eventType: 'ai_coach_response',
        endpoint: 'copilot_message',
        requestId,
        traceId,
        authContext,
        body,
        locale,
        safetyOutcome: effectiveSafetyOutcome,
        latencyMs,
        toolCount: toolsInvoked.length,
        textLength: responseText.length,
        ttsAvailable: Boolean(audioUrl),
        understanding,
        inference: inferenceMeta,
        understandingSource,
        modelToolHintCount,
        personalizationContextUsed,
        roleIntelligenceSignals,
        roleIntelligenceRole: roleIntelligence.requesterRole,
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
          safetyOutcome: effectiveSafetyOutcome,
          redactionApplied: preparedSpeech.redactionApplied,
          redactionCount: preparedSpeech.redactionCount,
          quietModeActive,
          toolCount: toolsInvoked.length,
          textLength: message.length,
          understanding,
          modelVersionOverride: llmModelVersion,
          inference: inferenceMeta,
          understandingSource,
          modelToolHintCount,
          personalizationContextUsed,
          roleIntelligenceSignals,
          roleIntelligenceRole: roleIntelligence.requesterRole,
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
        safetyOutcome: effectiveSafetyOutcome,
        safetyReasonCode: effectiveSafetyReasonCode,
        policyVersion: VOICE_POLICY_VERSION,
        modelVersion: responseGenerationSource === 'model' ? llmModelVersion : null,
        locale,
        role: authContext.requesterRole,
        gradeBand: authContext.gradeBand,
        toolsInvoked,
        quietModeActive,
        redactionApplied: preparedSpeech.redactionApplied,
        redactionCount: preparedSpeech.redactionCount,
        understandingSource,
        responseGenerationSource,
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
      bos: _bosPolicyHint ? {
        mode: _bosPolicyHint.mode ?? null,
        type: _bosPolicyHint.type ?? null,
        salience: _bosPolicyHint.salience ?? null,
        triggerMvl: _bosPolicyHint.triggerMvl === true,
        confidence: _bosPolicyHint.confidence ?? null,
        reasonCodes: _bosPolicyHint.reasonCodes ?? [],
        requiresExplainBack: _bosPolicyHint.triggerMvl === true ||
          (understanding.needsScaffold && authContext.requesterRole === 'student'),
      } : null,
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
    await assertActiveSchoolConsent(authContext.siteId);
    const settings = await loadVoiceSettings(authContext.siteId);
    await enforceVoiceAccess(authContext, settings);
    await maybeValidateSelectedLearnerScope(authContext, resolvedBody);

    if (!transcriptRaw && uploadedAudioLength === 0) {
      throw new VoiceHttpError(400, 'invalid_argument', 'audio or transcript input is required.');
    }

    const locale = resolveLocale(localeHint, req, settings.allowedLocales);
    const requestId = resolveRequestId(req);
    const traceId = resolveTraceId(req, resolvedBody);
    const [learningSnapshot, roleIntelligence] = await Promise.all([
      loadVoiceLearningSnapshot(authContext, resolvedBody),
      loadRoleIntelligenceContext(authContext, resolvedBody),
    ]);
    const personalizationContextUsed = Boolean(learningSnapshot) || roleIntelligence.signalCount > 0;
    const roleIntelligenceSignals = roleIntelligence.signalCount;
    const partial = normalizeBoolean(partialHint, false);
    let transcriptCandidate = transcriptRaw;
    let confidence = transcriptRaw ? 0.96 : undefined;
    let sttModelVersion: string | null = null;
    let sttModelUnderstanding: PartialVoiceUnderstandingSignal | undefined;
    let understandingSource: UnderstandingSource = 'heuristic';
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
          requesterRole: authContext.requesterRole,
          gradeBand: authContext.gradeBand,
          learningSnapshot: toInferenceLearningSnapshot(learningSnapshot),
          roleIntelligenceContext: roleIntelligence,
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
        understandingSource = 'blended';
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
    const transcript = cleanTranscript(transcriptCandidate ?? '');
    if (!transcript) {
      const latencyMs = Date.now() - startedAt;
      await Promise.all([
        recordVoiceAuditEvent({
          eventType: 'voice.escalated',
          endpoint: 'voice_transcribe',
          requestId,
          traceId,
          authContext,
          locale,
          safetyOutcome: 'escalated',
          latencyMs,
        }),
        recordVoiceTelemetryEvent({
          event: 'voice.escalated',
          endpoint: 'voice_transcribe',
          requestId,
          traceId,
          authContext,
          locale,
          latencyMs,
          transcriptProvided: Boolean(transcriptRaw),
          transcriptLength: 0,
          partial,
          audioBytes: uploadedAudioLength,
          safetyOutcome: 'escalated',
          modelVersionOverride: sttModelVersion,
          inference: inferenceMeta,
          understandingSource,
          personalizationContextUsed,
          roleIntelligenceSignals,
          roleIntelligenceRole: roleIntelligence.requesterRole,
        }),
      ]);
      throw new VoiceHttpError(
        422,
        'failed_precondition',
        'Voice transcription did not capture a reliable transcript. Please try again.',
      );
    }
    if (confidence === undefined) {
      confidence = Math.max(0.72, Math.min(0.93, 0.72 + transcript.length / 500));
    }
    const transcribeSafety = evaluateSafetyDecision(transcript, authContext.requesterRole, locale);
    const heuristicUnderstanding = deriveUnderstandingSignal({
      message: transcript,
      role: authContext.requesterRole,
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
        understandingSource,
        personalizationContextUsed,
        roleIntelligenceSignals,
        roleIntelligenceRole: roleIntelligence.requesterRole,
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
        understandingSource,
        personalizationContextUsed,
        roleIntelligenceSignals,
        roleIntelligenceRole: roleIntelligence.requesterRole,
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
        understandingSource,
        personalizationContextUsed,
        roleIntelligenceSignals,
        roleIntelligenceRole: roleIntelligence.requesterRole,
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
        understandingSource,
        personalizationContextUsed,
        roleIntelligenceSignals,
        roleIntelligenceRole: roleIntelligence.requesterRole,
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
        understandingSource,
        modelVersion: sttModelVersion,
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
    await assertActiveSchoolConsent(authContext.siteId);
    const settings = await loadVoiceSettings(authContext.siteId);
    await enforceVoiceAccess(authContext, settings);
    await maybeValidateSelectedLearnerScope(authContext, body);
    const locale = resolveLocale(body.locale, req, settings.allowedLocales);

    const rawText = normalizeSpeechText(normalizeString(body.text) ?? '');
    if (!rawText) {
      throw new VoiceHttpError(400, 'invalid_argument', 'text is required.');
    }
    const ttsSafety = evaluateSafetyDecision(rawText, authContext.requesterRole, locale);
    let understanding = deriveUnderstandingSignal({
      message: rawText,
      role: authContext.requesterRole,
      safety: ttsSafety,
    });
    let understandingSource: UnderstandingSource = 'heuristic';
    const ttsInputText =
      ttsSafety.safetyOutcome === 'blocked' || ttsSafety.safetyOutcome === 'escalated'
        ? ttsSafety.localizedMessage
        : rawText;
    const requestedGradeBand = normalizeGradeBand(body.gradeBand, body.grade);
    const effectiveGradeBand = authContext.requesterRole === 'student' ? authContext.gradeBand : requestedGradeBand;
    const knownNames = extractKnownNames(body);
    const speech = redactTextForSpeech(ttsInputText, knownNames);
    const voiceProfile = chooseVoiceProfile(locale, authContext.requesterRole, effectiveGradeBand);
    const requestId = resolveRequestId(req);
    const traceId = resolveTraceId(req, body);
    const [learningSnapshot, roleIntelligence] = await Promise.all([
      loadVoiceLearningSnapshot(authContext, body),
      loadRoleIntelligenceContext(authContext, body),
    ]);
    const personalizationContextUsed = Boolean(learningSnapshot) || roleIntelligence.signalCount > 0;
    const roleIntelligenceSignals = roleIntelligence.signalCount;
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
    let ttsModelVersion: string | null = null;
    let inferenceMeta: VoiceInferenceMeta = buildLocalInferenceMeta('tts', 'not_attempted');
    const ttsResult = await callInternalInferenceJson<Record<string, unknown>, Record<string, unknown>>({
      service: 'tts',
      body: {
        text: speech.speechText,
        locale,
        role: authContext.role,
        requesterRole: authContext.requesterRole,
        gradeBand: effectiveGradeBand,
        voiceProfile,
        prosodyPolicy: prosodyPolicyTag(authContext.requesterRole, effectiveGradeBand),
        styleHints: buildTtsStyleHints({
          understanding,
          learningSnapshot,
          role: authContext.requesterRole,
        }),
        learningSnapshot: toInferenceLearningSnapshot(learningSnapshot),
        roleIntelligenceContext: roleIntelligence,
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
    if (ttsPayload?.understanding) {
      understanding = mergeUnderstandingSignal(understanding, ttsPayload.understanding);
      understandingSource = 'blended';
    }
    if (ttsResult.ok && ttsPayload?.audioUrl) {
      if (isInternalAudioUrl(ttsPayload.audioUrl)) {
        audioUrl = ttsPayload.audioUrl;
        if (ttsPayload.modelVersion) {
          ttsModelVersion = ttsPayload.modelVersion;
        }
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
        understandingSource,
        personalizationContextUsed,
        roleIntelligenceSignals,
        roleIntelligenceRole: roleIntelligence.requesterRole,
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
        understandingSource,
        personalizationContextUsed,
        roleIntelligenceSignals,
        roleIntelligenceRole: roleIntelligence.requesterRole,
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
        understandingSource,
        personalizationContextUsed,
        roleIntelligenceSignals,
        roleIntelligenceRole: roleIntelligence.requesterRole,
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
        understandingSource,
        personalizationContextUsed,
        roleIntelligenceSignals,
        roleIntelligenceRole: roleIntelligence.requesterRole,
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
        prosodyPolicy: prosodyPolicyTag(authContext.requesterRole, effectiveGradeBand),
        safetyOutcome: ttsSafety.safetyOutcome,
        redactionApplied: speech.redactionApplied,
        redactionCount: speech.redactionCount,
        understandingSource,
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
    // TTS inference service is not configured — do not return fake sine-wave audio.
    // The Flutter client uses FlutterTts as primary; this endpoint honestly signals unavailability.
    res.setHeader('Cache-Control', 'no-store');
    res.status(200).json({
      ttsAvailable: false,
      reason: 'TTS inference service not configured',
      text: payload.text,
      locale: payload.locale,
    });
  } catch (error) {
    responseError(res, error);
  }
}

function enrichWithSsmlProsody(
  text: string,
  understanding: VoiceUnderstandingSignal,
  role: VoiceRequesterRole,
  gradeBand: GradeBand,
  locale: VoiceLocale,
): string {
  if (!text.trim()) return text;
  const rate = understanding.needsScaffold || understanding.emotionalState === 'frustrated' || understanding.emotionalState === 'confused'
    ? '80%'
    : understanding.complexity === 'high' ? '90%' : '100%';
  const pitch = understanding.emotionalState === 'frustrated' || understanding.emotionalState === 'confused'
    ? '+3%'
    : understanding.emotionalState === 'excited' || understanding.emotionalState === 'curious'
      ? '+5%'
      : role === 'teacher' || role === 'parent' || role === 'admin'
        ? '+0%'
        : '+2%';
  const breakMs = understanding.emotionalState === 'frustrated' || understanding.emotionalState === 'confused' ? 400
    : gradeBand === 'K-5' && understanding.needsScaffold ? 500
    : 250;

  const escaped = text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');
  const withBreaks = escaped.replace(
    /([.!?。！？])\s+/g,
    `$1 <break time="${breakMs}ms"/> `,
  );

  return `<speak><prosody rate="${rate}" pitch="${pitch}">${withBreaks}</prosody></speak>`;
}

export async function handleTtsStream(req: Request, res: Response): Promise<void> {
  try {
    const body = typeof req.body === 'object' && req.body !== null
      ? req.body as Record<string, unknown>
      : {};

    const authContext = await resolveAuthContext(req, body);
    await assertActiveSchoolConsent(authContext.siteId);

    const settings = await loadVoiceSettings(authContext.siteId);
    const locale = resolveLocale(body.locale, req, settings.allowedLocales);
    const ttsInputText = normalizeString(body.text);
    if (!ttsInputText) {
      throw new VoiceHttpError(400, 'invalid_argument', 'text is required for streaming TTS.');
    }

    const understanding: VoiceUnderstandingSignal = {
      intent: 'general_support',
      complexity: 'medium',
      needsScaffold: Boolean(body.needsScaffold),
      emotionalState: (normalizeString(body.emotionalState) as VoiceEmotionalState) ?? 'neutral',
      confidence: 1.0,
      responseMode: 'hint',
      topicTags: [],
    };

    const ssml = enrichWithSsmlProsody(
      ttsInputText, understanding, authContext.requesterRole,
      authContext.gradeBand, locale,
    );

    const knownNames = extractKnownNames(body);
    const speech = redactTextForSpeech(ssml, knownNames);
    const voiceProfile = chooseVoiceProfile(locale, authContext.requesterRole, authContext.gradeBand);
    const traceId = resolveTraceId(req, body);
    const requestId = resolveRequestId(req);

    const streamResult = await callInternalInferenceStream({
      service: 'tts',
      body: {
        text: speech.speechText,
        locale,
        voiceProfile,
        format: 'opus',
        streaming: true,
      },
      context: {
        traceId,
        siteId: authContext.siteId,
        role: authContext.role,
        gradeBand: authContext.gradeBand,
        locale,
        policyVersion: VOICE_POLICY_VERSION,
        requestId,
        callerService: 'voice-tts-stream',
      },
      timeoutMs: 15_000,
    });

    if (!streamResult.ok || !streamResult.stream) {
      const fallbackAudio = synthesizeAudioWave(ttsInputText, locale);
      res.status(200).set({
        'Content-Type': 'audio/wav',
        'Content-Length': String(fallbackAudio.length),
        'X-TTS-Source': 'fallback',
      }).send(fallbackAudio);
      return;
    }

    res.status(200).set({
      'Content-Type': 'audio/ogg; codecs=opus',
      'Transfer-Encoding': 'chunked',
      'Cache-Control': 'no-cache',
      'X-TTS-Source': 'stream',
    });

    const reader = streamResult.stream.getReader();
    try {
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        res.write(Buffer.from(value));
      }
    } finally {
      reader.releaseLock();
    }
    res.end();
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
  if (path === '/tts/stream') {
    await handleTtsStream(req, res);
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
    supported: ['/copilot/message', '/voice/transcribe', '/tts/speak', '/tts/stream', '/voice/audio/:token'],
  });
}

export const __voiceSystemInternals = {
  buildAdaptiveLocalizedResponse,
  cleanTranscript,
  createAudioToken,
  deriveBosModeToolHints,
  deriveUnderstandingSignal,
  detectLanguageCompatibility,
  enrichWithSsmlProsody,
  extractInternalBosPayload,
  evaluateSafetyDecision,
  normalizeRequesterRole,
  normalizeRole,
  normalizeVoiceLocale,
  redactTextForSpeech,
  resolveBosInteractionContext,
  resolveClientMvlContext,
  resolveClientOrchestrationState,
  resolveLocale,
  resolveTraceId,
  selectToolCalls,
  synthesizeAudioWave,
  verifyAudioToken,
};
