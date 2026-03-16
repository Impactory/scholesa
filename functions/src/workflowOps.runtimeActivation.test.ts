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
  return 1710700000000 + writeCounter;
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

class MockDocumentSnapshot {
  constructor(
    public readonly id: string,
    private readonly record: StoredDoc | undefined,
  ) {}

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

class MockDocumentReference {
  constructor(
    private readonly collectionName: string,
    public readonly id: string,
  ) {}

  async get(): Promise<MockDocumentSnapshot> {
    return new MockDocumentSnapshot(this.id, ensureCollection(this.collectionName).get(this.id));
  }

  async set(data: Record<string, unknown>, options?: { merge?: boolean }): Promise<void> {
    const store = ensureCollection(this.collectionName);
    const next = options?.merge
      ? mergeWrite(store.get(this.id), data)
      : materializeWrite(data);
    store.set(this.id, next);
  }
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
      .map(([id, data]) => new MockDocumentSnapshot(id, data));
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

const mockFirestore = Object.assign(
  jest.fn(() => ({
    collection: (name: string) => new MockCollectionReference(name),
  })),
  {
    FieldValue: undefined,
    Timestamp: undefined,
  },
);

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

import { upsertFederatedLearningRuntimeActivationRecord } from './workflowOps';

type TestCallable = (request: { auth?: { uid?: string }; data?: Record<string, unknown> }) => Promise<unknown>;

const upsertActivation = upsertFederatedLearningRuntimeActivationRecord as unknown as TestCallable;

function buildRequest(authUid: string, data: Record<string, unknown>) {
  return {
    auth: { uid: authUid },
    data,
  };
}

function baseDeliveryRecord(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    experimentId: 'fl_exp_1',
    candidateModelPackageId: 'fl_pkg_1',
    runtimeTarget: 'flutter_mobile',
    targetSiteIds: ['site-1', 'site-2'],
    status: 'active',
    packageDigest: 'sha256:pkg-1',
    boundedDigest: 'sha256:bounded-1',
    triggerSummaryId: 'sum-trigger-1',
    summaryIds: ['sum-1', 'sum-2'],
    schemaVersions: ['v1'],
    optimizerStrategies: ['bounded_runtime_vector_local_finetune_v1'],
    compatibilityKey: 'flutter_mobile:v1',
    warmStartPackageId: 'fl_pkg_prev',
    warmStartModelVersion: 'fl_runtime_model_v1',
    manifestDigest: 'sha256:manifest-1',
    expiresAt: 1893456000000,
    ...overrides,
  };
}

describe('workflowOps runtime activation', () => {
  beforeEach(() => {
    clearDatabase();
    seedCollection('users', {
      'site-admin-1': {
        role: 'site',
        siteIds: ['site-1'],
        activeSiteId: 'site-1',
      },
      'site-admin-2': {
        role: 'site',
        siteIds: ['site-9'],
        activeSiteId: 'site-9',
      },
      'hq-1': {
        role: 'hq',
        siteIds: ['site-1', 'site-2'],
        activeSiteId: 'site-1',
      },
    });
    seedCollection('federatedLearningRuntimeDeliveryRecords', {
      fl_delivery_1: baseDeliveryRecord(),
    });
  });

  it('records bounded site activation evidence for a site actor', async () => {
    const result = await upsertActivation(
      buildRequest('site-admin-1', {
        deliveryRecordId: 'fl_delivery_1',
        status: 'resolved',
        traceId: 'trace-1',
        notes: 'Prepared bounded runtime activation evidence.',
      }),
    );

    expect(result).toMatchObject({
      success: true,
      deliveryRecordId: 'fl_delivery_1',
      status: 'resolved',
    });
    const stored = Array.from(ensureCollection('federatedLearningRuntimeActivationRecords').values())[0];
    expect(stored).toMatchObject({
      siteId: 'site-1',
      status: 'resolved',
      traceId: 'trace-1',
      notes: 'Prepared bounded runtime activation evidence.',
      reportedBy: 'site-admin-1',
      runtimeTarget: 'flutter_mobile',
      manifestDigest: 'sha256:manifest-1',
    });
    const audit = Array.from(ensureCollection('auditLogs').values())[0];
    expect(audit).toMatchObject({
      collection: 'federatedLearningRuntimeActivationRecords',
      userId: 'site-admin-1',
    });
    expect(audit.details).toMatchObject({
      siteId: 'site-1',
      status: 'resolved',
    });
  });

  it('rejects activation when the actor lacks site access', async () => {
    try {
      await upsertActivation(
        buildRequest('site-admin-2', {
          deliveryRecordId: 'fl_delivery_1',
          siteId: 'site-1',
          status: 'resolved',
        }),
      );
      throw new Error('Expected activation to fail for inaccessible site.');
    } catch (error) {
      expect(error).toHaveProperty('code', 'permission-denied');
      expect(error).toHaveProperty('message', 'No access to requested site.');
    }
  });

  it('rejects activation when the delivery is not assigned to the requested site', async () => {
    seedCollection('federatedLearningRuntimeDeliveryRecords', {
      fl_delivery_1: baseDeliveryRecord({
        targetSiteIds: ['site-2'],
      }),
    });

    await expect(
      upsertActivation(
        buildRequest('site-admin-1', {
          deliveryRecordId: 'fl_delivery_1',
          status: 'resolved',
        }),
      ),
    ).rejects.toMatchObject({
      code: 'permission-denied',
      message: 'Runtime delivery record is not assigned to the requested site.',
    });
  });

  it('allows fallback evidence for a revoked delivery but rejects resolved evidence', async () => {
    seedCollection('federatedLearningRuntimeDeliveryRecords', {
      fl_delivery_1: baseDeliveryRecord({
        status: 'revoked',
        revokedAt: 1710703600000,
      }),
    });

    const fallbackResult = await upsertActivation(
      buildRequest('site-admin-1', {
        deliveryRecordId: 'fl_delivery_1',
        status: 'fallback',
        notes: 'Revoked delivery triggered fallback.',
      }),
    );

    expect(fallbackResult).toMatchObject({
      success: true,
      status: 'fallback',
    });

    await expect(
      upsertActivation(
        buildRequest('site-admin-1', {
          deliveryRecordId: 'fl_delivery_1',
          status: 'resolved',
        }),
      ),
    ).rejects.toMatchObject({
      code: 'failed-precondition',
      message: 'Runtime activation evidence requires an assigned or active, non-expired runtime delivery record.',
    });
  });
});