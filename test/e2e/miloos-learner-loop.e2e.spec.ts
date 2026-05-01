import { test, expect, type Page } from '@playwright/test';

type CollectionRecord = Record<string, unknown>;

type E2EWindowApi = {
  signInAs: (uid: string, locale?: string) => Promise<{ uid: string | null }>;
  reset: (locale?: string) => Promise<void>;
  currentUid: () => string | null;
  getCollection: (collectionName: string) => CollectionRecord[];
};

const LEARNER_UID = 'learner-alpha';

async function waitForE2EHarness(page: Page): Promise<void> {
  await page.waitForFunction(() => Boolean((window as Window & {
    __scholesaE2E?: E2EWindowApi;
  }).__scholesaE2E));
}

async function resetE2EState(page: Page): Promise<void> {
  await page.goto('/en/login');
  await waitForE2EHarness(page);
  await page.evaluate(async () => {
    await (window as Window & {
      __scholesaE2E: E2EWindowApi;
    }).__scholesaE2E.reset('en');
  });
}

async function signInAsLearner(page: Page): Promise<void> {
  await page.goto('/en/login');
  await waitForE2EHarness(page);
  await page.evaluate(async ({ uid, locale }) => {
    await (window as Window & {
      __scholesaE2E: E2EWindowApi;
    }).__scholesaE2E.signInAs(uid, locale);
  }, { uid: LEARNER_UID, locale: 'en' });
  await page.waitForFunction(
    (expectedUid) =>
      (window as Window & {
        __scholesaE2E?: E2EWindowApi;
      }).__scholesaE2E?.currentUid() === expectedUid,
    LEARNER_UID
  );
}

async function getCollection(page: Page, collectionName: string): Promise<CollectionRecord[]> {
  return page.evaluate((name) => {
    return (window as Window & {
      __scholesaE2E: E2EWindowApi;
    }).__scholesaE2E.getCollection(name);
  }, collectionName);
}

test.beforeEach(async ({ page }) => {
  await resetE2EState(page);
});

test('learner MiloOS route records support provenance and explain-back without mastery claims', async ({
  page,
}) => {
  await signInAsLearner(page);
  await page.goto('/en/learner/miloos');

  await expect(page).toHaveURL(/\/en\/learner\/miloos$/);
  await expect(page.getByRole('heading', { name: 'MiloOS Coach' })).toBeVisible();
  await expect(page.getByTestId('learner-miloos-loop-status')).toContainText('Learning Loop Ready');
  await expect(page.getByTestId('learner-miloos-support-opened')).toContainText('0');
  await expect(page.getByTestId('learner-miloos-support-used')).toContainText('0');
  await expect(page.getByTestId('learner-miloos-explain-backs')).toContainText('0');
  await expect(page.getByTestId('learner-miloos-pending-checks')).toContainText('0');
  await expect(page.getByText('support provenance, not capability mastery')).toBeVisible();

  await page.getByTestId('ai-coach-mode-hint').click();
  await page
    .getByTestId('ai-coach-question-input')
    .fill('How should I compare two prototype changes before choosing one?');
  await page.getByTestId('ai-coach-submit-question').click();

  await expect(page.getByTestId('ai-coach-response-transcript')).toContainText(
    'Try one small comparison test'
  );
  await expect(page.getByText('Now explain it back!')).toBeVisible();
  await expect(page.getByTestId('learner-miloos-loop-status')).toContainText('Explain-Back Needed');
  await expect(page.getByTestId('learner-miloos-support-opened')).toContainText('1');
  await expect(page.getByTestId('learner-miloos-support-used')).toContainText('1');
  await expect(page.getByTestId('learner-miloos-pending-checks')).toContainText('1');

  await page.getByTestId('ai-coach-explain-back-input').fill(
    'I learned to change one prototype variable, compare the evidence, and explain why the result supports my decision.'
  );
  await page.getByTestId('ai-coach-submit-explain-back').click();

  await expect(
    page.getByText('Explain-back submitted. Your reflection is now attached to this MiloOS session.')
  ).toBeVisible();
  await expect(page.getByTestId('learner-miloos-loop-status')).toContainText('Learning Loop Ready');
  await expect(page.getByTestId('learner-miloos-explain-backs')).toContainText('1');
  await expect(page.getByTestId('learner-miloos-pending-checks')).toContainText('0');

  await expect.poll(async () => {
    const eventTypes = (await getCollection(page, 'interactionEvents'))
      .filter((entry) => entry.actorId === LEARNER_UID)
      .map((entry) => entry.eventType);
    return [
      'ai_help_opened',
      'ai_help_used',
      'ai_coach_response',
      'explain_it_back_submitted',
    ].every((eventType) => eventTypes.includes(eventType));
  }, {
    timeout: 10_000,
  }).toBe(true);

  const masteryRecords = await getCollection(page, 'capabilityMastery');
  const growthRecords = await getCollection(page, 'capabilityGrowthEvents');
  expect(masteryRecords).toEqual([]);
  expect(growthRecords).toEqual([]);
  await expect(page.getByText(/mastery level|capability score/i)).toHaveCount(0);
});
