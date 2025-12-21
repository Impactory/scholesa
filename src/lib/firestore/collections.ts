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
  AuditLog
} from '@/schema';

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
export const missionAttemptsCollection = createCollection<MissionAttempt>('missionAttempts');

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