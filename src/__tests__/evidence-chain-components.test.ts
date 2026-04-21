/**
 * Evidence Chain Component & Callable Tests
 *
 * Validates that the new evidence chain components correctly implement
 * the capability-first evidence workflow:
 *   - EducatorEvidenceCapture links evidence to session occurrences
 *   - LearnerEvidenceSubmission captures artifacts, reflections, AI disclosure
 *   - CapabilityGuidancePanel interprets capability bands for guardians
 *   - verifyProofOfLearning callable exists and creates growth events
 */

import fs from 'fs';
import path from 'path';

const srcDir = path.join(process.cwd(), 'src');
const functionsDir = path.join(process.cwd(), 'functions', 'src');

function readSrcFile(...segments: string[]): string {
  return fs.readFileSync(path.join(srcDir, ...segments), 'utf8');
}

/* ───── EducatorEvidenceCapture session context ───── */

describe('EducatorEvidenceCapture session context linking', () => {
  const source = readSrcFile('components', 'evidence', 'EducatorEvidenceCapture.tsx');

  it('resolves site context through the shared active-site helper', () => {
    expect(source).toContain('resolveActiveSiteId');
    expect(source).not.toContain('const siteId = profile?.studioId ?? null;');
  });

  it('imports sessionOccurrencesCollection', () => {
    expect(source).toContain('sessionOccurrencesCollection');
  });

  it('imports sessionsCollection for time labels', () => {
    expect(source).toContain('sessionsCollection');
  });

  it('has selectedSessionOccurrenceId form state', () => {
    expect(source).toContain('selectedSessionOccurrenceId');
    expect(source).toContain('setSelectedSessionOccurrenceId');
  });

  it('includes sessionOccurrenceId in the addDoc call', () => {
    // The addDoc block should write sessionOccurrenceId
    const addDocBlock = source.slice(
      source.indexOf('await addDoc(evidenceRecordsCollection'),
      source.indexOf('} as Omit<EvidenceRecord', source.indexOf('await addDoc(evidenceRecordsCollection'))
    );
    expect(addDocBlock).toContain('sessionOccurrenceId');
  });

  it('queries today session occurrences by siteId and date range', () => {
    expect(source).toContain("where('siteId', '==', siteId)");
    expect(source).toContain('Timestamp.fromDate(todayStart)');
    expect(source).toContain('Timestamp.fromDate(todayEnd)');
  });

  it('queries learners by canonical siteIds membership', () => {
    expect(source).toContain("where('siteIds', 'array-contains', siteId)");
  });

  it('renders a session selector in the form', () => {
    expect(source).toContain('data-testid="evidence-session"');
  });

  it('keeps session selection sticky across logs', () => {
    // resetForm should NOT clear selectedSessionOccurrenceId
    const resetBlock = source.slice(
      source.indexOf('const resetForm'),
      source.indexOf('};', source.indexOf('const resetForm')) + 2
    );
    expect(resetBlock).not.toContain('setSelectedSessionOccurrenceId');
  });

  it('shows an explicit no-site blocked state', () => {
    expect(source).toContain('data-testid="evidence-capture-site-required"');
    expect(source).toContain('Select an active site before capturing evidence');
  });
});

/* ───── ProofOfLearningVerification site context ───── */

describe('ProofOfLearningVerification site context', () => {
  const source = readSrcFile('components', 'evidence', 'ProofOfLearningVerification.tsx');

  it('resolves site context through the shared active-site helper', () => {
    expect(source).toContain('resolveActiveSiteId');
    expect(source).not.toContain('const siteId = profile?.studioId ?? null;');
  });

  it('shows an explicit no-site blocked state', () => {
    expect(source).toContain('data-testid="proof-verification-site-required"');
    expect(source).toContain('Select an active site before reviewing proof-of-learning evidence.');
  });
});

/* ───── EducatorEvidenceReviewRenderer site context ───── */

