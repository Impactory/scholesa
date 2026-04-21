/**
 * Evidence Chain Integration Tests
 *
 * Validates schema integrity, route definitions, component existence,
 * and data normalization for the capability-first evidence chain:
 *   Admin-HQ setup → session runtime → educator observation →
 *   learner artifact → proof-of-learning → rubric/capability mapping →
 *   capability growth → portfolio → passport/report → guardian interpretation
 */

import fs from 'fs';
import path from 'path';

/* ───── Schema contracts ───── */

describe('Evidence chain schema contracts', () => {
  const schemaPath = path.join(process.cwd(), 'src', 'types', 'schema.ts');
  const schemaSource = fs.readFileSync(schemaPath, 'utf8');

  it('Capability type has progressionDescriptors for rubric alignment', () => {
    const capabilityBlock = schemaSource.match(
      /export interface Capability \{[\s\S]*?\n\}/
    )?.[0] ?? '';
    expect(capabilityBlock).toContain('progressionDescriptors');
    expect(capabilityBlock).toContain('rubricTemplateId');
    expect(capabilityBlock).toContain('sortOrder');
    expect(capabilityBlock).toContain("status?: 'active' | 'archived'");
  });

  it('ProgressionDescriptors defines four mastery levels', () => {
    const pdBlock = schemaSource.match(
      /export interface ProgressionDescriptors \{[\s\S]*?\n\}/
    )?.[0] ?? '';
    expect(pdBlock).toContain('beginning: string');
    expect(pdBlock).toContain('developing: string');
    expect(pdBlock).toContain('proficient: string');
    expect(pdBlock).toContain('advanced: string');
  });

  it('RubricTemplate connects criteria to capabilities', () => {
    const rtBlock = schemaSource.match(
      /export interface RubricTemplate \{[\s\S]*?\n\}/
    )?.[0] ?? '';
    expect(rtBlock).toContain('capabilityIds: string[]');
    expect(rtBlock).toContain('criteria: RubricTemplateCriterion[]');
    expect(rtBlock).toContain('siteId');
  });

  it('RubricTemplateCriterion maps to capability and pillar', () => {
    const rcBlock = schemaSource.match(
      /export interface RubricTemplateCriterion \{[\s\S]*?\n\}/
    )?.[0] ?? '';
    expect(rcBlock).toContain('capabilityId: string');
    expect(rcBlock).toContain('pillarCode');
    expect(rcBlock).toContain('maxScore: number');
    expect(rcBlock).toContain('descriptors?: ProgressionDescriptors');
  });

  it('PortfolioItem carries verification and proof-of-learning fields', () => {
    const piBlock = schemaSource.match(
      /export interface PortfolioItem \{[\s\S]*?\n\}/
    )?.[0] ?? '';
    expect(piBlock).toContain('verificationStatus');
    expect(piBlock).toContain('proofOfLearningStatus');
    expect(piBlock).toContain('proofHasExplainItBack');
    expect(piBlock).toContain('proofExplainItBackExcerpt');
    expect(piBlock).toContain('capabilityTitles');
  });

  it('ProofOfLearningBundle carries site provenance and pending review state', () => {
    const pbBlock = schemaSource.match(
      /export interface ProofOfLearningBundle \{[\s\S]*?\n\}/
    )?.[0] ?? '';
    expect(pbBlock).toContain('siteId');
    expect(pbBlock).toContain("'pending_review'");
  });

  it('EvidenceRecord links to capability and educator', () => {
    const erBlock = schemaSource.match(
      /export interface EvidenceRecord \{[\s\S]*?\n\}/
    )?.[0] ?? '';
    expect(erBlock).toContain('capabilityId');
    expect(erBlock).toContain('educatorId');
    expect(erBlock).toContain('learnerId');
    expect(erBlock).toContain('siteId');
  });

  it('CapabilityGrowthEvent tracks level progression', () => {
    const cgeBlock = schemaSource.match(
      /export interface CapabilityGrowthEvent \{[\s\S]*?\n\}/
    )?.[0] ?? '';
    expect(cgeBlock).toContain('capabilityId');
    expect(cgeBlock).toContain('level');
    expect(cgeBlock).toContain('learnerId');
  });

  it('CapabilityMastery represents latest mastery state', () => {
    const cmBlock = schemaSource.match(
      /export interface CapabilityMastery \{[\s\S]*?\n\}/
    )?.[0] ?? '';
    expect(cmBlock).toContain('capabilityId');
    expect(cmBlock).toContain('latestLevel');
    expect(cmBlock).toContain('learnerId');
  });
});

/* ───── Collection exports ───── */

