const SERVER_TIMESTAMP = Symbol('serverTimestamp');
const DELETE_FIELD = Symbol('deleteField');

class MockTimestamp {
  constructor(private readonly millis: number) {}

  toMillis(): number {
    return this.millis;
  }

  static fromMillis(millis: number): MockTimestamp {
    return new MockTimestamp(millis);
  }
}

type StoredDoc = Record<string, unknown>;
type CollectionStore = Map<string, StoredDoc>;

let writeCounter = 0;
const database = new Map<string, CollectionStore>();

function nextWriteMillis(): number {
  writeCounter += 1;
  return 1711000000000 + writeCounter;
}

function clearDatabase(): void {
  database.clear();
  writeCounter = 0;
}

function ensureCollection(name: string): CollectionStore {
  const existing = database.get(name);
  if (existing) {
    return existing;
  }
  const created = new Map<string, StoredDoc>();
  database.set(name, created);
  return created;
}

function cloneValue<T>(value: T): T {
  return JSON.parse(JSON.stringify(value)) as T;
}

function materializeWrite(input: Record<string, unknown>): Record<string, unknown> {
  const output: Record<string, unknown> = {};
  Object.entries(input).forEach(([key, value]) => {
    if (value === DELETE_FIELD) {
      return;
    }
    if (value === SERVER_TIMESTAMP) {
      output[key] = nextWriteMillis();
      return;
    }
    output[key] = cloneValue(value);
  });
  return output;
}

function mergeWrite(
  existing: Record<string, unknown> | undefined,
  input: Record<string, unknown>,
): Record<string, unknown> {
  const base = existing ? cloneValue(existing) : {};
  Object.entries(input).forEach(([key, value]) => {
    if (value === DELETE_FIELD) {
      delete base[key];
      return;
    }
    if (value === SERVER_TIMESTAMP) {
      base[key] = nextWriteMillis();
      return;
    }
    base[key] = cloneValue(value);
  });
  return base;
}

function seedCollection(name: string, docs: Record<string, StoredDoc>): void {
  const store = ensureCollection(name);
  Object.entries(docs).forEach(([id, data]) => {
    store.set(id, cloneValue(data));
  });
}

class MockDocumentReference {
  constructor(
    private readonly collectionName: string,
    public readonly id: string,
  ) {}

  async get(): Promise<MockDocumentSnapshot> {
    return new MockDocumentSnapshot(this, ensureCollection(this.collectionName).get(this.id));
  }

  async set(data: Record<string, unknown>, options?: { merge?: boolean }): Promise<void> {
    const store = ensureCollection(this.collectionName);
    const next = options?.merge
      ? mergeWrite(store.get(this.id), data)
      : materializeWrite(data);
    store.set(this.id, next);
  }
}

class MockDocumentSnapshot {
  constructor(
    public readonly ref: MockDocumentReference,
    private readonly record: StoredDoc | undefined,
  ) {}

  get exists(): boolean {
    return this.record != null;
  }

  data(): StoredDoc | undefined {
    return this.record == null ? undefined : cloneValue(this.record);
  }
}

class MockTransaction {
  set(ref: MockDocumentReference, data: Record<string, unknown>, options?: { merge?: boolean }): void {
    const store = ensureCollection((ref as unknown as { collectionName?: string }).collectionName || '');
    const next = options?.merge ? mergeWrite(store.get(ref.id), data) : materializeWrite(data);
    store.set(ref.id, next);
  }
}

class MockCollectionReference {
  constructor(private readonly collectionName: string) {}

  doc(id: string): MockDocumentReference {
    return new MockDocumentReference(this.collectionName, id);
  }

  async add(data: Record<string, unknown>): Promise<MockDocumentReference> {
    const store = ensureCollection(this.collectionName);
    const id = `${this.collectionName}_${store.size + 1}`;
    const ref = new MockDocumentReference(this.collectionName, id);
    await ref.set(data);
    return ref;
  }
}

const firestoreRoot = {
  collection: (name: string) => new MockCollectionReference(name),
  runTransaction: async <T>(handler: (transaction: MockTransaction) => Promise<T>): Promise<T> => {
    const transaction = new MockTransaction();
    return handler(transaction);
  },
};

const mockFirestore = Object.assign(jest.fn(() => firestoreRoot), {
  FieldValue: undefined,
  Timestamp: undefined,
});

jest.mock('firebase-admin', () => ({
  firestore: mockFirestore,
}));

