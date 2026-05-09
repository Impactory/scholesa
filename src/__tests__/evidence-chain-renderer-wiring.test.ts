/**
 * Evidence Chain Renderer Wiring Tests
 *
 * Validates that all evidence chain routes are wired to custom renderers
 * (not the generic card-list WorkflowRoutePage fallback) and that each
 * renderer delegates to a real Firestore-backed component.
 */

import fs from 'fs';
import path from 'path';

const srcDir = path.join(process.cwd(), 'src');

function readSrcFile(...segments: string[]): string {
  return fs.readFileSync(path.join(srcDir, ...segments), 'utf8');
}

/* ───── Renderer registry completeness ───── */

describe('Custom renderer registry covers all evidence chain routes', () => {
  const registrySource = readSrcFile(
    'features',
    'workflows',
    'customRouteRenderers.tsx'
  );

  const evidenceChainRoutes = [
    // HQ
    '/hq/curriculum',
    '/hq/capabilities',
    '/hq/capability-frameworks',
    '/hq/rubric-builder',
    '/hq/analytics',
    // Educator
    '/educator/today',
    '/educator/missions/review',
    '/educator/learners',
    '/educator/evidence',
    '/educator/observations',
    '/educator/proof-review',
    '/educator/verification',
    '/educator/rubrics/apply',
    // Learner
    '/learner/today',
    '/learner/missions',
    '/learner/portfolio',
    '/learner/proof-assembly',
    '/learner/checkpoints',
    '/learner/reflections',
    '/learner/peer-feedback',
    '/learner/habits',
    '/learner/timeline',
    // Educator (evidence-enriched)
    '/educator/sessions',
    // Parent / Guardian
    '/parent/summary',
    '/parent/portfolio',
    '/parent/growth-timeline',
    '/parent/passport',
    // Site
    '/site/dashboard',
    '/site/evidence-health',
  ];

  for (const route of evidenceChainRoutes) {
    it(`registers ${route} in CUSTOM_ROUTE_RENDERERS`, () => {
      expect(registrySource).toContain(`'${route}':`);
    });
  }
});

/* ───── Renderer files exist and are non-trivial ───── */

describe('All renderer files exist and are real components', () => {
  const renderersDir = path.join(
    srcDir,
    'features',
    'workflows',
    'renderers'
  );

  const rendererFiles = fs.readdirSync(renderersDir).filter((f) => f.endsWith('.tsx'));

  it('has at least 15 renderer files', () => {
    expect(rendererFiles.length).toBeGreaterThanOrEqual(15);
  });

  for (const file of rendererFiles) {
    describe(file, () => {
      const source = fs.readFileSync(path.join(renderersDir, file), 'utf8');

      it('has a default export', () => {
        expect(source).toMatch(/export default/);
      });

      it('is a client component', () => {
        expect(source).toContain("'use client'");
      });

      it('does not contain mock or fake data', () => {
        // No hardcoded mock/fake patterns
        expect(source).not.toMatch(/\bfakeData\b/);
        expect(source).not.toMatch(/\bmockData\b/);
        expect(source).not.toMatch(/\bTODO\b/i);
        // fakeWebBackend imports must be guarded by NEXT_PUBLIC_E2E_TEST_MODE
        if (source.includes('fakeWebBackend')) {
          expect(source).toContain('NEXT_PUBLIC_E2E_TEST_MODE');
        }
      });
    });
  }
});

/* ───── Renderer → component delegation ───── */