describe('EducatorEvidenceReviewRenderer site context', () => {
  const source = readSrcFile(
    'features',
    'workflows',
    'renderers',
    'EducatorEvidenceReviewRenderer.tsx'
  );

  it('resolves site context through the shared active-site helper', () => {
    expect(source).toContain('resolveActiveSiteId');
    expect(source).not.toContain('const educatorSiteId = ctx.profile?.studioId || ctx.profile?.siteIds?.[0] || \'\';');
  });

  it('uses the resolved active site for rubric lookup and apply fallbacks', () => {
    expect(source).toContain('const siteId = mission?.siteId || educatorSiteId;');
    expect(source).not.toContain("ctx.profile?.siteIds?.[0] || ''");
  });

  it('shows an explicit no-site blocked state', () => {
    expect(source).toContain('data-testid="educator-review-site-required"');
    expect(source).toContain('Select an active site before reviewing learner evidence and applying rubric decisions.');
  });
});

/* ───── EducatorTodayRenderer site context ───── */

describe('EducatorTodayRenderer site context', () => {
  const source = readSrcFile(
    'features',
    'workflows',
    'renderers',
    'EducatorTodayRenderer.tsx'
  );

  it('resolves site context through the shared active-site helper', () => {
    expect(source).toContain('resolveActiveSiteId');
    expect(source).not.toContain('const siteId = ctx.profile?.siteIds?.[0] ?? null;');
    expect(source).not.toContain('const educatorSiteId = ctx.profile?.studioId || siteId || \'\';');
  });

  it('site-scopes today sessions, learner roster, and review queue counts', () => {
    expect(source).toContain("where('siteId', '==', educatorSiteId)");
    expect(source).toContain("where('siteIds', 'array-contains', educatorSiteId)");
    expect(source).toContain("where('status', 'in', ['submitted', 'pending_review'])");
  });

  it('passes the resolved site into quick evidence capture writes', () => {
    expect(source).toContain('siteId={educatorSiteId}');
  });

  it('shows an explicit no-site blocked state', () => {
    expect(source).toContain('data-testid="educator-today-site-required"');
    expect(source).toContain('Select an active site before capturing live classroom observations.');
  });
});

/* ───── LearnerEvidenceSubmission ───── */