jest.mock('firebase-admin/firestore', () => ({
  FieldValue: {
    serverTimestamp: jest.fn(() => SERVER_TIMESTAMP),
    delete: jest.fn(() => DELETE_FIELD),
  },
  Timestamp: MockTimestamp,
}));

class MockHttpsError extends Error {
  constructor(public readonly code: string, message: string) {
    super(message);
    this.name = 'HttpsError';
  }
}

jest.mock('firebase-functions/v2/https', () => ({
  HttpsError: MockHttpsError,
  onCall: jest.fn((handler: unknown) => handler),
}));

jest.mock('./ltiIntegration', () => ({
  buildLtiGradePassbackAuditLog: jest.fn(),
  buildLtiGradePassbackJob: jest.fn(),
  normalizeIntegrationProvider: jest.fn(),
}));

jest.mock('./districtProviderIntegration', () => ({
  buildDistrictConnectionDocId: jest.fn(),
  districtProviderAuditAction: jest.fn(),
  districtProviderDefaultAuthBaseUrl: jest.fn(),
  districtProviderDisplayName: jest.fn(),
  districtProviderRosterSyncJobType: jest.fn(),
  districtProviderSchoolField: jest.fn(),
  districtProviderSectionsField: jest.fn(),
}));

import {
  buildFederatedLearningCandidatePromotionRecordDocId,
  buildFederatedLearningExperimentReviewRecordDocId,
  buildFederatedLearningPilotApprovalRecordDocId,
  buildFederatedLearningPilotEvidenceRecordDocId,
  buildFederatedLearningPilotExecutionRecordDocId,
} from './federatedLearningPrototype';
import {
  upsertFederatedLearningPilotApprovalRecord,
  upsertFederatedLearningPilotEvidenceRecord,
  upsertFederatedLearningPilotExecutionRecord,
} from './workflowOps';

type TestCallable = (request: { auth?: { uid?: string }; data?: Record<string, unknown> }) => Promise<unknown>;

const upsertEvidence = upsertFederatedLearningPilotEvidenceRecord as unknown as TestCallable;
const upsertApproval = upsertFederatedLearningPilotApprovalRecord as unknown as TestCallable;
const upsertExecution = upsertFederatedLearningPilotExecutionRecord as unknown as TestCallable;

function buildRequest(data: Record<string, unknown>) {
  return {
    auth: { uid: 'hq-1' },
    data,
  };
}

function basePackage(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    experimentId: 'fl_exp_1',
    aggregationRunId: 'fl_agg_1',
    mergeArtifactId: 'fl_merge_1',
    ...overrides,
  };
}

