/**
 * Analytics Engine - Implements analytics.json spec
 * 
 * Features:
 * - Event tracking aligned with analytics.json spec
 * - Computed metrics (checkpoint_pass_rate, attempts_to_mastery, etc.)
 * - Insight rules (threshold-based, no ML required)
 * - Grade band policy integration
 * - Internal AI inference (no third-party AI API calls)
 */

import {
  collection,
  doc,
  addDoc,
  query,
  where,
  getDocs,
  Timestamp,
  getDoc,
  setDoc,
  serverTimestamp,
  orderBy,
  limit
} from 'firebase/firestore';
import { db } from '@/src/firebase/client-init';
import type { AgeBand } from '@/src/types/schema';

// ==================== TYPES FROM ANALYTICS.JSON ====================

export type MissionLevel = 'BRONZE' | 'SILVER' | 'GOLD' | 'BRIDGE';

export type ArtifactType = 'PHOTO' | 'VIDEO_SHORT' | 'DOC' | 'CODE' | 'AUDIO' | 'LINK';

export type ReflectionFormat = 'EMOJI' | 'TEXT_SHORT' | 'TEXT' | 'AUDIO_SHORT' | 'AUDIO' | 'VIDEO_SHORT';

export type TeamRole = 'FACILITATOR' | 'BUILDER' | 'TESTER' | 'REPORTER';

export type AIMode =
  | 'HINT_GUIDED'
  | 'QUESTIONS_ONLY_GUIDED'
  | 'HINT'
  | 'QUESTIONS_ONLY'
  | 'RUBRIC_CHECK_LITE'
  | 'RUBRIC_CHECK'
  | 'DEBUG_BY_QUESTIONS'
  | 'CRITIQUE_WITH_EVIDENCE';

// ==================== EVENT PAYLOADS ====================

export interface AnalyticsEvent {
  event_id: string;
  event_name: string;
  event_time: Timestamp;
  class_id: string;
  session_id?: string;
  student_id: string;
  team_id?: string;
  grade_band_id: AgeBand;
  app_version: string;
  device_type: string;
  source_screen: string;
}

export interface MissionSelectedEvent extends AnalyticsEvent {
  event_name: 'mission_selected';
  mission_id: string;
  level: MissionLevel;
  choice_set_id?: string;
  reason_tag?: string;
}

export interface SprintStartedEvent extends AnalyticsEvent {
  event_name: 'sprint_started';
  sprint_id: string;
  mission_id: string;
  planned_minutes: number;
  focus_goal_text?: string;
}

export interface SprintEndedEvent extends AnalyticsEvent {
  event_name: 'sprint_ended';
  sprint_id: string;
  mission_id: string;
  actual_minutes: number;
  end_reason?: string;
}

export interface CheckpointSubmittedEvent extends AnalyticsEvent {
  event_name: 'checkpoint_submitted';
  checkpoint_id: string;
  mission_id: string;
  skill_id: string;
  attempt_no: number;
  passed: boolean;
  misconception_tag?: string;
  time_spent_seconds?: number;
  evidence_artifact_id?: string;
}

export interface ArtifactUploadedEvent extends AnalyticsEvent {
  event_name: 'artifact_uploaded';
  artifact_id: string;
  mission_id: string;
  artifact_type: ArtifactType;
  linked_skill_ids?: string[];
  linked_concept_ids?: string[];
  file_size_bytes?: number;
  duration_seconds?: number;
  version_no?: number;
}

export interface ReflectionSubmittedEvent extends AnalyticsEvent {
  event_name: 'reflection_submitted';
  reflection_id: string;
  mission_id: string;
  format: ReflectionFormat;
  prompt_id: string;
  text_length?: number;
  self_rating_1_5?: number;
  next_step_tag?: string;
}

export interface RoleAssignedEvent extends AnalyticsEvent {
  event_name: 'role_assigned';
  team_id: string;
  role: TeamRole;
  rotation_index: number;
  assigned_by?: 'SYSTEM' | 'TEACHER' | 'STUDENT';
}

export interface RoleRotatedEvent extends AnalyticsEvent {
  event_name: 'role_rotated';
  team_id: string;
  from_role: TeamRole;
  to_role: TeamRole;
  rotation_index: number;
}

