/**
 * Unified Intelligence Service
 * 
 * Integrates:
 * - Telemetry (user interactions, SDT motivation)
 * - Analytics (learning metrics, insight rules)
 * - AI Intelligence (Scholesa internal inference)
 * 
 * This is the central service for all data collection and intelligence generation.
 */

import { TelemetryService, type TelemetryPayload, type TelemetryEvent } from '../telemetry/telemetryService';
import { AnalyticsEngine, type AnalyticsEventType, type InsightRule, type SDTScore } from './analyticsEngine';
import type { UserRole, AgeBand } from '@/src/types/schema';

// ==================== UNIFIED EVENT INTERFACE ====================

export interface UnifiedEventPayload {
  // Core identifiers
  userId: string;
  userRole: UserRole;
  siteId: string;
  sessionId?: string;
  
  // Telemetry event (for SDT tracking)
  telemetryEvent?: TelemetryEvent;
  
  // Analytics event (for learning metrics)
  analyticsEvent?: Partial<AnalyticsEventType>;
  
  // Context
  grade?: number;
  ageBand?: AgeBand;
  metadata?: Record<string, unknown>;
}

// ==================== INTELLIGENCE SERVICE ====================

export class IntelligenceService {
  private static clampConfidence(value: number): number {
    return Math.max(0.55, Math.min(0.95, Number(value.toFixed(2))));
  }

  private static confidenceFromGap(gap: number, scale: number, baseline: number): number {
    const normalizedGap = Math.max(0, Math.min(gap, scale));
    return this.clampConfidence(baseline + (normalizedGap / scale) * 0.25);
  }

  /**
   * Track a unified event (both telemetry and analytics)
   * This is the primary method for event tracking across the platform
   */
  static async trackUnifiedEvent(payload: UnifiedEventPayload): Promise<void> {
    const promises: Promise<unknown>[] = [];
    
    // Track telemetry if telemetry event provided
    if (payload.telemetryEvent) {
      const telemetryPayload: TelemetryPayload = {
        event: payload.telemetryEvent,
        category: this.inferCategoryFromEvent(payload.telemetryEvent),
        userId: payload.userId,
        userRole: payload.userRole,
        siteId: payload.siteId,
        grade: payload.grade,
        ageBand: payload.ageBand,
        sessionId: payload.sessionId,
        metadata: payload.metadata
      };
      
      promises.push(TelemetryService.track(telemetryPayload));
    }
    
    // Track analytics if analytics event provided
    if (payload.analyticsEvent && payload.analyticsEvent.event_name) {
      promises.push(
        AnalyticsEngine.trackEvent(payload.analyticsEvent as AnalyticsEventType)
      );
    }
    
    // Execute in parallel
    await Promise.all(promises);
  }
  
  /**
   * Get comprehensive learner profile with SDT scores, engagement, and insights
   */
  static async getLearnerProfile(userId: string, siteId: string): Promise<{
    userId: string;
    siteId: string;
    sdtScores: SDTScore;
    engagementScore: number;
    insights: InsightRule[];
    lastUpdated: Date;
  }> {
    const [sdtScores, engagementScore] = await Promise.all([
      TelemetryService.getSDTProfile(userId, siteId, 30),
      TelemetryService.getUserEngagementScore(userId, siteId, 7)
    ]);
    
    return {
      userId,
      siteId,
      sdtScores,
      engagementScore,
      insights: [], // Individual insights not yet implemented
      lastUpdated: new Date()
    };
  }
  
  /**
   * Get class insights with AI-powered recommendations
   */
  static async getClassInsights(
    classId: string,
    sessionId?: string
  ): Promise<{
    classId: string;
    sessionId?: string;
    metrics: {
      checkpointPassRate: number;
      attemptsToMastery: number;
      hintDependencyIndex: number;
      explainItBackCompliance: number;
    };
    insights: InsightRule[];
    generatedAt: Date;
  }> {
    const [
      checkpointPassRate,
      attemptsToMastery,
      hintDependencyIndex,
      explainItBackCompliance,
      insights
    ] = await Promise.all([
      AnalyticsEngine.computeCheckpointPassRate(classId, sessionId),
      AnalyticsEngine.computeAttemptsToMastery(classId, sessionId),
      AnalyticsEngine.computeHintDependencyIndex(classId, sessionId),
      AnalyticsEngine.computeExplainItBackCompliance(classId, sessionId),
      AnalyticsEngine.getInsights(classId, sessionId)
    ]);
    
    return {
      classId,
      sessionId,
      metrics: {
        checkpointPassRate,
        attemptsToMastery,
        hintDependencyIndex,
        explainItBackCompliance
      },
      insights,
      generatedAt: new Date()
    };
  }
  
