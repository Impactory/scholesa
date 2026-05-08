import { expect, test, type Page } from '@playwright/test';

type E2EWindowApi = {
  signInAs: (uid: string, locale?: string) => Promise<{ uid: string | null }>;
  reset: (locale?: string) => Promise<void>;
  currentUid: () => string | null;
};

const hasExternalBaseURL = Boolean(process.env.PLAYWRIGHT_BASE_URL);

async function expectIconOnlyThemeSwitch(page: Page): Promise<void> {
  const themeGroup = page.getByRole('group', { name: 'Theme' }).first();
  await expect(themeGroup).toBeVisible();
  await expect(themeGroup).not.toContainText(/System|Light|Dark/);
  await expect(themeGroup.locator('svg[aria-hidden="true"]')).toHaveCount(3);

  for (const label of ['System', 'Light', 'Dark']) {
    const button = themeGroup.getByRole('button', { name: `Theme: ${label}` });
    await expect(button).toBeVisible();
    await expect(button).toHaveAttribute('title', label);
    await expect(button).toHaveText('');
  }
}

async function signInAsLearner(page: Page): Promise<void> {
  await page.goto('/en/login');
  await page.waitForFunction(() => Boolean((window as Window & {
    __scholesaE2E?: E2EWindowApi;
  }).__scholesaE2E));
  await page.evaluate(async () => {
    await (window as Window & {
      __scholesaE2E: E2EWindowApi;
    }).__scholesaE2E.reset('en');
    await (window as Window & {
      __scholesaE2E: E2EWindowApi;
    }).__scholesaE2E.signInAs('learner-alpha', 'en');
  });
  await page.waitForFunction(() => (
    window as Window & { __scholesaE2E?: E2EWindowApi }
  ).__scholesaE2E?.currentUid() === 'learner-alpha');
}

test.beforeEach(async ({ page }) => {
  await page.emulateMedia({ colorScheme: 'light', reducedMotion: 'reduce' });
  await page.addInitScript(() => {
    window.localStorage.setItem('scholesa.theme.preference', 'system');
  });
});

test('public entrypoints render the theme switch as accessible icon-only buttons', async ({ page }) => {
  for (const path of ['/en', '/en/login', '/en/register']) {
    await page.goto(path);
    await expectIconOnlyThemeSwitch(page);
  }
});

test('protected navigation renders the theme switch as accessible icon-only buttons', async ({ page }) => {
  test.skip(
    hasExternalBaseURL,
    'Protected icon-only proof uses the local E2E auth harness; rehearsal auth is covered by the operator role sweep.'
  );

  await signInAsLearner(page);
  await page.goto('/en/learner/today');
  await expect(page.getByRole('link', { name: 'Scholesa dashboard' })).toBeVisible();
  await expectIconOnlyThemeSwitch(page);
});
