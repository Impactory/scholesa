/**
 * SDT (Self-Determination Theory) Components
 * 
 * Autonomy + Competence + Belonging = Intrinsic Motivation
 */

// Phase A: Must-have for flow and retention
export { StudentDashboard, StudentDashboardCompact } from './StudentDashboard';
export { LearningPathMap, LearningPathCompact } from './LearningPathMap';
export { AICoachScreen } from './AICoachScreen';
export { ReflectionJournal, QuickReflection } from './ReflectionJournal';

// Re-export SDT service
export {
  sdtMotivation,
  SDTMotivationService,
  DIFFICULTY_LABELS,
  DIFFICULTY_EMOJI,
  DIFFICULTY_COLORS,
  CREW_ROLE_LABELS,
  CREW_ROLE_EMOJI,
  RECOGNITION_LABELS,
  RECOGNITION_EMOJI,
  type MissionOption,
  type DashboardData,
  type LearningPathProgress,
  type ProgressInsights,
  type AICoachRequest,
  type AICoachResponse
} from '@/src/lib/motivation/sdtMotivation';
