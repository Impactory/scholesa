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
  return 1710800000000 + writeCounter;
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
    private readonly filters: Array<{ field: string; value: unknown }> = [],
    private readonly limitCount: number | null = null,
  ) {}

  where(field: string, operator: string, value: unknown): MockQuery {
    if (operator !== '==') {
      throw new Error(`Unsupported query operator: ${operator}`);
    }
    return new MockQuery(this.collectionName, [...this.filters, { field, value }], this.limitCount);
  }

  limit(count: number): MockQuery {
    return new MockQuery(this.collectionName, this.filters, count);
  }

  async get(): Promise<MockQuerySnapshot> {
    const docs = Array.from(ensureCollection(this.collectionName).entries())
      .filter(([, data]) => this.filters.every((filter) => data[filter.field] === filter.value))
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

import {
  buildFederatedLearningPilotExecutionRecordDocId,
  buildFederatedLearningRuntimeDeliveryRecordDocId,
} from './federatedLearningPrototype';
import { upsertFederatedLearningRuntimeDeliveryRecord } from './workflowOps';

type TestCallable = (request: { auth?: { uid?: string }; data?: Record<string, unknown> }) => Promise<unknown>;

const upsertDelivery = upsertFederatedLearningRuntimeDeliveryRecord as unknown as TestCallable;

function buildRequest(data: Record<string, unknown>) {
  return {
    auth: { uid: 'hq-1' },
    data,
  };
}

function basePackage(id = 'fl_pkg_1', overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    experimentId: 'fl_exp_1',
    aggregationRunId: 'fl_agg_1',
    mergeArtifactId: 'fl_merge_1',
    schemaVersions: ['v1'],
    packageDigest: `sha256:${id}`,
    boundedDigest: `sha256:bounded:${id}`,
    triggerSummaryId: 'sum-trigger-1',
    summaryIds: ['sum-1', 'sum-2'],
    optimizerStrategies: ['bounded_runtime_vector_local_finetune_v1'],
    compatibilityKey: 'flutter_mobile:v1',
    warmStartPackageId: 'fl_pkg_prev',
    warmStartModelVersion: 'fl_runtime_model_v1',
    runtimeTargets: ['flutter_mobile'],
    ...overrides,
  };
}

function baseExperiment(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    allowedSiteIds: ['site-1', 'site-2', 'site-3'],
    runtimeTarget: 'flutter_mobile',
    ...overrides,
  };
}

function baseExecution(status: string): Record<string, unknown> {
  return {
    status,
  };
}

describe('workflowOps runtime delivery', () => {
  beforeEach(() => {
    clearDatabase();
    seedCollection('users', {
      'hq-1': {
        role: 'hq',
        siteIds: ['site-1', 'site-2', 'site-3'],
        activeSiteId: 'site-1',
      },
    });
    seedCollection('federatedLearningExperiments', {
      fl_exp_1: baseExperiment(),
    });
    seedCollection('federatedLearningCandidateModelPackages', {
      fl_pkg_1: basePackage('fl_pkg_1'),
      fl_pkg_2: basePackage('fl_pkg_2'),
    });
    seedCollection('federatedLearningPilotExecutionRecords', {
      [buildFederatedLearningPilotExecutionRecordDocId('fl_pkg_1')]: baseExecution('observed'),
      [buildFederatedLearningPilotExecutionRecordDocId('fl_pkg_2')]: baseExecution('observed'),
    });
  });

  it('rejects assigned delivery before observed or completed pilot execution', async () => {
    seedCollection('federatedLearningPilotExecutionRecords', {
      [buildFederatedLearningPilotExecutionRecordDocId('fl_pkg_1')]: baseExecution('planned'),
    });

    await expect(
      upsertDelivery(buildRequest({
        candidateModelPackageId: 'fl_pkg_1',
        status: 'assigned',
        targetSiteIds: ['site-1'],
      })),
    ).rejects.toMatchObject({
      code: 'failed-precondition',
      message: 'Assigned or active runtime delivery requires observed or completed pilot execution.',
    });
  });

  it('rejects delivery sites outside the experiment cohort', async () => {
    await expect(
      upsertDelivery(buildRequest({
        candidateModelPackageId: 'fl_pkg_1',
        status: 'assigned',
        targetSiteIds: ['site-9'],
      })),
    ).rejects.toMatchObject({
      code: 'failed-precondition',
      message: 'Runtime delivery sites must be within the experiment allowed-site cohort.',
    });
  });

  it('requires a revocation reason when revoking a runtime delivery', async () => {
    await expect(
      upsertDelivery(buildRequest({
        candidateModelPackageId: 'fl_pkg_1',
        status: 'revoked',
      })),
    ).rejects.toMatchObject({
      code: 'failed-precondition',
      message: 'Revoked runtime delivery requires a revocationReason.',
    });
  });

  it('supersedes overlapping live deliveries and retires the prior package', async () => {
    const existingDeliveryId = 'fl_delivery_existing';
    seedCollection('federatedLearningRuntimeDeliveryRecords', {
      [existingDeliveryId]: {
        experimentId: 'fl_exp_1',
        candidateModelPackageId: 'fl_pkg_2',
        runtimeTarget: 'flutter_mobile',
        targetSiteIds: ['site-2', 'site-3'],
        status: 'active',
        createdAt: nextWriteMillis(),
        updatedAt: nextWriteMillis(),
      },
    });

    const result = await upsertDelivery(buildRequest({
      candidateModelPackageId: 'fl_pkg_1',
      status: 'assigned',
      targetSiteIds: ['site-1', 'site-2'],
      notes: 'Assigned bounded runtime delivery.',
    }));

    const newDeliveryId = buildFederatedLearningRuntimeDeliveryRecordDocId('fl_pkg_1');
    expect(result).toMatchObject({
      success: true,
      id: newDeliveryId,
      candidateModelPackageId: 'fl_pkg_1',
      status: 'assigned',
    });

    const newDelivery = ensureCollection('federatedLearningRuntimeDeliveryRecords').get(newDeliveryId);
    expect(newDelivery).toMatchObject({
      status: 'assigned',
      targetSiteIds: ['site-1', 'site-2'],
      pilotExecutionRecordId: buildFederatedLearningPilotExecutionRecordDocId('fl_pkg_1'),
    });

    const oldDelivery = ensureCollection('federatedLearningRuntimeDeliveryRecords').get(existingDeliveryId);
    expect(oldDelivery).toMatchObject({
      status: 'superseded',
      supersededBy: 'hq-1',
      supersededByDeliveryRecordId: newDeliveryId,
      supersededByCandidateModelPackageId: 'fl_pkg_1',
    });

    const previousPackage = ensureCollection('federatedLearningCandidateModelPackages').get('fl_pkg_2');
    expect(previousPackage).toMatchObject({
      latestRuntimeDeliveryStatus: 'superseded',
      rolloutStatus: 'retired',
    });
    const currentPackage = ensureCollection('federatedLearningCandidateModelPackages').get('fl_pkg_1');
    expect(currentPackage).toMatchObject({
      latestRuntimeDeliveryRecordId: newDeliveryId,
      latestRuntimeDeliveryStatus: 'assigned',
      rolloutStatus: 'distributed',
    });

    const auditRows = Array.from(ensureCollection('auditLogs').values());
    expect(auditRows).toHaveLength(2);
    expect(auditRows[0]).toMatchObject({
      collection: 'federatedLearningRuntimeDeliveryRecords',
      documentId: existingDeliveryId,
    });
    expect(auditRows[0].details).toMatchObject({
      status: 'superseded',
      supersededByDeliveryRecordId: newDeliveryId,
    });
  });
});