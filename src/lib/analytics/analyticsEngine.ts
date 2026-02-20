/**
 * Analytics Engine - Implements analytics.json spec
 * 
 * Features:
 * - Event tracking aligned with analytics.json spec
 * - Computed metrics (checkpoint_pass_rate, attempts_to_mastery, etc.)
 * - Insight rules (threshold-based, no ML required)
 * - Grade band policy integration
 * - Gemini API integration for AI-powered insights
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
  autonomy: number;
  competence: number;
  belonging: number;
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
   * Generate AI-powered insights using Gemini
   * 
   * PRIVACY: Only sends aggregated class-level metrics (percentages, averages).
   * NO student names, IDs, or individual student data sent to Gemini.
   */
  static async generateAIInsights(
    classId: string,
    sessionId?: string
  ): Promise<InsightRule[]> {
    const geminiKey = process.env.NEXT_PUBLIC_GEMINI_API_KEY;
    if (!geminiKey) {
      console.warn('Gemini API key not configured, skipping AI insights');
      return [];
    }
    
    // Gather metrics (ALL AGGREGATED - NO INDIVIDUAL STUDENT DATA)
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
    
    // PRIVACY: Build prompt with ONLY aggregated metrics - NO class IDs, student data, or PII
    const prompt = `
You are an educational analytics expert. Analyze the following class metrics and provide actionable insights for teachers.

Class Metrics (AGGREGATED DATA ONLY):
- Checkpoint Pass Rate: ${(passRate * 100).toFixed(1)}%
- Average Attempts to Mastery: ${attemptsToMastery.toFixed(1)}
- Mission Choice Distribution:
  * Bronze (Easy): ${(choiceDistribution.BRONZE * 100).toFixed(1)}%
  * Silver (Medium): ${(choiceDistribution.SILVER * 100).toFixed(1)}%
  * Gold (Hard): ${(choiceDistribution.GOLD * 100).toFixed(1)}%
  * Bridge (Scaffolded): ${(choiceDistribution.BRIDGE * 100).toFixed(1)}%
- Hint Dependency Index: ${hintDependency.toFixed(2)} (AI turns per checkpoint pass)
- Explain-it-Back Compliance: ${(explainCompliance * 100).toFixed(1)}%

Provide 3-5 specific, actionable insights in JSON format:
[
  {
    "id": "unique_insight_id",
    "recommendation": "Clear, actionable recommendation",
    "actions": ["specific_action_1", "specific_action_2"],
    "priority": "high|medium|low",
    "category": "learning|engagement|collaboration|ai_usage"
  }
]

Focus on:
1. Student autonomy and choice patterns
2. Learning effectiveness (pass rates, attempts)
3. AI usage patterns (over-reliance or under-utilization)
4. Opportunities for differentiation

Return only valid JSON, no additional text.
`;
    
    try {
      const response = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${geminiKey}`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            contents: [{
              parts: [{ text: prompt }]
            }],
            generationConfig: {
              temperature: 0.7,
              maxOutputTokens: 2048
            }
          })
        }
      );
      
      if (!response.ok) {
        throw new Error(`Gemini API error: ${response.statusText}`);
      }
      
      const data = await response.json();
      const text = data.candidates?.[0]?.content?.parts?.[0]?.text || '[]';
      
      // Parse JSON from response
      const jsonMatch = text.match(/\[[\s\S]*\]/);
      if (jsonMatch) {
        const insights: InsightRule[] = JSON.parse(jsonMatch[0]);
        return insights.map(insight => ({
          ...insight,
          triggered: true
        }));
      }
      
      return [];
    } catch (error) {
      if (!this.isExpectedExternalAIError(error)) {
        console.error('Failed to generate AI insights:', error);
      }
      return [];
    }
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

  private static isExpectedExternalAIError(error: unknown): boolean {
    const message = (error as { message?: string } | null)?.message ?? '';
    return message.includes('Gemini API error: Bad Request');
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
