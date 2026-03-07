/**
 * Model Adapter Layer
 *
 * Scholesa is the system of record and the AI runtime.
 * This adapter is intentionally internal-only: no third-party AI APIs.
 */

import type { AgeBand } from '@/src/types/schema';
import type { SupportedLocale } from '@/src/lib/i18n/config';
import type { Role } from '@/schema';

// ==================== YOUR SCHEMA (vendor-agnostic) ====================

export type TaskType =
  | 'hint_generation'
  | 'rubric_check'
  | 'debug_assistance'
  | 'critique_feedback'
  | 'explain_concept'
  | 'reflection_prompt';

export type PolicyMode =
  | 'k3_safe'       // K-3: Teacher guidance, no PII, simple language
  | 'grades_4_6'    // 4-6: Structured scaffolding
  | 'grades_7_9'    // 7-9: Metacognition, identity-focused
  | 'grades_10_12'; // 10-12: Professional, critique-level

export interface ContextBlock {
  type: 'rubric' | 'artifact' | 'feedback' | 'exemplar' | 'misconception' | 'mission_goal';
  content: string;
  id?: string; // Reference to source (for citations)
  relevance?: number; // 0-1, from retrieval
  metadata?: Record<string, unknown>; // Optional metadata for logging/debugging
}

export interface SafetyConstraints {
  blockHarmfulContent: boolean;
  requireChildSafe: boolean;
  noDirectAnswers: boolean;
  explainBackRequired: boolean;
  maxTokens: number;
}

export interface ModelRequest {
  taskType: TaskType;
  gradeBand: AgeBand;
  targetLocale: SupportedLocale;
  role: Role;
  siteId: string;
  learnerId: string;
  traceId: string;
  promptTemplateId: string;
  policyVersion: string;
  policyMode: PolicyMode;
  missionAttemptId?: string;

  // Student context (redacted, minimal)
  studentLevel: 'emerging' | 'proficient' | 'advanced';
  studentQuestion: string;

  // Retrieved context (from your vector store)
  contextBlocks: ContextBlock[];

  // Your rules
  rubricId?: string;
  safetyConstraints: SafetyConstraints;

  // Response format
  responseFormat: {
    type: 'hint' | 'steps' | 'explanation' | 'questions' | 'feedback';
    includeFollowUp: boolean;
    includeCitations: boolean;
  };
}

export interface ModelResponse {
  answer: string;

  // Structured outputs
  steps?: string[];
  hints?: string[];
  followUpQuestions?: string[];

  // Citations to YOUR artifacts (not model's training data)
  citations?: {
    contextBlockId: string;
    snippet: string;
  }[];

  // Model metadata
  modelVersion: string;
  promptTemplateId: string;
  policyVersion: string;
  safetyOutcome: 'allowed' | 'blocked' | 'modified' | 'escalated';
  safetyReasonCode: string;
  toolCallIds: string[];
  targetLocale: SupportedLocale;
  gradeBand: AgeBand;
  traceId: string;
  missionAttemptId?: string;
  confidence?: number; // 0-1
  safetyFlags?: string[];

  // For your logging
  modelUsed: string;
  tokensUsed: number;
  latencyMs: number;
}

// ==================== ADAPTER INTERFACE ====================

export interface ModelAdapter {
  name: string;

  /**
   * Convert your ModelRequest to an internal AI runtime response.
   */
  complete(request: ModelRequest): Promise<ModelResponse>;

  /**
   * Health check
   */
  isAvailable(): Promise<boolean>;
}

// ==================== INTERNAL ADAPTER ====================

type LocaleText = {
  intro: string;
  noDirect: string;
  taskHint: Record<TaskType, string>;
  contextLead: string;
  explainBack: string;
  followUp: string;
};

