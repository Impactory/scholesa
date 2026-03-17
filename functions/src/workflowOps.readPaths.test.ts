const SERVER_TIMESTAMP = Symbol('serverTimestamp');
const DELETE_FIELD = Symbol('deleteField');

type StoredDoc = Record<string, unknown>;
type CollectionStore = Map<string, StoredDoc>;

const database = new Map<string, CollectionStore>();
let writeCounter = 0;

function nextWriteMillis(): number {
  writeCounter += 1;
  return 1714000000000 + writeCounter;
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
    if (!['==', 'array-contains', 'in'].includes(operator)) {
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
    let rows = Array.from(ensureCollection(this.collectionName).entries()).filter(([, data]) => (
      this.filters.every((filter) => {
        const current = data[filter.field];
        if (filter.operator === '==') {
          return current === filter.value;
        }
        if (filter.operator === 'array-contains') {
          return Array.isArray(current) && current.includes(filter.value);
        }
        if (filter.operator === 'in') {
          return Array.isArray(filter.value) && filter.value.includes(current);
        }
        return false;
      })
    ));

    if (this.order) {
      const { field, direction } = this.order;
      const orderFactor = direction === 'asc' ? 1 : -1;
      rows = rows.sort((left, right) => {
        const leftValue = left[1][field];
        const rightValue = right[1][field];
        const leftNumber = typeof leftValue === 'number' ? leftValue : Number(leftValue || 0);
        const rightNumber = typeof rightValue === 'number' ? rightValue : Number(rightValue || 0);
        return (leftNumber - rightNumber) * orderFactor;
      });
    }

    return new MockQuerySnapshot(
      rows
        .slice(0, this.limitCount ?? Number.MAX_SAFE_INTEGER)
        .map(([id, data]) => new MockDocumentSnapshot(new MockDocumentReference(this.collectionName, id), data)),
    );
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
    const id = `${this.collectionName}_${ensureCollection(this.collectionName).size + 1}`;
    const ref = new MockDocumentReference(this.collectionName, id);
    await ref.set(data);
    return ref;
  }
}

