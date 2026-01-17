/**
 * Motivation & Personalization Components
 * 
 * This module provides UI components for the learner motivation system.
 */

// Components
export { EducatorFeedbackForm } from './EducatorFeedbackForm';
export { MotivationNudges, NudgeIndicator } from './MotivationNudges';
export { ClassInsights, ClassInsightsCompact } from './ClassInsights';

// Re-export service and utilities
export {
  motivationEngine,
  MotivationEngineService,
  MOTIVATION_LABELS,
  MOTIVATION_EMOJI,
  ENGAGEMENT_COLORS,
  ENGAGEMENT_LABELS,
  formatInsight,
  type EducatorFeedbackInput,
  type SupportInterventionInput,
  type LearnerInteractionEvent,
  type ClassInsight,
} from '@/src/lib/motivation/motivationEngine';
