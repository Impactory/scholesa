/**
 * SDT Telemetry System
 * 
 * Tracks learner behaviors to build intelligence around motivation patterns
 * - Proof-of-learning submission rate
 * - Checkpoint pass/revision rate
 * - Peer feedback frequency
 * - Choice distribution (autonomy signals)
 * - Time-on-task patterns
 * - Age-band specific metrics
 */

import {
  doc,
  updateDoc,
  increment,
  serverTimestamp,
  Timestamp
} from 'firebase/firestore';
import { db } from '@/src/firebase/client-init';
import type { AgeBand } from '@/src/types/schema';
import { getAgeBandFromGrade } from '@/src/lib/policies/gradeBandPolicy';
import { TelemetryService, type TelemetryCategory, type TelemetryEvent as CanonicalTelemetryEvent } from '@/src/lib/telemetry/telemetryService';

// ==================== TYPES ====================

export interface TelemetryEvent {
  eventType: TelemetryEventType;
  learnerId: string;
  siteId: string;
  grade: number;
  ageBand: AgeBand;
  sessionId?: string;
  missionId?: string;
  timestamp: Timestamp;
  metadata: Record<string, unknown>;
}

export type TelemetryEventType =
  // Autonomy signals
  | 'mission_browsed'
  | 'mission_selected'
  | 'mission_switched'
  | 'goal_set'
  | 'interest_updated'
  // Competence signals
  | 'evidence_submitted'
  | 'evidence_revised'
  | 'checkpoint_attempted'
  | 'checkpoint_passed'
  | 'checkpoint_failed'
  | 'skill_proven'
  | 'rubric_viewed'
  // Belonging signals
  | 'showcase_submitted'
  | 'recognition_given'
  | 'recognition_received'
  | 'peer_feedback_given'
  | 'peer_feedback_received'
  | 'crew_joined'
  // Reflection signals
  | 'reflection_submitted'
  | 'effort_rated'
  | 'enjoyment_rated'
  // AI Coach signals
  | 'ai_coach_used'
  | 'explain_back_submitted'
  // Time signals
  | 'session_started'
  | 'session_resumed'
  | 'session_paused'
  | 'session_completed';

export interface MotivationMetrics {
  // Autonomy metrics
  choiceDiversity: number; // 0-1, how varied are their choices
  missionSwitchRate: number; // switches per session
  goalAlignmentScore: number; // % missions aligned with stated goals
  
  // Competence metrics
  proofSubmissionRate: number; // submissions per week
  firstTimeSuccessRate: number; // % checkpoints passed without revision
  revisionPersistence: number; // avg attempts before passing
  skillMasteryRate: number; // skills proven per week
  
  // Belonging metrics
  feedbackGivingRate: number; // peer feedbacks per week
  recognitionReceived: number; // shout-outs received
  crewParticipation: number; // % of crew sessions attended
  
  // Reflection metrics
  reflectionConsistency: number; // % sessions with reflection
  effortTrend: number; // avg change in effort rating over time
  enjoymentTrend: number; // avg change in enjoyment rating
  
  // Time metrics
  avgSessionDuration: number; // minutes
  sessionCompletionRate: number; // % started sessions completed
  optimalTimeOfDay: string; // when they're most engaged
}

export interface MotivationInsight {
  type: 'strength' | 'opportunity' | 'nudge';
  category: 'autonomy' | 'competence' | 'belonging';
  message: string;
  suggestedAction?: string;
  confidence: number; // 0-1
}

// ==================== TELEMETRY TRACKING ====================

class SDTTelemetry {
  /**
   * Track an event
   */
  async trackEvent(event: Omit<TelemetryEvent, 'timestamp' | 'ageBand'>): Promise<void> {
    try {
      const ageBand = getAgeBandFromGrade(event.grade);

      await TelemetryService.track({
        event: this.mapEventType(event.eventType),
        category: this.mapEventCategory(event.eventType),
        userId: event.learnerId,
        userRole: 'learner',
        siteId: event.siteId,
        grade: event.grade,
        ageBand,
        sessionId: event.sessionId,
        missionId: event.missionId,
        metadata: {
          ...event.metadata,
          sdtEventType: event.eventType
        }
      });

      // Update real-time aggregates
      await this.updateAggregates(event.learnerId, event.siteId, event.eventType);
    } catch (error) {
      console.error('Telemetry tracking error:', error);
      // Don't throw - telemetry failures should not break app
    }
  }

