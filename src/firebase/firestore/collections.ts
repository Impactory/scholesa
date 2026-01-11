import { collection, CollectionReference, DocumentData } from 'firebase/firestore';
import { db } from '@/src/firebase/client-init';
import type {
  UserProfile,
  Site,
  Room,
  Program,
  Course,
  Mission,
  Enrolment,
  Session,
  SessionOccurrence,
  Attendance,
  MissionPlan,
  MissionAttempt,
  Reflection,
  AccountabilityCycle,
  AccountabilityKPI,
  AccountabilityCommitment,
  AccountabilityReview,
  Alert,
  Announcement,
  PortfolioItem,
} from '@/src/types/schema';

// Helper to create typed collection
const createCollection = <T = DocumentData>(collectionName: string) => {
  return collection(db, collectionName) as CollectionReference<T>;
};

// Define the collections
export const usersCollection = createCollection<UserProfile>('users');
export const sitesCollection = createCollection<Site>('sites');
export const roomsCollection = createCollection<Room>('rooms');
export const programsCollection = createCollection<Program>('programs');
export const coursesCollection = createCollection<Course>('courses');
export const missionsCollection = createCollection<Mission>('missions');
export const enrolmentsCollection = createCollection<Enrolment>('enrolments');
export const sessionsCollection = createCollection<Session>('sessions');
export const sessionOccurrencesCollection = createCollection<SessionOccurrence>('sessionOccurrences');
export const attendanceCollection = createCollection<Attendance>('attendance');
export const missionPlansCollection = createCollection<MissionPlan>('missionPlans');
export const missionAttemptsCollection = createCollection<MissionAttempt>('missionAttempts');
export const reflectionsCollection = createCollection<Reflection>('reflections');
export const accountabilityCyclesCollection = createCollection<AccountabilityCycle>('accountabilityCycles');
export const accountabilityKPIsCollection = createCollection<AccountabilityKPI>('accountabilityKPIs');
export const accountabilityCommitmentsCollection = createCollection<AccountabilityCommitment>('accountabilityCommitments');
export const accountabilityReviewsCollection = createCollection<AccountabilityReview>('accountabilityReviews');
export const alertsCollection = createCollection<Alert>('alerts');
export const announcementsCollection = createCollection<Announcement>('announcements');
export const portfolioItemsCollection = createCollection<PortfolioItem>('portfolioItems');
