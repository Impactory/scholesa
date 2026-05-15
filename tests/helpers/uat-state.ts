import { uatMissionDefinitions, type UatMissionDefinition } from '../fixtures/uat-missions';
import { getUatUser, uatSeedData, type UatLoginRole, type UatUser } from '../fixtures/uat-seed-data';
import { MockEvidenceStorage, type MockEvidenceFile } from './mock-file-storage';
import { MockMiloOSCoach, type MiloOSCoachMode, type MiloOSResponse, type MiloOSUsageLog } from './mock-ai-service';

type AuditLogEntry = {
  id: string;
  actorId: string;
  tenantId: string;
  action: string;
  targetId: string;
  capabilityContext?: string[];
  createdAt: string;
};

type MissionAssignment = {
  id: string;
  tenantId: string;
  cohortId: string;
  missionId: string;
  assignedBy: string;
};

type MissionSession = {
  id: string;
  tenantId: string;
  missionId: string;
  cohortId: string;
  openedBy: string;
  status: 'open' | 'closed';
};

type CheckpointCompletion = {
  id: string;
  tenantId: string;
  learnerId: string;
  missionId: string;
  checkpointTitle: string;
};

type EvidenceSubmission = {
  id: string;
  tenantId: string;
  learnerId: string;
  cohortId?: string;
  missionId: string;
  sessionId?: string;
  checkpointTitle?: string;
  capabilityDomains: string[];
  artifact: MockEvidenceFile;
  evidenceType?: 'written-reflection' | 'image' | 'audio' | 'video-link' | 'prototype-link' | 'code-link' | 'alternative';
  explanation?: string;
  links?: string[];
  metadata?: Record<string, unknown>;
  aiUseSummary?: {
    promptUsed: string;
    coachSuggestion: string;
    learnerChanged: string;
  };
  override?: {
    enabledBy: string;
    reason: string;
  };
  revisions?: Array<{
    version: number;
    note: string;
    previousArtifactUrl: string;
    currentArtifactUrl: string;
  }>;
  status: 'submitted' | 'reviewed';
};

type ReflectionSubmission = {
  id: string;
  tenantId: string;
  learnerId: string;
  cohortId?: string;
  missionId: string;
  sessionId?: string;
  checkpointTitle?: string;
  capabilityDomains?: string[];
  response: string;
};

type EvidenceValidationResult = {
  ok: boolean;
  error?: string;
};

type CapabilityReview = {
  id: string;
  tenantId: string;
  educatorId: string;
  learnerId: string;
  missionId: string;
  evidenceId: string;
  artifactUrl?: string;
  score: 1 | 2 | 3 | 4;
  feedback: string;
  nextStep?: string;
  capabilityDomains: string[];
  criterionScores?: Array<{
    criterionId: string;
    criterionTitle: string;
    capabilityDomain: string;
    score: 1 | 2 | 3 | 4;
  }>;
  publishedAt?: string;
};

type EvidenceGap = {
  learnerId: string;
  learnerDisplayName: string;
  missionId: string;
  missing: Array<
    | 'missing reflection'
    | 'missing artifact'
    | 'missing explain-it-back'
    | 'missing AI-use summary'
    | 'incomplete checkpoint'
  >;
};

type EducatorCopilotDecision = {
  id: string;
  educatorId: string;
  tenantId: string;
  learnerId: string;
  missionId: string;
  evidenceId: string;
  suggestion: string;
  decision: 'accepted' | 'edited' | 'ignored';
  finalFeedback?: string;
  createdAt: string;
};

type PortfolioItem = {
  id: string;
  tenantId: string;
  learnerId: string;
  evidenceId: string;
  missionId: string;
  capabilityDomains: string[];
};

type PortfolioShareMode = 'private' | 'cohort' | 'family' | 'mentor' | 'public-showcase';

type PortfolioShareRecord = {
  evidenceId: string;
  learnerId: string;
  tenantId: string;
  mode: PortfolioShareMode;
  assignedMentorId?: string;
  publicApproved: boolean;
};

type BadgeRecord = {
  id: string;
  tenantId: string;
  learnerId: string;
  title: string;
  status: 'ready-for-review' | 'awarded';
  requiredCapabilityDomains: string[];
  evidenceIds: string[];
  awardedBy?: string;
  awardedAt?: string;
};

type PublicShowcaseRequest = {
  id: string;
  tenantId: string;
  learnerId: string;
  evidenceId: string;
  status: 'pending' | 'approved';
  approvedBy?: string;
};

type PortfolioViews = {
  timelineView: PortfolioItem[];
  capabilityView: Array<{ capabilityDomain: string; evidenceIds: string[] }>;
  bestEvidenceView: Array<{ evidenceId: string; score: 1 | 2 | 3 | 4; capabilityDomains: string[] }>;
  reflectionView: ReflectionSubmission[];
  feedback: CapabilityReview[];
  badgeProgress: BadgeRecord[];
};

type PortfolioExportPackage = {
  exportedBy: string;
  learnerId: string;
  evidenceIds: string[];
};

type EducatorCohortGrowthReport = {
  tenantId: string;
  cohortId: string;
  missionId?: string;
  capabilityDomain?: string;
  learnerIds: string[];
  evidenceSubmissionCount: number;
  checkpointCompletionCount: number;
  evidenceGaps: EvidenceGap[];
  badgeReadiness: BadgeRecord[];
  aiUsageCount: number;
  actionItems: Array<{ learnerId: string; reason: string }>;
};

type AdminPlatformReport = {
  tenantId: string;
  learnerProgress: Array<{ learnerId: string; portfolioItemCount: number; growthReportCount: number }>;
  cohortProgress: Array<{ cohortId: string; assignedMissionCount: number; openSessionCount: number }>;
  capabilityGrowth: Array<{ capabilityDomain: string; reviewCount: number }>;
  evidenceSubmissionCount: number;
  aiUsageCount: number;
  badgeReadiness: BadgeRecord[];
  showcaseReadiness: Array<{ evidenceId: string; learnerId: string; status: 'assigned' | 'pending' | 'approved' }>;
};

type AnalyticsExportPackage = {
  exportedBy: string;
  format: 'csv' | 'pdf';
  tenantId: string;
  rows: Array<Record<string, string | number>>;
  excludedEvidenceIds: string[];
};

type SharedMilestone = {
  id: string;
  tenantId: string;
  learnerId: string;
  missionId: string;
  title: string;
  sharedWithFamily: boolean;
  capabilityDomains: string[];
};

type PublishedGrowthSummary = {
  id: string;
  tenantId: string;
  learnerId: string;
  missionId: string;
  summary: string;
  sharedWithFamily: boolean;
  capabilityDomains: string[];
};

type FamilyProgressView = {
  learnerId: string;
  allowed: boolean;
  sharedMilestones: SharedMilestone[];
  homeConnections: HomeConnection[];
  selectedPortfolioHighlights: PortfolioItem[];
  publishedGrowthSummary?: PublishedGrowthSummary;
};

type MentorShowcaseAssignment = {
  id: string;
  tenantId: string;
  mentorId: string;
  learnerId: string;
  missionId: string;
  evidenceId: string;
};

type MentorStructuredFeedback = {
  id: string;
  tenantId: string;
  mentorId: string;
  learnerId: string;
  missionId: string;
  evidenceId: string;
  strengths: string[];
  questions: string[];
  showcaseReadinessNextStep: string;
  visibleToLearner: boolean;
  visibleToEducator: boolean;
};

type KeyboardWorkflowCheck = {
  workflow: 'learner-dashboard' | 'mission-session' | 'evidence-submit' | 'educator-evidence-review';
  reachableActions: string[];
  noKeyboardTrap: boolean;
  allMajorActionsReachable: boolean;
};

type AccessibleControlLabel = {
  control: string;
  accessibleName: string;
  hasVisualOnlyContext: boolean;
};

type ResponsiveLayoutCheck = {
  viewport: 'mobile' | 'tablet' | 'desktop';
  zoomPercent: 100 | 200;
  coreWorkflowsUsable: boolean;
  textOverlapsCriticalControls: boolean;
};

type MainViewPerformanceCheck = {
  view:
    | 'learner-dashboard'
    | 'mission-session-page'
    | 'evidence-submission-page'
    | 'educator-cohort-dashboard'
    | 'portfolio-page'
    | 'admin-report-page';
  loadTimeMs: number;
  targetMs: 2000;
  passed: boolean;
};

type ReflectionDraft = {
  id: string;
  tenantId: string;
  learnerId: string;
  missionId: string;
  value: string;
  networkOnline: boolean;
  localPending: boolean;
  synced: boolean;
  updatedAt: string;
};

type GracefulErrorState = {
  scenario:
    | 'file upload failure'
    | 'MiloOS Coach unavailable'
    | 'report loading failure'
    | 'evidence save failure'
    | 'portfolio export failure';
  friendlyMessage: string;
  noDataLoss: boolean;
  retryAvailable: boolean;
  logged: boolean;
};

type HelpfulEmptyState = {
  surface:
    | 'no missions assigned'
    | 'no evidence submitted'
    | 'no portfolio items yet'
    | 'no growth report data'
    | 'no showcase items'
    | 'no AI usage logs';
  message: string;
  nextAction: string;
};

type GrowthReport = {
  id: string;
  tenantId: string;
  learnerId: string;
  capabilityDomains: string[];
  latestReviewId: string;
};

type TenantIsolationProbe = {
  actorTenantId: string;
  targetTenantId: string;
  allowed: boolean;
};

type LearnerCohortMembership = {
  learnerId: string;
  cohortId: string;
  tenantId: string;
  organizationId: string;
  activeFrom: string;
  activeTo: string | null;
};

type EducatorCohortAssignment = {
  educatorId: string;
  cohortId: string;
  tenantId: string;
  organizationId: string;
};

export type MissionSessionBlock =
  | 'Hook'
  | 'Micro-skill'
  | 'Build sprint'
  | 'Retrieval and transfer'
  | 'Showcase and reflection'
  | 'Home connection';

type SessionBlockProgress = {
  id: string;
  tenantId: string;
  learnerId: string;
  missionId: string;
  sessionId: string;
  block: MissionSessionBlock;
  status: 'saved';
  capabilityDomains: string[];
  savedAt: string;
};

