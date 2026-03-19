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
  collection,
  doc,
  getDocs,
  query,
  updateDoc,
  increment,
  serverTimestamp,
  Timestamp,
  where,
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
  choiceDiversity: number | null; // 0-1, how varied are their choices
  missionSwitchRate: number | null; // switches per session
  goalAlignmentScore: number | null; // % missions aligned with stated goals
  
  // Competence metrics
  proofSubmissionRate: number | null; // submissions per week
  firstTimeSuccessRate: number | null; // % checkpoints passed without revision
  revisionPersistence: number | null; // avg attempts before passing
  skillMasteryRate: number | null; // skills proven per week
  
  // Belonging metrics
  feedbackGivingRate: number | null; // peer feedbacks per week
  recognitionReceived: number | null; // shout-outs received
  crewParticipation: number | null; // % of crew sessions attended
  
  // Reflection metrics
  reflectionConsistency: number | null; // % sessions with reflection
  effortTrend: number | null; // avg change in effort rating over time
  enjoymentTrend: number | null; // avg change in enjoyment rating
  
  // Time metrics
  avgSessionDuration: number | null; // minutes
  sessionCompletionRate: number | null; // % started sessions completed
  optimalTimeOfDay: string | null; // when they're most engaged
}

export interface MotivationInsight {
  type: 'strength' | 'opportunity' | 'nudge';
  category: 'autonomy' | 'competence' | 'belonging';
  message: string;
  suggestedAction?: string;
  confidence: number; // 0-1
}

function clampInsightConfidence(value: number): number {
  return Math.max(0.55, Math.min(0.95, Number(value.toFixed(2))));
}

function confidenceAboveThreshold(value: number, threshold: number, scale: number, baseline: number): number {
  const gap = Math.max(0, value - threshold);
  return clampInsightConfidence(baseline + Math.min(gap / scale, 1) * 0.25);
}

