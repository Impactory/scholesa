import { expect, test, type Page } from '@playwright/test';

type CollectionRecord = Record<string, unknown>;

type E2EWindowApi = {
  signInAs: (uid: string, locale?: string) => Promise<{ uid: string | null }>;
  reset: (locale?: string) => Promise<void>;
  currentUid: () => string | null;
  getCollection: (collectionName: string) => CollectionRecord[];
  seedEvidenceChain: (records: Record<string, CollectionRecord[]>) => void;
};

const LEARNER_ALPHA = 'learner-alpha';
const EDUCATOR_ALPHA = 'educator-alpha';
const PARENT_ALPHA = 'parent-alpha';
const SITE_ADMIN = 'site-alpha-admin';
const SITE_ALPHA = 'site-alpha';
const CAPABILITY_ID = 'capability-prototype-iteration';
const PROCESS_DOMAIN_ID = 'process-domain-evidence-reasoning';
const EVIDENCE_ID = 'evidence-chain-alpha';
const PORTFOLIO_ITEM_ID = 'portfolio-evidence-chain-alpha';
const RUBRIC_APPLICATION_ID = 'rubric-application-alpha';
const GROWTH_EVENT_ID = 'growth-event-alpha';

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
  const timestamp = new Date().toISOString();
  const records: Record<string, CollectionRecord[]> = {
    capabilities: [
      {
        id: CAPABILITY_ID,
        siteId: SITE_ALPHA,
        title: 'Prototype iteration and testing',
        pillarCode: 'FUTURE_SKILLS',
        progressionDescriptor: 'Explains test evidence and chooses the next prototype change.',
        status: 'active',
      },
    ],
    processDomains: [
      {
        id: PROCESS_DOMAIN_ID,
        siteId: SITE_ALPHA,
        title: 'Evidence reasoning',
        status: 'active',
      },
    ],
    evidenceRecords: [
      {
        id: EVIDENCE_ID,
        siteId: SITE_ALPHA,
        learnerId: LEARNER_ALPHA,
        educatorId: EDUCATOR_ALPHA,
        sessionOccurrenceId: 'session-future-skills',
        capabilityIds: [CAPABILITY_ID],
        portfolioItemId: PORTFOLIO_ITEM_ID,
        source: 'educator_observation',
        description: 'Educator observed Learner Alpha comparing prototype test results.',
        capabilityMapped: true,
        rubricStatus: 'applied',
        growthStatus: 'recorded',
        rubricApplicationId: RUBRIC_APPLICATION_ID,
        createdAt: timestamp,
        observedAt: timestamp,
      },
    ],
    proofOfLearningBundles: [
      {
        id: 'proof-bundle-alpha',
        siteId: SITE_ALPHA,
        learnerId: LEARNER_ALPHA,
        portfolioItemId: PORTFOLIO_ITEM_ID,
        status: 'verified',
        verificationStatus: 'verified',
        verifiedBy: EDUCATOR_ALPHA,
        verifiedAt: timestamp,
      },
    ],
    portfolioItems: [
      {
        id: PORTFOLIO_ITEM_ID,
        siteId: SITE_ALPHA,
        learnerId: LEARNER_ALPHA,
        title: 'Robotics Prototype Evidence Pack',
        description: 'Verified proof bundle tied to educator observation and rubric application.',
        mediaType: 'document',
        status: 'published',
        source: 'educator_observation',
        capabilityIds: [CAPABILITY_ID],
        evidenceRecordIds: [EVIDENCE_ID],
        missionAttemptId: 'mission-attempt-alpha',
        proofOfLearningStatus: 'verified',
        aiDisclosureStatus: 'learner-ai-not-used',
        proofDetails: {
          explainItBack: true,
          oralCheck: true,
          miniRebuild: true,
          explainItBackExcerpt: 'I changed one variable and used the test evidence to justify the next iteration.',
          oralCheckExcerpt: 'Learner explained why the stronger test result supports the design choice.',
          miniRebuildExcerpt: 'Learner rebuilt the sensor mount from memory and named the tradeoff.',
          educatorVerifierName: 'Educator Alpha',
          proofCheckpointCount: 3,
        },
        reviewedAt: timestamp,
        rubricScore: { raw: 4, max: 4, level: 'Level 4' },
        updatedAt: timestamp,
      },
    ],
    rubricApplications: [
      {
        id: RUBRIC_APPLICATION_ID,
        siteId: SITE_ALPHA,
        learnerId: LEARNER_ALPHA,
        educatorId: EDUCATOR_ALPHA,
        portfolioItemId: PORTFOLIO_ITEM_ID,
        evidenceRecordIds: [EVIDENCE_ID],
        capabilityScores: [{ capabilityId: CAPABILITY_ID, score: 4, maxScore: 4 }],
        status: 'applied',
        createdAt: timestamp,
      },
    ],
    capabilityMastery: [
      {
        id: `mastery-${LEARNER_ALPHA}-${CAPABILITY_ID}`,
        siteId: SITE_ALPHA,
        learnerId: LEARNER_ALPHA,
        capabilityId: CAPABILITY_ID,
        currentLevel: 4,
        highestLevel: 4,
        evidenceCount: 1,
        rubricScore: { raw: 4, max: 4 },
        updatedAt: timestamp,
      },
    ],
    processDomainMastery: [
      {
        id: `process-mastery-${LEARNER_ALPHA}-${PROCESS_DOMAIN_ID}`,
        siteId: SITE_ALPHA,
        learnerId: LEARNER_ALPHA,
        processDomainId: PROCESS_DOMAIN_ID,
        title: 'Evidence reasoning',
        currentLevel: 'Level 4',
        highestLevel: 'Level 4',
        evidenceCount: 1,
        updatedAt: timestamp,
      },
    ],
    capabilityGrowthEvents: [
      {
        id: GROWTH_EVENT_ID,
        siteId: SITE_ALPHA,
        learnerId: LEARNER_ALPHA,
        capabilityId: CAPABILITY_ID,
        capabilityTitle: 'Prototype iteration and testing',
        levelAchieved: 'Level 4',
        educatorId: EDUCATOR_ALPHA,
        educatorName: 'Educator Alpha',
        linkedEvidenceCount: 1,
        linkedPortfolioCount: 1,
        linkedEvidenceRecordIds: [EVIDENCE_ID],
        linkedPortfolioItemIds: [PORTFOLIO_ITEM_ID],
        missionAttemptId: 'mission-attempt-alpha',
        rubricScore: { raw: 4, max: 4 },
        createdAt: timestamp,
        date: timestamp,
      },
    ],
    processDomainGrowthEvents: [
      {
        id: 'process-growth-event-alpha',
        siteId: SITE_ALPHA,
        learnerId: LEARNER_ALPHA,
        processDomainId: PROCESS_DOMAIN_ID,
        processDomainTitle: 'Evidence reasoning',
        fromLevel: 'Level 3',
        toLevel: 'Level 4',
        educatorName: 'Educator Alpha',
        evidenceCount: 1,
        createdAt: timestamp,
        date: timestamp,
      },
    ],
  };

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