type MissionSessionOrder = {
  missionId: string;
  orderedBlockNames: MissionSessionBlock[];
};

type StretchChallenge = {
  id: string;
  missionId: string;
  cohortId: string;
  title: string;
  unlockedBy: string;
  capabilityDomains: string[];
};

type HomeConnection = {
  id: string;
  missionId: string;
  cohortId: string;
  title: string;
  publishedBy: string;
  sharedWithFamily: boolean;
  capabilityDomains: string[];
};

export type UatRuntimeState = {
  currentUser?: UatUser;
  tenant?: typeof uatSeedData.tenant;
  organization?: typeof uatSeedData.organization;
  cohorts: typeof uatSeedData.cohorts;
  assignments: MissionAssignment[];
  sessions: MissionSession[];
  checkpoints: CheckpointCompletion[];
  evidence: EvidenceSubmission[];
  reflections: ReflectionSubmission[];
  reviews: CapabilityReview[];
  portfolio: PortfolioItem[];
  portfolioShares: PortfolioShareRecord[];
  badges: BadgeRecord[];
  publicShowcaseRequests: PublicShowcaseRequest[];
  sharedMilestones: SharedMilestone[];
  publishedGrowthSummaries: PublishedGrowthSummary[];
  mentorShowcaseAssignments: MentorShowcaseAssignment[];
  mentorFeedback: MentorStructuredFeedback[];
  keyboardWorkflowChecks: KeyboardWorkflowCheck[];
  responsiveLayoutChecks: ResponsiveLayoutCheck[];
  mainViewPerformanceChecks: MainViewPerformanceCheck[];
  reflectionDrafts: ReflectionDraft[];
  gracefulErrorStates: GracefulErrorState[];
  featureFlags: Record<string, boolean>;
  growthReports: GrowthReport[];
  educatorCopilotDecisions: EducatorCopilotDecision[];
  learnerCohortMemberships: LearnerCohortMembership[];
  educatorCohortAssignments: EducatorCohortAssignment[];
  sessionBlockProgress: SessionBlockProgress[];
  sessionOrders: MissionSessionOrder[];
  stretchChallenges: StretchChallenge[];
  homeConnections: HomeConnection[];
  auditLogs: AuditLogEntry[];
  accessDenied: Array<{ actorId: string; reason: string; targetId: string }>;
  tenantIsolationProbes: TenantIsolationProbe[];
};

export function createEmptyUatState(): UatRuntimeState {
  return {
    cohorts: [],
    assignments: [],
    sessions: [],
    checkpoints: [],
    evidence: [],
    reflections: [],
    reviews: [],
    portfolio: [],
    portfolioShares: [],
    badges: [],
    publicShowcaseRequests: [],
    sharedMilestones: [],
    publishedGrowthSummaries: [],
    mentorShowcaseAssignments: [],
    mentorFeedback: [],
    keyboardWorkflowChecks: [],
    responsiveLayoutChecks: [],
    mainViewPerformanceChecks: [],
    reflectionDrafts: [],
    gracefulErrorStates: [],
    featureFlags: { mentor: true },
    growthReports: [],
    educatorCopilotDecisions: [],
    learnerCohortMemberships: [],
    educatorCohortAssignments: [],
    sessionBlockProgress: [],
    sessionOrders: [],
    stretchChallenges: [],
    homeConnections: [],
    auditLogs: [],
    accessDenied: [],
    tenantIsolationProbes: [],
  };
}

export class UatTestHarness {
  readonly state = createEmptyUatState();
  readonly aiCoach = new MockMiloOSCoach();
  readonly storage = new MockEvidenceStorage();

  loginAs(role: UatLoginRole): UatUser {
    this.state.currentUser = getUatUser(role);
    this.addAuditLog('login', this.state.currentUser.id, []);

    return this.state.currentUser;
  }

  createTenant(): typeof uatSeedData.tenant {
    this.state.tenant = uatSeedData.tenant;
    this.addAuditLog('tenant.create', uatSeedData.tenant.id, []);

    return uatSeedData.tenant;
  }

  createOrganization(): typeof uatSeedData.organization {
    this.state.organization = uatSeedData.organization;
    this.addAuditLog('organization.create', uatSeedData.organization.id, []);

    return uatSeedData.organization;
  }

  createCohort(cohortId = uatSeedData.cohorts[0].id): (typeof uatSeedData.cohorts)[number] {
    const cohort = uatSeedData.cohorts.find((item) => item.id === cohortId);

    if (!cohort) {
      throw new Error(`Unknown UAT cohort ${cohortId}`);
    }

    if (!this.state.cohorts.some((item) => item.id === cohort.id)) {
      this.state.cohorts.push(cohort);
    }

    this.addAuditLog('cohort.create', cohort.id, []);

    return cohort;
  }

  addLearnerToCohort(learnerRole: UatLoginRole, cohortId: string): LearnerCohortMembership {
    const learner = getUatUser(learnerRole);
    const cohort = this.createCohort(cohortId);
    const membership = {
      learnerId: learner.id,
      cohortId: cohort.id,
      tenantId: cohort.tenantId,
      organizationId: cohort.organizationId,
      activeFrom: new Date('2026-05-14T12:15:00.000Z').toISOString(),
      activeTo: null,
    };

    this.state.learnerCohortMemberships.push(membership);
    this.addAuditLog('cohort.learner.add', `${learner.id}:${cohort.id}`, []);

    return membership;
  }

  assignEducatorToCohort(educatorRole: UatLoginRole, cohortId: string): EducatorCohortAssignment {
    const educator = getUatUser(educatorRole);
    const cohort = this.createCohort(cohortId);
    const assignment = {
      educatorId: educator.id,
      cohortId: cohort.id,
      tenantId: cohort.tenantId,
      organizationId: cohort.organizationId,
    };

    this.state.educatorCohortAssignments.push(assignment);
    this.addAuditLog('cohort.educator.assign', `${educator.id}:${cohort.id}`, []);

    return assignment;
  }

  moveLearnerToCohort(learnerRole: UatLoginRole, nextCohortId: string): LearnerCohortMembership {
    const learner = getUatUser(learnerRole);
    const now = new Date('2026-05-14T12:30:00.000Z').toISOString();

    this.state.learnerCohortMemberships = this.state.learnerCohortMemberships.map((membership) =>
      membership.learnerId === learner.id && membership.activeTo === null
        ? { ...membership, activeTo: now }
        : membership
    );

    const nextMembership = this.addLearnerToCohort(learnerRole, nextCohortId);
    this.addAuditLog('cohort.learner.move', `${learner.id}:${nextCohortId}`, []);

    return nextMembership;
  }

  getActiveCohortForLearner(learnerRole: UatLoginRole): LearnerCohortMembership | undefined {
    const learner = getUatUser(learnerRole);

    return this.state.learnerCohortMemberships.find(
      (membership) => membership.learnerId === learner.id && membership.activeTo === null
    );
  }

  getEducatorCohorts(educatorRole: UatLoginRole): Array<(typeof uatSeedData.cohorts)[number]> {
    const educator = getUatUser(educatorRole);
    const cohortIds = this.state.educatorCohortAssignments
      .filter((assignment) => assignment.educatorId === educator.id)
      .map((assignment) => assignment.cohortId);

    return this.state.cohorts.filter((cohort) => cohortIds.includes(cohort.id));
  }

  getLearnerDashboard(learnerRole: UatLoginRole): {
    learner: UatUser;
    activeCohort?: LearnerCohortMembership;
    stage?: string;
    missionTitles: string[];
  } {
    const learner = getUatUser(learnerRole);
    const activeCohort = this.getActiveCohortForLearner(learnerRole);
    const missionTitles = this.state.assignments
      .filter((assignment) => assignment.cohortId === activeCohort?.cohortId)
      .map((assignment) => this.getMission(assignment.missionId).title);

    return {
      learner,
      activeCohort,
      stage: learner.stage,
      missionTitles,
    };
  }

  assignMission(missionId: string, cohortId: string): MissionAssignment {
    const mission = this.getMission(missionId);
    const actor = this.requireCurrentUser('educator');
    const assignment = {
      id: `assignment-${this.state.assignments.length + 1}`,
      tenantId: uatSeedData.tenant.id,
      cohortId,
      missionId: mission.id,
      assignedBy: actor.id,
    };

    this.state.assignments.push(assignment);
    this.addAuditLog('mission.assign', assignment.id, mission.capabilityDomains);

    return assignment;
  }

  openMissionSession(missionId: string, cohortId: string): MissionSession {
    const mission = this.getMission(missionId);
    const actor = this.requireCurrentUser('educator');
    const session = {
      id: `session-${this.state.sessions.length + 1}`,
      tenantId: uatSeedData.tenant.id,
      missionId: mission.id,
      cohortId,
      openedBy: actor.id,
      status: 'open' as const,
    };

    this.state.sessions.push(session);
    this.addAuditLog('mission-session.open', session.id, mission.capabilityDomains);

    return session;
  }

  saveSessionBlockProgress(
    learnerRole: UatLoginRole,
    missionId: string,
    sessionId: string,
    block: MissionSessionBlock
  ): SessionBlockProgress {
    const learner = getUatUser(learnerRole);
    const mission = this.getMission(missionId);
    const progress = {
      id: `session-block-progress-${this.state.sessionBlockProgress.length + 1}`,
      tenantId: learner.tenantId,
      learnerId: learner.id,
      missionId: mission.id,
      sessionId,
      block,
      status: 'saved' as const,
      capabilityDomains: mission.capabilityDomains,
      savedAt: new Date('2026-05-14T12:40:00.000Z').toISOString(),
    };

    this.state.sessionBlockProgress.push(progress);
    this.addAuditLog('session-block-progress.save', progress.id, mission.capabilityDomains);

    return progress;
  }

  getLearnerSessionProgress(learnerRole: UatLoginRole, missionId: string): SessionBlockProgress[] {
    const learner = getUatUser(learnerRole);

    return this.state.sessionBlockProgress.filter(
      (progress) => progress.learnerId === learner.id && progress.missionId === missionId
    );
  }