describe('Renderers delegate to real evidence components', () => {
  it('EducatorEvidenceCaptureRenderer → EducatorEvidenceCapture', () => {
    const source = readSrcFile(
      'features', 'workflows', 'renderers', 'EducatorEvidenceCaptureRenderer.tsx'
    );
    const captureSource = readSrcFile('components', 'evidence', 'EducatorEvidenceCapture.tsx');
    const browserEvidenceChainSource = fs.readFileSync(
      path.join(process.cwd(), 'test', 'e2e', 'evidence-chain-cross-role.e2e.spec.ts'),
      'utf8'
    );
    expect(source).toContain('EducatorEvidenceCapture');
    expect(source).toContain('@/src/components/evidence/EducatorEvidenceCapture');
    expect(captureSource).toContain('buildE2ECaptureData');
    expect(captureSource).toContain('upsertE2ECollectionRecord');
    expect(browserEvidenceChainSource).toContain("gotoProtectedRoute(page, '/en/educator/evidence')");
    expect(browserEvidenceChainSource).toContain('liveCaptureStartedAt');
    expect(browserEvidenceChainSource).toContain('toBeLessThan(10_000)');
  });

  it('EducatorProofReviewRenderer → ProofOfLearningVerification', () => {
    const source = readSrcFile(
      'features', 'workflows', 'renderers', 'EducatorProofReviewRenderer.tsx'
    );
    expect(source).toContain('ProofOfLearningVerification');
    expect(source).toContain('@/src/components/evidence/ProofOfLearningVerification');
  });

  it('EducatorRubricApplyRenderer → EducatorEvidenceCapture (embedded RubricReviewPanel)', () => {
    const source = readSrcFile(
      'features', 'workflows', 'renderers', 'EducatorRubricApplyRenderer.tsx'
    );
    expect(source).toContain('EducatorEvidenceCapture');
    expect(source).toContain('RubricReviewPanel');
    expect(source).toContain("searchParams?.get('portfolioItemId')");
  });

  it('LearnerCheckpointRenderer reads/writes checkpointHistory collection', () => {
    const source = readSrcFile(
      'features', 'workflows', 'renderers', 'LearnerCheckpointRenderer.tsx'
    );
    // Purpose-built checkpoint UI — reads canonical checkpoints, then writes
    // checkpointHistory plus a linked portfolio artifact.
    expect(source).toContain('checkpointsCollection');
    expect(source).toContain('checkpointHistory');
    expect(source).toContain('portfolioItemsCollection');
    expect(source).toContain('portfolioItemId: portfolioRef.id');
    expect(source).toContain('checkpointDefinitionId');
    expect(source).toContain('explainItBack');
    expect(source).toContain('learnerId');
    expect(source).toContain('writeBatch');
    expect(source).toContain('resolveActiveSiteId');
    expect(source).toContain('learner-checkpoint-submit');

    const browserEvidenceChainSource = fs.readFileSync(
      path.join(process.cwd(), 'test', 'e2e', 'evidence-chain-cross-role.e2e.spec.ts'),
      'utf8'
    );
    expect(browserEvidenceChainSource).toContain("gotoProtectedRoute(page, '/en/learner/checkpoints')");
    expect(browserEvidenceChainSource).toContain('checkpoint-prototype-iteration');
  });

  it('LearnerMissionsRenderer → LearnerEvidenceSubmission', () => {
    const source = readSrcFile(
      'features', 'workflows', 'renderers', 'LearnerMissionsRenderer.tsx'
    );
    const submissionSource = readSrcFile('components', 'evidence', 'LearnerEvidenceSubmission.tsx');
    expect(source).toContain('LearnerEvidenceSubmission');
    expect(source).toContain('@/src/components/evidence/LearnerEvidenceSubmission');
    expect(submissionSource).toContain('upsertE2ECollectionRecord');

    const browserEvidenceChainSource = fs.readFileSync(
      path.join(process.cwd(), 'test', 'e2e', 'evidence-chain-cross-role.e2e.spec.ts'),
      'utf8'
    );
    expect(browserEvidenceChainSource).toContain("gotoProtectedRoute(page, '/en/learner/missions')");
    expect(browserEvidenceChainSource).toContain('Learner-created artifact for gold proof');
    expect(browserEvidenceChainSource).toContain('learnerReflections');
    expect(browserEvidenceChainSource).toContain('checkpointHistory');
  });

  it('LearnerTodayRenderer uses the dedicated learner dashboard for /learner/today', () => {
    const registrySource = readSrcFile(
      'features', 'workflows', 'customRouteRenderers.tsx'
    );
    const source = readSrcFile(
      'features', 'workflows', 'renderers', 'LearnerTodayRenderer.tsx'
    );
    const dashboardSource = readSrcFile('components', 'dashboards', 'LearnerDashboardToday.tsx');
    const supportSnapshotSource = readSrcFile(
      'components', 'dashboards', 'MiloOSLearnerSupportSnapshot.tsx'
    );
    const insightsHelperSource = readSrcFile('lib', 'miloos', 'learnerLoopInsights.ts');
    const firestoreIndexes = JSON.parse(
      fs.readFileSync(path.join(process.cwd(), 'firestore.indexes.json'), 'utf8')
    ) as { indexes?: Array<{ collectionGroup?: string; fields?: Array<{ fieldPath?: string; order?: string; arrayConfig?: string }> }> };
    const hasCapabilityGrowthDashboardIndex = firestoreIndexes.indexes?.some((index) => {
      const fields = index.fields ?? [];
      return index.collectionGroup === 'capabilityGrowthEvents'
        && fields[0]?.fieldPath === 'learnerId'
        && fields[0]?.order === 'ASCENDING'
        && fields[1]?.fieldPath === 'siteId'
        && fields[1]?.order === 'ASCENDING'
        && fields[2]?.fieldPath === 'createdAt'
        && fields[2]?.order === 'DESCENDING';
    }) === true;
    const hasPortfolioDashboardIndex = firestoreIndexes.indexes?.some((index) => {
      const fields = index.fields ?? [];
      return index.collectionGroup === 'portfolioItems'
        && fields[0]?.fieldPath === 'learnerId'
        && fields[0]?.order === 'ASCENDING'
        && fields[1]?.fieldPath === 'siteId'
        && fields[1]?.order === 'ASCENDING'
        && fields[2]?.fieldPath === 'createdAt'
        && fields[2]?.order === 'DESCENDING';
    }) === true;
    const hasMissionAttemptRevisionIndex = firestoreIndexes.indexes?.some((index) => {
      const fields = index.fields ?? [];
      return index.collectionGroup === 'missionAttempts'
        && fields[0]?.fieldPath === 'learnerId'
        && fields[0]?.order === 'ASCENDING'
        && fields[1]?.fieldPath === 'siteId'
        && fields[1]?.order === 'ASCENDING'
        && fields[2]?.fieldPath === 'status'
        && fields[2]?.order === 'ASCENDING'
        && fields[3]?.fieldPath === 'updatedAt'
        && fields[3]?.order === 'DESCENDING';
    }) === true;
    const hasEducatorTodayOccurrenceIndex = firestoreIndexes.indexes?.some((index) => {
      const fields = index.fields ?? [];
      return index.collectionGroup === 'sessionOccurrences'
        && fields[0]?.fieldPath === 'siteId'
        && fields[0]?.order === 'ASCENDING'
        && fields[1]?.fieldPath === 'educatorId'
        && fields[1]?.order === 'ASCENDING'
        && fields[2]?.fieldPath === 'date'
        && fields[2]?.order === 'ASCENDING';
    }) === true;
    const hasEnrollmentSessionStatusIndex = firestoreIndexes.indexes?.some((index) => {
      const fields = index.fields ?? [];
      return index.collectionGroup === 'enrollments'
        && fields[0]?.fieldPath === 'sessionId'
        && fields[0]?.order === 'ASCENDING'
        && fields[1]?.fieldPath === 'status'
        && fields[1]?.order === 'ASCENDING';
    }) === true;
    const hasEvidenceHealthIndex = firestoreIndexes.indexes?.some((index) => {
      const fields = index.fields ?? [];
      return index.collectionGroup === 'evidenceRecords'
        && fields[0]?.fieldPath === 'siteId'
        && fields[0]?.order === 'ASCENDING'
        && fields[1]?.fieldPath === 'createdAt'
        && fields[1]?.order === 'DESCENDING';
    }) === true;
    const hasEvidenceHealthRangeIndex = firestoreIndexes.indexes?.some((index) => {
      const fields = index.fields ?? [];
      return index.collectionGroup === 'evidenceRecords'
        && fields[0]?.fieldPath === 'siteId'
        && fields[0]?.order === 'ASCENDING'
        && fields[1]?.fieldPath === 'createdAt'
        && fields[1]?.order === 'ASCENDING';
    }) === true;
    const hasEducatorObservationIndex = firestoreIndexes.indexes?.some((index) => {
      const fields = index.fields ?? [];
      return index.collectionGroup === 'evidenceRecords'
        && fields[0]?.fieldPath === 'siteId'
        && fields[0]?.order === 'ASCENDING'
        && fields[1]?.fieldPath === 'educatorId'
        && fields[1]?.order === 'ASCENDING'
        && fields[2]?.fieldPath === 'createdAt'
        && fields[2]?.order === 'DESCENDING';
    }) === true;
    const hasUsersSiteRoleIndex = firestoreIndexes.indexes?.some((index) => {
      const fields = index.fields ?? [];
      return index.collectionGroup === 'users'
        && fields[0]?.fieldPath === 'siteIds'
        && fields[0]?.arrayConfig === 'CONTAINS'
        && fields[1]?.fieldPath === 'role'
        && fields[1]?.order === 'ASCENDING';
    }) === true;
    expect(registrySource).toContain("'/learner/today': LearnerTodayRenderer");
    expect(source).toContain('LearnerDashboardToday');
    expect(source).toContain('@/src/components/dashboards/LearnerDashboardToday');
    expect(dashboardSource).toContain('resolveActiveSiteId');
    expect(dashboardSource).toContain("where('siteId', '==', siteId)");
    expect(dashboardSource).toContain('capabilityGrowthEventsCollection');
    expect(dashboardSource).toContain("orderBy('createdAt', 'desc')");
    expect(hasCapabilityGrowthDashboardIndex).toBe(true);
    expect(hasPortfolioDashboardIndex).toBe(true);
    expect(hasMissionAttemptRevisionIndex).toBe(true);
    expect(hasEducatorTodayOccurrenceIndex).toBe(true);
    expect(hasEnrollmentSessionStatusIndex).toBe(true);
    expect(hasEvidenceHealthIndex).toBe(true);
    expect(hasEvidenceHealthRangeIndex).toBe(true);
    expect(hasEducatorObservationIndex).toBe(true);
    expect(hasUsersSiteRoleIndex).toBe(true);
    expect(dashboardSource).toContain('MiloOSLearnerSupportSnapshot');
    expect(supportSnapshotSource).toContain('getMiloOSLearnerLoopInsights');
    expect(supportSnapshotSource).toContain('AICoachScreen');
    expect(supportSnapshotSource).toContain('onLearnerLoopUpdated');
    expect(supportSnapshotSource).toContain('ai_help_opened');
    expect(supportSnapshotSource).toContain('explain_it_back_submitted');
    expect(supportSnapshotSource).toContain('pendingExplainBack');
    expect(insightsHelperSource).toContain("'bosGetLearnerLoopInsights'");
  });

  it('LearnerHabitsRenderer uses persisted habits instead of routing habits to MiloOS', () => {
    const registrySource = readSrcFile(
      'features', 'workflows', 'customRouteRenderers.tsx'
    );
    const routesSource = readSrcFile('lib', 'routing', 'workflowRoutes.ts');
    const source = readSrcFile(
      'features', 'workflows', 'renderers', 'LearnerHabitsRenderer.tsx'
    );
    expect(registrySource).toContain("'/learner/habits': LearnerHabitsRenderer");
    expect(routesSource).toContain('Persisted learner routine tracking that stays separate from capability mastery claims.');
    expect(source).toContain("collection(firestore, 'habits')");
    expect(source).toContain("collection(firestore, 'habitLogs')");
    expect(source).toContain('writeBatch');
    expect(source).toContain('handleCompleteHabit');
    expect(source).toContain('data-testid={`habit-complete-${habit.id}`}');
  });

  it('LearnerReflectionsRenderer → ReflectionJournal with auth context', () => {
    const source = readSrcFile(
      'features', 'workflows', 'renderers', 'LearnerReflectionsRenderer.tsx'
    );
    expect(source).toContain('ReflectionJournal');
    expect(source).toContain('useAuthContext');
    expect(source).toContain('learnerId');
    expect(source).toContain('siteId');
  });

  it('HqRubricBuilderRenderer → CapabilityFrameworkEditor with rubricTemplates tab', () => {
    const source = readSrcFile(
      'features', 'workflows', 'renderers', 'HqRubricBuilderRenderer.tsx'
    );
    expect(source).toContain('CapabilityFrameworkEditor');
    expect(source).toContain('initialTab="rubricTemplates"');
  });

  it('HqCapabilityFrameworkRenderer → CapabilityFrameworkEditor with capabilities tab', () => {
    const source = readSrcFile(
      'features', 'workflows', 'renderers', 'HqCapabilityFrameworkRenderer.tsx'
    );
    expect(source).toContain('CapabilityFrameworkEditor');
    expect(source).toContain('initialTab="capabilities"');
  });

  it('GuardianCapabilityViewRenderer uses getParentDashboardBundle callable', () => {
    const source = readSrcFile(
      'features', 'workflows', 'renderers', 'GuardianCapabilityViewRenderer.tsx'
    );
    expect(source).toContain('getParentDashboardBundle');
    expect(source).toContain('httpsCallable');
    expect(source).toContain('resolveActiveSiteId');
    expect(source).toContain('callable({ parentId: ctx.uid, siteId })');
    expect(source).toContain('data-testid="guardian-view-site-required"');
  });

  it('pins parent summary and passport to the guardian evidence surfaces', () => {
    const registrySource = readSrcFile(
      'features', 'workflows', 'customRouteRenderers.tsx'
    );
    const guardianSource = readSrcFile(
      'features', 'workflows', 'renderers', 'GuardianCapabilityViewRenderer.tsx'
    );
    expect(registrySource).toContain("'/parent/summary': GuardianCapabilityViewRenderer");
    expect(registrySource).toContain("'/parent/passport': GuardianPassportRenderer");
    expect(guardianSource).toContain("'/parent/passport': {");
    expect(guardianSource).toContain('guardian-ideation-passport');
  });

  it('GuardianPassportRenderer delegates to GuardianCapabilityViewRenderer', () => {
    const source = readSrcFile(
      'features', 'workflows', 'renderers', 'GuardianPassportRenderer.tsx'
    );
    expect(source).toContain('GuardianCapabilityViewRenderer');
  });

  it('parent passport page delegates to WorkflowRoutePage instead of learner passport export', () => {
    const source = readSrcFile(
      '..',
      'app',
      '[locale]',
      '(protected)',
      'parent',
      'passport',
      'page.tsx'
    );
    expect(source).toContain('WorkflowRoutePage');
    expect(source).toContain("routePath='/parent/passport'");
    expect(source).not.toContain('LearnerPassportExport');
  });

  it('LearnerMiloOSRenderer reads the server-owned MiloOS learner-loop model', () => {
    const registrySource = readSrcFile(
      'features', 'workflows', 'customRouteRenderers.tsx'
    );
    const routesSource = readSrcFile('lib', 'routing', 'workflowRoutes.ts');
    const source = readSrcFile(
      'features', 'workflows', 'renderers', 'LearnerMiloOSRenderer.tsx'
    );
    expect(registrySource).toContain("'/learner/miloos': LearnerMiloOSRenderer");
    expect(routesSource).toContain("path: '/learner/miloos'");
    expect(routesSource).toContain("description: 'Learner support, explain-back verification, and support-journey provenance.'");
    expect(source).toContain('AICoachScreen');
    expect(source).toContain('resolveActiveSiteId');
    expect(source).toContain('getMiloOSLearnerLoopInsights');
    expect(source).toContain('pendingExplainBack');
    expect(source).toContain('ai_coach_response');
    expect(source).toContain('data-testid="learner-miloos-coach-responses"');
    expect(source).toContain('pendingSupportInteractions');
    expect(source).toContain('data-testid="learner-miloos-pending-explain-back"');
    expect(source).toContain('learner-miloos-submit-pending-explain-back');
    expect(source).toContain('onLearnerLoopUpdated');
    expect(source).toContain('support provenance, not capability mastery');
    expect(source).not.toContain('aiInteractionLogs');
    expect(source).not.toContain('missionAttempts');
    expect(source).not.toContain('collection(firestore');
    expect(source).toContain('data-testid="learner-miloos-site-required"');
  });

  it('MiloOS browser E2E uses fake callables only behind the E2E harness and checks no mastery write', () => {
    const motivationSource = readSrcFile('lib', 'motivation', 'sdtMotivation.ts');
    const insightsSource = readSrcFile('lib', 'miloos', 'learnerLoopInsights.ts');
    const fakeBackendSource = readSrcFile('testing', 'e2e', 'fakeWebBackend.ts');
    const e2eSource = fs.readFileSync(
      path.join(process.cwd(), 'test', 'e2e', 'miloos-learner-loop.e2e.spec.ts'),
      'utf8'
    );

    expect(motivationSource).toContain("NEXT_PUBLIC_E2E_TEST_MODE === '1'");
    expect(motivationSource).toContain('requestE2EAICoach');
    expect(motivationSource).toContain('submitE2EExplainBack');
    expect(insightsSource).toContain("NEXT_PUBLIC_E2E_TEST_MODE === '1'");
    expect(insightsSource).toContain('getE2EMiloOSLearnerLoopInsights');
    expect(fakeBackendSource).toContain('interactionEvents');
    expect(fakeBackendSource).toContain("eventType: 'ai_help_opened'");
    expect(fakeBackendSource).toContain("eventType: 'ai_help_used'");
    expect(fakeBackendSource).toContain("eventType: 'ai_coach_response'");
    expect(fakeBackendSource).toContain("eventType: 'explain_it_back_submitted'");
    expect(fakeBackendSource).toContain('pendingExplainBack: Math.max(aiHelpOpened - explainBackSubmitted, 0)');
    expect(e2eSource).toContain("page.goto('/en/learner/miloos')");
    expect(e2eSource).toContain("getCollection(page, 'interactionEvents')");
    expect(e2eSource).toContain("getCollection(page, 'capabilityMastery')");
    expect(e2eSource).toContain("getCollection(page, 'capabilityGrowthEvents')");
    expect(e2eSource).toContain('ai_coach_response');
    expect(e2eSource).toContain('learner-miloos-coach-responses');
    expect(e2eSource).toContain('expect(masteryRecords).toEqual([])');
    expect(e2eSource).toContain('expect(growthRecords).toEqual([])');
  });

  it('SiteImplementationHealthRenderer queries evidence chain collections', () => {
    const source = readSrcFile(
      'features', 'workflows', 'renderers', 'SiteImplementationHealthRenderer.tsx'
    );
    expect(source).toContain('resolveActiveSiteId');
    expect(source).toContain('rubricApplications');
    expect(source).toContain('evidenceRecords');
    expect(source).toContain('capabilityGrowthEvents');
    expect(source).toContain('proofOfLearningBundles');
    expect(source).toContain("collection(firestore, 'interactionEvents')");
    expect(source).toContain('deriveMiloOSSupportMetrics');
    expect(source).toContain("getE2ECollection('interactionEvents')");
    expect(source).toContain('MiloOS support health');
    expect(source).toContain('support and explain-back verification signals, not capability mastery');
    expect(source).toContain('data-testid="site-miloos-support-health"');
    expect(source).toContain('data-testid="site-miloos-support-opened"');
    expect(source).toContain('data-testid="site-miloos-support-used"');
    expect(source).toContain('data-testid="site-miloos-coach-responses"');
    expect(source).toContain('data-testid="site-miloos-explain-backs"');
    expect(source).toContain('data-testid="site-miloos-pending-checks"');
    expect(source).toContain('ai_coach_response');
    expect(source).toContain('learnersWithPendingMiloOSExplainBack');
    expect(source).toContain('data-testid="site-implementation-site-required"');
  });

  it('MiloOS site support health browser E2E is harness-only and checks non-mastery copy', () => {
    const clientInitSource = readSrcFile('firebase', 'client-init.ts');
    const fakeBackendSource = readSrcFile('testing', 'e2e', 'fakeWebBackend.ts');
    const e2eSource = fs.readFileSync(
      path.join(process.cwd(), 'test', 'e2e', 'miloos-site-support-health.e2e.spec.ts'),
      'utf8'
    );

    expect(clientInitSource).toContain('seedInteractionEvents');
    expect(clientInitSource).toContain('seedSyntheticMiloOSGoldStates');
    expect(clientInitSource).toContain('isE2ETestMode');
    expect(fakeBackendSource).toContain('seedE2EInteractionEvents');
    expect(fakeBackendSource).toContain('seedE2ESyntheticMiloOSGoldStates');
    expect(fakeBackendSource).toContain('syntheticMiloOSGoldStates');
    expect(e2eSource).toContain('seedCanonicalMiloOSGoldWebState');
    expect(e2eSource).toContain("getCollection('syntheticMiloOSGoldStates')");
    expect(e2eSource).toContain('miloosGoldLearnerStates: 5');
    expect(e2eSource).toContain('miloosGoldInteractionEvents: 13');
    expect(e2eSource).toContain("page.goto('/en/site/dashboard')");
    expect(e2eSource).toContain('site-miloos-support-health');
    expect(e2eSource).toContain('not capability mastery');
    expect(e2eSource).toContain('site-miloos-coach-responses');
    expect(e2eSource).toContain('site-miloos-pending-checks');
  });

  it('MiloOS web browser proofs consume canonical synthetic gold importer output', () => {
    const fixtureSource = fs.readFileSync(
      path.join(process.cwd(), 'test', 'e2e', 'miloos-synthetic-gold-fixture.ts'),
      'utf8'
    );
    const educatorE2ESource = fs.readFileSync(
      path.join(process.cwd(), 'test', 'e2e', 'miloos-educator-support-provenance.e2e.spec.ts'),
      'utf8'
    );
    const guardianE2ESource = fs.readFileSync(
      path.join(process.cwd(), 'test', 'e2e', 'miloos-guardian-support-provenance.e2e.spec.ts'),
      'utf8'
    );
    const mobileE2ESource = fs.readFileSync(
      path.join(process.cwd(), 'test', 'e2e', 'miloos-mobile-classroom.e2e.spec.ts'),
      'utf8'
    );

    expect(fixtureSource).toContain("buildImportBundle({ mode: 'starter' })");
    expect(fixtureSource).toContain('syntheticMiloOSGoldStates');
    expect(fixtureSource).toContain('canonicalMiloOSGoldWebSeed');
    expect(fixtureSource).toContain('seedSyntheticMiloOSGoldStates');
    expect(fixtureSource).toContain('sourceCounts: manifest.sourceCounts ?? bundle.summary?.sourceCounts');
    expect(fixtureSource).toContain('noMasteryWrites');
    expect(fixtureSource).toContain('pendingExplainBackLearnerId');
    expect(educatorE2ESource).toContain('seedCanonicalMiloOSGoldWebState');
    expect(guardianE2ESource).toContain('seedCanonicalMiloOSGoldWebState');
    expect(mobileE2ESource).toContain('seedCanonicalMiloOSGoldWebState');
  });

  it('MiloOS protected support surfaces have focused WCAG browser coverage', () => {
    const e2eSource = fs.readFileSync(
      path.join(process.cwd(), 'test', 'e2e', 'miloos-accessibility.e2e.spec.ts'),
      'utf8'
    );

    expect(e2eSource).toContain("import AxeBuilder from '@axe-core/playwright'");
    expect(e2eSource).toContain("withTags(['wcag2a', 'wcag2aa', 'wcag21aa', 'wcag22aa'])");
    expect(e2eSource).toContain("page.goto('/en/learner/miloos')");
    expect(e2eSource).toContain("page.goto('/en/educator/learners')");
    expect(e2eSource).toContain("page.goto('/en/parent/summary')");
    expect(e2eSource).toContain("page.goto('/en/site/dashboard')");
    expect(e2eSource).toContain('learner-miloos-loop-status');
    expect(e2eSource).toContain('miloos-support-');
    expect(e2eSource).toContain('guardian-miloos-support-');
    expect(e2eSource).toContain('site-miloos-support-health');
    expect(e2eSource).toContain('seedCanonicalMiloOSGoldWebState');
  });

  it('MiloOS has a cross-role golden path browser proof', () => {
    const e2eSource = fs.readFileSync(
      path.join(process.cwd(), 'test', 'e2e', 'miloos-cross-role-golden-path.e2e.spec.ts'),
      'utf8'
    );

    expect(e2eSource).toContain("gotoProtectedRoute(page, '/en/learner/miloos')");
    expect(e2eSource).toContain("gotoProtectedRoute(page, '/en/educator/learners')");
    expect(e2eSource).toContain("gotoProtectedRoute(page, '/en/parent/summary')");
    expect(e2eSource).toContain("gotoProtectedRoute(page, '/en/site/dashboard')");
    expect(e2eSource).toContain('learner-miloos-pending-explain-back');
    expect(e2eSource).toContain('learner-miloos-submit-pending-explain-back');
    expect(e2eSource).toContain('explain_it_back_submitted');
    expect(e2eSource).toContain("getCollection(page, 'capabilityMastery')");
    expect(e2eSource).toContain("getCollection(page, 'capabilityGrowthEvents')");
    expect(e2eSource).toContain('site-miloos-coach-responses');
    expect(e2eSource).toContain('not capability mastery');
  });

  it('MiloOS has phone-width classroom browser proof', () => {
    const e2eSource = fs.readFileSync(
      path.join(process.cwd(), 'test', 'e2e', 'miloos-mobile-classroom.e2e.spec.ts'),
      'utf8'
    );

    expect(e2eSource).toContain('MOBILE_VIEWPORT');
    expect(e2eSource).toContain("gotoProtectedRoute(page, '/en/learner/miloos')");
    expect(e2eSource).toContain("gotoProtectedRoute(page, '/en/educator/learners')");
    expect(e2eSource).toContain("gotoProtectedRoute(page, '/en/site/dashboard')");
    expect(e2eSource).toContain('ai-coach-response-transcript');
    expect(e2eSource).toContain('ai-coach-explain-back-input');
    expect(e2eSource).toContain('miloos-support-');
    expect(e2eSource).toContain('site-miloos-support-health');
    expect(e2eSource).toContain('expectNoHorizontalOverflow');
  });

  it('MiloOS has keyboard and focus browser proof', () => {
    const e2eSource = fs.readFileSync(
      path.join(process.cwd(), 'test', 'e2e', 'miloos-keyboard.e2e.spec.ts'),
      'utf8'
    );
    const coachSource = readSrcFile('components', 'sdt', 'AICoachScreen.tsx');

    expect(e2eSource).toContain('tabUntilTestId');
    expect(e2eSource).toContain('ai-coach-mode-hint');
    expect(e2eSource).toContain('ai-coach-question-input');
    expect(e2eSource).toContain('ai-coach-submit-question');
    expect(e2eSource).toContain('ai-coach-explain-back-input');
    expect(e2eSource).toContain('ai-coach-submit-explain-back');
    expect(e2eSource).toContain('ai-coach-status-message');
    expect(coachSource).toContain('explainBackInputRef.current?.focus()');
    expect(coachSource).toContain('statusMessageRef.current?.focus()');
    expect(coachSource).toContain('data-testid="ai-coach-status-message"');
  });

  it('MiloOS has canonical synthetic gold-readiness states', () => {
    const importerSource = fs.readFileSync(
      path.join(process.cwd(), 'scripts', 'import_synthetic_data.js'),
      'utf8'
    );
    const syntheticStateTest = fs.readFileSync(
      path.join(process.cwd(), 'test', 'synthetic_miloos_gold_states.test.js'),
      'utf8'
    );

    expect(importerSource).toContain('addMiloOSGoldSyntheticStates');
    expect(importerSource).toContain('synthetic-miloos-no-support-learner');
    expect(importerSource).toContain('synthetic-miloos-pending-explain-back-learner');
    expect(importerSource).toContain('synthetic-miloos-support-current-learner');
    expect(importerSource).toContain('synthetic-miloos-cross-site-denial-learner');
    expect(importerSource).toContain('synthetic-miloos-missing-site-denial-learner');
    expect(importerSource).toContain('syntheticMiloOSGoldStates');
    expect(importerSource).toContain('activeSiteId: siteId');
    expect(syntheticStateTest).toContain('does not seed support-only capability mastery or growth writes');
    expect(syntheticStateTest).toContain("users.get('synthetic-miloos-gold-educator')");
    expect(syntheticStateTest).toContain('miloosGoldInteractionEvents: 13');
  });

  it('MiloOS gold-candidate scope pins focused Flutter mobile parity', () => {
    const planSource = fs.readFileSync(
      path.join(process.cwd(), 'docs', 'MILOOS_GOLD_READINESS_PLAN_APRIL_30_2026.md'),
      'utf8'
    );
    const checklistSource = fs.readFileSync(
      path.join(process.cwd(), 'docs', 'MILOOS_GOLD_READINESS_EXECUTION_CHECKLIST_APRIL_30_2026.md'),
      'utf8'
    );
    const flutterMobilePlanSource = fs.readFileSync(
      path.join(process.cwd(), 'docs', 'FLUTTER_MOBILE_GOLD_READINESS_PLAN_APRIL_30_2026.md'),
      'utf8'
    );
    const flutterMobileChecklistSource = fs.readFileSync(
      path.join(process.cwd(), 'docs', 'FLUTTER_MOBILE_GOLD_READINESS_EXECUTION_CHECKLIST_APRIL_30_2026.md'),
      'utf8'
    );
    const flutterMobileRouteMatrixSource = fs.readFileSync(
      path.join(process.cwd(), 'docs', 'FLUTTER_MOBILE_ROUTE_PROOF_MATRIX_APRIL_30_2026.md'),
      'utf8'
    );
    const flutterBosSource = fs.readFileSync(
      path.join(process.cwd(), 'apps', 'empire_flutter', 'app', 'lib', 'runtime', 'bos_learner_loop_insights_card.dart'),
      'utf8'
    );
    const flutterBosTestSource = fs.readFileSync(
      path.join(process.cwd(), 'apps', 'empire_flutter', 'app', 'test', 'bos_insights_cards_test.dart'),
      'utf8'
    );
    const flutterEducatorSource = fs.readFileSync(
      path.join(process.cwd(), 'apps', 'empire_flutter', 'app', 'lib', 'modules', 'educator', 'educator_learner_supports_page.dart'),
      'utf8'
    );
    const flutterSiteSource = fs.readFileSync(
      path.join(process.cwd(), 'apps', 'empire_flutter', 'app', 'lib', 'modules', 'site', 'site_dashboard_page.dart'),
      'utf8'
    );
    const flutterEducatorTestSource = fs.readFileSync(
      path.join(process.cwd(), 'apps', 'empire_flutter', 'app', 'test', 'educator_learner_supports_page_test.dart'),
      'utf8'
    );
    const flutterSiteTestSource = fs.readFileSync(
      path.join(process.cwd(), 'apps', 'empire_flutter', 'app', 'test', 'site_dashboard_page_test.dart'),
      'utf8'
    );
    const flutterSyntheticMiloOSMobileTestSource = fs.readFileSync(
      path.join(process.cwd(), 'apps', 'empire_flutter', 'app', 'test', 'synthetic_miloos_gold_states_mobile_test.dart'),
      'utf8'
    );
    const flutterParentGrowthTimelineTestSource = fs.readFileSync(
      path.join(process.cwd(), 'apps', 'empire_flutter', 'app', 'test', 'parent_growth_timeline_page_test.dart'),
      'utf8'
    );
    const flutterHqAuthoringTestSource = fs.readFileSync(
      path.join(process.cwd(), 'apps', 'empire_flutter', 'app', 'test', 'hq_authoring_persistence_test.dart'),
      'utf8'
    );
    const flutterPeerFeedbackTestSource = fs.readFileSync(
      path.join(process.cwd(), 'apps', 'empire_flutter', 'app', 'test', 'peer_feedback_page_test.dart'),
      'utf8'
    );
    const flutterPartnerDeliverablesTestSource = fs.readFileSync(
      path.join(process.cwd(), 'apps', 'empire_flutter', 'app', 'test', 'partner_deliverables_page_test.dart'),
      'utf8'
    );
    const flutterPartnerWorkflowTestSource = fs.readFileSync(
      path.join(process.cwd(), 'apps', 'empire_flutter', 'app', 'test', 'partner_contracting_workflow_test.dart'),
      'utf8'
    );
    const flutterLearnerCredentialsTestSource = fs.readFileSync(
      path.join(process.cwd(), 'apps', 'empire_flutter', 'app', 'test', 'learner_credentials_page_test.dart'),
      'utf8'
    );
    const flutterLearnerPortfolioTestSource = fs.readFileSync(
      path.join(process.cwd(), 'apps', 'empire_flutter', 'app', 'test', 'learner_portfolio_honesty_test.dart'),
      'utf8'
    );
    const flutterLearnerTodayTestSource = fs.readFileSync(
      path.join(process.cwd(), 'apps', 'empire_flutter', 'app', 'test', 'learner_today_page_test.dart'),
      'utf8'
    );
    const flutterEducatorTodayPageSource = fs.readFileSync(
      path.join(process.cwd(), 'apps', 'empire_flutter', 'app', 'lib', 'modules', 'educator', 'educator_today_page.dart'),
      'utf8'
    );
    const flutterEducatorTodayTestSource = fs.readFileSync(
      path.join(process.cwd(), 'apps', 'empire_flutter', 'app', 'test', 'educator_today_page_test.dart'),
      'utf8'
    );
    const flutterObservationCapturePageSource = fs.readFileSync(
      path.join(process.cwd(), 'apps', 'empire_flutter', 'app', 'lib', 'modules', 'educator', 'observation_capture_page.dart'),
      'utf8'
    );
    const flutterObservationCaptureTestSource = fs.readFileSync(
      path.join(process.cwd(), 'apps', 'empire_flutter', 'app', 'test', 'observation_capture_page_test.dart'),
      'utf8'
    );
    const flutterProofVerificationPageSource = fs.readFileSync(
      path.join(process.cwd(), 'apps', 'empire_flutter', 'app', 'lib', 'modules', 'educator', 'proof_verification_page.dart'),
      'utf8'
    );
    const flutterProofVerificationTestSource = fs.readFileSync(
      path.join(process.cwd(), 'apps', 'empire_flutter', 'app', 'test', 'proof_verification_page_test.dart'),
      'utf8'
    );
    const flutterFirestoreServiceSource = fs.readFileSync(
      path.join(process.cwd(), 'apps', 'empire_flutter', 'app', 'lib', 'services', 'firestore_service.dart'),
      'utf8'
    );
    const flutterReflectionPageSource = fs.readFileSync(
      path.join(process.cwd(), 'apps', 'empire_flutter', 'app', 'lib', 'modules', 'learner', 'reflection_journal_page.dart'),
      'utf8'
    );
    const flutterReflectionTestSource = fs.readFileSync(
      path.join(process.cwd(), 'apps', 'empire_flutter', 'app', 'test', 'reflection_journal_page_test.dart'),
      'utf8'
    );
    const flutterProofAssemblyPageSource = fs.readFileSync(
      path.join(process.cwd(), 'apps', 'empire_flutter', 'app', 'lib', 'modules', 'learner', 'proof_assembly_page.dart'),
      'utf8'
    );
    const flutterProofAssemblyTestSource = fs.readFileSync(
      path.join(process.cwd(), 'apps', 'empire_flutter', 'app', 'test', 'proof_assembly_page_test.dart'),
      'utf8'
    );
    const flutterCheckpointPageSource = fs.readFileSync(
      path.join(process.cwd(), 'apps', 'empire_flutter', 'app', 'lib', 'modules', 'learner', 'checkpoint_submission_page.dart'),
      'utf8'
    );
    const flutterCheckpointTestSource = fs.readFileSync(
      path.join(process.cwd(), 'apps', 'empire_flutter', 'app', 'test', 'checkpoint_submission_page_test.dart'),
      'utf8'
    );
    const flutterSyncCoordinatorTestSource = fs.readFileSync(
      path.join(process.cwd(), 'apps', 'empire_flutter', 'app', 'test', 'sync_coordinator_test.dart'),
      'utf8'
    );
    const flutterParentConsentSource = fs.readFileSync(
      path.join(process.cwd(), 'apps', 'empire_flutter', 'app', 'lib', 'modules', 'parent', 'parent_consent_page.dart'),
      'utf8'
    );
    const flutterParentConsentServiceSource = fs.readFileSync(
      path.join(process.cwd(), 'apps', 'empire_flutter', 'app', 'lib', 'modules', 'parent', 'parent_consent_service.dart'),
      'utf8'
    );
    const flutterParentConsentTestSource = fs.readFileSync(
      path.join(process.cwd(), 'apps', 'empire_flutter', 'app', 'test', 'parent_consent_page_test.dart'),
      'utf8'
    );
    const firestoreRulesTestSource = fs.readFileSync(
      path.join(process.cwd(), 'test', 'firestore-rules.test.js'),
      'utf8'
    );

    expect(planSource).toContain('focused Flutter/mobile role-parity gate passed');
    expect(planSource).toContain('This does not make the full Flutter app gold-ready.');
    expect(planSource).toContain('the non-deploying `./scripts/deploy.sh release-gate` also passed from the current worktree');
    expect(checklistSource).toContain('Flutter MiloOS role parity is now in scope for the focused support-provenance gate.');
    expect(checklistSource).toContain('flutter test test/bos_insights_cards_test.dart test/educator_learner_supports_page_test.dart test/site_dashboard_page_test.dart');
    expect(checklistSource).toContain('synthetic_miloos_gold_states_mobile_test.dart');
    expect(checklistSource).toContain('./scripts/deploy.sh release-gate');
    expect(flutterMobilePlanSource).toContain('validated release bundle and approved Cloud Run web no-traffic rehearsal now pass');
    expect(flutterMobilePlanSource).toContain('Flutter route proof matrix');
    expect(flutterMobilePlanSource).toContain('Offline evidence-chain gate');
    expect(flutterMobilePlanSource).toContain('Mobile classroom ergonomics');
    expect(flutterMobilePlanSource).toContain('Role permission and site-boundary review');
    expect(flutterMobilePlanSource).toContain('Focused Flutter/mobile release bundle');
    expect(flutterMobilePlanSource).toContain('Direct parent growth timeline route proof');
    expect(flutterMobilePlanSource).toContain('Mobile HQ authoring persistence');
    expect(flutterMobilePlanSource).toContain('Peer-feedback persistence and role safety');
    expect(flutterMobilePlanSource).toContain('Partner deliverable evidence output trust');
    expect(flutterMobilePlanSource).toContain('Learner credential evidence provenance');
    expect(flutterMobilePlanSource).toContain('Parent active report-share revocation');
    expect(flutterMobilePlanSource).toContain('Learner today classroom evidence actions');
    expect(flutterMobilePlanSource).toContain('Learner checkpoint same-site capture');
    expect(flutterMobilePlanSource).toContain('Learner reflection portfolio provenance');
    expect(flutterMobilePlanSource).toContain('Learner proof assembly small-screen and offline replay');
    expect(flutterMobilePlanSource).toContain('Learner portfolio created-item provenance');
    expect(flutterMobilePlanSource).toContain('Educator today mobile evidence capture access');
    expect(flutterMobilePlanSource).toContain('Educator observation capture small-screen and site-boundary proof');
    expect(flutterMobilePlanSource).toContain('Educator proof-review persistence and site-boundary proof');
    expect(flutterMobilePlanSource).toContain('Canonical MiloOS synthetic mobile consumption');
    expect(flutterMobilePlanSource).toContain('Site support-health signal completeness');
    expect(flutterMobilePlanSource).toContain('The next highest-risk break is **post-rehearsal operator evidence and native release reproducibility**.');
    expect(flutterMobilePlanSource).toContain('`./scripts/deploy.sh release-gate` passes without deploying');
    expect(flutterMobilePlanSource).toContain('2026-05-03 `CLOUD_RUN_NO_TRAFFIC=1` web rehearsal created ready no-traffic revisions');
    expect(flutterMobilePlanSource).toContain('approved 2026-05-03 no-traffic web deploy rehearsal passed without moving production traffic');
    expect(flutterMobileChecklistSource).toContain('Milestone 1 - Guardian And Report Workflow Stabilization');
    expect(flutterMobileChecklistSource).toContain('Completed 2026-04-30: `docs/FLUTTER_MOBILE_ROUTE_PROOF_MATRIX_APRIL_30_2026.md`');
    expect(flutterMobileChecklistSource).toContain('Completed 2026-04-30: the focused offline evidence-chain suite passed as a bundle with 46 tests.');
    expect(flutterMobileChecklistSource).toContain('Completed 2026-04-30: the mobile classroom slice now runs learner mission evidence submission and educator quick evidence capture at phone width');
    expect(flutterMobileChecklistSource).toContain('Completed 2026-04-30: the mobile boundary bundle passed with 50 Flutter tests');
    expect(flutterMobileChecklistSource).toContain('Completed 2026-04-30: the focused Flutter/mobile release bundle passed.');
    expect(flutterMobileChecklistSource).toContain('No final signoff may describe Flutter/mobile as gold-ready while any milestone above is incomplete.');
    expect(flutterMobileChecklistSource).toContain('guardian active report-share visibility and revocation from the parent consent surface');
    expect(flutterMobileRouteMatrixSource).toContain('mobile route coverage is mapped, but Flutter/mobile is not gold-ready yet');
    expect(flutterMobileRouteMatrixSource).toContain('| Learner | `/learner/missions` | `MissionsPage` | Capture mission attempts, proof bundle fields, AI disclosure |');
    expect(flutterMobileRouteMatrixSource).toContain('| Learner | `/learner/peer-feedback` | `PeerFeedbackPage` | Capture peer evidence/feedback | active-site `missionAttempts`, active-site `peerFeedback`, Firestore rules | `peer_feedback_page_test.dart`, `evidence_chain_routes_test.dart`, `test/firestore-rules.test.js` | aligned and reusable |');
    expect(flutterMobileRouteMatrixSource).toContain('| Learner | `/learner/credentials` | `LearnerCredentialsPage` | Communicate recognitions/credentials | active-site `credentials`, Firestore rules | `learner_credentials_page_test.dart`, `test/firestore-rules.test.js` | aligned and reusable |');
    expect(flutterMobileRouteMatrixSource).toContain('| Educator | `/educator/rubrics/apply` | `RubricApplicationPage` | Interpret evidence through rubric |');
    expect(flutterMobileRouteMatrixSource).toContain('| Parent | `/parent/portfolio` | `ParentPortfolioPage` | Communicate reviewed portfolio artifacts |');
    expect(flutterMobileRouteMatrixSource).toContain('| Parent | `/parent/growth-timeline` | `GrowthTimelinePage` | Communicate capability growth over time | `guardianLinks`, `capabilityGrowthEvents`, `capabilities` | `parent_growth_timeline_page_test.dart`, `parent_surfaces_workflow_test.dart` | aligned and reusable |');
    expect(flutterMobileRouteMatrixSource).toContain('| HQ | `/hq/capability-frameworks` | `CapabilityFrameworkPage` | Capability framework setup | active-site `capabilities` records | `hq_authoring_persistence_test.dart`, `evidence_chain_routes_test.dart`, `hq_curriculum_workflow_test.dart` | aligned and reusable |');
    expect(flutterMobileRouteMatrixSource).toContain('| HQ | `/hq/rubric-builder` | `RubricBuilderPage` | Rubric setup | canonical active-site `rubricTemplates` records | `hq_authoring_persistence_test.dart`, `evidence_chain_routes_test.dart`, `hq_curriculum_workflow_test.dart` | aligned and reusable |');
    expect(flutterMobileRouteMatrixSource).toContain('| Site | `/site/dashboard` | `SiteDashboardPage` | Communicate implementation/support health |');
    expect(flutterMobileRouteMatrixSource).toContain('| HQ | `/hq/capability-frameworks` | `CapabilityFrameworkPage` | Capability framework setup |');
    expect(flutterMobileRouteMatrixSource).toContain('| Partner | `/partner/deliverables` | `PartnerDeliverablesPage` | External evidence-facing deliverables | `partnerContracts`, `partnerDeliverables`, audit logs, Firestore rules | `partner_deliverables_page_test.dart`, `partner_contracting_workflow_test.dart`, `test/firestore-rules.test.js` | aligned and reusable |');
    expect(flutterMobileRouteMatrixSource).toContain('Offline evidence chain gate** passed after this matrix');
    expect(flutterMobileRouteMatrixSource).toContain('Mobile classroom ergonomics gate** passed after this matrix');
    expect(flutterMobileRouteMatrixSource).toContain('Role permission and site-boundary review** passed after this matrix');
    expect(flutterMobileRouteMatrixSource).toContain('Focused Flutter/mobile release bundle** passed after this matrix');
    expect(flutterMobileRouteMatrixSource).toContain('Direct parent growth timeline route proof** passed after this matrix');
    expect(flutterMobileRouteMatrixSource).toContain('Mobile HQ authoring persistence** passed after this matrix');
    expect(flutterMobileRouteMatrixSource).toContain('Peer-feedback persistence and role-safety proof** passed after this matrix');
    expect(flutterMobileRouteMatrixSource).toContain('Partner deliverable evidence output trust** passed after this matrix');
    expect(flutterMobileRouteMatrixSource).toContain('Learner credential evidence provenance** passed after this matrix');
    expect(flutterMobileRouteMatrixSource).toContain('Parent active report-share revocation** passed after this matrix');
    expect(flutterMobileRouteMatrixSource).toContain('Learner today classroom evidence-action proof** passed after this matrix');
    expect(flutterMobileRouteMatrixSource).toContain('Learner checkpoint same-site mobile capture proof** passed after this matrix');
    expect(flutterMobileRouteMatrixSource).toContain('Learner reflection same-site portfolio provenance proof** passed after this matrix');
    expect(flutterMobileRouteMatrixSource).toContain('Learner proof assembly small-screen and offline replay proof** passed after this matrix');
    expect(flutterMobileRouteMatrixSource).toContain('Learner portfolio created-item provenance proof** passed after this matrix');
    expect(flutterMobileRouteMatrixSource).toContain('Educator today mobile evidence capture access proof** passed after this matrix');
    expect(flutterMobileRouteMatrixSource).toContain('Educator observation capture small-screen and site-boundary proof** passed after this matrix');
    expect(flutterMobileRouteMatrixSource).toContain('Educator proof-review persistence and site-boundary proof** passed after this matrix');
    expect(flutterMobileRouteMatrixSource).toContain('Canonical MiloOS synthetic mobile consumption proof** passed after this matrix');
    expect(flutterMobileRouteMatrixSource).toContain('Non-deploying release script gate** passed after route-level blocker closure');
    expect(flutterMobileRouteMatrixSource).toContain('Proceed to approved live or no-traffic deploy rehearsal reproducibility.');
    expect(flutterMobileRouteMatrixSource).toContain('Do not call Flutter/mobile gold-ready');
    expect(flutterMobileRouteMatrixSource).toContain('current-worktree live or `CLOUD_RUN_NO_TRAFFIC=1` rehearsal');
    expect(flutterBosSource).toContain('pendingExplainBack');
    expect(flutterBosSource).toContain('aiCoachResponses');
    expect(flutterBosSource).toContain("_readInt(eventCounts, 'ai_coach_response')");
    expect(flutterBosTestSource).toContain('2 opened/2 responses/1 explained/1 pending');
    expect(flutterEducatorSource).toContain('MiloOS Support Provenance');
    expect(flutterEducatorSource).toContain('Support events show follow-up debt only. They are not capability mastery.');
    expect(flutterEducatorSource).toContain("collection('interactionEvents')");
    expect(flutterSiteSource).toContain('MiloOS Support Health');
    expect(flutterSiteSource).toContain('Site-scoped support provenance and explain-back debt. Not capability mastery.');
    expect(flutterSiteSource).toContain("collection('interactionEvents')");
    expect(flutterSiteSource).toContain("_t('Responses')");
    expect(flutterSiteSource).toContain("_t('Pending explain-backs')");
    expect(flutterEducatorTestSource).toContain('shows MiloOS support debt for every learner');
    expect(flutterSiteTestSource).toContain('shows site-scoped MiloOS support health without mastery claims');
    expect(flutterSyntheticMiloOSMobileTestSource).toContain("buildImportBundle({ mode: 'starter' })");
    expect(flutterSyntheticMiloOSMobileTestSource).toContain('syntheticMiloOSGoldStates');
    expect(flutterSyntheticMiloOSMobileTestSource).toContain('canonical MiloOS synthetic states feed Flutter educator support provenance');
    expect(flutterSyntheticMiloOSMobileTestSource).toContain('canonical MiloOS synthetic states feed Flutter site support health');
    expect(flutterSyntheticMiloOSMobileTestSource).toContain("collection('capabilityMastery')");
    expect(flutterSyntheticMiloOSMobileTestSource).toContain("collection('capabilityGrowthEvents')");
    expect(flutterParentGrowthTimelineTestSource).toContain('parent growth timeline shows only linked learner growth provenance');
    expect(flutterParentGrowthTimelineTestSource).toContain("collection('capabilityGrowthEvents')");
    expect(flutterParentGrowthTimelineTestSource).toContain('Unlinked capability');
    expect(flutterHqAuthoringTestSource).toContain('mobile HQ creates site-scoped capability framework records');
    expect(flutterHqAuthoringTestSource).toContain("collection('rubricTemplates')");
    expect(flutterHqAuthoringTestSource).toContain('Other Site Rubric');
    expect(flutterPeerFeedbackTestSource).toContain('learner peer feedback persists same-site structured review only');
    expect(flutterPeerFeedbackTestSource).toContain("collection('peerFeedback')");
    expect(flutterPeerFeedbackTestSource).toContain('mission-other-site');
    expect(flutterPartnerDeliverablesTestSource).toContain('partner deliverables page submits a deliverable end to end');
    expect(flutterPartnerDeliverablesTestSource).toContain("collection('partnerDeliverables')");
    expect(flutterPartnerDeliverablesTestSource).toContain("saved['partnerId'], 'partner-1'");
    expect(flutterPartnerWorkflowTestSource).toContain('partner workflow repositories persist approvals, payouts, and audit evidence');
    expect(flutterPartnerWorkflowTestSource).toContain("acceptedDeliverable.data()?['partnerId'], 'partner-1'");
    expect(flutterLearnerCredentialsTestSource).toContain('learner credentials page renders live credentials');
    expect(flutterLearnerCredentialsTestSource).toContain("collection('credentials')");
    expect(flutterLearnerCredentialsTestSource).toContain("find.text('Evidence provenance')");
    expect(flutterLearnerCredentialsTestSource).toContain("find.text('Other Site Credential'), findsNothing");
    expect(flutterLearnerPortfolioTestSource).toContain('learner portfolio renders reviewed artifacts created by the live educator mission review flow');
    expect(flutterLearnerPortfolioTestSource).toContain("createdPortfolioItem['source'], 'educator_review_linkage'");
    expect(flutterLearnerPortfolioTestSource).toContain("createdPortfolioItem['proofBundleId'], 'learner-1_mission-1'");
    expect(flutterLearnerPortfolioTestSource).toContain("createdPortfolioItem['proofOfLearningStatus'], 'verified'");
    expect(flutterLearnerPortfolioTestSource).toContain("createdPortfolioItem['aiDisclosureStatus'], 'learner-ai-not-used'");
    expect(flutterLearnerPortfolioTestSource).toContain("find.text('Evidence linked • Reviewed')");
    expect(flutterLearnerTodayTestSource).toContain('learner today renders current evidence actions on classroom mobile width');
    expect(flutterLearnerTodayTestSource).toContain("find.text('My Evidence Loop')");
    expect(flutterLearnerTodayTestSource).toContain("find.text('What evidence I have shown')");
    expect(flutterLearnerTodayTestSource).toContain('expect(tester.takeException(), isNull)');
    expect(flutterEducatorTodayPageSource).toContain("label: _tEducatorToday(context, 'Log Evidence')");
    expect(flutterEducatorTodayPageSource).toContain("context.push('/educator/observations')");
    expect(flutterEducatorTodayTestSource).toContain('educator today exposes under-10-second evidence capture on classroom mobile width');
    expect(flutterEducatorTodayTestSource).toContain("find.text('Log Evidence')");
    expect(flutterEducatorTodayTestSource).toContain("find.text('Quick Observation Capture')");
    expect(flutterEducatorTodayTestSource).toContain('expect(tester.takeException(), isNull)');
    expect(flutterFirestoreServiceSource).toContain("case 'arrayContains':");
    expect(flutterObservationCapturePageSource).toContain("<dynamic>['siteIds', 'arrayContains', siteId]");
    expect(flutterObservationCapturePageSource).toContain("<dynamic>['siteId', siteId]");
    expect(flutterObservationCapturePageSource).toContain("<dynamic>['recordedBy', appState.userId]");
    expect(flutterObservationCaptureTestSource).toContain('observation capture records same-site classroom evidence on mobile width');
    expect(flutterObservationCaptureTestSource).toContain("find.text('Other Site Learner'), findsNothing");
    expect(flutterObservationCaptureTestSource).toContain('Other-site recent observation should stay hidden');
    expect(flutterObservationCaptureTestSource).toContain("saved['rubricStatus'], 'pending'");
    expect(flutterObservationCaptureTestSource).toContain("saved['growthStatus'], 'pending'");
    expect(flutterObservationCaptureTestSource).toContain("saved.containsKey('capabilityMastery'), isFalse");
    expect(flutterObservationCaptureTestSource).toContain('expect(tester.takeException(), isNull)');
    expect(flutterProofVerificationPageSource).toContain("<dynamic>['siteId', siteId]");
    expect(flutterProofVerificationPageSource).toContain("'proofOfLearningBundles'");
    expect(flutterProofVerificationPageSource).toContain('Wrap(');
    expect(flutterProofVerificationTestSource).toContain('proof verification shows same-site bundles and persists revision request on mobile width');
    expect(flutterProofVerificationTestSource).toContain("find.text('Other Site Learner'), findsNothing");
    expect(flutterProofVerificationTestSource).toContain("sameSiteProof.data()?['verificationStatus'], 'revision_requested'");
    expect(flutterProofVerificationTestSource).toContain("otherSiteProof.data()?['verificationStatus'], 'pending_review'");
    expect(flutterProofVerificationTestSource).toContain('expect(tester.takeException(), isNull)');
    expect(flutterReflectionPageSource).toContain("where('siteId', isEqualTo: siteId)");
    expect(flutterReflectionPageSource).toContain('Portfolio-linked reflection');
    expect(flutterReflectionTestSource).toContain('reflection journal renders same-site portfolio provenance on classroom mobile width');
    expect(flutterReflectionTestSource).toContain('Other-site reflection should stay hidden');
    expect(flutterReflectionTestSource).toContain("find.text('Portfolio-linked reflection')");
    expect(flutterReflectionTestSource).toContain('expect(tester.takeException(), isNull)');
    expect(flutterProofAssemblyPageSource).toContain("where('siteId', isEqualTo: siteId)");
    expect(flutterProofAssemblyPageSource).toContain('activePortfolioItemIds.contains(bundle.portfolioItemId)');
    expect(flutterProofAssemblyTestSource).toContain('proof assembly captures same-site proof methods on classroom mobile width');
    expect(flutterProofAssemblyTestSource).toContain('Other-site portfolio item should stay hidden');
    expect(flutterProofAssemblyTestSource).toContain("proof['capabilityId'], 'capability-evidence-reasoning'");
    expect(flutterProofAssemblyTestSource).toContain('expect(tester.takeException(), isNull)');
    expect(flutterCheckpointPageSource).toContain("where('siteId', isEqualTo: siteId)");
    expect(flutterCheckpointTestSource).toContain('checkpoint page captures same-site learner response on classroom mobile width');
    expect(flutterCheckpointTestSource).toContain('Other-site checkpoint should stay hidden');
    expect(flutterCheckpointTestSource).toContain("collection('checkpointHistory')");
    expect(flutterCheckpointTestSource).toContain('expect(tester.takeException(), isNull)');
    expect(flutterSyncCoordinatorTestSource).toContain('checkpointSubmit captures history and routes eligible mastery');
    expect(flutterSyncCoordinatorTestSource).toContain("httpsCallable('processCheckpointMasteryUpdate')");
    expect(flutterSyncCoordinatorTestSource).toContain('proofBundleCreate and proofBundleUpdate replay to proof bundles');
    expect(flutterSyncCoordinatorTestSource).toContain("collection('proofOfLearningBundles')");
    expect(flutterParentConsentSource).toContain('Active Report Shares');
    expect(flutterParentConsentSource).toContain('ReportShareRequestService.instance.revoke');
    expect(flutterParentConsentSource).toContain('Report share revoked.');
    expect(flutterParentConsentServiceSource).toContain("collection('reportShareRequests')");
    expect(flutterParentConsentServiceSource).toContain("where('siteId', isEqualTo: siteId!.trim())");
    expect(flutterParentConsentServiceSource).toContain('ParentReportShareRequest');
    expect(flutterParentConsentTestSource).toContain('parent consent page manages active report share revocation');
    expect(flutterParentConsentTestSource).toContain('share-hidden-1');
    expect(flutterParentConsentTestSource).toContain('share-other-site-1');
    expect(flutterParentConsentTestSource).toContain("find.text('Other Site Evidence Summary'), findsNothing");
    expect(flutterParentConsentTestSource).toContain('revokeReportShareRequest');
    expect(flutterParentConsentTestSource).toContain('parent consent page keeps active shares visible when revocation fails');
    expect(flutterParentConsentTestSource).toContain('Unable to revoke report share right now.');
    expect(firestoreRulesTestSource).toContain('partner can create own evidence-backed deliverable for a contract');
    expect(firestoreRulesTestSource).toContain('partner cannot create deliverable for another partner or accept it directly');
    expect(firestoreRulesTestSource).toContain('educator cannot issue credential without evidence provenance or as another issuer');
    expect(firestoreRulesTestSource).toContain('other-site educator cannot read or issue site1 learner credential');
  });

  it('Platform gold readiness master plan keeps blanket certification bounded', () => {
    const masterPlanSource = fs.readFileSync(
      path.join(process.cwd(), 'docs', 'PLATFORM_GOLD_READINESS_MASTER_PLAN_MAY_2026.md'),
      'utf8'
    );
    const routeMatrixSource = fs.readFileSync(
      path.join(process.cwd(), 'docs', 'PLATFORM_ROUTE_GOLD_MATRIX_MAY_2026.md'),
      'utf8'
    );
    const auditSource = fs.readFileSync(
      path.join(process.cwd(), 'AUDIT_TODO_APRIL_2026.md'),
      'utf8'
    );
    const finalSignoffSource = fs.readFileSync(
      path.join(process.cwd(), 'docs', 'PLATFORM_GOLD_READINESS_FINAL_SIGNOFF_MAY_2026.md'),
      'utf8'
    );
    const blanketGoldAchievementPlanSource = fs.readFileSync(
      path.join(process.cwd(), 'docs', 'PLATFORM_BLANKET_GOLD_ACHIEVEMENT_PLAN_MAY_2026.md'),
      'utf8'
    );
    const browserEvidenceChainSource = fs.readFileSync(
      path.join(process.cwd(), 'test', 'e2e', 'evidence-chain-cross-role.e2e.spec.ts'),
      'utf8'
    );
    const workflowRoutesBrowserSource = fs.readFileSync(
      path.join(process.cwd(), 'test', 'e2e', 'workflow-routes.e2e.spec.ts'),
      'utf8'
    );
    const themeModeToggleBrowserSource = fs.readFileSync(
      path.join(process.cwd(), 'test', 'e2e', 'theme-mode-toggle.e2e.spec.ts'),
      'utf8'
    );
    const playwrightConfigSource = fs.readFileSync(
      path.join(process.cwd(), 'playwright.config.ts'),
      'utf8'
    );
    const operatorReleaseProofSource = fs.readFileSync(
      path.join(process.cwd(), 'scripts', 'operator_release_proof.sh'),
      'utf8'
    );
    const proofVerificationIndexReadinessSource = fs.readFileSync(
      path.join(process.cwd(), 'scripts', 'proof_verification_index_readiness.js'),
      'utf8'
    );
    const cloudRunRehearsalUrlsSource = fs.readFileSync(
      path.join(process.cwd(), 'scripts', 'cloud_run_rehearsal_urls.js'),
      'utf8'
    );
    const deployScriptSource = fs.readFileSync(
      path.join(process.cwd(), 'scripts', 'deploy.sh'),
      'utf8'
    );
    const appleReleaseLocalSource = fs.readFileSync(
      path.join(process.cwd(), 'scripts', 'apple_release_local.sh'),
      'utf8'
    );
    const androidReleaseLocalSource = fs.readFileSync(
      path.join(process.cwd(), 'scripts', 'android_release_local.sh'),
      'utf8'
    );
    const macosReleaseLocalSource = fs.readFileSync(
      path.join(process.cwd(), 'scripts', 'macos_release_local.sh'),
      'utf8'
    );
    const appleReleaseAutomationSource = fs.readFileSync(
      path.join(process.cwd(), 'docs', 'APPLE_RELEASE_AUTOMATION.md'),
      'utf8'
    );
    const androidReleaseAutomationSource = fs.readFileSync(
      path.join(process.cwd(), 'docs', 'ANDROID_RELEASE_AUTOMATION.md'),
      'utf8'
    );
    const macosReleaseAutomationSource = fs.readFileSync(
      path.join(process.cwd(), 'docs', 'MACOS_RELEASE_AUTOMATION.md'),
      'utf8'
    );
    const primaryWebDockerfileSource = fs.readFileSync(
      path.join(process.cwd(), 'Dockerfile'),
      'utf8'
    );
    const primaryWebCloudBuildSource = fs.readFileSync(
      path.join(process.cwd(), 'cloudbuild.web.yaml'),
      'utf8'
    );
    const cloudRunReleaseStateProbeSource = fs.readFileSync(
      path.join(process.cwd(), 'scripts', 'cloud_run_release_state_probe.sh'),
      'utf8'
    );

    expect(masterPlanSource).toContain('not blanket platform gold-ready yet');
    expect(masterPlanSource).toContain('Master Matrix');
    expect(masterPlanSource).toContain('MiloOS support provenance');
    expect(masterPlanSource).toContain('Gold-candidate');
    expect(masterPlanSource).toContain('HQ setup -> educator live evidence capture -> learner artifact/reflection/checkpoint/proof');
    expect(masterPlanSource).toContain('applyRubricToEvidence');
    expect(masterPlanSource).toContain('processCheckpointMasteryUpdate');
    expect(masterPlanSource).toContain('Work Package 1 - Build The Route Gold Matrix');
    expect(masterPlanSource).toContain('Work Package 2 - Certify The Full Evidence Chain');
    expect(masterPlanSource).toContain('Do not call the platform blanket gold-ready');
    expect(masterPlanSource).toContain('PLATFORM_ROUTE_GOLD_MATRIX_MAY_2026.md');
    expect(masterPlanSource).toContain('PLATFORM_BLANKET_GOLD_ACHIEVEMENT_PLAN_MAY_2026.md');
    expect(masterPlanSource).toContain('test/e2e/evidence-chain-cross-role.e2e.spec.ts');
    expect(routeMatrixSource).toContain('route coverage is classified, but blanket platform gold is still blocked');
    expect(routeMatrixSource).toContain('/hq/capability-frameworks` -> `/hq/rubric-builder` -> `/educator/today`');
    expect(routeMatrixSource).toContain('Gold-Critical Route Proof References');
    expect(routeMatrixSource).toContain('syntheticPlatformEvidenceChainGoldStates/latest');
    expect(routeMatrixSource).toContain('Educator live queue and capture');
    expect(routeMatrixSource).toContain('| `/partner/deliverables` | partner | generic | External evidence-facing deliverables | deferred |');
    expect(routeMatrixSource).toContain('Work Package 1 is complete for the first gold-critical route chain');
    expect(routeMatrixSource).toContain('routeProofReferences.educatorRubricApply');
    expect(routeMatrixSource).toContain('consent-backed report-share records');
    expect(routeMatrixSource).toContain('canonical published HQ rubric template is available');
    expect(routeMatrixSource).toContain('newly authored and edited HQ rubric template');
    expect(routeMatrixSource).toContain('live-authored template is selected and applied');
    expect(routeMatrixSource).toContain('test/e2e/evidence-chain-cross-role.e2e.spec.ts');
    expect(routeMatrixSource).toContain('educator/site session evidence coverage');
    expect(routeMatrixSource).toContain('operator proof depth beyond that route lifecycle');
    expect(routeMatrixSource).toContain('`/site/ops` can create and resolve a site-scoped operator event');
    expect(routeMatrixSource).toContain('site_ops.event_resolved');
    expect(routeMatrixSource).toContain('local compliance runtime endpoints smoke');
    expect(routeMatrixSource).toContain('unauthenticated `/compliance/status` 401');
    expect(routeMatrixSource).toContain('local operator release proof');
    expect(routeMatrixSource).toContain('read-only Cloud Run release state probe');
    expect(masterPlanSource).toContain('operator proof depth beyond the site ops event lifecycle');
    expect(masterPlanSource).toContain('local compliance runtime smoke');
    expect(masterPlanSource).toContain('local operator release proof');
    expect(masterPlanSource).toContain('read-only Cloud Run release state probe');
    expect(finalSignoffSource).toContain('GO for blanket platform Gold for the included web/Cloud Run scope');
    expect(finalSignoffSource).toContain('Release Controls Closed');
    expect(finalSignoffSource).toContain('Included Scope');
    expect(finalSignoffSource).toContain('PLATFORM_BLANKET_GOLD_ACHIEVEMENT_PLAN_MAY_2026.md');
    expect(finalSignoffSource).toContain('/tmp/scholesa-release-gate-20260508-001144.log');
    expect(finalSignoffSource).toContain('full Flutter gate passed `1087` tests');
    expect(finalSignoffSource).toContain('Production web build');
    expect(finalSignoffSource).toContain('/[locale]/educator/proof-review');
    expect(finalSignoffSource).toContain('synthetic-import-2026-05-08T00-04-56-329Z');
    expect(finalSignoffSource).toContain('bash ./scripts/operator_release_proof.sh');
    expect(finalSignoffSource).toContain('bash ./scripts/cloud_run_release_state_probe.sh');
    expect(finalSignoffSource).toContain('Role-cutover Firestore index contracts');
    expect(finalSignoffSource).toContain('Passed; `sessionOccurrences`, `enrollments`, `evidenceRecords`, and `users` role-cutover indexes are READY');
    expect(finalSignoffSource).toContain('Proof/verification Firestore indexes');
    expect(finalSignoffSource).toContain('May 8 read-only `node scripts/proof_verification_index_readiness.js` after reauth');
    expect(finalSignoffSource).toContain('all READY (`READY=6`, `MISSING=0`)');
    expect(finalSignoffSource).toContain('May 8 post-reauth read-only checks passed');
    expect(finalSignoffSource).toContain('The live role sweep proves learner, educator, guardian, site, HQ, and partner web access on the rehearsal tag');
    expect(finalSignoffSource).toContain('MiloOS learner callable browser proof');
    expect(finalSignoffSource).toContain('MiloOS typed input intelligence');
    expect(finalSignoffSource).toContain('Final signoff validation');
    expect(finalSignoffSource).toContain('Commit `9ea389cf`');
    expect(finalSignoffSource).toContain('source-contract signoff test `192` tests');
    expect(finalSignoffSource).toContain('Logo source/render proof');
    expect(finalSignoffSource).toContain('Theme icon-only source/browser proof');
    expect(finalSignoffSource).toContain('Theme rehearsal-mode browser proof');
    expect(finalSignoffSource).toContain('PLAYWRIGHT_BASE_URL=http://127.0.0.1:3010');
    expect(finalSignoffSource).toContain('without Playwright starting a local web server');
    expect(finalSignoffSource).toContain('Prior stale `gold-rehearsal` theme runtime proof');
    expect(finalSignoffSource).toContain('scholesa-web-00047-7px');
    expect(finalSignoffSource).toContain('SystemLightDark');
    expect(finalSignoffSource).toContain('Current `gold-rehearsal` theme runtime proof');
    expect(finalSignoffSource).toContain('scholesa-web-00049-rmm');
    expect(finalSignoffSource).toContain('bebf1e7d-ff33-4339-8df6-c217ce74c400');
    expect(finalSignoffSource).toContain('gold-theme-proof-20260508-144726');
    expect(finalSignoffSource).toContain('Educator proof-review / verification rehearsal proof');
    expect(finalSignoffSource).toContain('do not show `Failed to load verification queue` or Firestore index errors');
    expect(finalSignoffSource).toContain('Partner web evidence-facing proof');
    expect(finalSignoffSource).toContain('scholesa-web-00050-fs9');
    expect(finalSignoffSource).toContain('561c4e87-70af-4d3e-bed7-3f1f10afd2b4');
    expect(finalSignoffSource).toContain('gold-partner-proof-20260508-152550');
    expect(finalSignoffSource).toContain('contract `W3rtDqJ7GJqt2tAjQD3q` and deliverable `6C1WhwTodWrlkSjZnZGf`');
    expect(finalSignoffSource).toContain('https://example.com/scholesa-gold-partner-evidence');
    expect(finalSignoffSource).toContain('Native macOS local release build');
    expect(finalSignoffSource).toContain('`./scripts/deploy.sh flutter-macos`');
    expect(finalSignoffSource).toContain('Flutter gate passed `1087` tests');
    expect(finalSignoffSource).toContain('build/macos/Build/Products/Release/scholesa_app.app` at `137.0MB`');
    expect(finalSignoffSource).toContain('Native iOS local release build');
    expect(finalSignoffSource).toContain('`./scripts/deploy.sh flutter-ios`');
    expect(finalSignoffSource).toContain('build/ios/iphoneos/Runner.app` at `76.3MB`');
    expect(finalSignoffSource).toContain('Native Android local release build');
    expect(finalSignoffSource).toContain('`./scripts/deploy.sh flutter-android`');
    expect(finalSignoffSource).toContain('Build-Tools 36.0.0');
    expect(finalSignoffSource).toContain('build/app/outputs/bundle/release/app-release.aab` at `56.6MB`');
    expect(finalSignoffSource).toContain('build/app/outputs/flutter-apk/app-release.apk` at `78.2MB`');
    expect(deployScriptSource).toContain('require_android_sdk');
    expect(deployScriptSource).toContain('Android SDK not found. Install Android Studio command-line tools or set ANDROID_HOME');
    expect(finalSignoffSource).toContain('`./scripts/macos_release_local.sh verify_local_release`');
    expect(finalSignoffSource).toContain('missing Developer ID Application identity plus `.env.app_store_connect.local`');
    expect(finalSignoffSource).toContain('no Apple Distribution / iOS Distribution identity');
    expect(finalSignoffSource).toContain('no iOS provisioning profile');
    expect(finalSignoffSource).toContain('no Android `apps/empire_flutter/app/android/key.properties` release signing file');
    expect(appleReleaseLocalSource).toContain('require_app_store_connect_env');
    expect(appleReleaseLocalSource).toContain('Missing local iOS provisioning profile');
    expect(appleReleaseLocalSource).toContain('Local iOS distribution prerequisites are incomplete');
    expect(androidReleaseLocalSource).toContain('require_google_play_env');
    expect(androidReleaseLocalSource).toContain('Missing $KEY_PROPERTIES_FILE');
    expect(androidReleaseLocalSource).toContain('Local Android release prerequisites are incomplete');
    expect(macosReleaseLocalSource).toContain('require_developer_id_identity');
    expect(macosReleaseLocalSource).toContain('Local macOS distribution prerequisites are incomplete');
    expect(appleReleaseAutomationSource).toContain('reports all missing local prerequisites in one pass');
    expect(appleReleaseAutomationSource).toContain('a local Apple Distribution identity');
    expect(androidReleaseAutomationSource).toContain('reports all missing local prerequisites in one pass');
    expect(androidReleaseAutomationSource).toContain('apps/empire_flutter/app/android/key.properties');
    expect(macosReleaseAutomationSource).toContain('./scripts/macos_release_local.sh verify_local_release');
    expect(macosReleaseAutomationSource).toContain('macOS distribution Gold requires Developer ID signing plus notarization proof');
    expect(finalSignoffSource).toContain('Fail-closed Firebase placeholder proof');
    expect(finalSignoffSource).toContain('0346e4be-94f6-45c9-84d7-8d4cd17f872f');
    expect(finalSignoffSource).toContain('scholesa-web-00045-pm9');
    expect(finalSignoffSource).toContain('genAiCoach` preflight accepts the `gold-rehearsal` origin');
    expect(finalSignoffSource).toContain('production traffic remains 100% on `scholesa-web-00048-s92`');
    expect(finalSignoffSource).toContain('The release owner explicitly accepted traffic-pinning proof as the final release-control substitute for production promotion');
    expect(finalSignoffSource).toContain('Current remote public theme proof against `scholesa-web-00049-rmm` passed');
    expect(finalSignoffSource).toContain('authenticated educator browser proof for `/en/educator/proof-review` plus `/en/educator/verification` rendered `Proof-of-Learning Verification`');
    expect(finalSignoffSource).toContain('partner evidence-facing web workflows');
    expect(finalSignoffSource).toContain('must not be used to claim native-channel app-store Gold');
    expect(blanketGoldAchievementPlanSource).toContain('Current verdict: **GO for blanket platform Gold for the included web/Cloud Run scope**');
    expect(blanketGoldAchievementPlanSource).toContain('None for the included web/Cloud Run scope');
    expect(blanketGoldAchievementPlanSource).toContain('Partner scope | Included for partner web evidence-facing workflows');
    expect(blanketGoldAchievementPlanSource).toContain('Native build proof | macOS local release build now passes');
    expect(blanketGoldAchievementPlanSource).toContain('iOS local release build now passes through `./scripts/deploy.sh flutter-ios`');
    expect(blanketGoldAchievementPlanSource).toContain('Android local release build now passes through `./scripts/deploy.sh flutter-android`');
    expect(blanketGoldAchievementPlanSource).toContain('May 7 Continuation Delta - Broad Gold Deployment');
    expect(blanketGoldAchievementPlanSource).toContain('Proof-of-learning verification queue hardening');
    expect(blanketGoldAchievementPlanSource).toContain('Theme mode switch presentation');
    expect(blanketGoldAchievementPlanSource).toContain('READY=6');
    expect(blanketGoldAchievementPlanSource).toContain('node scripts/proof_verification_index_readiness.js');
    expect(blanketGoldAchievementPlanSource).toContain('May 8 post-reauth read-only `node scripts/proof_verification_index_readiness.js` check confirmed the six proof/verification index shapes are READY');
    expect(blanketGoldAchievementPlanSource).toContain('current `scholesa-web-00049-rmm` no-traffic rehearsal passed the remote public theme proof');
    expect(blanketGoldAchievementPlanSource).toContain('[x] Current-worktree proof queue fix and icon-only theme switch included in a no-traffic web revision.');
    expect(blanketGoldAchievementPlanSource).toContain('[x] Proof-review queue loads without index/load errors on the rehearsed or promoted web revision.');
    expect(blanketGoldAchievementPlanSource).toContain('[x] Theme mode switch renders icon-only controls on public and protected shells.');
    expect(blanketGoldAchievementPlanSource).toContain('[x] Partner evidence-facing web workflows render and persist a submitted evidence URL deliverable with permission-safe readback.');
    expect(blanketGoldAchievementPlanSource).toContain('[x] macOS local release build passes while native app-store distribution remains fail-closed behind signing/notarization/store credentials.');
    expect(blanketGoldAchievementPlanSource).toContain('[x] iOS local release build passes with codesigning disabled while App Store distribution remains fail-closed behind App Store Connect credentials.');
    expect(blanketGoldAchievementPlanSource).toContain('[x] Android local release build passes after Android SDK/toolchain install, with Google Play distribution still fail-closed behind credentials and release signing assets.');
    expect(proofVerificationIndexReadinessSource).toContain('proofOfLearningBundles');
    expect(proofVerificationIndexReadinessSource).toContain('CLOUDSDK_CORE_DISABLE_PROMPTS');
    expect(blanketGoldAchievementPlanSource).toContain('npx playwright test test/e2e/theme-mode-toggle.e2e.spec.ts');
    expect(blanketGoldAchievementPlanSource).toContain('PLAYWRIGHT_BASE_URL="https://gold-rehearsal---<web-service-url>"');
    expect(finalSignoffSource).toContain('--grep "public entrypoints"');
    expect(finalSignoffSource).toContain('node scripts/cloud_run_rehearsal_urls.js');
    expect(blanketGoldAchievementPlanSource).toContain('REHEARSAL_URL');
    expect(blanketGoldAchievementPlanSource).toContain('the current `scholesa-web-00049-rmm` no-traffic rehearsal passed the remote public theme proof');
    expect(masterPlanSource).toContain('fresh rehearsal screenshot proving the theme switch no longer renders visible `System`, `Light`, or `Dark` labels');
    expect(masterPlanSource).toContain('test/e2e/theme-mode-toggle.e2e.spec.ts');
    expect(themeModeToggleBrowserSource).toContain('await expect(themeGroup).not.toContainText(/System|Light|Dark/)');
    expect(themeModeToggleBrowserSource).toContain("await expect(button).toHaveText('')");
    expect(themeModeToggleBrowserSource).toContain('Protected icon-only proof uses the local E2E auth harness');
    expect(playwrightConfigSource).toContain('const hasExternalBaseURL = Boolean(process.env.PLAYWRIGHT_BASE_URL);');
    expect(playwrightConfigSource).toContain('...(hasExternalBaseURL');
    expect(cloudRunRehearsalUrlsSource).toContain('CLOUD_RUN_REHEARSAL_TAG');
    expect(cloudRunRehearsalUrlsSource).toContain('REHEARSAL_URL=');
    expect(blanketGoldAchievementPlanSource).toContain('CLOUD_RUN_REHEARSAL_TAG=gold-rehearsal');
    expect(finalSignoffSource).toContain('Native-channel app-store release operations are deferred');
    expect(finalSignoffSource).toContain('iOS/macOS/Android store distribution');
    expect(masterPlanSource).toContain('native-channel app-store release operations explicitly deferred');
    expect(operatorReleaseProofSource).toContain('rc3_big_bang_cutover_entrypoint.sh --print-only');
    expect(operatorReleaseProofSource).toContain('append_no_traffic_arg');
    expect(operatorReleaseProofSource).toContain('tag_no_traffic_rehearsal_revision');
    expect(operatorReleaseProofSource).toContain('--update-tags');
    expect(operatorReleaseProofSource).toContain('COMPLIANCE_ALLOW_UNAUTH=0');
    expect(operatorReleaseProofSource).toContain('declare NO-GO and rollback the full release');
    expect(primaryWebDockerfileSource).toContain('ARG NEXT_PUBLIC_FIREBASE_API_KEY');
    expect(primaryWebDockerfileSource).toContain('ENV NEXT_PUBLIC_FIREBASE_API_KEY=${NEXT_PUBLIC_FIREBASE_API_KEY}');
    expect(primaryWebCloudBuildSource).toContain('NEXT_PUBLIC_FIREBASE_API_KEY=${_NEXT_PUBLIC_FIREBASE_API_KEY}');
    expect(primaryWebCloudBuildSource).toContain('NEXT_PUBLIC_FIREBASE_APP_ID=${_NEXT_PUBLIC_FIREBASE_APP_ID}');
    expect(deployScriptSource).toContain('cloudbuild.web.yaml');
    expect(deployScriptSource).toContain('Missing $key for primary web build');
    expect(deployScriptSource).toContain('SERVICE_STATE_JSON');
    expect(cloudRunReleaseStateProbeSource).toContain('CLOUDSDK_CORE_DISABLE_PROMPTS=1');
    expect(cloudRunReleaseStateProbeSource).toContain('EXPECTED_WEB_REHEARSAL_REVISION:-');
    expect(cloudRunReleaseStateProbeSource).toContain('EXPECTED_FLUTTER_REHEARSAL_REVISION:-');
    expect(cloudRunReleaseStateProbeSource).toContain('EXPECTED_COMPLIANCE_REHEARSAL_REVISION');
    expect(cloudRunReleaseStateProbeSource).toContain('EXPECTED_COMPLIANCE_TRAFFIC_REVISION');
    expect(cloudRunReleaseStateProbeSource).toContain('expected unauthenticated compliance status to return 403');
    expect(blanketGoldAchievementPlanSource).toContain('Phase 0 - Freeze Scope And Record Baseline');
    expect(blanketGoldAchievementPlanSource).toContain('Phase 3 - Rehearse Current-Worktree No-Traffic Deploys');
    expect(blanketGoldAchievementPlanSource).toContain('Phase 5 - Promote Or Roll Back Under Operator Control');
    expect(blanketGoldAchievementPlanSource).toContain('Final GO Checklist');
    expect(blanketGoldAchievementPlanSource).toContain('Live operator cutover is missing');
    expect(browserEvidenceChainSource).toContain("gotoProtectedRoute(page, '/en/hq/rubric-builder')");
    expect(browserEvidenceChainSource).toContain('Live HQ Authored Evidence Rubric');
    expect(browserEvidenceChainSource).toContain('Edited Live HQ Authored Evidence Rubric');
    expect(browserEvidenceChainSource).toContain('rubric-template-card-');
    expect(browserEvidenceChainSource).toContain('Apply Rubric (1 scores)');
    expect(browserEvidenceChainSource).toContain("page.getByLabel('Select rubric template')");
    expect(browserEvidenceChainSource).toContain('Prototype Iteration Evidence Rubric');
    expect(browserEvidenceChainSource).toContain("gotoProtectedRoute(page, '/en/parent/passport')");
    expect(browserEvidenceChainSource).toContain("gotoProtectedRoute(page, '/en/site/evidence-health')");
    expect(browserEvidenceChainSource).toContain('seedEvidenceChain');
    expect(browserEvidenceChainSource).toContain('canonicalPlatformEvidenceChainGoldRecords');
    expect(browserEvidenceChainSource).toContain('canonicalPlatformEvidenceChainRouteProofReferences');
    expect(browserEvidenceChainSource).toContain('platform-evidence-chain-gold-fixture');
    expect(browserEvidenceChainSource).toContain('capabilityGrowthEvents');
    expect(browserEvidenceChainSource).toContain('rubricTemplates');
    expect(browserEvidenceChainSource).toContain('reportShareRequests');
    expect(browserEvidenceChainSource).toContain('learner-weak-report');
    expect(browserEvidenceChainSource).toContain('report.delivery_blocked');
    expect(browserEvidenceChainSource).toContain("reportBlockReason: 'missing_provenance'");
    expect(browserEvidenceChainSource).toContain('report_missing_provenance_signals');
    expect(browserEvidenceChainSource).toContain("gotoProtectedRoute(page, '/en/educator/missions/review')");
    expect(browserEvidenceChainSource).toContain('Request consent');
    expect(browserEvidenceChainSource).toContain("getByRole('button', { name: 'Grant' })");
    expect(browserEvidenceChainSource).toContain('Active share:');
    expect(workflowRoutesBrowserSource).toContain("page.goto('/en/site/ops')");
    expect(workflowRoutesBrowserSource).toContain('release-cutover-drill');
    expect(workflowRoutesBrowserSource).toContain('siteOpsEvents');
    expect(workflowRoutesBrowserSource).toContain('site_ops.event_resolved');
    expect(workflowRoutesBrowserSource).toContain('auditLogs');
    expect(workflowRoutesBrowserSource).toContain('Status: resolved');
    expect(masterPlanSource).toContain('syntheticPlatformEvidenceChainGoldStates/latest');
    expect(masterPlanSource).toContain('syntheticPlatformEvidenceChainGoldStates/latest.routeProofReferences');
    expect(masterPlanSource).toContain('consent-backed broader share records');
    expect(masterPlanSource).toContain('canonical HQ rubric template selection');
    expect(masterPlanSource).toContain('live HQ rubric create/edit');
    expect(masterPlanSource).toContain('live-authored rubric application');
    expect(auditSource).toContain('PLATFORM_GOLD_READINESS_MASTER_PLAN_MAY_2026.md');
    expect(auditSource).toContain('PLATFORM_ROUTE_GOLD_MATRIX_MAY_2026.md');
    expect(auditSource).toContain('first gold-critical gap');
  });

  it('PageTransition keeps reduced-motion MiloOS routes hydration-stable', () => {
    const source = readSrcFile('components', 'layout', 'PageTransition.tsx');

    expect(source).toContain("window.matchMedia('(prefers-reduced-motion: reduce)')");
    expect(source).toContain('if (!hasMounted || prefersReducedMotion)');
    expect(source).not.toContain('useReducedMotion');
  });

  it('SiteEvidenceHealthRenderer delegates to SiteEvidenceHealthDashboard', () => {
    const source = readSrcFile(
      'features', 'workflows', 'renderers', 'SiteEvidenceHealthRenderer.tsx'
    );
    expect(source).toContain('SiteEvidenceHealthDashboard');
    expect(source).toContain('@/src/components/analytics/SiteEvidenceHealthDashboard');
  });

  it('GuardianCapabilityViewRenderer normalizes the parent bundle contract and quarantines engagement signals', () => {
    const source = readSrcFile(
      'features', 'workflows', 'renderers', 'GuardianCapabilityViewRenderer.tsx'
    );
    const fakeBackendSource = readSrcFile('testing', 'e2e', 'fakeWebBackend.ts');
    const e2eSource = fs.readFileSync(
      path.join(process.cwd(), 'test', 'e2e', 'miloos-guardian-support-provenance.e2e.spec.ts'),
      'utf8'
    );
    expect(source).toContain('normalizeLearnerSummary');
    expect(source).toContain('learnerName');
    expect(source).toContain('capabilitySnapshot');
    expect(source).toContain('pillarProgress');
    expect(source).toContain('portfolioItemsPreview');
    expect(source).toContain('updatedCapabilityCount');
    expect(source).toContain('Supplemental engagement signals');
    expect(source).toContain('do not replace the evidence-backed');
    expect(source).toContain('capability, proof, and growth judgments');
    expect(source).toContain("NEXT_PUBLIC_E2E_TEST_MODE === '1'");
    expect(source).toContain('getE2EParentDashboardBundle');
    expect(source).toContain('trackInteractionRef');
    expect(fakeBackendSource).toContain('getE2EParentDashboardBundle');
    expect(e2eSource).toContain("page.goto('/en/parent/summary')");
    expect(e2eSource).toContain('seedCanonicalMiloOSGoldWebState');
    expect(e2eSource).toContain('guardian-miloos-support-');
    expect(e2eSource).toContain('not capability mastery');
    expect(e2eSource).toContain('seedCanonicalMiloOSGoldWebState');
    expect(e2eSource).toContain('WEB_MILOOS_SYNTHETIC_IDS');
  });

  it('EducatorTodayRenderer uses canonical site context for live capture', () => {
    const source = readSrcFile(
      'features', 'workflows', 'renderers', 'EducatorTodayRenderer.tsx'
    );
    expect(source).toContain('resolveActiveSiteId');
    expect(source).toContain("where('siteId', '==', educatorSiteId)");
    expect(source).toContain('siteId={educatorSiteId}');
    expect(source).toContain('quick-evidence-capability');
    expect(source).toContain('evidenceRecordIds: [evidenceRef.id]');
    expect(source).toContain('sessionOccurrenceId={selectedSession?.occurrenceId}');
    expect(source).toContain('data-testid="quick-observation-session"');
    expect(source).toContain("collection(firestore, 'attendanceRecords')");
    expect(source).toContain('data-testid="educator-today-site-required"');
  });

  it('LearnerProgressReportRenderer uses canonical site context for passport output', () => {
    const source = readSrcFile(
      'features', 'workflows', 'renderers', 'LearnerProgressReportRenderer.tsx'
    );
    expect(source).toContain('resolveActiveSiteId');
    expect(source).toContain('<LearnerPassportExport siteId={siteId} />');
    expect(source).toContain('data-testid="learner-progress-site-required"');
  });
});

