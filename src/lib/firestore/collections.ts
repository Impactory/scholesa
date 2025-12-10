import { collection, CollectionReference, DocumentData } from 'firebase/firestore';
import { firestore } from '@/src/lib/firebase/client';
import { 
  UserProfile, 
  Program, 
  Course, 
  Mission, 
  Enrolment, 
  Attendance, 
  Reflection, 
  Alert, 
  Announcement,
  Session,
  SessionOccurrence,
  MissionPlan,
  MissionAttempt,
  AccountabilityCommitment,
  AccountabilityReview,
  PortfolioItem,
  Site,
  Room
} from '@/src/types/schema';

// Helper to create collection references with types
const createCollection = <T = DocumentData>(collectionName: string) => {
  return collection(firestore, collectionName) as CollectionReference<T>;
};

export const usersCollection = createCollection<UserProfile>('users');
export const sitesCollection = createCollection<Site>('sites');
export const roomsCollection = createCollection<Room>('rooms');
export const programsCollection = createCollection<Program>('programs');
export const coursesCollection = createCollection<Course>('courses');
export const missionsCollection = createCollection<Mission>('missions');
export const enrolmentsCollection = createCollection<Enrolment>('enrolments');
export const sessionsCollection = createCollection<Session>('sessions');
export const sessionOccurrencesCollection = createCollection<SessionOccurrence>('sessionOccurrences');
export const attendanceCollection = createCollection<Attendance>('attendanceRecords'); // Mapped to attendanceRecords per checklist
export const missionPlansCollection = createCollection<MissionPlan>('missionPlans');
export const missionAttemptsCollection = createCollection<MissionAttempt>('missionAttempts');
export const reflectionsCollection = createCollection<Reflection>('reflections');
export const accountabilityCommitmentsCollection = createCollection<AccountabilityCommitment>('accountabilityCommitments');
export const accountabilityReviewsCollection = createCollection<AccountabilityReview>('accountabilityReviews');
export const portfolioItemsCollection = createCollection<PortfolioItem>('portfolioItems');
export const alertsCollection = createCollection<Alert>('alerts');
export const announcementsCollection = createCollection<Announcement>('announcements');
export const pillarsCollection = createCollection('pillars');