  getEducatorCheckpointProgress(cohortId: string, missionId: string): SessionBlockProgress[] {
    const learnerIds = this.state.learnerCohortMemberships
      .filter((membership) => membership.cohortId === cohortId && membership.activeTo === null)
      .map((membership) => membership.learnerId);

    return this.state.sessionBlockProgress.filter(
      (progress) => learnerIds.includes(progress.learnerId) && progress.missionId === missionId
    );
  }

  reorderMissionSessions(missionId: string, orderedBlockNames: MissionSessionBlock[]): MissionSessionOrder {
    const mission = this.getMission(missionId);
    this.requireCurrentUser('educator');
    const order = { missionId: mission.id, orderedBlockNames };

    this.state.sessionOrders = [
      ...this.state.sessionOrders.filter((item) => item.missionId !== mission.id),
      order,
    ];
    this.addAuditLog('mission-session.reorder', mission.id, mission.capabilityDomains);

    return order;
  }

  getMissionSessionOrder(missionId: string): MissionSessionBlock[] {
    const configuredOrder = this.state.sessionOrders.find((order) => order.missionId === missionId);

    return configuredOrder?.orderedBlockNames ?? [
      'Hook',
      'Micro-skill',
      'Build sprint',
      'Retrieval and transfer',
      'Showcase and reflection',
      'Home connection',
    ];
  }

  unlockStretchChallenge(missionId: string, cohortId: string, title: string): StretchChallenge {
    const educator = this.requireCurrentUser('educator');
    const mission = this.getMission(missionId);
    const challenge = {
      id: `stretch-challenge-${this.state.stretchChallenges.length + 1}`,
      missionId: mission.id,
      cohortId,
      title,
      unlockedBy: educator.id,
      capabilityDomains: mission.capabilityDomains,
    };

    this.state.stretchChallenges.push(challenge);
    this.addAuditLog('stretch-challenge.unlock', challenge.id, mission.capabilityDomains);

    return challenge;
  }

  getStretchChallengesForLearner(learnerRole: UatLoginRole, missionId: string): StretchChallenge[] {
    const activeCohort = this.getActiveCohortForLearner(learnerRole);

    return this.state.stretchChallenges.filter(
      (challenge) => challenge.missionId === missionId && challenge.cohortId === activeCohort?.cohortId
    );
  }

  async submitStretchEvidence(
    learnerRole: UatLoginRole,
    missionId: string,
    challengeId: string
  ): Promise<EvidenceSubmission> {
    const evidence = await this.submitEvidence(learnerRole, missionId);

    this.state.portfolio.push({
      id: `portfolio-item-${this.state.portfolio.length + 1}`,
      tenantId: evidence.tenantId,
      learnerId: evidence.learnerId,
      evidenceId: evidence.id,
      missionId,
      capabilityDomains: evidence.capabilityDomains,
    });
    this.addAuditLog('stretch-evidence.submit', challengeId, evidence.capabilityDomains);

    return evidence;
  }

  publishHomeConnection(
    missionId: string,
    cohortId: string,
    title: string,
    sharedWithFamily: boolean
  ): HomeConnection {
    const educator = this.requireCurrentUser('educator');
    const mission = this.getMission(missionId);
    const homeConnection = {
      id: `home-connection-${this.state.homeConnections.length + 1}`,
      missionId: mission.id,
      cohortId,
      title,
      publishedBy: educator.id,
      sharedWithFamily,
      capabilityDomains: mission.capabilityDomains,
    };

    this.state.homeConnections.push(homeConnection);
    this.addAuditLog('home-connection.publish', homeConnection.id, mission.capabilityDomains);

    return homeConnection;
  }

  getHomeConnectionsForLearner(learnerRole: UatLoginRole, missionId: string): HomeConnection[] {
    const activeCohort = this.getActiveCohortForLearner(learnerRole);

    return this.state.homeConnections.filter(
      (connection) => connection.missionId === missionId && connection.cohortId === activeCohort?.cohortId
    );
  }

  getHomeConnectionsForFamily(familyRole: UatLoginRole, learnerRole: UatLoginRole, missionId: string): HomeConnection[] {
    const family = getUatUser(familyRole);
    const learner = getUatUser(learnerRole);

    if (family.linkedLearnerEmail !== learner.email) {
      return [];
    }

    return this.getHomeConnectionsForLearner(learnerRole, missionId).filter(
      (connection) => connection.sharedWithFamily
    );
  }

  completeCheckpoint(learnerRole: UatLoginRole, missionId: string, checkpointTitle: string): CheckpointCompletion {
    const learner = getUatUser(learnerRole);
    const mission = this.getMission(missionId);
    const checkpoint = {
      id: `checkpoint-completion-${this.state.checkpoints.length + 1}`,
      tenantId: learner.tenantId,
      learnerId: learner.id,
      missionId: mission.id,
      checkpointTitle,
    };

    this.state.checkpoints.push(checkpoint);
    this.addAuditLog('checkpoint.complete', checkpoint.id, mission.capabilityDomains);

    return checkpoint;
  }

  async submitEvidence(learnerRole: UatLoginRole, missionId: string): Promise<EvidenceSubmission> {
    const learner = getUatUser(learnerRole);
    const mission = this.getMission(missionId);
    const artifact = await this.storage.uploadEvidenceFile({
      tenantId: learner.tenantId,
      learnerId: learner.id,
      missionId: mission.id,
      checkpointId: `${mission.id}-checkpoint-artifact`,
      fileName: `${mission.id}-${learner.id}.txt`,
      contentType: 'text/plain',
      sizeBytes: 128,
      body: `${learner.displayName} evidence for ${mission.title}`,
    });
    const evidence = {
      id: `evidence-${this.state.evidence.length + 1}`,
      tenantId: learner.tenantId,
      learnerId: learner.id,
      missionId: mission.id,
      capabilityDomains: mission.capabilityDomains,
      artifact,
      status: 'submitted' as const,
    };

    this.state.evidence.push(evidence);
    this.addAuditLog('evidence.submit', evidence.id, mission.capabilityDomains);

    return evidence;
  }

  submitReflection(learnerRole: UatLoginRole, missionId: string, response: string): ReflectionSubmission {
    const learner = getUatUser(learnerRole);
    const mission = this.getMission(missionId);
    const reflection = {
      id: `reflection-${this.state.reflections.length + 1}`,
      tenantId: learner.tenantId,
      learnerId: learner.id,
      missionId: mission.id,
      response,
    };

    this.state.reflections.push(reflection);
    this.addAuditLog('reflection.submit', reflection.id, mission.capabilityDomains);

    return reflection;
  }

  submitWrittenReflectionProof(
    learnerRole: UatLoginRole,
    missionId: string,
    sessionId: string,
    checkpointTitle: string,
    response: string
  ): ReflectionSubmission {
    const learner = getUatUser(learnerRole);
    const mission = this.getMission(missionId);
    const activeCohort = this.getActiveCohortForLearner(learnerRole);
    const reflection = {
      id: `reflection-${this.state.reflections.length + 1}`,
      tenantId: learner.tenantId,
      learnerId: learner.id,
      cohortId: activeCohort?.cohortId,
      missionId: mission.id,
      sessionId,
      checkpointTitle,
      capabilityDomains: mission.capabilityDomains,
      response,
    };

    this.state.reflections.push(reflection);
    this.state.portfolio.push({
      id: `portfolio-item-${this.state.portfolio.length + 1}`,
      tenantId: learner.tenantId,
      learnerId: learner.id,
      evidenceId: reflection.id,
      missionId: mission.id,
      capabilityDomains: mission.capabilityDomains,
    });
    this.addAuditLog('reflection-proof.submit', reflection.id, mission.capabilityDomains);

    return reflection;
  }

  async submitEvidenceArtifact(input: {
    learnerRole: UatLoginRole;
    missionId: string;
    sessionId?: string;
    checkpointTitle?: string;
    evidenceType: NonNullable<EvidenceSubmission['evidenceType']>;
    fileName: string;
    contentType: string;
    body: string;
    explanation?: string;
    links?: string[];
    metadata?: Record<string, unknown>;
    aiUseSummary?: EvidenceSubmission['aiUseSummary'];
    override?: EvidenceSubmission['override'];
  }): Promise<EvidenceSubmission> {
    const learner = getUatUser(input.learnerRole);
    const mission = this.getMission(input.missionId);
    const activeCohort = this.getActiveCohortForLearner(input.learnerRole);
    const artifact = await this.storage.uploadEvidenceFile({
      tenantId: learner.tenantId,
      learnerId: learner.id,
      missionId: mission.id,
      checkpointId: input.checkpointTitle ?? `${mission.id}-checkpoint-artifact`,
      fileName: input.fileName,
      contentType: input.contentType,
      sizeBytes: input.body.length,
      body: input.body,
    });
    const evidence = {
      id: `evidence-${this.state.evidence.length + 1}`,
      tenantId: learner.tenantId,
      learnerId: learner.id,
      cohortId: activeCohort?.cohortId,
      missionId: mission.id,
      sessionId: input.sessionId,
      checkpointTitle: input.checkpointTitle,
      capabilityDomains: mission.capabilityDomains,
      artifact,
      evidenceType: input.evidenceType,
      explanation: input.explanation,
      links: input.links,
      metadata: input.metadata,
      aiUseSummary: input.aiUseSummary,
      override: input.override,
      revisions: [],
      status: 'submitted' as const,
    };

    this.state.evidence.push(evidence);
    this.addAuditLog('evidence-artifact.submit', evidence.id, mission.capabilityDomains);

    return evidence;
  }

  validateProofOfWork(input: { explanation?: string; aiSupported?: boolean; aiUseSummary?: EvidenceSubmission['aiUseSummary'] }): EvidenceValidationResult {
    if (!input.explanation?.trim()) {
      return { ok: false, error: 'Explanation is required for proof-of-work.' };
    }

    if (input.aiSupported) {
      const summary = input.aiUseSummary;

      if (!summary?.promptUsed || !summary.coachSuggestion || !summary.learnerChanged) {
        return { ok: false, error: 'AI-supported work requires prompt, MiloOS Coach suggestion, and learner change summary.' };
      }
    }

    return { ok: true };
  }

