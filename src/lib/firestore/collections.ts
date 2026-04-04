import { collection, CollectionReference, DocumentData } from 'firebase/firestore';
import { firestore } from '@/src/firebase/client-init';
import type {
  User,
  Site,
  Session,
  SessionOccurrence,
  Enrollment,
  AttendanceRecord,
  Mission,
  MissionPlan,
  MissionAttempt,
  Portfolio,
  PortfolioItem,
  AccountabilityCycle,
  AccountabilityKPI,
  AccountabilityCommitment,
  AccountabilityReview,
  AuditLog,
  Stage,
  Capability,
  CapabilityMastery,
  CapabilityGrowthEvent,
} from '@/schema';

import type {
  EducatorFeedback,
  LearnerMotivationProfile,
  LearnerInteraction,
  SupportIntervention,
  MotivationNudge,
  MotivationConfig,
  MicroSkill,
  MissionVariant,
  Crew,
  Badge,
  BadgeAward,
  SkillEvidence,
  SprintSession,
  Checkpoint,
  ShowcaseSubmission,
  ReflectionEntry,
  AICoachInteraction,
  WeeklyGoal,
  LearnerInterestProfile,
  ParentSnapshot,
  PeerFeedback,
  MotivationAnalytics
} from '@/src/types/schema';

import type { TelemetryEvent } from '@/src/lib/telemetry/sdtTelemetry';

// Helper to create a typed collection reference
const createCollection = <T = DocumentData>(collectionName: string) => {
  return collection(firestore, collectionName) as CollectionReference<T>;
};

// Core
export const usersCollection = createCollection<User>('users');
export const sitesCollection = createCollection<Site>('sites');

// Learning & Sessions
export const sessionsCollection = createCollection<Session>('sessions');
export const sessionOccurrencesCollection = createCollection<SessionOccurrence>('sessionOccurrences');
export const enrollmentsCollection = createCollection<Enrollment>('enrollments');
export const attendanceRecordsCollection = createCollection<AttendanceRecord>('attendanceRecords');

// Missions
export const missionsCollection = createCollection<Mission>('missions');
export const missionPlansCollection = createCollection<MissionPlan>('missionPlans');
export const missionAttemptsCollection = createCollection<Omit<MissionAttempt, 'id'>>('missionAttempts');

// Portfolio
export const portfoliosCollection = createCollection<Portfolio>('portfolios');
export const portfolioItemsCollection = createCollection<PortfolioItem>('portfolioItems');

// Accountability
export const accountabilityCyclesCollection = createCollection<AccountabilityCycle>('accountabilityCycles');
export const accountabilityKPIsCollection = createCollection<AccountabilityKPI>('accountabilityKPIs');
export const accountabilityCommitmentsCollection = createCollection<AccountabilityCommitment>('accountabilityCommitments');
export const accountabilityReviewsCollection = createCollection<AccountabilityReview>('accountabilityReviews');

// System
export const auditLogsCollection = createCollection<AuditLog>('auditLogs');

// Motivation & Personalization System
export const educatorFeedbackCollection = createCollection<EducatorFeedback>('educatorFeedback');
export const learnerMotivationProfilesCollection = createCollection<LearnerMotivationProfile>('learnerMotivationProfiles');
export const learnerInteractionsCollection = createCollection<LearnerInteraction>('learnerInteractions');
export const supportInterventionsCollection = createCollection<SupportIntervention>('supportInterventions');
export const motivationNudgesCollection = createCollection<MotivationNudge>('motivationNudges');
export const motivationConfigCollection = createCollection<MotivationConfig>('configs');

// SDT Framework Collections
export const microSkillsCollection = createCollection<MicroSkill>('microSkills');
export const missionVariantsCollection = createCollection<MissionVariant>('missionVariants');
export const crewsCollection = createCollection<Crew>('crews');
export const badgesCollection = createCollection<Badge>('badges');
export const badgeAwardsCollection = createCollection<BadgeAward>('badgeAwards');
export const skillEvidenceCollection = createCollection<SkillEvidence>('skillEvidence');
export const sprintSessionsCollection = createCollection<SprintSession>('sprintSessions');
export const checkpointsCollection = createCollection<Checkpoint>('checkpoints');
export const showcaseSubmissionsCollection = createCollection<ShowcaseSubmission>('showcaseSubmissions');
export const reflectionEntriesCollection = createCollection<ReflectionEntry>('reflectionEntries');
export const aiCoachInteractionsCollection = createCollection<AICoachInteraction>('aiCoachInteractions');
export const weeklyGoalsCollection = createCollection<WeeklyGoal>('weeklyGoals');
export const learnerInterestProfilesCollection = createCollection<LearnerInterestProfile>('learnerInterestProfiles');
export const parentSnapshotsCollection = createCollection<ParentSnapshot>('parentSnapshots');
export const peerFeedbackCollection = createCollection<PeerFeedback>('peerFeedback');
export const motivationAnalyticsCollection = createCollection<MotivationAnalytics>('motivationAnalytics');

// Capability Graph
export const stagesCollection = createCollection<Stage>('stages');
export const capabilitiesCollection = createCollection<Capability>('capabilities');
export const capabilityMasteryCollection = createCollection<CapabilityMastery>('capabilityMastery');
export const capabilityGrowthEventsCollection = createCollection<CapabilityGrowthEvent>('capabilityGrowthEvents');

// Telemetry
export const telemetryEventsCollection = createCollection<TelemetryEvent>('telemetryEvents');
