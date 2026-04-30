import { expect, test, type Page } from '@playwright/test';

type E2EWindowApi = {
  signInAs: (uid: string, locale?: string) => Promise<{ uid: string | null }>;
  reset: (locale?: string) => Promise<void>;
  currentUid: () => string | null;
  seedInteractionEvents: (events: Array<Record<string, unknown>>) => void;
};

const SITE_ALPHA = 'site-alpha';
const SITE_BETA = 'site-beta';
const EDUCATOR_ALPHA = 'educator-alpha';
const LEARNER_ALPHA = 'learner-alpha';
const LEARNER_BETA = 'learner-beta';

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

async function signInAsEducator(page: Page): Promise<void> {
  await page.goto('/en/login');
  await waitForE2EHarness(page);
  await page.evaluate(async ({ uid, locale }) => {
    await (window as Window & {
      __scholesaE2E: E2EWindowApi;
    }).__scholesaE2E.signInAs(uid, locale);
  }, { uid: EDUCATOR_ALPHA, locale: 'en' });
  await page.waitForFunction(
    (expectedUid) =>
      (window as Window & {
        __scholesaE2E?: E2EWindowApi;
      }).__scholesaE2E?.currentUid() === expectedUid,
    EDUCATOR_ALPHA
  );
}

test.beforeEach(async ({ page }) => {
  await resetE2EState(page);
});

test('educator AI audit shows same-site MiloOS support provenance without mastery claims', async ({ page }) => {
  await signInAsEducator(page);
  await page.evaluate(({ siteAlpha, siteBeta, learnerAlpha, learnerBeta }) => {
    (window as Window & {
      __scholesaE2E: E2EWindowApi;
    }).__scholesaE2E.seedInteractionEvents([
      {
        id: 'educator-alpha-opened',
        siteId: siteAlpha,
        actorId: learnerAlpha,
        learnerId: learnerAlpha,
        eventType: 'ai_help_opened',
      },
      {
        id: 'educator-alpha-used',
        siteId: siteAlpha,
        actorId: learnerAlpha,
        learnerId: learnerAlpha,
        eventType: 'ai_help_used',
        interactionId: 'educator-alpha-opened',
      },
      {
        id: 'educator-beta-opened',
        siteId: siteAlpha,
        actorId: learnerBeta,
        learnerId: learnerBeta,
        eventType: 'ai_help_opened',
      },
      {
        id: 'educator-beta-used',
        siteId: siteAlpha,
        actorId: learnerBeta,
        learnerId: learnerBeta,
        eventType: 'ai_help_used',
        interactionId: 'educator-beta-opened',
      },
      {
        id: 'educator-beta-explain-back',
        siteId: siteAlpha,
        actorId: learnerBeta,
        learnerId: learnerBeta,
        eventType: 'explain_it_back_submitted',
        interactionId: 'educator-beta-opened',
      },
      {
        id: 'educator-other-site-opened',
        siteId: siteBeta,
        actorId: learnerAlpha,
        learnerId: learnerAlpha,
        eventType: 'ai_help_opened',
      },
    ]);
  }, {
    siteAlpha: SITE_ALPHA,
    siteBeta: SITE_BETA,
    learnerAlpha: LEARNER_ALPHA,
    learnerBeta: LEARNER_BETA,
  });

  await page.goto('/en/educator/learners');

  await expect(page.getByTestId('educator-ai-audit')).toBeVisible();
  await expect(page.getByTestId('ai-audit-tab')).toBeVisible();

  const alphaSupport = page.getByTestId(`miloos-support-${LEARNER_ALPHA}`);
  await expect(alphaSupport).toBeVisible();
  await expect(alphaSupport).toContainText('MiloOS support provenance');
  await expect(alphaSupport).toContainText('1 explain-back pending');
  await expect(alphaSupport).toContainText('Opened: 1');
  await expect(alphaSupport).toContainText('Used: 1');
  await expect(alphaSupport).toContainText('Explain-backs: 0');
  await expect(alphaSupport).toContainText('Pending: 1');
  await expect(alphaSupport).toContainText('support signals and verification gaps, not capability mastery');

  const betaSupport = page.getByTestId(`miloos-support-${LEARNER_BETA}`);
  await expect(betaSupport).toBeVisible();
  await expect(betaSupport).toContainText('Explain-back current');
  await expect(betaSupport).toContainText('Opened: 1');
  await expect(betaSupport).toContainText('Used: 1');
  await expect(betaSupport).toContainText('Explain-backs: 1');
  await expect(betaSupport).toContainText('Pending: 0');
});