import { Timestamp } from 'firebase/firestore';

export type UserRole = 'learner' | 'parent' | 'educator' | 'hq' | 'siteLead' | 'partner';
/**
 * Legacy three-family capability grouping retained for backward compatibility.
 * The canonical curriculum model is six strands defined in
 * `src/lib/curriculum/architecture.ts`.
 */
export type PillarCode = 'FUTURE_SKILLS' | 'LEADERSHIP_AGENCY' | 'IMPACT_INNOVATION';
export type CurriculumStrandId =
  | 'think'
  | 'make'
  | 'communicate'
  | 'lead'
  | 'navigate_ai'
  | 'build_for_the_world';
export type StageId = 'discoverers' | 'builders' | 'explorers' | 'innovators';
export type AiPolicyTier = 'A' | 'B' | 'C' | 'D';
export type UxComplexity = 'simple' | 'guided' | 'autonomous' | 'professional';

/**
 * Learning stage (grade band) — defines age-appropriate delivery, AI policy,
 * and UX complexity for a cohort of learners. Spec §7.
 */
export interface Stage {
  id: StageId;
  name: string;
  gradeRange: [number, number];
  description: string;
  focusAreas: string[];
  aiPolicyTier: AiPolicyTier;
  uxComplexity: UxComplexity;
  defaultSessionDuration: number; // minutes
}

