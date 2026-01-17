/**
 * Motivation Engine Service
 * 
 * Client-side service for interacting with the motivation and personalization system.
 * Tracks learner interactions, retrieves motivation profiles, and handles nudges.
 */

import { httpsCallable } from 'firebase/functions';
import { functions } from '@/src/firebase/client-init';
import type {
  MotivationType,
  EngagementLevel,
  LearnerMotivationProfile,
  MotivationNudge,
  MotivationInsight,
  PillarCode,
} from '@/src/types/schema';

// ============================================================================
// TYPES
// ============================================================================

export interface EducatorFeedbackInput {
  learnerId: string;
  siteId: string;
  sessionOccurrenceId?: string;
  engagementLevel: 1 | 2 | 3 | 4 | 5;
  participationType: 'leader' | 'active' | 'quiet' | 'observer' | 'reluctant';
  respondedWellTo: MotivationType[];
  struggledWith?: string;
  effectiveStrategies?: Array<{ type: MotivationType; strategy: string }>;
  notes?: string;
  highlights?: string[];
}

export interface SupportInterventionInput {
  learnerId: string;
  siteId: string;
  sessionOccurrenceId?: string;
  strategyType: MotivationType;
  strategyDescription: string;
  context: 'group' | 'individual' | 'peer-supported';
  triggerReason?: string;
  outcome: 'helped' | 'partial' | 'no-change' | 'backfired';
  learnerResponse?: 'positive' | 'neutral' | 'resistant';
  notes?: string;
  recommendForFuture: boolean;
}

export interface LearnerInteractionEvent {
  eventType: 
    | 'app.open'
    | 'app.session.end'
    | 'mission.started'
    | 'mission.completed'
    | 'mission.abandoned'
    | 'reflection.submitted'
    | 'portfolio.item.added'
    | 'help.requested'
    | 'badge.viewed'
    | 'leaderboard.viewed'
    | 'streak.celebrated'
    | 'nudge.accepted'
    | 'nudge.dismissed'
    | 'nudge.snoozed';
  siteId: string;
  metadata?: {
    durationSeconds?: number;
    missionId?: string;
    pillarCode?: PillarCode;
    difficultyLevel?: string;
    timeToComplete?: number;
    helpType?: string;
    nudgeType?: string;
  };
}

export interface ClassInsight {
  learnerId: string;
  currentEngagement: EngagementLevel;
  primaryMotivators: MotivationType[];
  suggestedStrategies: Array<{ type: MotivationType; strategy: string }>;
  recentHighlights?: string[];
  needsAttention: boolean;
}

// ============================================================================
// SERVICE CLASS
// ============================================================================

class MotivationEngineService {
  private sessionStartTime: number | null = null;

  /**
   * Start tracking an app session
   */
  startSession(siteId: string): void {
    this.sessionStartTime = Date.now();
    this.trackInteraction({
      eventType: 'app.open',
      siteId,
    });
  }

  /**
   * End tracking an app session
   */
  async endSession(siteId: string): Promise<void> {
    const durationSeconds = this.sessionStartTime 
      ? Math.round((Date.now() - this.sessionStartTime) / 1000)
      : 0;
    
    await this.trackInteraction({
      eventType: 'app.session.end',
      siteId,
      metadata: { durationSeconds },
    });
    
    this.sessionStartTime = null;
  }

  /**
   * Track a learner interaction with the app
   */
  async trackInteraction(event: LearnerInteractionEvent): Promise<void> {
    try {
      const trackFn = httpsCallable(functions, 'trackLearnerInteraction');
      await trackFn(event);
    } catch (error) {
      console.error('Error tracking interaction:', error);
      // Don't throw - tracking failures shouldn't break the app
    }
  }

  // Convenience methods for common interactions
  async trackMissionStarted(siteId: string, missionId: string, pillarCode?: PillarCode): Promise<void> {
    await this.trackInteraction({
      eventType: 'mission.started',
      siteId,
      metadata: { missionId, pillarCode },
    });
  }