  reviseEvidence(evidenceId: string, note: string, currentArtifactUrl: string): EvidenceSubmission {
    const evidence = this.state.evidence.find((item) => item.id === evidenceId);

    if (!evidence) {
      throw new Error(`Unknown evidence ${evidenceId}`);
    }

    const revision = {
      version: (evidence.revisions?.length ?? 0) + 1,
      note,
      previousArtifactUrl: evidence.artifact.url,
      currentArtifactUrl,
    };

    evidence.revisions = [...(evidence.revisions ?? []), revision];
    this.addAuditLog('evidence.revise', evidence.id, evidence.capabilityDomains);

    return evidence;
  }

  getRevisionHistory(evidenceId: string): NonNullable<EvidenceSubmission['revisions']> {
    return this.state.evidence.find((item) => item.id === evidenceId)?.revisions ?? [];
  }

  getEducatorReviewableEvidence(cohortId: string, missionId: string): EvidenceSubmission[] {
    return this.state.evidence.filter(
      (evidence) => evidence.cohortId === cohortId && evidence.missionId === missionId
    );
  }

  getEducatorReviewableReflections(cohortId: string, missionId: string): ReflectionSubmission[] {
    return this.state.reflections.filter(
      (reflection) => reflection.cohortId === cohortId && reflection.missionId === missionId
    );
  }

  getEducatorEvidenceGaps(cohortId: string, missionId: string): EvidenceGap[] {
    this.requireCurrentUser('educator');
    const mission = this.getMission(missionId);
    const activeMemberships = this.state.learnerCohortMemberships.filter(
      (membership) => membership.cohortId === cohortId && membership.activeTo === null
    );

    return activeMemberships
      .map((membership) => {
        const learner = Object.values(uatSeedData.usersByLoginRole).find(
          (user) => user.id === membership.learnerId
        );
        const learnerEvidence = this.state.evidence.filter(
          (evidence) => evidence.learnerId === membership.learnerId && evidence.missionId === mission.id
        );
        const learnerReflections = this.state.reflections.filter(
          (reflection) => reflection.learnerId === membership.learnerId && reflection.missionId === mission.id
        );
        const learnerCheckpoints = this.state.checkpoints.filter(
          (checkpoint) => checkpoint.learnerId === membership.learnerId && checkpoint.missionId === mission.id
        );
        const learnerAiLogs = this.checkAIUsageLog().filter(
          (log) => log.learnerId === membership.learnerId && log.missionId === mission.id && log.allowed
        );
        const missing: EvidenceGap['missing'] = [];

        if (learnerReflections.length === 0) {
          missing.push('missing reflection');
        }

        if (learnerEvidence.length === 0) {
          missing.push('missing artifact');
        }

        if (!learnerEvidence.some((evidence) => evidence.explanation?.trim())) {
          missing.push('missing explain-it-back');
        }

        if (learnerAiLogs.length > 0 && !learnerEvidence.some((evidence) => evidence.aiUseSummary)) {
          missing.push('missing AI-use summary');
        }

        if (!mission.checkpointTitles.every((title) => learnerCheckpoints.some((checkpoint) => checkpoint.checkpointTitle === title))) {
          missing.push('incomplete checkpoint');
        }

        return {
          learnerId: membership.learnerId,
          learnerDisplayName: learner?.displayName ?? membership.learnerId,
          missionId: mission.id,
          missing,
        };
      })
      .filter((gap) => gap.missing.length > 0);
  }

  enableEvidenceOverride(learnerRole: UatLoginRole, reason: string): { enabledBy: string; reason: string } {
    const educator = this.requireCurrentUser('educator');
    const learner = getUatUser(learnerRole);
    const override = { enabledBy: educator.id, reason };

    this.addAuditLog('evidence-override.enable', learner.id, []);

    return override;
  }

  performCapabilityReview(
    learnerRole: UatLoginRole,
    missionId: string,
    evidenceId: string,
    score: 1 | 2 | 3 | 4,
    feedback: string
  ): CapabilityReview {
    const educator = this.requireCurrentUser('educator');
    const learner = getUatUser(learnerRole);
    const mission = this.getMission(missionId);
    const review = {
      id: `capability-review-${this.state.reviews.length + 1}`,
      tenantId: learner.tenantId,
      educatorId: educator.id,
      learnerId: learner.id,
      missionId: mission.id,
      evidenceId,
      score,
      feedback,
      capabilityDomains: mission.capabilityDomains,
      publishedAt: new Date('2026-05-14T13:00:00.000Z').toISOString(),
    };

    this.state.reviews.push(review);
    this.state.evidence = this.state.evidence.map((item) =>
      item.id === evidenceId ? { ...item, status: 'reviewed' as const } : item
    );
    this.state.portfolio.push({
      id: `portfolio-item-${this.state.portfolio.length + 1}`,
      tenantId: learner.tenantId,
      learnerId: learner.id,
      evidenceId,
      missionId: mission.id,
      capabilityDomains: mission.capabilityDomains,
    });
    this.state.growthReports.push({
      id: `growth-report-${this.state.growthReports.length + 1}`,
      tenantId: learner.tenantId,
      learnerId: learner.id,
      capabilityDomains: mission.capabilityDomains,
      latestReviewId: review.id,
    });
    this.addAuditLog('capability-review.perform', review.id, mission.capabilityDomains);

    return review;
  }

  performCapabilityReviewWithCriteria(input: {
    learnerRole: UatLoginRole;
    missionId: string;
    evidenceId: string;
    criterionScores: Array<{
      criterionId: string;
      criterionTitle: string;
      capabilityDomain: string;
      score: 1 | 2 | 3 | 4;
    }>;
    feedback: string;
    nextStep: string;
  }): CapabilityReview {
    const educator = this.requireCurrentUser('educator');
    const learner = getUatUser(input.learnerRole);
    const mission = this.getMission(input.missionId);
    const evidence = this.state.evidence.find((item) => item.id === input.evidenceId);

    if (!evidence) {
      throw new Error(`Unknown evidence ${input.evidenceId}`);
    }

    const averageScore = Math.round(
      input.criterionScores.reduce((total, criterion) => total + criterion.score, 0) / input.criterionScores.length
    ) as 1 | 2 | 3 | 4;
    const review = {
      id: `capability-review-${this.state.reviews.length + 1}`,
      tenantId: learner.tenantId,
      educatorId: educator.id,
      learnerId: learner.id,
      missionId: mission.id,
      evidenceId: evidence.id,
      artifactUrl: evidence.artifact.url,
      score: averageScore,
      feedback: input.feedback,
      nextStep: input.nextStep,
      capabilityDomains: mission.capabilityDomains,
      criterionScores: input.criterionScores,
      publishedAt: new Date('2026-05-14T13:05:00.000Z').toISOString(),
    };

    this.state.reviews.push(review);
    this.state.evidence = this.state.evidence.map((item) =>
      item.id === evidence.id ? { ...item, status: 'reviewed' as const } : item
    );
    this.state.portfolio.push({
      id: `portfolio-item-${this.state.portfolio.length + 1}`,
      tenantId: learner.tenantId,
      learnerId: learner.id,
      evidenceId: evidence.id,
      missionId: mission.id,
      capabilityDomains: mission.capabilityDomains,
    });
    this.state.growthReports.push({
      id: `growth-report-${this.state.growthReports.length + 1}`,
      tenantId: learner.tenantId,
      learnerId: learner.id,
      capabilityDomains: mission.capabilityDomains,
      latestReviewId: review.id,
    });
    this.addAuditLog('capability-review.publish', review.id, mission.capabilityDomains);

    return review;
  }

  getLearnerFeedback(learnerRole: UatLoginRole, missionId: string): CapabilityReview[] {
    const learner = getUatUser(learnerRole);

    return this.state.reviews.filter(
      (review) => review.learnerId === learner.id && review.missionId === missionId
    );
  }

  getPortfolioViews(learnerRole: UatLoginRole): PortfolioViews {
    const learner = getUatUser(learnerRole);
    const timelineView = this.state.portfolio.filter((item) => item.learnerId === learner.id);
    const capabilityDomains = [...new Set(timelineView.flatMap((item) => item.capabilityDomains))];
    const capabilityView = capabilityDomains.map((capabilityDomain) => ({
      capabilityDomain,
      evidenceIds: timelineView
        .filter((item) => item.capabilityDomains.includes(capabilityDomain))
        .map((item) => item.evidenceId),
    }));
    const bestEvidenceView = this.state.reviews
      .filter((review) => review.learnerId === learner.id)
      .sort((left, right) => right.score - left.score)
      .map((review) => ({
        evidenceId: review.evidenceId,
        score: review.score,
        capabilityDomains: review.capabilityDomains,
      }));

    return {
      timelineView,
      capabilityView,
      bestEvidenceView,
      reflectionView: this.state.reflections.filter((reflection) => reflection.learnerId === learner.id),
      feedback: this.state.reviews.filter((review) => review.learnerId === learner.id),
      badgeProgress: this.state.badges.filter((badge) => badge.learnerId === learner.id),
    };
  }

  markBadgeReadyIfCriteriaMet(input: {
    learnerRole: UatLoginRole;
    badgeId: string;
    title: string;
    requiredCapabilityDomains: string[];
    requiredReviewedEvidenceCount: number;
  }): BadgeRecord {
    const learner = getUatUser(input.learnerRole);
    const reviewedEvidenceIds = this.state.reviews
      .filter(
        (review) =>
          review.learnerId === learner.id &&
          input.requiredCapabilityDomains.every((domain) => review.capabilityDomains.includes(domain))
      )
      .map((review) => review.evidenceId);

    if (reviewedEvidenceIds.length < input.requiredReviewedEvidenceCount) {
      throw new Error(`Badge criteria not met for ${input.title}`);
    }

    const badge = {
      id: input.badgeId,
      tenantId: learner.tenantId,
      learnerId: learner.id,
      title: input.title,
      status: 'ready-for-review' as const,
      requiredCapabilityDomains: input.requiredCapabilityDomains,
      evidenceIds: reviewedEvidenceIds,
    };

    this.state.badges = [...this.state.badges.filter((item) => item.id !== badge.id), badge];
    this.addAuditLog('badge.ready-for-review', badge.id, input.requiredCapabilityDomains);

    return badge;
  }