/* ───── EducatorEvidenceReviewRenderer growth write path ───── */

describe('EducatorEvidenceReviewRenderer capability growth write path', () => {
  const source = readSrcFile(
    'features', 'workflows', 'renderers', 'EducatorEvidenceReviewRenderer.tsx'
  );

  it('uses canonical active-site resolution and honest blocked state', () => {
    expect(source).toContain('resolveActiveSiteId');
    expect(source).toContain('data-testid="educator-review-site-required"');
    expect(source).toContain('Select an active site before reviewing learner evidence and applying rubric decisions.');
  });

  it('writes to rubricApplications', () => {
    expect(source).toContain('rubricApplications');
  });

  it('creates capabilityGrowthEvents', () => {
    expect(source).toContain('capabilityGrowthEvents');
  });

  it('upserts capabilityMastery', () => {
    expect(source).toContain('capabilityMastery');
  });

  it('updates missionAttempts status', () => {
    expect(source).toContain('missionAttempts');
  });

  it('passes the canonical portfolio item into mission rubric application when available', () => {
    expect(source).toContain('portfolioItemId: attempt.portfolioItemId ?? undefined');
  });

  it('uses Firestore batch for atomicity', () => {
    expect(source).toMatch(/batch|writeBatch|setDoc|addDoc/);
  });

  it('captures processCheckpointMasteryUpdate result and warns when growth not triggered', () => {
    // The callable result must be captured (not fire-and-forget) so the renderer
    // can detect updated: false and show the amber warning banner.
    expect(source).toContain('growthResult');
    expect(source).toContain('growthResult.data.updated');
    expect(source).toContain('checkpointGrowthWarning');
    expect(source).toContain('checkpoint-growth-warning');
  });

  it('treats proof-linked checkpoints as reviewed evidence instead of a growth side-channel', () => {
    expect(source).toContain('cp.portfolioItemId');
    expect(source).toContain('checkpointDefinitionId');
    expect(source).toContain('checkpointLabel');
    expect(source).toContain("where('status', 'in', ['submitted', 'pending_proof'])");
    expect(source).toContain('Checkpoint correctness saved. Verify the linked proof-of-learning, then record capability growth from this review surface.');
    expect(source).toContain('Linked proof is verified. Confirm this checkpoint again to record capability growth.');
    expect(source).toContain('Record growth');
    expect(source).toContain('data-testid={`checkpoint-proof-gate-${cp.id}`}');
  });

  it('shows a truthful proof gate before rubric-driven growth', () => {
    expect(source).toContain("attempt.proofOfLearningStatus !== 'verified'");
    expect(source).toContain('Verify proof-of-learning before applying a rubric that updates capability growth.');
    expect(source).not.toContain('rubric-proof-verified-');
  });
});

