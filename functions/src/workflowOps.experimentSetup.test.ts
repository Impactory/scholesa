const SERVER_TIMESTAMP = Symbol('serverTimestamp');
const DELETE_FIELD = Symbol('deleteField');

type StoredDoc = Record<string, unknown>;
type CollectionStore = Map<string, StoredDoc>;

let writeCounter = 0;
const database = new Map<string, CollectionStore>();

function nextWriteMillis(): number {
  writeCounter += 1;
  return 1712000000000 + writeCounter;
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
  Timestamp: class MockTimestamp {},
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
  buildFederatedLearningExperimentDocId,
  buildFederatedLearningExperimentReviewRecordDocId,
  buildFederatedLearningFeatureFlagId,
} from './federatedLearningPrototype';
import {
  upsertFederatedLearningExperiment,
  upsertFederatedLearningExperimentReviewRecord,
} from './workflowOps';

type TestCallable = (request: { auth?: { uid?: string }; data?: Record<string, unknown> }) => Promise<unknown>;

const upsertExperiment = upsertFederatedLearningExperiment as unknown as TestCallable;
const upsertReview = upsertFederatedLearningExperimentReviewRecord as unknown as TestCallable;

function buildRequest(data: Record<string, unknown>) {
  return {
    auth: { uid: 'hq-1' },
    data,
  };
}

describe('workflowOps experiment setup', () => {
  beforeEach(() => {
    clearDatabase();
    seedCollection('users', {
      'hq-1': {
        role: 'hq',
        siteIds: ['site-1', 'site-2'],
        activeSiteId: 'site-1',
      },
    });
  });

  it('rejects pilot-ready experiments without an allowed-site cohort', async () => {
    await expect(
      upsertExperiment(buildRequest({
        name: 'My Pilot',
        runtimeTarget: 'flutter_mobile',
        status: 'pilot_ready',
        enablePrototypeUploads: true,
      })),
    ).rejects.toMatchObject({
      code: 'invalid-argument',
      message: 'allowedSiteIds are required when status is pilot_ready or active.',
    });
  });

  it('persists experiment config and its feature flag payload', async () => {
    const result = await upsertExperiment(buildRequest({
      name: 'My Pilot',
      description: 'Bounded runtime pilot.',
      runtimeTarget: 'flutter_mobile',
      status: 'pilot_ready',
      enablePrototypeUploads: true,
      allowedSiteIds: ['site-1', 'site-2'],
      requireWarmStartForTraining: true,
      maxLocalEpochs: 4,
      maxLocalSteps: 30,
      maxTrainingWindowSeconds: 2400,
      aggregateThreshold: 12,
      minDistinctSiteCount: 2,
      rawUpdateMaxBytes: 32768,
    }));

    const experimentId = buildFederatedLearningExperimentDocId('My Pilot');
    const featureFlagId = buildFederatedLearningFeatureFlagId(experimentId);
    expect(result).toMatchObject({
      success: true,
      id: experimentId,
      featureFlagId,
    });

    const experiment = ensureCollection('federatedLearningExperiments').get(experimentId);
    expect(experiment).toMatchObject({
      name: 'My Pilot',
      status: 'pilot_ready',
      runtimeTarget: 'flutter_mobile',
      allowedSiteIds: ['site-1', 'site-2'],
      minDistinctSiteCount: 2,
      featureFlagId,
      updatedBy: 'hq-1',
    });
    const flag = ensureCollection('featureFlags').get(featureFlagId);
    expect(flag).toMatchObject({
      experimentId,
      enabled: true,
      status: 'enabled',
      scope: 'site',
      enabledSites: ['site-1', 'site-2'],
      updatedBy: 'hq-1',
    });
  });

  it('rejects experiment configs when site quorum exceeds the enabled cohort', async () => {
    await expect(
      upsertExperiment(buildRequest({
        name: 'My Pilot',
        runtimeTarget: 'flutter_mobile',
        status: 'pilot_ready',
        enablePrototypeUploads: true,
        allowedSiteIds: ['site-1', 'site-2'],
        minDistinctSiteCount: 3,
      })),
    ).rejects.toMatchObject({
      code: 'invalid-argument',
      message: 'minDistinctSiteCount cannot exceed the enabled site cohort size.',
    });
  });

  it('rejects approved experiment reviews until all governance checkpoints are complete', async () => {
    seedCollection('federatedLearningExperiments', {
      fl_exp_my_pilot: {
        name: 'My Pilot',
      },
    });

    await expect(
      upsertReview(buildRequest({
        experimentId: 'fl_exp_my_pilot',
        status: 'approved',
        privacyReviewComplete: true,
        signoffChecklistComplete: false,
        rolloutRiskAcknowledged: true,
      })),
    ).rejects.toMatchObject({
      code: 'failed-precondition',
      message: 'Approved review records require privacy review, sign-off checklist, and rollout-risk acknowledgement.',
    });
  });

  it('persists approved experiment reviews once all checkpoints are complete', async () => {
    seedCollection('federatedLearningExperiments', {
      fl_exp_my_pilot: {
        name: 'My Pilot',
      },
    });

    const result = await upsertReview(buildRequest({
      experimentId: 'fl_exp_my_pilot',
      status: 'approved',
      privacyReviewComplete: true,
      signoffChecklistComplete: true,
      rolloutRiskAcknowledged: true,
      notes: 'Bounded experiment review approved.',
    }));

    const reviewId = buildFederatedLearningExperimentReviewRecordDocId('fl_exp_my_pilot');
    expect(result).toMatchObject({
      success: true,
      id: reviewId,
      experimentId: 'fl_exp_my_pilot',
      status: 'approved',
    });
    const review = ensureCollection('federatedLearningExperimentReviewRecords').get(reviewId);
    expect(review).toMatchObject({
      experimentId: 'fl_exp_my_pilot',
      status: 'approved',
      privacyReviewComplete: true,
      signoffChecklistComplete: true,
      rolloutRiskAcknowledged: true,
      reviewedBy: 'hq-1',
    });
  });
});