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
  AccountabilityCommitment,
  AccountabilityReview,
  Alert,
  Announcement,
  PortfolioItem,
  EnterpriseSsoProvider,
  IntegrationConnection,
  ExternalCourseLink,
  ExternalUserLink,
  SyncJob,
  SyncCursor,
  ExternalIdentityLink,
  LtiPlatformRegistration,
  LtiResourceLink,
  LtiGradePassbackJob,
  EducatorFeedback,
  LearnerMotivationProfile,
  LearnerInteraction,
  SupportIntervention,
  MotivationNudge,
  MotivationConfig,
  Capability,
  CapabilityMastery,
  CapabilityGrowthEvent,
  EvidenceRecord,
  RubricApplication,
  RubricTemplate,
  LearnerReflection,
  ProcessDomain,
  ProcessDomainMastery,
  ProcessDomainGrowthEvent,
  SkillEvidence,
  ProofOfLearningBundle,
} from '@/src/types/schema';

// Helper to create typed collection
const createCollection = <T = DocumentData>(collectionName: string) => {
  return collection(db, collectionName) as CollectionReference<T>;
};

type MissionAttemptWrite = Omit<MissionAttempt, 'id'>;

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
export const missionAttemptsCollection = createCollection<MissionAttemptWrite>('missionAttempts');
export const reflectionsCollection = createCollection<Reflection>('reflections');
export const accountabilityCyclesCollection = createCollection<AccountabilityCycle>('accountabilityCycles');
// accountabilityKPIsCollection removed �� S1-8: legacy LMS metric
export const accountabilityCommitmentsCollection = createCollection<AccountabilityCommitment>('accountabilityCommitments');
export const accountabilityReviewsCollection = createCollection<AccountabilityReview>('accountabilityReviews');
export const alertsCollection = createCollection<Alert>('alerts');
export const announcementsCollection = createCollection<Announcement>('announcements');
export const portfolioItemsCollection = createCollection<PortfolioItem>('portfolioItems');
export const enterpriseSsoProvidersCollection = createCollection<EnterpriseSsoProvider>('enterpriseSsoProviders');
export const integrationConnectionsCollection = createCollection<IntegrationConnection>('integrationConnections');
export const externalCourseLinksCollection = createCollection<ExternalCourseLink>('externalCourseLinks');
export const externalUserLinksCollection = createCollection<ExternalUserLink>('externalUserLinks');
export const syncJobsCollection = createCollection<SyncJob>('syncJobs');
export const syncCursorsCollection = createCollection<SyncCursor>('syncCursors');
export const externalIdentityLinksCollection = createCollection<ExternalIdentityLink>('externalIdentityLinks');
export const ltiPlatformRegistrationsCollection = createCollection<LtiPlatformRegistration>('ltiPlatformRegistrations');
export const ltiResourceLinksCollection = createCollection<LtiResourceLink>('ltiResourceLinks');
export const ltiGradePassbackJobsCollection = createCollection<LtiGradePassbackJob>('ltiGradePassbackJobs');

// Motivation & Personalization System
export const educatorFeedbackCollection = createCollection<EducatorFeedback>('educatorFeedback');
export const learnerMotivationProfilesCollection = createCollection<LearnerMotivationProfile>('learnerMotivationProfiles');
export const learnerInteractionsCollection = createCollection<LearnerInteraction>('learnerInteractions');
export const supportInterventionsCollection = createCollection<SupportIntervention>('supportInterventions');
export const motivationNudgesCollection = createCollection<MotivationNudge>('motivationNudges');
export const motivationConfigCollection = createCollection<MotivationConfig>('configs/motivationConfig');

// Capability Framework & Evidence Chain
export const capabilitiesCollection = createCollection<Capability>('capabilities');
export const capabilityMasteryCollection = createCollection<CapabilityMastery>('capabilityMastery');
export const capabilityGrowthEventsCollection = createCollection<CapabilityGrowthEvent>('capabilityGrowthEvents');
export const evidenceRecordsCollection = createCollection<EvidenceRecord>('evidenceRecords');
export const rubricApplicationsCollection = createCollection<RubricApplication>('rubricApplications');
export const rubricTemplatesCollection = createCollection<RubricTemplate>('rubricTemplates');
export const learnerReflectionsCollection = createCollection<LearnerReflection>('learnerReflections');

// Process Domains
export const processDomainsCollection = createCollection<ProcessDomain>('processDomains');
export const processDomainMasteryCollection = createCollection<ProcessDomainMastery>('processDomainMastery');
export const processDomainGrowthEventsCollection = createCollection<ProcessDomainGrowthEvent>('processDomainGrowthEvents');

// Evidence Engine
export const skillEvidenceCollection = createCollection<SkillEvidence>('skillEvidence');
export const proofOfLearningBundlesCollection = createCollection<ProofOfLearningBundle>('proofOfLearningBundles');
