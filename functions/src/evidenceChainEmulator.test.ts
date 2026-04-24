const PROJECT_ID = 'scholesa-evidence-chain-emulator';
const SITE_ID = 'site-1';
const EDUCATOR_ID = 'educator-1';
const LEARNER_ID = 'learner-1';
const PARENT_ID = 'parent-1';
const CAPABILITY_ID = 'capability-1';
const PROCESS_DOMAIN_ID = 'process-domain-1';
const SESSION_ID = 'session-1';
const SESSION_OCCURRENCE_ID = 'session-occurrence-1';
const ENROLLMENT_ID = 'enrollment-1';
const EVIDENCE_ID = 'evidence-1';
const PORTFOLIO_ITEM_ID = 'portfolio-1';
const PROOF_BUNDLE_ID = 'proof-bundle-1';

process.env.GCLOUD_PROJECT = PROJECT_ID;
process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';

const admin = require('firebase-admin') as typeof import('firebase-admin');

type EvidenceChainFunctions = typeof import('./index');

let functionsModule: EvidenceChainFunctions;

function authFor(uid: string) {
  return {
    uid,
    token: { uid },
    rawToken: { uid },
  } as any;
}

function callableRequest<T extends Record<string, unknown>>(uid: string, data: T) {
  return {
    auth: authFor(uid),
    data,
    rawRequest: {} as any,
    acceptsStreaming: false,
  } as any;
}

async function clearFirestore(): Promise<void> {
  const response = await fetch(
    `http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`,
    { method: 'DELETE' },
  );

  if (!response.ok) {
    throw new Error(`Failed to clear Firestore emulator: ${response.status} ${response.statusText}`);
  }
}

async function seedEvidenceChainFixture(): Promise<void> {
  const db = admin.firestore();
  const batch = db.batch();
  const now = new Date();
  const observedAt = admin.firestore.Timestamp.fromDate(now);
  const nextSession = admin.firestore.Timestamp.fromDate(new Date(now.getTime() + (24 * 60 * 60 * 1000)));

  batch.set(db.collection('sites').doc(SITE_ID), {
    name: 'Studio One',
    status: 'active',
    createdAt: observedAt,
    updatedAt: observedAt,
  });

  batch.set(db.collection('users').doc(EDUCATOR_ID), {
    email: 'educator@example.com',
    displayName: 'Educator One',
    role: 'educator',
    siteIds: [SITE_ID],
    activeSiteId: SITE_ID,
  });

  batch.set(db.collection('users').doc(LEARNER_ID), {
    email: 'learner@example.com',
    displayName: 'Learner One',
    role: 'learner',
    siteIds: [SITE_ID],
    activeSiteId: SITE_ID,
    parentIds: [PARENT_ID],
  });

  batch.set(db.collection('users').doc(PARENT_ID), {
    email: 'parent@example.com',
    displayName: 'Parent One',
    role: 'parent',
    siteIds: [SITE_ID],
    activeSiteId: SITE_ID,
    learnerIds: [LEARNER_ID],
  });

  batch.set(db.collection('capabilities').doc(CAPABILITY_ID), {
    title: 'Systems Thinking',
    siteId: SITE_ID,
    pillarCode: 'FUTURE_SKILLS',
    status: 'active',
    progressionDescriptors: {
      beginning: 'Names basic parts of the system.',
      developing: 'Connects parts with support.',
      proficient: 'Explains how system changes affect outcomes.',
      advanced: 'Improves the system with evidence-backed reasoning.',
    },
    createdAt: observedAt,
    updatedAt: observedAt,
  });

  batch.set(db.collection('processDomains').doc(PROCESS_DOMAIN_ID), {
    title: 'Collaboration',
    descriptor: 'Works productively with others.',
    siteId: SITE_ID,
    status: 'active',
    createdAt: observedAt,
    updatedAt: observedAt,
  });

  batch.set(db.collection('sessions').doc(SESSION_ID), {
    siteId: SITE_ID,
    title: 'Studio Systems Lab',
    educatorId: EDUCATOR_ID,
    createdAt: observedAt,
    updatedAt: observedAt,
  });

  batch.set(db.collection('sessionOccurrences').doc(SESSION_OCCURRENCE_ID), {
    siteId: SITE_ID,
    sessionId: SESSION_ID,
    sessionTitle: 'Studio Systems Lab',
    title: 'Studio Systems Lab',
    educatorId: EDUCATOR_ID,
    startTime: nextSession,
    createdAt: observedAt,
    updatedAt: observedAt,
  });

  batch.set(db.collection('enrollments').doc(ENROLLMENT_ID), {
    siteId: SITE_ID,
    sessionId: SESSION_ID,
    learnerId: LEARNER_ID,
    status: 'active',
    createdAt: observedAt,
    updatedAt: observedAt,
  });

  batch.set(db.collection('evidenceRecords').doc(EVIDENCE_ID), {
    siteId: SITE_ID,
    learnerId: LEARNER_ID,
    educatorId: EDUCATOR_ID,
    capabilityId: CAPABILITY_ID,
    pillarCode: 'FUTURE_SKILLS',
    description: 'Observed the learner diagnosing a prototype system failure.',
    sessionOccurrenceId: SESSION_OCCURRENCE_ID,
    observedAt,
    rubricStatus: 'pending',
    growthStatus: 'pending',
  });

  batch.set(db.collection('proofOfLearningBundles').doc(PROOF_BUNDLE_ID), {
    siteId: SITE_ID,
    learnerId: LEARNER_ID,
    portfolioItemId: PORTFOLIO_ITEM_ID,
    verificationStatus: 'missing',
    versionHistory: [],
    createdAt: observedAt,
    updatedAt: observedAt,
  });

  batch.set(db.collection('portfolioItems').doc(PORTFOLIO_ITEM_ID), {
    siteId: SITE_ID,
    learnerId: LEARNER_ID,
    title: 'Prototype systems diagnosis',
    description: 'Learner explained how they found and fixed the system issue.',
    source: 'educator_observation',
    capabilityIds: [CAPABILITY_ID],
    capabilityTitles: ['Systems Thinking'],
    pillarCodes: ['FUTURE_SKILLS'],
    evidenceRecordIds: [EVIDENCE_ID],
    proofBundleId: PROOF_BUNDLE_ID,
    verificationStatus: 'pending',
    proofOfLearningStatus: 'missing',
    proofHasExplainItBack: false,
    proofHasOralCheck: false,
    proofHasMiniRebuild: false,
    proofCheckpointCount: 0,
    aiDisclosureStatus: 'learner-ai-not-used',
    artifacts: [],
    createdAt: observedAt,
    updatedAt: observedAt,
  });

  await batch.commit();
}

