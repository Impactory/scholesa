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
  return 1713000000000 + writeCounter;
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
  if (value === undefined || value === null) {
    return value;
  }
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

function mergeWrite(existing: Record<string, unknown> | undefined, input: Record<string, unknown>) {
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
    const next = options?.merge ? mergeWrite(store.get(this.id), data) : materializeWrite(data);
    store.set(this.id, next);
  }
}

class MockDocumentSnapshot {
  constructor(
    public readonly ref: MockDocumentReference,
    private readonly record: StoredDoc | undefined,
  ) {}

  get id(): string {
    return this.ref.id;
  }

  get exists(): boolean {
    return this.record != null;
  }

  data(): StoredDoc | undefined {
    return this.record == null ? undefined : cloneValue(this.record);
  }
}

class MockQuerySnapshot {
  constructor(public readonly docs: MockDocumentSnapshot[]) {}
}

class MockQuery {
  constructor(
    protected readonly collectionName: string,
    private readonly filters: Array<{ field: string; operator: string; value: unknown }> = [],
    private readonly order: { field: string; direction: 'asc' | 'desc' } | null = null,
    private readonly limitCount: number | null = null,
  ) {}

  where(field: string, operator: string, value: unknown): MockQuery {
    if (!['==', 'array-contains'].includes(operator)) {
      throw new Error(`Unsupported query operator: ${operator}`);
    }
    return new MockQuery(
      this.collectionName,
      [...this.filters, { field, operator, value }],
      this.order,
      this.limitCount,
    );
  }

  orderBy(field: string, direction: 'asc' | 'desc' = 'asc'): MockQuery {
    return new MockQuery(this.collectionName, this.filters, { field, direction }, this.limitCount);
  }

  limit(count: number): MockQuery {
    return new MockQuery(this.collectionName, this.filters, this.order, count);
  }

  async get(): Promise<MockQuerySnapshot> {
    let rows = Array.from(ensureCollection(this.collectionName).entries())
      .filter(([, data]) => this.filters.every((filter) => {
        const current = data[filter.field];
        if (filter.operator === '==') {
          return current === filter.value;
        }
        if (filter.operator === 'array-contains') {
          return Array.isArray(current) && current.includes(filter.value);
        }
        return false;
      }));

    if (this.order) {
      rows = rows.sort((a, b) => {
        const aValue = a[1][this.order!.field];
        const bValue = b[1][this.order!.field];
        const direction = this.order!.direction === 'asc' ? 1 : -1;
        if (typeof aValue === 'number' && typeof bValue === 'number') {
          return (aValue - bValue) * direction;
        }
        const aMillis = aValue instanceof MockTimestamp ? aValue.toMillis() : Number(aValue || 0);
        const bMillis = bValue instanceof MockTimestamp ? bValue.toMillis() : Number(bValue || 0);
        return (aMillis - bMillis) * direction;
      });
    }

    const docs = rows
      .slice(0, this.limitCount ?? Number.MAX_SAFE_INTEGER)
      .map(([id, data]) => new MockDocumentSnapshot(new MockDocumentReference(this.collectionName, id), data));
    return new MockQuerySnapshot(docs);
  }
}

class MockCollectionReference extends MockQuery {
  constructor(collectionName: string) {
    super(collectionName);
  }

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

class MockTransaction {
  async get(refOrQuery: MockDocumentReference | MockQuery): Promise<MockDocumentSnapshot | MockQuerySnapshot> {
    return refOrQuery.get();
  }