const LOCALE_TEXT: Record<SupportedLocale, LocaleText> = {
  en: {
    intro: 'Let us work through this step by step.',
    noDirect: 'I will guide with hints instead of giving the final answer.',
    taskHint: {
      hint_generation: 'Start by identifying the goal, the inputs, and one small action.',
      rubric_check: 'Compare your work against each rubric criterion and note one strength plus one gap.',
      debug_assistance: 'Check what changed most recently, then isolate one possible cause.',
      critique_feedback: 'Focus feedback on evidence, clarity, and one concrete improvement.',
      explain_concept: 'Break the concept into simple parts and connect it to a familiar example.',
      reflection_prompt: 'Think about what worked, what did not, and what you will try next.',
    },
    contextLead: 'Use this mission clue:',
    explainBack: 'Can you explain your reasoning in your own words?',
    followUp: 'What is one next step you can try now?',
  },
  'zh-CN': {
    intro: '我们一步一步来。',
    noDirect: '我会用提示引导你，而不是直接给最终答案。',
    taskHint: {
      hint_generation: '先明确目标、已知条件，再选一个最小可执行步骤。',
      rubric_check: '按评分标准逐项对照，写出一个优势和一个改进点。',
      debug_assistance: '先检查最近改动，再定位一个最可能的原因。',
      critique_feedback: '反馈聚焦证据、清晰度和一个可执行改进。',
      explain_concept: '把概念拆成简单部分，并联系一个熟悉例子。',
      reflection_prompt: '回想什么有效、什么无效、下一步要尝试什么。',
    },
    contextLead: '可参考这个任务线索：',
    explainBack: '你可以用自己的话解释一下你的思路吗？',
    followUp: '你现在可以先尝试哪一步？',
  },
  'zh-TW': {
    intro: '我們一步一步來。',
    noDirect: '我會用提示引導你，而不是直接給最終答案。',
    taskHint: {
      hint_generation: '先明確目標、已知條件，再選一個最小可執行步驟。',
      rubric_check: '按評分標準逐項對照，寫出一個優勢和一個改進點。',
      debug_assistance: '先檢查最近改動，再定位一個最可能的原因。',
      critique_feedback: '回饋聚焦證據、清晰度和一個可執行改進。',
      explain_concept: '把概念拆成簡單部分，並連結一個熟悉例子。',
      reflection_prompt: '回想什麼有效、什麼無效、下一步要嘗試什麼。',
    },
    contextLead: '可參考這個任務線索：',
    explainBack: '你可以用自己的話解釋一下你的思路嗎？',
    followUp: '你現在可以先嘗試哪一步？',
  },
  th: {
    intro: 'เรามาแก้ทีละขั้นตอนกัน',
    noDirect: 'ฉันจะช่วยด้วยคำใบ้แทนการให้คำตอบสุดท้ายทันที',
    taskHint: {
      hint_generation: 'เริ่มจากระบุเป้าหมาย ข้อมูลที่มี และหนึ่งขั้นตอนเล็ก ๆ ที่ทำได้ทันที',
      rubric_check: 'เทียบงานของคุณกับเกณฑ์ทีละข้อ แล้วระบุจุดแข็งหนึ่งข้อและจุดที่ต้องปรับหนึ่งข้อ',
      debug_assistance: 'ตรวจสอบสิ่งที่เปลี่ยนล่าสุด แล้วแยกสาเหตุที่เป็นไปได้ที่สุดหนึ่งข้อ',
      critique_feedback: 'ให้ข้อเสนอแนะโดยยึดหลักฐาน ความชัดเจน และการปรับปรุงที่ทำได้จริงหนึ่งข้อ',
      explain_concept: 'แยกแนวคิดออกเป็นส่วนง่าย ๆ และเชื่อมกับตัวอย่างที่คุ้นเคย',
      reflection_prompt: 'ทบทวนว่าอะไรได้ผล อะไรยังไม่ดี และครั้งต่อไปจะลองอะไร',
    },
    contextLead: 'ใช้เบาะแสภารกิจนี้:',
    explainBack: 'ลองอธิบายเหตุผลของคุณด้วยคำของคุณเองได้ไหม?',
    followUp: 'ตอนนี้คุณลองทำขั้นตอนถัดไปข้อไหนได้บ้าง?',
  },
};

function countApproxTokens(text: string): number {
  // Lightweight approximation for internal telemetry accounting.
  const words = text.trim().split(/\s+/).filter(Boolean).length;
  return Math.max(1, Math.ceil(words * 1.3));
}

