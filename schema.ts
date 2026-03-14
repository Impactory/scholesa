export type Role = 'learner' | 'educator' | 'parent' | 'site' | 'partner' | 'hq';

export interface User {
  uid: string;
  email: string;
  displayName?: string;
  photoURL?: string;
  role: Role;
  siteIds: string[]; // Users can belong to multiple sites
  parentIds?: string[]; // For learners, links to their parents
  organizationId?: string; // For partners/HQ
  createdAt: number; // Timestamp (ms)
  updatedAt: number;
}

export interface Site {
  id: string;
  name: string;
  location?: string;
  siteLeadIds: string[];
  createdAt: number;
}

// --- Learning & Sessions ---

export interface Session {
  id: string;
  title: string;
  description?: string;
  siteId: string;
  educatorIds: string[];
  pillarCodes: string[]; // e.g., 'tech', 'arts'
  startDate: number;
  endDate: number;
  recurrence?: string; // e.g., 'weekly'
}

export interface SessionOccurrence {
  id: string;
  sessionId: string;
  siteId: string;
  startTime: number;
  endTime: number;
  educatorId?: string; // The specific educator for this occurrence
  status: 'scheduled' | 'completed' | 'cancelled';
}

export interface Enrollment {
  id: string;
  sessionId: string;
  learnerId: string;
  siteId: string;
  enrolledAt: number;
  status: 'active' | 'dropped' | 'completed';
}

export interface AttendanceRecord {
  id: string;
  sessionOccurrenceId: string;
  learnerId: string;
  siteId: string;
  status: 'present' | 'absent' | 'late' | 'excused';
  timestamp: number;
  notes?: string;
}

// --- Pillars & Skills ---

export interface Pillar {
  code: string; // ID
  name: string;
  description?: string;
  color?: string;
}

export interface Skill {
  id: string;
  pillarCode: string;
  name: string;
  description?: string;
  level: number;
}

export interface SkillMastery {
  id: string;
  learnerId: string;
  skillId: string;
  levelAchieved: number;
  achievedAt: number;
  evidenceIds?: string[]; // Links to portfolio items
}

// --- Missions ---

export interface Mission {
  id: string;
  title: string;
  description: string;
  pillarCodes: string[];
  difficulty: 'beginner' | 'intermediate' | 'advanced';
  estimatedDurationMinutes?: number;
}

export interface MissionPlan {
  id: string;
  learnerId: string;
  missionId: string;
  status: 'planned' | 'in-progress' | 'completed';
  dueDate?: number;
}

export interface MissionAttempt {
  id: string;
  missionId: string;
  learnerId: string;
  sessionOccurrenceId?: string;
  siteId: string;
  startedAt: number;
  completedAt?: number;
  status: 'started' | 'submitted' | 'approved' | 'rejected';
  submissionUrl?: string;
  feedback?: string;
}

// --- Portfolio ---

export interface Portfolio {
  id: string;
  learnerId: string;
  title: string;
  description?: string;
  createdAt: number;
  updatedAt: number;
}

export interface PortfolioItem {
  id: string;
  portfolioId: string;
  title: string;
  description?: string;
  mediaUrl?: string;
  mediaType: 'image' | 'video' | 'document' | 'link';
  relatedSkillIds?: string[];
  createdAt: number;
}

export interface Credential {
  id: string;
  learnerId: string;
  title: string;
  issuer: string;
  issuedAt: number;
  expiresAt?: number;
  metadata?: Record<string, any>;
}

// --- Accountability ---

export interface AccountabilityCycle {
  id: string;
  siteId: string;
  name: string; // e.g., "Q1 2024"
  startDate: number;
  endDate: number;
  status: 'active' | 'closed';
}

export interface AccountabilityKPI {
  id: string;
  cycleId: string;
  siteId: string;
  metricName: string;
  targetValue: number;
  actualValue?: number;
  unit: string;
}

export interface AccountabilityCommitment {
  id: string;
  cycleId: string;
  userId: string; // Educator or Site Lead
  description: string;
  status: 'pending' | 'fulfilled' | 'missed';
}

export interface AccountabilityReview {
  id: string;
  cycleId: string;
  reviewerId: string;
  revieweeId: string; // Could be a site or a person
  rating: number;
  comments: string;
  createdAt: number;
}

export interface AuditLog {
  id: string;
  userId: string;
  action: string;
  collection?: string;
  documentId?: string;
  timestamp: number;
  details?: Record<string, any>;
}

export type FederatedLearningRuntimeTarget = 'flutter_mobile' | 'web_pwa' | 'hybrid';
export type FederatedLearningExperimentStatus = 'draft' | 'pilot_ready' | 'active' | 'paused' | 'disabled';
export type FederatedLearningExperimentReviewStatus = 'pending' | 'approved' | 'blocked';

export interface FederatedLearningExperiment {
  id: string;
  name: string;
  description?: string;
  runtimeTarget: FederatedLearningRuntimeTarget;
  status: FederatedLearningExperimentStatus;
  allowedSiteIds: string[];
  aggregateThreshold: number;
  rawUpdateMaxBytes: number;
  enablePrototypeUploads: boolean;
  featureFlagId: string;
  createdAt: number;
  updatedAt: number;
}

export interface FederatedLearningUpdateSummary {
  id: string;
  experimentId: string;
  siteId: string;
  traceId: string;
  schemaVersion: string;
  sampleCount: number;
  vectorLength: number;
  payloadBytes: number;
  updateNorm: number;
  payloadDigest: string;
  batteryState?: 'low' | 'ok' | 'charging' | 'unknown';
  networkType?: 'wifi' | 'cellular' | 'offline' | 'unknown';
  aggregationStatus?: 'pending' | 'materialized';
  aggregationRunId?: string;
  requestedBy?: string;
  createdAt: number;
  updatedAt: number;
}

