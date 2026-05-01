import { expect, test, type Locator, type Page } from '@playwright/test';
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

const MOBILE_VIEWPORT = { width: 390, height: 844 };
const LEARNER_ALPHA = WEB_MILOOS_SYNTHETIC_IDS.pendingExplainBackLearnerId;
const EDUCATOR_ALPHA = 'educator-alpha';
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

async function gotoProtectedRoute(page: Page, path: string): Promise<void> {
  await page.goto(path, { waitUntil: 'domcontentloaded' }).catch((error: unknown) => {
    if (!String(error).includes('net::ERR_ABORTED')) {
      throw error;
    }
  });
  await page.waitForURL((url) => url.pathname === path, { timeout: 10_000 });
}

async function expectNoHorizontalOverflow(page: Page): Promise<void> {
  await expect
    .poll(async () =>
      page.evaluate(() => {
        const scrollWidth = Math.max(
          document.documentElement.scrollWidth,
          document.body.scrollWidth
        );
        return scrollWidth - window.innerWidth;
      })
    )
    .toBeLessThanOrEqual(1);
}

async function expectWithinMobileWidth(locator: Locator): Promise<void> {
  await locator.scrollIntoViewIfNeeded();
  await expect(locator).toBeVisible();
  const box = await locator.boundingBox();
  expect(box).not.toBeNull();
  expect(box?.x ?? -1).toBeGreaterThanOrEqual(0);
  expect((box?.x ?? 0) + (box?.width ?? 0)).toBeLessThanOrEqual(MOBILE_VIEWPORT.width + 1);
}

async function seedSupportEvents(page: Page): Promise<void> {
  await page.evaluate((events) => {
    (window as Window & {
      __scholesaE2E: E2EWindowApi;
    }).__scholesaE2E.seedInteractionEvents(events);
  }, canonicalMiloOSGoldWebEvents());
}

test.describe('MiloOS mobile classroom proof', () => {
  test.use({
    viewport: MOBILE_VIEWPORT,
    isMobile: true,
    hasTouch: true,
  });

  test.beforeEach(async ({ page }) => {
    await resetE2EState(page);
  });

  test('learner MiloOS support loop stays usable on a phone viewport', async ({ page }) => {
    await signInAs(page, LEARNER_ALPHA);
    await gotoProtectedRoute(page, '/en/learner/miloos');

    await expectWithinMobileWidth(page.getByTestId('learner-miloos-loop-status'));
    await expectWithinMobileWidth(page.getByTestId('learner-miloos-support-opened'));
    await expectWithinMobileWidth(page.getByTestId('learner-miloos-support-used'));
    await expectWithinMobileWidth(page.getByTestId('learner-miloos-coach-responses'));
    await expectWithinMobileWidth(page.getByTestId('learner-miloos-explain-backs'));
    await expectWithinMobileWidth(page.getByTestId('learner-miloos-pending-checks'));

    await page.getByTestId('ai-coach-mode-hint').click();
    await expectWithinMobileWidth(page.getByTestId('ai-coach-question-input'));
    await page
      .getByTestId('ai-coach-question-input')
      .fill('How can I compare two prototype changes during class?');
    await expectWithinMobileWidth(page.getByTestId('ai-coach-submit-question'));
    await page.getByTestId('ai-coach-submit-question').click();

    await expect(page.getByTestId('ai-coach-response-transcript')).toContainText(
      'Try one small comparison test'
    );
    await expectWithinMobileWidth(page.getByTestId('ai-coach-response-transcript'));
    await expectWithinMobileWidth(page.getByTestId('ai-coach-explain-back-input'));
    await expectWithinMobileWidth(page.getByTestId('ai-coach-submit-explain-back'));
    await expect(page.getByTestId('learner-miloos-coach-responses')).toContainText('1');
    await expect(page.getByTestId('learner-miloos-pending-checks')).toContainText('1');
    await expectNoHorizontalOverflow(page);
  });

  test('educator MiloOS follow-up debt stays scannable on a phone viewport', async ({ page }) => {
    await signInAs(page, EDUCATOR_ALPHA);
    await seedSupportEvents(page);
    await gotoProtectedRoute(page, '/en/educator/learners');

    const alphaSupport = page.getByTestId(`miloos-support-${LEARNER_ALPHA}`);
    await expectWithinMobileWidth(alphaSupport);
    await expect(alphaSupport).toContainText('MiloOS support provenance');
    await expect(alphaSupport).toContainText('1 explain-back pending');
    await expect(alphaSupport).toContainText('Pending: 1');
    await expectNoHorizontalOverflow(page);
  });

  test('site MiloOS support health tiles stay readable on a phone viewport', async ({ page }) => {
    await signInAs(page, SITE_ADMIN);
    await seedSupportEvents(page);
    await gotoProtectedRoute(page, '/en/site/dashboard');

    const supportHealth = page.getByTestId('site-miloos-support-health');
    await expectWithinMobileWidth(supportHealth);
    await expect(supportHealth).toContainText('MiloOS support health');
    await expect(supportHealth).toContainText('2/2 learners used support');
    await expectWithinMobileWidth(supportHealth.getByTestId('site-miloos-support-opened'));
    await expectWithinMobileWidth(supportHealth.getByTestId('site-miloos-support-used'));
    await expectWithinMobileWidth(supportHealth.getByTestId('site-miloos-coach-responses'));
    await expectWithinMobileWidth(supportHealth.getByTestId('site-miloos-explain-backs'));
    await expectWithinMobileWidth(supportHealth.getByTestId('site-miloos-pending-checks'));
    await expectNoHorizontalOverflow(page);
  });
});