export interface AICoachUsedEvent extends AnalyticsEvent {
  event_name: 'ai_coach_used';
  interaction_id: string;
  mode: AIMode;
  turns: number;
  mission_id: string;
  topic_tag?: string;
  hint_count?: number;
}

export interface ExplainItBackSubmittedEvent extends AnalyticsEvent {
  event_name: 'explain_it_back_submitted';
  interaction_id: string;
  passed: boolean;
  format: ReflectionFormat;
  text_length?: number;
  rubric_score_0_3?: number;
}

export interface PeerFeedbackGivenEvent extends AnalyticsEvent {
  event_name: 'peer_feedback_given';
  feedback_id: string;
  to_student_id: string;
  mission_id: string;
  template_id?: string;
  length_chars?: number;
  kindness_flag?: boolean;
}

export type AnalyticsEventType =
  | MissionSelectedEvent
  | SprintStartedEvent
  | SprintEndedEvent
  | CheckpointSubmittedEvent
  | ArtifactUploadedEvent
  | ReflectionSubmittedEvent
  | RoleAssignedEvent
  | RoleRotatedEvent
  | AICoachUsedEvent
  | ExplainItBackSubmittedEvent
  | PeerFeedbackGivenEvent;

// ==================== COMPUTED METRICS ====================

export interface ComputedMetric {
  metric_id: string;
  class_id?: string;
  session_id?: string;
  mission_id?: string;
  skill_id?: string;
  value: number;
  computed_at: Timestamp;
}

export interface ChoiceDistribution {
  BRONZE: number;
  SILVER: number;
  GOLD: number;
  BRIDGE: number;
}

export interface SDTScore {
  autonomy: number | null;
  competence: number | null;
  belonging: number | null;
}

// ==================== INSIGHT RULES ====================

export interface InsightRule {
  id: string;
  triggered: boolean;
  recommendation: string;
  actions: string[];
  priority: 'high' | 'medium' | 'low';
  category: 'learning' | 'engagement' | 'collaboration' | 'ai_usage';
}

// ==================== ANALYTICS ENGINE ====================

export class AnalyticsEngine {
  /**
   * Track an analytics event (follows analytics.json spec)
   */
  static async trackEvent(event: AnalyticsEventType): Promise<string> {
    try {
      const docRef = await addDoc(collection(db, 'analyticsEvents'), {
        ...event,
        event_time: event.event_time || Timestamp.now(),
        app_version: process.env.NEXT_PUBLIC_APP_VERSION || '1.0.0',
        device_type: this.getDeviceType(),
      });
      
      return docRef.id;
    } catch (error) {
      if (!this.isExpectedWriteError(error)) {
        console.error('Failed to track analytics event:', error);
      }
      return 'error';
    }
  }
  
  /**
   * Compute checkpoint pass rate
   */
  static async computeCheckpointPassRate(
    classId: string,
    sessionId?: string,
    missionId?: string,
    skillId?: string
  ): Promise<number> {
    try {
      const q = query(
        collection(db, 'analyticsEvents'),
        where('event_name', '==', 'checkpoint_submitted'),
        where('class_id', '==', classId),
        ...(sessionId ? [where('session_id', '==', sessionId)] : []),
        ...(missionId ? [where('mission_id', '==', missionId)] : []),
        ...(skillId ? [where('skill_id', '==', skillId)] : [])
      );

      const snapshot = await getDocs(q);
      const events = snapshot.docs.map(doc => doc.data() as CheckpointSubmittedEvent);

      if (events.length === 0) return 0;

      const passes = events.filter(e => e.passed).length;
      return passes / events.length;
    } catch {
      return 0;
    }
  }
  