export interface UserProfile {
  uid: string;
  email: string;
  displayName: string;
  role: UserRole;
  studioId?: string;
  stageId?: StageId; // Learner stage (grade band)
  linkedLearnerIds?: string[]; // For parents
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

export interface Site {
  id: string;
  name: string;
  location: string;
}

export interface Room {
  id: string;
  siteId: string;
  name: string;
  capacity: number;
}

export interface Program {
  id: string;
  name: string;
  description: string;
  studioId: string; // Deprecated in favor of siteId, keeping for backward compatibility if needed, but primary association should be clear
  siteId?: string;
  active: boolean;
}

export interface Course {
  id: string;
  programId: string;
  name: string;
  description: string;
  order: number;
}

export interface Mission {
  id: string;
  courseId: string;
  title: string;
  description?: string;
  content: string;
  xp: number;
  order: number;
  skills?: string[];
  pillarCodes: string[];
  capabilityIds?: string[]; // S2-1: linked capabilities from the graph
  stageId?: StageId; // Target stage for this mission
}

export interface Enrolment {
  id: string;
  userId: string;
  programId: string;
  courseId: string;
  status: 'active' | 'completed' | 'dropped';
  enrolledAt: Timestamp;
}

export interface Session {
  id: string;
  siteId: string;
  programId: string;
  educatorId: string;
  roomId?: string;
  startTime: Timestamp;
  endTime: Timestamp;
  dayOfWeek?: number; // 0-6
  stageId?: StageId; // Stage this session targets
  pillarCodes: string[]; // Pillar focus for session planning
}

export interface SessionOccurrence {
  id: string;
  sessionId: string;
  date: Timestamp;
  siteId: string;
  roomId: string;
  educatorId: string;
}

export interface Attendance {
  id: string;
  userId: string; // learnerId
  learnerId?: string; // Alias for clarity in context
  sessionOccurrenceId: string;
  studioId: string; // siteId
  date: Timestamp;
  status: 'present' | 'absent' | 'late';
  recordedBy: string; // educatorId
}

export interface MissionPlan {
  id: string;
  sessionOccurrenceId: string;
  educatorId: string;
  missions: string[]; // List of mission IDs
  pillarEmphasis: PillarCode[];
}

export interface RevisionHistoryEntry {
  round: number;
  educatorFeedback: string;
  educatorId: string;
  requestedAt: Timestamp;
  previousContent: string;
  resubmittedContent?: string;
  resubmittedAt?: Timestamp;
}

export interface MissionAttempt {
  id: string;
  learnerId: string;
  missionId: string;
  missionTitle?: string;
  sessionOccurrenceId?: string;
  siteId: string;
  status: 'started' | 'submitted' | 'pending_review' | 'reviewed' | 'completed' | 'revision';
  reviewStatus?: 'reviewed' | 'approved' | 'revision';
  content?: string; // Artifacts or submission text
  notes?: string;
  attachmentUrls?: string[];
  startedAt?: Timestamp;
  submittedAt?: Timestamp;
  reviewedAt?: Timestamp;
  updatedAt?: Timestamp;
  feedback?: string;
  gradedBy?: string;
  gradedAt?: Timestamp;
  reviewedBy?: string;
  reviewNotes?: string;
  proofBundleId?: string;
  aiAssistanceUsed?: boolean;
  aiAssistanceDetails?: string;
  aiDisclosureStatus?: string;
  revisionFeedback?: string;
  revisionRequestedBy?: string;
  revisionRequestedAt?: Timestamp;
  revisionHistory?: RevisionHistoryEntry[];
  revisionRound?: number;
}

export interface Reflection {
  id: string;
  userId: string;
  missionId?: string;
  content: string;
  createdAt: Timestamp;
  // Linking to weekly cycle
  cycleId?: string;
}

export interface AccountabilityCycle {
  id: string;
  startDate: number;
  endDate: number;
  siteId: string;
  name: string; // e.g., "Week 1 - Term 2"
  status: 'active' | 'closed';
}

/**
 * @deprecated LMS-shaped type — conflates attendance with mastery.
 * Migrate to CapabilityMastery + CapabilityGrowthEvent for evidence-based tracking.
 * Scheduled for removal in Sprint 2. See docs/ALIGNMENT_PLAN.md S0-2.
 */
export interface AccountabilityKPI {
  id: string;
  cycleId: string;
  learnerId: string;
  /** @deprecated Use CapabilityMastery instead of attendance metrics */
  attendancePct: number;
  /** @deprecated Use CapabilityMastery.currentLevel instead */
  missionsCompleted: number;
  pillarScores: Record<PillarCode, number>;
}

export interface AccountabilityCommitment {
  id: string;
  learnerId: string;
  cycleId: string;
  content: string;
  pillarCodes?: PillarCode[];
  createdAt: Timestamp;
}

export interface AccountabilityReview {
  id: string;
  learnerId: string;
  cycleId: string;
  content: string;
  createdAt: Timestamp;
}

export interface Alert {
  id: string;
  type: 'red-team' | 'incident' | 'safety';
  severity: 'low' | 'medium' | 'high';
  message: string;
  studioId: string;
  createdAt: Timestamp;
  resolved: boolean;
}

export interface Announcement {
  id: string;
  title: string;
  content: string;
  targetRole: UserRole | 'all';
  createdAt: Timestamp;
  authorId: string;
}

export interface PortfolioItem {
  id: string;
  learnerId: string;
  siteId?: string;
  title: string;
  description: string;
  pillarCodes: PillarCode[];
  artifacts: string[]; // URLs
  evidenceRecordIds?: string[];
  capabilityIds?: string[];
  capabilityTitles?: string[];
  reflectionIds?: string[]; // S1-6: linked ReflectionEntry documents
  growthEventIds?: string[];
  missionAttemptId?: string;
  checkpointDefinitionId?: string;
  rubricApplicationId?: string;
  proofBundleId?: string;
  proofOfLearningStatus?: 'not-available' | 'missing' | 'partial' | 'verified';
  proofHasExplainItBack?: boolean;
  proofHasOralCheck?: boolean;
  proofHasMiniRebuild?: boolean;
  proofCheckpointCount?: number;
  proofExplainItBackExcerpt?: string;
  proofOralCheckExcerpt?: string;
  proofMiniRebuildExcerpt?: string;
  aiAssistanceUsed?: boolean;
  aiAssistanceDetails?: string;
  aiDisclosureStatus?:
      | 'learner-ai-not-used'
      | 'learner-ai-verified'
      | 'learner-ai-verification-gap'
      | 'educator-feedback-ai'
      | 'no-learner-ai-signal'
      | 'not-available';
  educatorId?: string;
  verificationPrompt?: string;
  verificationNotes?: string;
  verificationStatus?: 'pending' | 'reviewed' | 'verified';
  source?: string;
  createdAt: Timestamp;
}

export type ReportShareRequestStatus = 'active' | 'revoked' | 'expired';
export type ReportShareRequestAction = 'share' | 'export_text' | 'export_html' | 'export_pdf';
export type ReportShareRequestDelivery =
  | 'shared'
  | 'copied'
  | 'downloaded'
  | 'unavailable'
  | 'aborted'
  | 'contract-failed';
export type ReportShareRequestAudience =
  | 'learner'
  | 'guardian'
  | 'educator'
  | 'site'
  | 'hq'
  | 'partner'
  | 'external';
export type ReportShareRequestVisibility =
  | 'private'
  | 'family'
  | 'staff'
  | 'site'
  | 'external'
  | 'public';

export interface ReportShareRequest {
  id: string;
  siteId: string;
  learnerId: string;
  createdBy: string;
  createdByRole: UserRole | 'site';
  status: ReportShareRequestStatus;
  reportAction: ReportShareRequestAction;
  reportDelivery?: ReportShareRequestDelivery;
  audience: ReportShareRequestAudience;
  visibility: ReportShareRequestVisibility;
  source?: string;
  surface?: string;
  cta?: string;
  fileName?: string;
  sharePolicy: {
    requiresEvidenceProvenance: boolean;
    requiresGuardianContext: boolean;
    allowsExternalSharing: boolean;
    includesLearnerIdentifiers: boolean;
  };
  provenance: {
    expectedSignals: string[];
    missingSignals: string[];
    meetsProvenanceContract: boolean;
    meetsDeliveryContract: boolean;
    sharePolicyDeclared: boolean;
  };
  deliveryAuditId?: string;
  expiresAt: Timestamp;
  revokedAt?: Timestamp;
  revokedBy?: string;
  revocationReason?: string;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

export interface EnterpriseSsoProvider {
  id: string;
  providerId: string;
  providerType: 'oidc' | 'saml';
  displayName: string;
  siteIds: string[];
  defaultSiteId?: string;
  defaultRole: 'learner' | 'parent' | 'educator' | 'site' | 'partner' | 'hq';
  allowedDomains?: string[];
  organizationId?: string;
  buttonText?: string;
  jitProvisioning: boolean;
  enabled: boolean;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

export type IntegrationProvider = 'google_classroom' | 'github' | 'lti_1p3' | 'clever' | 'classlink';
export type IntegrationStatus = 'active' | 'pending' | 'revoked' | 'error';

export interface IntegrationConnection {
  id: string;
  ownerUserId: string;
  provider: IntegrationProvider;
  status: IntegrationStatus;
  siteId?: string;
  scopesGranted?: string[];
  tokenRef?: string;
  lastError?: string;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

export interface ExternalCourseLink {
  id: string;
  provider: IntegrationProvider;
  providerCourseId: string;
  ownerUserId: string;
  siteId: string;
  sessionId: string;
  syncPolicy?: 'manual' | 'daily' | 'weekly';
  lastRosterSyncAt?: Timestamp;
  lastCourseworkSyncAt?: Timestamp;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

export interface ExternalUserLink {
  id: string;
  provider: IntegrationProvider;
  providerUserId: string;
  scholesaUserId: string;
  siteId: string;
  roleHint?: 'learner' | 'educator';
  matchSource?: 'email' | 'manual' | 'sis';
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

export interface SyncJob {
  id: string;
  type: string;
  requestedBy: string;
  status: 'queued' | 'running' | 'failed' | 'completed';
  siteId?: string;
  provider?: IntegrationProvider;
  jobType?: string;
  cursor?: string;
  nextPageToken?: string;
  lastError?: string;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

export interface SyncCursor {
  id: string;
  ownerUserId: string;
  provider: IntegrationProvider;
  providerCourseId: string;
  cursorType: 'roster' | 'coursework' | 'submissions';
  nextPageToken?: string;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

export interface ExternalIdentityLink {
  id: string;
  siteId: string;
  provider: 'google_classroom' | 'github' | 'clever' | 'classlink';
  providerUserId: string;
  scholesaUserId?: string;
  status: 'unmatched' | 'linked' | 'ignored' | 'held';
  suggestedMatches?: Array<{ scholesaUserId: string; reason: string; confidence: 'low' | 'med' | 'high' }>;
  approvedBy?: string;
  approvedAt?: Timestamp;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

export interface LtiPlatformRegistration {
  id: string;
  siteId: string;
  issuer: string;
  clientId: string;
  deploymentId: string;
  authLoginUrl: string;
  accessTokenUrl: string;
  jwksUrl: string;
  ownerUserId: string;
  status: 'active' | 'paused' | 'revoked';
  platformName?: string;
  lineItemsScope?: boolean;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

export interface LtiResourceLink {
  id: string;
  registrationId: string;
  siteId: string;
  resourceLinkId: string;
  title?: string;
  missionId?: string;
  sessionId?: string;
  locale?: string;
  targetPath?: string;
  lineItemId?: string;
  lineItemUrl?: string;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

export interface LtiGradePassbackJob {
  id: string;
  siteId: string;
  learnerId: string;
  missionAttemptId: string;
  requestedBy: string;
  lineItemId?: string;
  lineItemUrl?: string;
  scoreGiven: number;
  scoreMaximum: number;
  activityProgress: 'Initialized' | 'Started' | 'InProgress' | 'Submitted' | 'Completed';
  gradingProgress: 'Pending' | 'PendingManual' | 'FullyGraded' | 'Failed';
  status: 'queued' | 'running' | 'failed' | 'completed';
  idempotencyKey: string;
  lastError?: string;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

// --- Motivation & Personalization System ---

/**
 * Motivation types that work for different learners
 */
export type MotivationType = 
  | 'achievement'      // Loves completing tasks and earning rewards
  | 'social'           // Motivated by collaboration and recognition
  | 'mastery'          // Driven by learning and skill development
  | 'autonomy'         // Wants choice and self-direction
  | 'purpose'          // Motivated by real-world impact
  | 'competition'      // Thrives on challenges and leaderboards
  | 'creativity';      // Loves self-expression and projects

/**
 * Engagement states based on observed patterns
 */
export type EngagementLevel = 'thriving' | 'engaged' | 'coasting' | 'struggling' | 'at-risk';

/**
 * Tracks interaction patterns with the app
 */
export interface InteractionPattern {
  avgSessionDurationMinutes: number;
  preferredTimeOfDay: 'morning' | 'afternoon' | 'evening';
  mostActiveDay: number; // 0-6 (Sunday-Saturday)
  missionsCompletedPerWeek: number;
  reflectionResponseRate: number; // 0-1
  appOpenFrequency: number; // times per week
  streakDays: number;
  longestStreak: number;
  pauseBeforeSubmit: boolean; // Takes time to review work
  seeksHelpFrequency: number; // times per week
  portfolioContributions: number; // items added
}

/**
 * Educator observation about a learner's motivation
 */
export interface EducatorFeedback {
  id: string;
  learnerId: string;
  educatorId: string;
  siteId: string;
  sessionOccurrenceId?: string;
  