  private mapEventType(eventType: TelemetryEventType): CanonicalTelemetryEvent {
    const map: Record<string, CanonicalTelemetryEvent> = {
      mission_browsed: 'mission_browsed',
      mission_selected: 'mission_selected',
      mission_switched: 'mission_variant_chosen',
      goal_set: 'goal_set',
      interest_updated: 'interest_profile_updated',
      evidence_submitted: 'artifact_submitted',
      evidence_revised: 'artifact_revised',
      checkpoint_attempted: 'checkpoint_attempted',
      checkpoint_passed: 'checkpoint_passed',
      checkpoint_failed: 'checkpoint_failed',
      skill_proven: 'skill_proven',
      rubric_viewed: 'rubric_viewed',
      showcase_submitted: 'showcase_submitted',
      recognition_given: 'recognition_given',
      recognition_received: 'recognition_received',
      peer_feedback_given: 'peer_feedback_given',
      peer_feedback_received: 'peer_feedback_received',
      crew_joined: 'crew_joined',
      reflection_submitted: 'reflection_submitted',
      effort_rated: 'effort_rated',
      enjoyment_rated: 'enjoyment_rated',
      ai_coach_used: 'ai_hint_requested',
      explain_back_submitted: 'ai_explain_back_submitted',
      session_started: 'session_started',
      session_resumed: 'session_resumed',
      session_paused: 'session_paused',
      session_completed: 'session_completed'
    };
    return map[eventType] || 'feature_discovered';
  }

  private mapEventCategory(eventType: TelemetryEventType): TelemetryCategory {
    if (
      eventType === 'mission_browsed' ||
      eventType === 'mission_selected' ||
      eventType === 'mission_switched' ||
      eventType === 'goal_set' ||
      eventType === 'interest_updated'
    ) {
      return 'autonomy';
    }

    if (
      eventType === 'evidence_submitted' ||
      eventType === 'evidence_revised' ||
      eventType === 'checkpoint_attempted' ||
      eventType === 'checkpoint_passed' ||
      eventType === 'checkpoint_failed' ||
      eventType === 'skill_proven' ||
      eventType === 'rubric_viewed'
    ) {
      return 'competence';
    }

    if (
      eventType === 'showcase_submitted' ||
      eventType === 'recognition_given' ||
      eventType === 'recognition_received' ||
      eventType === 'peer_feedback_given' ||
      eventType === 'peer_feedback_received' ||
      eventType === 'crew_joined'
    ) {
      return 'belonging';
    }

    if (
      eventType === 'reflection_submitted' ||
      eventType === 'effort_rated' ||
      eventType === 'enjoyment_rated'
    ) {
      return 'reflection';
    }

    if (eventType === 'ai_coach_used' || eventType === 'explain_back_submitted') {
      return 'ai_interaction';
    }

    return 'engagement';
  }

  /**
   * Update aggregate metrics in real-time
   */
  private async updateAggregates(
    learnerId: string,
    siteId: string,
    eventType: TelemetryEventType
  ): Promise<void> {
    const aggregateRef = doc(db, 'motivationAnalytics', `${siteId}_${learnerId}`);

    // Map event types to aggregate fields
    const incrementMap: Record<string, string> = {
      mission_selected: 'totalMissionsSelected',
      evidence_submitted: 'totalEvidenceSubmitted',
      checkpoint_passed: 'totalCheckpointsPassed',
      checkpoint_failed: 'totalCheckpointsFailed',
      peer_feedback_given: 'totalFeedbackGiven',
      recognition_received: 'totalRecognitionReceived',
      reflection_submitted: 'totalReflections',
      ai_coach_used: 'totalAICoachUses',
      session_completed: 'totalSessionsCompleted'
    };

    const field = incrementMap[eventType];
    if (field) {
      await updateDoc(aggregateRef, {
        [field]: increment(1),
        lastActivityAt: serverTimestamp()
      });
    }
  }

  /**
   * Compute motivation metrics for a learner
   * (This would typically run server-side as a Cloud Function)
   */
  async computeMetrics(learnerId: string, siteId: string): Promise<MotivationMetrics> {
    // This is a simplified client-side stub
    // Real implementation would query telemetryEvents collection and compute
    
    return {
      choiceDiversity: 0,
      missionSwitchRate: 0,
      goalAlignmentScore: 0,
      proofSubmissionRate: 0,
      firstTimeSuccessRate: 0,
      revisionPersistence: 0,
      skillMasteryRate: 0,
      feedbackGivingRate: 0,
      recognitionReceived: 0,
      crewParticipation: 0,
      reflectionConsistency: 0,
      effortTrend: 0,
      enjoymentTrend: 0,
      avgSessionDuration: 0,
      sessionCompletionRate: 0,
      optimalTimeOfDay: 'morning'
    };
  }

