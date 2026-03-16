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
  return 1710600000000 + writeCounter;
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

import { upsertFederatedLearningRuntimeRolloutAlertRecord } from './workflowOps';

type TestCallable = (request: { auth?: { uid?: string }; data?: Record<string, unknown> }) => Promise<unknown>;

const upsertAlert = upsertFederatedLearningRuntimeRolloutAlertRecord as unknown as TestCallable;

function buildRequest(data: Record<string, unknown>) {
  return {
    auth: { uid: 'hq-1' },
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

function baseActivation(siteId: string, status: string): Record<string, unknown> {
  return {
    deliveryRecordId: 'fl_delivery_1',
    experimentId: 'fl_exp_1',
    candidateModelPackageId: 'fl_pkg_1',
    siteId,
    runtimeTarget: 'flutter_mobile',
    manifestDigest: 'sha256:manifest-1',
    status,
    createdAt: nextWriteMillis(),
    updatedAt: nextWriteMillis(),
  };
}

describe('workflowOps runtime rollout alert', () => {
  beforeEach(() => {
    clearDatabase();
    seedCollection('users', {
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

  it('auto-acknowledges a healthy rollout with no fallback or pending sites', async () => {
    seedCollection('federatedLearningRuntimeActivationRecords', {
      fl_activation_1: baseActivation('site-1', 'resolved'),
      fl_activation_2: baseActivation('site-2', 'resolved'),
    });

    const result = await upsertAlert(
      buildRequest({
        deliveryRecordId: 'fl_delivery_1',
        status: 'active',
        notes: 'Healthy rollout snapshot.',
      }),
    );

    expect(result).toMatchObject({
      success: true,
      status: 'acknowledged',
      fallbackCount: 0,
      pendingCount: 0,
    });
    const stored = ensureCollection('federatedLearningRuntimeRolloutAlertRecords')
      .get('fl_rollout_alert_1');
    expect(stored).toMatchObject({
      status: 'acknowledged',
      fallbackCount: 0,
      pendingCount: 0,
      acknowledgedBy: 'hq-1',
      notes: 'Healthy rollout snapshot.',
    });
  });

  it('keeps requested active status while a live issue remains', async () => {
    seedCollection('federatedLearningRuntimeActivationRecords', {
      fl_activation_1: baseActivation('site-1', 'resolved'),
      fl_activation_2: baseActivation('site-2', 'fallback'),
    });

    const result = await upsertAlert(
      buildRequest({
        deliveryRecordId: 'fl_delivery_1',
        status: 'active',
        notes: 'Fallback still live.',
      }),
    );

    expect(result).toMatchObject({
      success: true,
      status: 'active',
      fallbackCount: 1,
      pendingCount: 0,
    });
    const stored = ensureCollection('federatedLearningRuntimeRolloutAlertRecords')
      .get('fl_rollout_alert_1');
    expect(stored).toMatchObject({
      status: 'active',
      fallbackCount: 1,
      pendingCount: 0,
      notes: 'Fallback still live.',
    });
    expect(stored?.acknowledgedBy).toBeUndefined();
  });

  it('auto-acknowledges for a superseded delivery while retaining issue counts', async () => {
    seedCollection('federatedLearningRuntimeDeliveryRecords', {
      fl_delivery_1: baseDeliveryRecord({
        status: 'superseded',
        supersededAt: 1710603600000,
        supersededByDeliveryRecordId: 'fl_delivery_2',
      }),
    });
    seedCollection('federatedLearningRuntimeActivationRecords', {
      fl_activation_1: baseActivation('site-1', 'resolved'),
    });

    const result = await upsertAlert(
      buildRequest({
        deliveryRecordId: 'fl_delivery_1',
        status: 'active',
        notes: 'Superseded deliveries should settle alerts.',
      }),
    );

    expect(result).toMatchObject({
      success: true,
      status: 'acknowledged',
      fallbackCount: 0,
      pendingCount: 1,
    });
    const stored = ensureCollection('federatedLearningRuntimeRolloutAlertRecords')
      .get('fl_rollout_alert_1');
    expect(stored).toMatchObject({
      status: 'acknowledged',
      fallbackCount: 0,
      pendingCount: 1,
      acknowledgedBy: 'hq-1',
    });
    const auditRows = Array.from(ensureCollection('auditLogs').values());
    expect(auditRows[0]).toMatchObject({
      collection: 'federatedLearningRuntimeRolloutAlertRecords',
    });
    expect(auditRows[0].details).toMatchObject({
      terminalLifecycleStatus: 'superseded',
      acknowledgedBy: 'hq-1',
    });
  });
});