  // Structured observations
  engagementLevel: 1 | 2 | 3 | 4 | 5; // 1=disengaged, 5=highly engaged
  participationType: 'leader' | 'active' | 'quiet' | 'observer' | 'reluctant';
  respondedWellTo: MotivationType[];
  struggledWith?: string;
  
  // What worked for this learner today
  effectiveStrategies: MotivationStrategy[];
  
  // Free-form notes
  notes?: string;
  
  // Celebration moments
  highlights?: string[];
  
  createdAt: Timestamp;
}

/**
 * Strategies that can motivate learners
 */
export interface MotivationStrategy {
  type: MotivationType;
  strategy: string;        // e.g., "Give choice between 2 missions"
  effectiveness: number;   // 0-1 based on outcomes
  lastUsedAt?: Timestamp;
  usageCount: number;
}

/**
 * Learner's motivation profile - learned over time
 */
export interface LearnerMotivationProfile {
  id: string;
  learnerId: string;
  siteId: string;
  
  // Primary motivation types (top 3, in order)
  primaryMotivators: MotivationType[];
  
  // Confidence in each motivation type (0-1)
  motivatorConfidence: Record<MotivationType, number>;
  
  // Current engagement state
  currentEngagement: EngagementLevel;
  engagementTrend: 'improving' | 'stable' | 'declining';
  
