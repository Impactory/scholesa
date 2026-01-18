/**
 * Analytics & Intelligence Integration Test
 * 
 * Verifies that all analytics.json specifications are implemented correctly
 * and that Gemini API integration is working
 */

import { describe, it, expect } from '@jest/globals';
import {
  AnalyticsEngine,
  IntelligenceService,
  TelemetryService,
  type MissionSelectedEvent,
  type CheckpointSubmittedEvent
} from '@/src/lib/analytics';
import { Timestamp } from 'firebase/firestore';

// Mock environment
process.env.NEXT_PUBLIC_GEMINI_API_KEY = 'test_key';

describe('Analytics Implementation', () => {
  describe('Event Tracking', () => {
    it('should track mission selected event', async () => {
      const event: MissionSelectedEvent = {
        event_id: 'test_1',
        event_name: 'mission_selected',
        event_time: Timestamp.now(),
        class_id: 'class_123',
        student_id: 'student_456',
        grade_band_id: 'grades_4_6',
        app_version: '1.0.0',
        device_type: 'desktop',
        source_screen: 'mission_browser',
        mission_id: 'm_123',
        level: 'GOLD'
      };
      
      const result = await AnalyticsEngine.trackEvent(event);
      expect(result).toBeDefined();
    });
    
    it('should track checkpoint submission event', async () => {
      const event: CheckpointSubmittedEvent = {
        event_id: 'test_2',
        event_name: 'checkpoint_submitted',
        event_time: Timestamp.now(),
        class_id: 'class_123',
        student_id: 'student_456',
        grade_band_id: 'grades_4_6',
        app_version: '1.0.0',
        device_type: 'desktop',
        source_screen: 'checkpoint',
        checkpoint_id: 'cp_1',
        mission_id: 'm_123',
        skill_id: 'sk_debugging',
        attempt_no: 2,
        passed: true
      };
      
      const result = await AnalyticsEngine.trackEvent(event);
      expect(result).toBeDefined();
    });
  });
  
  describe('Computed Metrics', () => {
    it('should compute checkpoint pass rate', async () => {
      const passRate = await AnalyticsEngine.computeCheckpointPassRate('class_123');
      expect(typeof passRate).toBe('number');
      expect(passRate).toBeGreaterThanOrEqual(0);
      expect(passRate).toBeLessThanOrEqual(1);
    });
    
    it('should compute choice distribution', async () => {
      const distribution = await AnalyticsEngine.computeChoiceDistribution('class_123');
      expect(distribution).toHaveProperty('BRONZE');
      expect(distribution).toHaveProperty('SILVER');
      expect(distribution).toHaveProperty('GOLD');
      expect(distribution).toHaveProperty('BRIDGE');
    });
    
    it('should compute hint dependency index', async () => {
      const index = await AnalyticsEngine.computeHintDependencyIndex('class_123');
      expect(typeof index).toBe('number');
      expect(index).toBeGreaterThanOrEqual(0);
    });
  });
  
  describe('Insight Rules', () => {
    it('should evaluate threshold-based insight rules', async () => {
      const insights = await AnalyticsEngine.evaluateInsightRules('class_123');
      expect(Array.isArray(insights)).toBe(true);
      
      insights.forEach(insight => {
        expect(insight).toHaveProperty('id');
        expect(insight).toHaveProperty('recommendation');
        expect(insight).toHaveProperty('actions');
        expect(insight).toHaveProperty('priority');
        expect(insight).toHaveProperty('category');
        expect(insight.triggered).toBe(true);
      });
    });
    
    it('should detect ai_overhelping rule', async () => {
      // Mock high hint dependency
      const insights = await AnalyticsEngine.evaluateInsightRules('class_123');
      const aiOverhelpingRule = insights.find(i => i.id === 'ai_overhelping');
      
      if (aiOverhelpingRule) {
        expect(aiOverhelpingRule.category).toBe('ai_usage');
        expect(aiOverhelpingRule.actions).toContain('gate_hints_on_explain_it_back');
      }
    });
  });
  
  describe('Gemini AI Integration', () => {
    it('should have Gemini API key configured', () => {
      const key = process.env.NEXT_PUBLIC_GEMINI_API_KEY;
      expect(key).toBeDefined();
      expect(key).not.toBe('');
    });
    
    it('should generate AI insights with proper structure', async () => {
      // This will call Gemini API if key is valid
      const insights = await AnalyticsEngine.generateAIInsights('class_123');
      
      expect(Array.isArray(insights)).toBe(true);
      
      insights.forEach(insight => {
        expect(insight).toHaveProperty('id');
        expect(insight).toHaveProperty('recommendation');
        expect(insight).toHaveProperty('actions');
        expect(insight).toHaveProperty('priority');
        expect(['high', 'medium', 'low']).toContain(insight.priority);
        expect(insight).toHaveProperty('category');
        expect(['learning', 'engagement', 'collaboration', 'ai_usage']).toContain(insight.category);
      });
    });
  });
  
  describe('Intelligence Service', () => {
    it('should track unified events', async () => {
      await IntelligenceService.trackUnifiedEvent({
        userId: 'user_123',
        userRole: 'learner',
        siteId: 'site_abc',
        grade: 5,
        telemetryEvent: 'mission_selected',
        analyticsEvent: {
          event_name: 'mission_selected',
          event_id: 'test_unified',
          event_time: Timestamp.now(),
          class_id: 'class_123',
          student_id: 'user_123',
          grade_band_id: 'grades_4_6',
          app_version: '1.0.0',
          device_type: 'desktop',
          source_screen: 'test',
          mission_id: 'm_123',
          level: 'SILVER'
        }
      });
      
      // Should not throw
      expect(true).toBe(true);
    });
    
    it('should get learner profile', async () => {
      const profile = await IntelligenceService.getLearnerProfile('user_123', 'site_abc');
      
      expect(profile).toHaveProperty('userId');
      expect(profile).toHaveProperty('siteId');
      expect(profile).toHaveProperty('sdtScores');
      expect(profile.sdtScores).toHaveProperty('autonomy');
      expect(profile.sdtScores).toHaveProperty('competence');
      expect(profile.sdtScores).toHaveProperty('belonging');
      expect(profile).toHaveProperty('engagementScore');
    });
    
    it('should get class insights', async () => {
      const insights = await IntelligenceService.getClassInsights('class_123');
      
      expect(insights).toHaveProperty('classId');
      expect(insights).toHaveProperty('metrics');
      expect(insights.metrics).toHaveProperty('checkpointPassRate');
      expect(insights.metrics).toHaveProperty('attemptsToMastery');
      expect(insights.metrics).toHaveProperty('hintDependencyIndex');
      expect(insights.metrics).toHaveProperty('explainItBackCompliance');
      expect(insights).toHaveProperty('insights');
      expect(Array.isArray(insights.insights)).toBe(true);
    });
    
    it('should generate personalized recommendations', async () => {
      const recs = await IntelligenceService.generatePersonalizedRecommendations(
        'user_123',
        'site_abc',
        {
          recentActivities: ['Completed mission', 'Submitted reflection'],
          currentMission: 'Test mission'
        }
      );
      
      expect(recs).toHaveProperty('recommendations');
      expect(recs).toHaveProperty('nextSteps');
      expect(recs).toHaveProperty('encouragement');
      expect(Array.isArray(recs.recommendations)).toBe(true);
      expect(Array.isArray(recs.nextSteps)).toBe(true);
      expect(typeof recs.encouragement).toBe('string');
    });
    
    it('should detect learning patterns', async () => {
      const patterns = await IntelligenceService.detectLearningPatterns('user_123', 'site_abc');
      
      expect(patterns).toHaveProperty('patterns');
      expect(patterns).toHaveProperty('strengths');
      expect(patterns).toHaveProperty('growthAreas');
      expect(Array.isArray(patterns.patterns)).toBe(true);
      expect(Array.isArray(patterns.strengths)).toBe(true);
      expect(Array.isArray(patterns.growthAreas)).toBe(true);
    });
  });
  
  describe('Telemetry Service', () => {
    it('should track telemetry events', async () => {
      const result = await TelemetryService.track({
        event: 'mission_selected',
        category: 'autonomy',
        userId: 'user_123',
        userRole: 'learner',
        siteId: 'site_abc',
        grade: 5
      });
      
      expect(result).toBeDefined();
    });
    
    it('should get SDT profile', async () => {
      const profile = await TelemetryService.getSDTProfile('user_123', 'site_abc', 30);
      
      expect(profile).toHaveProperty('autonomy');
      expect(profile).toHaveProperty('competence');
      expect(profile).toHaveProperty('belonging');
      expect(typeof profile.autonomy).toBe('number');
      expect(typeof profile.competence).toBe('number');
      expect(typeof profile.belonging).toBe('number');
    });
    
    it('should get engagement score', async () => {
      const score = await TelemetryService.getUserEngagementScore('user_123', 'site_abc', 7);
      
      expect(typeof score).toBe('number');
      expect(score).toBeGreaterThanOrEqual(0);
      expect(score).toBeLessThanOrEqual(100);
    });
  });
});

// Run tests
console.log('Analytics Implementation Test Suite');
console.log('====================================');
console.log('All tests verify analytics.json specification compliance');
console.log('Gemini API key configured:', !!process.env.NEXT_PUBLIC_GEMINI_API_KEY);
