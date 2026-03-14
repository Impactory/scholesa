import AxeBuilder from '@axe-core/playwright';
import { expect, test, type Page } from '@playwright/test';

async function expectNoWcagViolations(page: Page): Promise<void> {
  const results = await new AxeBuilder({ page })
    .withTags(['wcag2a', 'wcag2aa', 'wcag21aa', 'wcag22aa'])
    .analyze();

  expect(
    results.violations,
    results.violations
      .map((violation) => {
        const targets = violation.nodes
          .flatMap((node) => node.target)
          .join(', ');
        return `${violation.id}: ${violation.help} (${targets})`;
      })
      .join('\n'),
  ).toEqual([]);
}

test.beforeEach(async ({ page }) => {
  await page.emulateMedia({ colorScheme: 'light', reducedMotion: 'reduce' });
  await page.addInitScript(() => {
    window.localStorage.setItem('scholesa.theme.preference', 'light');
    document.documentElement.dataset.theme = 'light';
    document.documentElement.style.colorScheme = 'light';
  });
});

test('@wcag landing page satisfies WCAG 2.2 AA automation baseline', async ({ page }) => {
  await page.goto('/en');
  await expect.poll(() => page.evaluate(() => document.documentElement.dataset.theme)).toBe('light');
  await expect(page.locator('a[href="/en/login"]').first()).toBeVisible();
  await expectNoWcagViolations(page);
});

test('@wcag login routes satisfy localized WCAG 2.2 AA automation baseline', async ({ page }) => {
  await page.goto('/en/login');
  await expect.poll(() => page.evaluate(() => document.documentElement.dataset.theme)).toBe('light');
  await expect(page.getByRole('heading', { name: 'Welcome back' })).toBeVisible();
  await expectNoWcagViolations(page);

  await page.goto('/zh-CN/login');
  await expect(page.getByRole('heading', { name: '欢迎回来' })).toBeVisible();
  await expectNoWcagViolations(page);

  await page.goto('/zh-TW/hq/sites');
  await expect(page).toHaveURL(/\/zh-TW\/login\?from=%2Fzh-TW%2Fhq%2Fsites$/);
  await expect(page.getByRole('heading', { name: '歡迎回來' })).toBeVisible();
  await expectNoWcagViolations(page);
});