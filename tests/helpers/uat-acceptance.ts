import { type UatMissionDefinition } from '../fixtures/uat-missions';
import { type UatLoginRole } from '../fixtures/uat-seed-data';
import { type UatApiAction, type UatApiClient } from './uat-api-client';
import { type UatTestHarness } from './uat-state';

function assert(condition: unknown, message: string): asserts condition {
  if (!condition) {
    throw new Error(message);
  }
}

export type UatUiState = 'loading' | 'empty' | 'error' | 'success';

export const requiredScholesaTerminology = [
  'Educator',
  'Learner',
  'Family',
  'Cohort',
  'Mission',
  'Session',
  'Evidence',
  'Capability Review',
  'Growth Report',
  'Portfolio',
  'Showcase',
  'MiloOS Coach',
] as const;

export type UatAcceptanceInput = {
  harness: UatTestHarness;
  api: UatApiClient;
  mission: UatMissionDefinition;
  action: UatApiAction;
  correctRole: UatLoginRole;
  incorrectRole: UatLoginRole;
  learnerRole: UatLoginRole;
  uiStates: Record<UatUiState, string>;
  uiCopy: string;
};

export async function verifyUatAcceptanceCriteria(input: UatAcceptanceInput): Promise<void> {
  const allowedResponse = await input.api.performAction(input.correctRole, input.action, input.mission);
  const blockedResponse = await input.api.performAction(input.incorrectRole, input.action, input.mission);
  const actionConfig = input.api.getActionConfig(input.action);

  assert(allowedResponse.ok, `Expected ${input.correctRole} to perform ${input.action}.`);
  assert([200, 201].includes(allowedResponse.status), `Expected success status for ${input.action}.`);

  assert(!blockedResponse.ok, `Expected ${input.incorrectRole} to be blocked from ${input.action}.`);
  assert(blockedResponse.status === 403, `Expected 403 for blocked ${input.action}.`);
  assert(
    input.harness.state.accessDenied.some((entry) => entry.targetId === input.action),
    `Expected access denied record for ${input.action}.`
  );

  assert(
    input.harness.expectTenantIsolation(input.incorrectRole, 'tenant-unauthorized-uat').allowed === false,
    'Expected tenant isolation to deny cross-tenant access.'
  );

  if (actionConfig.capabilityContextRequired) {
    const contextLog = input.harness
      .checkAuditLog()
      .find((entry) =>
        input.mission.capabilityDomains.every((domain) => entry.capabilityContext?.includes(domain))
      );
    assert(contextLog, `Expected capability context to be preserved for ${input.action}.`);
  }

  const savedLearningState =
    input.harness.state.evidence.length +
    input.harness.state.reflections.length +
    input.harness.state.checkpoints.length +
    input.harness.state.reviews.length +
    input.harness.state.portfolio.length +
    input.harness.state.growthReports.length +
    input.harness.checkAIUsageLog().length;
  assert(savedLearningState > 0, `Expected ${input.action} to save evidence or learning state.`);

  if (actionConfig.auditRequired) {
    assert(input.harness.checkAuditLog().length > 0, `Expected audit log for ${input.action}.`);
  }

  assert(
    Object.keys(input.uiStates).sort().join(',') === 'empty,error,loading,success',
    'Expected loading, empty, error, and success UI states.'
  );
  assert(/loading/i.test(input.uiStates.loading), 'Expected loading UI state copy.');
  assert(/empty|no evidence|no missions|not yet/i.test(input.uiStates.empty), 'Expected empty UI state copy.');
  assert(/error|denied|unable/i.test(input.uiStates.error), 'Expected error UI state copy.');
  assert(/success|saved|updated|submitted/i.test(input.uiStates.success), 'Expected success UI state copy.');

  for (const term of requiredScholesaTerminology) {
    assert(input.uiCopy.includes(term), `Expected UI copy to use Scholesa term: ${term}.`);
  }
}