describe('LearnerEvidenceSubmission component', () => {
  const source = readSrcFile('components', 'evidence', 'LearnerEvidenceSubmission.tsx');

  it('exists and is non-trivial', () => {
    expect(source.length).toBeGreaterThan(200);
  });

  it('resolves site context through the shared active-site helper', () => {
    expect(source).toContain('resolveActiveSiteId');
    expect(source).not.toContain('const siteId = profile?.studioId ?? null;');
  });

  it('supports artifact submission', () => {
    expect(source).toContain('artifact');
  });

  it('supports reflection submission', () => {
    expect(source).toContain('reflection');
  });

  it('supports checkpoint evidence submission', () => {
    expect(source).toContain("'checkpoint'");
    expect(source).toContain('handleSubmitCheckpoint');
    expect(source).toContain('data-testid="checkpoint-form"');
  });

  it('imports missionAttemptsCollection for checkpoint writes', () => {
    expect(source).toContain('missionAttemptsCollection');
  });

  it('loads missions for checkpoint selector', () => {
    expect(source).toContain('missionsCollection');
    expect(source).toContain('setMissions');
  });

  it('has mission selector in checkpoint form', () => {
    expect(source).toContain('data-testid="checkpoint-mission-select"');
    expect(source).toContain('checkpointMissionId');
  });

  it('writes checkpoint to missionAttempts with submitted status', () => {
    const handler = source.slice(
      source.indexOf('const handleSubmitCheckpoint'),
      source.indexOf('};', source.indexOf("setSuccessMessage('Checkpoint evidence submitted!')")) + 2
    );
    expect(handler).toContain('missionAttemptsCollection');
    expect(handler).toContain("status: 'submitted'");
  });

  it('also writes checkpoint to portfolio for visibility', () => {
    const handler = source.slice(
      source.indexOf('const handleSubmitCheckpoint'),
      source.indexOf('};', source.indexOf("setSuccessMessage('Checkpoint evidence submitted!')")) + 2
    );
    expect(handler).toContain('portfolioItemsCollection');
    expect(handler).toContain("source: 'checkpoint_submission'");
  });

  it('includes AI disclosure on checkpoint form', () => {
    expect(source).toContain('data-testid="checkpoint-ai-details"');
    expect(source).toContain('checkpointAiUsed');
  });

  it('captures AI disclosure', () => {
    expect(source).toContain('aiAssistanceUsed');
  });

  it('links to capabilities', () => {
    expect(source).toContain('capabilityId');
  });

  it('writes to portfolioItemsCollection', () => {
    expect(source).toContain('portfolioItemsCollection');
  });

  it('writes to learnerReflectionsCollection', () => {
    expect(source).toContain('learnerReflectionsCollection');
  });

  it('site-scopes learner portfolio reads', () => {
    expect(source).toContain("where('siteId', '==', siteId)");
  });

  it('site-scopes revision reads', () => {
    const revisionsBlock = source.slice(
      source.indexOf('const loadRevisions'),
      source.indexOf('const handleResubmit')
    );
    expect(revisionsBlock).toContain("where('siteId', '==', siteId)");
  });

  it('shows an explicit no-site blocked state', () => {
    expect(source).toContain('data-testid="learner-evidence-site-required"');
    expect(source).toContain('Select an active site before submitting learner evidence');
  });

  it('uses RoleRouteGuard for access control', () => {
    expect(source).toContain('RoleRouteGuard');
  });

  it('has three tab buttons (artifact, reflection, checkpoint)', () => {
    expect(source).toContain('Submit Artifact');
    expect(source).toContain('Write Reflection');
    expect(source).toContain('Checkpoint Evidence');
  });
});

/* ───── LearnerPortfolioBrowser ───── */

describe('LearnerPortfolioBrowser component', () => {
  const source = readSrcFile('components', 'evidence', 'LearnerPortfolioBrowser.tsx');

  it('resolves site context through the shared active-site helper', () => {
    expect(source).toContain('resolveActiveSiteId');
    expect(source).not.toContain('const siteId = profile?.studioId ?? null;');
  });

  it('site-scopes learner portfolio reads', () => {
    expect(source).toContain("where('siteId', '==', siteId)");
  });

  it('shows an explicit no-site blocked state', () => {
    expect(source).toContain('data-testid="portfolio-browser-site-required"');
    expect(source).toContain('Select an active site before browsing your portfolio evidence.');
  });
});

/* ───── CapabilityGuidancePanel ───── */

describe('CapabilityGuidancePanel guardian interpretation', () => {
  const source = readSrcFile('components', 'analytics', 'CapabilityGuidancePanel.tsx');

  it('exists and is non-trivial', () => {
    expect(source.length).toBeGreaterThan(150);
  });

  it('interprets capability bands', () => {
    // Should reference the mastery bands
    expect(source).toMatch(/strong|proficient|developing|emerging|beginning/i);
  });

  it('groups by pillar', () => {
    expect(source).toContain('pillar');
  });

  it('shows evidence counts', () => {
    expect(source).toContain('evidence');
  });

  it('provides parent-friendly explanations', () => {
    // Should not just show raw data
    expect(source).toMatch(/can do|able to|growth|progress/i);
  });
});

/* ───── ParentAnalyticsDashboard guardian honesty ───── */

describe('ParentAnalyticsDashboard guardian honesty', () => {
  const source = readSrcFile('components', 'analytics', 'ParentAnalyticsDashboard.tsx');

  it('uses shared active-site resolution', () => {
    expect(source).toContain('resolveActiveSiteId');
  });

  it('shows an explicit no-site blocked state', () => {
    expect(source).toContain('data-testid="parent-analytics-site-required"');
    expect(source).toContain('Select an active site before viewing supplemental engagement signals.');
  });

  it('frames engagement as secondary to evidence-backed capability judgments', () => {
    expect(source).toContain('These signals describe participation and motivation patterns.');
    expect(source).toContain('They do not replace');
    expect(source).toContain('evidence-backed capability, proof, or growth judgments.');
  });

  it('does not embed CapabilityGuidancePanel inside the engagement panel', () => {
    expect(source).not.toContain('CapabilityGuidancePanel');
  });
});

