import {
  buildReportShareRequestRecord,
  buildReportShareRequestRevocationAuditDetails,
  canCreateReportShareRequestForPolicy,
  doesReportShareRequestMatchDeliveryAudit,
  expectedReportShareRevocationReason,
  isActiveUnexpiredReportShareRequestRecord,
  isReportShareRevocationReasonAllowedForActor,
  linkReportShareRequestDeliveryAuditRecord,
  persistReportShareRequestRecord,
  reportShareRequestHasEvidenceProvenanceContract,
  revokeReportShareRequestsLinkedToConsentRecord,
  revokeReportShareRequestRecord,
} from './reportShareRequests';

const mockSet = jest.fn(async () => undefined);
const mockUpdate = jest.fn(async () => undefined);
const mockBatchUpdate = jest.fn();
const mockBatchCommit = jest.fn(async () => undefined);
const mockDoc = jest.fn((id?: string) => ({
  id: id ?? 'share-request-123',
  set: mockSet,
  update: mockUpdate,
}));
const mockCollection = jest.fn(() => ({
  doc: mockDoc,
}));
const mockBatch = jest.fn(() => ({
  update: mockBatchUpdate,
  commit: mockBatchCommit,
}));

jest.mock('firebase-admin', () => ({
  firestore: jest.fn(() => ({
    collection: mockCollection,
    batch: mockBatch,
  })),
}));

