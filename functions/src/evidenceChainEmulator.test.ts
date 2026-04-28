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

import { createServer, type IncomingHttpHeaders, type Server } from 'http';
import * as admin from 'firebase-admin';

type EvidenceChainFunctions = typeof import('./index');

let functionsModule: EvidenceChainFunctions;

type CapturedInferenceRequest = {
  headers: IncomingHttpHeaders;
  body: Record<string, unknown>;
};

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

async function startInternalInferenceServer(): Promise<{
  url: string;
  requests: CapturedInferenceRequest[];
  close: () => Promise<void>;
}> {
  const requests: CapturedInferenceRequest[] = [];
  const server = createServer((req, res) => {
    let raw = '';
    req.on('data', (chunk: Buffer) => {
      raw += chunk.toString('utf8');
    });
    req.on('end', () => {
      const body = raw.length > 0 ? JSON.parse(raw) as Record<string, unknown> : {};
      requests.push({ headers: req.headers, body });
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({
        text: 'Test one prototype variable at a time, compare results, and explain the tradeoff in your own words.',
        modelVersion: 'local-internal-llm-test-v1',
        toolSuggestions: ['Run one comparison test', 'Write what changed'],
        traceId: 'internal-trace-1',
        policyVersion: 'internal-policy-test-v1',
        safetyOutcome: 'allowed',
        safetyReasonCode: 'none',
        understanding: {
          intent: 'explain_tradeoff',
          complexity: 'moderate',
          needsScaffold: true,
          emotionalState: 'focused',
          confidence: 0.99,
          responseMode: 'coach',
          topicTags: ['prototype tradeoffs'],
        },
      }));
    });
  });

  await new Promise<void>((resolve, reject) => {
    server.once('error', reject);
    server.listen(0, '127.0.0.1', () => {
      server.off('error', reject);
      resolve();
    });
  });

  const address = server.address();
  if (!address || typeof address === 'string') {
    throw new Error('Internal inference test server did not bind a TCP port.');
  }

  return {
    url: `http://127.0.0.1:${address.port}/v1/chat`,
    requests,
    close: () => new Promise<void>((resolve, reject) => {
      (server as Server).close((error) => {
        if (error) {
          reject(error);
          return;
        }
        resolve();
      });
    }),
  };
}

