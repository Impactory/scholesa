import AxeBuilder from '@axe-core/playwright';
import { expect, test, type Page } from '@playwright/test';

type E2EWindowApi = {
  signInAs: (uid: string, locale?: string) => Promise<{ uid: string | null }>;
  reset: (locale?: string) => Promise<void>;
  currentUid: () => string | null;
  seedInteractionEvents: (events: Array<Record<string, unknown>>) => void;
};

const SITE_ALPHA = 'site-alpha';
const SITE_BETA = 'site-beta';
const LEARNER_ALPHA = 'learner-alpha';
const LEARNER_BETA = 'learner-beta';

async function expectNoWcagViolations(page: Page, selector: string): Promise<void> {
  const results = await new AxeBuilder({ page })
    .include(selector)
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
      .join('\n')
  ).toEqual([]);
}

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
  await page.evaluate(async ({ userId, locale }) => {
    await (window as Window & {
      __scholesaE2E: E2EWindowApi;
    }).__scholesaE2E.signInAs(userId, locale);
  }, { userId: uid, locale: 'en' });
  await page.waitForFunction(
    (expectedUid) =>
      (window as Window & {
        __scholesaE2E?: E2EWindowApi;
      }).__scholesaE2E?.currentUid() === expectedUid,
    uid
  );
}

async function seedMiloOSSupportEvents(page: Page): Promise<void> {
  await page.evaluate(({ siteAlpha, siteBeta, learnerAlpha, learnerBeta }) => {
    (window as Window & {
      __scholesaE2E: E2EWindowApi;
    }).__scholesaE2E.seedInteractionEvents([
      {
        id: 'a11y-alpha-opened',
        siteId: siteAlpha,
        actorId: learnerAlpha,
        learnerId: learnerAlpha,
        eventType: 'ai_help_opened',
      },
      {
        id: 'a11y-alpha-used',
        siteId: siteAlpha,
        actorId: learnerAlpha,
        learnerId: learnerAlpha,
        eventType: 'ai_help_used',
        interactionId: 'a11y-alpha-opened',
      },
      {
        id: 'a11y-beta-opened',
        siteId: siteAlpha,
        actorId: learnerBeta,
        learnerId: learnerBeta,
        eventType: 'ai_help_opened',
      },
      {
        id: 'a11y-beta-used',
        siteId: siteAlpha,
        actorId: learnerBeta,
        learnerId: learnerBeta,
        eventType: 'ai_help_used',
        interactionId: 'a11y-beta-opened',
      },
      {
        id: 'a11y-beta-explain-back',
        siteId: siteAlpha,
        actorId: learnerBeta,
        learnerId: learnerBeta,
        eventType: 'explain_it_back_submitted',
        interactionId: 'a11y-beta-opened',
      },
      {
        id: 'a11y-other-site-opened',
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
}

test.beforeEach(async ({ page }) => {
  await page.emulateMedia({ colorScheme: 'light', reducedMotion: 'reduce' });
  await page.addInitScript(() => {
    window.localStorage.setItem('scholesa.theme.preference', 'light');
    document.documentElement.dataset.theme = 'light';
    document.documentElement.style.colorScheme = 'light';
  });
  await resetE2EState(page);
});

test('@wcag learner MiloOS support status satisfies WCAG 2.2 AA automation baseline', async ({ page }) => {
  await signInAs(page, LEARNER_ALPHA);
  await page.goto('/en/learner/miloos');
  await expect(page.getByTestId('learner-miloos-loop-status')).toBeVisible();
  await expectNoWcagViolations(page, '[data-testid="learner-miloos-loop-status"]');
});

test('@wcag educator MiloOS support provenance satisfies WCAG 2.2 AA automation baseline', async ({ page }) => {
  await signInAs(page, 'educator-alpha');
  await seedMiloOSSupportEvents(page);
  await page.goto('/en/educator/learners');
  await expect(page.getByTestId(`miloos-support-${LEARNER_ALPHA}`)).toBeVisible();
  await expectNoWcagViolations(page, `[data-testid="miloos-support-${LEARNER_ALPHA}"]`);
});

test('@wcag guardian MiloOS support provenance satisfies WCAG 2.2 AA automation baseline', async ({ page }) => {
  await signInAs(page, 'parent-alpha');
  await seedMiloOSSupportEvents(page);
  await page.goto('/en/parent/summary');
  await expect(page.getByTestId(`guardian-miloos-support-${LEARNER_ALPHA}`)).toBeVisible();
  await expectNoWcagViolations(page, `[data-testid="guardian-miloos-support-${LEARNER_ALPHA}"]`);
});

test('@wcag site MiloOS support health satisfies WCAG 2.2 AA automation baseline', async ({ page }) => {
  await signInAs(page, 'site-alpha-admin');
  await seedMiloOSSupportEvents(page);
  await page.goto('/en/site/dashboard');
  await expect(page.getByTestId('site-miloos-support-health')).toBeVisible();
  await expectNoWcagViolations(page, '[data-testid="site-miloos-support-health"]');
});