  async trackMissionCompleted(
    siteId: string, 
    missionId: string, 
    timeToCompleteSeconds: number,
    pillarCode?: PillarCode
  ): Promise<void> {
    await this.trackInteraction({
      eventType: 'mission.completed',
      siteId,
      metadata: { 
        missionId, 
        timeToComplete: timeToCompleteSeconds,
        pillarCode,
      },
    });
  }

  async trackMissionAbandoned(siteId: string, missionId: string): Promise<void> {
    await this.trackInteraction({
      eventType: 'mission.abandoned',
      siteId,
      metadata: { missionId },
    });
  }

  async trackReflectionSubmitted(siteId: string, missionId?: string): Promise<void> {
    await this.trackInteraction({
      eventType: 'reflection.submitted',
      siteId,
      metadata: missionId ? { missionId } : undefined,
    });
  }

  async trackPortfolioItemAdded(siteId: string, pillarCode?: PillarCode): Promise<void> {
    await this.trackInteraction({
      eventType: 'portfolio.item.added',
      siteId,
      metadata: pillarCode ? { pillarCode } : undefined,
    });
  }

  async trackHelpRequested(siteId: string, helpType?: string): Promise<void> {
    await this.trackInteraction({
      eventType: 'help.requested',
      siteId,
      metadata: helpType ? { helpType } : undefined,
    });
  }

  async trackBadgeViewed(siteId: string): Promise<void> {
    await this.trackInteraction({
      eventType: 'badge.viewed',
      siteId,
    });
  }

  async trackLeaderboardViewed(siteId: string): Promise<void> {
    await this.trackInteraction({
      eventType: 'leaderboard.viewed',
      siteId,
    });
  }

  async trackStreakCelebrated(siteId: string): Promise<void> {
    await this.trackInteraction({
      eventType: 'streak.celebrated',
      siteId,
    });
  }

  /**
   * Get learner's motivation profile
   */
  async getMotivationProfile(learnerId: string, siteId: string): Promise<LearnerMotivationProfile> {
    const getProfileFn = httpsCallable<
      { learnerId: string; siteId: string },
      LearnerMotivationProfile
    >(functions, 'getLearnerMotivationProfile');
    
    const result = await getProfileFn({ learnerId, siteId });
    return result.data;
  }

  /**
   * Get personalized nudges for the current learner
   */
  async getNudges(siteId: string, limit?: number): Promise<MotivationNudge[]> {
    const getNudgesFn = httpsCallable<
      { siteId: string; limit?: number },
      { nudges: MotivationNudge[] }
    >(functions, 'getLearnerNudges');
    
    const result = await getNudgesFn({ siteId, limit });
    return result.data.nudges;
  }

  /**
   * Respond to a motivation nudge
   */
  async respondToNudge(
    nudgeId: string, 
    response: 'accepted' | 'dismissed' | 'snoozed',
    snoozeDurationMinutes?: number
  ): Promise<void> {
    const respondFn = httpsCallable(functions, 'respondToNudge');
    await respondFn({ nudgeId, response, snoozeDurationMinutes });
  }

  /**
   * Submit educator feedback about a learner
   */
  async submitEducatorFeedback(feedback: EducatorFeedbackInput): Promise<{ feedbackId: string }> {
    const submitFn = httpsCallable<EducatorFeedbackInput, { success: boolean; feedbackId: string }>(
      functions, 
      'submitEducatorFeedback'
    );
    const result = await submitFn(feedback);
    return { feedbackId: result.data.feedbackId };
  }

  /**
   * Log a support intervention and its outcome
   */
  async logSupportIntervention(intervention: SupportInterventionInput): Promise<{ interventionId: string }> {
    const logFn = httpsCallable<SupportInterventionInput, { success: boolean; interventionId: string }>(
      functions, 
      'logSupportIntervention'
    );
    const result = await logFn(intervention);
    return { interventionId: result.data.interventionId };
  }

