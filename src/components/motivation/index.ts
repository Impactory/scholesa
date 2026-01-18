/**
 * Motivation & Personalization Components
 * 
 * This module provides UI components for the learner motivation system.
 */

// Components
export { EducatorFeedbackForm } from './EducatorFeedbackForm';
export { MotivationNudges, NudgeIndicator } from './MotivationNudges';
export { ClassInsights, ClassInsightsCompact } from './ClassInsights';

// Re-export engines from motivationEngine
export {
  AutonomyEngine,
  CompetenceEngine,
  BelongingEngine,
  ReflectionEngine,
  getMissionChoices,
  recordMissionSelection,
  setLearnerGoal,
  updateLearnerInterests,
  recordSkillEvidence,
  recordCheckpointPassed,
  awardBadge,
  getMasteryDashboard,
  giveRecognition,
  submitToShowcase,
  givePeerFeedback,
  getRecognitionReceived,
  getReflectionPrompts,
  submitReflection,
  rateEffort,
  rateEnjoyment,
  getReflectionHistory,
} from '@/src/lib/motivation/motivationEngine';
