/**
 * AI Interaction Logger
 * 
 * Log everything you need to build your own training dataset:
 * - Request + response (with IDs)
 * - Context retrieved
 * - UI trigger
 * - Outcomes (student revised? passed? time to mastery?)
 * - Teacher feedback ("was this helpful?")
 * 
 * This is YOUR data vault for future model training
 */

import {
  collection,
  addDoc,
  updateDoc,
  doc,
  serverTimestamp,
  Timestamp
} from 'firebase/firestore';
import { db } from '@/src/firebase/client-init';
import type {
  ModelRequest,
  ModelResponse,
  TaskType,
  PolicyMode
} from './modelAdapter';
import type { AgeBand } from '@/src/types/schema';
import type { Role } from '@/schema';
import type { SupportedLocale } from '@/src/lib/i18n/config';

// ==================== TYPES ====================

export interface AIInteractionLog {
  // Identifiers (for linking outcomes)
  id?: string;
  learnerId: string;
  siteId: string;
  sessionId?: string;
  missionId?: string;
  missionAttemptId?: string;
  traceId: string;
  
  // Request details (YOUR schema, not vendor's)
  taskType: TaskType;
  gradeBand: AgeBand;
  policyMode: PolicyMode;
  targetLocale: SupportedLocale;
  role: Role;
  studentLevel: 'emerging' | 'proficient' | 'advanced';
  
  // What we sent (redacted)
  redactedQuestion: string;
  contextBlocksUsed: {
    type: string;
    id?: string;
    relevanceScore?: number;
  }[];
  
  // What we got back
  modelUsed: string;
  modelVersion: string;
  promptTemplateId: string;
  policyVersion: string;
  safetyOutcome: 'allowed' | 'blocked' | 'modified' | 'escalated';
  safetyReasonCode: string;
  toolCallIds: string[];
  response: string;
  tokensUsed: number;
  latencyMs: number;
  safetyFlags?: string[];
  
  // Where it was triggered
  uiContext: {
    screen: string; // 'ai_coach_popup', 'mission_workspace', 'reflection_journal'
    triggeredBy: 'student_click' | 'auto_suggestion' | 'educator_prompt';
  };
  
  // Redaction audit
  redactionApplied: boolean;
  redactionReplacements?: number; // Count of replacements
  redactionFlags?: string[]; // Potential PII that was flagged
  
  // Outcomes (filled in later)
  outcome?: {
    wasHelpful?: boolean; // Teacher/student thumbs up/down
    helpfulReason?: string; // Free text explanation
    studentRevised?: boolean; // Did they revise their work after?
    checkpointPassed?: boolean; // Did they pass next checkpoint?
    timeToMastery?: number; // Minutes from hint to mastery
    followUpNeeded?: boolean; // Did they ask again?
  };
  
  // Timestamps
  createdAt: Timestamp;
  updatedAt?: Timestamp;
}

// Firestore collection
export const aiInteractionLogsCollection = collection(db, 'aiInteractionLogs');

// ==================== LOGGER ====================

export class AIInteractionLogger {
  /**
   * Log an AI interaction
   */
  static async logInteraction(
    request: ModelRequest,
    response: ModelResponse,
    context: {
      learnerId: string;
      siteId: string;
      sessionId?: string;
      missionId?: string;
      missionAttemptId?: string;
      traceId: string;
      role: Role;
      targetLocale: SupportedLocale;
      uiScreen: string;
      triggeredBy: 'student_click' | 'auto_suggestion' | 'educator_prompt';
      redactedQuestion: string;
      redactionInfo: {
        wasRedacted: boolean;
        replacementCount: number;
        flags: string[];
      };
    }
  ): Promise<string> {
    const log: Omit<AIInteractionLog, 'id'> = {
      learnerId: context.learnerId,
      siteId: context.siteId,
      sessionId: context.sessionId,
      missionId: context.missionId,
      missionAttemptId: context.missionAttemptId || request.missionAttemptId,
      traceId: context.traceId,
      
      taskType: request.taskType,
      gradeBand: request.gradeBand,
      policyMode: request.policyMode,
      targetLocale: request.targetLocale,
      role: context.role,
      studentLevel: request.studentLevel,
      
      redactedQuestion: context.redactedQuestion,
      contextBlocksUsed: request.contextBlocks.map(block => ({
        type: block.type,
        id: block.id,
        relevanceScore: block.relevance
      })),
      
      modelUsed: response.modelUsed,
      modelVersion: response.modelVersion,
      promptTemplateId: response.promptTemplateId,
      policyVersion: response.policyVersion,
      safetyOutcome: response.safetyOutcome,
      safetyReasonCode: response.safetyReasonCode,
      toolCallIds: response.toolCallIds,
      response: response.answer,
      tokensUsed: response.tokensUsed,
      latencyMs: response.latencyMs,
      safetyFlags: response.safetyFlags,
      
      uiContext: {
        screen: context.uiScreen,
        triggeredBy: context.triggeredBy
      },
      
      redactionApplied: context.redactionInfo.wasRedacted,
      redactionReplacements: context.redactionInfo.replacementCount,
      redactionFlags: context.redactionInfo.flags.length > 0 ? context.redactionInfo.flags : undefined,
      
      createdAt: serverTimestamp() as Timestamp
    };
    
    const docRef = await addDoc(aiInteractionLogsCollection, log);
    return docRef.id;
  }
  
