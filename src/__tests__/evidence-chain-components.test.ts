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
});

/* ───── LearnerEvidenceSubmission ───── */

describe('LearnerEvidenceSubmission component', () => {
  const source = readSrcFile('components', 'evidence', 'LearnerEvidenceSubmission.tsx');

  it('exists and is non-trivial', () => {
    expect(source.length).toBeGreaterThan(200);
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

  it('uses RoleRouteGuard for access control', () => {
    expect(source).toContain('RoleRouteGuard');
  });

  it('has three tab buttons (artifact, reflection, checkpoint)', () => {
    expect(source).toContain('Submit Artifact');
    expect(source).toContain('Write Reflection');
    expect(source).toContain('Checkpoint Evidence');
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

/* ───── SiteEvidenceHealthDashboard ───── */

describe('SiteEvidenceHealthDashboard school health view', () => {
  const source = readSrcFile('components', 'analytics', 'SiteEvidenceHealthDashboard.tsx');

  it('exists and is non-trivial', () => {
    expect(source.length).toBeGreaterThan(200);
  });

  it('queries evidence records by site and period', () => {
    expect(source).toContain('evidenceRecordsCollection');
    expect(source).toContain("where('siteId', '==', siteId)");
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