function restoreEnvVar(name: string, previousValue: string | undefined): void {
  if (previousValue === undefined) {
    delete process.env[name];
    return;
  }
  process.env[name] = previousValue;
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

  batch.set(db.collection('coppaSchoolConsents').doc(SITE_ID), {
    siteId: SITE_ID,
    active: true,
    agreementSigned: true,
    educationalUseOnly: true,
    parentNoticeProvided: true,
    noStudentMarketing: true,
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

  it('drives MiloOS help through explain-back and learner-loop insight without mastery writes', async () => {
    const db = admin.firestore();
    const miloLearnerId = 'milo-learner-1';
    const now = Date.now();
    await Promise.all([
      db.collection('users').doc(miloLearnerId).set({
        email: 'milo-learner@example.com',
        displayName: 'Milo Learner',
        role: 'learner',
        siteIds: [SITE_ID],
        activeSiteId: SITE_ID,
      }),
      db.collection('orchestrationStates').doc(`${miloLearnerId}-latest`).set({
        siteId: SITE_ID,
        learnerId: miloLearnerId,
        x_hat: { cognition: 0.82, engagement: 0.74, integrity: 0.93 },
        P: { trace: 0.1, confidence: 0.95 },
        lastUpdatedAt: admin.firestore.Timestamp.fromMillis(now),
      }),
      db.collection('orchestrationStates').doc(`${miloLearnerId}-baseline`).set({
        siteId: SITE_ID,
        learnerId: miloLearnerId,
        x_hat: { cognition: 0.62, engagement: 0.58, integrity: 0.84 },
        P: { trace: 0.2, confidence: 0.86 },
        lastUpdatedAt: admin.firestore.Timestamp.fromMillis(now - 60 * 60 * 1000),
      }),
    ]);

    const firstCoachResult = await functionsModule.genAiCoach.run(callableRequest(
      miloLearnerId,
      {
        mode: 'explain',
        siteId: SITE_ID,
        gradeBand: 'G9_12',
        conceptTags: ['prototype tradeoffs'],
        studentInput: 'I need help explaining why our prototype tradeoff matters.',
      },
    ));

    const firstOpenedEventId = firstCoachResult.meta.aiHelpOpenedEventId as string;
    expect(firstOpenedEventId).toEqual(expect.any(String));
    expect(firstCoachResult.requiresExplainBack).toBe(true);

    const explainResult = await functionsModule.submitExplainBack.run(callableRequest(
      miloLearnerId,
      {
        siteId: SITE_ID,
        interactionId: firstOpenedEventId,
        explainBack:
          'I chose the lighter prototype because it made testing faster, but the tradeoff is that the structure needs extra bracing before showcase.',
      },
    ));

    expect(explainResult).toMatchObject({ approved: true });

    await functionsModule.genAiCoach.run(callableRequest(
      miloLearnerId,
      {
        mode: 'hint',
        siteId: SITE_ID,
        gradeBand: 'G9_12',
        conceptTags: ['iteration plan'],
        studentInput: 'I need a hint for the next test plan step.',
      },
    ));

    const eventSnap = await db.collection('interactionEvents')
      .where('siteId', '==', SITE_ID)
      .where('actorId', '==', miloLearnerId)
      .get();
    const events = eventSnap.docs.map((doc) => ({ id: doc.id, data: doc.data() }));
    expect(events.map((event) => event.data.eventType)).toEqual(expect.arrayContaining([
      'ai_help_opened',
      'ai_help_used',
      'ai_coach_response',
      'explain_it_back_submitted',
    ]));
    for (const event of events) {
      expect(event.data.timestamp).toBeDefined();
      expect(event.data.createdAt).toBeDefined();
    }
    expect(events.find((event) => event.data.eventType === 'explain_it_back_submitted')?.data.payload).toMatchObject({
      aiHelpOpenedEventId: firstOpenedEventId,
      approved: true,
      mode: 'explain',
    });

    const insights = await functionsModule.bosGetLearnerLoopInsights.run(callableRequest(
      miloLearnerId,
      {
        siteId: SITE_ID,
        learnerId: miloLearnerId,
        lookbackDays: 30,
      },
    ));

    expect(insights.state).toEqual({ cognition: 0.82, engagement: 0.74, integrity: 0.93 });
    expect(insights.stateAvailability).toMatchObject({
      validSamples: 2,
      hasCurrentState: true,
      hasTrendBaseline: true,
    });
    expect(insights.eventCounts).toMatchObject({
      ai_help_opened: 2,
      ai_help_used: 2,
      ai_coach_response: 2,
      explain_it_back_submitted: 1,
    });
    expect(insights.verification).toEqual({
      aiHelpOpened: 2,
      aiHelpUsed: 2,
      explainBackSubmitted: 1,
      pendingExplainBack: 1,
    });
    expect(insights.mvl).toEqual({ active: 0, passed: 0, failed: 0 });
    expect(insights).not.toHaveProperty('capabilityMastery');
    expect(insights).not.toHaveProperty('masteryLevel');

    const masterySnap = await db.collection('capabilityMastery')
      .where('learnerId', '==', miloLearnerId)
      .get();
    expect(masterySnap.empty).toBe(true);
  });

  it('uses configured internal inference in the MiloOS explain-back journey', async () => {
    const db = admin.firestore();
    const inferenceServer = await startInternalInferenceServer();
    const previousLlmUrl = process.env.INTERNAL_LLM_INFERENCE_URL;
    const previousAuthMode = process.env.INTERNAL_INFERENCE_AUTH_MODE;
    const previousRequired = process.env.INTERNAL_INFERENCE_REQUIRED;
    const internalLearnerId = 'milo-internal-learner-1';

    try {
      process.env.INTERNAL_LLM_INFERENCE_URL = inferenceServer.url;
      process.env.INTERNAL_INFERENCE_AUTH_MODE = 'none';
      process.env.INTERNAL_INFERENCE_REQUIRED = 'true';

      await db.collection('users').doc(internalLearnerId).set({
        email: 'milo-internal-learner@example.com',
        displayName: 'Internal Milo Learner',
        role: 'learner',
        siteIds: [SITE_ID],
        activeSiteId: SITE_ID,
      });
      await db.collection('orchestrationStates').doc(`${internalLearnerId}-latest`).set({
        siteId: SITE_ID,
        learnerId: internalLearnerId,
        x_hat: { cognition: 0.78, engagement: 0.71, integrity: 0.94 },
        P: { trace: 0.12, confidence: 0.94 },
        lastUpdatedAt: admin.firestore.Timestamp.fromMillis(Date.now()),
      });

      const coachResult = await functionsModule.genAiCoach.run(callableRequest(
        internalLearnerId,
        {
          mode: 'explain',
          siteId: SITE_ID,
          gradeBand: 'G9_12',
          conceptTags: ['prototype tradeoffs'],
          studentInput: 'Help me explain our prototype tradeoff without giving me the final answer.',
        },
      ));

      expect(coachResult.message).toContain('prototype variable');
      expect(coachResult.message).not.toContain('MiloOS is not ready to give a reliable answer right now');
      expect(coachResult.requiresExplainBack).toBe(true);
      expect(coachResult.meta).toMatchObject({
        modelVersion: 'local-internal-llm-test-v1',
        traceId: 'internal-trace-1',
      });
      expect(coachResult.metadata).toMatchObject({
        safetyOutcome: 'allowed',
        safetyReasonCode: 'none',
        modelVersion: 'local-internal-llm-test-v1',
        policyVersion: 'internal-policy-test-v1',
      });

      expect(inferenceServer.requests).toHaveLength(1);
      expect(inferenceServer.requests[0].headers).toMatchObject({
        'x-caller-service': 'genAiCoach',
        'x-inference-service': 'llm',
        'x-site-id': SITE_ID,
        'x-role': 'learner',
      });
      expect(inferenceServer.requests[0].body).toMatchObject({
        role: 'learner',
        requesterRole: 'student',
        gradeBand: 'G9_12',
        coachMode: 'explain',
        conceptTags: ['prototype tradeoffs'],
        coppaBand: 'G9_12',
      });

      const openedEventId = coachResult.meta.aiHelpOpenedEventId as string;
      const explainResult = await functionsModule.submitExplainBack.run(callableRequest(
        internalLearnerId,
        {
          siteId: SITE_ID,
          interactionId: openedEventId,
          explainBack:
            'I can explain the tradeoff by changing one variable at a time, comparing the result, and naming why the choice supports our prototype goal.',
        },
      ));
      expect(explainResult).toMatchObject({ approved: true });

      const eventsSnap = await db.collection('interactionEvents')
        .where('siteId', '==', SITE_ID)
        .where('actorId', '==', internalLearnerId)
        .get();
      const events = eventsSnap.docs.map((doc) => doc.data() as Record<string, any>);
      expect(events).toEqual(expect.arrayContaining([
        expect.objectContaining({ eventType: 'ai_help_opened' }),
        expect.objectContaining({
          eventType: 'ai_help_used',
          payload: expect.objectContaining({
            traceId: 'internal-trace-1',
            policyVersion: 'internal-policy-test-v1',
            safetyOutcome: 'allowed',
            requiresExplainBack: true,
          }),
        }),
        expect.objectContaining({
          eventType: 'ai_coach_response',
          payload: expect.objectContaining({
            traceId: 'internal-trace-1',
            safetyOutcome: 'allowed',
            aiResponseText: expect.stringContaining('prototype variable'),
          }),
        }),
        expect.objectContaining({
          eventType: 'explain_it_back_submitted',
          payload: expect.objectContaining({
            aiHelpOpenedEventId: openedEventId,
            approved: true,
          }),
        }),
      ]));

      const insights = await functionsModule.bosGetLearnerLoopInsights.run(callableRequest(
        internalLearnerId,
        {
          siteId: SITE_ID,
          learnerId: internalLearnerId,
          lookbackDays: 30,
        },
      ));

      expect(insights.eventCounts).toMatchObject({
        ai_help_opened: 1,
        ai_help_used: 1,
        ai_coach_response: 1,
        explain_it_back_submitted: 1,
      });
      expect(insights.verification).toEqual({
        aiHelpOpened: 1,
        aiHelpUsed: 1,
        explainBackSubmitted: 1,
        pendingExplainBack: 0,
      });
    } finally {
      restoreEnvVar('INTERNAL_LLM_INFERENCE_URL', previousLlmUrl);
      restoreEnvVar('INTERNAL_INFERENCE_AUTH_MODE', previousAuthMode);
      restoreEnvVar('INTERNAL_INFERENCE_REQUIRED', previousRequired);
      await inferenceServer.close();
    }
  });
});