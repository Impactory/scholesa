/**
 * Integrated AI Service
 * 
 * Your app is the system of record. AI is just a stateless reasoning service.
 * 
 * Flow:
 * 1. Get student question
 * 2. Redact PII (your redaction service)
 * 3. Retrieve context (your vector store)
 * 4. Build request (your schema)
 * 5. Call model (swappable adapter)
 * 6. Log compliance telemetry (analytics-only, no training)
 * 7. Return response
 */

import { modelRouter, type TaskType, type PolicyMode, type ModelRequest, type ModelResponse, type ContextBlock } from './modelAdapter';
import { RedactionService, redactStudentQuestion } from './redactionService';
import { RetrievalService, getHintContext, getRubricCheckContext } from './retrievalService';
import { AIInteractionLogger, logAICoachInteraction } from './interactionLogger';
import { getPolicyForGrade } from '@/src/lib/policies/gradeBandPolicy';
import type { AgeBand } from '@/src/types/schema';
import type { Role } from '@/schema';
import { normalizeLocale, type SupportedLocale } from '@/src/lib/i18n/config';
import {
  evaluateGuardrailInput,
  evaluateGuardrailOutput,
  languageLooksCompatible,
  localizedRefusal,
  localizedTutorFallback,
  policyVersion,
  type SafetyOutcome,
} from './multilingualGuardrails';

// ==================== TYPES ====================

export interface AIServiceRequest {
  // Student context (minimal)
  learnerId: string;
  studentName: string;
  siteId: string;
  grade: number;
  studentLevel: 'emerging' | 'proficient' | 'advanced';
  
  // Mission context
  sessionId?: string;
  missionId?: string;
  
  // The actual request
  taskType: TaskType;
  question: string;
  
  // Optional
  preferredModel?: 'scholesa_internal_ai';
  targetLocale?: SupportedLocale | string;
  role?: Role;
  missionAttemptId?: string;
}

export interface AIServiceResponse {
  answer: string;
  steps?: string[];
  hints?: string[];
  followUpQuestions?: string[];
  citations?: {
    type: string;
    snippet: string;
  }[];
  
  // Metadata
  modelUsed: string;
  modelVersion: string;
  logId: string; // For tracking outcomes
  promptTemplateId: string;
  policyVersion: string;
  safetyOutcome: SafetyOutcome;
  safetyReasonCode: string;
  toolCallIds: string[];
  targetLocale: SupportedLocale;
  gradeBand: AgeBand;
  traceId: string;
  missionAttemptId?: string;
}

// ==================== INTEGRATED AI SERVICE ====================

