// docs/02A_SCHEMA_V3.ts
export type ID = string;
export type EpochMs = number;
export interface BaseEntity { id: ID; createdAt: EpochMs; updatedAt?: EpochMs; metadata?: Record<string, any>; }

/* ===========================
   GOOGLE CLASSROOM INTEGRATION
   =========================== */

export type IntegrationProvider = 'google_classroom';
export type IntegrationStatus = 'active' | 'revoked' | 'error';

export interface IntegrationConnection extends BaseEntity {
  ownerUserId: ID; // educator uid
  provider: IntegrationProvider;
  status: IntegrationStatus;
  scopesGranted?: string[];
  tokenRef?: string; // reference to secret store / encrypted blob
  lastError?: string;
}

export interface ExternalCourseLink extends BaseEntity {
  provider: IntegrationProvider;
  providerCourseId: string;

  ownerUserId: ID; // educator who linked it
  siteId: ID;
  sessionId: ID;

  syncPolicy?: 'manual' | 'daily' | 'weekly';
  lastRosterSyncAt?: EpochMs;
  lastCourseworkSyncAt?: EpochMs;
}

export interface ExternalUserLink extends BaseEntity {
  provider: IntegrationProvider;
  providerUserId: string;
  scholesaUserId: ID;
  siteId: ID;
  roleHint?: 'learner' | 'educator';
  matchSource?: 'email' | 'manual' | 'sis';
}

export interface ExternalCourseworkLink extends BaseEntity {
  provider: IntegrationProvider;
  providerCourseId: string;
  providerCourseWorkId: string;

  siteId: ID;
  missionId: ID;

  sessionId?: ID;
  sessionOccurrenceId?: ID;

  publishedBy: ID;
  publishedAt: EpochMs;
}

export interface SyncJob extends BaseEntity {
  type: 'roster_import' | 'coursework_publish' | 'submission_pull' | 'grade_push';
  siteId?: ID;
  requestedBy: ID;
  status: 'queued' | 'running' | 'failed' | 'completed';
  cursor?: string;
  nextPageToken?: string;
  lastError?: string;
}

export interface SyncCursor extends BaseEntity {
  ownerUserId: ID;
  provider: IntegrationProvider;
  providerCourseId: string;
  cursorType: 'roster' | 'coursework' | 'submissions';
  nextPageToken?: string;
}

/* ===========================
   GITHUB INTEGRATION
   =========================== */

export type GitHubAuthType = 'oauth_app' | 'github_app';
export type GitHubConnectionStatus = 'active' | 'revoked' | 'error';

export interface GitHubConnection extends BaseEntity {
  ownerUserId: ID; // educator uid (or admin uid for org installs)
  authType: GitHubAuthType;
  status: GitHubConnectionStatus;

  // If OAuth app
  oauthScopesGranted?: string[];
  tokenRef?: string; // secret-store reference (encrypted)

  // If GitHub App
  installationId?: string;
  orgLogin?: string;

  lastError?: string;
}

export interface ExternalRepoLink extends BaseEntity {
  siteId: ID;
  learnerId?: ID;
  educatorId?: ID;

  repoFullName: string; // "org/repo"
  repoUrl: string;
  installationId?: string;

  // Optional linkage to mission/attempt
  missionId?: ID;
  missionAttemptId?: ID;

  status?: 'active' | 'archived';
}

export interface ExternalPullRequestLink extends BaseEntity {
  repoFullName: string;
  prNumber: number;
  prUrl: string;

  learnerId?: ID;
  missionAttemptId?: ID;

  status?: 'open' | 'merged' | 'closed';
}

export interface GitHubWebhookDelivery extends BaseEntity {
  deliveryId: string;
  event: string;
  repoFullName?: string;
  installationId?: string;
  processedAt?: EpochMs;
  status?: 'ok' | 'failed';
  lastError?: string;
}

/* ===========================
   PHYSICAL SCHOOL OPERATIONS / SAFETY / COMPLIANCE
   =========================== */

export type IncidentSeverity = 'minor' | 'major' | 'critical';
export type IncidentStatus = 'draft' | 'submitted' | 'reviewed' | 'closed';
export type ConsentStatus = 'active' | 'expired' | 'revoked';

export interface MediaConsent extends BaseEntity {
  siteId: ID;
  learnerId: ID;

  photoCaptureAllowed: boolean;
  shareWithLinkedParents: boolean;
  marketingUseAllowed: boolean;

  consentStatus: ConsentStatus;
  consentStartDate?: string; // YYYY-MM-DD
  consentEndDate?: string;   // YYYY-MM-DD
  consentDocumentUrl?: string;
}

export interface AuthorizedPickupPerson {
  name: string;
  relationship?: string;
  phone?: string;
  notes?: string;
}

export interface PickupAuthorization extends BaseEntity {
  siteId: ID;
  learnerId: ID;
  authorizedPickup: AuthorizedPickupPerson[];
  updatedBy: ID; // admin uid
}

export interface IncidentReport extends BaseEntity {
  siteId: ID;
  learnerId?: ID;
  sessionOccurrenceId?: ID;
  reportedBy: ID; // educator/admin
  severity: IncidentSeverity;
  category: 'injury' | 'behavior' | 'bullying' | 'facility' | 'late_pickup' | 'other';
  status: IncidentStatus;

  summary: string;
  details?: string;