  /**
   * Update with outcome data
   */
  static async updateOutcome(
    logId: string,
    outcome: {
      wasHelpful?: boolean;
      helpfulReason?: string;
      studentRevised?: boolean;
      checkpointPassed?: boolean;
      timeToMastery?: number;
      followUpNeeded?: boolean;
    }
  ): Promise<void> {
    const logRef = doc(db, 'aiInteractionLogs', logId);
    await updateDoc(logRef, {
      outcome,
      updatedAt: serverTimestamp()
    });
  }
  
  /**
   * Export training dataset (de-identified)
   * Returns JSONL format for model training
   */
  static exportForTraining(logs: AIInteractionLog[]): string {
    const trainingData = logs
      .filter(log => log.outcome?.wasHelpful !== undefined) // Only labeled data
      .map(log => ({
        // Input
        task_type: log.taskType,
        grade_band: log.gradeBand,
        policy_mode: log.policyMode,
        target_locale: log.targetLocale,
        role: log.role,
        prompt_template_id: log.promptTemplateId,
        policy_version: log.policyVersion,
        student_level: log.studentLevel,
        question: log.redactedQuestion, // Already redacted
        context_blocks: log.contextBlocksUsed,
        
        // Output
        response: log.response,
        safety_outcome: log.safetyOutcome,
        safety_reason_code: log.safetyReasonCode,
        
        // Labels
        helpful: log.outcome?.wasHelpful,
        revised: log.outcome?.studentRevised,
        passed: log.outcome?.checkpointPassed,
        time_to_mastery_minutes: log.outcome?.timeToMastery,
        
        // Metadata
        trace_id: log.traceId,
        model_used: log.modelUsed,
        model_version: log.modelVersion,
        tokens: log.tokensUsed,
        latency_ms: log.latencyMs
      }));
    
    // JSONL format (one JSON object per line)
    return trainingData.map(item => JSON.stringify(item)).join('\n');
  }
}

// ==================== CONVENIENCE FUNCTIONS ====================

/**
 * Quick log for AI Coach interactions
 */
export async function logAICoachInteraction(
  request: ModelRequest,
  response: ModelResponse,
  context: {
    learnerId: string;
    siteId: string;
    sessionId?: string;
    missionId?: string;
    missionAttemptId?: string;
    traceId: string;
    role: Role;
    targetLocale: SupportedLocale;
    redactedQuestion: string;
    redactionInfo: {
      wasRedacted: boolean;
      replacementCount: number;
      flags: string[];
    };
  }
): Promise<string> {
  return AIInteractionLogger.logInteraction(request, response, {
    ...context,
    uiScreen: 'ai_coach_popup',
    triggeredBy: 'student_click'
  });
}

/**
 * Record student feedback on AI response
 */
export async function recordAIFeedback(
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
 * Record checkpoint outcome after AI help
 */
export async function recordCheckpointOutcome(
  logId: string,
  passed: boolean,
  timeToMastery: number
): Promise<void> {
  return AIInteractionLogger.updateOutcome(logId, {
    checkpointPassed: passed,
    timeToMastery
  });
}