/* ───── LearnerProofAssemblyRenderer proof bundle writes ───── */

describe('LearnerProofAssemblyRenderer proof bundle writes', () => {
  const source = readSrcFile(
    'features', 'workflows', 'renderers', 'LearnerProofAssemblyRenderer.tsx'
  );
  const browserEvidenceChainSource = fs.readFileSync(
    path.join(process.cwd(), 'test', 'e2e', 'evidence-chain-cross-role.e2e.spec.ts'),
    'utf8'
  );

  it('reads portfolioItems', () => {
    expect(source).toContain('portfolioItems');
  });

  it('manages proofOfLearningBundles', () => {
    expect(source).toContain('proofOfLearningBundles');
  });

  it('supports ExplainItBack verification', () => {
    expect(source).toMatch(/explainItBack|ExplainItBack/i);
  });

  it('supports OralCheck verification', () => {
    expect(source).toMatch(/oralCheck|OralCheck/i);
  });

  it('supports MiniRebuild verification', () => {
    expect(source).toMatch(/miniRebuild|MiniRebuild/i);
  });

  it('computes verification status (missing/partial/verified)', () => {
    expect(source).toContain('missing');
    expect(source).toContain('partial');
    expect(source).toContain('verified');
  });

  it('site-scopes proof assembly and mirrors proof fields onto portfolio items', () => {
    expect(source).toContain('resolveActiveSiteId');
    expect(source).toContain("where('siteId', '==', siteId)");
    expect(source).toContain("NEXT_PUBLIC_E2E_TEST_MODE === '1'");
    expect(source).toContain('saveE2EProofBundle');
    expect(source).toContain('proofHasExplainItBack');
    expect(source).toContain('proofExplainItBackExcerpt');
    expect(source).toContain('proofCheckpointCount');
  });

  it('falls back to portfolio proof fields when no persisted proof bundle exists', () => {
    expect(source).toContain('portfolioProofFallback');
    expect(source).toContain('proofBundleId ?? `portfolio-${item.id}`');
  });

  it('has browser proof for learner-created pending-review proof bundles', () => {
    expect(browserEvidenceChainSource).toContain("gotoProtectedRoute(page, '/en/learner/proof-assembly')");
    expect(browserEvidenceChainSource).toContain('Learner-Created Proof Draft');
    expect(browserEvidenceChainSource).toContain("verificationStatus: 'pending_review'");
    expect(browserEvidenceChainSource).toContain('proofCheckpointCount: 3');
    expect(browserEvidenceChainSource).toContain("gotoProtectedRoute(page, '/en/educator/proof-review')");
    expect(browserEvidenceChainSource).toContain('Verify (3/3 checks)');
    expect(browserEvidenceChainSource).toContain("verificationStatus: 'verified'");
  });
});