  // Interaction patterns from app usage
  interactionPatterns: InteractionPattern;
  
  // Effective strategies that have worked
  effectiveStrategies: MotivationStrategy[];
  
  // Personalized nudge preferences
  preferredNudgeTime?: string; // HH:MM format
  nudgeFrequency: 'often' | 'moderate' | 'minimal';
  respondsToBadges: boolean;
  respondsToStreaks: boolean;
  respondsToSocialProof: boolean;
  
  // Pillar-specific engagement
  pillarEngagement: Record<PillarCode, {
    interest: number;      // 0-1
    performance: number;   // 0-1
    growth: number;        // change over last 30 days
  }>;
  
  // Computed insights
  insights: MotivationInsight[];
  
  // Last updated timestamps
  lastInteractionUpdate: Timestamp;
  lastEducatorFeedback: Timestamp;
  lastComputedAt: Timestamp;
  
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

/**
 * An actionable insight derived from motivation data
 */
export interface MotivationInsight {
  id: string;
  type: 'strength' | 'opportunity' | 'warning' | 'celebration';
  title: string;
  description: string;
  confidence: number; // 0-1
  basedOn: string[];  // What signals led to this insight
  suggestedActions: string[];
  expiresAt?: Timestamp;
  createdAt: Timestamp;
}

/**
 * Individual learner interaction event (aggregated for privacy)
 */
export interface LearnerInteraction {
  id: string;
  learnerId: string;
  siteId: string;
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
  metadata?: {
    durationSeconds?: number;
    missionId?: string;
    pillarCode?: PillarCode;
    difficultyLevel?: string;
    timeToComplete?: number;
    helpType?: string;
    nudgeType?: string;
  };
  timestamp: Timestamp;
}

/**
 * Support intervention logged by educator
 */
export interface SupportIntervention {
  id: string;
  learnerId: string;
  educatorId: string;
  siteId: string;
  sessionOccurrenceId?: string;
  
  // What strategy was tried
  strategyType: MotivationType;
  strategyDescription: string;
  
  // Context
  context: 'group' | 'individual' | 'peer-supported';
  triggerReason?: string; // Why intervention was needed
  
  // Outcome
  outcome: 'helped' | 'partial' | 'no-change' | 'backfired';
  learnerResponse?: 'positive' | 'neutral' | 'resistant';
  
  // Notes for future reference
  notes?: string;
  recommendForFuture: boolean;
  
  createdAt: Timestamp;
}

/**
 * S5-1: MiloOS autonomy intervention trigger.
 * Records when the BOS runtime detects autonomy risk and triggers
 * an intervention for a learner. Append-only for audit trail.
 * Collection: autonomyInterventions
 */
export interface AutonomyIntervention {
  id: string;
  learnerId: string;
  siteId: string;
  sessionId?: string;

  // Risk signals that triggered this intervention
  riskSignals: Array<{
    signal: 'heavy_ai_use' | 'rapid_submit' | 'verification_gap' | 'repeated_hints_no_attempt' | 'low_integrity_state';
    score: number;
  }>;
  totalRiskScore: number;

  // Intervention decision (from BOS runtime)
  interventionType: 'nudge' | 'scaffold' | 'handoff' | 'revisit' | 'pace';
  salience: 'low' | 'medium' | 'high';
  reasonCodes: string[];

  // Whether MVL (minimum viable learning) gate was activated
  mvlGateTriggered: boolean;

  // Outcome (filled in later)
  outcome?: 'resolved' | 'escalated' | 'dismissed';
  resolvedAt?: Timestamp;

  createdAt: Timestamp;
}

/**
 * Personalized nudge for a learner
 */
export interface MotivationNudge {
  id: string;
  learnerId: string;
  siteId: string;
  
  // Nudge content
  type: 'reminder' | 'celebration' | 'challenge' | 'encouragement' | 'tip';
  title: string;
  message: string;
  