  /**
   * Get class insights for educators
   */
  async getClassInsights(
    siteId: string, 
    options?: { sessionOccurrenceId?: string; learnerIds?: string[] }
  ): Promise<ClassInsight[]> {
    const getInsightsFn = httpsCallable<
      { siteId: string; sessionOccurrenceId?: string; learnerIds?: string[] },
      { insights: ClassInsight[] }
    >(functions, 'getClassInsights');
    
    const result = await getInsightsFn({ 
      siteId, 
      sessionOccurrenceId: options?.sessionOccurrenceId,
      learnerIds: options?.learnerIds,
    });
    return result.data.insights;
  }

  /**
   * Manually trigger motivation profile computation (for educators)
   */
  async computeMotivationSignals(learnerId: string, siteId: string): Promise<void> {
    const computeFn = httpsCallable(functions, 'computeMotivationSignals');
    await computeFn({ learnerId, siteId });
  }

  /**
   * Generate nudges for learners (for educators)
   */
  async generateNudges(siteId: string, learnerIds?: string[]): Promise<{ processedCount: number }> {
    const generateFn = httpsCallable<
      { siteId: string; learnerIds?: string[] },
      { success: boolean; processedCount: number }
    >(functions, 'generateMotivationNudges');
    
    const result = await generateFn({ siteId, learnerIds });
    return { processedCount: result.data.processedCount };
  }
}

// ============================================================================
// UTILITIES
// ============================================================================

/**
 * Get a user-friendly label for motivation types
 */
export const MOTIVATION_LABELS: Record<MotivationType, string> = {
  achievement: 'Achievement-driven',
  social: 'Socially motivated',
  mastery: 'Mastery-focused',
  autonomy: 'Values autonomy',
  purpose: 'Purpose-driven',
  competition: 'Competitive',
  creativity: 'Creative',
};

/**
 * Get emoji for motivation types
 */
export const MOTIVATION_EMOJI: Record<MotivationType, string> = {
  achievement: '🎯',
  social: '👥',
  mastery: '📚',
  autonomy: '🧭',
  purpose: '🌍',
  competition: '🏆',
  creativity: '🎨',
};

/**
 * Get color for engagement levels
 */
export const ENGAGEMENT_COLORS: Record<EngagementLevel, { bg: string; text: string; border: string }> = {
  thriving: { bg: 'bg-green-100', text: 'text-green-800', border: 'border-green-300' },
  engaged: { bg: 'bg-blue-100', text: 'text-blue-800', border: 'border-blue-300' },
  coasting: { bg: 'bg-yellow-100', text: 'text-yellow-800', border: 'border-yellow-300' },
  struggling: { bg: 'bg-orange-100', text: 'text-orange-800', border: 'border-orange-300' },
  'at-risk': { bg: 'bg-red-100', text: 'text-red-800', border: 'border-red-300' },
};

/**
 * Get label for engagement levels
 */
export const ENGAGEMENT_LABELS: Record<EngagementLevel, string> = {
  thriving: 'Thriving',
  engaged: 'Engaged',
  coasting: 'Coasting',
  struggling: 'Needs Support',
  'at-risk': 'At Risk',
};

/**
 * Format insights for display
 */
export function formatInsight(insight: MotivationInsight): {
  icon: string;
  color: string;
  bgColor: string;
} {
  switch (insight.type) {
    case 'strength':
      return { icon: '💪', color: 'text-green-700', bgColor: 'bg-green-50' };
    case 'opportunity':
      return { icon: '💡', color: 'text-blue-700', bgColor: 'bg-blue-50' };
    case 'warning':
      return { icon: '⚠️', color: 'text-orange-700', bgColor: 'bg-orange-50' };
    case 'celebration':
      return { icon: '🎉', color: 'text-purple-700', bgColor: 'bg-purple-50' };
    default:
      return { icon: '📝', color: 'text-gray-700', bgColor: 'bg-gray-50' };
  }
}

// Export singleton instance
export const motivationEngine = new MotivationEngineService();

// Export class for testing
export { MotivationEngineService };