  set(ref: MockDocumentReference, data: Record<string, unknown>, options?: { merge?: boolean }): void {
    const store = ensureCollection((ref as unknown as { collectionName?: string }).collectionName || '');
    const existing = store.get(ref.id);
    const next = options?.merge ? mergeWrite(existing, data) : materializeWrite(data);
    store.set(ref.id, next);
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

import { recordFederatedLearningPrototypeUpdate } from './workflowOps';

type TestCallable = (request: { auth?: { uid?: string }; data?: Record<string, unknown> }) => Promise<unknown>;

const recordUpdate = recordFederatedLearningPrototypeUpdate as unknown as TestCallable;

function buildRequest(data: Record<string, unknown>) {
  return {
    auth: { uid: 'site-admin-1' },
    data,
  };
}

function seedBaseExperiment(overrides: Record<string, unknown> = {}): void {
  seedCollection('federatedLearningExperiments', {
    fl_exp_1: {
      name: 'Pilot Alpha',
      runtimeTarget: 'flutter_mobile',
      status: 'pilot_ready',
      enablePrototypeUploads: true,
      featureFlagId: 'feature_fl_exp_1',
      allowedSiteIds: ['site-1', 'site-2'],
      aggregateThreshold: 2,
      rawUpdateMaxBytes: 4096,
      ...overrides,
    },
  });
  seedCollection('featureFlags', {
    feature_fl_exp_1: {
      enabled: true,
      scope: 'site',
      enabledSites: ['site-1', 'site-2'],
      status: 'enabled',
    },
  });
}

function baseSummary(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    experimentId: 'fl_exp_1',
    siteId: 'site-1',
    traceId: 'trace-1',
    schemaVersion: 'v1',
    sampleCount: 4,
    vectorLength: 2,
    vectorSketch: [0.2, 0.4],
    payloadBytes: 512,
    updateNorm: 0.7,
    payloadDigest: 'digest-1',
    batteryState: 'ok',
    networkType: 'wifi',
    optimizerStrategy: 'adamw',
    localEpochCount: 1,
    localStepCount: 6,
    trainingWindowSeconds: 60,
    ...overrides,
  };
}

describe('workflowOps prototype update', () => {
  beforeEach(() => {
    clearDatabase();
    seedCollection('users', {
      'site-admin-1': {
        role: 'site',
        siteIds: ['site-1'],
        activeSiteId: 'site-1',
      },
    });
    seedBaseExperiment();
  });

  it('rejects updates when the site is outside the enabled feature-flag cohort', async () => {
    seedBaseExperiment();
    seedCollection('featureFlags', {
      feature_fl_exp_1: {
        enabled: true,
        scope: 'site',
        enabledSites: ['site-2'],
        status: 'enabled',
      },
    });

    await expect(recordUpdate(buildRequest(baseSummary()))).rejects.toMatchObject({
      code: 'failed-precondition',
      message: 'Site is outside the enabled feature-flag cohort.',
    });
  });

  it('rejects raw-content fields in bounded prototype summaries', async () => {
    await expect(recordUpdate(buildRequest({
      ...baseSummary(),
      rawUpdate: [1, 2, 3],
    }))).rejects.toMatchObject({
      code: 'invalid-argument',
      message: 'rawUpdate is not allowed in prototype update summaries.',
    });
  });

  it('persists an accepted summary when the aggregation threshold is not yet met', async () => {
    const result = await recordUpdate(buildRequest(baseSummary()));

    expect(result).toMatchObject({
      success: true,
      id: 'federatedLearningUpdateSummaries_1',
      experimentId: 'fl_exp_1',
      siteId: 'site-1',
      aggregationRunId: null,
      mergeArtifactId: null,
      candidateModelPackageId: null,
      aggregationMaterialized: false,
    });

    const summary = ensureCollection('federatedLearningUpdateSummaries').get('federatedLearningUpdateSummaries_1');
    expect(summary).toMatchObject({
      experimentId: 'fl_exp_1',
      requestedBy: 'site-admin-1',
      status: 'accepted',
      aggregationStatus: 'pending',
      traceId: 'trace-1',
      payloadDigest: 'digest-1',
      batteryState: 'ok',
      networkType: 'wifi',
      optimizerStrategy: 'adamw',
    });
    expect(ensureCollection('federatedLearningAggregationRuns').size).toBe(0);
  });

  it('materializes aggregation outputs once accepted summaries cross the threshold', async () => {
    seedCollection('federatedLearningUpdateSummaries', {
      seed_summary_1: {
        experimentId: 'fl_exp_1',
        runtimeTarget: 'flutter_mobile',
        requestedBy: 'site-admin-1',
        status: 'accepted',
        aggregationStatus: 'pending',
        siteId: 'site-1',
        traceId: 'trace-seed',
        schemaVersion: 'v1',
        sampleCount: 5,
        vectorLength: 2,
        vectorSketch: [0.1, 0.3],
        payloadBytes: 400,
        updateNorm: 0.5,
        payloadDigest: 'digest-seed',
        batteryState: 'ok',
        networkType: 'wifi',
        optimizerStrategy: 'adamw',
        localEpochCount: 1,
        localStepCount: 4,
        trainingWindowSeconds: 50,
        createdAt: 100,
        updatedAt: 100,
      },
    });

    const result = await recordUpdate(buildRequest({
      ...baseSummary({
        traceId: 'trace-new',
        payloadDigest: 'digest-new',
      }),
    }));

    expect(result).toMatchObject({
      success: true,
      id: 'federatedLearningUpdateSummaries_2',
      experimentId: 'fl_exp_1',
      siteId: 'site-1',
      aggregationMaterialized: true,
      aggregationRunId: expect.any(String),
      mergeArtifactId: expect.any(String),
      candidateModelPackageId: expect.any(String),
    });

    expect(ensureCollection('federatedLearningAggregationRuns').size).toBe(1);
    expect(ensureCollection('federatedLearningMergeArtifacts').size).toBe(1);
    expect(ensureCollection('federatedLearningCandidateModelPackages').size).toBe(1);

    const [runId, run] = Array.from(ensureCollection('federatedLearningAggregationRuns').entries())[0];
    expect(run).toMatchObject({
      experimentId: 'fl_exp_1',
      status: 'materialized',
      thresholdMet: true,
      summaryCount: 2,
      contributingSiteIds: ['site-1'],
      runtimeTargets: ['flutter_mobile'],
      optimizerStrategies: ['adamw'],
    });

    const seeded = ensureCollection('federatedLearningUpdateSummaries').get('seed_summary_1');
    const accepted = ensureCollection('federatedLearningUpdateSummaries').get('federatedLearningUpdateSummaries_2');
    expect(seeded).toMatchObject({ aggregationStatus: 'materialized', aggregationRunId: runId });
    expect(accepted).toMatchObject({ aggregationStatus: 'materialized', aggregationRunId: runId });

    const experiment = ensureCollection('federatedLearningExperiments').get('fl_exp_1');
    expect(experiment).toMatchObject({
      latestAggregationRunId: runId,
    });
  });
});