import { expect, test, type Page } from '@playwright/test';
import {
  canonicalMiloOSGoldWebEvents,
  WEB_MILOOS_SYNTHETIC_IDS,
} from './miloos-synthetic-gold-fixture';

type E2EWindowApi = {
  signInAs: (uid: string, locale?: string) => Promise<{ uid: string | null }>;
  reset: (locale?: string) => Promise<void>;
  currentUid: () => string | null;
  seedInteractionEvents: (events: Array<Record<string, unknown>>) => void;
};

const PARENT_ALPHA = 'parent-alpha';
const LEARNER_ALPHA = WEB_MILOOS_SYNTHETIC_IDS.pendingExplainBackLearnerId;

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

async function signInAsParent(page: Page): Promise<void> {
  await page.goto('/en/login');
  await waitForE2EHarness(page);
  await page.evaluate(async ({ uid, locale }) => {
    await (window as Window & {
      __scholesaE2E: E2EWindowApi;
    }).__scholesaE2E.signInAs(uid, locale);
  }, { uid: PARENT_ALPHA, locale: 'en' });
  await page.waitForFunction(
    (expectedUid) =>
      (window as Window & {
        __scholesaE2E?: E2EWindowApi;
      }).__scholesaE2E?.currentUid() === expectedUid,
    PARENT_ALPHA
  );
}

test.beforeEach(async ({ page }) => {
  await resetE2EState(page);
});

test('guardian summary shows linked learner MiloOS support provenance without mastery claims', async ({ page }) => {
  await signInAsParent(page);
  await page.evaluate((events) => {
    (window as Window & {
      __scholesaE2E: E2EWindowApi;
    }).__scholesaE2E.seedInteractionEvents(events);
  }, canonicalMiloOSGoldWebEvents());

  await page.goto('/en/parent/summary');

  await expect(page.getByTestId(`learner-header-${LEARNER_ALPHA}`)).toContainText('Learner Alpha');
  const support = page.getByTestId(`guardian-miloos-support-${LEARNER_ALPHA}`);
  await expect(support).toBeVisible();
  await expect(support).toContainText('MiloOS support provenance');
  await expect(support).toContainText(
    'These are support signals and explain-back verification gaps, not capability mastery.'
  );
  await expect(support).toContainText('Explain-back needed');
  await expect(support.getByTestId('guardian-miloos-support-opened')).toContainText('1');
  await expect(support.getByTestId('guardian-miloos-support-used')).toContainText('1');
  await expect(support.getByTestId('guardian-miloos-explain-backs')).toContainText('0');
  await expect(support.getByTestId('guardian-miloos-pending-checks')).toContainText('1');
  await expect(support).not.toContainText('Support explained back');
});