const SERVER_TIMESTAMP = Symbol('serverTimestamp');
const DELETE_FIELD = Symbol('deleteField');

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
    if (operator !== '==') {
      throw new Error(`Unsupported query operator: ${operator}`);
    }
    return new MockQuery(this.collectionName, [...this.filters, { field, operator, value }], this.order, this.limitCount);
  }

  orderBy(field: string, direction: 'asc' | 'desc' = 'asc'): MockQuery {
    return new MockQuery(this.collectionName, this.filters, { field, direction }, this.limitCount);
  }

  limit(count: number): MockQuery {
    return new MockQuery(this.collectionName, this.filters, this.order, count);
  }

  async get(): Promise<MockQuerySnapshot> {
    let rows = Array.from(ensureCollection(this.collectionName).entries()).filter(([, data]) => (
      this.filters.every((filter) => data[filter.field] === filter.value)
    ));

    if (this.order) {
      const { field, direction } = this.order;
      const factor = direction === 'asc' ? 1 : -1;
      rows = rows.sort((left, right) => {
        const leftValue = left[1][field];
        const rightValue = right[1][field];
        const leftNumber = typeof leftValue === 'number' ? leftValue : Number(leftValue || 0);
        const rightNumber = typeof rightValue === 'number' ? rightValue : Number(rightValue || 0);
        return (leftNumber - rightNumber) * factor;
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
  listFederatedLearningAggregationRuns,
  listFederatedLearningCandidateModelPackages,
  listFederatedLearningCandidatePromotionRecords,
  listFederatedLearningCandidatePromotionRevocationRecords,
  listFederatedLearningExperimentReviewRecords,
  listFederatedLearningMergeArtifacts,
  listFederatedLearningPilotApprovalRecords,
  listFederatedLearningPilotEvidenceRecords,
  listFederatedLearningPilotExecutionRecords,
  listFederatedLearningRuntimeActivationRecords,
  listFederatedLearningRuntimeDeliveryRecords,
  listFederatedLearningRuntimeRolloutAlertRecords,
  listFederatedLearningRuntimeRolloutControlRecords,
  listFederatedLearningRuntimeRolloutEscalationHistoryRecords,
  listFederatedLearningRuntimeRolloutEscalationRecords,
} from './workflowOps';

type TestCallable = (request: { auth?: { uid?: string }; data?: Record<string, unknown> }) => Promise<unknown>;

const listRuns = listFederatedLearningAggregationRuns as unknown as TestCallable;
const listArtifacts = listFederatedLearningMergeArtifacts as unknown as TestCallable;
const listPackages = listFederatedLearningCandidateModelPackages as unknown as TestCallable;
const listPromotions = listFederatedLearningCandidatePromotionRecords as unknown as TestCallable;
const listRevocations = listFederatedLearningCandidatePromotionRevocationRecords as unknown as TestCallable;
const listReviews = listFederatedLearningExperimentReviewRecords as unknown as TestCallable;
const listEvidence = listFederatedLearningPilotEvidenceRecords as unknown as TestCallable;
const listApprovals = listFederatedLearningPilotApprovalRecords as unknown as TestCallable;
const listExecutions = listFederatedLearningPilotExecutionRecords as unknown as TestCallable;
const listDeliveries = listFederatedLearningRuntimeDeliveryRecords as unknown as TestCallable;
const listActivations = listFederatedLearningRuntimeActivationRecords as unknown as TestCallable;
const listAlerts = listFederatedLearningRuntimeRolloutAlertRecords as unknown as TestCallable;
const listEscalations = listFederatedLearningRuntimeRolloutEscalationRecords as unknown as TestCallable;
const listEscalationHistory = listFederatedLearningRuntimeRolloutEscalationHistoryRecords as unknown as TestCallable;
const listControls = listFederatedLearningRuntimeRolloutControlRecords as unknown as TestCallable;

function buildRequest(data: Record<string, unknown> = {}) {
  return {
    auth: { uid: 'hq-actor' },
    data,
  };
}

describe('workflowOps HQ list callables', () => {
  beforeEach(() => {
    clearDatabase();
    seedCollection('users', {
      'hq-actor': {
        role: 'hq',
        siteIds: ['site-1', 'site-2'],
        activeSiteId: 'site-1',
      },
    });
  });

  it('lists experiment reviews newest-first and filtered by experiment', async () => {
    seedCollection('federatedLearningExperimentReviewRecords', {
      review_old: { experimentId: 'fl_exp_1', status: 'pending', updatedAt: 100 },
      review_new: { experimentId: 'fl_exp_1', status: 'approved', updatedAt: 300 },
      review_other: { experimentId: 'fl_exp_2', status: 'blocked', updatedAt: 500 },
    });

    const result = await listReviews(buildRequest({ experimentId: 'fl_exp_1' }));
    expect(result).toEqual({
      records: [
        expect.objectContaining({ id: 'review_new', experimentId: 'fl_exp_1' }),
        expect.objectContaining({ id: 'review_old', experimentId: 'fl_exp_1' }),
      ],
    });
  });

  it('lists aggregation runs, merge artifacts, and candidate packages newest-first by experiment', async () => {
    seedCollection('federatedLearningAggregationRuns', {
      run_old: { experimentId: 'fl_exp_1', createdAt: 100 },
      run_new: { experimentId: 'fl_exp_1', createdAt: 200 },
      run_other: { experimentId: 'fl_exp_2', createdAt: 400 },
    });
    seedCollection('federatedLearningMergeArtifacts', {
      artifact_old: { experimentId: 'fl_exp_1', createdAt: 50 },
      artifact_new: { experimentId: 'fl_exp_1', createdAt: 150 },
      artifact_other: { experimentId: 'fl_exp_2', createdAt: 250 },
    });
    seedCollection('federatedLearningCandidateModelPackages', {
      pkg_old: { experimentId: 'fl_exp_1', createdAt: 75 },
      pkg_new: { experimentId: 'fl_exp_1', createdAt: 175 },
      pkg_other: { experimentId: 'fl_exp_2', createdAt: 275 },
    });

    await expect(listRuns(buildRequest({ experimentId: 'fl_exp_1' }))).resolves.toEqual({
      runs: [
        expect.objectContaining({ id: 'run_new' }),
        expect.objectContaining({ id: 'run_old' }),
      ],
    });
    await expect(listArtifacts(buildRequest({ experimentId: 'fl_exp_1' }))).resolves.toEqual({
      artifacts: [
        expect.objectContaining({ id: 'artifact_new' }),
        expect.objectContaining({ id: 'artifact_old' }),
      ],
    });
    await expect(listPackages(buildRequest({ experimentId: 'fl_exp_1' }))).resolves.toEqual({
      packages: [
        expect.objectContaining({ id: 'pkg_new' }),
        expect.objectContaining({ id: 'pkg_old' }),
      ],
    });
  });

  it('lists promotion, revocation, and pilot records filtered by package and ordered by update time', async () => {
    seedCollection('federatedLearningCandidatePromotionRecords', {
      promo_old: { experimentId: 'fl_exp_1', candidateModelPackageId: 'pkg_1', updatedAt: 10 },
      promo_new: { experimentId: 'fl_exp_1', candidateModelPackageId: 'pkg_1', updatedAt: 30 },
      promo_other: { experimentId: 'fl_exp_1', candidateModelPackageId: 'pkg_2', updatedAt: 50 },
    });
    seedCollection('federatedLearningCandidatePromotionRevocationRecords', {
      rev_old: { experimentId: 'fl_exp_1', candidateModelPackageId: 'pkg_1', updatedAt: 20 },
      rev_new: { experimentId: 'fl_exp_1', candidateModelPackageId: 'pkg_1', updatedAt: 40 },
      rev_other: { experimentId: 'fl_exp_2', candidateModelPackageId: 'pkg_1', updatedAt: 60 },
    });
    seedCollection('federatedLearningPilotEvidenceRecords', {
      evidence_old: { experimentId: 'fl_exp_1', candidateModelPackageId: 'pkg_1', updatedAt: 15 },
      evidence_new: { experimentId: 'fl_exp_1', candidateModelPackageId: 'pkg_1', updatedAt: 35 },
    });
    seedCollection('federatedLearningPilotApprovalRecords', {
      approval_old: { experimentId: 'fl_exp_1', candidateModelPackageId: 'pkg_1', updatedAt: 12 },
      approval_new: { experimentId: 'fl_exp_1', candidateModelPackageId: 'pkg_1', updatedAt: 42 },
    });
    seedCollection('federatedLearningPilotExecutionRecords', {
      execution_old: { experimentId: 'fl_exp_1', candidateModelPackageId: 'pkg_1', updatedAt: 18 },
      execution_new: { experimentId: 'fl_exp_1', candidateModelPackageId: 'pkg_1', updatedAt: 45 },
    });

    const data = { experimentId: 'fl_exp_1', candidateModelPackageId: 'pkg_1' };
    await expect(listPromotions(buildRequest(data))).resolves.toEqual({
      records: [expect.objectContaining({ id: 'promo_new' }), expect.objectContaining({ id: 'promo_old' })],
    });
    await expect(listRevocations(buildRequest(data))).resolves.toEqual({
      records: [expect.objectContaining({ id: 'rev_new' }), expect.objectContaining({ id: 'rev_old' })],
    });
    await expect(listEvidence(buildRequest(data))).resolves.toEqual({
      records: [expect.objectContaining({ id: 'evidence_new' }), expect.objectContaining({ id: 'evidence_old' })],
    });
    await expect(listApprovals(buildRequest(data))).resolves.toEqual({
      records: [expect.objectContaining({ id: 'approval_new' }), expect.objectContaining({ id: 'approval_old' })],
    });
    await expect(listExecutions(buildRequest(data))).resolves.toEqual({
      records: [expect.objectContaining({ id: 'execution_new' }), expect.objectContaining({ id: 'execution_old' })],
    });
  });

  it('lists runtime delivery and activation history filtered by experiment, package, and site', async () => {
    seedCollection('federatedLearningRuntimeDeliveryRecords', {
      delivery_old: { experimentId: 'fl_exp_1', candidateModelPackageId: 'pkg_1', updatedAt: 100 },
      delivery_new: { experimentId: 'fl_exp_1', candidateModelPackageId: 'pkg_1', updatedAt: 300 },
      delivery_other: { experimentId: 'fl_exp_1', candidateModelPackageId: 'pkg_2', updatedAt: 500 },
    });
    seedCollection('federatedLearningRuntimeActivationRecords', {
      activation_old: { experimentId: 'fl_exp_1', candidateModelPackageId: 'pkg_1', siteId: 'site-1', updatedAt: 110 },
      activation_new: { experimentId: 'fl_exp_1', candidateModelPackageId: 'pkg_1', siteId: 'site-1', updatedAt: 310 },
      activation_other_site: { experimentId: 'fl_exp_1', candidateModelPackageId: 'pkg_1', siteId: 'site-2', updatedAt: 510 },
    });

    await expect(listDeliveries(buildRequest({ experimentId: 'fl_exp_1', candidateModelPackageId: 'pkg_1' }))).resolves.toEqual({
      records: [expect.objectContaining({ id: 'delivery_new' }), expect.objectContaining({ id: 'delivery_old' })],
    });
    await expect(listActivations(buildRequest({ experimentId: 'fl_exp_1', candidateModelPackageId: 'pkg_1', siteId: 'site-1' }))).resolves.toEqual({
      records: [expect.objectContaining({ id: 'activation_new' }), expect.objectContaining({ id: 'activation_old' })],
    });
  });

  it('lists rollout alert, escalation, escalation history, and control records with normalized filters', async () => {
    seedCollection('federatedLearningRuntimeRolloutAlertRecords', {
      alert_old: { experimentId: 'fl_exp_1', candidateModelPackageId: 'pkg_1', deliveryRecordId: 'delivery_1', status: 'active', updatedAt: 100 },
      alert_new: { experimentId: 'fl_exp_1', candidateModelPackageId: 'pkg_1', deliveryRecordId: 'delivery_1', status: 'active', updatedAt: 300 },
      alert_other: { experimentId: 'fl_exp_1', candidateModelPackageId: 'pkg_1', deliveryRecordId: 'delivery_1', status: 'acknowledged', updatedAt: 500 },
    });
    seedCollection('federatedLearningRuntimeRolloutEscalationRecords', {
      esc_old: { experimentId: 'fl_exp_1', candidateModelPackageId: 'pkg_1', deliveryRecordId: 'delivery_1', status: 'investigating', updatedAt: 120 },
      esc_new: { experimentId: 'fl_exp_1', candidateModelPackageId: 'pkg_1', deliveryRecordId: 'delivery_1', status: 'investigating', updatedAt: 320 },
      esc_other: { experimentId: 'fl_exp_1', candidateModelPackageId: 'pkg_1', deliveryRecordId: 'delivery_1', status: 'resolved', updatedAt: 520 },
    });
    seedCollection('federatedLearningRuntimeRolloutEscalationHistoryRecords', {
      hist_old: { experimentId: 'fl_exp_1', candidateModelPackageId: 'pkg_1', deliveryRecordId: 'delivery_1', status: 'investigating', recordedAt: 130 },
      hist_new: { experimentId: 'fl_exp_1', candidateModelPackageId: 'pkg_1', deliveryRecordId: 'delivery_1', status: 'investigating', recordedAt: 330 },
      hist_other: { experimentId: 'fl_exp_1', candidateModelPackageId: 'pkg_1', deliveryRecordId: 'delivery_1', status: 'resolved', recordedAt: 530 },
    });
    seedCollection('federatedLearningRuntimeRolloutControlRecords', {
      ctrl_old: { experimentId: 'fl_exp_1', candidateModelPackageId: 'pkg_1', deliveryRecordId: 'delivery_1', mode: 'restricted', updatedAt: 140 },
      ctrl_new: { experimentId: 'fl_exp_1', candidateModelPackageId: 'pkg_1', deliveryRecordId: 'delivery_1', mode: 'restricted', updatedAt: 340 },
      ctrl_other: { experimentId: 'fl_exp_1', candidateModelPackageId: 'pkg_1', deliveryRecordId: 'delivery_1', mode: 'paused', updatedAt: 540 },
    });

    const scoped = { experimentId: 'fl_exp_1', candidateModelPackageId: 'pkg_1', deliveryRecordId: 'delivery_1' };
    await expect(listAlerts(buildRequest({ ...scoped, status: 'active' }))).resolves.toEqual({
      records: [expect.objectContaining({ id: 'alert_new' }), expect.objectContaining({ id: 'alert_old' })],
    });
    await expect(listEscalations(buildRequest({ ...scoped, status: 'in_progress' }))).resolves.toEqual({
      records: [expect.objectContaining({ id: 'esc_new' }), expect.objectContaining({ id: 'esc_old' })],
    });
    await expect(listEscalationHistory(buildRequest({ ...scoped, status: 'in_progress' }))).resolves.toEqual({
      records: [expect.objectContaining({ id: 'hist_new' }), expect.objectContaining({ id: 'hist_old' })],
    });
    await expect(listControls(buildRequest({ ...scoped, mode: 'restricted' }))).resolves.toEqual({
      records: [expect.objectContaining({ id: 'ctrl_new' }), expect.objectContaining({ id: 'ctrl_old' })],
    });
  });
});