  /**
   * Compute attempts to mastery
   */
  static async computeAttemptsToMastery(
    classId: string,
    sessionId?: string,
    missionId?: string,
    skillId?: string
  ): Promise<number> {
    try {
      const q = query(
        collection(db, 'analyticsEvents'),
        where('event_name', '==', 'checkpoint_submitted'),
        where('class_id', '==', classId),
        ...(sessionId ? [where('session_id', '==', sessionId)] : []),
        ...(missionId ? [where('mission_id', '==', missionId)] : []),
        ...(skillId ? [where('skill_id', '==', skillId)] : [])
      );

      const snapshot = await getDocs(q);
      const events = snapshot.docs.map(doc => doc.data() as CheckpointSubmittedEvent);

      const studentAttempts: Record<string, number[]> = {};

      events.forEach(event => {
        if (!studentAttempts[event.student_id]) {
          studentAttempts[event.student_id] = [];
        }
        if (event.passed) {
          studentAttempts[event.student_id].push(event.attempt_no);
        }
      });

      const firstPassAttempts = Object.values(studentAttempts)
        .map(attempts => Math.min(...attempts))
        .filter(n => !isNaN(n));

      if (firstPassAttempts.length === 0) return 0;

      return firstPassAttempts.reduce((a, b) => a + b, 0) / firstPassAttempts.length;
    } catch {
      return 0;
    }
  }
  
  /**
   * Compute choice distribution (mission level selection)
   */
  static async computeChoiceDistribution(
    classId: string,
    sessionId?: string
  ): Promise<ChoiceDistribution> {
    try {
      const q = query(
        collection(db, 'analyticsEvents'),
        where('event_name', '==', 'mission_selected'),
        where('class_id', '==', classId),
        ...(sessionId ? [where('session_id', '==', sessionId)] : [])
      );

      const snapshot = await getDocs(q);
      const events = snapshot.docs.map(doc => doc.data() as MissionSelectedEvent);

      const distribution: ChoiceDistribution = {
        BRONZE: 0,
        SILVER: 0,
        GOLD: 0,
        BRIDGE: 0
      };

      events.forEach(event => {
        distribution[event.level]++;
      });

      const total = events.length || 1;
      return {
        BRONZE: distribution.BRONZE / total,
        SILVER: distribution.SILVER / total,
        GOLD: distribution.GOLD / total,
        BRIDGE: distribution.BRIDGE / total
      };
    } catch {
      return { BRONZE: 0, SILVER: 0, GOLD: 0, BRIDGE: 0 };
    }
  }
  
  /**
   * Compute hint dependency index
   */
  static async computeHintDependencyIndex(
    classId: string,
    sessionId?: string
  ): Promise<number> {
    try {
      const aiQuery = query(
        collection(db, 'analyticsEvents'),
        where('event_name', '==', 'ai_coach_used'),
        where('class_id', '==', classId),
        ...(sessionId ? [where('session_id', '==', sessionId)] : [])
      );

      const checkpointQuery = query(
        collection(db, 'analyticsEvents'),
        where('event_name', '==', 'checkpoint_submitted'),
        where('class_id', '==', classId),
        where('passed', '==', true),
        ...(sessionId ? [where('session_id', '==', sessionId)] : [])
      );

      const [aiSnapshot, checkpointSnapshot] = await Promise.all([
        getDocs(aiQuery),
        getDocs(checkpointQuery)
      ]);

      const totalTurns = aiSnapshot.docs
        .map(doc => (doc.data() as AICoachUsedEvent).turns)
        .reduce((a, b) => a + b, 0);

      const checkpointPasses = checkpointSnapshot.size;

      return checkpointPasses > 0 ? totalTurns / checkpointPasses : 0;
    } catch {
      return 0;
    }
  }
  
  /**
   * Compute explain-it-back compliance
   */
  static async computeExplainItBackCompliance(
    classId: string,
    sessionId?: string
  ): Promise<number> {
    try {
      const aiQuery = query(
        collection(db, 'analyticsEvents'),
        where('event_name', '==', 'ai_coach_used'),
        where('class_id', '==', classId),
        ...(sessionId ? [where('session_id', '==', sessionId)] : [])
      );

      const explainQuery = query(
        collection(db, 'analyticsEvents'),
        where('event_name', '==', 'explain_it_back_submitted'),
        where('class_id', '==', classId),
        ...(sessionId ? [where('session_id', '==', sessionId)] : [])
      );

      const [aiSnapshot, explainSnapshot] = await Promise.all([
        getDocs(aiQuery),
        getDocs(explainQuery)
      ]);

      const aiUsages = aiSnapshot.size;
      const explainSubmissions = explainSnapshot.size;

      return aiUsages > 0 ? explainSubmissions / aiUsages : 0;
    } catch {
      return 0;
    }
  }
  
