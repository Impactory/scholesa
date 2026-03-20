const SERVER_TIMESTAMP = Symbol('serverTimestamp');

type StoredDoc = Record<string, unknown>;
type CollectionStore = Map<string, StoredDoc>;

const database = new Map<string, CollectionStore>();
let writeCounter = 0;

function nextWriteMillis(): number {
  writeCounter += 1;
  return 1715000000000 + writeCounter;
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

  async set(data: Record<string, unknown>, options?: { merge?: boolean }): Promise<void> {
    const store = ensureCollection(this.collectionName);
    const current = options?.merge ? store.get(this.id) || {} : {};
    store.set(this.id, { ...cloneValue(current), ...materializeWrite(data) });
  }
}

class MockQuerySnapshot {
  constructor(public readonly docs: Array<{ id: string; data: () => StoredDoc }>) {}
}

class MockCollectionReference {
  constructor(private readonly name: string) {}

  doc(id?: string): MockDocumentReference {
    return new MockDocumentReference(this.name, id ?? `${this.name}_${ensureCollection(this.name).size + 1}`);
  }

  limit(_count: number): MockCollectionReference {
    return this;
  }

  async get(): Promise<MockQuerySnapshot> {
    const docs = Array.from(ensureCollection(this.name).entries()).map(([id, data]) => ({
      id,
      data: () => cloneValue(data),
    }));
    return new MockQuerySnapshot(docs);
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

import { listFeatureFlags, upsertFeatureFlag } from './workflowOps';

type TestCallable = (request: { auth?: { uid?: string }; data?: Record<string, unknown> }) => Promise<unknown>;

const listFlags = listFeatureFlags as unknown as TestCallable;
const upsertFlag = upsertFeatureFlag as unknown as TestCallable;

function buildRequest(data: Record<string, unknown> = {}) {
  return {
    auth: { uid: 'hq-actor' },
    data,
  };
}

describe('workflowOps feature flags', () => {
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

  it('canonicalizes legacy ai help loop flag names on list', async () => {
    seedCollection('featureFlags', {
      flag_legacy: {
        name: 'miloos_loop',
        description: 'Enable spoken AI help loop runtime',
        enabled: true,
        scope: 'global',
      },
    });

    await expect(listFlags(buildRequest())).resolves.toEqual({
      flags: [
        expect.objectContaining({
          id: 'flag_legacy',
          name: 'ai_help_loop',
          enabled: true,
        }),
      ],
    });
  });

  it('writes canonical ai help loop flag names on upsert', async () => {
    const result = await upsertFlag(buildRequest({
      id: 'flag_legacy',
      name: 'miloos_loop',
      description: 'Enable spoken AI help loop runtime',
      enabled: true,
      scope: 'global',
    }));

    expect(result).toEqual({ success: true, id: 'flag_legacy' });
    expect(ensureCollection('featureFlags').get('flag_legacy')).toMatchObject({
      name: 'ai_help_loop',
      enabled: true,
      scope: 'global',
      status: 'enabled',
      updatedBy: 'hq-actor',
    });
  });
});