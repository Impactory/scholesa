import { expect, test } from '@playwright/test';
import { getUatMissionByStage, uatMissionDefinitions } from '../fixtures/uat-missions';
import {
  createUatApiClient,
  createUatTestHarness,
  requiredScholesaTerminology,
  verifyUatAcceptanceCriteria,
} from '../helpers';

test('UAT mission smoke verifies UI plus backend/API permission chain', async ({ page }) => {
  await page.goto('/en');
  await expect(page.getByRole('link', { name: /Summer Camp|Camp/i }).first()).toBeVisible();

  expect(uatMissionDefinitions.map((mission) => mission.title)).toEqual([
    'My Helpful Invention Studio',
    'Eco-Smart City Lab',
    'AI Media Detective Lab',
    'Venture Sprint',
  ]);
  expect(uatMissionDefinitions.every((mission) => mission.capabilityDomains.length >= 2)).toBe(true);
  expect(uatMissionDefinitions.every((mission) => mission.expectedEvidence.length >= 4)).toBe(true);

  const harness = createUatTestHarness();
  const api = createUatApiClient(harness);
  const mission = getUatMissionByStage('Builders');

  await verifyUatAcceptanceCriteria({
    harness,
    api,
    mission,
    action: 'submitEvidence',
    correctRole: 'builder',
    incorrectRole: 'family',
    learnerRole: 'builder',
    uiStates: {
      loading: 'Loading Mission Evidence...',
      empty: 'No Evidence has been submitted yet.',
      error: 'Access denied: unable to submit Evidence.',
      success: 'Success: Evidence submitted and Portfolio updated.',
    },
    uiCopy: requiredScholesaTerminology.join(' '),
  });
});
