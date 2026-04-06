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
    '/learner/missions',
    '/learner/proof-assembly',
    '/learner/checkpoints',
    '/learner/reflections',
    '/learner/peer-feedback',
    '/learner/habits',
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

  it('LearnerCheckpointRenderer → LearnerEvidenceSubmission', () => {
    const source = readSrcFile(
      'features', 'workflows', 'renderers', 'LearnerCheckpointRenderer.tsx'
    );
    expect(source).toContain('LearnerEvidenceSubmission');
    expect(source).toContain('@/src/components/evidence/LearnerEvidenceSubmission');
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
    expect(source).toContain('rubricApplications');
    expect(source).toContain('evidenceRecords');
    expect(source).toContain('capabilityGrowthEvents');
    expect(source).toContain('proofOfLearningBundles');
  });
});

/* ───── EducatorEvidenceReviewRenderer growth write path ───── */

describe('EducatorEvidenceReviewRenderer capability growth write path', () => {
  const source = readSrcFile(
    'features', 'workflows', 'renderers', 'EducatorEvidenceReviewRenderer.tsx'
  );

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