const firestoreRoot = {
  collection: (name: string) => new MockCollectionReference(name),
  getAll: async (...refs: MockDocumentReference[]) => Promise.all(refs.map((ref) => ref.get())),
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

import { buildFederatedLearningRuntimeRolloutControlRecordDocId } from './federatedLearningPrototype';
import {
  listFederatedLearningRuntimeRolloutAuditEvents,
  listSiteFederatedLearningExperiments,
  listSiteFederatedLearningRuntimeDeliveryRecords,
  listSiteFederatedLearningRuntimeDeliveryHistoryRecords,
  resolveSiteFederatedLearningRuntimePackage,
} from './workflowOps';

type TestCallable = (request: { auth?: { uid?: string }; data?: Record<string, unknown> }) => Promise<unknown>;

const listSiteExperiments = listSiteFederatedLearningExperiments as unknown as TestCallable;
const listSiteDeliveries = listSiteFederatedLearningRuntimeDeliveryRecords as unknown as TestCallable;
const listSiteDeliveryHistory = listSiteFederatedLearningRuntimeDeliveryHistoryRecords as unknown as TestCallable;
const resolvePackage = resolveSiteFederatedLearningRuntimePackage as unknown as TestCallable;
const listAuditEvents = listFederatedLearningRuntimeRolloutAuditEvents as unknown as TestCallable;

function buildRequest(uid: string, data: Record<string, unknown> = {}) {
  return {
    auth: { uid },
    data,
  };
}

describe('workflowOps read paths', () => {
  beforeEach(() => {
    clearDatabase();
    seedCollection('users', {
      'site-actor': {
        role: 'site',
        siteIds: ['site-1'],
        activeSiteId: 'site-1',
      },
      'hq-actor': {
        role: 'hq',
        siteIds: ['site-1', 'site-2'],
        activeSiteId: 'site-1',
      },
    });
  });

  it('returns only enabled site-scoped experiments in the caller cohort', async () => {
    seedCollection('federatedLearningExperiments', {
      exp_live: {
        name: 'Live Pilot',
        allowedSiteIds: ['site-1'],
        status: 'active',
        featureFlagId: 'flag_live',
      },
      exp_disabled_flag: {
        name: 'Disabled Flag Pilot',
        allowedSiteIds: ['site-1'],
        status: 'active',
        featureFlagId: 'flag_disabled',
      },
      exp_other_site: {
        name: 'Other Site Pilot',
        allowedSiteIds: ['site-2'],
        status: 'active',
        featureFlagId: 'flag_other',
      },
      exp_draft: {
        name: 'Draft Pilot',
        allowedSiteIds: ['site-1'],
        status: 'draft',
        featureFlagId: 'flag_draft',
      },
    });
    seedCollection('featureFlags', {
      flag_live: { enabled: true, scope: 'site', enabledSites: ['site-1'], status: 'enabled' },
      flag_disabled: { enabled: false, scope: 'site', enabledSites: ['site-1'], status: 'disabled' },
      flag_other: { enabled: true, scope: 'site', enabledSites: ['site-2'], status: 'enabled' },
      flag_draft: { enabled: true, scope: 'site', enabledSites: ['site-1'], status: 'enabled' },
    });

    const result = await listSiteExperiments(buildRequest('site-actor'));

    expect(result).toMatchObject({
      siteId: 'site-1',
      experiments: [
        expect.objectContaining({
          id: 'exp_live',
          name: 'Live Pilot',
          featureFlag: expect.objectContaining({ id: 'flag_live', enabled: true }),
        }),
      ],
    });
  });

  it('returns only non-terminal assigned or active site delivery records ordered by freshness', async () => {
    seedCollection('federatedLearningRuntimeDeliveryRecords', {
      active_new: {
        experimentId: 'fl_exp_1',
        candidateModelPackageId: 'pkg_new',
        targetSiteIds: ['site-1'],
        status: 'active',
        updatedAt: 300,
      },
      assigned_old: {
        experimentId: 'fl_exp_1',
        candidateModelPackageId: 'pkg_old',
        targetSiteIds: ['site-1'],
        status: 'assigned',
        updatedAt: 100,
      },
      revoked: {
        experimentId: 'fl_exp_1',
        candidateModelPackageId: 'pkg_revoked',
        targetSiteIds: ['site-1'],
        status: 'revoked',
        updatedAt: 400,
      },
      other_site: {
        experimentId: 'fl_exp_1',
        candidateModelPackageId: 'pkg_other',
        targetSiteIds: ['site-2'],
        status: 'active',
        updatedAt: 500,
      },
    });

    const result = await listSiteDeliveries(buildRequest('site-actor'));

    expect(result).toEqual({
      records: [
        expect.objectContaining({ id: 'active_new', candidateModelPackageId: 'pkg_new' }),
        expect.objectContaining({ id: 'assigned_old', candidateModelPackageId: 'pkg_old' }),
      ],
    });
  });

  it('returns site delivery lifecycle history including terminal statuses and control review context', async () => {
    seedCollection('federatedLearningRuntimeDeliveryRecords', {
      active_new: {
        experimentId: 'fl_exp_1',
        candidateModelPackageId: 'pkg_new',
        targetSiteIds: ['site-1'],
        runtimeTarget: 'flutter_mobile',
        status: 'active',
        manifestDigest: 'manifest-active',
        updatedAt: 500,
      },
      revoked_delivery: {
        experimentId: 'fl_exp_1',
        candidateModelPackageId: 'pkg_revoked',
        targetSiteIds: ['site-1'],
        runtimeTarget: 'flutter_mobile',
        status: 'revoked',
        manifestDigest: 'manifest-revoked',
        revokedAt: 450,
        revocationReason: 'Revoked after bounded regression review.',
        updatedAt: 450,
      },
      assigned_review: {
        experimentId: 'fl_exp_1',
        candidateModelPackageId: 'pkg_review',
        targetSiteIds: ['site-1'],
        runtimeTarget: 'flutter_mobile',
        status: 'assigned',
        manifestDigest: 'manifest-review',
        updatedAt: 425,
      },
      other_site: {
        experimentId: 'fl_exp_1',
        candidateModelPackageId: 'pkg_other',
        targetSiteIds: ['site-2'],
        runtimeTarget: 'flutter_mobile',
        status: 'active',
        updatedAt: 600,
      },
    });
    seedCollection('federatedLearningRuntimeRolloutControlRecords', {
      [buildFederatedLearningRuntimeRolloutControlRecordDocId('assigned_review')]: {
        deliveryRecordId: 'assigned_review',
        mode: 'paused',
        reason: 'Paused pending bounded verification.',
        reviewByAt: 900,
      },
    });

    const result = await listSiteDeliveryHistory(buildRequest('site-actor'));

    expect(result).toEqual({
      records: [
        expect.objectContaining({
          id: 'active_new',
          candidateModelPackageId: 'pkg_new',
          terminalLifecycleStatus: null,
        }),
        expect.objectContaining({
          id: 'revoked_delivery',
          candidateModelPackageId: 'pkg_revoked',
          terminalLifecycleStatus: 'revoked',
          revocationReason: 'Revoked after bounded regression review.',
        }),
        expect.objectContaining({
          id: 'assigned_review',
          candidateModelPackageId: 'pkg_review',
          rolloutControlMode: 'paused',
          rolloutControlReason: 'Paused pending bounded verification.',
          rolloutControlReviewByAt: 900,
        }),
      ],
    });
  });

  it('returns restricted package resolution when rollout control blocks unresolved sites', async () => {
    seedCollection('federatedLearningRuntimeDeliveryRecords', {
      delivery_1: {
        experimentId: 'fl_exp_1',
        candidateModelPackageId: 'pkg_1',
        runtimeTarget: 'flutter_mobile',
        targetSiteIds: ['site-1'],
        status: 'active',
        manifestDigest: 'manifest-1',
        updatedAt: 250,
      },
    });
    seedCollection('federatedLearningRuntimeRolloutControlRecords', {
      [buildFederatedLearningRuntimeRolloutControlRecordDocId('delivery_1')]: {
        deliveryRecordId: 'delivery_1',
        mode: 'restricted',
        reason: 'Only previously resolved sites may continue.',
        reviewByAt: 900,
      },
    });
    seedCollection('federatedLearningCandidateModelPackages', {
      pkg_1: {
        packageDigest: 'pkg-digest-1',
        modelVersion: 'fl_runtime_model_v7',
        runtimeVectorLength: 2,
        runtimeVector: [0.1, 0.2],
        runtimeVectorDigest: 'vector-digest-1',
        rolloutStatus: 'distributed',
        runtimeTargets: ['flutter_mobile'],
      },
    });

    const result = await resolvePackage(buildRequest('site-actor', { experimentId: 'fl_exp_1' }));

    expect(result).toMatchObject({
      package: {
        packageId: 'pkg_1',
        deliveryRecordId: 'delivery_1',
        resolutionStatus: 'restricted',
        rolloutControlMode: 'restricted',
        rolloutControlReason: 'Only previously resolved sites may continue.',
        runtimeVectorLength: 0,
        runtimeVector: [],
      },
    });
  });

  it('filters rollout audit events by experiment and site from bounded action logs', async () => {
    seedCollection('auditLogs', {
      audit_1: {
        action: 'federated_learning.runtime_delivery_record.upsert',
        timestamp: 500,
        details: {
          experimentId: 'fl_exp_1',
          candidateModelPackageId: 'pkg_1',
          deliveryRecordId: 'delivery_1',
          siteId: 'site-1',
        },
      },
      audit_2: {
        action: 'federated_learning.runtime_activation_record.upsert',
        timestamp: 700,
        details: {
          experimentId: 'fl_exp_1',
          candidateModelPackageId: 'pkg_1',
          deliveryRecordId: 'delivery_1',
          siteId: 'site-1',
        },
      },
      audit_3: {
        action: 'federated_learning.runtime_rollout_alert_record.upsert',
        timestamp: 200,
        details: {
          experimentId: 'fl_exp_2',
          candidateModelPackageId: 'pkg_2',
          deliveryRecordId: 'delivery_2',
          siteId: 'site-2',
        },
      },
      audit_4: {
        action: 'some_other_action',
        timestamp: 900,
        details: {
          experimentId: 'fl_exp_1',
          siteId: 'site-1',
        },
      },
    });

    const result = await listAuditEvents(buildRequest('hq-actor', {
      experimentId: 'fl_exp_1',
      siteId: 'site-1',
    }));

    expect(result).toEqual({
      records: [
        expect.objectContaining({ id: 'audit_2', action: 'federated_learning.runtime_activation_record.upsert' }),
        expect.objectContaining({ id: 'audit_1', action: 'federated_learning.runtime_delivery_record.upsert' }),
      ],
    });
  });
});