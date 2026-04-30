import { expect, test, type Page } from '@playwright/test';

type E2EWindowApi = {
  signInAs: (uid: string, locale?: string) => Promise<{ uid: string | null }>;
  reset: (locale?: string) => Promise<void>;
  currentUid: () => string | null;
  seedInteractionEvents: (events: Array<Record<string, unknown>>) => void;
};

const SITE_ALPHA = 'site-alpha';
const SITE_BETA = 'site-beta';
const SITE_ADMIN = 'site-alpha-admin';
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

async function signInAsSiteAdmin(page: Page): Promise<void> {
  await page.goto('/en/login');
  await waitForE2EHarness(page);
  await page.evaluate(async ({ uid, locale }) => {
    await (window as Window & {
      __scholesaE2E: E2EWindowApi;
    }).__scholesaE2E.signInAs(uid, locale);
  }, { uid: SITE_ADMIN, locale: 'en' });
  await page.waitForFunction(
    (expectedUid) =>
      (window as Window & {
        __scholesaE2E?: E2EWindowApi;
      }).__scholesaE2E?.currentUid() === expectedUid,
    SITE_ADMIN
  );
}

test.beforeEach(async ({ page }) => {
  await resetE2EState(page);
});

test('site dashboard shows MiloOS support health without treating support as mastery', async ({ page }) => {
  await signInAsSiteAdmin(page);
  await page.evaluate(({ siteAlpha, siteBeta, learnerAlpha, learnerBeta }) => {
    (window as Window & {
      __scholesaE2E: E2EWindowApi;
    }).__scholesaE2E.seedInteractionEvents([
      {
        id: 'e2e-alpha-opened',
        siteId: siteAlpha,
        actorId: learnerAlpha,
        learnerId: learnerAlpha,
        eventType: 'ai_help_opened',
      },
      {
        id: 'e2e-alpha-used',
        siteId: siteAlpha,
        actorId: learnerAlpha,
        learnerId: learnerAlpha,
        eventType: 'ai_help_used',
        interactionId: 'e2e-alpha-opened',
      },
      {
        id: 'e2e-beta-opened',
        siteId: siteAlpha,
        actorId: learnerBeta,
        learnerId: learnerBeta,
        eventType: 'ai_help_opened',
      },
      {
        id: 'e2e-beta-used',
        siteId: siteAlpha,
        actorId: learnerBeta,
        learnerId: learnerBeta,
        eventType: 'ai_help_used',
        interactionId: 'e2e-beta-opened',
      },
      {
        id: 'e2e-beta-explain-back',
        siteId: siteAlpha,
        actorId: learnerBeta,
        learnerId: learnerBeta,
        eventType: 'explain_it_back_submitted',
        interactionId: 'e2e-beta-opened',
      },
      {
        id: 'e2e-other-site-opened',
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

  await page.goto('/en/site/dashboard');

  const supportHealth = page.getByTestId('site-miloos-support-health');
  await expect(supportHealth).toBeVisible();
  await expect(supportHealth).toContainText('MiloOS support health');
  await expect(supportHealth).toContainText(
    'These are support and explain-back verification signals, not capability mastery.'
  );
  await expect(supportHealth).toContainText('2/2 learners used support');
  await expect(supportHealth.getByTestId('site-miloos-support-opened')).toContainText('2');
  await expect(supportHealth.getByTestId('site-miloos-support-used')).toContainText('2');
  await expect(supportHealth.getByTestId('site-miloos-explain-backs')).toContainText('1');
  await expect(supportHealth.getByTestId('site-miloos-pending-checks')).toContainText('1');
  await expect(supportHealth).toContainText('1 learner');
  await expect(supportHealth).toContainText('MiloOS explain-back follow-up');
});