export class AIService {
  /**
   * Main entry point for all AI interactions
   */
  static async request(req: AIServiceRequest): Promise<AIServiceResponse> {
    const startTime = Date.now();
    const targetLocale = normalizeLocale(req.targetLocale);
    const role = req.role || 'learner';
    const traceId = this.createTraceId();
    const missionAttemptId = req.missionAttemptId || req.missionId;

    try {
      // 1. Get policy for age band
      const policy = getPolicyForGrade(req.grade);
      const policyMode: PolicyMode = this.getPolicyMode(req.grade);
      const gradeBand: AgeBand = this.getAgeBand(req.grade);
      const promptTemplateId = this.getPromptTemplateId(req.taskType, policyMode);
      const policyVersionTag = policyVersion();
      
      // 2. Redact PII from question
      const redactionResult = redactStudentQuestion(
        req.question,
        req.studentName,
        policyMode
      );
      
      if (redactionResult.flagged.length > 0) {
        console.warn('Redaction flags:', redactionResult.flagged);
      }

      const modelRequest: ModelRequest = {
        taskType: req.taskType,
        gradeBand,
        targetLocale,
        role,
        siteId: req.siteId,
        learnerId: req.learnerId,
        traceId,
        promptTemplateId,
        policyVersion: policyVersionTag,
        policyMode,
        missionAttemptId,
        studentLevel: req.studentLevel,
        studentQuestion: redactionResult.redacted,
        contextBlocks: [],
        rubricId: req.missionId ? `rubric_${req.missionId}` : undefined,
        safetyConstraints: {
          blockHarmfulContent: true,
          requireChildSafe: req.grade <= 8,
          noDirectAnswers: policy.aiCoach.explainBackRequired,
          explainBackRequired: policy.aiCoach.explainBackRequired,
          maxTokens: this.getMaxTokens(req.grade)
        },
        responseFormat: {
          type: this.getResponseFormat(req.taskType),
          includeFollowUp: true,
          includeCitations: true
        }
      };

      // 3. Input guardrails (multilingual)
      const inputDecision = evaluateGuardrailInput(redactionResult.redacted, targetLocale);
      let modelResponse: ModelResponse;

      if (inputDecision.blocked) {
        modelResponse = {
          answer: inputDecision.localizedMessage,
          modelUsed: 'guardrail-blocked',
          modelVersion: 'guardrail-blocked',
          promptTemplateId,
          policyVersion: inputDecision.policyVersion,
          safetyOutcome: inputDecision.safetyOutcome,
          safetyReasonCode: inputDecision.safetyReasonCode,
          toolCallIds: inputDecision.toolCallIds,
          targetLocale,
          gradeBand,
          traceId,
          missionAttemptId,
          tokensUsed: 0,
          latencyMs: Date.now() - startTime,
        };
      } else {
        // 4. Retrieve relevant context from YOUR stores
        const rawContextBlocks = await this.getContextForTask(
          req.taskType,
          redactionResult.redacted,
          req.learnerId,
          req.missionId || '',
          gradeBand
        );
        modelRequest.contextBlocks = this.sanitizeContextBlocks(
          rawContextBlocks,
          req.studentName,
          policyMode
        );

        // 5. Call model (swappable vendor)
        modelResponse = await modelRouter.complete(
          modelRequest,
          req.preferredModel
        );

        // 6. Output guardrails (multilingual)
        const outputDecision = evaluateGuardrailOutput(modelResponse.answer, targetLocale);
        if (outputDecision.blocked) {
          modelResponse = {
            ...modelResponse,
            answer: outputDecision.localizedMessage,
            policyVersion: outputDecision.policyVersion,
            safetyOutcome: outputDecision.safetyOutcome,
            safetyReasonCode: outputDecision.safetyReasonCode,
            toolCallIds: outputDecision.toolCallIds,
          };
        } else if (!languageLooksCompatible(modelResponse.answer, targetLocale)) {
          modelResponse = {
            ...modelResponse,
            answer: localizedTutorFallback(targetLocale),
            safetyOutcome: 'modified',
            safetyReasonCode: 'output_language_mismatch',
            toolCallIds: [],
            policyVersion: policyVersionTag,
          };
        } else {
          modelResponse = {
            ...modelResponse,
            safetyOutcome: modelResponse.safetyOutcome || 'allowed',
            safetyReasonCode: modelResponse.safetyReasonCode || 'none',
            policyVersion: modelResponse.policyVersion || policyVersionTag,
            toolCallIds: modelResponse.toolCallIds || [],
          };
        }

        const sanitizedResponse = this.sanitizeModelResponse(
          modelResponse,
          req.studentName,
          policyMode
        );
        modelResponse = sanitizedResponse.response;
        if (sanitizedResponse.wasModified) {
          modelResponse = {
            ...modelResponse,
            safetyOutcome: 'modified',
            safetyReasonCode: 'output_pii_redacted',
            policyVersion: policyVersionTag,
          };
        }
      }

      modelResponse = {
        ...modelResponse,
        targetLocale,
        gradeBand,
        traceId,
        missionAttemptId,
        promptTemplateId,
        policyVersion: modelResponse.policyVersion || policyVersionTag,
      };
      
      // 7. Log analytics-only interaction telemetry (no training usage)
      const logId = await logAICoachInteraction(
        modelRequest,
        modelResponse,
        {
          learnerId: req.learnerId,
          siteId: req.siteId,
          sessionId: req.sessionId,
          missionId: req.missionId,
          missionAttemptId,
          traceId,
          role,
          targetLocale,
          redactedQuestion: redactionResult.redacted,
          redactionInfo: {
            wasRedacted: redactionResult.replacements.size > 0,
            replacementCount: redactionResult.replacements.size,
            flags: redactionResult.flagged
          }
        }
      );
      
      // 8. Return response
      return {
        answer: modelResponse.answer,
        steps: modelResponse.steps,
        hints: modelResponse.hints,
        followUpQuestions: modelResponse.followUpQuestions,
        citations: modelResponse.citations?.map(c => ({
          type: modelRequest.contextBlocks.find(b => b.id === c.contextBlockId)?.type || 'unknown',
          snippet: c.snippet
        })),
        modelUsed: modelResponse.modelUsed,
        modelVersion: modelResponse.modelVersion,
        logId,
        promptTemplateId: modelResponse.promptTemplateId,
        policyVersion: modelResponse.policyVersion,
        safetyOutcome: modelResponse.safetyOutcome,
        safetyReasonCode: modelResponse.safetyReasonCode,
        toolCallIds: modelResponse.toolCallIds,
        targetLocale: modelResponse.targetLocale,
        gradeBand: modelResponse.gradeBand,
        traceId: modelResponse.traceId,
        missionAttemptId: modelResponse.missionAttemptId,
      };
      
    } catch (error) {
      console.error('AI Service error:', error);
      
      // Fallback response (don't break the app)
      const gradeBand: AgeBand = this.getAgeBand(req.grade);
      const fallbackPolicyVersion = policyVersion();
      return {
        answer: localizedTutorFallback(targetLocale),
        modelUsed: 'error_fallback',
        modelVersion: 'error_fallback',
        logId: 'error',
        promptTemplateId: this.getPromptTemplateId(req.taskType, this.getPolicyMode(req.grade)),
        policyVersion: fallbackPolicyVersion,
        safetyOutcome: 'escalated',
        safetyReasonCode: 'service_error',
        toolCallIds: [],
        targetLocale,
        gradeBand,
        traceId,
        missionAttemptId,
      };
    }
  }
  