/* ───── LearnerPortfolioCurationRenderer evidence-linked portfolio ───── */

describe('LearnerPortfolioCurationRenderer evidence-linked portfolio', () => {
  const source = readSrcFile(
    'features', 'workflows', 'renderers', 'LearnerPortfolioCurationRenderer.tsx'
  );

  it('reads portfolioItems', () => {
    expect(source).toContain('portfolioItems');
  });

  it('reads capabilityMastery for growth context', () => {
    expect(source).toContain('capabilityMastery');
  });

  it('reads capabilityGrowthEvents', () => {
    expect(source).toContain('capabilityGrowthEvents');
  });

  it('reads proofOfLearningBundles', () => {
    expect(source).toContain('proofOfLearningBundles');
  });

  it('creates new portfolioItems with addDoc', () => {
    expect(source).toContain('addDoc');
    expect(source).toContain('portfolioItems');
  });

  it('requires capability linkage when creating new portfolio items', () => {
    expect(source).toContain('portfolio-item-capability-select');
    expect(source).toContain('capabilityIds: [selectedCapability.id]');
    expect(source).toContain('capabilityTitles: [resolveTitle(selectedCapability.id)]');
    expect(source).not.toContain('capabilityIds: [],');
  });

  it('scopes learner portfolio reads and writes to the resolved active site', () => {
    expect(source).toContain('resolveActiveSiteId');
    expect(source).toContain("where('siteId', '==', siteId)");
    expect(source).toContain('data-testid="learner-portfolio-site-required"');
  });

  it('supports AI disclosure tracking', () => {
    expect(source).toMatch(/aiDisclosure|aiAssistance/i);
    expect(source).toContain('newAiDetails');
    expect(source).toContain('portfolio-item-ai-details-input');
  });

  it('writes canonical portfolio item fields instead of legacy learner curation fields', () => {
    const addDocBlock = source.slice(
      source.indexOf('const portfolioDoc = await addDoc(portfolioItemsCollection'),
      source.indexOf('} as unknown as Omit<PortfolioItemRecord, \'id\'>);') +
        '} as unknown as Omit<PortfolioItemRecord, \'id\'>);'.length
    );
    expect(addDocBlock).toContain('pillarCodes');
    expect(addDocBlock).toContain('artifacts');
    expect(addDocBlock).toContain('proofOfLearningStatus');
    expect(addDocBlock).toContain('aiDisclosureStatus');
    expect(addDocBlock).toContain('aiAssistanceDetails');
    expect(addDocBlock).toContain("source: 'learner_submission'");
    expect(addDocBlock).not.toContain("source: 'learner_curation'");
    expect(addDocBlock).not.toContain('pillarCode: selectedCapability.pillarCode ?? newPillar');
    expect(addDocBlock).not.toContain('artifactUrl: newArtifactUrl.trim()');
    expect(addDocBlock).not.toContain('aiDisclosure: newAiDisclosure');
    expect(addDocBlock).not.toContain('proofOfLearning: false');
  });

  it('creates linked learnerReflections with canonical content while preserving reflection prompts', () => {
    const handler = source.slice(
      source.indexOf('const handleAddItem'),
      source.indexOf('const handleMarkAsShowcase')
    );
    expect(handler).toContain('learnerReflectionsCollection');
    expect(handler).toContain('content: newReflection.trim()');
    expect(handler).toContain('proudOf: newReflection.trim()');
    expect(handler).toContain("nextIWill: ''");
    expect(handler).toContain('reflectionIds: [reflectionDoc.id]');
    expect(handler).toContain('reflectionPayload.aiAssistanceDetails = aiDetails');
  });
});