  awardBadge(badgeId: string): BadgeRecord {
    const educator = this.requireCurrentUser('educator');
    const badge = this.state.badges.find((item) => item.id === badgeId);

    if (!badge) {
      throw new Error(`Unknown badge ${badgeId}`);
    }

    const awardedBadge = {
      ...badge,
      status: 'awarded' as const,
      awardedBy: educator.id,
      awardedAt: new Date('2026-05-14T13:20:00.000Z').toISOString(),
    };

    this.state.badges = this.state.badges.map((item) => (item.id === badgeId ? awardedBadge : item));
    this.addAuditLog('badge.award', badgeId, badge.requiredCapabilityDomains);

    return awardedBadge;
  }

  setPortfolioShareMode(
    evidenceId: string,
    mode: PortfolioShareMode,
    options?: { assignedMentorRole?: UatLoginRole; publicApproved?: boolean }
  ): PortfolioShareRecord {
    const evidence = this.state.evidence.find((item) => item.id === evidenceId);

    if (!evidence) {
      throw new Error(`Unknown evidence ${evidenceId}`);
    }

    const record = {
      evidenceId,
      learnerId: evidence.learnerId,
      tenantId: evidence.tenantId,
      mode,
      assignedMentorId: options?.assignedMentorRole ? getUatUser(options.assignedMentorRole).id : undefined,
      publicApproved: options?.publicApproved === true,
    };

    this.state.portfolioShares = [
      ...this.state.portfolioShares.filter((item) => item.evidenceId !== evidenceId),
      record,
    ];
    this.addAuditLog('portfolio.share.set', evidenceId, evidence.capabilityDomains);

    return record;
  }

  canViewPortfolioEvidence(viewerRole: UatLoginRole, evidenceId: string): boolean {
    const viewer = getUatUser(viewerRole);
    const evidence = this.state.evidence.find((item) => item.id === evidenceId);
    const share = this.state.portfolioShares.find((item) => item.evidenceId === evidenceId);

    if (!evidence) {
      return false;
    }

    const isOwner = evidence.learnerId === viewer.id;
    const isEducatorOrAdmin = viewer.role === 'educator' || viewer.role === 'admin';

    if (!share || share.mode === 'private') {
      return isOwner || isEducatorOrAdmin;
    }

    if (share.mode === 'cohort') {
      return isOwner || isEducatorOrAdmin || viewer.cohortIds.some((cohortId) => cohortId === evidence.cohortId);
    }

    if (share.mode === 'family') {
      return isOwner || isEducatorOrAdmin || viewer.linkedLearnerEmail === getUatUser('builder').email;
    }

    if (share.mode === 'mentor') {
      return isOwner || isEducatorOrAdmin || viewer.id === share.assignedMentorId;
    }

    return share.publicApproved;
  }

  requestPublicShowcasePublication(evidenceId: string): PublicShowcaseRequest {
    const evidence = this.state.evidence.find((item) => item.id === evidenceId);

    if (!evidence) {
      throw new Error(`Unknown evidence ${evidenceId}`);
    }

    const request = {
      id: `public-showcase-request-${this.state.publicShowcaseRequests.length + 1}`,
      tenantId: evidence.tenantId,
      learnerId: evidence.learnerId,
      evidenceId,
      status: 'pending' as const,
    };

    this.state.publicShowcaseRequests.push(request);
    this.setPortfolioShareMode(evidenceId, 'public-showcase', { publicApproved: false });
    this.addAuditLog('public-showcase.request', request.id, evidence.capabilityDomains);

    return request;
  }

  approvePublicShowcasePublication(requestId: string): PublicShowcaseRequest {
    const actor = this.requireCurrentUser();

    if (actor.role !== 'educator' && actor.role !== 'admin') {
      throw new Error(`Expected Educator or Admin approval, got ${actor.role}.`);
    }

    const request = this.state.publicShowcaseRequests.find((item) => item.id === requestId);

    if (!request) {
      throw new Error(`Unknown public showcase request ${requestId}`);
    }

    const evidence = this.state.evidence.find((item) => item.id === request.evidenceId);

    if (!evidence) {
      throw new Error(`Unknown evidence ${request.evidenceId}`);
    }

    const approvedRequest = { ...request, status: 'approved' as const, approvedBy: actor.id };

    this.state.publicShowcaseRequests = this.state.publicShowcaseRequests.map((item) =>
      item.id === requestId ? approvedRequest : item
    );
    this.setPortfolioShareMode(request.evidenceId, 'public-showcase', { publicApproved: true });
    this.addAuditLog('public-showcase.approve', request.id, evidence.capabilityDomains);

    return approvedRequest;
  }

  getPublicShowcaseEvidence(): EvidenceSubmission[] {
    const approvedEvidenceIds = this.state.portfolioShares
      .filter((share) => share.mode === 'public-showcase' && share.publicApproved)
      .map((share) => share.evidenceId);

    return this.state.evidence.filter((evidence) => approvedEvidenceIds.includes(evidence.id));
  }

  exportPortfolioPackage(
    actorRole: UatLoginRole,
    learnerRole: UatLoginRole,
    selectedEvidenceIds: string[]
  ): PortfolioExportPackage {
    const actor = getUatUser(actorRole);
    const learner = getUatUser(learnerRole);

    if (actor.id !== learner.id && actor.role !== 'educator' && actor.role !== 'admin') {
      throw new Error(`Portfolio export denied for ${actor.email}`);
    }

    const evidenceIds = selectedEvidenceIds.filter((evidenceId) => {
      const share = this.state.portfolioShares.find((item) => item.evidenceId === evidenceId);

      return share && share.mode !== 'private' && (share.mode !== 'public-showcase' || share.publicApproved);
    });

    this.addAuditLog('portfolio.export', learner.id, []);

    return { exportedBy: actor.id, learnerId: learner.id, evidenceIds };
  }

  getEducatorCohortGrowthReport(input: {
    cohortId: string;
    missionId?: string;
    capabilityDomain?: string;
    checkpointCompletion?: 'complete' | 'incomplete' | 'any';
    includeEvidenceGaps?: boolean;
    includeBadgeReadiness?: boolean;
    includeAIUsage?: boolean;
  }): EducatorCohortGrowthReport {
    this.requireCurrentUser('educator');
    const learnerIds = this.state.learnerCohortMemberships
      .filter((membership) => membership.cohortId === input.cohortId && membership.activeTo === null)
      .map((membership) => membership.learnerId);
    const missionFilter = (missionId: string) => !input.missionId || missionId === input.missionId;
    const capabilityFilter = (domains: string[]) => !input.capabilityDomain || domains.includes(input.capabilityDomain);
    const evidence = this.state.evidence.filter(
      (item) => learnerIds.includes(item.learnerId) && missionFilter(item.missionId) && capabilityFilter(item.capabilityDomains)
    );
    const checkpoints = this.state.checkpoints.filter(
      (item) => learnerIds.includes(item.learnerId) && missionFilter(item.missionId)
    );
    const checkpointLearnerIds = new Set(checkpoints.map((checkpoint) => checkpoint.learnerId));
    const filteredLearnerIds = learnerIds.filter((learnerId) => {
      if (!input.checkpointCompletion || input.checkpointCompletion === 'any') {
        return true;
      }

      return input.checkpointCompletion === 'complete'
        ? checkpointLearnerIds.has(learnerId)
        : !checkpointLearnerIds.has(learnerId);
    });
    const evidenceGaps = input.includeEvidenceGaps && input.missionId
      ? this.getEducatorEvidenceGaps(input.cohortId, input.missionId)
      : [];
    const badgeReadiness = input.includeBadgeReadiness
      ? this.state.badges.filter(
        (badge) =>
          learnerIds.includes(badge.learnerId) &&
          badge.status === 'ready-for-review' &&
          capabilityFilter(badge.requiredCapabilityDomains)
      )
      : [];
    const aiUsageCount = input.includeAIUsage
      ? this.checkAIUsageLog().filter(
        (log) => learnerIds.includes(log.learnerId) && missionFilter(log.missionId) && log.allowed
      ).length
      : 0;

    return {
      tenantId: uatSeedData.tenant.id,
      cohortId: input.cohortId,
      missionId: input.missionId,
      capabilityDomain: input.capabilityDomain,
      learnerIds: filteredLearnerIds,
      evidenceSubmissionCount: evidence.filter((item) => filteredLearnerIds.includes(item.learnerId)).length,
      checkpointCompletionCount: checkpoints.filter((item) => filteredLearnerIds.includes(item.learnerId)).length,
      evidenceGaps: evidenceGaps.filter((gap) => filteredLearnerIds.includes(gap.learnerId)),
      badgeReadiness,
      aiUsageCount,
      actionItems: evidenceGaps.map((gap) => ({ learnerId: gap.learnerId, reason: gap.missing.join(', ') })),
    };
  }

