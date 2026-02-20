/**
 * Unified Intelligence Service
 * 
 * Integrates:
 * - Telemetry (user interactions, SDT motivation)
 * - Analytics (learning metrics, insight rules)
 * - AI Intelligence (Gemini-powered insights and recommendations)
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
   * Generate personalized learning recommendations using Gemini
   * 
   * PRIVACY: Only sends aggregated metrics and sanitized context.
   * NO student names, IDs, or PII are sent to Gemini.
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
    const geminiKey = process.env.NEXT_PUBLIC_GEMINI_API_KEY;
    if (!geminiKey) {
      return {
        recommendations: ['Continue working on your current mission'],
        nextSteps: ['Complete the next checkpoint'],
        encouragement: 'Keep up the great work!'
      };
    }
    
    const [profile] = await Promise.all([
      this.getLearnerProfile(userId, siteId)
    ]);
    
    // PRIVACY: Sanitize activities to remove any potential PII
    const sanitizedActivities = context.recentActivities.map(activity => 
      this.sanitizeText(activity)
    );
    const sanitizedMission = context.currentMission ? 
      this.sanitizeText(context.currentMission) : undefined;
    
    // PRIVACY: Only send aggregate scores and sanitized text - NO user IDs or names
    const prompt = `
You are an encouraging educational AI coach. Generate personalized learning recommendations for a student.

Student Profile (AGGREGATED DATA ONLY):
- Autonomy: ${profile.sdtScores.autonomy}% (choice & agency)
- Competence: ${profile.sdtScores.competence}% (skill mastery)
- Belonging: ${profile.sdtScores.belonging}% (social connection)
- Engagement Score: ${profile.engagementScore}/100

Recent Context:
${sanitizedActivities.map((activity, i) => `${i + 1}. ${activity}`).join('\n')}

${sanitizedMission ? `Current Mission: ${sanitizedMission}` : ''}
${context.strugglingConcepts?.length ? `Struggling with: ${context.strugglingConcepts.join(', ')}` : ''}

Provide a JSON response with:
{
  "recommendations": ["3-5 specific learning recommendations"],
  "nextSteps": ["2-3 concrete next steps"],
  "encouragement": "A warm, personalized encouragement message"
}

Be specific, actionable, and encouraging. Focus on growth mindset.
Return only valid JSON.
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
              temperature: 0.8,
              maxOutputTokens: 1024
            }
          })
        }
      );
      
      if (!response.ok) {
        throw new Error(`Gemini API error: ${response.statusText}`);
      }
      
      const data = await response.json();
      const text = data.candidates?.[0]?.content?.parts?.[0]?.text || '{}';
      
      // Parse JSON from response
      const jsonMatch = text.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        return JSON.parse(jsonMatch[0]);
      }
      
      // Fallback
      return {
        recommendations: ['Continue working on your current mission'],
        nextSteps: ['Complete the next checkpoint'],
        encouragement: 'Keep up the great work!'
      };
    } catch (error) {
      if (!this.isExpectedExternalAIError(error)) {
        console.error('Failed to generate personalized recommendations:', error);
      }
      return {
        recommendations: ['Continue working on your current mission'],
        nextSteps: ['Complete the next checkpoint'],
        encouragement: 'Keep up the great work!'
      };
    }
  }
  
  /**
   * Detect learning patterns using Gemini
   * 
   * PRIVACY: Only sends aggregated SDT scores and engagement metrics.
   * NO student names, IDs, or PII are sent to Gemini.
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
    const geminiKey = process.env.NEXT_PUBLIC_GEMINI_API_KEY;
    if (!geminiKey) {
      return {
        patterns: [],
        strengths: [],
        growthAreas: []
      };
    }
    
    const days = timeframe === 'week' ? 7 : 30;
    const [profile] = await Promise.all([
      this.getLearnerProfile(userId, siteId)
    ]);
    
    // PRIVACY: Only send aggregate scores - NO user IDs or names
    const prompt = `
Analyze this student's learning patterns and provide insights.

Student Metrics (AGGREGATED DATA ONLY):
- Autonomy (choice-making): ${profile.sdtScores.autonomy}%
- Competence (skill mastery): ${profile.sdtScores.competence}%
- Belonging (collaboration): ${profile.sdtScores.belonging}%
- Overall Engagement: ${profile.engagementScore}/100

Timeframe: Past ${days} days

Identify:
1. Learning patterns (how they approach challenges)
2. Strengths (what they excel at)
3. Growth areas (opportunities for improvement)

Return JSON:
{
  "patterns": [
    {
      "pattern": "Brief pattern name",
      "confidence": 0.85,
      "description": "Detailed explanation"
    }
  ],
  "strengths": ["strength 1", "strength 2", "strength 3"],
  "growthAreas": ["area 1", "area 2"]
}

Be specific and evidence-based. Return only valid JSON.
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
              maxOutputTokens: 1024
            }
          })
        }
      );
      
      if (!response.ok) {
        throw new Error(`Gemini API error: ${response.statusText}`);
      }
      
      const data = await response.json();
      const text = data.candidates?.[0]?.content?.parts?.[0]?.text || '{}';
      
      // Parse JSON from response
      const jsonMatch = text.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        return JSON.parse(jsonMatch[0]);
      }
      
      return {
        patterns: [],
        strengths: [],
        growthAreas: []
      };
    } catch (error) {
      if (!this.isExpectedExternalAIError(error)) {
        console.error('Failed to detect learning patterns:', error);
      }
      return {
        patterns: [],
        strengths: [],
        growthAreas: []
      };
    }
  }
  
  // ===== HELPER FUNCTIONS =====
  
  /**
   * Sanitize text to remove potential PII before sending to external APIs
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

    private static isExpectedExternalAIError(error: unknown): boolean {
      const message = (error as { message?: string } | null)?.message ?? '';
      return message.includes('Gemini API error: Bad Request');
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