describe('Evidence chain Firestore collections', () => {
  const collectionsPath = path.join(
    process.cwd(),
    'src',
    'firebase',
    'firestore',
    'collections.ts'
  );
  const collectionsSource = fs.readFileSync(collectionsPath, 'utf8');

  const requiredCollections = [
    'evidenceRecordsCollection',
    'portfolioItemsCollection',
    'capabilityGrowthEventsCollection',
    'capabilityMasteryCollection',
    'rubricTemplatesCollection',
    // proofOfLearningBundles is accessed via raw collection() path, not a typed export
  ];

  for (const name of requiredCollections) {
    it(`exports ${name}`, () => {
      expect(collectionsSource).toContain(name);
    });
  }
});

/* ───── Route definitions ───── */

describe('Evidence chain route definitions', () => {
  const routesPath = path.join(
    process.cwd(),
    'src',
    'lib',
    'routing',
    'workflowRoutes.ts'
  );
  const routesSource = fs.readFileSync(routesPath, 'utf8');

  const evidenceRoutes = [
    { path: '/hq/capabilities', roles: ['hq'] },
    { path: '/educator/verification', roles: ['educator'] },
    { path: '/parent/passport', roles: ['parent'] },
    { path: '/educator/evidence', roles: ['educator'] },
    { path: '/parent/portfolio', roles: ['parent'] },
  ];

  for (const route of evidenceRoutes) {
    it(`registers ${route.path} in ALL_WORKFLOW_PATHS`, () => {
      expect(routesSource).toContain(`'${route.path}'`);
    });

    it(`defines ${route.path} with correct role access`, () => {
      const defRegex = new RegExp(
        `path:\\s*'${route.path.replace(/\//g, '\\/')}',\\s*\\n\\s*title:\\s*'[^']+',\\s*\\n\\s*description:\\s*'[^']+',\\s*\\n\\s*allowedRoles:\\s*\\[([^\\]]+)\\]`
      );
      const match = routesSource.match(defRegex);
      expect(match).toBeTruthy();
      const rolesStr = match?.[1] ?? '';
      for (const role of route.roles) {
        expect(rolesStr).toContain(`'${role}'`);
      }
    });
  }
});

/* ───── Route page files exist ───── */

describe('Evidence chain route pages exist', () => {
  const appDir = path.join(process.cwd(), 'app', '[locale]', '(protected)');

  const pages = [
    'hq/capabilities/page.tsx',
    'educator/today/page.tsx',
    'educator/verification/page.tsx',
    'parent/passport/page.tsx',
    'site/evidence-health/page.tsx',
  ];

  for (const pagePath of pages) {
    it(`${pagePath} exists`, () => {
      const fullPath = path.join(appDir, pagePath);
      expect(fs.existsSync(fullPath)).toBe(true);
    });
  }

  it('parent/passport/page.tsx routes through WorkflowRoutePage instead of learner export', () => {
    const fullPath = path.join(appDir, 'parent', 'passport', 'page.tsx');
    const source = fs.readFileSync(fullPath, 'utf8');
    expect(source).toContain('WorkflowRoutePage');
    expect(source).toContain("routePath='/parent/passport'");
    expect(source).not.toContain('LearnerPassportExport');
  });

  it('educator/today/page.tsx routes through WorkflowRoutePage instead of the legacy dashboard', () => {
    const fullPath = path.join(appDir, 'educator', 'today', 'page.tsx');
    const source = fs.readFileSync(fullPath, 'utf8');
    expect(source).toContain('WorkflowRoutePage');
    expect(source).toContain("routePath='/educator/today'");
    expect(source).not.toContain('EducatorDashboardToday');
  });

  it('site/evidence-health/page.tsx routes through WorkflowRoutePage', () => {
    const fullPath = path.join(appDir, 'site', 'evidence-health', 'page.tsx');
    const source = fs.readFileSync(fullPath, 'utf8');
    expect(source).toContain('WorkflowRoutePage');
    expect(source).toContain("routePath='/site/evidence-health'");
    expect(source).not.toContain('SiteEvidenceHealthDashboard');
  });
});

/* ───── Component files exist ───── */

describe('Evidence chain components exist', () => {
  const srcDir = path.join(process.cwd(), 'src', 'components');

  const components = [
    'capabilities/CapabilityFrameworkEditor.tsx',
    'evidence/ProofOfLearningVerification.tsx',
    'passport/LearnerPassportExport.tsx',
  ];

  for (const componentPath of components) {
    it(`${componentPath} exists and is non-empty`, () => {
      const fullPath = path.join(srcDir, componentPath);
      expect(fs.existsSync(fullPath)).toBe(true);
      const content = fs.readFileSync(fullPath, 'utf8');
      expect(content.length).toBeGreaterThan(100);
    });
  }
});

/* ───── Firestore rules ───── */