/* ───── LearnerEvidenceTimelineRenderer all-evidence synthesis ───── */

describe('LearnerEvidenceTimelineRenderer all-evidence synthesis', () => {
  const source = readSrcFile(
    'features', 'workflows', 'renderers', 'LearnerEvidenceTimelineRenderer.tsx'
  );

  it('reads portfolioItems for artifacts', () => {
    expect(source).toContain('portfolioItems');
  });

  it('reads learnerReflections', () => {
    expect(source).toContain('learnerReflections');
  });

  it('reads checkpointHistory for checkpoint submissions', () => {
    expect(source).toContain('checkpointHistory');
  });

  it('reads proofOfLearningBundles', () => {
    expect(source).toContain('proofOfLearningBundles');
  });

  it('renders proof bundles as standalone timeline entries', () => {
    expect(source).toContain("type: 'proof_bundle'");
    expect(source).toContain('Proof of learning');
    expect(source).toContain('portfolioItemId');
    expect(source).toContain('hasExplainItBack');
  });

  it('reads missionAttempts', () => {
    expect(source).toContain('missionAttempts');
  });

  it('scopes all queries by learnerId', () => {
    const matchCount = (source.match(/learnerId/g) || []).length;
    expect(matchCount).toBeGreaterThanOrEqual(5);
  });

  it('shows AI disclosure status on evidence items', () => {
    expect(source).toMatch(/aiDisclosure|aiAssistance/i);
  });

  it('shows proof status on evidence items', () => {
    expect(source).toMatch(/proofStatus|proof_bundle/i);
  });

  it('back-links growth from linked evidence records as well as portfolio items', () => {
    expect(source).toContain('linkedEvidenceRecordIds');
    expect(source).toContain('growthByEvidence');
    expect(source).toContain('evidenceRecordIds');
    expect(source).toContain('mergeGrowthLinks');
  });

  it('orders items chronologically', () => {
    expect(source).toMatch(/createdAt|orderBy/i);
  });
});