  /**
   * Generate personalized learning recommendations using internal inference.
   *
   * PRIVACY: Uses aggregate metrics and sanitized context in-process only.
   */
  static async generatePersonalizedRecommendations(
    userId: string,
    siteId: string,
    context: {
      recentActivities: string[];
      currentMission?: string;
      strugglingConcepts?: string[];
    }
  ): Promise<{
    recommendations: string[];
    nextSteps: string[];
    encouragement: string;
  }> {
    const profile = await this.getLearnerProfile(userId, siteId);

    const sanitizedMission = context.currentMission
      ? this.sanitizeText(context.currentMission)
      : undefined;
    const sanitizedActivities = context.recentActivities.map((activity) => this.sanitizeText(activity));
    const struggling = (context.strugglingConcepts ?? []).map((concept) => this.sanitizeText(concept));

    const recommendations: string[] = [];

    if (profile.sdtScores.autonomy < 55) {
      recommendations.push('Offer two mission pathways and let the learner choose their starting route.');
    }
    if (profile.sdtScores.competence < 55) {
      recommendations.push('Use one worked example, then require an independent attempt before additional hints.');
    }
    if (profile.sdtScores.belonging < 55) {
      recommendations.push('Add a short peer check-in or partner review before final submission.');
    }
    if (profile.engagementScore < 50) {
      recommendations.push('Break work into a 10-minute sprint with a single visible success target.');
    }
    if (struggling.length > 0) {
      recommendations.push(`Target focused practice on: ${struggling.slice(0, 3).join(', ')}.`);
    }
    if (sanitizedMission) {
      recommendations.push(`Anchor examples to the current mission context: ${sanitizedMission}.`);
    }
    if (sanitizedActivities.length > 0 && recommendations.length < 3) {
      recommendations.push('Reference one recent activity and ask the learner to transfer that strategy to the next checkpoint.');
    }

    const dedupedRecommendations = Array.from(new Set(recommendations));
    const finalRecommendations = (
      dedupedRecommendations.length > 0
        ? dedupedRecommendations
        : ['Continue the current mission with one clear micro-goal for the next checkpoint.']
    ).slice(0, 5);

    const nextSteps = [
      'Pick one recommendation and commit to it for the next attempt.',
      'Complete one checkpoint attempt without skipping the explain-it-back step.',
      'Log what worked and what you will change next.',
    ].slice(0, 3);

    const strengths: string[] = [];
    if (profile.sdtScores.autonomy >= 70) strengths.push('independent decision-making');
    if (profile.sdtScores.competence >= 70) strengths.push('skill mastery');
    if (profile.sdtScores.belonging >= 70) strengths.push('collaboration');
    if (profile.engagementScore >= 70) strengths.push('consistent engagement');

    const encouragement = strengths.length > 0
      ? `You are showing strong ${strengths.slice(0, 2).join(' and ')}. Keep building on that momentum.`
      : 'You are making progress. Keep going one step at a time and your consistency will pay off.';

    return {
      recommendations: finalRecommendations,
      nextSteps,
      encouragement,
    };
  }
  
  /**
   * Detect learning patterns using internal inference.
   *
   * PRIVACY: Uses aggregate SDT and engagement metrics in-process only.
   */
  static async detectLearningPatterns(
    userId: string,
    siteId: string,
    timeframe: 'week' | 'month' = 'week'
  ): Promise<{
    patterns: Array<{
      pattern: string;
      confidence: number;
      description: string;
    }>;
    strengths: string[];
    growthAreas: string[];
  }> {
    const days = timeframe === 'week' ? 7 : 30;
    const profile = await this.getLearnerProfile(userId, siteId);

    const patterns: Array<{ pattern: string; confidence: number; description: string }> = [];

    if (profile.sdtScores.autonomy >= 70 && profile.sdtScores.competence < 60) {
      const challengeGap = (profile.sdtScores.autonomy - 70) + (60 - profile.sdtScores.competence);
      patterns.push({
        pattern: 'Challenge-seeking with uneven mastery',
        confidence: this.confidenceFromGap(challengeGap, 35, 0.6),
        description: `High agency over the past ${days} days with lower mastery indicators suggests the learner takes on challenge and may need tighter scaffolding.`,
      });
    }

    if (profile.sdtScores.competence >= 70 && profile.engagementScore >= 70) {
      const steadyProgressGap = (profile.sdtScores.competence - 70) + (profile.engagementScore - 70);
      patterns.push({
        pattern: 'Consistent independent progress',
        confidence: this.confidenceFromGap(steadyProgressGap, 45, 0.62),
        description: `Strong mastery and engagement across the past ${days} days indicate stable self-directed execution.`,
      });
    }

    if (profile.sdtScores.belonging >= 75) {
      const belongingGap = profile.sdtScores.belonging - 75;
      patterns.push({
        pattern: 'Collaborative momentum',
        confidence: this.confidenceFromGap(belongingGap, 20, 0.58),
        description: `Belonging signals are high, indicating peer interaction likely reinforces progress and persistence.`,
      });
    }

    if (profile.engagementScore < 45) {
      const engagementRiskGap = 45 - profile.engagementScore;
      patterns.push({
        pattern: 'Engagement drop risk',
        confidence: this.confidenceFromGap(engagementRiskGap, 25, 0.6),
        description: `Recent engagement is low, so shorter cycles and clearer wins are likely needed to sustain attention.`,
      });
    }

    if (patterns.length === 0) {
      const balanceGap = Math.abs(profile.sdtScores.autonomy - 60)
        + Math.abs(profile.sdtScores.competence - 60)
        + Math.abs(profile.sdtScores.belonging - 60)
        + Math.abs(profile.engagementScore - 60);
      patterns.push({
        pattern: 'Developing steady habits',
        confidence: this.clampConfidence(0.72 - Math.min(balanceGap, 80) / 80 * 0.14),
        description: `Signals over the past ${days} days are balanced without strong extremes; continue structured routines and checkpoint pacing.`,
      });
    }

    const strengths: string[] = [];
    if (profile.sdtScores.autonomy >= 65) strengths.push('Makes independent learning choices');
    if (profile.sdtScores.competence >= 65) strengths.push('Builds mastery with persistence');
    if (profile.sdtScores.belonging >= 65) strengths.push('Collaborates effectively with peers');
    if (profile.engagementScore >= 65) strengths.push('Sustains attention during learning tasks');

    const growthAreas: string[] = [];
    if (profile.sdtScores.autonomy < 55) growthAreas.push('Increase learner ownership through explicit choice points');
    if (profile.sdtScores.competence < 55) growthAreas.push('Strengthen core skills with micro-scaffolded checkpoints');
    if (profile.sdtScores.belonging < 55) growthAreas.push('Improve social connection via peer feedback loops');
    if (profile.engagementScore < 55) growthAreas.push('Raise engagement with shorter cycles and visible progress markers');

    return {
      patterns: patterns.slice(0, 4),
      strengths: strengths.slice(0, 4),
      growthAreas: growthAreas.slice(0, 4),
    };
  }
  