function confidenceBelowThreshold(value: number, threshold: number, scale: number, baseline: number): number {
  const gap = Math.max(0, threshold - value);
  return clampInsightConfidence(baseline + Math.min(gap / scale, 1) * 0.25);
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
    const defaultMetrics: MotivationMetrics = {
      choiceDiversity: null,
      missionSwitchRate: null,
      goalAlignmentScore: null,
      proofSubmissionRate: null,
      firstTimeSuccessRate: null,
      revisionPersistence: null,
      skillMasteryRate: null,
      feedbackGivingRate: null,
      recognitionReceived: null,
      crewParticipation: null,
      reflectionConsistency: null,
      effortTrend: null,
      enjoymentTrend: null,
      avgSessionDuration: null,
      sessionCompletionRate: null,
      optimalTimeOfDay: null,
    };

    try {
      const since = Timestamp.fromDate(new Date(Date.now() - 30 * 24 * 60 * 60 * 1000));
      const q = query(
        collection(db, 'telemetryEvents'),
        where('userId', '==', learnerId),
        where('siteId', '==', siteId),
        where('timestamp', '>=', since),
      );

      const snap = await getDocs(q);
      if (snap.empty) return defaultMetrics;

      const missionIds = new Set<string>();
      let missionSwitches = 0;
      let goalsSet = 0;

      let evidenceSubmitted = 0;
      let checkpointAttempts = 0;
      let checkpointPasses = 0;
      let skillProven = 0;

      let feedbackGiven = 0;
      let recognitionReceived = 0;
      let crewJoined = 0;

      let reflectionCount = 0;
      const effortRatings: number[] = [];
      const enjoymentRatings: number[] = [];

      let sessionStarted = 0;
      let sessionCompleted = 0;
      const completionDurationsMinutes: number[] = [];

      const hourCounts = new Map<number, number>();
      const sessionsWithReflection = new Set<string>();

      const parseNumber = (value: unknown): number | null => {
        if (typeof value === 'number' && Number.isFinite(value)) return value;
        if (typeof value === 'string') {
          const parsed = Number(value);
          return Number.isFinite(parsed) ? parsed : null;
        }
        return null;
      };

      for (const docSnap of snap.docs) {
        const data = docSnap.data() as Record<string, unknown>;
        const event = typeof data.event === 'string' ? data.event : '';
        const missionId = typeof data.missionId === 'string' ? data.missionId : undefined;
        const sessionId = typeof data.sessionId === 'string' ? data.sessionId : undefined;
        const metadata = (data.metadata && typeof data.metadata === 'object'
          ? data.metadata
          : {}) as Record<string, unknown>;

        const timestampValue = data.timestamp;
        const ts = timestampValue instanceof Timestamp
          ? timestampValue
          : Timestamp.now();
        const hour = ts.toDate().getHours();
        hourCounts.set(hour, (hourCounts.get(hour) || 0) + 1);

        if (missionId) {
          if (missionIds.size > 0 && !missionIds.has(missionId)) {
            missionSwitches += 1;
          }
          missionIds.add(missionId);
        }

        switch (event) {
          case 'mission_selected':
            break;
          case 'mission_variant_chosen':
            missionSwitches += 1;
            break;
          case 'goal_set':
            goalsSet += 1;
            break;
          case 'artifact_submitted':
            evidenceSubmitted += 1;
            break;
          case 'checkpoint_attempted':
          case 'checkpoint_failed':
            checkpointAttempts += 1;
            break;
          case 'checkpoint_passed':
            checkpointAttempts += 1;
            checkpointPasses += 1;
            break;
          case 'skill_proven':
            skillProven += 1;
            break;
          case 'peer_feedback_given':
            feedbackGiven += 1;
            break;
          case 'recognition_received':
            recognitionReceived += 1;
            break;
          case 'crew_joined':
            crewJoined += 1;
            break;
          case 'reflection_submitted':
            reflectionCount += 1;
            if (sessionId) sessionsWithReflection.add(sessionId);
            break;
          case 'effort_rated': {
            const rating = parseNumber(metadata.rating ?? metadata.effortRating);
            if (rating !== null) effortRatings.push(rating);
            break;
          }
          case 'enjoyment_rated': {
            const rating = parseNumber(metadata.rating ?? metadata.enjoymentRating);
            if (rating !== null) enjoymentRatings.push(rating);
            break;
          }
          case 'session_started':
            sessionStarted += 1;
            break;
          case 'session_completed': {
            sessionCompleted += 1;
            const durationMin = parseNumber(metadata.durationMinutes ?? metadata.durationMin);
            if (durationMin !== null && durationMin >= 0) {
              completionDurationsMinutes.push(durationMin);
            }
            break;
          }
          default:
            break;
        }
      }

      const avg = (values: number[]): number | null => {
        if (values.length === 0) return null;
        return values.reduce((sum, current) => sum + current, 0) / values.length;
      };

      const sortedHours = Array.from(hourCounts.entries()).sort((a, b) => b[1] - a[1]);
      const topHour = sortedHours.length > 0 ? sortedHours[0][0] : null;
      const optimalTimeOfDay = topHour == null ? null : topHour < 12 ? 'morning' : topHour < 17 ? 'afternoon' : 'evening';

      return {
        choiceDiversity: missionIds.size > 0 ? Math.min(1, missionIds.size / 5) : null,
        missionSwitchRate: sessionStarted > 0 ? missionSwitches / sessionStarted : null,
        goalAlignmentScore: missionIds.size > 0 ? Math.min(1, goalsSet / missionIds.size) : null,
        proofSubmissionRate: evidenceSubmitted / 4,
        firstTimeSuccessRate: checkpointAttempts > 0 ? checkpointPasses / checkpointAttempts : null,
        revisionPersistence: checkpointPasses > 0
          ? (checkpointAttempts - checkpointPasses) / checkpointPasses
          : null,
        skillMasteryRate: skillProven / 4,
        feedbackGivingRate: feedbackGiven / 4,
        recognitionReceived,
        crewParticipation: sessionStarted > 0 ? Math.min(1, crewJoined / sessionStarted) : null,
        reflectionConsistency: sessionStarted > 0 ? sessionsWithReflection.size / sessionStarted : null,
        effortTrend: avg(effortRatings),
        enjoymentTrend: avg(enjoymentRatings),
        avgSessionDuration: avg(completionDurationsMinutes),
        sessionCompletionRate: sessionStarted > 0 ? sessionCompleted / sessionStarted : null,
        optimalTimeOfDay,
      };
    } catch (error) {
      console.error('Failed to compute SDT metrics:', error);
      return defaultMetrics;
    }
  }

  /**
   * Generate insights from metrics
   * (This would typically use ML or rule-based analysis server-side)
   */
  generateInsights(metrics: MotivationMetrics, ageBand: AgeBand): MotivationInsight[] {
    const insights: MotivationInsight[] = [];

    // Autonomy insights
    if (metrics.choiceDiversity != null && metrics.choiceDiversity < 0.3) {
      insights.push({
        type: 'opportunity',
        category: 'autonomy',
        message: 'Learner tends to pick similar missions',
        suggestedAction: 'Suggest exploring different pillars or skill areas',
        confidence: confidenceBelowThreshold(metrics.choiceDiversity, 0.3, 0.3, 0.58)
      });
    }

    // Competence insights
    if (metrics.firstTimeSuccessRate != null && metrics.firstTimeSuccessRate > 0.8) {
      insights.push({
        type: 'strength',
        category: 'competence',
        message: 'High first-time success rate',
        suggestedAction: 'Suggest harder missions for growth',
        confidence: confidenceAboveThreshold(metrics.firstTimeSuccessRate, 0.8, 0.2, 0.62)
      });
    }

    if (metrics.revisionPersistence != null && metrics.revisionPersistence > 5) {
      insights.push({
        type: 'opportunity',
        category: 'competence',
        message: 'Struggles with checkpoints, but persists',
        suggestedAction: 'Offer scaffolding or AI Coach nudge',
        confidence: confidenceAboveThreshold(metrics.revisionPersistence, 5, 5, 0.58)
      });
    }

    // Belonging insights
    if (metrics.feedbackGivingRate != null && metrics.feedbackGivingRate < 1 && ageBand !== 'grades_1_3') {
      insights.push({
        type: 'nudge',
        category: 'belonging',
        message: 'Not giving peer feedback regularly',
        suggestedAction: 'Prompt to review a teammate\'s work',
        confidence: confidenceBelowThreshold(metrics.feedbackGivingRate, 1, 1, 0.56)
      });
    }

    if (metrics.recognitionReceived != null && metrics.recognitionReceived > 3) {
      insights.push({
        type: 'strength',
        category: 'belonging',
        message: 'Receives lots of recognition from peers',
        confidence: confidenceAboveThreshold(metrics.recognitionReceived, 3, 4, 0.6)
      });
    }

    // Reflection insights
    if (metrics.reflectionConsistency != null && metrics.reflectionConsistency < 0.5) {
      insights.push({
        type: 'opportunity',
        category: 'competence',
        message: 'Skips reflection often',
        suggestedAction: 'Make reflection required or add reward',
        confidence: confidenceBelowThreshold(metrics.reflectionConsistency, 0.5, 0.5, 0.55)
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
