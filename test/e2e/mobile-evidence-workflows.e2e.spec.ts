import { test, expect, type Locator, type Page } from '@playwright/test';

type Role = 'learner' | 'educator';

type SeedUser = {
  uid: string;
  role: Role;
};

type E2EWindowApi = {
  signInAs: (uid: string, locale?: string) => Promise<{ uid: string | null }>;
  reset: (locale?: string) => Promise<void>;
  currentUid: () => string | null;
};

const MOBILE_VIEWPORT = { width: 390, height: 844 };

const USERS: Record<Role, SeedUser> = {
  learner: { uid: 'learner-alpha', role: 'learner' },
  educator: { uid: 'educator-alpha', role: 'educator' },
};

async function waitForE2EHarness(page: Page): Promise<void> {
  await page.goto('/en/login');
  await page.waitForFunction(() =>
    Boolean(
      (window as Window & {
        __scholesaE2E?: E2EWindowApi;
      }).__scholesaE2E
    )
  );
}

async function resetE2EState(page: Page): Promise<void> {
  await waitForE2EHarness(page);
  await page.evaluate(async () => {
    await (window as Window & {
      __scholesaE2E: E2EWindowApi;
    }).__scholesaE2E.reset('en');
  });
}

async function signInAs(page: Page, user: SeedUser): Promise<void> {
  await waitForE2EHarness(page);
  await page.evaluate(
    async ({ uid, locale }) => {
      await (window as Window & {
        __scholesaE2E: E2EWindowApi;
      }).__scholesaE2E.signInAs(uid, locale);
    },
    { uid: user.uid, locale: 'en' }
  );
  await page.waitForFunction(
    (expectedUid) =>
      (window as Window & {
        __scholesaE2E?: E2EWindowApi;
      }).__scholesaE2E?.currentUid() === expectedUid,
    user.uid
  );
}

async function expectNoHorizontalOverflow(page: Page): Promise<void> {
  await expect
    .poll(async () => {
      return page.evaluate(() => {
        const scrollWidth = Math.max(
          document.documentElement.scrollWidth,
          document.body.scrollWidth
        );
        return scrollWidth - window.innerWidth;
      });
    })
    .toBeLessThanOrEqual(1);
}

async function expectWithinViewport(locator: Locator): Promise<void> {
  await expect(locator).toBeVisible();
  const box = await locator.boundingBox();
  expect(box).not.toBeNull();
  expect(box?.x ?? -1).toBeGreaterThanOrEqual(0);
  expect((box?.x ?? 0) + (box?.width ?? 0)).toBeLessThanOrEqual(MOBILE_VIEWPORT.width + 1);
}

async function expectStackedBelow(first: Locator, second: Locator): Promise<void> {
  await expect(first).toBeVisible();
  await expect(second).toBeVisible();
  const firstBox = await first.boundingBox();
  const secondBox = await second.boundingBox();
  expect(firstBox).not.toBeNull();
  expect(secondBox).not.toBeNull();
  expect(secondBox?.y ?? 0).toBeGreaterThan((firstBox?.y ?? 0) + (firstBox?.height ?? 0) - 1);
}

test.describe('mobile evidence workflows', () => {
  test.use({
    viewport: MOBILE_VIEWPORT,
    isMobile: true,
    hasTouch: true,
  });

  test.beforeEach(async ({ page }) => {
    page.on('dialog', (dialog) => dialog.dismiss());
    await resetE2EState(page);
  });

  test('educator live evidence capture remains usable on a phone viewport', async ({ page }) => {
    await signInAs(page, USERS.educator);

    await page.goto('/en/educator/evidence');
    await expect(page).toHaveURL(/\/en\/educator\/evidence$/);
    await expect(page.getByTestId('evidence-capture-page')).toBeVisible();
    await expect(page.getByRole('heading', { name: 'Live Evidence Capture' })).toBeVisible();

    await expectWithinViewport(page.getByTestId('evidence-form'));
    await expectWithinViewport(page.getByTestId('evidence-learner'));
    await expectWithinViewport(page.getByTestId('evidence-phase'));
    await expectWithinViewport(page.getByTestId('evidence-description'));
    await expectWithinViewport(page.getByTestId('evidence-submit'));
    await expectStackedBelow(page.getByTestId('evidence-learner'), page.getByTestId('evidence-phase'));
    await expectNoHorizontalOverflow(page);
  });

  test('learner evidence submission keeps all submission modes reachable on a phone viewport', async ({ page }) => {
    await signInAs(page, USERS.learner);

    await page.goto('/en/learner/missions');
    await expect(page).toHaveURL(/\/en\/learner\/missions$/);
    await expect(page.getByTestId('learner-evidence-page')).toBeVisible();
    await expect(page.getByRole('heading', { name: 'My Portfolio & Evidence' })).toBeVisible();

    const submitArtifact = page.getByRole('button', { name: 'Submit Artifact' });
    const writeReflection = page.getByRole('button', { name: 'Write Reflection' });
    const checkpointEvidence = page.getByRole('button', { name: 'Checkpoint Evidence' });

    await expectWithinViewport(page.getByTestId('submission-tabs'));
    await expectStackedBelow(submitArtifact, writeReflection);
    await expectStackedBelow(writeReflection, checkpointEvidence);

    await expectWithinViewport(page.getByTestId('artifact-form'));
    await expectWithinViewport(page.getByTestId('artifact-title'));
    await expectWithinViewport(page.getByTestId('artifact-description'));
    await expectWithinViewport(page.getByTestId('artifact-submit'));
    await expectNoHorizontalOverflow(page);

    await writeReflection.click();
    await expectWithinViewport(page.getByTestId('reflection-form'));
    await expectWithinViewport(page.getByTestId('reflection-content'));
    await expectWithinViewport(page.getByTestId('reflection-submit'));
    await expectNoHorizontalOverflow(page);

    await checkpointEvidence.click();
    await expectWithinViewport(page.getByTestId('checkpoint-form'));
    await expectWithinViewport(page.getByTestId('checkpoint-mission-select'));
    await expectWithinViewport(page.getByTestId('checkpoint-content'));
    await expectWithinViewport(page.getByTestId('checkpoint-submit'));
    await expectNoHorizontalOverflow(page);
  });
});