  // Personalization
  motivationTypeTarget: MotivationType;
  priority: 'low' | 'medium' | 'high';
  
  // Timing
  scheduledFor?: Timestamp;
  expiresAt?: Timestamp;
  
  // State
  status: 'pending' | 'shown' | 'accepted' | 'dismissed' | 'snoozed' | 'expired';
  shownAt?: Timestamp;
  respondedAt?: Timestamp;
  
  // Tracking
  generatedBy: 'system' | 'educator' | 'ai-draft';
  basedOnInsights?: string[]; // insight IDs
  
  createdAt: Timestamp;
}

/**
 * Configuration for motivation strategies
 */
export interface MotivationConfig {
  id: string; // 'default' or siteId for site-specific
  
  // Strategy templates by motivation type
  strategyTemplates: Record<MotivationType, {
    nudgeMessages: string[];
    celebrationMessages: string[];
    challengePrompts: string[];
    reminderStyles: string[];
  }>;
  
  // Engagement thresholds
  engagementThresholds: {
    thriving: { minAttendance: number; minMissionsPerWeek: number; minReflectionRate: number };
    engaged: { minAttendance: number; minMissionsPerWeek: number; minReflectionRate: number };
    coasting: { minAttendance: number; minMissionsPerWeek: number; minReflectionRate: number };
    struggling: { minAttendance: number; minMissionsPerWeek: number; minReflectionRate: number };
  };
  
  // Nudge limits to prevent over-messaging
  nudgeLimits: {
    maxPerDay: number;
    maxPerWeek: number;
    cooldownMinutes: number;
  };
  
  updatedAt: Timestamp;
  updatedBy: string;
}

// --- Self-Determination Theory (SDT) Framework ---

/**
 * Difficulty level for missions (Bronze/Silver/Gold)
 */
export type DifficultyLevel = 'bronze' | 'silver' | 'gold';

/**
 * Crew role types for team learning
 */
export type CrewRole = 'builder' | 'tester' | 'reporter';

/**
 * Recognition token types
 */
export type RecognitionType = 'helper' | 'debugger' | 'clear_communicator' | 'courage_to_try';

/**
 * Age bands for developmental appropriateness
 */
export type AgeBand = 'grades_1_3' | 'grades_4_6' | 'grades_7_9' | 'grades_10_12';

/**
 * Micro-skill that can be proven with evidence
 */
export interface MicroSkill {
  id: string;
  siteId: string;
  name: string;
  description: string;
  pillarCode: PillarCode;
  courseId?: string;
  
  // What evidence proves mastery
  evidenceTypes: ('upload' | 'quiz' | 'demo' | 'version_history' | 'peer_review')[];
  
  // Success criteria
  successCriteria: string;
  
  // Rubric simplified for students
  rubric?: {
    proficient: string;
    developing: string;
    emerging: string;
  };
  
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

/**
 * Mission variant with difficulty level (autonomy)
 */
export interface MissionVariant {
  id: string;
  baseMissionId: string; // Links to the original Mission
  siteId: string;
  
  difficultyLevel: DifficultyLevel;
  title: string;
  description: string;
  successCriterion: string; // "Done looks like..."
  
  // Different theme/tool/context
  theme?: string; // e.g., 'sports', 'music', 'gaming', 'environment'
  estimatedMinutes: number;
  
  // Skills this variant proves
  microSkillIds: string[];
  
  createdAt: Timestamp;
  updatedBy: string;
}

/**
 * Crew (stable team for 4-8 sessions)
 */
export interface Crew {
  id: string;
  siteId: string;
  name: string;
  
  // Members
  learnerIds: string[];
  
  // Team structure
  currentRoles: Record<string, CrewRole>; // learnerId -> role
  roleRotationSchedule?: Timestamp[]; // When to rotate
  
  // Active period
  startDate: Timestamp;
  endDate?: Timestamp;
  sessionCount: number; // How many sessions together
  
  // Team goals
  weeklyGoal?: string;
  
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

/**
 * Evidence-based badge
 */
export interface Badge {
  id: string;
  siteId: string;
  name: string;
  description: string;
  iconUrl?: string;

  // What proves this badge
  requiredMicroSkillIds: string[];
  requiredEvidenceCount: number; // How many pieces of evidence needed

  // S3-2: Capability mastery threshold for auto-issuance
  requiredCapabilityId?: string;
  requiredMasteryLevel?: MasteryLevel;

  pillarCode?: PillarCode;

  createdAt: Timestamp;
}

/**
 * Peer recognition record stored in recognitionBadges by legacy belonging surfaces.
 */
export interface RecognitionBadge {
  id: string;
  recipientId: string;
  giverId: string;
  giverName: string;
  siteId: string;
  studioId?: string;
  sessionOccurrenceId?: string;
  recognitionType: RecognitionType;
  message: string;
  isPublic: boolean;
  createdAt: Timestamp;
}

/**
 * Badge award to a learner
 */
export interface BadgeAward {
  id: string;
  badgeId: string;
  learnerId: string;
  siteId: string;
  
