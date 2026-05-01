import { expect, test, type Page } from '@playwright/test';
import { canonicalMiloOSGoldWebEvents } from './miloos-synthetic-gold-fixture';

type E2EWindowApi = {
  signInAs: (uid: string, locale?: string) => Promise<{ uid: string | null }>;
  reset: (locale?: string) => Promise<void>;
  currentUid: () => string | null;
  seedInteractionEvents: (events: Array<Record<string, unknown>>) => void;
};

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
  await page.evaluate((events) => {
    (window as Window & {
      __scholesaE2E: E2EWindowApi;
    }).__scholesaE2E.seedInteractionEvents(events);
  }, canonicalMiloOSGoldWebEvents());

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
  await expect(supportHealth.getByTestId('site-miloos-coach-responses')).toContainText('2');
  await expect(supportHealth.getByTestId('site-miloos-explain-backs')).toContainText('1');
  await expect(supportHealth.getByTestId('site-miloos-pending-checks')).toContainText('1');
  await expect(supportHealth).toContainText('1 learner');
  await expect(supportHealth).toContainText('MiloOS explain-back follow-up');
});