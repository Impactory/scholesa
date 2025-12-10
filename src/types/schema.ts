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
  learnerId?: string; // Alias for userId for clarity in context
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
