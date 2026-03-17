const httpsCallableMock = jest.fn();
const addDocMock = jest.fn();
const collectionMock = jest.fn((_firestore, collectionName: string) => ({ collectionName }));
const deleteDocMock = jest.fn();
const docMock = jest.fn((ref: { collectionName?: string }, id: string) => ({ collectionName: ref.collectionName, id }));
const documentIdMock = jest.fn(() => 'documentId');
const getDocMock = jest.fn();
const getDocsMock = jest.fn();
const incrementMock = jest.fn((value: number) => ({ __increment__: value }));
const limitMock = jest.fn((value: number) => ({ type: 'limit', value }));
const orderByMock = jest.fn((field: string, direction?: string) => ({ type: 'orderBy', field, direction }));
const queryMock = jest.fn((...constraints: unknown[]) => ({ constraints }));
const serverTimestampMock = jest.fn(() => 'SERVER_TIMESTAMP');
const setDocMock = jest.fn();
const updateDocMock = jest.fn();
const whereMock = jest.fn((field: string, op: string, value: unknown) => ({ type: 'where', field, op, value }));

jest.mock('@/src/firebase/client-init', () => ({
  firestore: { app: 'test-firestore' },
  functions: { app: 'test-functions' },
}));

jest.mock('firebase/functions', () => ({
  httpsCallable: (...args: unknown[]) => httpsCallableMock(...args),
}));

jest.mock('firebase/firestore', () => ({
  addDoc: (...args: unknown[]) => addDocMock(...args),
  arrayRemove: jest.fn(),
  arrayUnion: jest.fn(),
  collection: (...args: unknown[]) => collectionMock(...args),
  deleteDoc: (...args: unknown[]) => deleteDocMock(...args),
  doc: (...args: unknown[]) => docMock(...args),
  documentId: () => documentIdMock(),
  getDoc: (...args: unknown[]) => getDocMock(...args),
  getDocs: (...args: unknown[]) => getDocsMock(...args),
  increment: (...args: unknown[]) => incrementMock(...args),
  limit: (...args: unknown[]) => limitMock(...args),
  orderBy: (...args: unknown[]) => orderByMock(...args),
  query: (...args: unknown[]) => queryMock(...args),
  serverTimestamp: () => serverTimestampMock(),
  setDoc: (...args: unknown[]) => setDocMock(...args),
  updateDoc: (...args: unknown[]) => updateDocMock(...args),
  where: (...args: unknown[]) => whereMock(...args),
}));

import {
  createWorkflowRecord,
  loadWorkflowRecords,
  updateWorkflowRecord,
  type WorkflowContext,
} from '@/src/features/workflows/workflowData';

type CallableHandler = jest.Mock<Promise<{ data: Record<string, unknown> }>, [Record<string, unknown>?]>;

const callableHandlers = new Map<string, CallableHandler>();

function setCallableHandler(name: string, handler?: CallableHandler) {
  if (handler) {
    callableHandlers.set(name, handler);
    return handler;
  }
  const fallback = jest.fn().mockResolvedValue({ data: {} }) as CallableHandler;
  callableHandlers.set(name, fallback);
  return fallback;
}

function makeContext(routePath: WorkflowContext['routePath'], overrides?: Partial<WorkflowContext>): WorkflowContext {
  return {
    routePath,
    locale: 'en',
    uid: 'user-1',
    role: 'hq',
    profile: {
      role: 'hq',
      activeSiteId: 'site-1',
      siteIds: ['site-1'],
      displayName: 'HQ User',
    } as never,
    ...overrides,
  };
}

function makeDocSnapshot(data: Record<string, unknown>) {
  return {
    exists: () => true,
    data: () => data,
    id: data.id || 'doc-1',
  };
}