  // Evidence that earned this badge
  evidenceIds: string[]; // References to SkillEvidence
  
  awardedAt: Timestamp;
  awardedBy?: string; // educatorId or 'system'
}

/**
 * Skill evidence submission
 */
export interface SkillEvidence {
  id: string;
  learnerId: string;
  siteId: string;
  microSkillId: string;
  
  // What was submitted
  evidenceType: 'upload' | 'quiz' | 'demo' | 'version_history' | 'peer_review';
  artifactUrl?: string;
  description: string;
  locationInWork?: string; // "Where in my work is it?"
  
  // Self-assessment
  selfScore?: 'emerging' | 'developing' | 'proficient';
  
  // Teacher feedback
  teacherScore?: 'emerging' | 'developing' | 'proficient';
  teacherFeedback?: string;
  teacherFeedbackAt?: Timestamp;
  teacherFeedbackBy?: string;
  
  // Status
  status: 'submitted' | 'approved' | 'needs_revision';

  // AI disclosure (S1-7)
  aiAssistanceUsed?: boolean;
  aiAssistanceDetails?: string;

  submittedAt: Timestamp;
  updatedAt: Timestamp;
}

/**
 * Proof-of-learning bundle — learner-assembled proof linking
 * portfolio items to verification methods (ExplainItBack, OralCheck, MiniRebuild).
 * Collection: proofOfLearningBundles
 */
export interface ProofOfLearningBundle {
  id: string;
  learnerId: string;
  portfolioItemId: string;
  siteId?: string;
  capabilityId?: string;

  // Three verification methods
  hasExplainItBack: boolean;
  hasOralCheck: boolean;
  hasMiniRebuild: boolean;

  // Excerpts / evidence from each method
  explainItBackExcerpt?: string;
  oralCheckExcerpt?: string;
  miniRebuildExcerpt?: string;

  // Verification status (derived from methods present)
  verificationStatus: 'missing' | 'partial' | 'pending_review' | 'verified';
  educatorVerifierId?: string;

  version: number;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

/**
 * Sprint session (15-30 min focused work)
 */
export interface SprintSession {
  id: string;
  learnerId: string;
  siteId: string;
  sessionOccurrenceId?: string;
  
  // What they're working on
  missionVariantId: string;
  difficultyLevel: DifficultyLevel;
  
  // Sprint timing
  startedAt: Timestamp;
  targetEndAt: Timestamp;
  actualEndAt?: Timestamp;
  
  // Progress
  checkpointsPassed: number;
  totalCheckpoints: number;
  
  // Artifact
  artifactUrl?: string;
  showcaseReady: boolean;
  
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

/**
 * Canonical checkpoint definition authored by HQ and reused at runtime.
 * Collection: checkpoints
 */
export interface Checkpoint {
  id: string;
  siteId: string;
  capabilityId: string;
  capabilityTitle?: string;
  pillarCode?: PillarCode;
  missionId?: string;
  missionTitle?: string;
  title: string;
  description?: string;
  checkpointNumber?: number;
  status: 'active' | 'archived';
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

/**
 * Showcase submission (belonging)
 */
export interface ShowcaseSubmission {
  id: string;
  learnerId: string;
  siteId: string;
  learnerName?: string;
  crewId?: string;
  
  // What they're showcasing
  sprintSessionId?: string;
  title: string;
  artifactType: 'photo' | 'screenshot' | 'video' | 'code' | 'document';
  artifactUrl: string;
  description: string;
  
  // Micro-skills demonstrated
  microSkillIds: string[];
  
  // Recognition received
  recognitions: {
    fromUserId: string;
    recognitionType: RecognitionType;
    comment?: string;
    createdAt: Timestamp;
  }[];
  
  // Visibility
  visibility?: 'site' | 'program' | 'public';
  visibleToCrew: boolean;
  visibleToSite: boolean;

  // Optional linkage + engagement metadata used by showcase surfaces
  artifactId?: string;
  caption?: string;
  missionId?: string | null;
  attemptId?: string | null;
  submittedAt?: Timestamp;
  viewCount?: number;
  likeCount?: number;
  commentCount?: number;
  likes?: number;
  comments?: unknown[];

  // AI disclosure (S1-7)
  aiAssistanceUsed?: boolean;
  aiAssistanceDetails?: string;

  createdAt: Timestamp;
  updatedAt: Timestamp;
}

/**
 * Reflection entry (identity building)
 */
export interface ReflectionEntry {
  id: string;
  learnerId: string;
  siteId: string;
  
  // Context
  sprintSessionId?: string;
  missionId?: string;
  cycleId?: string; // Weekly cycle
  portfolioItemId?: string; // S1-6: back-link to the portfolio item this reflects on
  
  // Core prompts
  proudOf: string; // "I'm proud of..."
  nextIWill: string; // "Next I will..."
  
  // Optional emoji scale
  effortLevel?: 1 | 2 | 3 | 4 | 5;
  enjoymentLevel?: 1 | 2 | 3 | 4 | 5;
  
  // What strategy worked
  effectiveStrategy?: string;

