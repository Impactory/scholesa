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
  httpsCallable: (...args: unknown[]) => httpsCallableMock.apply(undefined, args),
}));

jest.mock('firebase/firestore', () => ({
  addDoc: (...args: unknown[]) => addDocMock.apply(undefined, args),
  arrayRemove: jest.fn(),
  arrayUnion: jest.fn(),
  collection: (...args: unknown[]) => collectionMock.apply(undefined, args),
  deleteDoc: (...args: unknown[]) => deleteDocMock.apply(undefined, args),
  doc: (...args: unknown[]) => docMock.apply(undefined, args),
  documentId: () => documentIdMock(),
  getDoc: (...args: unknown[]) => getDocMock.apply(undefined, args),
  getDocs: (...args: unknown[]) => getDocsMock.apply(undefined, args),
  increment: (...args: unknown[]) => incrementMock.apply(undefined, args),
  limit: (...args: unknown[]) => limitMock.apply(undefined, args),
  orderBy: (...args: unknown[]) => orderByMock.apply(undefined, args),
  query: (...args: unknown[]) => queryMock.apply(undefined, args),
  serverTimestamp: () => serverTimestampMock(),
  setDoc: (...args: unknown[]) => setDocMock.apply(undefined, args),
  updateDoc: (...args: unknown[]) => updateDocMock.apply(undefined, args),
  where: (...args: unknown[]) => whereMock.apply(undefined, args),
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

  it('keeps site check-in records read-only even when records are present', async () => {
    getDocsMock
      .mockResolvedValueOnce({
        docs: [{
          id: 'learner-1',
          data: () => ({ displayName: 'Learner One', role: 'learner' }),
        }],
      })
      .mockResolvedValueOnce({
        docs: [{
          id: 'checkin-1',
          data: () => ({
            learnerName: 'Learner One',
            learnerId: 'learner-1',
            type: 'checkin',
            status: 'completed',
            siteId: 'site-1',
            timestamp: '2026-03-17T08:00:00.000Z',
          }),
        }],
      });

    const result = await loadWorkflowRecords(makeContext('/site/checkin', {
      role: 'site',
      uid: 'site-user-1',
      profile: {
        role: 'site',
        activeSiteId: 'site-1',
        siteIds: ['site-1'],
      } as never,
    }));

    expect(result.records[0]).toEqual(expect.objectContaining({
      canEdit: false,
      primaryActionLabel: undefined,
      collectionName: 'checkins',
    }));
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

  it('passes partnerId through HQ partner listing creation', async () => {
    await createWorkflowRecord(makeContext('/partner/listings'), {
      values: {
        partnerId: 'partner-2',
        title: 'Robotics Residency',
        description: 'HQ-created listing',
        category: 'STEM',
      },
    });

    expect(addDocMock).toHaveBeenCalledWith(
      expect.objectContaining({ collectionName: 'marketplaceListings' }),
      expect.objectContaining({
        partnerId: 'partner-2',
        title: 'Robotics Residency',
        description: 'HQ-created listing',
        category: 'STEM',
      }),
    );
  });

  it('loads partner deliverables with contract context and HQ acceptance action', async () => {
    getDocsMock
      .mockResolvedValueOnce({
        docs: [{
          id: 'contract-1',
          data: () => ({
            title: 'Contract One',
            partnerId: 'partner-1',
            siteId: 'site-1',
            updatedAt: '2026-03-18T01:00:00.000Z',
          }),
        }],
      })
      .mockResolvedValueOnce({
        docs: [{
          id: 'deliverable-1',
          data: () => ({
            contractId: 'contract-1',
            title: 'Launch checklist',
            status: 'submitted',
            submittedAt: '2026-03-18T02:00:00.000Z',
          }),
        }],
      });

    const result = await loadWorkflowRecords(makeContext('/partner/deliverables'));

    expect(result.records).toHaveLength(1);
    expect(result.records[0]).toEqual(expect.objectContaining({
      collectionName: 'partnerDeliverables',
      subtitle: 'Contract One',
      canEdit: true,
      primaryActionLabel: 'Accept deliverable',
    }));
  });

  it('creates partner deliverables in the live collection with submitted status', async () => {
    await createWorkflowRecord(makeContext('/partner/deliverables', {
      role: 'partner',
      uid: 'partner-1',
      profile: {
        role: 'partner',
        activeSiteId: 'site-1',
        siteIds: ['site-1'],
      } as never,
    }), {
      values: {
        contractId: 'contract-1',
        title: 'Robotics showcase video',
        description: 'Edited event recap',
        evidenceUrl: 'https://example.com/showcase',
      },
    });

    expect(addDocMock).toHaveBeenCalledWith(
      expect.objectContaining({ collectionName: 'partnerDeliverables' }),
      expect.objectContaining({
        contractId: 'contract-1',
        title: 'Robotics showcase video',
        description: 'Edited event recap',
        evidenceUrl: 'https://example.com/showcase',
        status: 'submitted',
        submittedBy: 'partner-1',
      }),
    );
  });

  it('loads partner-owned integrations through integrationConnections', async () => {
    getDocsMock.mockResolvedValueOnce({
      docs: [{
        id: 'connection-1',
        data: () => ({
          ownerUserId: 'partner-1',
          provider: 'clever',
          status: 'connected',
          tokenRef: 'token-ref-1',
          createdAt: '2026-03-18T03:00:00.000Z',
        }),
      }],
    });

    const result = await loadWorkflowRecords(makeContext('/partner/integrations', {
      role: 'partner',
      uid: 'partner-1',
      profile: {
        role: 'partner',
        activeSiteId: 'site-1',
        siteIds: ['site-1'],
      } as never,
    }));

    expect(result.records).toHaveLength(1);
    expect(result.records[0]).toEqual(expect.objectContaining({
      collectionName: 'integrationConnections',
      title: 'clever',
      subtitle: 'token-ref-1',
      status: 'connected',
      canEdit: false,
    }));
  });

  it('loads parent schedule records only for linked learners', async () => {
    getDocsMock
      .mockResolvedValueOnce({
        docs: [{
          id: 'guardian-link-1',
          data: () => ({
            parentId: 'parent-1',
            learnerId: 'learner-1',
            learnerName: 'Ava Learner',
          }),
        }],
      })
      .mockResolvedValueOnce({
        docs: [{
          id: 'enrollment-1',
          data: () => ({
            learnerId: 'learner-1',
            sessionId: 'session-1',
            status: 'active',
          }),
        }],
      })
      .mockResolvedValueOnce({
        docs: [{
          id: 'session-1',
          data: () => ({
            title: 'Robotics Studio',
            description: 'Prototype review',
            status: 'scheduled',
            updatedAt: '2026-03-18T09:00:00.000Z',
            siteId: 'site-1',
          }),
        }],
      });

    const result = await loadWorkflowRecords(makeContext('/parent/schedule', {
      role: 'parent',
      uid: 'parent-1',
      profile: {
        role: 'parent',
        activeSiteId: 'site-1',
        siteIds: ['site-1'],
      } as never,
    }));

    expect(whereMock).toHaveBeenCalledWith('parentId', '==', 'parent-1');
    expect(whereMock).toHaveBeenCalledWith('learnerId', 'in', ['learner-1']);
    expect(result.records).toEqual([
      expect.objectContaining({
        collectionName: 'sessions',
        routePath: '/parent/schedule',
        title: 'Robotics Studio',
        subtitle: 'Prototype review',
        status: 'scheduled',
        canEdit: false,
      }),
    ]);
  });

  it('loads parent portfolio summaries and artifacts only for linked learners', async () => {
    setCallableHandler('getParentDashboardBundle', jest.fn().mockResolvedValue({
      data: {
        learners: [{
          learnerId: 'learner-1',
          learnerName: 'Ava Learner',
          updatedAt: '2026-03-18T10:00:00.000Z',
          capabilitySnapshot: {
            band: 'developing',
            futureSkills: 0.8,
            leadership: 0.6,
            impact: 0.4,
            overall: 0.6,
          },
          portfolioSnapshot: {
            artifactCount: 3,
            publishedArtifactCount: 2,
            badgeCount: 1,
            projectCount: 2,
            latestArtifactAt: '2026-03-18T10:30:00.000Z',
          },
          ideationPassport: {
            completedMissions: 4,
            reflectionsSubmitted: 2,
            voiceInteractions: 3,
            collaborationSignals: 1,
            lastReflectionAt: '2026-03-18T09:30:00.000Z',
          },
        }],
      },
    }) as CallableHandler);
    getDocsMock.mockResolvedValueOnce({
      docs: [{
        id: 'portfolio-item-1',
        data: () => ({
          learnerId: 'learner-1',
          title: 'Build a Robot',
          description: 'Prototype iteration complete',
          status: 'published',
          createdAt: '2026-03-18T11:00:00.000Z',
        }),
      }],
    });

    const result = await loadWorkflowRecords(makeContext('/parent/portfolio', {
      role: 'parent',
      uid: 'parent-1',
      profile: {
        role: 'parent',
        activeSiteId: 'site-1',
        siteIds: ['site-1'],
      } as never,
    }));

    expect(whereMock).toHaveBeenCalledWith('learnerId', '==', 'learner-1');
    expect(result.records).toEqual(expect.arrayContaining([
      expect.objectContaining({
        id: 'capability:learner-1',
        collectionName: 'parentCapabilitySnapshots',
        routePath: '/parent/portfolio',
      }),
      expect.objectContaining({
        id: 'portfolio:learner-1',
        collectionName: 'parentPortfolioSnapshots',
        routePath: '/parent/portfolio',
      }),
      expect.objectContaining({
        id: 'passport:learner-1',
        collectionName: 'parentIdeationPassports',
        routePath: '/parent/portfolio',
      }),
      expect.objectContaining({
        id: 'portfolio-item-1',
        collectionName: 'portfolioItems',
        title: 'Build a Robot',
        status: 'published',
        routePath: '/parent/portfolio',
      }),
    ]));
  });

  it('routes site billing plan changes through requestSiteBillingPlanChange', async () => {
    const requestSiteBillingPlanChange = setCallableHandler('requestSiteBillingPlanChange');

    await createWorkflowRecord(makeContext('/site/billing', {
      role: 'site',
      uid: 'site-user-1',
      profile: {
        role: 'site',
        activeSiteId: 'site-1',
        siteIds: ['site-1'],
      } as never,
    }), {
      values: {
        siteId: 'site-1',
        reason: 'Need a higher learner cap',
      },
    });

    expect(requestSiteBillingPlanChange).toHaveBeenCalledWith({
      siteId: 'site-1',
      reason: 'Need a higher learner cap',
    });
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

  it('fails closed for site-scoped create and update mutations without an active site context', async () => {
    const noSiteContext = makeContext('/site/incidents', {
      role: 'hq',
      profile: {
        role: 'hq',
        siteIds: [],
      } as never,
    });

    await expect(createWorkflowRecord(noSiteContext, {
      values: {
        title: 'Incident',
        summary: 'No site context',
      },
    })).rejects.toThrow('Active site context is required for site workflows.');

    await expect(updateWorkflowRecord(noSiteContext, {
      routePath: '/site/incidents',
      collectionName: 'incidents',
      id: 'incident-1',
    })).rejects.toThrow('Active site context is required for site workflows.');
  });

  it('keeps partner payout rows read-only', async () => {
    setCallableHandler('listPartnerPayouts', jest.fn().mockResolvedValue({
      data: {
        payouts: [{
          id: 'payout-1',
          periodLabel: 'March 2026',
          currency: 'USD',
          partnerId: 'partner-1',
          status: 'pending',
        }],
      },
    }) as CallableHandler);

    const result = await loadWorkflowRecords(makeContext('/partner/payouts', {
      role: 'partner',
      uid: 'partner-1',
      profile: {
        role: 'partner',
        activeSiteId: 'site-1',
        siteIds: ['site-1'],
      } as never,
    }));

    expect(result.records[0]).toEqual(expect.objectContaining({
      canEdit: false,
      primaryActionLabel: undefined,
      collectionName: 'payouts',
    }));
  });
});