  reviewedBy?: ID;
  reviewedAt?: EpochMs;
  closedAt?: EpochMs;
}

export interface SiteCheckInOut extends BaseEntity {
  siteId: ID;
  learnerId: ID;
  date: string; // YYYY-MM-DD

  checkInAt?: EpochMs;
  checkInBy?: ID;

  checkOutAt?: EpochMs;
  checkOutBy?: ID;
  pickedUpByName?: string;

  latePickupFlag?: boolean;
}

export interface Room extends BaseEntity {
  siteId: ID;
  name: string;
  capacity?: number;
}

export interface MissionSnapshot extends BaseEntity {
  missionId: ID;
  contentHash: string; // sha256 or similar
  title: string;
  description: string;
  pillarCodes: PillarCode[];
  skillIds?: ID[];
  bodyJson?: any; // immutable snapshot of mission content blocks
  publisherType?: 'hq' | 'partner' | 'site';
  publisherId?: ID;
  publishedAt?: EpochMs;
}

export interface Rubric extends BaseEntity {
  siteId?: ID; // global rubrics may omit
  title: string;
  criteria: Array<{
    title: string;
    pillarCodes?: PillarCode[];
    skillIds?: ID[];
    levels: Array<{ level: 0|1|2|3|4; descriptor: string }>;
  }>;
}

export interface RubricCriterionScore {
  label: string;
  pillarCode?: PillarCode;
  capabilityId: ID; // reference to capabilities collection
  score: number;
  maxScore: number;
  notes?: string;
}

export interface RubricApplication extends BaseEntity {
  siteId: ID;
  learnerId: ID;
  educatorId: ID;
  missionAttemptId?: ID;
  evidenceRecordId?: ID;
  rubricId?: ID;
  rubricTitle: string;
  criteria: RubricCriterionScore[];
  totalRawScore: number;
  totalMaxScore: number;
  capabilityIds: ID[]; // references to capabilities collection
  feedback?: string;
}

/* ===========================
   EVIDENCE CHAIN
   =========================== */

export type PillarCode = string; // e.g. 'ideation' | 'craft' | 'character' | 'community' | 'enterprise'

export type EvidencePhaseKey =
  | 'retrieval_warm_up'
  | 'mini_lesson'
  | 'build_sprint'
  | 'checkpoint'
  | 'share_out'
  | 'reflection';

/** HQ-defined capability within a pillar framework. */
export interface Capability extends BaseEntity {
  title: string;
  normalizedTitle: string;
  pillarCode: PillarCode;
  siteId?: ID | null; // null = global
  descriptor?: string;
}

/** Educator-logged in-session observation linked to evidence chain. */
export interface ObservationRecord extends BaseEntity {
  siteId: ID;
  learnerId: ID;
  educatorId: ID;
  sessionOccurrenceId?: ID;
  description: string;
  capabilityId?: ID;
  phaseKey?: EvidencePhaseKey;
  portfolioCandidate: boolean;
  artifactUrl?: string;
}

/** Educator-captured evidence record (observation + artifact). */
export interface EvidenceRecord extends BaseEntity {
  siteId: ID;
  learnerId: ID;
  educatorId: ID;
  sessionOccurrenceId?: ID;
  description: string;
  capabilityId?: ID;
  capabilityMapped: boolean;
  phaseKey?: EvidencePhaseKey;
  portfolioCandidate: boolean;
  rubricStatus: 'pending' | 'applied' | 'skipped';
  growthStatus: 'pending' | 'recorded' | 'skipped';
  rubricApplicationId?: ID;
  growthEventId?: ID;
  artifactUrl?: string;
}

/** Append-only provenance record for each capability-level update. */
export interface CapabilityGrowthEvent extends BaseEntity {
  siteId: ID;
  learnerId: ID;
  capabilityId: ID;
  pillarCode: PillarCode;
  level: number; // 1-5
  rawScore: number;
  maxScore: number;
  evidenceId?: ID;
  missionAttemptId?: ID;
  rubricApplicationId?: ID;
  educatorId?: ID;
}

/** Aggregated mastery state per learner per capability (upserted on each growth event). */
export interface CapabilityMastery extends BaseEntity {
  siteId: ID;
  learnerId: ID;
  capabilityId: ID;
  pillarCode: PillarCode;
  latestLevel: number; // 1-5
  highestLevel: number;
  latestEvidenceId?: ID;
  latestMissionAttemptId?: ID;
  evidenceIds: ID[];
  growthEventIds: ID[];
}

/** Educator-issued proof that a learner satisfied a checkpoint requirement. */
export interface CheckpointVerification extends BaseEntity {
  siteId: ID;
  learnerId: ID;
  educatorId: ID;
  capabilityId: ID;
  checkpointId: ID;
  targetLevel: number;
  verifiedAt: EpochMs;
  notes?: string;
}

export type IdentityLinkProvider = 'google_classroom' | 'github';

export interface ExternalIdentityLink extends BaseEntity {
  siteId: ID;
  provider: IdentityLinkProvider;
  providerUserId: string;

  scholesaUserId?: ID; // linked uid
  status: 'unmatched' | 'linked' | 'ignored';

  suggestedMatches?: Array<{ scholesaUserId: ID; reason: string; confidence: 'low'|'med'|'high' }>;
  approvedBy?: ID; // admin/HQ
  approvedAt?: EpochMs;
}