  // AI disclosure (S1-7)
  aiAssistanceUsed?: boolean;
  aiAssistanceDetails?: string;

  createdAt: Timestamp;
}

/**
 * AI help interaction log
 */
export interface AICoachInteraction {
  id: string;
  learnerId: string;
  siteId: string;
  sprintSessionId?: string;
  
  // Which mode used
  mode: 'hint' | 'rubric_check' | 'debug';
  
  // Conversation
  studentQuestion: string;
  aiResponse: string;
  
  // Guardrails
  explainItBackRequired: boolean;
  explainItBackProvided?: string;
  explainItBackApproved?: boolean;
  
  // Version history check (anti-cheating)
  versionHistoryChecked: boolean;
  
  createdAt: Timestamp;
}

/**
 * Weekly goal (autonomy)
 */
export interface WeeklyGoal {
  id: string;
  learnerId: string;
  siteId: string;
  cycleId: string;
  
  goalType: 'try_stretch' | 'give_feedback' | 'revise_twice' | 'custom';
  goalText: string;
  
  // Progress
  targetCount?: number;
  currentCount: number;
  completed: boolean;
  
  createdAt: Timestamp;
  completedAt?: Timestamp;
}

/**
 * Interest profile (for mission skinning)
 */
export interface LearnerInterestProfile {
  id: string;
  learnerId: string;
  siteId: string;
  
  interests: string[]; // 'sports', 'music', 'gaming', 'environment', 'art', etc.
  preferredDifficultyLevel?: DifficultyLevel;
  
  // History tracking
  difficultyChoiceHistory: {
    date: Timestamp;
    level: DifficultyLevel;
  }[];
  
  updatedAt: Timestamp;
}

/**
 * @deprecated LMS-shaped type — skillsImproved has no evidence provenance.
 * Migrate to buildParentLearnerSummary() which reads from CapabilityMastery,
 * CapabilityGrowthEvent, and PortfolioItem with proof-of-learning linkage.
 * Scheduled for removal in Sprint 2. See docs/ALIGNMENT_PLAN.md S0-2.
 */
export interface ParentSnapshot {
  id: string;
  learnerId: string;
  parentId: string;
  siteId: string;
  cycleId: string;

  // Summary
  whatTheyBuilt: string[];
  /** @deprecated No evidence provenance — use CapabilityGrowthEvent instead */
  skillsImproved: string[];
  howToSupportAtHome: string[];

  // Stats
  /** @deprecated Use CapabilityMastery for evidence-backed metrics */
  attendanceThisWeek: number;
  /** @deprecated Use CapabilityMastery for evidence-backed metrics */
  missionsCompleted: number;
  badgesEarned: number;

  // Highlights
  showcaseHighlight?: {
    title: string;
    artifactUrl: string;
    description: string;
  };

  createdAt: Timestamp;
}

/**
 * Peer feedback
 */
export interface PeerFeedback {
  id: string;
  fromLearnerId: string;
  fromLearnerName?: string;
  toLearnerId: string;
  siteId: string;
  
  // What they're giving feedback on
  showcaseSubmissionId?: string;
  
  // Structured feedback
  iLike: string;
  iWonder: string;
  nextStep: string;
  
  // Safety
  flagged: boolean;
  flagReason?: string;
  moderatedBy?: string;
  moderatedAt?: Timestamp;

  // Legacy compatibility fields (kept until old records are fully migrated)
  giverId?: string;
  recipientId?: string;
  authorId?: string;
  targetLearnerId?: string;
  feedbackText?: string;
  artifactId?: string;
  missionId?: string | null;
  feedback?: string;
  stars?: number;
  status?: string;
  targetId?: string;
  targetType?: 'showcase' | 'mission' | 'other';

  // AI disclosure (S1-7)
  aiAssistanceUsed?: boolean;
  aiAssistanceDetails?: string;

  createdAt: Timestamp;
  updatedAt?: Timestamp;
}

/**
 * Learner profile record used by provisioning and workflow data forms.
 */
export interface LearnerProfile {
  id: string;
  siteId: string;
  learnerId: string;
  userId: string;
  displayName: string;
  email: string;
  gradeLevel?: number;
  notes?: string;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

/**
 * Motivation analytics (what to track)
 */
export interface MotivationAnalytics {
  id: string;
  learnerId: string;
  siteId: string;
  cycleId: string;
  
  // Key metrics
  proofOfLearningRate: number; // % of sessions with artifact + reflection
  checkpointPassRate: number; // % passed on first attempt
  averageAttemptsToMastery: number;
  revisionsPerProject: number;
  
  // Belonging signals
  peerFeedbackGiven: number;
  roleRotationCompletions: number;
  recognitionsReceived: number;
  
  // Autonomy signals
  choiceDistribution: Record<DifficultyLevel, number>;
  selfSelectedChallengeChanges: number;

