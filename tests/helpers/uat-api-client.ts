import { getUatMissionByStage, type UatMissionDefinition } from '../fixtures/uat-missions';
import { getUatUser, type UatLoginRole, type UatUser } from '../fixtures/uat-seed-data';
import { type UatTestHarness } from './uat-state';

export type UatApiAction =
  | 'createTenant'
  | 'createOrganization'
  | 'createCohort'
  | 'assignMission'
  | 'openMissionSession'
  | 'submitEvidence'
  | 'submitReflection'
  | 'performCapabilityReview'
  | 'viewPortfolio'
  | 'viewGrowthReport'
  | 'useMiloOSCoach';

export type UatApiResponse<T = unknown> = {
  ok: boolean;
  status: 200 | 201 | 403 | 404;
  action: UatApiAction;
  actor: UatUser;
  data?: T;
  error?: string;
};

type UatApiActionConfig = {
  allowedRoles: UatUser['role'][];
  auditRequired: boolean;
  capabilityContextRequired: boolean;
};

const actionConfig: Record<UatApiAction, UatApiActionConfig> = {
  createTenant: { allowedRoles: ['admin'], auditRequired: true, capabilityContextRequired: false },
  createOrganization: { allowedRoles: ['admin'], auditRequired: true, capabilityContextRequired: false },
  createCohort: { allowedRoles: ['admin'], auditRequired: true, capabilityContextRequired: false },
  assignMission: { allowedRoles: ['educator'], auditRequired: true, capabilityContextRequired: true },
  openMissionSession: { allowedRoles: ['educator'], auditRequired: true, capabilityContextRequired: true },
  submitEvidence: { allowedRoles: ['learner'], auditRequired: true, capabilityContextRequired: true },
  submitReflection: { allowedRoles: ['learner'], auditRequired: true, capabilityContextRequired: true },
  performCapabilityReview: { allowedRoles: ['educator'], auditRequired: true, capabilityContextRequired: true },
  viewPortfolio: { allowedRoles: ['learner', 'family', 'mentor', 'educator'], auditRequired: false, capabilityContextRequired: true },
  viewGrowthReport: { allowedRoles: ['learner', 'family', 'educator'], auditRequired: false, capabilityContextRequired: true },
  useMiloOSCoach: { allowedRoles: ['learner', 'educator'], auditRequired: true, capabilityContextRequired: true },
};

export class UatApiClient {
  constructor(private readonly harness: UatTestHarness) {}

  getActionConfig(action: UatApiAction): UatApiActionConfig {
    return actionConfig[action];
  }

  async performAction(
    actorRole: UatLoginRole,
    action: UatApiAction,
    mission: UatMissionDefinition = getUatMissionByStage('Builders')
  ): Promise<UatApiResponse> {
    const actor = getUatUser(actorRole);
    const config = actionConfig[action];

    if (!config.allowedRoles.includes(actor.role)) {
      this.harness.expectAccessDenied(
        actorRole,
        action,
        `${actor.role} cannot perform backend/API action ${action}.`
      );

      return {
        ok: false,
        status: 403,
        action,
        actor,
        error: 'Access denied by UAT backend/API permission policy.',
      };
    }

    this.harness.loginAs(actorRole);

    switch (action) {
      case 'createTenant':
        return this.ok(actor, action, this.harness.createTenant());
      case 'createOrganization':
        return this.ok(actor, action, this.harness.createOrganization());
      case 'createCohort':
        return this.ok(actor, action, this.harness.createCohort('cohort-builders-4-6'));
      case 'assignMission':
        return this.ok(actor, action, this.harness.assignMission(mission.id, 'cohort-builders-4-6'));
      case 'openMissionSession':
        return this.ok(actor, action, this.harness.openMissionSession(mission.id, 'cohort-builders-4-6'));
      case 'submitEvidence':
        return this.ok(actor, action, await this.harness.submitEvidence(actorRole, mission.id));
      case 'submitReflection':
        return this.ok(
          actor,
          action,
          this.harness.submitReflection(actorRole, mission.id, 'I can explain what evidence changed my next step.')
        );
      case 'performCapabilityReview': {
        const evidence = await this.harness.submitEvidence('builder', mission.id);
        return this.ok(
          actor,
          action,
          this.harness.performCapabilityReview(
            'builder',
            mission.id,
            evidence.id,
            3,
            'Evidence supports a capability review with clear provenance.'
          )
        );
      }
      case 'viewPortfolio':
        return this.ok(actor, action, { learnerId: getUatUser('builder').id, missionId: mission.id });
      case 'viewGrowthReport':
        return this.ok(actor, action, { learnerId: getUatUser('builder').id, missionId: mission.id });
      case 'useMiloOSCoach':
        return this.ok(
          actor,
          action,
          await this.harness.useMiloOSCoach(
            actorRole === 'educator' ? 'builder' : actorRole,
            mission.id,
            mission.capabilityDomains[0],
            'Give deterministic support for this UAT mission.',
            actorRole === 'educator'
          )
        );
      default:
        return {
          ok: false,
          status: 404,
          action,
          actor,
          error: 'Unknown UAT backend/API action.',
        };
    }
  }

  private ok(actor: UatUser, action: UatApiAction, data: unknown): UatApiResponse {
    return {
      ok: true,
      status: 201,
      action,
      actor,
      data,
    };
  }
}

export function createUatApiClient(harness: UatTestHarness): UatApiClient {
  return new UatApiClient(harness);
}