export interface FederatedLearningExperimentReviewRecord {
  id: string;
  experimentId: string;
  status: FederatedLearningExperimentReviewStatus;
  privacyReviewComplete: boolean;
  signoffChecklistComplete: boolean;
  rolloutRiskAcknowledged: boolean;
  notes?: string;
  reviewedBy?: string;
  reviewedAt?: number;
  createdAt: number;
  updatedAt: number;
}

export interface FederatedLearningAggregationRun {
  id: string;
  experimentId: string;
  status: 'materialized';
  threshold: number;
  thresholdMet: boolean;
  mergeArtifactId?: string;
  mergeArtifactStatus?: 'generated';
  candidateModelPackageId?: string;
  candidateModelPackageStatus?: 'staged';
  candidateModelPackageFormat?: 'bounded_metadata_manifest';
  mergeStrategy?: string;
  boundedDigest?: string;
  triggerSummaryId: string;
  summaryIds: string[];
  summaryCount: number;
  distinctSiteCount: number;
  totalSampleCount: number;
  maxVectorLength: number;
  totalPayloadBytes: number;
  averageUpdateNorm: number;
  schemaVersions: string[];
  runtimeTargets: string[];
  createdBy?: string;
  createdAt: number;
  updatedAt: number;
}

export interface FederatedLearningMergeArtifact {
  id: string;
  experimentId: string;
  aggregationRunId: string;
  status: 'generated';
  mergeStrategy: string;
  boundedDigest: string;
  sampleCount: number;
  summaryCount: number;
  distinctSiteCount: number;
  schemaVersions: string[];
  runtimeTargets: string[];
  maxVectorLength: number;
  totalPayloadBytes: number;
  averageUpdateNorm: number;
  createdBy?: string;
  createdAt: number;
  updatedAt: number;
}

export interface FederatedLearningCandidateModelPackage {
  id: string;
  experimentId: string;
  aggregationRunId: string;
  mergeArtifactId: string;
  status: 'staged';
  packageFormat: 'bounded_metadata_manifest';
  rolloutStatus: 'not_distributed';
  latestPromotionRecordId?: string;
  latestPromotionStatus?: 'approved_for_eval' | 'hold' | 'revoked';
  latestPromotionRevocationRecordId?: string;
  packageDigest: string;
  boundedDigest: string;
  sampleCount: number;
  summaryCount: number;
  distinctSiteCount: number;
  schemaVersions: string[];
  runtimeTargets: string[];
  maxVectorLength: number;
  totalPayloadBytes: number;
  averageUpdateNorm: number;
  createdBy?: string;
  createdAt: number;
  updatedAt: number;
}

export interface FederatedLearningCandidatePromotionRecord {
  id: string;
  experimentId: string;
  candidateModelPackageId: string;
  aggregationRunId: string;
  mergeArtifactId: string;
  status: 'approved_for_eval' | 'hold';
  target: 'sandbox_eval';
  rationale?: string;
  decidedBy?: string;
  decidedAt?: number;
  createdAt: number;
  updatedAt: number;
}

export interface FederatedLearningCandidatePromotionRevocationRecord {
  id: string;
  experimentId: string;
  candidateModelPackageId: string;
  candidatePromotionRecordId: string;
  aggregationRunId: string;
  mergeArtifactId: string;
  revokedStatus: 'approved_for_eval' | 'hold';
  target: 'sandbox_eval';
  rationale?: string;
  revokedBy?: string;
  revokedAt?: number;
  createdAt: number;
  updatedAt: number;
}

export interface EnterpriseSsoProvider {
  id: string;
  providerId: string;
  providerType: 'oidc' | 'saml';
  displayName: string;
  siteIds: string[];
  defaultSiteId?: string;
  defaultRole: Role;
  allowedDomains?: string[];
  organizationId?: string;
  buttonText?: string;
  jitProvisioning: boolean;
  enabled: boolean;
  createdAt: number;
  updatedAt: number;
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
  createdAt: number;
  updatedAt: number;
}

export interface ExternalCourseLink {
  id: string;
  provider: IntegrationProvider;
  providerCourseId: string;
  ownerUserId: string;
  siteId: string;
  sessionId: string;
  syncPolicy?: 'manual' | 'daily' | 'weekly';
  lastRosterSyncAt?: number;
  lastCourseworkSyncAt?: number;
  createdAt: number;
  updatedAt: number;
}

export interface ExternalUserLink {
  id: string;
  provider: IntegrationProvider;
  providerUserId: string;
  scholesaUserId: string;
  siteId: string;
  roleHint?: 'learner' | 'educator';
  matchSource?: 'email' | 'manual' | 'sis';
  createdAt: number;
  updatedAt: number;
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
  createdAt: number;
  updatedAt: number;
}

export interface SyncCursor {
  id: string;
  ownerUserId: string;
  provider: IntegrationProvider;
  providerCourseId: string;
  cursorType: 'roster' | 'coursework' | 'submissions';
  nextPageToken?: string;
  createdAt: number;
  updatedAt: number;
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
  approvedAt?: number;
  createdAt: number;
  updatedAt: number;
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
  status: 'active' | 'paused' | 'revoked';
  ownerUserId: string;
  platformName?: string;
  lineItemsScope?: boolean;
  createdAt: number;
  updatedAt: number;
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
  createdAt: number;
  updatedAt: number;
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
  createdAt: number;
  updatedAt: number;
}