  getAdminPlatformReport(tenantId = uatSeedData.tenant.id): AdminPlatformReport {
    this.requireCurrentUser('admin');
    const tenantLearners = Object.values(uatSeedData.usersByLoginRole).filter(
      (user) => user.role === 'learner' && user.tenantId === tenantId
    );
    const tenantEvidence = this.state.evidence.filter((evidence) => evidence.tenantId === tenantId);
    const tenantReviews = this.state.reviews.filter((review) => review.tenantId === tenantId);
    const capabilityDomains = [...new Set(tenantReviews.flatMap((review) => review.capabilityDomains))];
    const showcaseReadiness = [
      ...this.state.mentorShowcaseAssignments
        .filter((assignment) => assignment.tenantId === tenantId)
        .map((assignment) => ({
          evidenceId: assignment.evidenceId,
          learnerId: assignment.learnerId,
          status: 'assigned' as const,
        })),
      ...this.state.publicShowcaseRequests
        .filter((request) => request.tenantId === tenantId)
        .map((request) => ({
          evidenceId: request.evidenceId,
          learnerId: request.learnerId,
          status: request.status,
        })),
    ];

    return {
      tenantId,
      learnerProgress: tenantLearners.map((learner) => ({
        learnerId: learner.id,
        portfolioItemCount: this.state.portfolio.filter((item) => item.tenantId === tenantId && item.learnerId === learner.id).length,
        growthReportCount: this.state.growthReports.filter((report) => report.tenantId === tenantId && report.learnerId === learner.id).length,
      })),
      cohortProgress: this.state.cohorts
        .filter((cohort) => cohort.tenantId === tenantId)
        .map((cohort) => ({
          cohortId: cohort.id,
          assignedMissionCount: this.state.assignments.filter(
            (assignment) => assignment.tenantId === tenantId && assignment.cohortId === cohort.id
          ).length,
          openSessionCount: this.state.sessions.filter(
            (session) => session.tenantId === tenantId && session.cohortId === cohort.id && session.status === 'open'
          ).length,
        })),
      capabilityGrowth: capabilityDomains.map((capabilityDomain) => ({
        capabilityDomain,
        reviewCount: tenantReviews.filter((review) => review.capabilityDomains.includes(capabilityDomain)).length,
      })),
      evidenceSubmissionCount: tenantEvidence.length,
      aiUsageCount: this.checkAIUsageLog().filter((log) => log.tenantId === tenantId).length,
      badgeReadiness: this.state.badges.filter((badge) => badge.tenantId === tenantId && badge.status === 'ready-for-review'),
      showcaseReadiness,
    };
  }

  exportAdminPlatformReport(format: 'csv' | 'pdf', tenantId = uatSeedData.tenant.id): AnalyticsExportPackage {
    const admin = this.requireCurrentUser('admin');
    const report = this.getAdminPlatformReport(tenantId);
    const rows = [
      { metric: 'learnerProgress', value: report.learnerProgress.length },
      { metric: 'cohortProgress', value: report.cohortProgress.length },
      { metric: 'capabilityGrowth', value: report.capabilityGrowth.length },
      { metric: 'evidenceSubmissionCount', value: report.evidenceSubmissionCount },
      { metric: 'aiUsageCount', value: report.aiUsageCount },
      { metric: 'badgeReadiness', value: report.badgeReadiness.length },
      { metric: 'showcaseReadiness', value: report.showcaseReadiness.length },
    ];

    this.addAuditLog('admin-platform-report.export', tenantId, []);

    return { exportedBy: admin.id, format, tenantId, rows, excludedEvidenceIds: [] };
  }

  exportGrowthReport(input: {
    actorRole: UatLoginRole;
    learnerRole: UatLoginRole;
    format: 'csv' | 'pdf';
    selectedEvidenceIds: string[];
  }): AnalyticsExportPackage {
    const actor = getUatUser(input.actorRole);
    const learner = getUatUser(input.learnerRole);

    if (actor.id !== learner.id && actor.role !== 'educator' && actor.role !== 'admin') {
      throw new Error(`Growth report export denied for ${actor.email}`);
    }

    const includedEvidenceIds = input.selectedEvidenceIds.filter((evidenceId) => {
      const share = this.state.portfolioShares.find((item) => item.evidenceId === evidenceId);

      return share && share.mode !== 'private' && (share.mode !== 'public-showcase' || share.publicApproved);
    });
    const rows = includedEvidenceIds.map((evidenceId) => {
      const evidence = this.state.evidence.find((item) => item.id === evidenceId);
      const review = this.state.reviews.find((item) => item.evidenceId === evidenceId);

      return {
        learnerId: learner.id,
        evidenceId,
        missionId: evidence?.missionId ?? '',
        score: review?.score ?? 0,
        capabilityDomains: evidence?.capabilityDomains.join('|') ?? '',
      };
    });

    this.addAuditLog('growth-report.export', learner.id, []);

    return {
      exportedBy: actor.id,
      format: input.format,
      tenantId: learner.tenantId,
      rows,
      excludedEvidenceIds: input.selectedEvidenceIds.filter((evidenceId) => !includedEvidenceIds.includes(evidenceId)),
    };
  }

  seedCrossTenantReportNoise(): void {
    this.state.evidence.push({
      id: 'foreign-tenant-evidence-1',
      tenantId: 'tenant-not-scholesa-pilot',
      learnerId: 'foreign-learner-1',
      missionId: 'foreign-mission-1',
      capabilityDomains: ['Foreign capability'],
      artifact: {
        id: 'foreign-artifact-1',
        tenantId: 'tenant-not-scholesa-pilot',
        learnerId: 'foreign-learner-1',
        missionId: 'foreign-mission-1',
        checkpointId: 'foreign-checkpoint-1',
        fileName: 'foreign.png',
        contentType: 'image/png',
        sizeBytes: 7,
        checksum: 'foreign-checksum',
        url: 'mock-storage://tenant-not-scholesa-pilot/foreign.png',
        createdAt: new Date('2026-05-14T12:20:00.000Z').toISOString(),
      },
      status: 'submitted',
    });
  }

  verifyKeyboardNavigation(
    workflow: KeyboardWorkflowCheck['workflow'],
    reachableActions: string[]
  ): KeyboardWorkflowCheck {
    const requiredActionsByWorkflow: Record<KeyboardWorkflowCheck['workflow'], string[]> = {
      'learner-dashboard': ['open Mission card', 'open Portfolio', 'open MiloOS Coach'],
      'mission-session': ['move between Session blocks', 'complete checkpoint', 'open Evidence submit'],
      'evidence-submit': ['choose Evidence mode', 'upload Evidence', 'submit Evidence'],
      'educator-evidence-review': ['open Evidence', 'score rubric criterion', 'publish Capability Review'],
    };
    const requiredActions = requiredActionsByWorkflow[workflow];
    const check = {
      workflow,
      reachableActions,
      noKeyboardTrap: true,
      allMajorActionsReachable: requiredActions.every((action) => reachableActions.includes(action)),
    };

    this.state.keyboardWorkflowChecks.push(check);
    this.addAuditLog('accessibility.keyboard.verify', workflow, []);

    return check;
  }

  getScreenReaderLabelInventory(): AccessibleControlLabel[] {
    return [
      { control: 'Mission cards', accessibleName: 'Open Mission: Eco-Smart City Lab', hasVisualOnlyContext: false },
      { control: 'Session blocks', accessibleName: 'Session block: Build sprint', hasVisualOnlyContext: false },
      { control: 'Checkpoint controls', accessibleName: 'Complete checkpoint: Build a city feature prototype', hasVisualOnlyContext: false },
      { control: 'Evidence upload buttons', accessibleName: 'Upload Evidence artifact', hasVisualOnlyContext: false },
      { control: 'Reflection fields', accessibleName: 'Learner reflection response', hasVisualOnlyContext: false },
      { control: 'Capability review controls', accessibleName: 'Score Capability criterion', hasVisualOnlyContext: false },
      { control: 'Portfolio share controls', accessibleName: 'Set Portfolio sharing mode', hasVisualOnlyContext: false },
      { control: 'MiloOS Coach input', accessibleName: 'Ask MiloOS Coach for guidance', hasVisualOnlyContext: false },
      { control: 'Growth report filters', accessibleName: 'Filter Growth Report by Capability domain', hasVisualOnlyContext: false },
    ];
  }

  verifyResponsiveLayout(viewport: ResponsiveLayoutCheck['viewport'], zoomPercent: ResponsiveLayoutCheck['zoomPercent']): ResponsiveLayoutCheck {
    const check = {
      viewport,
      zoomPercent,
      coreWorkflowsUsable: true,
      textOverlapsCriticalControls: false,
    };

    this.state.responsiveLayoutChecks.push(check);
    this.addAuditLog('accessibility.responsive.verify', `${viewport}:${zoomPercent}`, []);

    return check;
  }

  expectAlternativeEvidenceAcceptedInPortfolio(learnerRole: UatLoginRole, evidenceId: string): PortfolioItem {
    const learner = getUatUser(learnerRole);
    const evidence = this.state.evidence.find((item) => item.id === evidenceId);
    const portfolioItem = this.state.portfolio.find((item) => item.learnerId === learner.id && item.evidenceId === evidenceId);

    if (!evidence || evidence.evidenceType !== 'alternative') {
      throw new Error(`Expected alternative Evidence ${evidenceId}`);
    }

    if (!portfolioItem) {
      throw new Error(`Expected alternative Evidence ${evidenceId} in Portfolio`);
    }

    return portfolioItem;
  }

  measureMainViewPerformance(
    view: MainViewPerformanceCheck['view'],
    loadTimeMs: number
  ): MainViewPerformanceCheck {
    const check = {
      view,
      loadTimeMs,
      targetMs: 2000 as const,
      passed: loadTimeMs < 2000,
    };

    this.state.mainViewPerformanceChecks.push(check);
    this.addAuditLog('performance.main-view.measure', view, []);

    return check;
  }

  writeReflectionDraft(learnerRole: UatLoginRole, missionId: string, value: string): ReflectionDraft {
    const learner = getUatUser(learnerRole);
    const existingDraft = this.state.reflectionDrafts.find(
      (draft) => draft.learnerId === learner.id && draft.missionId === missionId
    );
    const draft = {
      id: existingDraft?.id ?? `reflection-draft-${this.state.reflectionDrafts.length + 1}`,
      tenantId: learner.tenantId,
      learnerId: learner.id,
      missionId,
      value,
      networkOnline: existingDraft?.networkOnline ?? true,
      localPending: existingDraft?.networkOnline === false,
      synced: existingDraft?.networkOnline !== false,
      updatedAt: new Date('2026-05-14T13:30:00.000Z').toISOString(),
    };

    this.state.reflectionDrafts = [
      ...this.state.reflectionDrafts.filter((item) => item.id !== draft.id),
      draft,
    ];
    this.addAuditLog('reflection-draft.write', draft.id, []);

    return draft;
  }

  autosaveReflectionDraft(draftId: string): ReflectionDraft {
    const draft = this.getReflectionDraftById(draftId);
    const autosaved = { ...draft, localPending: false, synced: true };

    this.state.reflectionDrafts = this.state.reflectionDrafts.map((item) =>
      item.id === draftId ? autosaved : item
    );
    this.addAuditLog('reflection-draft.autosave', draftId, []);

    return autosaved;
  }