  /**
   * Generate insights from metrics
   * (This would typically use ML or rule-based analysis server-side)
   */
  generateInsights(metrics: MotivationMetrics, ageBand: AgeBand): MotivationInsight[] {
    const insights: MotivationInsight[] = [];

    // Autonomy insights
    if (metrics.choiceDiversity < 0.3) {
      insights.push({
        type: 'opportunity',
        category: 'autonomy',
        message: 'Learner tends to pick similar missions',
        suggestedAction: 'Suggest exploring different pillars or skill areas',
        confidence: 0.8
      });
    }

    // Competence insights
    if (metrics.firstTimeSuccessRate > 0.8) {
      insights.push({
        type: 'strength',
        category: 'competence',
        message: 'High first-time success rate',
        suggestedAction: 'Suggest harder missions for growth',
        confidence: 0.9
      });
    }

    if (metrics.revisionPersistence > 5) {
      insights.push({
        type: 'opportunity',
        category: 'competence',
        message: 'Struggles with checkpoints, but persists',
        suggestedAction: 'Offer scaffolding or AI Coach nudge',
        confidence: 0.75
      });
    }

    // Belonging insights
    if (metrics.feedbackGivingRate < 1 && ageBand !== 'grades_1_3') {
      insights.push({
        type: 'nudge',
        category: 'belonging',
        message: 'Not giving peer feedback regularly',
        suggestedAction: 'Prompt to review a teammate\'s work',
        confidence: 0.7
      });
    }

    if (metrics.recognitionReceived > 3) {
      insights.push({
        type: 'strength',
        category: 'belonging',
        message: 'Receives lots of recognition from peers',
        confidence: 0.85
      });
    }

    // Reflection insights
    if (metrics.reflectionConsistency < 0.5) {
      insights.push({
        type: 'opportunity',
        category: 'competence',
        message: 'Skips reflection often',
        suggestedAction: 'Make reflection required or add reward',
        confidence: 0.65
      });
    }

    return insights;
  }
}

// ==================== CONVENIENCE METHODS ====================

export const sdtTelemetry = new SDTTelemetry();

/**
 * Quick track helpers
 */
export const trackMissionSelected = (
  learnerId: string,
  siteId: string,
  grade: number,
  missionId: string,
  chosenFromOptions: number
) => {
  return sdtTelemetry.trackEvent({
    eventType: 'mission_selected',
    learnerId,
    siteId,
    grade,
    missionId,
    metadata: {
      chosenFromOptions
    }
  });
};

export const trackCheckpointAttempt = (
  learnerId: string,
  siteId: string,
  grade: number,
  sessionId: string,
  missionId: string,
  passed: boolean,
  attemptNumber: number
) => {
  return sdtTelemetry.trackEvent({
    eventType: passed ? 'checkpoint_passed' : 'checkpoint_failed',
    learnerId,
    siteId,
    grade,
    sessionId,
    missionId,
    metadata: {
      attemptNumber,
      passed
    }
  });
};

export const trackPeerFeedback = (
  learnerId: string,
  siteId: string,
  grade: number,
  targetLearnerId: string,
  showcaseId: string
) => {
  return sdtTelemetry.trackEvent({
    eventType: 'peer_feedback_given',
    learnerId,
    siteId,
    grade,
    metadata: {
      targetLearnerId,
      showcaseId
    }
  });
};

export const trackReflection = (
  learnerId: string,
  siteId: string,
  grade: number,
  sessionId: string,
  effortRating: number,
  enjoymentRating: number
) => {
  return sdtTelemetry.trackEvent({
    eventType: 'reflection_submitted',
    learnerId,
    siteId,
    grade,
    sessionId,
    metadata: {
      effortRating,
      enjoymentRating
    }
  });
};

export const trackAICoachUse = (
  learnerId: string,
  siteId: string,
  grade: number,
  sessionId: string,
  mode: string,
  explainedBack: boolean
) => {
  return sdtTelemetry.trackEvent({
    eventType: 'ai_coach_used',
    learnerId,
    siteId,
    grade,
    sessionId,
    metadata: {
      mode,
      explainedBack
    }
  });
};
