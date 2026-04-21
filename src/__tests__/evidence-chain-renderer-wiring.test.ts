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
    expect(source).toContain('EducatorEvidenceCapture');
    expect(source).toContain('@/src/components/evidence/EducatorEvidenceCapture');
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
  });

  it('LearnerCheckpointRenderer reads/writes checkpointHistory collection', () => {
    const source = readSrcFile(
      'features', 'workflows', 'renderers', 'LearnerCheckpointRenderer.tsx'
    );
    // Purpose-built checkpoint UI — reads from and writes to checkpointHistory
    expect(source).toContain('checkpointHistory');
    expect(source).toContain('explainItBack');
    expect(source).toContain('learnerId');
    expect(source).toContain('addDoc');
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

  it('LearnerMiloOSRenderer → AICoachScreen with autonomy risk awareness', () => {
    const source = readSrcFile(
      'features', 'workflows', 'renderers', 'LearnerMiloOSRenderer.tsx'
    );
    expect(source).toContain('AICoachScreen');
    expect(source).toContain('aiInteractionLogs');
    expect(source).toContain('autonomyRiskLevel');
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
    expect(source).toContain('data-testid="site-implementation-site-required"');
  });

  it('GuardianCapabilityViewRenderer normalizes the parent bundle contract and quarantines engagement signals', () => {
    const source = readSrcFile(
      'features', 'workflows', 'renderers', 'GuardianCapabilityViewRenderer.tsx'
    );
    expect(source).toContain('normalizeLearnerSummary');
    expect(source).toContain('learnerName');
    expect(source).toContain('capabilitySnapshot');
    expect(source).toContain('pillarProgress');
    expect(source).toContain('portfolioItemsPreview');
    expect(source).toContain('updatedCapabilityCount');
    expect(source).toContain('Supplemental engagement signals');
    expect(source).toContain('do not replace the evidence-backed capability');
  });

  it('EducatorTodayRenderer uses canonical site context for live capture', () => {
    const source = readSrcFile(
      'features', 'workflows', 'renderers', 'EducatorTodayRenderer.tsx'
    );
    expect(source).toContain('resolveActiveSiteId');
    expect(source).toContain("where('siteId', '==', educatorSiteId)");
    expect(source).toContain('siteId={educatorSiteId}');
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
});

/* ───── LearnerProofAssemblyRenderer proof bundle writes ───── */

describe('LearnerProofAssemblyRenderer proof bundle writes', () => {
  const source = readSrcFile(
    'features', 'workflows', 'renderers', 'LearnerProofAssemblyRenderer.tsx'
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

  it('supports AI disclosure tracking', () => {
    expect(source).toMatch(/aiDisclosure|aiAssistance/i);
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
});

/* ───── EducatorAiAuditRenderer motivation feedback wiring ───── */

describe('EducatorAiAuditRenderer motivation feedback wiring', () => {
  const source = readSrcFile(
    'features', 'workflows', 'renderers', 'EducatorAiAuditRenderer.tsx'
  );

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
});
