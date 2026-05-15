import { uatMissionDefinitions } from '../fixtures/uat-missions';
import {
  createUatApiClient,
  createUatTestHarness,
  requiredScholesaTerminology,
  verifyUatAcceptanceCriteria,
} from '../helpers';

const roleByMissionStage = {
  Discoverers: 'discoverer',
  Builders: 'builder',
  Explorers: 'explorer',
  Innovators: 'innovator',
} as const;

describe('UAT mission acceptance criteria', () => {
  it.each(uatMissionDefinitions)(
    '$title verifies role access, isolation, capability context, persistence, audit, UI states, terminology, and backend/API permissions',
    async (mission) => {
      const harness = createUatTestHarness();
      const api = createUatApiClient(harness);
      const learnerRole = roleByMissionStage[mission.stage];

      await verifyUatAcceptanceCriteria({
        harness,
        api,
        mission,
        action: 'submitEvidence',
        correctRole: learnerRole,
        incorrectRole: 'mentor',
        learnerRole,
        uiStates: {
          loading: `Loading ${mission.title} Mission Evidence...`,
          empty: 'No Evidence has been submitted for this Mission yet.',
          error: 'Access denied: unable to submit Evidence for this Cohort.',
          success: 'Success: Evidence submitted, Portfolio updated, and Growth Report ready.',
        },
        uiCopy: [
          ...requiredScholesaTerminology,
          mission.title,
          mission.stage,
          ...mission.capabilityDomains,
          ...mission.expectedEvidence,
        ].join(' '),
      });
    }
  );
});
