import { expect, test, type Page } from '@playwright/test';
import {
  PLATFORM_EVIDENCE_CHAIN_GOLD_IDS,
  canonicalPlatformEvidenceChainRouteProofReferences,
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
const HQ_ALPHA = 'hq-alpha';
const PARENT_ALPHA = PLATFORM_EVIDENCE_CHAIN_GOLD_IDS.parentId;
const SITE_ADMIN = PLATFORM_EVIDENCE_CHAIN_GOLD_IDS.siteAdminId;
const CAPABILITY_ID = PLATFORM_EVIDENCE_CHAIN_GOLD_IDS.capabilityId;
const EVIDENCE_ID = PLATFORM_EVIDENCE_CHAIN_GOLD_IDS.evidenceId;
const PORTFOLIO_ITEM_ID = PLATFORM_EVIDENCE_CHAIN_GOLD_IDS.portfolioItemId;
const RUBRIC_APPLICATION_ID = PLATFORM_EVIDENCE_CHAIN_GOLD_IDS.rubricApplicationId;
const RUBRIC_TEMPLATE_ID = PLATFORM_EVIDENCE_CHAIN_GOLD_IDS.rubricTemplateId;
const GROWTH_EVENT_ID = PLATFORM_EVIDENCE_CHAIN_GOLD_IDS.growthEventId;
const LEARNER_CREATED_PORTFOLIO_ITEM_ID = 'portfolio-learner-created-proof';

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
  const liveAuthoredRubricTitle = 'Live HQ Authored Evidence Rubric';
  const editedLiveAuthoredRubricTitle = 'Edited Live HQ Authored Evidence Rubric';

  await page.evaluate(
    ({ portfolioItem, missionAttempt }) => {
      (window as Window & {
        __scholesaE2E: E2EWindowApi;
      }).__scholesaE2E.seedEvidenceChain({
        portfolioItems: [portfolioItem],
        missionAttempts: [missionAttempt],
      });
    },
    {
      portfolioItem: {
        id: LEARNER_CREATED_PORTFOLIO_ITEM_ID,
        learnerId: LEARNER_ALPHA,
        siteId: 'site-alpha',
        title: 'Learner-Created Proof Draft',
        description: 'Learner-authored proof assembly browser item.',
        mediaType: 'document',
        status: 'draft',
        updatedAt: '2026-03-07T18:05:00.000Z',
        source: 'learner-created-proof-e2e',
        capabilityIds: [CAPABILITY_ID],
      },
      missionAttempt: {
        id: 'mission-attempt-consent-e2e',
        learnerId: LEARNER_ALPHA,
        siteId: 'site-alpha',
        missionId: 'mission-robotics',
        notes: 'Learner submitted evidence for broader-share consent proof.',
        content: 'I tested the prototype and can explain what changed after feedback.',
        status: 'submitted',
        submittedAt: '2026-03-07T18:10:00.000Z',
        updatedAt: '2026-03-07T18:10:00.000Z',
        capabilityId: CAPABILITY_ID,
        proofOfLearningStatus: 'verified',
        aiDisclosureStatus: 'learner-ai-verified',
      },
    }
  );

  await signInAs(page, HQ_ALPHA);
  await gotoProtectedRoute(page, '/en/hq/rubric-builder');

  await expect(page.getByRole('heading', { name: 'Capability Framework' })).toBeVisible();
  await page.getByRole('button', { name: '+ Add Rubric Template' }).click();
  await expect(page.getByRole('heading', { name: 'Create Rubric Template' })).toBeVisible();
  await page.getByPlaceholder('e.g., Design Thinking Project Rubric').fill(liveAuthoredRubricTitle);
  await page.getByRole('button', { name: '+ Add Criterion' }).click();
  await page
    .getByPlaceholder('Criterion label (e.g., Problem decomposition)')
    .fill('Explains learner test evidence from live HQ authoring');
  await page.getByLabel('Map to capability').selectOption(CAPABILITY_ID);
  await page.getByRole('button', { name: 'Draft' }).click();
  await page.getByRole('button', { name: 'Create' }).click();
  await expect(page.getByText('Rubric template created.')).toBeVisible();
  await expect(page.getByText(liveAuthoredRubricTitle)).toBeVisible();

  await page
    .locator('[data-testid^="rubric-template-card-"]')
    .filter({ hasText: liveAuthoredRubricTitle })
    .getByRole('button', { name: 'Edit' })
    .click();
  await expect(page.getByRole('heading', { name: 'Edit Rubric Template' })).toBeVisible();
  await page
    .getByPlaceholder('e.g., Design Thinking Project Rubric')
    .fill(editedLiveAuthoredRubricTitle);
  await page.getByRole('button', { name: 'Update' }).click();
  await expect(page.getByText('Rubric template published.')).toBeVisible();
  await expect(page.getByText(editedLiveAuthoredRubricTitle)).toBeVisible();

  expect(await getCollection(page, 'rubricTemplates')).toEqual(
    expect.arrayContaining([
      expect.objectContaining({
        title: editedLiveAuthoredRubricTitle,
        siteId: 'site-alpha',
        status: 'published',
        createdBy: HQ_ALPHA,
        capabilityIds: expect.arrayContaining([CAPABILITY_ID]),
        criteria: expect.arrayContaining([
          expect.objectContaining({
            label: 'Explains learner test evidence from live HQ authoring',
            capabilityId: CAPABILITY_ID,
          }),
        ]),
      }),
    ])
  );

  await signInAs(page, EDUCATOR_ALPHA);
  await gotoProtectedRoute(page, `/en/educator/rubrics/apply?portfolioItemId=${PORTFOLIO_ITEM_ID}`);

  await expect(page.getByTestId('educator-rubric-portfolio-handoff')).toBeVisible();
  await expect(page.getByTestId('educator-rubric-portfolio-handoff')).toContainText(
    'Robotics Prototype Evidence Pack'
  );
  await expect(page.getByTestId('educator-rubric-portfolio-handoff')).toContainText(
    'Learner: Learner Alpha'
  );
  await expect(page.getByLabel('Select rubric template')).toContainText(
    'Prototype Iteration Evidence Rubric'
  );
  await expect(page.getByLabel('Select rubric template')).toContainText(
    editedLiveAuthoredRubricTitle
  );

  const authoredTemplate = (await getCollection(page, 'rubricTemplates')).find(
    (template) => template.title === editedLiveAuthoredRubricTitle
  );
  expect(authoredTemplate).toEqual(
    expect.objectContaining({
      siteId: 'site-alpha',
      status: 'published',
      createdBy: HQ_ALPHA,
      capabilityIds: expect.arrayContaining([CAPABILITY_ID]),
    })
  );
  const authoredTemplateId = String(authoredTemplate?.id);
  await page.getByLabel('Select rubric template').selectOption(authoredTemplateId);
  await page.getByRole('button', { name: 'Advanced' }).click();
  await page.getByRole('button', { name: 'Apply Rubric (1 scores)' }).click();

  await expect.poll(async () => getCollection(page, 'rubricApplications')).toEqual(
    expect.arrayContaining([
      expect.objectContaining({
        rubricId: authoredTemplateId,
        learnerId: LEARNER_ALPHA,
        siteId: 'site-alpha',
        status: 'applied',
      }),
    ])
  );
  expect(await getCollection(page, 'capabilityGrowthEvents')).toEqual(
    expect.arrayContaining([
      expect.objectContaining({
        rubricId: authoredTemplateId,
        learnerId: LEARNER_ALPHA,
        capabilityId: CAPABILITY_ID,
      }),
    ])
  );

  expect(await getCollection(page, 'rubricTemplates')).toEqual(
    expect.arrayContaining([
      expect.objectContaining({
        id: RUBRIC_TEMPLATE_ID,
        siteId: 'site-alpha',
        status: 'published',
        capabilityIds: expect.arrayContaining([CAPABILITY_ID]),
      }),
    ])
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
  expect(canonicalPlatformEvidenceChainRouteProofReferences()).toMatchObject({
    educatorRubricApply: {
      route: '/educator/rubrics/apply',
      web: ['test/e2e/evidence-chain-cross-role.e2e.spec.ts'],
    },
    parentPassport: {
      route: '/parent/passport',
      web: ['test/e2e/evidence-chain-cross-role.e2e.spec.ts'],
    },
    siteEvidenceHealth: {
      route: '/site/evidence-health',
      web: ['test/e2e/evidence-chain-cross-role.e2e.spec.ts'],
    },
  });
  expect(await getCollection(page, 'reportShareRequests')).toEqual(
    expect.arrayContaining([
      expect.objectContaining({
        id: 'report-share-request-alpha',
        explicitConsentId: 'report-share-consent-alpha',
        audience: 'external',
        visibility: 'external',
      }),
    ])
  );

  await signInAs(page, EDUCATOR_ALPHA);
  await gotoProtectedRoute(page, '/en/educator/missions/review');

  await expect(page.getByTestId('educator-evidence-review')).toBeVisible();
  await expect(page.getByTestId('submission-mission-attempt-consent-e2e')).toContainText(
    'Learner Alpha'
  );
  const consentRequester = page.getByTestId(`report-share-consent-requester-${LEARNER_ALPHA}`);
  await expect(consentRequester).toBeVisible();
  await consentRequester.getByRole('button', { name: 'Partner' }).click();
  await consentRequester.getByRole('button', { name: 'Request consent' }).click();
  await expect(consentRequester).toContainText('Consent status: pending');

  const partnerConsent = (await getCollection(page, 'reportShareConsents')).find(
    (consent) => consent.scope === 'partner' && consent.status === 'pending'
  );
  expect(partnerConsent).toEqual(
    expect.objectContaining({
      learnerId: LEARNER_ALPHA,
      siteId: 'site-alpha',
      audience: 'partner',
      visibility: 'external',
    })
  );

  await signInAs(page, PARENT_ALPHA);
  await gotoProtectedRoute(page, '/en/parent/passport');

  const consentManager = page.getByTestId(`report-share-request-manager-${LEARNER_ALPHA}`);
  await expect(consentManager).toContainText('Explicit consent requests');
  await consentManager
    .locator('li')
    .filter({ hasText: 'partner' })
    .getByRole('button', { name: 'Grant' })
    .click();
  await expect(consentManager).toContainText('Consent granted · partner');

  expect(await getCollection(page, 'reportShareConsents')).toEqual(
    expect.arrayContaining([
      expect.objectContaining({
        id: partnerConsent?.id,
        status: 'granted',
        decidedBy: PARENT_ALPHA,
      }),
    ])
  );

  await signInAs(page, EDUCATOR_ALPHA);
  await gotoProtectedRoute(page, '/en/educator/missions/review');

  const grantedConsentRequester = page.getByTestId(`report-share-consent-requester-${LEARNER_ALPHA}`);
  await grantedConsentRequester.getByRole('button', { name: 'Partner' }).click();
  await expect(grantedConsentRequester).toContainText('Consent status: granted');
  await grantedConsentRequester.getByRole('button', { name: 'Activate share' }).click();
  await expect(grantedConsentRequester).toContainText('Active share:');

  expect(await getCollection(page, 'reportShareRequests')).toEqual(
    expect.arrayContaining([
      expect.objectContaining({
        explicitConsentId: partnerConsent?.id,
        audience: 'partner',
        visibility: 'external',
        status: 'active',
      }),
    ])
  );

  await signInAs(page, LEARNER_ALPHA);
  await gotoProtectedRoute(page, '/en/learner/proof-assembly');

  await expect(page.getByRole('heading', { name: 'Proof of Learning' })).toBeVisible();
  await page.getByRole('button', { name: /Learner-Created Proof Draft/ }).click();
  await page
    .getByPlaceholder('I learned that... My approach was...')
    .fill('I learned that testing evidence changed which prototype part I rebuilt first.');
  await page
    .getByPlaceholder('If asked, I would explain...')
    .fill('If asked, I would explain why the sensor result showed the weak point.');
  await page
    .getByPlaceholder('To rebuild this, I would start by...')
    .fill('To rebuild this, I would start by retesting the sensor mount with one variable changed.');
  await page.getByRole('button', { name: 'Save Proof Bundle' }).click();
  await expect(page.getByText('Ready for review')).toBeVisible();

  const learnerCreatedProofBundles = await getCollection(page, 'proofOfLearningBundles');
  const learnerCreatedProofBundle = learnerCreatedProofBundles.find(
    (bundle) => bundle.portfolioItemId === LEARNER_CREATED_PORTFOLIO_ITEM_ID
  );
  expect(learnerCreatedProofBundle).toEqual(
    expect.objectContaining({
      learnerId: LEARNER_ALPHA,
      siteId: 'site-alpha',
      hasExplainItBack: true,
      hasOralCheck: true,
      hasMiniRebuild: true,
      verificationStatus: 'pending_review',
      status: 'pending_review',
    })
  );
  expect(await getCollection(page, 'portfolioItems')).toEqual(
    expect.arrayContaining([
      expect.objectContaining({
        id: LEARNER_CREATED_PORTFOLIO_ITEM_ID,
        proofBundleId: learnerCreatedProofBundle?.id,
        proofOfLearningStatus: 'pending_review',
        proofHasExplainItBack: true,
        proofHasOralCheck: true,
        proofHasMiniRebuild: true,
        proofCheckpointCount: 3,
      }),
    ])
  );

  await signInAs(page, EDUCATOR_ALPHA);
  await gotoProtectedRoute(page, '/en/educator/proof-review');

  await expect(page.getByRole('heading', { name: 'Proof-of-Learning Verification' })).toBeVisible();
  await page.getByRole('button', { name: /Learner-Created Proof Draft/ }).click();
  await expect(page.getByText('Next step after proof verification')).toBeVisible();
  await page.getByPlaceholder('Overall notes on this verification').fill(
    'Learner independently explained the rebuild path from their own evidence.'
  );
  await page.getByRole('button', { name: 'Verify (3/3 checks)' }).click();
  await expect(page.getByText('Verified — proof confirmed. Ready for rubric application.')).toBeVisible();

  expect(await getCollection(page, 'proofOfLearningBundles')).toEqual(
    expect.arrayContaining([
      expect.objectContaining({
        id: learnerCreatedProofBundle?.id,
        portfolioItemId: LEARNER_CREATED_PORTFOLIO_ITEM_ID,
        verificationStatus: 'verified',
        status: 'verified',
        educatorVerifierId: EDUCATOR_ALPHA,
      }),
    ])
  );
  expect(await getCollection(page, 'portfolioItems')).toEqual(
    expect.arrayContaining([
      expect.objectContaining({
        id: LEARNER_CREATED_PORTFOLIO_ITEM_ID,
        verificationStatus: 'verified',
        proofOfLearningStatus: 'verified',
        educatorVerifierId: EDUCATOR_ALPHA,
      }),
    ])
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

  await signInAs(page, EDUCATOR_ALPHA);
  await gotoProtectedRoute(page, '/en/educator/sessions');

  const educatorSession = page.getByRole('button', { name: /Skills Studio/ });
  await expect(educatorSession).toContainText('1 learners');
  await expect(educatorSession).toContainText('1 evidence');
  await educatorSession.click();
  const educatorSessionDetails = page.getByText('Evidence Records').locator('..');
  await expect(educatorSessionDetails).toContainText('1');

  await signInAs(page, SITE_ADMIN);
  await gotoProtectedRoute(page, '/en/site/sessions');

  const siteSession = page.getByTestId('workflow-record-session-future-skills');
  await expect(siteSession).toContainText('Skills Studio');
  await expect(siteSession).toContainText('Site: site-alpha');
  await expect(siteSession).toContainText('Evidence Count:');
  await expect(siteSession).toContainText('1');
  await expect(siteSession).toContainText('Observed Learner Count:');

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