  /**
   * Record feedback on AI response quality.
   */
  static async recordFeedback(
    logId: string,
    wasHelpful: boolean,
    reason?: string
  ): Promise<void> {
    return AIInteractionLogger.updateOutcome(logId, {
      wasHelpful,
      helpfulReason: reason
    });
  }
  
  /**
   * Record outcome after AI help (checkpoint passed, etc.)
   */
  static async recordOutcome(
    logId: string,
    outcome: {
      studentRevised?: boolean;
      checkpointPassed?: boolean;
      timeToMastery?: number;
    }
  ): Promise<void> {
    return AIInteractionLogger.updateOutcome(logId, outcome);
  }
  
  // ===== PRIVATE HELPERS =====

  private static createTraceId(): string {
    const random = Math.random().toString(36).slice(2, 10);
    return `ai_${Date.now()}_${random}`;
  }

  private static getPromptTemplateId(taskType: TaskType, policyMode: PolicyMode): string {
    return `coach.${taskType}.${policyMode}.v1`;
  }
  
  private static async getContextForTask(
    taskType: TaskType,
    question: string,
    learnerId: string,
    missionId: string,
    gradeBand: AgeBand
  ) {
    switch (taskType) {
      case 'hint_generation':
      case 'debug_assistance':
      case 'explain_concept':
        return getHintContext(question, learnerId, missionId, gradeBand);
        
      case 'rubric_check':
      case 'critique_feedback':
        return getRubricCheckContext(question, missionId, gradeBand);
        
      default:
        return RetrievalService.retrieve({
          query: question,
          gradeBand,
          missionId,
          learnerId,
          topK: 5
        });
    }
  }
  
  private static getPolicyMode(grade: number): PolicyMode {
    if (grade <= 3) return 'k3_safe';
    if (grade <= 6) return 'grades_4_6';
    if (grade <= 9) return 'grades_7_9';
    return 'grades_10_12';
  }
  
  private static getAgeBand(grade: number): AgeBand {
    if (grade <= 3) return 'grades_1_3';
    if (grade <= 6) return 'grades_4_6';
    if (grade <= 9) return 'grades_7_9';
    return 'grades_10_12';
  }
  
  private static getMaxTokens(grade: number): number {
    // Younger = shorter responses
    if (grade <= 3) return 150;
    if (grade <= 6) return 300;
    if (grade <= 9) return 500;
    return 800;
  }
  
  private static getResponseFormat(taskType: TaskType): 'hint' | 'steps' | 'explanation' | 'questions' | 'feedback' {
    const formatMap: Record<TaskType, 'hint' | 'steps' | 'explanation' | 'questions' | 'feedback'> = {
      hint_generation: 'hint',
      rubric_check: 'feedback',
      debug_assistance: 'questions',
      critique_feedback: 'feedback',
      explain_concept: 'explanation',
      reflection_prompt: 'questions'
    };
    
    return formatMap[taskType] || 'hint';
  }

