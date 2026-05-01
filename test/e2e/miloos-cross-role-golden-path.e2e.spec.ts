import { expect, test, type Page } from '@playwright/test';

type CollectionRecord = Record<string, unknown>;

type E2EWindowApi = {
  signInAs: (uid: string, locale?: string) => Promise<{ uid: string | null }>;
  reset: (locale?: string) => Promise<void>;
  currentUid: () => string | null;
  getCollection: (collectionName: string) => CollectionRecord[];
};

const LEARNER_ALPHA = 'learner-alpha';
const EDUCATOR_ALPHA = 'educator-alpha';
const PARENT_ALPHA = 'parent-alpha';
const SITE_ADMIN = 'site-alpha-admin';

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

async function signInAs(page: Page, uid: string): Promise<void> {
  await page.goto('/en/login');
  await waitForE2EHarness(page);
  await switchUserWithoutNavigation(page, uid);
  await page.waitForLoadState('domcontentloaded');
  await page.waitForURL((url) => !url.pathname.endsWith('/login'), { timeout: 5_000 }).catch(() => undefined);
}

async function switchUserWithoutNavigation(page: Page, uid: string): Promise<void> {
  await waitForE2EHarness(page);
  await page.evaluate(async ({ nextUid, locale }) => {
    await (window as Window & {
      __scholesaE2E: E2EWindowApi;
    }).__scholesaE2E.signInAs(nextUid, locale);
  }, { nextUid: uid, locale: 'en' });
  await page.waitForFunction(
    (expectedUid) =>
      (window as Window & {
        __scholesaE2E?: E2EWindowApi;
      }).__scholesaE2E?.currentUid() === expectedUid,
    uid
  );
}

async function getCollection(page: Page, collectionName: string): Promise<CollectionRecord[]> {
  return page.evaluate((name) => {
    return (window as Window & {
      __scholesaE2E: E2EWindowApi;
    }).__scholesaE2E.getCollection(name);
  }, collectionName);
}

async function gotoProtectedRoute(page: Page, path: string): Promise<void> {
  await page.goto(path, { waitUntil: 'domcontentloaded' }).catch((error: unknown) => {
    if (!String(error).includes('net::ERR_ABORTED')) {
      throw error;
    }
  });
  await page.waitForURL((url) => url.pathname === path, { timeout: 10_000 });
}

test.beforeEach(async ({ page }) => {
  await resetE2EState(page);
});

test('MiloOS support journey flows across learner, educator, guardian, and site without mastery writes', async ({
  page,
}) => {
  await signInAs(page, LEARNER_ALPHA);
  await gotoProtectedRoute(page, '/en/learner/miloos');

  await expect(page.getByTestId('learner-miloos-loop-status')).toContainText('Learning Loop Ready');
  await page.getByTestId('ai-coach-mode-hint').click();
  await page
    .getByTestId('ai-coach-question-input')
    .fill('How can I test which prototype change is stronger?');
  await page.getByTestId('ai-coach-submit-question').click();

  await expect(page.getByTestId('ai-coach-response-transcript')).toContainText(
    'Try one small comparison test'
  );
  await expect(page.getByTestId('learner-miloos-loop-status')).toContainText('Explain-Back Needed');
  await expect(page.getByTestId('learner-miloos-pending-checks')).toContainText('1');

  await signInAs(page, EDUCATOR_ALPHA);
  await gotoProtectedRoute(page, '/en/educator/learners');

  const educatorSupport = page.getByTestId(`miloos-support-${LEARNER_ALPHA}`);
  await expect(educatorSupport).toBeVisible();
  await expect(educatorSupport).toContainText('MiloOS support provenance');
  await expect(educatorSupport).toContainText('1 explain-back pending');
  await expect(educatorSupport).toContainText('support signals and verification gaps, not capability mastery');

  await signInAs(page, LEARNER_ALPHA);
  await gotoProtectedRoute(page, '/en/learner/miloos');
  await expect(page.getByTestId('learner-miloos-pending-explain-back')).toBeVisible();
  await page.getByTestId('learner-miloos-pending-explain-back-input').fill(
    'I will change one prototype variable, compare the evidence, and explain why the result supports my decision.'
  );
  await page.getByTestId('learner-miloos-submit-pending-explain-back').click();

  await expect(page.getByTestId('learner-miloos-loop-status')).toContainText('Learning Loop Ready');
  await expect(page.getByTestId('learner-miloos-pending-checks')).toContainText('0');

  await signInAs(page, PARENT_ALPHA);
  await gotoProtectedRoute(page, '/en/parent/summary');

  const guardianSupport = page.getByTestId(`guardian-miloos-support-${LEARNER_ALPHA}`);
  await expect(guardianSupport).toBeVisible();
  await expect(guardianSupport).toContainText('MiloOS support provenance');
  await expect(guardianSupport).toContainText('Support explained back');
  await expect(guardianSupport.getByTestId('guardian-miloos-support-opened')).toContainText('1');
  await expect(guardianSupport.getByTestId('guardian-miloos-support-used')).toContainText('1');
  await expect(guardianSupport.getByTestId('guardian-miloos-explain-backs')).toContainText('1');
  await expect(guardianSupport.getByTestId('guardian-miloos-pending-checks')).toContainText('0');
  await expect(guardianSupport).toContainText(
    'These are support signals and explain-back verification gaps, not capability mastery.'
  );

  await signInAs(page, SITE_ADMIN);
  await gotoProtectedRoute(page, '/en/site/dashboard');

  const supportHealth = page.getByTestId('site-miloos-support-health');
  await expect(supportHealth).toBeVisible();
  await expect(supportHealth).toContainText('MiloOS support health');
  await expect(supportHealth).toContainText('1/2 learners used support');
  await expect(supportHealth.getByTestId('site-miloos-support-opened')).toContainText('1');
  await expect(supportHealth.getByTestId('site-miloos-support-used')).toContainText('1');
  await expect(supportHealth.getByTestId('site-miloos-explain-backs')).toContainText('1');
  await expect(supportHealth.getByTestId('site-miloos-pending-checks')).toContainText('0');
  await expect(supportHealth).toContainText(
    'These are support and explain-back verification signals, not capability mastery.'
  );

  const interactionEvents = await getCollection(page, 'interactionEvents');
  const learnerEventTypes = interactionEvents
    .filter((entry) => entry.actorId === LEARNER_ALPHA)
    .map((entry) => entry.eventType);
  expect(learnerEventTypes).toEqual(expect.arrayContaining([
    'ai_help_opened',
    'ai_help_used',
    'ai_coach_response',
    'explain_it_back_submitted',
  ]));

  expect(await getCollection(page, 'capabilityMastery')).toEqual([]);
});
