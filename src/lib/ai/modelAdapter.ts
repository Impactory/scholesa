/**
 * Model Adapter Layer
 *
 * Scholesa is the system of record and the AI runtime.
 * This adapter is intentionally internal-only: no third-party AI APIs.
 */

import type { AgeBand } from '@/src/types/schema';
import type { SupportedLocale } from '@/src/lib/i18n/config';
import type { Role } from '@/schema';
import { buildLocaleHeaders } from '@/src/lib/i18n/localeHeaders';

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
  localeInstruction: string;
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

export function buildLocaleInstruction(locale: SupportedLocale): string {
  return `Respond strictly in locale ${locale}. Do not switch languages unless the learner explicitly asks for translation help.`;
}

// ==================== INTERNAL ADAPTER ====================

function resolveAiEndpoint(): string {
  if (typeof window !== 'undefined') {
    return '/api/ai/complete';
  }

  const explicitBase = process.env.NEXT_PUBLIC_APP_URL?.trim();
  if (explicitBase) {
    return `${explicitBase.replace(/\/$/, '')}/api/ai/complete`;
  }

  const vercelUrl = process.env.VERCEL_URL?.trim();
  if (vercelUrl) {
    return `https://${vercelUrl.replace(/\/$/, '')}/api/ai/complete`;
  }

  throw new Error('Unable to resolve AI completion endpoint outside the browser');
}

export class ScholesaServerInferenceAdapter implements ModelAdapter {
  name = 'scholesa_internal_ai';

  async complete(request: ModelRequest): Promise<ModelResponse> {
    const endpoint = resolveAiEndpoint();
    const startedAt = Date.now();
    const response = await fetch(endpoint, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...buildLocaleHeaders(request.targetLocale),
      },
      credentials: 'include',
      cache: 'no-store',
      body: JSON.stringify(request),
    });

    if (!response.ok) {
      throw new Error(`ai_complete_failed_${response.status}`);
    }

    const payload = await response.json() as ModelResponse;
    return {
      ...payload,
      latencyMs: payload.latencyMs || (Date.now() - startedAt),
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
modelRouter.registerAdapter(new ScholesaServerInferenceAdapter());
modelRouter.setDefault('scholesa_internal_ai');
