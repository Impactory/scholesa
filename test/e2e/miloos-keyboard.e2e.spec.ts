import { expect, test, type Page } from '@playwright/test';

type E2EWindowApi = {
  signInAs: (uid: string, locale?: string) => Promise<{ uid: string | null }>;
  reset: (locale?: string) => Promise<void>;
  currentUid: () => string | null;
};

const LEARNER_ALPHA = 'learner-alpha';

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
  }, { uid: LEARNER_ALPHA, locale: 'en' });
  await page.waitForFunction(
    (expectedUid) =>
      (window as Window & {
        __scholesaE2E?: E2EWindowApi;
      }).__scholesaE2E?.currentUid() === expectedUid,
    LEARNER_ALPHA
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

async function activeTestId(page: Page): Promise<string | null> {
  return page.evaluate(() => {
    const activeElement = document.activeElement as HTMLElement | null;
    return activeElement?.closest<HTMLElement>('[data-testid]')?.dataset.testid ?? null;
  });
}

async function tabUntilTestId(page: Page, testId: string): Promise<void> {
  for (let index = 0; index < 80; index += 1) {
    if ((await activeTestId(page)) === testId) return;
    await page.keyboard.press('Tab');
  }
  expect(await activeTestId(page)).toBe(testId);
}

test.beforeEach(async ({ page }) => {
  await resetE2EState(page);
});

test('learner can complete the MiloOS support loop with keyboard focus preserved', async ({ page }) => {
  await signInAsLearner(page);
  await gotoProtectedRoute(page, '/en/learner/miloos');

  await expect(page.getByTestId('ai-coach-mode-hint')).toHaveAccessibleName(/Give me a hint/);
  await tabUntilTestId(page, 'ai-coach-mode-hint');
  await page.keyboard.press('Enter');

  await expect(page.getByTestId('ai-coach-question-input')).toBeVisible();
  await tabUntilTestId(page, 'ai-coach-question-input');
  expect(await activeTestId(page)).toBe('ai-coach-question-input');
  await page.keyboard.type('How can I test which prototype change is stronger?');

  await expect(page.getByTestId('ai-coach-submit-question')).toHaveAccessibleName('Ask MiloOS');
  await tabUntilTestId(page, 'ai-coach-submit-question');
  await page.keyboard.press('Enter');

  await expect(page.getByTestId('ai-coach-response-transcript')).toContainText(
    'Try one small comparison test'
  );
  await expect(page.getByTestId('ai-coach-explain-back-input')).toBeFocused();
  expect(await activeTestId(page)).toBe('ai-coach-explain-back-input');
  await page.keyboard.type(
    'I will change one prototype variable, compare the evidence, and explain why the result supports my decision.'
  );

  await expect(page.getByTestId('ai-coach-submit-explain-back')).toHaveAccessibleName(
    'Submit Explanation'
  );
  await tabUntilTestId(page, 'ai-coach-submit-explain-back');
  await page.keyboard.press('Enter');

  await expect(page.getByTestId('ai-coach-status-message')).toContainText(
    'Explain-back submitted'
  );
  await expect(page.getByTestId('ai-coach-status-message')).toBeFocused();
  await expect(page.getByTestId('learner-miloos-loop-status')).toContainText('Learning Loop Ready');
  await expect(page.getByTestId('learner-miloos-pending-checks')).toContainText('0');
});