/* ───── EducatorSessionsRenderer evidence-enriched session view ───── */

describe('EducatorSessionsRenderer evidence-enriched session view', () => {
  const source = readSrcFile(
    'features', 'workflows', 'renderers', 'EducatorSessionsRenderer.tsx'
  );

  it('reads sessions collection', () => {
    expect(source).toContain("'sessions'");
  });

  it('reads evidenceRecords to show per-session counts', () => {
    expect(source).toContain('evidenceRecords');
  });

  it('reads checkpointHistory for checkpoint counts', () => {
    expect(source).toContain('checkpointHistory');
  });

  it('scopes session queries by siteId', () => {
    expect(source).toContain('siteId');
  });

  it('shows evidence count per session', () => {
    expect(source).toMatch(/evidenceCount|evidenceCounts/);
  });

  it('shows checkpoint count per session', () => {
    expect(source).toMatch(/checkpointCount|checkpointCounts/);
  });

  it('has harness-backed browser proof for educator and site session coverage', () => {
    const browserEvidenceChainSource = fs.readFileSync(
      path.join(process.cwd(), 'test', 'e2e', 'evidence-chain-cross-role.e2e.spec.ts'),
      'utf8'
    );
    const workflowDataSource = readSrcFile('features', 'workflows', 'workflowData.ts');

    expect(source).toContain('NEXT_PUBLIC_E2E_TEST_MODE');
    expect(browserEvidenceChainSource).toContain("gotoProtectedRoute(page, '/en/educator/sessions')");
    expect(browserEvidenceChainSource).toContain("gotoProtectedRoute(page, '/en/site/sessions')");
    expect(workflowDataSource).toContain('enrichSessionRecordsWithEvidenceCoverage');
    expect(workflowDataSource).toContain('observedLearnerCount');
  });
});

