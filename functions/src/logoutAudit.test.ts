import { buildLogoutAuditRecord, persistLogoutAuditRecord } from './logoutAudit';

const mockSet = jest.fn(async () => undefined);
const mockDoc = jest.fn(() => ({
  id: 'audit-123',
  set: mockSet,
}));
const mockCollection = jest.fn(() => ({
  doc: mockDoc,
}));

jest.mock('firebase-admin', () => ({
  firestore: jest.fn(() => ({
    collection: mockCollection,
  })),
}));

describe('logoutAudit', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('builds the expected durable logout audit payload', () => {
    const record = buildLogoutAuditRecord({
      actorId: 'user-1',
      actorRole: 'educator',
      siteId: 'site-1',
      source: 'settings',
      impersonatingRole: 'parent',
    });

    expect(record.actorId).toBe('user-1');
    expect(record.actorRole).toBe('educator');
    expect(record.action).toBe('auth.logout');
    expect(record.entityType).toBe('session');
    expect(record.entityId).toBe('user-1');
    expect(record.siteId).toBe('site-1');
    expect(record.details).toEqual({
      source: 'settings',
      impersonatingRole: 'parent',
    });
    expect(record.createdAt).toBeDefined();
  });

  it('writes the logout audit record to auditLogs', async () => {
    const id = await persistLogoutAuditRecord({
      actorId: 'user-2',
      actorRole: 'hq',
      siteId: 'site-9',
      source: 'dashboard',
    });

    expect(id).toBe('audit-123');
    expect(mockCollection).toHaveBeenCalledWith('auditLogs');
    expect(mockDoc).toHaveBeenCalledTimes(1);
    expect(mockSet).toHaveBeenCalledTimes(1);
    expect(mockSet.mock.calls[0][0]).toMatchObject({
      actorId: 'user-2',
      actorRole: 'hq',
      action: 'auth.logout',
      entityType: 'session',
      entityId: 'user-2',
      siteId: 'site-9',
      details: { source: 'dashboard' },
    });
  });
});