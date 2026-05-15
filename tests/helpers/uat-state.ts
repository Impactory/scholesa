import { uatMissionDefinitions, type UatMissionDefinition } from '../fixtures/uat-missions';
import { getUatUser, uatSeedData, type UatLoginRole, type UatUser } from '../fixtures/uat-seed-data';
import { MockEvidenceStorage, type MockEvidenceFile } from './mock-file-storage';
import { MockMiloOSCoach, type MiloOSResponse, type MiloOSUsageLog } from './mock-ai-service';

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
  missionId: string;
  capabilityDomains: string[];
  artifact: MockEvidenceFile;
  status: 'submitted' | 'reviewed';
};

type ReflectionSubmission = {
  id: string;
  tenantId: string;
  learnerId: string;
  missionId: string;
  response: string;
};

type CapabilityReview = {
  id: string;
  tenantId: string;
  educatorId: string;
  learnerId: string;
  missionId: string;
  evidenceId: string;
  score: 1 | 2 | 3 | 4;
  feedback: string;
  capabilityDomains: string[];
};

type PortfolioItem = {
  id: string;
  tenantId: string;
  learnerId: string;
  evidenceId: string;
  missionId: string;
  capabilityDomains: string[];
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
  growthReports: GrowthReport[];
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
    growthReports: [],
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
    educatorLed = false
  ): Promise<MiloOSResponse> {
    const response = await this.aiCoach.useCoach({
      learnerRole,
      educatorLed,
      mode: 'hint',
      prompt,
      missionId,
      capabilityId,
    });

    this.addAuditLog('miloos-coach.use', response.auditEventId, [capabilityId]);

    return response;
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