  /**
   * Generate AI-powered insights using Scholesa internal inference.
   *
   * PRIVACY: Uses only in-process aggregated class-level metrics.
   * NO student names, IDs, individual records, or third-party AI APIs.
   */
  static async generateAIInsights(
    classId: string,
    sessionId?: string
  ): Promise<InsightRule[]> {
    const [
      passRate,
      attemptsToMastery,
      choiceDistribution,
      hintDependency,
      explainCompliance
    ] = await Promise.all([
      this.computeCheckpointPassRate(classId, sessionId),
      this.computeAttemptsToMastery(classId, sessionId),
      this.computeChoiceDistribution(classId, sessionId),
      this.computeHintDependencyIndex(classId, sessionId),
      this.computeExplainItBackCompliance(classId, sessionId)
    ]);
    const insights: InsightRule[] = [];

    if (passRate < 0.45) {
      insights.push({
        id: 'internal_pass_rate_low',
        triggered: true,
        recommendation: 'Checkpoint pass rates are low; tighten modeling and provide one worked example before independent attempts.',
        actions: ['add_teacher_modeling_block', 'enable_worked_example_before_checkpoint'],
        priority: 'high',
        category: 'learning',
      });
    }

    if (attemptsToMastery > 2.8) {
      insights.push({
        id: 'internal_attempts_to_mastery_high',
        triggered: true,
        recommendation: 'Learners need multiple retries; break checkpoints into smaller validation steps.',
        actions: ['split_checkpoint_into_micro_steps', 'add_mid_checkpoint_feedback'],
        priority: 'medium',
        category: 'learning',
      });
    }

    if (choiceDistribution.BRONZE > 0.55) {
      insights.push({
        id: 'internal_low_challenge_selection',
        triggered: true,
        recommendation: 'Mission selection is skewed toward low challenge; add confidence scaffolds and nudge more SILVER choices.',
        actions: ['default_to_silver_with_opt_down', 'show_recent_mastery_badges_before_choice'],
        priority: 'medium',
        category: 'engagement',
      });
    } else if (choiceDistribution.GOLD < 0.10 && passRate > 0.7) {
      insights.push({
        id: 'internal_under_challenged_cohort',
        triggered: true,
        recommendation: 'Class is performing well with low GOLD uptake; introduce extension pathways for advanced learners.',
        actions: ['enable_gold_extension_prompts', 'assign_peer_teaching_challenges'],
        priority: 'low',
        category: 'learning',
      });
    }

    if (hintDependency > 3.0) {
      insights.push({
        id: 'internal_hint_dependency_high',
        triggered: true,
        recommendation: 'AI hint dependency is high; gate additional hints behind explain-it-back evidence.',
        actions: ['gate_hints_on_explain_it_back', 'reduce_max_hint_turns'],
        priority: 'high',
        category: 'ai_usage',
      });
    } else if (hintDependency < 0.4 && passRate < 0.5) {
      insights.push({
        id: 'internal_ai_support_underused',
        triggered: true,
        recommendation: 'AI support appears underused while outcomes are weak; prompt strategic hint usage at first failure.',
        actions: ['suggest_hint_after_first_failed_attempt', 'surface_ai_questions_only_mode'],
        priority: 'medium',
        category: 'ai_usage',
      });
    }

    if (explainCompliance < 0.55) {
      insights.push({
        id: 'internal_explain_back_low',
        triggered: true,
        recommendation: 'Explain-it-back completion is low; add sentence stems and require short verbal justification before final submit.',
        actions: ['enable_explain_back_sentence_stems', 'require_explain_back_pre_submit'],
        priority: 'high',
        category: 'collaboration',
      });
    }

    if (insights.length === 0) {
      insights.push({
        id: 'internal_stable_performance',
        triggered: true,
        recommendation: 'Current metrics are stable; continue current pacing and monitor AI scaffolding drift weekly.',
        actions: ['keep_current_pacing', 'schedule_weekly_ai_usage_review'],
        priority: 'low',
        category: 'learning',
      });
    }

    return insights.slice(0, 5);
  }
  
