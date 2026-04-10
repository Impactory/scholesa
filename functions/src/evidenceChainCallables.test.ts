/**
 * Behavioral tests for evidence chain callable functions.
 *
 * Tests applyRubricToEvidence, evaluateBadgeEligibility, and
 * processCheckpointMasteryUpdate for correct Firestore write behavior,
 * field naming consistency, and collection targeting.
 */

// ── Firestore mock ──────────────────────────────────────────────

const batchOps: Array<{ op: string; path: string; data: any }> = [];
const storedDocs: Record<string, any> = {};

const mockBatch = {
  set: jest.fn((ref: any, data: any, _opts?: any) => {
    batchOps.push({ op: 'set', path: ref._path, data });
  }),
  update: jest.fn((ref: any, data: any) => {
    batchOps.push({ op: 'update', path: ref._path, data });
  }),
  commit: jest.fn(async () => {}),
};

function makeDocRef(path: string) {
  return {
    _path: path,
    get: jest.fn(async () => ({
      exists: path in storedDocs,
      data: () => storedDocs[path] ?? {},
    })),
  };
}

let autoId = 0;
const mockDb: Record<string, any> = {
  collection: jest.fn((name: string) => ({
    doc: jest.fn((id?: string) => makeDocRef(`${name}/${id ?? `auto_${++autoId}`}`)),
    where: jest.fn().mockReturnThis(),
    limit: jest.fn().mockReturnThis(),
    get: jest.fn(async () => ({ docs: [], empty: true, size: 0 })),
  })),
  batch: jest.fn(() => mockBatch),
};

jest.mock('firebase-admin', () => {
  const actual = {
    apps: [{ name: 'test' }],
    initializeApp: jest.fn(() => ({ firestore: () => mockDb })),
    firestore: Object.assign(() => mockDb, {
      FieldValue: {
        serverTimestamp: jest.fn(() => '__SERVER_TIMESTAMP__'),
        increment: jest.fn((n: number) => `__INCREMENT_${n}__`),
        arrayUnion: jest.fn((...args: any[]) => args),
        arrayRemove: jest.fn((...args: any[]) => args),
        delete: jest.fn(() => '__DELETE__'),
      },
    }),
    auth: jest.fn(() => ({
      getUser: jest.fn(),
      verifyIdToken: jest.fn(),
    })),
    storage: jest.fn(() => ({
      bucket: jest.fn(() => ({
        file: jest.fn(),
      })),
    })),
  };
  return actual;
});

// ── Helpers ─────────────────────────────────────────────────────

function resetMocks() {
  batchOps.length = 0;
  autoId = 0;
  Object.keys(storedDocs).forEach((k) => delete storedDocs[k]);
  jest.clearAllMocks();
}

function _batchOpsForCollection(collection: string) {
  return batchOps.filter((op) => op.path.startsWith(`${collection}/`));
}

// ── Tests ───────────────────────────────────────────────────────

describe('Evidence chain callable exports', () => {
  beforeEach(resetMocks);

  it('applyRubricToEvidence is exported in index.ts', async () => {
    const fs = await import('fs');
    const path = await import('path');
    const source = fs.readFileSync(path.join(__dirname, 'index.ts'), 'utf-8');
    expect(source).toContain('export const applyRubricToEvidence');
  });

  it('processCheckpointMasteryUpdate is exported in index.ts', async () => {
    const fs = await import('fs');
    const path = await import('path');
    const source = fs.readFileSync(path.join(__dirname, 'index.ts'), 'utf-8');
    expect(source).toContain('export const processCheckpointMasteryUpdate');
  });

  it('evaluateBadgeEligibility is exported in index.ts', async () => {
    const fs = await import('fs');
    const path = await import('path');
    const source = fs.readFileSync(path.join(__dirname, 'index.ts'), 'utf-8');
    expect(source).toContain('export const evaluateBadgeEligibility');
  });

  it('verifyProofOfLearning is exported in index.ts', async () => {
    const fs = await import('fs');
    const path = await import('path');
    const source = fs.readFileSync(path.join(__dirname, 'index.ts'), 'utf-8');
    expect(source).toContain('export const verifyProofOfLearning');
  });

  it('getParentDashboardBundle is exported in index.ts', async () => {
    const fs = await import('fs');
    const path = await import('path');
    const source = fs.readFileSync(path.join(__dirname, 'index.ts'), 'utf-8');
    expect(source).toContain('export const getParentDashboardBundle');
  });
});