  private static sanitizeContextBlocks(
    blocks: ContextBlock[],
    studentName: string,
    policyMode: PolicyMode
  ): ContextBlock[] {
    return blocks.map((block) => ({
      type: block.type,
      id: block.id,
      relevance: block.relevance,
      content: this.redactText(block.content, studentName, policyMode, 220).text,
    }));
  }

  private static sanitizeModelResponse(
    response: ModelResponse,
    studentName: string,
    policyMode: PolicyMode
  ): { response: ModelResponse; wasModified: boolean } {
    let wasModified = false;
    const sanitize = (value?: string, maxLength = 280): string | undefined => {
      if (!value) return value;
      const redacted = this.redactText(value, studentName, policyMode, maxLength);
      if (redacted.wasModified) {
        wasModified = true;
      }
      return redacted.text;
    };

    return {
      response: {
        ...response,
        answer: sanitize(response.answer, 420) || response.answer,
        steps: response.steps?.map((step) => sanitize(step, 180) || step),
        hints: response.hints?.map((hint) => sanitize(hint, 180) || hint),
        followUpQuestions: response.followUpQuestions?.map((question) => sanitize(question, 180) || question),
        citations: response.citations?.map((citation) => ({
          ...citation,
          snippet: sanitize(citation.snippet, 140) || citation.snippet,
        })),
      },
      wasModified,
    };
  }

  private static redactText(
    text: string,
    studentName: string,
    policyMode: PolicyMode,
    maxLength: number
  ): { text: string; wasModified: boolean } {
    const result = RedactionService.redact(
      text,
      RedactionService.getConfigForPolicy(policyMode),
      {
        studentNames: [studentName],
      }
    );
    const normalized = result.redacted.replace(/\s+/g, ' ').trim();
    const limited = normalized.length > maxLength
      ? `${normalized.slice(0, maxLength - 1)}...`
      : normalized;
    return {
      text: limited,
      wasModified: limited !== text,
    };
  }
}

// ==================== CONVENIENCE FUNCTIONS ====================

/**
 * Get a hint for student
 */
export async function getAIHint(
  learnerId: string,
  studentName: string,
  siteId: string,
  grade: number,
  question: string,
  options: {
    missionId?: string;
    sessionId?: string;
    studentLevel?: 'emerging' | 'proficient' | 'advanced';
    targetLocale?: SupportedLocale | string;
    role?: Role;
    missionAttemptId?: string;
  }
): Promise<AIServiceResponse> {
  return AIService.request({
    learnerId,
    studentName,
    siteId,
    grade,
    studentLevel: options.studentLevel || 'proficient',
    sessionId: options.sessionId,
    missionId: options.missionId,
    missionAttemptId: options.missionAttemptId,
    targetLocale: options.targetLocale,
    role: options.role,
    taskType: 'hint_generation',
    question
  });
}

/**
 * Check student work against rubric
 */
export async function checkAgainstRubric(
  learnerId: string,
  studentName: string,
  siteId: string,
  grade: number,
  workDescription: string,
  options: {
    missionId: string;
    sessionId?: string;
    studentLevel?: 'emerging' | 'proficient' | 'advanced';
    targetLocale?: SupportedLocale | string;
    role?: Role;
    missionAttemptId?: string;
  }
): Promise<AIServiceResponse> {
  return AIService.request({
    learnerId,
    studentName,
    siteId,
    grade,
    studentLevel: options.studentLevel || 'proficient',
    sessionId: options.sessionId,
    missionId: options.missionId,
    missionAttemptId: options.missionAttemptId,
    targetLocale: options.targetLocale,
    role: options.role,
    taskType: 'rubric_check',
    question: workDescription
  });
}

/**
 * Help debug code/project
 */
export async function getDebugHelp(
  learnerId: string,
  studentName: string,
  siteId: string,
  grade: number,
  problem: string,
  options: {
    missionId?: string;
    sessionId?: string;
    studentLevel?: 'emerging' | 'proficient' | 'advanced';
    targetLocale?: SupportedLocale | string;
    role?: Role;
    missionAttemptId?: string;
  }
): Promise<AIServiceResponse> {
  return AIService.request({
    learnerId,
    studentName,
    siteId,
    grade,
    studentLevel: options.studentLevel || 'proficient',
    sessionId: options.sessionId,
    missionId: options.missionId,
    missionAttemptId: options.missionAttemptId,
    targetLocale: options.targetLocale,
    role: options.role,
    taskType: 'debug_assistance',
    question: problem
  });
}
