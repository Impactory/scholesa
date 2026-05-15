import { expect, test } from '@playwright/test';
import { uatMissionDefinitions } from '../fixtures/uat-missions';

test('UAT mission fixtures preserve stage, capability, AI policy, and evidence context', async ({ page }) => {
  await page.goto('/en');
  await expect(page.getByRole('link', { name: /Summer Camp|Camp/i })).toBeVisible();

  expect(uatMissionDefinitions.map((mission) => mission.title)).toEqual([
    'My Helpful Invention Studio',
    'Eco-Smart City Lab',
    'AI Media Detective Lab',
    'Venture Sprint',
  ]);
  expect(uatMissionDefinitions.every((mission) => mission.capabilityDomains.length >= 2)).toBe(true);
  expect(uatMissionDefinitions.every((mission) => mission.expectedEvidence.length >= 4)).toBe(true);
});