  /**
   * Evaluate threshold-based insight rules (from analytics.json)
   */
  static async evaluateInsightRules(
    classId: string,
    sessionId?: string
  ): Promise<InsightRule[]> {
    const insights: InsightRule[] = [];
    
    const [
      passRate,
      choiceDistribution,
      hintDependency,
      explainCompliance
    ] = await Promise.all([
      this.computeCheckpointPassRate(classId, sessionId),
      this.computeChoiceDistribution(classId, sessionId),
      this.computeHintDependencyIndex(classId, sessionId),
      this.computeExplainItBackCompliance(classId, sessionId)
    ]);
    
    // Rule: shallow_understanding_explain_it_back_low
    if (explainCompliance < 0.50) {
      insights.push({
        id: 'shallow_understanding_explain_it_back_low',
        triggered: true,
        recommendation: 'Switch to 2-minute teacher model + sentence stems; keep AI in questions-only',
        actions: ['set_ai_mode_questions_only', 'enable_sentence_stems'],
        priority: 'high',
        category: 'ai_usage'
      });
    }
    
    // Rule: gold_mismatch_need_bridge
    if (choiceDistribution.GOLD > 0.35 && passRate < 0.50) {
      insights.push({
        id: 'gold_mismatch_need_bridge',
        triggered: true,
        recommendation: 'Insert BRIDGE mission and improve "done looks like…" criteria',
        actions: ['enable_bridge_mission', 'require_done_criteria_ack'],
        priority: 'high',
        category: 'learning'
      });
    }
    
    // Rule: ai_overhelping
    if (hintDependency > 3.0 && explainCompliance < 0.80) {
      insights.push({
        id: 'ai_overhelping',
        triggered: true,
        recommendation: 'Require explain-it-back before showing further hints; reduce hint mode availability',
        actions: ['gate_hints_on_explain_it_back', 'limit_ai_modes'],
        priority: 'medium',
        category: 'ai_usage'
      });
    }
    
    return insights;
  }
  
  /**
   * Get combined insights (threshold + AI-powered)
   */
  static async getInsights(classId: string, sessionId?: string): Promise<InsightRule[]> {
    const [thresholdInsights, aiInsights] = await Promise.all([
      this.evaluateInsightRules(classId, sessionId),
      this.generateAIInsights(classId, sessionId)
    ]);
    
    return [...thresholdInsights, ...aiInsights];
  }
  
  // ===== UTILITY FUNCTIONS =====
  
  private static getDeviceType(): string {
    if (typeof window === 'undefined') return 'server';
    
    const ua = navigator.userAgent;
    if (/(tablet|ipad|playbook|silk)|(android(?!.*mobi))/i.test(ua)) {
      return 'tablet';
    }
    if (/Mobile|Android|iP(hone|od)|IEMobile|BlackBerry|Kindle|Silk-Accelerated|(hpw|web)OS|Opera M(obi|ini)/.test(ua)) {
      return 'mobile';
    }
    return 'desktop';
  }

  private static isExpectedWriteError(error: unknown): boolean {
    const code = (error as { code?: string } | null)?.code;
    return code === 'permission-denied' || code === 'invalid-argument';
  }

}

// ===== CONVENIENCE EXPORTS =====

export const trackEvent = AnalyticsEngine.trackEvent.bind(AnalyticsEngine);
export const computeCheckpointPassRate = AnalyticsEngine.computeCheckpointPassRate.bind(AnalyticsEngine);
export const computeAttemptsToMastery = AnalyticsEngine.computeAttemptsToMastery.bind(AnalyticsEngine);
export const computeChoiceDistribution = AnalyticsEngine.computeChoiceDistribution.bind(AnalyticsEngine);
export const computeHintDependencyIndex = AnalyticsEngine.computeHintDependencyIndex.bind(AnalyticsEngine);
export const computeExplainItBackCompliance = AnalyticsEngine.computeExplainItBackCompliance.bind(AnalyticsEngine);
export const getInsights = AnalyticsEngine.getInsights.bind(AnalyticsEngine);
export const generateAIInsights = AnalyticsEngine.generateAIInsights.bind(AnalyticsEngine);