  createdAt: Timestamp;
  updatedAt: Timestamp;
}

// ═══════════════════════════════════════════════════════════════════════════
// Capability Graph — core types for the capability-first evidence chain
// ═══════════════════════════════════════════════════════════════════════════

export type MasteryLevel = 'emerging' | 'developing' | 'proficient' | 'advanced';

/**
 * A capability definition within the Scholesa framework.
 * Collection: capabilities (HQ-only write, all read)
 */
export interface ProgressionDescriptors {
  beginning: string;
  developing: string;
  proficient: string;
  advanced: string;
}

export interface CheckpointMapping {
  label: string;
  checkpointId?: string;
  description?: string;
  missionId?: string;
  missionTitle?: string;
  checkpointNumber?: number;
}

export interface RubricTemplateCriterion {
  id: string;
  label: string;
  capabilityId: string;
  pillarCode: PillarCode;
  maxScore: number;
  descriptors?: ProgressionDescriptors;
  processDomainId?: string;
}

export interface RubricTemplate {
  id: string;
  /** Display title of the rubric template */
  title: string;
  /** @deprecated Use title instead */
  name?: string;
  siteId: string;
  capabilityIds: string[];
  criteria: RubricTemplateCriterion[];
  status?: 'draft' | 'published' | 'archived';
  createdBy?: string;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

export interface EvidenceRecord {
  id: string;
  learnerId: string;
  educatorId: string;
  siteId: string;
  sessionOccurrenceId?: string;
  capabilityId?: string;
  capabilityMapped?: boolean;
  phaseKey?: string;
  description: string;
  rubricStatus?: 'pending' | 'applied' | 'linked';
  growthStatus?: 'pending' | 'recorded' | 'updated';
  portfolioCandidate?: boolean;
  createdAt: Timestamp;
  updatedAt?: Timestamp;
}

export interface RubricApplication {
  id: string;
  learnerId: string;
  educatorId: string;
  siteId: string;
  rubricTemplateId: string;
  evidenceRecordIds: string[];
  scores: Array<{ criterionId: string; score: number; capabilityId: string }>;
  status: 'pending' | 'applied' | 'growth-recorded';
  capabilityId?: string;
  missionAttemptId?: string;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

export interface LearnerReflection {
  id: string;
  learnerId: string;
  siteId: string;
  content: string;
  capabilityIds?: string[];
  pillarCodes?: string[];
  missionAttemptId?: string;
  portfolioItemId?: string;
  aiAssistanceUsed?: boolean;
  createdAt: Timestamp;
}

export interface ProcessDomain {
  id: string;
  title: string;
  descriptor?: string;
  siteId: string;
  pillarCode?: string;
  progressionDescriptors?: ProgressionDescriptors;
  sortOrder?: number;
  status?: 'active' | 'archived';
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

export interface ProcessDomainMastery {
  id?: string;
  learnerId: string;
  processDomainId: string;
  siteId: string;
  currentLevel: MasteryLevel;
  latestLevel: MasteryLevel;
  previousLevel?: MasteryLevel;
  evidenceCount: number;
  lastAssessedBy: string;
  lastAssessedAt: Timestamp;
  updatedAt: Timestamp;
}

export interface ProcessDomainGrowthEvent {
  id: string;
  learnerId: string;
  processDomainId: string;
  level: MasteryLevel;
  fromLevel: MasteryLevel | null;
  toLevel: MasteryLevel;
  educatorId: string;
  siteId: string;
  evidenceIds: string[];
  createdAt: Timestamp;
}

export interface Capability {
  id: string;
  name: string;
  title?: string; // Alias for name — used by some surfaces
  normalizedTitle?: string;
  domain: 'technical' | 'human';
  pillarCode: PillarCode;
  description: string;
  descriptor?: string; // Short one-line description for UI display
  siteId?: string;
  progressionDescriptors?: ProgressionDescriptors;
  rubricTemplateId?: string;
  sortOrder?: number;
  status?: 'active' | 'archived';
  stageId?: StageId;
  prerequisites?: string[];
  iCanStatements?: Record<MasteryLevel, string>;
  teacherLookFors?: string[];
  unitMappings?: string[];
  checkpointMappings?: CheckpointMapping[];
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

/**
 * Current mastery level of a learner for a specific capability.
 * Collection: capabilityMastery (doc ID: learnerId_capabilityId)
 */
export interface CapabilityMastery {
  id?: string;
  learnerId: string;
  capabilityId: string;
  pillarCode?: string;
  currentLevel: MasteryLevel;
  latestLevel: MasteryLevel;
  previousLevel?: MasteryLevel;
  evidenceCount: number;
  evidenceIds?: string[];
  lastAssessedBy: string;
  lastAssessedAt: Timestamp;
  updatedAt: Timestamp;
}

/**
 * Immutable growth event recording a mastery level change.
 * Collection: capabilityGrowthEvents (educator create-only, append-only)
 */
export interface CapabilityGrowthEvent {
  id: string;
  learnerId: string;
  capabilityId: string;
  level: MasteryLevel;
  fromLevel: MasteryLevel | null;
  toLevel: MasteryLevel;
  educatorId: string;
  siteId: string;
  rubricApplicationId?: string;
  evidenceIds: string[];
  linkedEvidenceRecordIds?: string[];
  linkedPortfolioItemIds?: string[];
  rawScore?: number;
  maxScore?: number;
  createdAt: Timestamp;
}
