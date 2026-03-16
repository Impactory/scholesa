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
  return 1710900000000 + writeCounter;
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
  buildFederatedLearningCandidatePromotionRevocationRecordDocId,
} from './federatedLearningPrototype';
import {
  revokeFederatedLearningCandidatePromotionRecord,
  upsertFederatedLearningCandidatePromotionRecord,
} from './workflowOps';

type TestCallable = (request: { auth?: { uid?: string }; data?: Record<string, unknown> }) => Promise<unknown>;

const upsertPromotion = upsertFederatedLearningCandidatePromotionRecord as unknown as TestCallable;
const revokePromotion = revokeFederatedLearningCandidatePromotionRecord as unknown as TestCallable;

function buildRequest(data: Record<string, unknown>) {
  return {
    auth: { uid: 'hq-1' },
    data,
  };
}

function basePackage(status = 'staged', overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    experimentId: 'fl_exp_1',
    aggregationRunId: 'fl_agg_1',
    mergeArtifactId: 'fl_merge_1',
    packageDigest: 'sha256:pkg-1',
    boundedDigest: 'sha256:bounded-1',
    status,
    ...overrides,
  };
}

describe('workflowOps candidate promotion', () => {
  beforeEach(() => {
    clearDatabase();
    seedCollection('users', {
      'hq-1': {
        role: 'hq',
        siteIds: ['site-1'],
        activeSiteId: 'site-1',
      },
    });
    seedCollection('federatedLearningCandidateModelPackages', {
      fl_pkg_1: basePackage(),
    });
  });

  it('rejects promotion for non-staged candidate packages', async () => {
    seedCollection('federatedLearningCandidateModelPackages', {
      fl_pkg_1: basePackage('retired'),
    });

    await expect(
      upsertPromotion(buildRequest({
        candidateModelPackageId: 'fl_pkg_1',
        status: 'approved_for_eval',
      })),
    ).rejects.toMatchObject({
      code: 'failed-precondition',
      message: 'Only staged candidate model packages can receive promotion records.',
    });
  });

  it('persists bounded promotion records and updates package latest promotion state', async () => {
    const result = await upsertPromotion(buildRequest({
      candidateModelPackageId: 'fl_pkg_1',
      status: 'approved_for_eval',
      target: 'sandbox_eval',
      rationale: 'Approved for bounded sandbox evaluation.',
    }));

    const promotionId = buildFederatedLearningCandidatePromotionRecordDocId('fl_pkg_1');
    expect(result).toMatchObject({
      success: true,
      id: promotionId,
      candidateModelPackageId: 'fl_pkg_1',
      status: 'approved_for_eval',
      target: 'sandbox_eval',
    });
    const promotion = ensureCollection('federatedLearningCandidatePromotionRecords').get(promotionId);
    expect(promotion).toMatchObject({
      experimentId: 'fl_exp_1',
      aggregationRunId: 'fl_agg_1',
      mergeArtifactId: 'fl_merge_1',
      packageDigest: 'sha256:pkg-1',
      boundedDigest: 'sha256:bounded-1',
      decidedBy: 'hq-1',
      status: 'approved_for_eval',
      target: 'sandbox_eval',
      rationale: 'Approved for bounded sandbox evaluation.',
    });
    const pkg = ensureCollection('federatedLearningCandidateModelPackages').get('fl_pkg_1');
    expect(pkg).toMatchObject({
      latestPromotionRecordId: promotionId,
      latestPromotionStatus: 'approved_for_eval',
    });
  });

  it('rejects revocation when no promotion record exists', async () => {
    await expect(
      revokePromotion(buildRequest({
        candidateModelPackageId: 'fl_pkg_1',
        rationale: 'No approval should mean no revocation record.',
      })),
    ).rejects.toMatchObject({
      code: 'failed-precondition',
      message: 'Promotion record not found for candidate model package.',
    });
  });

  it('persists rollback-proof promotion revocation and updates package state', async () => {
    const promotionId = buildFederatedLearningCandidatePromotionRecordDocId('fl_pkg_1');
    seedCollection('federatedLearningCandidatePromotionRecords', {
      [promotionId]: {
        experimentId: 'fl_exp_1',
        candidateModelPackageId: 'fl_pkg_1',
        aggregationRunId: 'fl_agg_1',
        mergeArtifactId: 'fl_merge_1',
        packageDigest: 'sha256:pkg-1',
        boundedDigest: 'sha256:bounded-1',
        status: 'approved_for_eval',
        target: 'sandbox_eval',
      },
    });

    const result = await revokePromotion(buildRequest({
      candidateModelPackageId: 'fl_pkg_1',
      rationale: 'Rollback after bounded pilot regression.',
    }));

    const revocationId = buildFederatedLearningCandidatePromotionRevocationRecordDocId('fl_pkg_1');
    expect(result).toMatchObject({
      success: true,
      id: revocationId,
      candidateModelPackageId: 'fl_pkg_1',
    });
    const revocation = ensureCollection('federatedLearningCandidatePromotionRevocationRecords').get(revocationId);
    expect(revocation).toMatchObject({
      experimentId: 'fl_exp_1',
      candidateModelPackageId: 'fl_pkg_1',
      candidatePromotionRecordId: promotionId,
      packageDigest: 'sha256:pkg-1',
      boundedDigest: 'sha256:bounded-1',
      revokedStatus: 'approved_for_eval',
      target: 'sandbox_eval',
      revokedBy: 'hq-1',
      rationale: 'Rollback after bounded pilot regression.',
    });
    const pkg = ensureCollection('federatedLearningCandidateModelPackages').get('fl_pkg_1');
    expect(pkg).toMatchObject({
      latestPromotionStatus: 'revoked',
      latestPromotionRevocationRecordId: revocationId,
    });
  });
});