/**
 * Root schema re-export shim.
 *
 * Legacy code imports from '@/schema'. The canonical types live in
 * src/types/schema.ts. This file bridges the gap with compatibility aliases.
 *
 * New code should import from '@/src/types/schema' directly.
 */

// Core types with name aliases (old schema used different names)
export type { UserRole as Role } from '@/src/types/schema';
export type { UserProfile as User } from '@/src/types/schema';
export type { Enrolment as Enrollment } from '@/src/types/schema';
export type { Attendance as AttendanceRecord } from '@/src/types/schema';
export type { PortfolioItem as Portfolio } from '@/src/types/schema';

// Direct re-exports (same names in both schemas)
export type {
  Site,
  Session,
  SessionOccurrence,
  Mission,
  MissionPlan,
  MissionAttempt,
  PortfolioItem,
  ReportShareRequest,
  AccountabilityCycle,
  AccountabilityCommitment,
  AccountabilityReview,
  Stage,
  Capability,
  CapabilityMastery,
  CapabilityGrowthEvent,
  // Evidence chain types added in Sprint 1-5
  Badge,
  BadgeAward,
  AutonomyIntervention,
  ProofOfLearningBundle,
  SkillEvidence,
  MicroSkill,
  MissionVariant,
  Crew,
  Checkpoint,
  ReflectionEntry,
  AICoachInteraction,
  ShowcaseSubmission,
  WeeklyGoal,
  ParentSnapshot,
  PeerFeedback,
  MotivationAnalytics,
} from '@/src/types/schema';

// AuditLog — defined here as it has no canonical equivalent yet
export interface AuditLog {
  id: string;
  action: string;
  userId: string;
  targetId?: string;
  targetType?: string;
  metadata?: Record<string, unknown>;
  createdAt: unknown; // Timestamp
}
