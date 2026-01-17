import { Timestamp } from 'firebase/firestore';

export type UserRole = 'learner' | 'parent' | 'educator' | 'hq' | 'siteLead' | 'partner';
export type PillarCode = 'FUTURE_SKILLS' | 'LEADERSHIP_AGENCY' | 'IMPACT_INNOVATION';

export interface UserProfile {
  uid: string;
  email: string;
  displayName: string;
  role: UserRole;
  studioId?: string;
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
  pillarCodes: PillarCode[];
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

export interface MissionAttempt {
  id: string;
  learnerId: string;
  missionId: string;
  sessionOccurrenceId?: string;
  siteId: string;
  status: 'started' | 'submitted' | 'completed';
  content?: string; // Artifacts or submission text
  submittedAt: Timestamp;
  feedback?: string;
  gradedBy?: string;
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
  startDate: Timestamp;
  endDate: Timestamp;
  siteId: string;
  name: string; // e.g., "Week 1 - Term 2"
}

export interface AccountabilityKPI {
  id: string;
  cycleId: string;
  learnerId: string;
  attendancePct: number;
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
  title: string;
  description: string;
  pillarCodes: PillarCode[];
  artifacts: string[]; // URLs
  createdAt: Timestamp;
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