describe('Evidence chain Firestore rules', () => {
  const rulesPath = path.join(process.cwd(), 'firestore.rules');
  const rulesSource = fs.readFileSync(rulesPath, 'utf8');

  const requiredCollections = [
    'evidenceRecords',
    'portfolioItems',
    'checkpoints',
    'capabilityGrowthEvents',
    'capabilityMastery',
    'rubricTemplates',
    'rubricApplications',
    'proofOfLearningBundles',
    'checkpointVerifications',
  ];

  for (const collection of requiredCollections) {
    it(`has rules for ${collection}`, () => {
      expect(rulesSource).toContain(collection);
    });
  }

  it('rubricTemplates restricts writes to HQ', () => {
    const rubricRulesBlock = rulesSource.slice(
      rulesSource.indexOf('match /rubricTemplates/'),
      rulesSource.indexOf('}', rulesSource.indexOf('match /rubricTemplates/') + 100) + 1
    );
    expect(rubricRulesBlock).toContain('isHQ()');
  });
});

/* ───── Functions backend evidence chain ───── */

describe('Functions backend evidence chain callables', () => {
  const functionsPath = path.join(process.cwd(), 'functions', 'src', 'index.ts');
  const functionsSource = fs.readFileSync(functionsPath, 'utf8');

  const requiredCallables = [
    'getParentDashboardBundle',
    'applyRubricToEvidence',
  ];

  for (const name of requiredCallables) {
    it(`exports ${name} as onCall`, () => {
      expect(functionsSource).toContain(`export const ${name}`);
      expect(functionsSource).toContain('onCall(');
    });
  }

  it('buildParentLearnerSummary produces passport claims', () => {
    expect(functionsSource).toContain('passportClaims');
    expect(functionsSource).toContain('ideationPassport');
    expect(functionsSource).toContain('growthTimeline');
    expect(functionsSource).toContain('portfolioItemsPreview');
    expect(functionsSource).toContain('evidenceSummary');
    expect(functionsSource).toContain('capabilitySnapshot');
    expect(functionsSource).toContain('row.proofExplainItBackExcerpt');
    expect(functionsSource).toContain('proofBundle?.explainItBackExcerpt');
  });

  it('applyRubricToEvidence gates growth on verified proof-of-learning', () => {
    const applyRubricSection = functionsSource.slice(
      functionsSource.indexOf('export const applyRubricToEvidence'),
      functionsSource.indexOf(
        'export const',
        functionsSource.indexOf('export const applyRubricToEvidence') + 10
      )
    );

    expect(applyRubricSection).toContain("'failed-precondition'");
    expect(applyRubricSection).toContain('Verify proof-of-learning before applying a rubric that updates capability growth.');
    expect(applyRubricSection).toContain('proofOfLearningStatus');
    expect(applyRubricSection).toContain('portfolioItems');
    expect(applyRubricSection).toContain('verificationStatus');
  });

  it('processCheckpointMasteryUpdate refuses checkpoint growth before verified proof', () => {
    const checkpointSection = functionsSource.slice(
      functionsSource.indexOf('export const processCheckpointMasteryUpdate'),
      functionsSource.indexOf(
        'export const',
        functionsSource.indexOf('export const processCheckpointMasteryUpdate') + 10
      )
    );

    expect(checkpointSection).toContain('portfolioItemId');
    expect(checkpointSection).toContain('checkpointDefinitionId');
    expect(checkpointSection).toContain("collection('checkpoints')");
    expect(checkpointSection).toContain('proofOfLearningStatus');
    expect(checkpointSection).toContain('HQ-authored checkpoint definition');
    expect(checkpointSection).toContain('Verify proof-of-learning for the linked checkpoint artifact before updating capability growth.');
    expect(checkpointSection).toContain('Checkpoint growth is recorded from proof verification on the linked portfolio artifact.');
  });
});

/* ───── Parent dashboard API types ───── */

describe('Parent dashboard API passport support', () => {
  const apiPath = path.join(
    process.cwd(),
    'src',
    'lib',
    'dashboard',
    'roleDashboardApi.ts'
  );
  const apiSource = fs.readFileSync(apiPath, 'utf8');

  it('exports fetchParentDashboardBundle', () => {
    expect(apiSource).toContain('export async function fetchParentDashboardBundle');
  });

  it('ParentDashboardBundle type includes ideationPassport', () => {
    expect(apiSource).toContain('ideationPassport');
  });

  it('ParentDashboardBundle type includes capabilitySnapshot', () => {
    expect(apiSource).toContain('capabilitySnapshot');
  });

  it('calls getParentDashboardBundle callable', () => {
    expect(apiSource).toContain("httpsCallable(functions, 'getParentDashboardBundle')");
  });
});