describe('workflow route parity', () => {
  beforeEach(() => {
    callableHandlers.clear();
    httpsCallableMock.mockReset();
    httpsCallableMock.mockImplementation((_functions: unknown, name: string) => {
      const handler = callableHandlers.get(name);
      if (!handler) {
        return jest.fn().mockResolvedValue({ data: {} });
      }
      return handler;
    });

    addDocMock.mockReset().mockResolvedValue({ id: 'new-doc' });
    collectionMock.mockClear();
    deleteDocMock.mockReset();
    docMock.mockClear();
    getDocMock.mockReset().mockResolvedValue(makeDocSnapshot({}));
    getDocsMock.mockReset().mockResolvedValue({ docs: [] });
    incrementMock.mockClear();
    limitMock.mockClear();
    orderByMock.mockClear();
    queryMock.mockClear();
    serverTimestampMock.mockClear();
    setDocMock.mockReset().mockResolvedValue(undefined);
    updateDocMock.mockReset().mockResolvedValue(undefined);
    whereMock.mockClear();
  });

  it('exposes the HQ approvals action for live approval records', async () => {
    setCallableHandler('listWorkflowApprovals', jest.fn().mockResolvedValue({
      data: {
        approvals: [{
          id: 'partnerContracts:contract-1',
          title: 'Partner Contract',
          summary: 'Awaiting review',
          status: 'pending',
          sourceCollection: 'partnerContracts',
          siteId: 'site-1',
        }],
      },
    }) as CallableHandler);

    const result = await loadWorkflowRecords(makeContext('/hq/approvals'));

    expect(result.records).toHaveLength(1);
    expect(result.records[0]).toEqual(expect.objectContaining({
      canEdit: true,
      primaryActionLabel: 'Approve',
      collectionName: 'approvals',
    }));
  });

  it('only exposes site identity resolution on unresolved links', async () => {
    setCallableHandler('listExternalIdentityLinks', jest.fn().mockResolvedValue({
      data: {
        links: [
          {
            id: 'link-1',
            providerUserId: 'clever-1',
            provider: 'clever',
            siteId: 'site-1',
            status: 'pending',
          },
          {
            id: 'link-2',
            providerUserId: 'clever-2',
            provider: 'clever',
            siteId: 'site-1',
            status: 'resolved',
          },
        ],
      },
    }) as CallableHandler);

    const result = await loadWorkflowRecords(makeContext('/site/identity', {
      role: 'site',
      uid: 'site-user-1',
      profile: {
        role: 'site',
        activeSiteId: 'site-1',
        siteIds: ['site-1'],
      } as never,
    }));

    expect(result.records[0]).toEqual(expect.objectContaining({
      canEdit: true,
      primaryActionLabel: 'Resolve link',
    }));
    expect(result.records[1]).toEqual(expect.objectContaining({
      canEdit: false,
      primaryActionLabel: 'Resolve link',
    }));
  });

  it('fails closed for site workflows without an active site context', async () => {
    await expect(loadWorkflowRecords(makeContext('/site/checkin', {
      role: 'hq',
      profile: {
        role: 'hq',
        siteIds: [],
      } as never,
    }))).rejects.toThrow('Active site context is required for site workflows.');
  });

  it('passes partnerId through HQ partner launch creation', async () => {
    const upsertPartnerLaunch = setCallableHandler('upsertPartnerLaunch');

    await createWorkflowRecord(makeContext('/partner/contracts'), {
      values: {
        action: 'partnerLaunch',
        partnerId: 'partner-1',
        partnerName: 'Partner One',
        region: 'APAC',
        locale: 'en',
      },
    });

    expect(upsertPartnerLaunch).toHaveBeenCalledWith(expect.objectContaining({
      partnerId: 'partner-1',
      partnerName: 'Partner One',
      region: 'APAC',
    }));
  });

  it('routes HQ billing creation through createHqInvoice with a numeric amount', async () => {
    const createHqInvoice = setCallableHandler('createHqInvoice');

    await createWorkflowRecord(makeContext('/hq/billing'), {
      values: {
        parentId: 'parent-1',
        learnerId: 'learner-1',
        amount: '120',
        currency: 'USD',
        description: 'Manual invoice',
      },
    });

    expect(createHqInvoice).toHaveBeenCalledWith(expect.objectContaining({
      parentId: 'parent-1',
      learnerId: 'learner-1',
      amount: 120,
      currency: 'USD',
    }));
  });

  it('uses updateUserRoles for HQ user-admin activation toggles', async () => {
    const updateUserRoles = setCallableHandler('updateUserRoles');
    getDocMock.mockResolvedValue(makeDocSnapshot({ isActive: true }));

    await updateWorkflowRecord(makeContext('/hq/user-admin'), {
      routePath: '/hq/user-admin',
      collectionName: 'users',
      id: 'user-2',
    });

    expect(updateUserRoles).toHaveBeenCalledWith({
      uid: 'user-2',
      isActive: false,
    });
  });
});