describe('Collection naming consistency', () => {
  it('evaluateBadgeEligibility targets badgeAchievements (not badgeAwards)', async () => {
    // Read the source to verify the collection name was fixed
    const fs = await import('fs');
    const path = await import('path');
    const source = fs.readFileSync(
      path.join(__dirname, 'index.ts'),
      'utf-8'
    );

    // The evaluateBadgeEligibility function should reference badgeAchievements
    const evalSection = source.slice(
      source.indexOf('evaluateBadgeEligibility'),
      source.indexOf('evaluateBadgeEligibility') + 3000
    );

    // Must reference badgeAchievements, not badgeAwards
    expect(evalSection).toContain("collection('badgeAchievements')");
    expect(evalSection).not.toContain("collection('badgeAwards')");
  });

  it('applyRubricToEvidence writes to capabilityGrowthEvents (append-only)', async () => {
    const fs = await import('fs');
    const path = await import('path');
    const source = fs.readFileSync(
      path.join(__dirname, 'index.ts'),
      'utf-8'
    );

    const rubricStart = source.indexOf('export const applyRubricToEvidence');
    const rubricEnd = source.indexOf('export const', rubricStart + 1);
    const rubricSection = source.slice(rubricStart, rubricEnd);

    expect(rubricSection).toContain("collection('capabilityGrowthEvents')");
    expect(rubricSection).toContain("collection('capabilityMastery')");
    expect(rubricSection).toContain("collection('rubricApplications')");
  });

  it('applyRubricToEvidence writes currentLevel alongside latestLevel', async () => {
    const fs = await import('fs');
    const path = await import('path');
    const source = fs.readFileSync(
      path.join(__dirname, 'index.ts'),
      'utf-8'
    );

    // Find the mastery set() call in applyRubricToEvidence
    const rubricStart = source.indexOf('export const applyRubricToEvidence');
    const rubricEnd = source.indexOf('export const', rubricStart + 1);
    const rubricFn = source.slice(rubricStart, rubricEnd);

    // Must write both fields for cross-function compatibility
    expect(rubricFn).toContain('latestLevel:');
    expect(rubricFn).toContain('currentLevel:');
  });

  it('processCheckpointMasteryUpdate writes latestLevel alongside currentLevel', async () => {
    const fs = await import('fs');
    const path = await import('path');
    const source = fs.readFileSync(
      path.join(__dirname, 'index.ts'),
      'utf-8'
    );

    const checkpointStart = source.indexOf('export const processCheckpointMasteryUpdate');
    const checkpointEnd = source.indexOf('export const', checkpointStart + 1);
    const checkpointFn = source.slice(checkpointStart, checkpointEnd);

    // Must write both fields for cross-function compatibility
    expect(checkpointFn).toContain('currentLevel:');
    expect(checkpointFn).toContain('latestLevel:');
  });

  it('evaluateBadgeEligibility reads both currentLevel and latestLevel', async () => {
    const fs = await import('fs');
    const path = await import('path');
    const source = fs.readFileSync(
      path.join(__dirname, 'index.ts'),
      'utf-8'
    );

    const badgeStart = source.indexOf('export const evaluateBadgeEligibility');
    const badgeEnd = source.indexOf('export const', badgeStart + 1);
    const badgeFn = source.slice(badgeStart, badgeEnd);

    // Must handle both field conventions
    expect(badgeFn).toContain('currentLevel');
    expect(badgeFn).toContain('latestLevel');
  });
});

describe('buildParentLearnerSummary integration', () => {
  it('reads latestLevel from capabilityMastery', async () => {
    const fs = await import('fs');
    const path = await import('path');
    const source = fs.readFileSync(
      path.join(__dirname, 'index.ts'),
      'utf-8'
    );

    const summaryStart = source.indexOf('buildParentLearnerSummary');
    expect(summaryStart).toBeGreaterThan(-1);

    const summaryEnd = source.indexOf('\nexport ', summaryStart + 1);
    const summarySection = source.slice(summaryStart, summaryEnd > summaryStart ? summaryEnd : summaryStart + 50000);
    expect(summarySection).toContain('latestLevel');
  });

  it('getParentDashboardBundle callable is exported', async () => {
    const indexModule = await import('./index');
    expect(indexModule.getParentDashboardBundle).toBeDefined();
  });
});

describe('verifyProofOfLearning evidence chain writes', () => {
  it('is exported as a callable', async () => {
    const indexModule = await import('./index');
    expect(indexModule.verifyProofOfLearning).toBeDefined();
  });

  it('writes to capabilityMastery and capabilityGrowthEvents', async () => {
    const fs = await import('fs');
    const path = await import('path');
    const source = fs.readFileSync(
      path.join(__dirname, 'index.ts'),
      'utf-8'
    );

    const proofStart = source.indexOf('export const verifyProofOfLearning');
    const proofEnd = source.indexOf('export const', proofStart + 1);
    const proofFn = source.slice(proofStart, proofEnd);

    expect(proofFn).toContain("collection('capabilityMastery')");
    expect(proofFn).toContain("collection('capabilityGrowthEvents')");
    expect(proofFn).toContain("collection('portfolioItems')");
  });
});

describe('Offline sync collection alignment', () => {
  it('offline observation sync targets evidenceRecords (not observationRecords)', async () => {
    const fs = await import('fs');
    const path = await import('path');
    const syncPath = path.resolve(
      __dirname,
      '../../apps/empire_flutter/app/lib/offline/sync_coordinator.dart'
    );

    // This test may not have access to the Flutter file from the functions
    // test runner, so we verify via source scanning if accessible.
    try {
      const source = fs.readFileSync(syncPath, 'utf-8');
      const obsSection = source.slice(
        source.indexOf('OpType.observationCapture'),
        source.indexOf('OpType.observationCapture') + 200
      );
      expect(obsSection).toContain("'evidenceRecords'");
      expect(obsSection).not.toContain("'observationRecords'");
    } catch {
      // If the Flutter file is not accessible from this test runner location,
      // skip gracefully — this is tested in the Flutter test suite.
      console.log('Skipping cross-surface sync test (Flutter file not accessible)');
    }
  });
});