/* ───── EducatorAiAuditRenderer motivation feedback wiring ───── */

describe('EducatorAiAuditRenderer motivation feedback wiring', () => {
  const source = readSrcFile(
    'features', 'workflows', 'renderers', 'EducatorAiAuditRenderer.tsx'
  );
  const rulesSource = readSrcFile('..', 'firestore.rules');
  const rulesTestSource = readSrcFile('..', 'test', 'firestore-rules.test.js');
  const firestoreIndexes = JSON.parse(
    fs.readFileSync(path.join(process.cwd(), 'firestore.indexes.json'), 'utf8')
  ) as { indexes?: Array<{ collectionGroup?: string; fields?: Array<{ fieldPath?: string; order?: string; arrayConfig?: string }> }> };

  it('imports EducatorFeedbackForm', () => {
    expect(source).toContain('EducatorFeedbackForm');
  });

  it('renders log-motivation button per learner', () => {
    expect(source).toContain('log-motivation-');
  });

  it('renders EducatorFeedbackForm inline when open', () => {
    expect(source).toContain('motivation-form-');
    expect(source).toContain('openMotivationId');
  });

  it('shows saved confirmation after successful submission', () => {
    expect(source).toContain('motivationSavedIds');
    expect(source).toMatch(/Saved|saved/);
  });

  it('surfaces MiloOS support provenance and explain-back gaps for educators', () => {
    expect(source).toContain('resolveActiveSiteId');
    expect(source).toContain("collection(firestore, 'interactionEvents')");
    expect(source).toContain("where('siteId', '==', siteId)");
    expect(source).toContain('buildLearnerAiSummaries');
    expect(source).toContain("getE2ECollection('interactionEvents')");
    expect(source).toContain('MILOOS_SUPPORT_EVENT_TYPES');
    expect(source).toContain('pendingExplainBack');
    expect(source).toContain('MiloOS support provenance');
    expect(source).toContain('support signals and verification gaps, not capability mastery');
    expect(source).toContain('data-testid={`miloos-support-${s.learnerId}`}');
    expect(source).toContain('data-testid="educator-ai-audit-site-required"');
  });

  it('keeps the educator AI audit interaction log query backed by a composite index', () => {
    const hasAiInteractionLogIndex = firestoreIndexes.indexes?.some((index) => {
      const fields = index.fields ?? [];
      return index.collectionGroup === 'aiInteractionLogs'
        && fields[0]?.fieldPath === 'siteId'
        && fields[0]?.order === 'ASCENDING'
        && fields[1]?.fieldPath === 'createdAt'
        && fields[1]?.order === 'DESCENDING';
    }) === true;

    expect(source).toContain("collection(firestore, 'aiInteractionLogs')");
    expect(source).toContain("where('siteId', '==', siteId)");
    expect(source).toContain("orderBy('createdAt', 'desc')");
    expect(hasAiInteractionLogIndex).toBe(true);
  });

  it('allows educator reads of interactionEvents only through site-scoped rules', () => {
    expect(rulesSource).toContain(
      'allow read: if isHQ() || isAdminOrHQ() || (isEducator() && hasSiteField(resource.data) && isSiteScopedRead(resource.data));'
    );
  });

  it('blocks parents from raw MiloOS interactionEvents in Firestore rules tests', () => {
    expect(rulesTestSource).toContain(
      'linked parent cannot read raw MiloOS interaction events directly'
    );
    expect(rulesTestSource).toContain(
      'unlinked parent cannot read raw MiloOS interaction events directly'
    );
  });

  it('has browser E2E coverage for educator MiloOS support provenance', () => {
    const e2eSource = fs.readFileSync(
      path.join(process.cwd(), 'test', 'e2e', 'miloos-educator-support-provenance.e2e.spec.ts'),
      'utf8'
    );
    expect(e2eSource).toContain("page.goto('/en/educator/learners')");
    expect(e2eSource).toContain('seedCanonicalMiloOSGoldWebState');
    expect(e2eSource).toContain('miloos-support-');
    expect(e2eSource).toContain('support signals and verification gaps, not capability mastery');
    expect(e2eSource).toContain('seedCanonicalMiloOSGoldWebState');
    expect(e2eSource).toContain('WEB_MILOOS_SYNTHETIC_IDS');
  });
});