  // ===== HELPER FUNCTIONS =====
  
  /**
   * Sanitize text to remove potential PII before processing intelligence context
   * Removes: student names, email patterns, phone numbers, specific IDs
   */
  private static sanitizeText(text: string): string {
    if (!text) return text;
    
    let sanitized = text;
    
    // Remove email patterns
    sanitized = sanitized.replace(/[\w.+-]+@[\w-]+\.[\w.-]+/gi, '[email]');
    
    // Remove phone numbers (various formats)
    sanitized = sanitized.replace(/\b\d{3}[-.]?\d{3}[-.]?\d{4}\b/g, '[phone]');
    
    // Remove common student ID patterns (e.g., student_123, learner_456)
    sanitized = sanitized.replace(/\b(student|learner|user)_[\w-]+\b/gi, '[student-id]');
    
    // Remove any remaining numeric IDs longer than 5 digits
    sanitized = sanitized.replace(/\b\d{6,}\b/g, '[id]');
    
    // Remove potential names (capitalized words that appear isolated)
    // Keep mission names, concepts, and other educational terms
    // This is conservative - only removes obvious name patterns
    sanitized = sanitized.replace(/\b([A-Z][a-z]+ [A-Z][a-z]+)\b/g, (match) => {
      // Don't sanitize educational terms (keep things like "Gold Mission", "Silver Checkpoint")
      const educationalTerms = /Mission|Checkpoint|Sprint|Challenge|Quest|Level/i;
      return educationalTerms.test(match) ? match : '[name]';
    });
    
    return sanitized;
  }
  
  private static inferCategoryFromEvent(event: TelemetryEvent): TelemetryPayload['category'] {
    // Autonomy events
    if (['mission_selected', 'goal_set', 'difficulty_chosen', 'crew_role_chosen', 'interest_profile_updated'].includes(event)) {
      return 'autonomy';
    }
    
    // Competence events
    if (['checkpoint_passed', 'skill_proven', 'badge_earned', 'artifact_submitted'].includes(event)) {
      return 'competence';
    }
    
    // Belonging events
    if (['recognition_given', 'peer_feedback_given', 'showcase_submitted', 'crew_joined'].includes(event)) {
      return 'belonging';
    }
    
    // Reflection events
    if (['reflection_submitted', 'self_assessment_completed', 'effort_rated', 'enjoyment_rated'].includes(event)) {
      return 'reflection';
    }
    
    // AI interaction events
    if (event.startsWith('ai_')) {
      return 'ai_interaction';
    }
    
    // Session/engagement events
    if (event.startsWith('session_')) {
      return 'engagement';
    }
    
    // Performance events
    if (['page_load_time', 'api_error', 'client_error', 'slow_query_detected'].includes(event)) {
      return 'performance';
    }
    
    // Default to navigation
    return 'navigation';
  }

}

// ===== CONVENIENCE EXPORTS =====

export const trackUnifiedEvent = IntelligenceService.trackUnifiedEvent.bind(IntelligenceService);
export const getLearnerProfile = IntelligenceService.getLearnerProfile.bind(IntelligenceService);
export const getClassInsights = IntelligenceService.getClassInsights.bind(IntelligenceService);
export const generatePersonalizedRecommendations = IntelligenceService.generatePersonalizedRecommendations.bind(IntelligenceService);
export const detectLearningPatterns = IntelligenceService.detectLearningPatterns.bind(IntelligenceService);
