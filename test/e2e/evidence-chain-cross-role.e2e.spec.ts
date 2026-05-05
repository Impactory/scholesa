import { expect, test, type Page } from '@playwright/test';
import {
  PLATFORM_EVIDENCE_CHAIN_GOLD_IDS,
  canonicalPlatformEvidenceChainGoldRecords,
} from './platform-evidence-chain-gold-fixture';

type CollectionRecord = Record<string, unknown>;

type E2EWindowApi = {
  signInAs: (uid: string, locale?: string) => Promise<{ uid: string | null }>;
  reset: (locale?: string) => Promise<void>;
  currentUid: () => string | null;
  getCollection: (collectionName: string) => CollectionRecord[];
  seedEvidenceChain: (records: Record<string, CollectionRecord[]>) => void;
};

const LEARNER_ALPHA = PLATFORM_EVIDENCE_CHAIN_GOLD_IDS.learnerId;
const EDUCATOR_ALPHA = PLATFORM_EVIDENCE_CHAIN_GOLD_IDS.educatorId;
const PARENT_ALPHA = PLATFORM_EVIDENCE_CHAIN_GOLD_IDS.parentId;
const SITE_ADMIN = PLATFORM_EVIDENCE_CHAIN_GOLD_IDS.siteAdminId;
const CAPABILITY_ID = PLATFORM_EVIDENCE_CHAIN_GOLD_IDS.capabilityId;
const EVIDENCE_ID = PLATFORM_EVIDENCE_CHAIN_GOLD_IDS.evidenceId;
const PORTFOLIO_ITEM_ID = PLATFORM_EVIDENCE_CHAIN_GOLD_IDS.portfolioItemId;
const RUBRIC_APPLICATION_ID = PLATFORM_EVIDENCE_CHAIN_GOLD_IDS.rubricApplicationId;
const GROWTH_EVENT_ID = PLATFORM_EVIDENCE_CHAIN_GOLD_IDS.growthEventId;

async function waitForE2EHarness(page: Page): Promise<void> {
  await page.waitForFunction(() =>
    Boolean(
      (window as Window & {
        __scholesaE2E?: E2EWindowApi;
      }).__scholesaE2E
    )
  );
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
  await page.evaluate(
    async ({ nextUid, locale }) => {
      await (window as Window & {
        __scholesaE2E: E2EWindowApi;
      }).__scholesaE2E.signInAs(nextUid, locale);
    },
    { nextUid: uid, locale: 'en' }
  );
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
  await page.waitForURL((url) => `${url.pathname}${url.search}` === path, { timeout: 10_000 });
}

async function getCollection(page: Page, collectionName: string): Promise<CollectionRecord[]> {
  return page.evaluate((name) => {
    return (window as Window & {
      __scholesaE2E: E2EWindowApi;
    }).__scholesaE2E.getCollection(name);
  }, collectionName);
}

async function seedEvidenceChain(page: Page): Promise<void> {
  const records = canonicalPlatformEvidenceChainGoldRecords();

  await page.evaluate(
    ({ seedRecords }) => {
      (window as Window & {
        __scholesaE2E: E2EWindowApi;
      }).__scholesaE2E.seedEvidenceChain(seedRecords);
    },
    { seedRecords: records }
  );
}

test.beforeEach(async ({ page }) => {
  await resetE2EState(page);
  await seedEvidenceChain(page);
});

test('verified proof and rubric growth are consumed by educator, guardian, and site routes', async ({
  page,
}) => {
  await signInAs(page, EDUCATOR_ALPHA);
  await gotoProtectedRoute(page, `/en/educator/rubrics/apply?portfolioItemId=${PORTFOLIO_ITEM_ID}`);

  await expect(page.getByTestId('educator-rubric-portfolio-handoff')).toBeVisible();
  await expect(page.getByTestId('educator-rubric-portfolio-handoff')).toContainText(
    'Robotics Prototype Evidence Pack'
  );
  await expect(page.getByTestId('educator-rubric-portfolio-handoff')).toContainText(
    'Learner: Learner Alpha'
  );

  expect(await getCollection(page, 'proofOfLearningBundles')).toEqual(
    expect.arrayContaining([expect.objectContaining({ id: 'proof-bundle-alpha', status: 'verified' })])
  );
  expect(await getCollection(page, 'rubricApplications')).toEqual(
    expect.arrayContaining([expect.objectContaining({ id: RUBRIC_APPLICATION_ID, status: 'applied' })])
  );
  expect(await getCollection(page, 'capabilityGrowthEvents')).toEqual(
    expect.arrayContaining([expect.objectContaining({ id: GROWTH_EVENT_ID, capabilityId: CAPABILITY_ID })])
  );

  await signInAs(page, PARENT_ALPHA);
  await gotoProtectedRoute(page, '/en/parent/passport');

  const passport = page.getByTestId(`ideation-passport-${LEARNER_ALPHA}`);
  await expect(passport).toBeVisible();
  await expect(passport).toContainText('1 capability claims');
  await expect(passport).toContainText('Prototype iteration and testing');
  await expect(passport).toContainText('Level 4');
  await expect(passport).toContainText('rubric 4/4');
  await expect(passport).toContainText('proof: E·O·R');
  await expect(passport).toContainText('Explains test evidence and chooses the next prototype change.');

  const portfolioItem = page.getByTestId(`portfolio-item-${PORTFOLIO_ITEM_ID}`);
  await expect(portfolioItem).toBeVisible();
  await expect(portfolioItem).toContainText('Robotics Prototype Evidence Pack');
  await expect(portfolioItem).toContainText('Educator observed');
  await expect(portfolioItem).toContainText('Verified by: Educator Alpha');
  await expect(portfolioItem).toContainText('Rubric: 4/4 (Level 4/4)');

  const growthTimeline = page.getByTestId(`growth-timeline-${LEARNER_ALPHA}`);
  await expect(growthTimeline).toBeVisible();
  await expect(growthTimeline).toContainText('Prototype iteration and testing');
  await expect(growthTimeline).toContainText('1 evidence');
  await expect(growthTimeline).toContainText('1 portfolio item');
  await expect(growthTimeline).toContainText('rubric 4/4');

  await signInAs(page, SITE_ADMIN);
  await gotoProtectedRoute(page, '/en/site/evidence-health');

  const kpis = page.getByTestId('evidence-health-kpis');
  await expect(kpis).toContainText('1 of 2 learners have evidence');
  await expect(kpis).toContainText('Total Evidence');
  await expect(kpis).toContainText('1');
  await expect(kpis).toContainText('Capability Mapped');
  await expect(kpis).toContainText('100%');
  await expect(kpis).toContainText('Rubric Applied');
  await expect(kpis).toContainText('100%');

  const educators = page.getByTestId('evidence-health-educators');
  await expect(educators).toContainText('Educator Alpha');
  await expect(educators).toContainText('1');

  const evidenceRecords = await getCollection(page, 'evidenceRecords');
  expect(evidenceRecords).toEqual(
    expect.arrayContaining([
      expect.objectContaining({
        id: EVIDENCE_ID,
        capabilityMapped: true,
        rubricStatus: 'applied',
        growthStatus: 'recorded',
      }),
    ])
  );
});