describe('workflowOps pilot lifecycle', () => {
  beforeEach(() => {
    clearDatabase();
    seedCollection('users', {
      'hq-1': {
        role: 'hq',
        siteIds: ['site-1', 'site-2'],
        activeSiteId: 'site-1',
      },
    });
    seedCollection('federatedLearningExperiments', {
      fl_exp_1: {
        allowedSiteIds: ['site-1', 'site-2'],
      },
    });
    seedCollection('federatedLearningCandidateModelPackages', {
      fl_pkg_1: basePackage(),
    });
  });

  it('rejects ready-for-pilot evidence when required checkpoints are incomplete', async () => {
    await expect(
      upsertEvidence(buildRequest({
        candidateModelPackageId: 'fl_pkg_1',
        status: 'ready_for_pilot',
        sandboxEvalComplete: true,
        metricsSnapshotComplete: false,
        rollbackPlanVerified: true,
      })),
    ).rejects.toMatchObject({
      code: 'failed-precondition',
      message: 'Ready-for-pilot evidence requires sandbox eval, metrics snapshot, and rollback-plan verification.',
    });
  });

  it('persists ready-for-pilot evidence and updates package state', async () => {
    const result = await upsertEvidence(buildRequest({
      candidateModelPackageId: 'fl_pkg_1',
      status: 'ready_for_pilot',
      sandboxEvalComplete: true,
      metricsSnapshotComplete: true,
      rollbackPlanVerified: true,
      notes: 'Bounded pilot evidence is complete.',
    }));

    const evidenceId = buildFederatedLearningPilotEvidenceRecordDocId('fl_pkg_1');
    expect(result).toMatchObject({
      success: true,
      id: evidenceId,
      candidateModelPackageId: 'fl_pkg_1',
      status: 'ready_for_pilot',
    });
    const evidence = ensureCollection('federatedLearningPilotEvidenceRecords').get(evidenceId);
    expect(evidence).toMatchObject({
      status: 'ready_for_pilot',
      sandboxEvalComplete: true,
      metricsSnapshotComplete: true,
      rollbackPlanVerified: true,
      reviewedBy: 'hq-1',
    });
    const pkg = ensureCollection('federatedLearningCandidateModelPackages').get('fl_pkg_1');
    expect(pkg).toMatchObject({
      latestPilotEvidenceRecordId: evidenceId,
      latestPilotEvidenceStatus: 'ready_for_pilot',
    });
  });

  it('requires approved review, ready evidence, and approved-for-eval promotion before pilot approval', async () => {
    await expect(
      upsertApproval(buildRequest({
        candidateModelPackageId: 'fl_pkg_1',
        status: 'approved',
      })),
    ).rejects.toMatchObject({
      code: 'failed-precondition',
      message: 'Approved pilot approval requires an approved experiment review record.',
    });

    seedCollection('federatedLearningExperimentReviewRecords', {
      [buildFederatedLearningExperimentReviewRecordDocId('fl_exp_1')]: { status: 'approved' },
    });
    seedCollection('federatedLearningPilotEvidenceRecords', {
      [buildFederatedLearningPilotEvidenceRecordDocId('fl_pkg_1')]: { status: 'ready_for_pilot' },
    });
    seedCollection('federatedLearningCandidatePromotionRecords', {
      [buildFederatedLearningCandidatePromotionRecordDocId('fl_pkg_1')]: {
        status: 'approved_for_eval',
        target: 'sandbox_eval',
      },
    });

    const result = await upsertApproval(buildRequest({
      candidateModelPackageId: 'fl_pkg_1',
      status: 'approved',
      notes: 'Pilot approved after bounded review chain.',
    }));

    const approvalId = buildFederatedLearningPilotApprovalRecordDocId('fl_pkg_1');
    expect(result).toMatchObject({
      success: true,
      id: approvalId,
      status: 'approved',
    });
    const approval = ensureCollection('federatedLearningPilotApprovalRecords').get(approvalId);
    expect(approval).toMatchObject({
      experimentReviewRecordId: buildFederatedLearningExperimentReviewRecordDocId('fl_exp_1'),
      pilotEvidenceRecordId: buildFederatedLearningPilotEvidenceRecordDocId('fl_pkg_1'),
      candidatePromotionRecordId: buildFederatedLearningCandidatePromotionRecordDocId('fl_pkg_1'),
      promotionTarget: 'sandbox_eval',
      status: 'approved',
      approvedBy: 'hq-1',
    });
  });

  it('requires approved pilot approval and positive observed metrics within the cohort for observed execution', async () => {
    await expect(
      upsertExecution(buildRequest({
        candidateModelPackageId: 'fl_pkg_1',
        status: 'observed',
        launchedSiteIds: ['site-1'],
        sessionCount: 2,
        learnerCount: 10,
      })),
    ).rejects.toMatchObject({
      code: 'failed-precondition',
      message: 'Pilot execution beyond planning requires an approved pilot approval record.',
    });

    seedCollection('federatedLearningPilotApprovalRecords', {
      [buildFederatedLearningPilotApprovalRecordDocId('fl_pkg_1')]: { status: 'approved' },
    });

    await expect(
      upsertExecution(buildRequest({
        candidateModelPackageId: 'fl_pkg_1',
        status: 'observed',
        launchedSiteIds: ['site-9'],
        sessionCount: 2,
        learnerCount: 10,
      })),
    ).rejects.toMatchObject({
      code: 'failed-precondition',
      message: 'Pilot execution sites must be within the experiment allowed-site cohort.',
    });

    const result = await upsertExecution(buildRequest({
      candidateModelPackageId: 'fl_pkg_1',
      status: 'observed',
      launchedSiteIds: ['site-1'],
      sessionCount: 2,
      learnerCount: 10,
      notes: 'Observed bounded pilot execution.',
    }));

    const executionId = buildFederatedLearningPilotExecutionRecordDocId('fl_pkg_1');
    expect(result).toMatchObject({
      success: true,
      id: executionId,
      status: 'observed',
    });
    const execution = ensureCollection('federatedLearningPilotExecutionRecords').get(executionId);
    expect(execution).toMatchObject({
      pilotApprovalRecordId: buildFederatedLearningPilotApprovalRecordDocId('fl_pkg_1'),
      status: 'observed',
      launchedSiteIds: ['site-1'],
      sessionCount: 2,
      learnerCount: 10,
      recordedBy: 'hq-1',
    });
  });
});