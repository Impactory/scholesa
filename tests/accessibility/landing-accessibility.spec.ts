import AxeBuilder from '@axe-core/playwright';
import { expect, test, type Page } from '@playwright/test';

async function expectNoAccessibilityViolations(page: Page): Promise<void> {
  const results = await new AxeBuilder({ page })
    .withTags(['wcag2a', 'wcag2aa', 'wcag21aa', 'wcag22aa'])
    .disableRules(['color-contrast'])
    .analyze();

  expect(
    results.violations,
    results.violations
      .map((violation) => `${violation.id}: ${violation.help}`)
      .join('\n')
  ).toEqual([]);
}

test('@wcag public Summer Camp CTA flow meets automated accessibility baseline', async ({ page }) => {
  await page.emulateMedia({ colorScheme: 'light', reducedMotion: 'reduce' });
  await page.goto('/en');

  await expect(page.getByRole('link', { name: /Summer Camp|Camp/i })).toBeVisible();
  await expectNoAccessibilityViolations(page);

  await page.getByRole('link', { name: /Summer Camp|Camp/i }).click();
  await expect(page).toHaveURL(/\/en\/summer-camp-2026$/);
  await expect(page.getByRole('heading', { name: /Young Innovators/i })).toBeVisible();
  await expectNoAccessibilityViolations(page);
});