describe('reportShareRequests', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('builds an active share request with expiry, policy, and provenance', () => {
    const expiresAt = new Date('2026-05-01T00:00:00.000Z');
    const record = buildReportShareRequestRecord('share-1', {
      actorId: 'parent-1',
      actorRole: 'parent',
      learnerId: 'learner-1',
      siteId: 'site-1',
      reportAction: 'share',
      reportDelivery: 'copied',
      audience: 'guardian',
      visibility: 'family',
      expiresAt,
      source: 'passport',
      surface: 'guardian_capability_view',
      cta: 'guardian_passport_share_family_summary',
      explicitConsentId: 'consent-1',
      sharePolicy: {
        requiresEvidenceProvenance: true,
        requiresGuardianContext: true,
        allowsExternalSharing: false,
        includesLearnerIdentifiers: true,
      },
      provenance: {
        expectedSignals: ['evidence', 'growth'],
        missingSignals: [],
        meetsProvenanceContract: true,
        meetsDeliveryContract: true,
        sharePolicyDeclared: true,
      },
    });

    expect(record).toMatchObject({
      id: 'share-1',
      siteId: 'site-1',
      learnerId: 'learner-1',
      createdBy: 'parent-1',
      createdByRole: 'parent',
      status: 'active',
      reportAction: 'share',
      reportDelivery: 'copied',
      audience: 'guardian',
      visibility: 'family',
      source: 'passport',
      surface: 'guardian_capability_view',
      cta: 'guardian_passport_share_family_summary',
      explicitConsentId: 'consent-1',
      sharePolicy: {
        requiresEvidenceProvenance: true,
        requiresGuardianContext: true,
        allowsExternalSharing: false,
        includesLearnerIdentifiers: true,
      },
      provenance: {
        expectedSignals: ['evidence', 'growth'],
        missingSignals: [],
        meetsProvenanceContract: true,
        meetsDeliveryContract: true,
        sharePolicyDeclared: true,
      },
    });
    expect(record.expiresAt).toBeDefined();
    expect(record.createdAt).toBeDefined();
    expect(record.updatedAt).toBeDefined();
  });

  it('persists a share request to reportShareRequests', async () => {
    const id = await persistReportShareRequestRecord({
      actorId: 'learner-1',
      actorRole: 'learner',
      learnerId: 'learner-1',
      siteId: 'site-1',
      reportAction: 'export_pdf',
      reportDelivery: 'downloaded',
      audience: 'learner',
      visibility: 'private',
      expiresAt: new Date('2026-05-01T00:00:00.000Z'),
      sharePolicy: {
        requiresEvidenceProvenance: true,
        requiresGuardianContext: false,
        allowsExternalSharing: false,
        includesLearnerIdentifiers: true,
      },
      provenance: {
        expectedSignals: ['evidence'],
        missingSignals: [],
        meetsProvenanceContract: true,
        meetsDeliveryContract: true,
        sharePolicyDeclared: true,
      },
    });
    const writes = mockSet.mock.calls as unknown as Array<[Record<string, unknown>]>;

    expect(id).toBe('share-request-123');
    expect(mockCollection).toHaveBeenCalledWith('reportShareRequests');
    expect(mockSet).toHaveBeenCalledTimes(1);
    expect(writes[0][0]).toMatchObject({
      id: 'share-request-123',
      status: 'active',
      learnerId: 'learner-1',
      audience: 'learner',
      visibility: 'private',
    });
  });

  it('identifies only active unexpired share request records as live lifecycle records', () => {
    const now = new Date('2026-05-01T12:00:00.000Z');

    expect(
      isActiveUnexpiredReportShareRequestRecord(
        {
          status: 'active',
          expiresAt: new Date('2026-05-02T12:00:00.000Z'),
        },
        now
      )
    ).toBe(true);
    expect(
      isActiveUnexpiredReportShareRequestRecord(
        {
          status: 'revoked',
          expiresAt: new Date('2026-05-02T12:00:00.000Z'),
        },
        now
      )
    ).toBe(false);
    expect(
      isActiveUnexpiredReportShareRequestRecord(
        {
          status: 'active',
          expiresAt: new Date('2026-04-30T12:00:00.000Z'),
        },
        now
      )
    ).toBe(false);
    expect(isActiveUnexpiredReportShareRequestRecord({ status: 'active' }, now)).toBe(false);
  });

  it('limits active share request creation to learner/private and guardian/family ownership', () => {
    expect(
      canCreateReportShareRequestForPolicy({
        actorId: 'learner-1',
        actorRole: 'learner',
        learnerId: 'learner-1',
        audience: 'learner',
        visibility: 'private',
      })
    ).toBe(true);
    expect(
      canCreateReportShareRequestForPolicy({
        actorId: 'parent-1',
        actorRole: 'parent',
        learnerId: 'learner-1',
        audience: 'guardian',
        visibility: 'family',
      })
    ).toBe(true);
    expect(
      canCreateReportShareRequestForPolicy({
        actorId: 'learner-1',
        actorRole: 'learner',
        learnerId: 'learner-1',
        audience: 'guardian',
        visibility: 'family',
      })
    ).toBe(false);
    expect(
      canCreateReportShareRequestForPolicy({
        actorId: 'learner-2',
        actorRole: 'learner',
        learnerId: 'learner-1',
        audience: 'learner',
        visibility: 'private',
      })
    ).toBe(false);
    expect(
      canCreateReportShareRequestForPolicy({
        actorId: 'educator-1',
        actorRole: 'educator',
        learnerId: 'learner-1',
        audience: 'guardian',
        visibility: 'family',
      })
    ).toBe(false);
  });

  it('requires non-empty, complete evidence provenance for report share records', () => {
    expect(
      reportShareRequestHasEvidenceProvenanceContract({
        requiresEvidenceProvenance: true,
        expectedSignals: ['evidence', 'proof'],
        missingSignals: [],
        meetsProvenanceContract: true,
      })
    ).toBe(true);
    expect(
      reportShareRequestHasEvidenceProvenanceContract({
        requiresEvidenceProvenance: false,
        expectedSignals: ['evidence'],
        missingSignals: [],
        meetsProvenanceContract: true,
      })
    ).toBe(false);
    expect(
      reportShareRequestHasEvidenceProvenanceContract({
        requiresEvidenceProvenance: true,
        expectedSignals: [],
        missingSignals: [],
        meetsProvenanceContract: true,
      })
    ).toBe(false);
    expect(
      reportShareRequestHasEvidenceProvenanceContract({
        requiresEvidenceProvenance: true,
        expectedSignals: ['evidence', 'proof'],
        missingSignals: ['proof'],
        meetsProvenanceContract: true,
      })
    ).toBe(false);
  });

  it('matches delivery-audit linkage only to the originating share request actor and delivery', () => {
    const shareRequestData = {
      createdBy: 'parent-1',
      learnerId: 'learner-1',
      siteId: 'site-1',
      reportAction: 'share',
      reportDelivery: 'copied',
    };

    expect(
      doesReportShareRequestMatchDeliveryAudit({
        data: shareRequestData,
        actorId: 'parent-1',
        learnerId: 'learner-1',
        siteId: 'site-1',
        reportAction: 'share',
        reportDelivery: 'copied',
      })
    ).toBe(true);
    expect(
      doesReportShareRequestMatchDeliveryAudit({
        data: shareRequestData,
        actorId: 'parent-2',
        learnerId: 'learner-1',
        siteId: 'site-1',
        reportAction: 'share',
        reportDelivery: 'copied',
      })
    ).toBe(false);
    expect(
      doesReportShareRequestMatchDeliveryAudit({
        data: shareRequestData,
        actorId: 'parent-1',
        learnerId: 'learner-1',
        siteId: 'site-1',
        reportAction: 'export_pdf',
        reportDelivery: 'downloaded',
      })
    ).toBe(false);
  });

  it('limits revocation reasons to the revoking actor role', () => {
    expect(expectedReportShareRevocationReason('learner')).toBe('learner_revoked_report_share');
    expect(expectedReportShareRevocationReason('parent')).toBe('guardian_revoked_report_share');
    expect(expectedReportShareRevocationReason('educator')).toBe('educator_revoked_report_share');
    expect(expectedReportShareRevocationReason('site')).toBe('site_revoked_report_share');
    expect(expectedReportShareRevocationReason('hq')).toBe('hq_revoked_report_share');
    expect(
      isReportShareRevocationReasonAllowedForActor({
        actorRole: 'parent',
        reason: 'guardian_revoked_report_share',
      })
    ).toBe(true);
    expect(
      isReportShareRevocationReasonAllowedForActor({
        actorRole: 'parent',
        reason: 'learner_revoked_report_share',
      })
    ).toBe(false);
  });

  it('builds revocation audit details with lifecycle and policy provenance', () => {
    const details = buildReportShareRequestRevocationAuditDetails({
      reason: 'guardian_revoked_report_share',
      data: {
        status: 'active',
        createdBy: 'parent-1',
        createdByRole: 'parent',
        audience: 'guardian',
        visibility: 'family',
        reportAction: 'share',
        reportDelivery: 'copied',
        deliveryAuditId: 'audit-1',
        source: 'passport',
        surface: 'guardian_capability_view',
        cta: 'guardian_passport_share_family_summary',
        fileName: 'family-passport.txt',
        sharePolicy: {
          requiresEvidenceProvenance: true,
          requiresGuardianContext: true,
          allowsExternalSharing: false,
          includesLearnerIdentifiers: true,
        },
        provenance: {
          meetsProvenanceContract: true,
          meetsDeliveryContract: true,
          sharePolicyDeclared: true,
        },
      },
    });

    expect(details).toMatchObject({
      reason: 'guardian_revoked_report_share',
      previousStatus: 'active',
      createdBy: 'parent-1',
      createdByRole: 'parent',
      audience: 'guardian',
      visibility: 'family',
      reportAction: 'share',
      reportDelivery: 'copied',
      deliveryAuditId: 'audit-1',
      source: 'passport',
      surface: 'guardian_capability_view',
      cta: 'guardian_passport_share_family_summary',
      fileName: 'family-passport.txt',
      sharePolicy: {
        requiresEvidenceProvenance: true,
        requiresGuardianContext: true,
        allowsExternalSharing: false,
        includesLearnerIdentifiers: true,
      },
      provenance: {
        meetsProvenanceContract: true,
        meetsDeliveryContract: true,
        sharePolicyDeclared: true,
      },
    });
  });

  it('revokes a share request without deleting the lifecycle record', async () => {
    await revokeReportShareRequestRecord({
      shareRequestId: 'share-request-1',
      actorId: 'learner-1',
      reason: 'learner_revoked_report_share',
    });
    const updates = mockUpdate.mock.calls as unknown as Array<[Record<string, unknown>]>;

    expect(mockCollection).toHaveBeenCalledWith('reportShareRequests');
    expect(mockDoc).toHaveBeenCalledWith('share-request-1');
    expect(mockUpdate).toHaveBeenCalledTimes(1);
    expect(updates[0][0]).toMatchObject({
      status: 'revoked',
      revokedBy: 'learner-1',
      revocationReason: 'learner_revoked_report_share',
    });
    expect(updates[0][0].revokedAt).toBeDefined();
    expect(updates[0][0].updatedAt).toBeDefined();
  });

  it('revokes linked report share requests when explicit consent is revoked', async () => {
    const revokedCount = await revokeReportShareRequestsLinkedToConsentRecord({
      shareRequestIds: ['share-request-1', 'share-request-2', 'share-request-1'],
      actorId: 'parent-1',
      reason: 'guardian_revoked_report_share',
    });

    expect(revokedCount).toBe(2);
    expect(mockBatch).toHaveBeenCalledTimes(1);
    expect(mockBatchUpdate).toHaveBeenCalledTimes(2);
    expect(mockCollection).toHaveBeenCalledWith('reportShareRequests');
    expect(mockDoc).toHaveBeenCalledWith('share-request-1');
    expect(mockDoc).toHaveBeenCalledWith('share-request-2');
    expect(mockBatchUpdate).toHaveBeenCalledWith(
      expect.any(Object),
      expect.objectContaining({
        status: 'revoked',
        revokedBy: 'parent-1',
        revocationReason: 'guardian_revoked_report_share',
      })
    );
    expect(mockBatchCommit).toHaveBeenCalledTimes(1);
  });

  it('links the lifecycle record back to the durable delivery audit', async () => {
    await linkReportShareRequestDeliveryAuditRecord({
      shareRequestId: 'share-request-1',
      deliveryAuditId: 'audit-1',
      reportDelivery: 'copied',
    });
    const updates = mockUpdate.mock.calls as unknown as Array<[Record<string, unknown>]>;

    expect(mockCollection).toHaveBeenCalledWith('reportShareRequests');
    expect(mockDoc).toHaveBeenCalledWith('share-request-1');
    expect(mockUpdate).toHaveBeenCalledTimes(1);
    expect(updates[0][0]).toMatchObject({
      deliveryAuditId: 'audit-1',
      reportDelivery: 'copied',
    });
    expect(updates[0][0].updatedAt).toBeDefined();
  });
});
