const SERVER_TIMESTAMP = Symbol('serverTimestamp');

type StoredDoc = Record<string, unknown>;
type CollectionStore = Map<string, StoredDoc>;

const database = new Map<string, CollectionStore>();
let writeCounter = 0;

function nextWriteMillis(): number {
  writeCounter += 1;
  return 1717000000000 + writeCounter;
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
  if (value == null) {
    return value;
  }
  return JSON.parse(JSON.stringify(value)) as T;
}

function materializeWrite(input: Record<string, unknown>): Record<string, unknown> {
  const output: Record<string, unknown> = {};
  Object.entries(input).forEach(([key, value]) => {
    if (value === SERVER_TIMESTAMP) {
      output[key] = nextWriteMillis();
      return;
    }
    output[key] = cloneValue(value);
  });
  return output;
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
    const current = options?.merge ? store.get(this.id) || {} : {};
    store.set(this.id, { ...cloneValue(current), ...materializeWrite(data) });
  }
}

class MockDocumentSnapshot {
  constructor(
    public readonly ref: MockDocumentReference,
    private readonly record: StoredDoc | undefined,
  ) {}

  get exists(): boolean {
    return this.record !== undefined;
  }

  data(): StoredDoc | undefined {
    return this.record ? cloneValue(this.record) : undefined;
  }
}

class MockCollectionReference {
  constructor(private readonly name: string) {}

  doc(id?: string): MockDocumentReference {
    return new MockDocumentReference(this.name, id ?? `${this.name}_${ensureCollection(this.name).size + 1}`);
  }

  async add(data: Record<string, unknown>): Promise<MockDocumentReference> {
    const ref = this.doc();
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

import { createHqInvoice } from './workflowOps';

type TestCallable = (request: { auth?: { uid?: string }; data?: Record<string, unknown> }) => Promise<unknown>;

const createInvoice = createHqInvoice as unknown as TestCallable;

function buildRequest(uid: string, data: Record<string, unknown> = {}) {
  return {
    auth: { uid },
    data,
  };
}

describe('workflowOps HQ invoice creation', () => {
  beforeEach(() => {
    clearDatabase();
    seedCollection('users', {
      'hq-actor': {
        role: 'hq',
        siteIds: ['site-1'],
        activeSiteId: 'site-1',
      },
    });
  });

  it('persists an invoice payout and audit log for HQ invoice creation', async () => {
    await expect(
      createInvoice(buildRequest('hq-actor', {
        siteId: 'site-1',
        parentId: 'parent-1',
        parentName: 'Parent One',
        learnerId: 'learner-1',
        learnerName: 'Learner One',
        amount: 120,
        description: 'Studio tuition for March',
        currency: 'USD',
      })),
    ).resolves.toEqual({
      success: true,
      id: 'payouts_1',
      invoiceId: 'payouts_1',
    });

    expect(ensureCollection('payouts').get('payouts_1')).toMatchObject({
      type: 'invoice',
      invoiceId: 'payouts_1',
      status: 'pending',
      amount: 120,
      currency: 'USD',
      parentId: 'parent-1',
      parentName: 'Parent One',
      learnerId: 'learner-1',
      learnerName: 'Learner One',
      description: 'Studio tuition for March',
      siteId: 'site-1',
      createdBy: 'hq-actor',
    });

    expect(ensureCollection('auditLogs').get('auditLogs_1')).toMatchObject({
      actorId: 'hq-actor',
      actorRole: 'hq',
      action: 'billing.invoice_created',
      entityType: 'payouts',
      entityId: 'payouts_1',
      siteId: 'site-1',
      details: {
        invoiceId: 'payouts_1',
        amount: 120,
        currency: 'USD',
        parentId: 'parent-1',
        learnerId: 'learner-1',
      },
    });
  });
});