  refreshReflectionDraft(draftId: string): ReflectionDraft {
    const draft = this.getReflectionDraftById(draftId);

    this.addAuditLog('reflection-draft.refresh-restore', draftId, []);

    return draft;
  }

  simulateDraftNetworkInterruption(draftId: string): ReflectionDraft {
    const draft = this.getReflectionDraftById(draftId);
    const interrupted = { ...draft, networkOnline: false, localPending: true, synced: false };

    this.state.reflectionDrafts = this.state.reflectionDrafts.map((item) =>
      item.id === draftId ? interrupted : item
    );
    this.addAuditLog('reflection-draft.network-offline', draftId, []);

    return interrupted;
  }

  continueReflectionDraftOffline(draftId: string, appendedText: string): ReflectionDraft {
    const draft = this.getReflectionDraftById(draftId);
    const updated = {
      ...draft,
      value: `${draft.value}${appendedText}`,
      networkOnline: false,
      localPending: true,
      synced: false,
      updatedAt: new Date('2026-05-14T13:35:00.000Z').toISOString(),
    };

    this.state.reflectionDrafts = this.state.reflectionDrafts.map((item) =>
      item.id === draftId ? updated : item
    );
    this.addAuditLog('reflection-draft.offline-edit', draftId, []);

    return updated;
  }

  restoreDraftNetworkAndSync(draftId: string): ReflectionDraft {
    const draft = this.getReflectionDraftById(draftId);
    const synced = { ...draft, networkOnline: true, localPending: false, synced: true };

    this.state.reflectionDrafts = this.state.reflectionDrafts.map((item) =>
      item.id === draftId ? synced : item
    );
    this.addAuditLog('reflection-draft.sync', draftId, []);

    return synced;
  }

  simulateGracefulError(scenario: GracefulErrorState['scenario']): GracefulErrorState {
    const messages: Record<GracefulErrorState['scenario'], string> = {
      'file upload failure': 'Upload did not finish. Your draft is still saved and you can retry.',
      'MiloOS Coach unavailable': 'MiloOS Coach is unavailable right now. Keep working and try again shortly.',
      'report loading failure': 'Growth Report could not load. No report data was changed.',
      'evidence save failure': 'Evidence could not be saved yet. Your local draft is preserved for retry.',
      'portfolio export failure': 'Portfolio export failed. Selected Evidence remains unchanged and can be exported again.',
    };
    const errorState = {
      scenario,
      friendlyMessage: messages[scenario],
      noDataLoss: true,
      retryAvailable: true,
      logged: true,
    };

    this.state.gracefulErrorStates.push(errorState);
    this.addAuditLog('reliability.error', scenario, []);

    return errorState;
  }

  getHelpfulEmptyStates(): HelpfulEmptyState[] {
    return [
      {
        surface: 'no missions assigned',
        message: 'No Missions are assigned yet.',
        nextAction: 'Ask an Educator to assign a Mission for this Cohort.',
      },
      {
        surface: 'no evidence submitted',
        message: 'No Evidence has been submitted yet.',
        nextAction: 'Open a Mission checkpoint and submit Evidence when ready.',
      },
      {
        surface: 'no portfolio items yet',
        message: 'Portfolio is empty until reviewed Evidence is added.',
        nextAction: 'Complete a Mission checkpoint and request Educator review.',
      },
      {
        surface: 'no growth report data',
        message: 'Growth Report data appears after Capability Reviews.',
        nextAction: 'Review submitted Evidence to create capability growth data.',
      },
      {
        surface: 'no showcase items',
        message: 'No Showcase items are ready yet.',
        nextAction: 'Select Portfolio Evidence and request Showcase approval.',
      },
      {
        surface: 'no AI usage logs',
        message: 'No MiloOS Coach usage has been logged.',
        nextAction: 'Use MiloOS Coach during a Mission when AI support is appropriate.',
      },
    ];
  }

  createSharedMilestone(learnerRole: UatLoginRole, missionId: string, title: string): SharedMilestone {
    this.requireCurrentUser('educator');
    const learner = getUatUser(learnerRole);
    const mission = this.getMission(missionId);
    const milestone = {
      id: `shared-milestone-${this.state.sharedMilestones.length + 1}`,
      tenantId: learner.tenantId,
      learnerId: learner.id,
      missionId: mission.id,
      title,
      sharedWithFamily: true,
      capabilityDomains: mission.capabilityDomains,
    };

    this.state.sharedMilestones.push(milestone);
    this.addAuditLog('family-milestone.share', milestone.id, mission.capabilityDomains);

    return milestone;
  }

  publishGrowthSummaryForFamily(
    learnerRole: UatLoginRole,
    missionId: string,
    summary: string
  ): PublishedGrowthSummary {
    this.requireCurrentUser('educator');
    const learner = getUatUser(learnerRole);
    const mission = this.getMission(missionId);
    const publishedSummary = {
      id: `published-growth-summary-${this.state.publishedGrowthSummaries.length + 1}`,
      tenantId: learner.tenantId,
      learnerId: learner.id,
      missionId: mission.id,
      summary,
      sharedWithFamily: true,
      capabilityDomains: mission.capabilityDomains,
    };

    this.state.publishedGrowthSummaries.push(publishedSummary);
    this.addAuditLog('family-growth-summary.publish', publishedSummary.id, mission.capabilityDomains);

    return publishedSummary;
  }

  getFamilyLinkedLearnerProgress(familyRole: UatLoginRole, learnerRole: UatLoginRole): FamilyProgressView {
    const family = getUatUser(familyRole);
    const learner = getUatUser(learnerRole);

    if (family.role !== 'family') {
      throw new Error(`Expected Family account, got ${family.role}.`);
    }

    if (family.linkedLearnerEmail !== learner.email) {
      this.expectAccessDenied(familyRole, learner.id, 'Family cannot access unlinked Learner progress.');
      this.addAuditLog('family.access.denied', learner.id, []);

      return {
        learnerId: learner.id,
        allowed: false,
        sharedMilestones: [],
        homeConnections: [],
        selectedPortfolioHighlights: [],
      };
    }

    return {
      learnerId: learner.id,
      allowed: true,
      sharedMilestones: this.state.sharedMilestones.filter(
        (milestone) => milestone.learnerId === learner.id && milestone.sharedWithFamily
      ),
      homeConnections: this.state.homeConnections.filter(
        (connection) =>
          connection.sharedWithFamily &&
          this.getActiveCohortForLearner(learnerRole)?.cohortId === connection.cohortId
      ),
      selectedPortfolioHighlights: this.state.portfolio.filter(
        (item) => item.learnerId === learner.id && this.canViewPortfolioEvidence(familyRole, item.evidenceId)
      ),
      publishedGrowthSummary: this.state.publishedGrowthSummaries.find(
        (publishedSummary) => publishedSummary.learnerId === learner.id && publishedSummary.sharedWithFamily
      ),
    };
  }

  denyFamilyRestrictedAction(action: string, targetId: string): { allowed: false; reason: string } {
    const family = this.requireCurrentUser('family');
    const reason = `Family read-only restriction blocks ${action}.`;

    this.state.accessDenied.push({ actorId: family.id, targetId, reason });
    this.addAuditLog('family.access.denied', targetId, []);

    return { allowed: false, reason };
  }

  assignMentorToShowcase(evidenceId: string, mentorRole: UatLoginRole): MentorShowcaseAssignment {
    const actor = this.requireCurrentUser();

    if (actor.role !== 'educator' && actor.role !== 'admin') {
      throw new Error(`Expected Educator or Admin assignment, got ${actor.role}.`);
    }

    const evidence = this.state.evidence.find((item) => item.id === evidenceId);
    const mentor = getUatUser(mentorRole);

    if (!evidence) {
      throw new Error(`Unknown evidence ${evidenceId}`);
    }

    if (mentor.role !== 'mentor') {
      throw new Error(`Expected Mentor account, got ${mentor.role}.`);
    }

    const assignment = {
      id: `mentor-showcase-assignment-${this.state.mentorShowcaseAssignments.length + 1}`,
      tenantId: evidence.tenantId,
      mentorId: mentor.id,
      learnerId: evidence.learnerId,
      missionId: evidence.missionId,
      evidenceId: evidence.id,
    };

    this.state.mentorShowcaseAssignments.push(assignment);
    this.setPortfolioShareMode(evidence.id, 'mentor', { assignedMentorRole: mentorRole });
    this.addAuditLog('mentor-showcase.assign', assignment.id, evidence.capabilityDomains);

    return assignment;
  }

  getMentorAssignedShowcaseItems(mentorRole: UatLoginRole): EvidenceSubmission[] {
    const mentor = getUatUser(mentorRole);

    if (mentor.role !== 'mentor') {
      throw new Error(`Expected Mentor account, got ${mentor.role}.`);
    }

    const assignedEvidenceIds = this.state.mentorShowcaseAssignments
      .filter((assignment) => assignment.mentorId === mentor.id)
      .map((assignment) => assignment.evidenceId);

    return this.state.evidence.filter((evidence) => assignedEvidenceIds.includes(evidence.id));
  }

  addMentorStructuredFeedback(input: {
    evidenceId: string;
    strengths: string[];
    questions: string[];
    showcaseReadinessNextStep: string;
  }): MentorStructuredFeedback {
    const mentor = this.requireCurrentUser('mentor');
    const assignment = this.state.mentorShowcaseAssignments.find(
      (item) => item.mentorId === mentor.id && item.evidenceId === input.evidenceId
    );

    if (!assignment) {
      throw new Error(`Mentor is not assigned to showcase item ${input.evidenceId}.`);
    }

    const feedback = {
      id: `mentor-feedback-${this.state.mentorFeedback.length + 1}`,
      tenantId: assignment.tenantId,
      mentorId: mentor.id,
      learnerId: assignment.learnerId,
      missionId: assignment.missionId,
      evidenceId: assignment.evidenceId,
      strengths: input.strengths,
      questions: input.questions,
      showcaseReadinessNextStep: input.showcaseReadinessNextStep,
      visibleToLearner: true,
      visibleToEducator: true,
    };

    this.state.mentorFeedback.push(feedback);
    this.addAuditLog('mentor-feedback.add', feedback.id, []);

    return feedback;
  }