/* ───── verifyProofOfLearning callable ───── */

describe('verifyProofOfLearning callable', () => {
  const functionsSource = fs.readFileSync(
    path.join(functionsDir, 'index.ts'),
    'utf8'
  );

  it('exports verifyProofOfLearning as onCall', () => {
    expect(functionsSource).toContain('export const verifyProofOfLearning');
  });

  it('creates capability growth events atomically', () => {
    const section = functionsSource.slice(
      functionsSource.indexOf('export const verifyProofOfLearning'),
      functionsSource.indexOf(
        'export const',
        functionsSource.indexOf('export const verifyProofOfLearning') + 40
      )
    );
    expect(section).toContain('capabilityGrowthEvents');
    expect(section).toContain('batch');
  });

  it('upserts capability mastery', () => {
    const section = functionsSource.slice(
      functionsSource.indexOf('export const verifyProofOfLearning'),
      functionsSource.indexOf(
        'export const',
        functionsSource.indexOf('export const verifyProofOfLearning') + 40
      )
    );
    expect(section).toContain('capabilityMastery');
  });

  it('validates educator role', () => {
    const section = functionsSource.slice(
      functionsSource.indexOf('export const verifyProofOfLearning'),
      functionsSource.indexOf(
        'export const',
        functionsSource.indexOf('export const verifyProofOfLearning') + 40
      )
    );
    expect(section).toContain('educator');
  });
});

/* ───── EvidenceRecord schema sessionOccurrenceId ───── */

describe('EvidenceRecord schema supports session linking', () => {
  const schemaSource = readSrcFile('types', 'schema.ts');

  it('EvidenceRecord has sessionOccurrenceId field', () => {
    const erBlock = schemaSource.match(
      /export interface EvidenceRecord \{[\s\S]*?\n\}/
    )?.[0] ?? '';
    expect(erBlock).toContain('sessionOccurrenceId');
  });

  it('SessionOccurrence type exists with required fields', () => {
    const soBlock = schemaSource.match(
      /export interface SessionOccurrence \{[\s\S]*?\n\}/
    )?.[0] ?? '';
    expect(soBlock).toContain('sessionId');
    expect(soBlock).toContain('date');
    expect(soBlock).toContain('siteId');
    expect(soBlock).toContain('educatorId');
  });
});

/* ───── HQ capability framework site context ───── */

describe('HQ capability framework site context', () => {
  const editorSource = readSrcFile('components', 'capabilities', 'CapabilityFrameworkEditor.tsx');
  const hqRendererSource = readSrcFile('features', 'workflows', 'renderers', 'HqCapabilityFrameworkRenderer.tsx');
  const rubricRendererSource = readSrcFile('features', 'workflows', 'renderers', 'HqRubricBuilderRenderer.tsx');

  it('resolves site context through the shared active-site helper', () => {
    expect(editorSource).toContain('resolveActiveSiteId');
    expect(editorSource).not.toContain('const siteId = profile?.studioId ?? null;');
  });

  it('shows an explicit blocked state when no site is selected', () => {
    expect(editorSource).toContain('data-testid="hq-framework-site-required"');
    expect(editorSource).toContain('Select an active site before editing capabilities');
  });

  it('passes route site context into the HQ framework renderer', () => {
    expect(hqRendererSource).toContain('siteId={resolveActiveSiteId(ctx.profile)}');
  });

  it('passes route site context into the HQ rubric renderer', () => {
    expect(rubricRendererSource).toContain('siteId={resolveActiveSiteId(ctx.profile)}');
  });
});

/* ───── SiteEvidenceHealthDashboard ───── */

