/**
 * Analytics & Intelligence - Central Export
 * 
 * Implements the complete analytics.json specification:
 * - Event tracking (mission selection, checkpoints, AI usage, etc.)
 * - Computed metrics (pass rates, attempts to mastery, hint dependency)
 * - Insight rules (threshold-based + AI-powered via Gemini)
 * - Grade band policy integration
 * - SDT motivation profiling
 * - Personalized recommendations
 */

// Analytics Engine (implements analytics.json spec)
export {
  AnalyticsEngine,
  trackEvent,
  computeCheckpointPassRate,
  computeAttemptsToMastery,
  computeChoiceDistribution,
  computeHintDependencyIndex,
  computeExplainItBackCompliance,
  getInsights,
  generateAIInsights,
  type AnalyticsEventType,
  type MissionSelectedEvent,
  type SprintStartedEvent,
  type SprintEndedEvent,
  type CheckpointSubmittedEvent,
  type ArtifactUploadedEvent,
  type ReflectionSubmittedEvent,
  type RoleAssignedEvent,
  type RoleRotatedEvent,
  type AICoachUsedEvent,
  type ExplainItBackSubmittedEvent,
  type PeerFeedbackGivenEvent,
  type ComputedMetric,
  type ChoiceDistribution,
  type SDTScore,
  type InsightRule,
  type MissionLevel,
  type ArtifactType,
  type ReflectionFormat,
  type TeamRole,
  type AIMode
} from './analyticsEngine';

// Intelligence Service (unified telemetry + analytics + AI)
export {
  IntelligenceService,
  trackUnifiedEvent,
  getLearnerProfile,
  getClassInsights,
  generatePersonalizedRecommendations,
  detectLearningPatterns,
  type UnifiedEventPayload
} from './intelligenceService';

// Telemetry Service (SDT motivation tracking)
export {
  TelemetryService,
  trackPageView,
  trackAutonomy,
  trackCompetence,
  trackBelonging,
  trackReflection,
  trackAI,
  trackSession,
  trackPerformance,
  getUserEngagementScore,
  getSDTProfile,
  type TelemetryPayload,
  type TelemetryEvent,
  type TelemetryCategory
} from '../telemetry/telemetryService';