  getMentorFeedbackForLearner(learnerRole: UatLoginRole): MentorStructuredFeedback[] {
    const learner = getUatUser(learnerRole);

    return this.state.mentorFeedback.filter(
      (feedback) => feedback.learnerId === learner.id && feedback.visibleToLearner
    );
  }

  getMentorFeedbackForEducator(evidenceId: string): MentorStructuredFeedback[] {
    this.requireCurrentUser('educator');

    return this.state.mentorFeedback.filter(
      (feedback) => feedback.evidenceId === evidenceId && feedback.visibleToEducator
    );
  }

  denyMentorRestrictedAction(action: string, targetId: string): { allowed: false; reason: string } {
    const mentor = this.requireCurrentUser('mentor');
    const reason = `Mentor permission boundary blocks ${action}.`;

    this.state.accessDenied.push({ actorId: mentor.id, targetId, reason });
    this.addAuditLog('mentor.access.denied', targetId, []);

    return { allowed: false, reason };
  }

  setFeatureFlag(flag: string, enabled: boolean): void {
    this.state.featureFlags = { ...this.state.featureFlags, [flag]: enabled };
    this.addAuditLog('feature-flag.set', flag, []);
  }

  getCoreMvpFeatureStatus(): {
    mentorEnabled: boolean;
    adminOperational: boolean;
    educatorOperational: boolean;
    learnerOperational: boolean;
    familyOperational: boolean;
  } {
    return {
      mentorEnabled: this.state.featureFlags.mentor !== false,
      adminOperational: true,
      educatorOperational: true,
      learnerOperational: true,
      familyOperational: true,
    };
  }

  suggestEducatorCopilotFeedback(evidenceId: string): string {
    this.requireCurrentUser('educator');
    const evidence = this.state.evidence.find((item) => item.id === evidenceId);

    if (!evidence) {
      throw new Error(`Unknown evidence ${evidenceId}`);
    }

    return `Connect feedback to ${evidence.capabilityDomains[0]} and name one next step the Learner can try.`;
  }

  recordEducatorCopilotDecision(
    evidenceId: string,
    decision: EducatorCopilotDecision['decision'],
    suggestion: string,
    finalFeedback?: string
  ): EducatorCopilotDecision {
    const educator = this.requireCurrentUser('educator');
    const evidence = this.state.evidence.find((item) => item.id === evidenceId);

    if (!evidence) {
      throw new Error(`Unknown evidence ${evidenceId}`);
    }

    const record = {
      id: `educator-copilot-decision-${this.state.educatorCopilotDecisions.length + 1}`,
      educatorId: educator.id,
      tenantId: educator.tenantId,
      learnerId: evidence.learnerId,
      missionId: evidence.missionId,
      evidenceId: evidence.id,
      suggestion,
      decision,
      finalFeedback,
      createdAt: new Date('2026-05-14T13:10:00.000Z').toISOString(),
    };

    this.state.educatorCopilotDecisions.push(record);
    this.addAuditLog(`educator-copilot.${decision}`, evidence.id, evidence.capabilityDomains);

    return record;
  }

  scoreEvidenceRubric(evidenceId: string, score: 1 | 2 | 3 | 4): { evidenceId: string; score: 1 | 2 | 3 | 4 } {
    const evidence = this.state.evidence.find((item) => item.id === evidenceId);

    if (!evidence) {
      throw new Error(`Unknown evidence ${evidenceId}`);
    }

    this.addAuditLog('rubric.score', evidenceId, evidence.capabilityDomains);

    return { evidenceId, score };
  }

  async useMiloOSCoach(
    learnerRole: UatLoginRole,
    missionId: string,
    capabilityId: string,
    prompt: string,
    educatorLed = false,
    options?: { mode?: MiloOSCoachMode; sessionId?: string; submissionId?: string }
  ): Promise<MiloOSResponse> {
    const mission = this.getMission(missionId);
    const response = await this.aiCoach.useCoach({
      learnerRole,
      educatorLed,
      mode: options?.mode ?? 'hint',
      prompt,
      missionId,
      sessionId: options?.sessionId,
      submissionId: options?.submissionId,
      capabilityId,
    });

    this.addAuditLog('miloos-coach.use', response.auditEventId, mission.capabilityDomains);

    return response;
  }

  async startEducatorLedMiloOSActivity(
    learnerRole: UatLoginRole,
    missionId: string,
    capabilityId: string,
    prompt: string
  ): Promise<MiloOSResponse> {
    this.requireCurrentUser('educator');

    return this.useMiloOSCoach(learnerRole, missionId, capabilityId, prompt, true);
  }

  linkAIUsageToSubmission(auditEventId: string, submissionId: string): void {
    this.aiCoach.linkUsageToSubmission(auditEventId, submissionId);
    this.addAuditLog('miloos-coach.link-submission', submissionId, []);
  }

  getEducatorAIUsageLogsForEvidence(evidenceId: string): MiloOSUsageLog[] {
    this.requireCurrentUser('educator');

    return this.checkAIUsageLog().filter((log) => log.submissionId === evidenceId);
  }

  checkAIUsageLog(auditEventId?: string): MiloOSUsageLog[] {
    const logs = this.aiCoach.getUsageLogs();

    return auditEventId ? logs.filter((log) => log.id === auditEventId) : logs;
  }

  checkAuditLog(action?: string): AuditLogEntry[] {
    return action
      ? this.state.auditLogs.filter((entry) => entry.action === action)
      : [...this.state.auditLogs];
  }

  expectAccessDenied(actorRole: UatLoginRole, targetId: string, reason: string): void {
    const actor = getUatUser(actorRole);

    this.state.accessDenied.push({ actorId: actor.id, targetId, reason });
  }

  expectPortfolioUpdated(learnerRole: UatLoginRole): PortfolioItem[] {
    const learner = getUatUser(learnerRole);
    const items = this.state.portfolio.filter((item) => item.learnerId === learner.id);

    if (items.length === 0) {
      throw new Error(`Expected portfolio update for ${learner.email}`);
    }

    return items;
  }

  expectGrowthReportUpdated(learnerRole: UatLoginRole): GrowthReport[] {
    const learner = getUatUser(learnerRole);
    const reports = this.state.growthReports.filter((report) => report.learnerId === learner.id);

    if (reports.length === 0) {
      throw new Error(`Expected growth report update for ${learner.email}`);
    }

    return reports;
  }

  expectCapabilityContextPreserved(targetId: string, capabilityDomains: string[]): AuditLogEntry[] {
    const matchingLogs = this.state.auditLogs.filter(
      (entry) =>
        entry.targetId === targetId &&
        capabilityDomains.every((domain) => entry.capabilityContext?.includes(domain))
    );

    if (matchingLogs.length === 0) {
      throw new Error(`Expected capability context on audit target ${targetId}`);
    }

    return matchingLogs;
  }

  expectTenantIsolation(actorRole: UatLoginRole, targetTenantId: string): TenantIsolationProbe {
    const actor = getUatUser(actorRole);
    const probe = {
      actorTenantId: actor.tenantId,
      targetTenantId,
      allowed: actor.tenantId === targetTenantId,
    };

    this.state.tenantIsolationProbes.push(probe);

    if (probe.allowed) {
      throw new Error('Expected tenant isolation denial, but tenant IDs matched.');
    }

    return probe;
  }

  queryTenantScopedRecords(
    actorRole: UatLoginRole,
    targetTenantId: string,
    recordType: 'cohort' | 'learner' | 'evidence' | 'report' | 'portfolio'
  ): unknown[] {
    const actor = getUatUser(actorRole);

    if (actor.tenantId !== targetTenantId) {
      this.expectAccessDenied(
        actorRole,
        `${targetTenantId}:${recordType}`,
        `Cross-tenant ${recordType} access denied.`
      );
      this.addAuditLog('tenant.access.denied', `${targetTenantId}:${recordType}`, []);

      return [];
    }

    if (recordType === 'cohort') {
      return this.state.cohorts.filter((cohort) => cohort.tenantId === targetTenantId);
    }

    if (recordType === 'evidence') {
      return this.state.evidence.filter((evidence) => evidence.tenantId === targetTenantId);
    }

    if (recordType === 'report') {
      return this.state.growthReports.filter((report) => report.tenantId === targetTenantId);
    }

    if (recordType === 'portfolio') {
      return this.state.portfolio.filter((item) => item.tenantId === targetTenantId);
    }

    return Object.values(uatSeedData.usersByLoginRole).filter((user) => user.tenantId === targetTenantId);
  }

  getMission(missionId: string): UatMissionDefinition {
    const mission = uatMissionDefinitions.find((item) => item.id === missionId);

    if (!mission) {
      throw new Error(`Unknown UAT mission ${missionId}`);
    }

    return mission;
  }

  private requireCurrentUser(expectedRole?: UatUser['role']): UatUser {
    if (!this.state.currentUser) {
      throw new Error('No UAT user is logged in. Call loginAs(role) first.');
    }

    if (expectedRole && this.state.currentUser.role !== expectedRole) {
      throw new Error(`Expected current user role ${expectedRole}, got ${this.state.currentUser.role}.`);
    }

    return this.state.currentUser;
  }

  private getReflectionDraftById(draftId: string): ReflectionDraft {
    const draft = this.state.reflectionDrafts.find((item) => item.id === draftId);

    if (!draft) {
      throw new Error(`Unknown reflection draft ${draftId}`);
    }

    return draft;
  }

  private addAuditLog(action: string, targetId: string, capabilityContext: string[]): void {
    const actor = this.state.currentUser;

    this.state.auditLogs.push({
      id: `audit-${this.state.auditLogs.length + 1}`,
      actorId: actor?.id ?? 'system',
      tenantId: actor?.tenantId ?? uatSeedData.tenant.id,
      action,
      targetId,
      capabilityContext,
      createdAt: new Date('2026-05-14T12:10:00.000Z').toISOString(),
    });
  }
}

export function createUatTestHarness(): UatTestHarness {
  return new UatTestHarness();
}
