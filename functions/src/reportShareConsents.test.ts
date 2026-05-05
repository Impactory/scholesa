import {
  buildReportShareConsentRecord,
  canDecideReportShareConsent,
  canRequestReportShareConsentForPolicy,
  canRevokeReportShareConsent,
  grantReportShareConsentRecord,
  isGrantedUnexpiredReportShareConsentRecord,
  isPendingUnexpiredReportShareConsentRecord,
  isReportShareConsentScope,
  persistReportShareConsentRecord,
  revokeReportShareConsentRecord,
} from './reportShareConsents';

const mockSet = jest.fn(async () => undefined);
const mockUpdate = jest.fn(async () => undefined);
const mockDoc = jest.fn((id?: string) => ({
  id: id ?? 'consent-123',
  set: mockSet,
  update: mockUpdate,
}));
const mockCollection = jest.fn(() => ({
  doc: mockDoc,
}));

jest.mock('firebase-admin', () => ({
  firestore: jest.fn(() => ({
    collection: mockCollection,
  })),
}));

describe('reportShareConsents', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('builds pending explicit consent records with purpose and evidence summary', () => {
    const record = buildReportShareConsentRecord('consent-1', {
      requesterId: 'educator-1',
      requesterRole: 'educator',
      learnerId: 'learner-1',
      siteId: 'site-1',
      scope: 'external',
      audience: 'external',
      visibility: 'external',
      purpose: 'Share portfolio with approved showcase reviewer.',
      evidenceSummary: 'Includes verified portfolio artifacts and rubric-backed growth.',
      expiresAt: new Date('2026-05-01T00:00:00.000Z'),
      linkedReportShareRequestIds: ['share-1'],
    });

    expect(record).toMatchObject({
      id: 'consent-1',
      siteId: 'site-1',
      learnerId: 'learner-1',
      requesterId: 'educator-1',
      requesterRole: 'educator',
      status: 'pending',
      scope: 'external',
      audience: 'external',
      visibility: 'external',
      purpose: 'Share portfolio with approved showcase reviewer.',
      evidenceSummary: 'Includes verified portfolio artifacts and rubric-backed growth.',
      linkedReportShareRequestIds: ['share-1'],
    });
    expect(record.requestedAt).toBeDefined();
    expect(record.expiresAt).toBeDefined();
    expect(record.createdAt).toBeDefined();
    expect(record.updatedAt).toBeDefined();
  });

  it('recognizes supported consent scopes', () => {
    expect(isReportShareConsentScope('partner')).toBe(true);
    expect(isReportShareConsentScope('external')).toBe(true);
    expect(isReportShareConsentScope('public')).toBe(true);
    expect(isReportShareConsentScope('private')).toBe(false);
  });

  it('limits consent requests to staff roles and matching broader scopes', () => {
    expect(
      canRequestReportShareConsentForPolicy({
        actorRole: 'educator',
        scope: 'partner',
        audience: 'partner',
        visibility: 'external',
      })
    ).toBe(true);
    expect(
      canRequestReportShareConsentForPolicy({
        actorRole: 'site',
        scope: 'public',
        audience: 'external',
        visibility: 'public',
      })
    ).toBe(true);
    expect(
      canRequestReportShareConsentForPolicy({
        actorRole: 'learner',
        scope: 'external',
        audience: 'external',
        visibility: 'external',
      })
    ).toBe(false);
    expect(
      canRequestReportShareConsentForPolicy({
        actorRole: 'educator',
        scope: 'family',
        audience: 'guardian',
        visibility: 'family',
      })
    ).toBe(false);
    expect(
      canRequestReportShareConsentForPolicy({
        actorRole: 'educator',
        scope: 'partner',
        audience: 'external',
        visibility: 'external',
      })
    ).toBe(false);
  });

  it('lets only learners and linked parents decide consent', () => {
    expect(
      canDecideReportShareConsent({
        actorId: 'learner-1',
        actorRole: 'learner',
        learnerId: 'learner-1',
      })
    ).toBe(true);
    expect(
      canDecideReportShareConsent({
        actorId: 'parent-1',
        actorRole: 'parent',
        learnerId: 'learner-1',
        linkedLearnerIds: ['learner-1'],
      })
    ).toBe(true);
    expect(
      canDecideReportShareConsent({
        actorId: 'educator-1',
        actorRole: 'educator',
        learnerId: 'learner-1',
      })
    ).toBe(false);
  });

  it('allows revocation by approver, requester, linked family, and site governance roles', () => {
    expect(
      canRevokeReportShareConsent({
        actorId: 'learner-1',
        actorRole: 'learner',
        learnerId: 'learner-1',
      })
    ).toBe(true);
    expect(
      canRevokeReportShareConsent({
        actorId: 'educator-1',
        actorRole: 'educator',
        learnerId: 'learner-1',
        requesterId: 'educator-1',
      })
    ).toBe(true);
    expect(
      canRevokeReportShareConsent({
        actorId: 'site-lead-1',
        actorRole: 'site',
        learnerId: 'learner-1',
      })
    ).toBe(true);
    expect(
      canRevokeReportShareConsent({
        actorId: 'educator-2',
        actorRole: 'educator',
        learnerId: 'learner-1',
        requesterId: 'educator-1',
      })
    ).toBe(false);
  });

  it('identifies pending and granted unexpired records', () => {
    const now = new Date('2026-05-01T12:00:00.000Z');

    expect(
      isPendingUnexpiredReportShareConsentRecord(
        { status: 'pending', expiresAt: new Date('2026-05-02T12:00:00.000Z') },
        now
      )
    ).toBe(true);
    expect(
      isPendingUnexpiredReportShareConsentRecord(
        { status: 'pending', expiresAt: new Date('2026-04-30T12:00:00.000Z') },
        now
      )
    ).toBe(false);
    expect(
      isGrantedUnexpiredReportShareConsentRecord(
        { status: 'granted', expiresAt: new Date('2026-05-02T12:00:00.000Z') },
        now
      )
    ).toBe(true);
    expect(
      isGrantedUnexpiredReportShareConsentRecord(
        { status: 'revoked', expiresAt: new Date('2026-05-02T12:00:00.000Z') },
        now
      )
    ).toBe(false);
  });

  it('persists, grants, and revokes consent records in the consent collection', async () => {
    const id = await persistReportShareConsentRecord({
      requesterId: 'educator-1',
      requesterRole: 'educator',
      learnerId: 'learner-1',
      siteId: 'site-1',
      scope: 'external',
      audience: 'external',
      visibility: 'external',
      purpose: 'Share passport with approved reviewer.',
      evidenceSummary: 'Verified portfolio evidence only.',
      expiresAt: new Date('2026-05-01T00:00:00.000Z'),
    });
    await grantReportShareConsentRecord({
      consentId: 'consent-1',
      approverId: 'parent-1',
      approverRole: 'parent',
    });
    await revokeReportShareConsentRecord({ consentId: 'consent-1', actorId: 'parent-1' });

    const writes = mockSet.mock.calls as unknown as Array<[Record<string, unknown>]>;
    const updates = mockUpdate.mock.calls as unknown as Array<[Record<string, unknown>]>;

    expect(id).toBe('consent-123');
    expect(mockCollection).toHaveBeenCalledWith('reportShareConsents');
    expect(writes[0][0]).toMatchObject({
      id: 'consent-123',
      status: 'pending',
      learnerId: 'learner-1',
      scope: 'external',
    });
    expect(updates[0][0]).toMatchObject({
      status: 'granted',
      approverId: 'parent-1',
      approverRole: 'parent',
    });
    expect(updates[1][0]).toMatchObject({
      status: 'revoked',
      revokedBy: 'parent-1',
    });
  });
});