describe('Evidence chain emulator integration', () => {
  beforeAll(async () => {
    functionsModule = await import('./index');
  });

  beforeEach(async () => {
    await clearFirestore();
    await seedEvidenceChainFixture();
  });

  afterAll(async () => {
    await clearFirestore();
    const activeApps = admin.apps.filter(
      (app): app is NonNullable<(typeof admin.apps)[number]> => Boolean(app),
    );
    await Promise.all(activeApps.map((app) => app.delete()));
  });

  it('drives session-backed evidence through proof, rubric, mastery, and passport bundles', async () => {
    const db = admin.firestore();
    const verifyResult = await functionsModule.verifyProofOfLearning.run(callableRequest(
      EDUCATOR_ID,
      {
        portfolioItemId: PORTFOLIO_ITEM_ID,
        verificationStatus: 'verified',
        proofOfLearningStatus: 'verified',
        proofChecks: {
          explainItBack: true,
          oralCheck: true,
          miniRebuild: false,
        },
        excerpts: {
          explainItBack: 'The learner explained why the sensor loop failed.',
          oralCheck: 'The learner defended the fix in real time.',
        },
        educatorNotes: 'Authentic explanation confirmed during studio time.',
      },
    ));

    expect(verifyResult).toMatchObject({
      portfolioItemId: PORTFOLIO_ITEM_ID,
      verificationStatus: 'verified',
      capabilitiesReadyForRubric: 1,
    });

    const rubricResult = await functionsModule.applyRubricToEvidence.run(callableRequest(
      EDUCATOR_ID,
      {
        evidenceRecordIds: [EVIDENCE_ID],
        portfolioItemId: PORTFOLIO_ITEM_ID,
        learnerId: LEARNER_ID,
        siteId: SITE_ID,
        rubricId: 'rubric-template-1',
        scores: [
          {
            criterionId: 'systems-thinking-criterion',
            capabilityId: CAPABILITY_ID,
            processDomainId: PROCESS_DOMAIN_ID,
            pillarCode: 'FUTURE_SKILLS',
            score: 4,
            maxScore: 4,
          },
        ],
      },
    ));

    expect(rubricResult.rubricApplicationId).toEqual(expect.any(String));
    expect(rubricResult.growthEventIds).toHaveLength(1);
    expect(rubricResult.portfolioItemIds).toContain(PORTFOLIO_ITEM_ID);
    expect(rubricResult.capabilitiesProcessed).toBe(1);

    const evidenceData = (await db.collection('evidenceRecords').doc(EVIDENCE_ID).get()).data();
    expect(evidenceData).toMatchObject({
      sessionOccurrenceId: SESSION_OCCURRENCE_ID,
      rubricStatus: 'applied',
      growthStatus: 'recorded',
      rubricApplicationId: rubricResult.rubricApplicationId,
    });

    const proofBundleData = (await db.collection('proofOfLearningBundles').doc(PROOF_BUNDLE_ID).get()).data();
    expect(proofBundleData).toMatchObject({
      verificationStatus: 'verified',
      educatorVerifierId: EDUCATOR_ID,
      hasExplainItBack: true,
      hasOralCheck: true,
      hasMiniRebuild: false,
    });

    const masteryData = (await db.collection('capabilityMastery').doc(`${LEARNER_ID}_${CAPABILITY_ID}`).get()).data();
    expect(masteryData).toMatchObject({
      learnerId: LEARNER_ID,
      capabilityId: CAPABILITY_ID,
      siteId: SITE_ID,
      latestLevel: 4,
      highestLevel: 4,
      latestEvidenceId: EVIDENCE_ID,
    });

    const processDomainMasteryData = (await db.collection('processDomainMastery').doc(`${LEARNER_ID}_${PROCESS_DOMAIN_ID}`).get()).data();
    expect(processDomainMasteryData).toMatchObject({
      learnerId: LEARNER_ID,
      processDomainId: PROCESS_DOMAIN_ID,
      siteId: SITE_ID,
      latestLevel: 4,
      highestLevel: 4,
      lastAssessedBy: EDUCATOR_ID,
      evidenceCount: 1,
    });

    const learnerBundle = await functionsModule.getLearnerPassportBundle.run(callableRequest(
      LEARNER_ID,
      {
        siteId: SITE_ID,
        locale: 'en',
        range: 'all',
      },
    ));

    expect(learnerBundle.learners).toHaveLength(1);
    const learnerSummary = learnerBundle.learners[0] as Record<string, any>;
    expect(learnerSummary.upcomingEvents).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          id: SESSION_OCCURRENCE_ID,
          title: 'Studio Systems Lab',
          type: 'session',
        }),
      ]),
    );
    expect(learnerSummary.ideationPassport.claims).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          capabilityId: CAPABILITY_ID,
          title: 'Systems Thinking',
          evidenceCount: 1,
          proofOfLearningStatus: 'verified',
          aiDisclosureStatus: 'learner-ai-not-used',
        }),
      ]),
    );
    expect(learnerSummary.growthTimeline).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          capabilityId: CAPABILITY_ID,
          linkedEvidenceRecordIds: [EVIDENCE_ID],
          linkedPortfolioItemIds: [PORTFOLIO_ITEM_ID],
        }),
      ]),
    );
    expect(learnerSummary.processDomainSnapshot).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          processDomainId: PROCESS_DOMAIN_ID,
          title: 'Collaboration',
          currentLevel: 4,
          highestLevel: 4,
          evidenceCount: 1,
        }),
      ]),
    );
    expect(learnerSummary.processDomainGrowthTimeline).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          processDomainId: PROCESS_DOMAIN_ID,
          title: 'Collaboration',
          toLevel: 4,
          evidenceCount: 1,
        }),
      ]),
    );

    const parentBundle = await functionsModule.getParentDashboardBundle.run(callableRequest(
      PARENT_ID,
      {
        siteId: SITE_ID,
        locale: 'en',
        range: 'all',
      },
    ));

    expect(parentBundle.linkedLearnerCount).toBe(1);
    expect(parentBundle.learners).toHaveLength(1);
    const parentSummary = parentBundle.learners[0] as Record<string, any>;
    expect(parentSummary.ideationPassport.claims).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          capabilityId: CAPABILITY_ID,
          title: 'Systems Thinking',
          evidenceCount: 1,
        }),
      ]),
    );
    expect(parentSummary.processDomainSnapshot).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          processDomainId: PROCESS_DOMAIN_ID,
          title: 'Collaboration',
          currentLevel: 4,
        }),
      ]),
    );
  });
});