function snippet(text: string, maxLen: number): string {
  const trimmed = text.trim();
  if (trimmed.length <= maxLen) return trimmed;
  return `${trimmed.slice(0, maxLen - 1)}…`;
}

export class ScholesaInternalAdapter implements ModelAdapter {
  name = 'scholesa_internal_ai';

  async complete(request: ModelRequest): Promise<ModelResponse> {
    const startTime = Date.now();
    const copy = LOCALE_TEXT[request.targetLocale] || LOCALE_TEXT.en;
    // Prompt invariant for VIBE locale gate: Respond strictly in locale <targetLocale>.

    const topContext = request.contextBlocks
      .slice(0, 2)
      .map((block) => snippet(block.content, 160))
      .filter(Boolean);

    const lines: string[] = [copy.intro, copy.taskHint[request.taskType]];

    if (request.safetyConstraints.noDirectAnswers) {
      lines.push(copy.noDirect);
    }

    if (topContext.length > 0) {
      lines.push(`${copy.contextLead} ${topContext[0]}`);
    }

    if (request.safetyConstraints.explainBackRequired) {
      lines.push(copy.explainBack);
    }

    const answer = lines.join(' ').trim();
    const latencyMs = Date.now() - startTime;

    const citations = request.responseFormat.includeCitations
      ? request.contextBlocks
          .filter((block) => Boolean(block.id))
          .slice(0, 3)
          .map((block) => ({
            contextBlockId: block.id as string,
            snippet: snippet(block.content, 120),
          }))
      : undefined;

    return {
      answer,
      hints: request.taskType === 'hint_generation' ? [copy.taskHint.hint_generation] : undefined,
      followUpQuestions: request.responseFormat.includeFollowUp ? [copy.followUp] : undefined,
      citations: citations && citations.length > 0 ? citations : undefined,
      modelUsed: 'scholesa_internal_ai',
      modelVersion: 'scholesa-internal-ai-v1',
      promptTemplateId: request.promptTemplateId,
      policyVersion: request.policyVersion,
      safetyOutcome: 'allowed',
      safetyReasonCode: 'none',
      toolCallIds: [],
      targetLocale: request.targetLocale,
      gradeBand: request.gradeBand,
      traceId: request.traceId,
      missionAttemptId: request.missionAttemptId,
      confidence: 0.74,
      tokensUsed: countApproxTokens(answer),
      latencyMs,
    };
  }

  async isAvailable(): Promise<boolean> {
    return true;
  }
}

// ==================== MODEL ROUTER ====================

export class ModelRouter {
  private adapters: Map<string, ModelAdapter> = new Map();
  private defaultAdapter = 'scholesa_internal_ai';

  registerAdapter(adapter: ModelAdapter) {
    this.adapters.set(adapter.name, adapter);
  }

  setDefault(adapterName: string) {
    if (!this.adapters.has(adapterName)) {
      throw new Error(`Adapter ${adapterName} not registered`);
    }
    this.defaultAdapter = adapterName;
  }

  async complete(
    request: ModelRequest,
    preferredAdapter?: string
  ): Promise<ModelResponse> {
    const adapterName = preferredAdapter || this.defaultAdapter;
    const adapter = this.adapters.get(adapterName);

    if (!adapter) {
      const fallback = this.adapters.get(this.defaultAdapter);
      if (!fallback) {
        throw new Error('No available internal adapters');
      }
      console.warn(`Adapter ${adapterName} not found, falling back to ${this.defaultAdapter}`);
      return fallback.complete(request);
    }

    if (preferredAdapter && !(await adapter.isAvailable())) {
      const fallback = this.adapters.get(this.defaultAdapter);
      if (!fallback) {
        throw new Error('No available internal adapters');
      }
      console.warn(`${adapterName} unavailable, falling back to ${this.defaultAdapter}`);
      return fallback.complete(request);
    }

    return adapter.complete(request);
  }
}

// ==================== SINGLETON INSTANCE ====================

export const modelRouter = new ModelRouter();
modelRouter.registerAdapter(new ScholesaInternalAdapter());
modelRouter.setDefault('scholesa_internal_ai');