describe('SiteEvidenceHealthDashboard school health view', () => {
  const source = readSrcFile('components', 'analytics', 'SiteEvidenceHealthDashboard.tsx');

  it('exists and is non-trivial', () => {
    expect(source.length).toBeGreaterThan(200);
  });

  it('resolves site context through the shared active-site helper', () => {
    expect(source).toContain('resolveActiveSiteId');
    expect(source).not.toContain('const siteId = profile?.activeSiteId ?? profile?.studioId ?? null;');
  });

  it('queries evidence records by site and period', () => {
    expect(source).toContain('evidenceRecordsCollection');
    expect(source).toContain("where('siteId', '==', siteId)");
  });

  it('queries learners and educators by canonical site membership', () => {
    expect(source).toContain("where('siteIds', 'array-contains', siteId)");
  });

  it('calculates learner coverage', () => {
    expect(source).toContain('learnersWithEvidence');
  });

  it('shows per-educator breakdown', () => {
    expect(source).toContain('educatorMetrics');
    expect(source).toContain('data-testid="evidence-health-educators"');
  });

  it('tracks capability mapping rate', () => {
    expect(source).toContain('capabilityMappedRate');
  });

  it('tracks rubric application rate', () => {
    expect(source).toContain('rubricAppliedRate');
  });

  it('alerts on low coverage', () => {
    expect(source).toContain('data-testid="evidence-health-alert"');
  });

  it('shows an explicit no-site blocked state', () => {
    expect(source).toContain('data-testid="evidence-health-site-required"');
    expect(source).toContain('Select an active site before reviewing school evidence health.');
  });

  it('uses RoleRouteGuard for site/hq access', () => {
    expect(source).toContain('RoleRouteGuard');
    expect(source).toContain("'site'");
    expect(source).toContain("'hq'");
  });
});

/* ───── Collections exports for evidence chain ───── */

describe('Evidence chain collection exports completeness', () => {
  const collectionsSource = readSrcFile('firebase', 'firestore', 'collections.ts');

  const evidenceCollections = [
    'sessionOccurrencesCollection',
    'sessionsCollection',
    'evidenceRecordsCollection',
    'portfolioItemsCollection',
    'learnerReflectionsCollection',
    'capabilityGrowthEventsCollection',
    'capabilityMasteryCollection',
    'rubricApplicationsCollection',
    'rubricTemplatesCollection',
  ];

  for (const name of evidenceCollections) {
    it(`exports ${name}`, () => {
      expect(collectionsSource).toContain(`export const ${name}`);
    });
  }
});

/* ───── CapabilityFrameworkEditor unit/checkpoint mapping ───── */

describe('CapabilityFrameworkEditor unit mapping', () => {
  const source = readSrcFile('components', 'capabilities', 'CapabilityFrameworkEditor.tsx');

  it('includes unitMappings in capability form data', () => {
    expect(source).toContain('unitMappings');
  });

  it('imports missionsCollection for unit selector', () => {
    expect(source).toContain('missionsCollection');
  });

  it('loads missions data', () => {
    expect(source).toContain('setMissions');
    expect(source).toMatch(/useState<Mission\[\]>/);
  });

  it('renders mission checkboxes for mapping', () => {
    expect(source).toContain('missions.map');
  });

  it('saves unitMappings on create', () => {
    const createBlock = source.slice(
      source.indexOf('await addDoc(capabilitiesCollection'),
      source.indexOf(');', source.indexOf('await addDoc(capabilitiesCollection')) + 1
    );
    expect(createBlock).toContain('unitMappings');
  });

  it('saves unitMappings on update', () => {
    const updateBlock = source.slice(
      source.indexOf('await updateDoc('),
      source.indexOf(');', source.indexOf('await updateDoc(')) + 1
    );
    expect(updateBlock).toContain('unitMappings');
  });

  it('populates unitMappings when editing existing capability', () => {
    expect(source).toContain('unitMappings: cap.unitMappings');
  });
});
