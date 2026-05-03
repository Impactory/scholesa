import {
  buildReportDeliveryAuditRecord,
  persistReportDeliveryAuditRecord,
  validateReportShareLifecycleMetadata,
} from './reportDeliveryAudit';

const mockSet = jest.fn(async () => undefined);
const mockDoc = jest.fn(() => ({
  id: 'audit-report-123',
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

describe('reportDeliveryAudit', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('accepts lifecycle metadata for a created linked share request', () => {
    expect(() =>
      validateReportShareLifecycleMetadata({
        shareRequestId: 'share-request-1',
        metadata: {
          report_share_request_lifecycle_expected: true,
          report_share_request_lifecycle_outcome: 'created',
          report_share_request_created: true,
          report_share_request_skipped_reason: null,
        },
      })
    ).not.toThrow();
  });

  it('accepts skipped lifecycle metadata with a canonical reason', () => {
    expect(() =>
      validateReportShareLifecycleMetadata({
        metadata: {
          report_share_request_lifecycle_expected: false,
          report_share_request_lifecycle_outcome: 'skipped',
          report_share_request_created: false,
          report_share_request_skipped_reason: 'unsupported_visibility',
        },
      })
    ).not.toThrow();
  });

  it('accepts actor-policy-misaligned skipped lifecycle metadata', () => {
    expect(() =>
      validateReportShareLifecycleMetadata({
        metadata: {
          report_share_request_lifecycle_expected: false,
          report_share_request_lifecycle_outcome: 'skipped',
          report_share_request_created: false,
          report_share_request_skipped_reason: 'actor_policy_misaligned',
        },
      })
    ).not.toThrow();
  });

  it('rejects skipped lifecycle metadata with a non-canonical reason', () => {
    expect(() =>
      validateReportShareLifecycleMetadata({
        metadata: {
          report_share_request_lifecycle_expected: false,
          report_share_request_lifecycle_outcome: 'skipped',
          report_share_request_created: false,
          report_share_request_skipped_reason: 'manual_review_needed',
        },
      })
    ).toThrow('Skipped report share lifecycle reason is unsupported.');
  });

  it('rejects lifecycle metadata that claims creation without a linked share request', () => {
    expect(() =>
      validateReportShareLifecycleMetadata({
        metadata: {
          report_share_request_lifecycle_expected: true,
          report_share_request_lifecycle_outcome: 'created',
          report_share_request_created: true,
          report_share_request_skipped_reason: null,
        },
      })
    ).toThrow('Report share lifecycle metadata requires a linked share request.');
  });

  it('rejects linked share request metadata that does not claim creation', () => {
    expect(() =>
      validateReportShareLifecycleMetadata({
        shareRequestId: 'share-request-1',
        metadata: {
          report_share_request_lifecycle_expected: false,
          report_share_request_lifecycle_outcome: 'skipped',
          report_share_request_created: false,
          report_share_request_skipped_reason: 'unsupported_visibility',
        },
      })
    ).toThrow('Report share lifecycle metadata conflicts with linked share request.');
  });

  it('accepts expected-but-missing lifecycle metadata when callable creation returns no id', () => {
    expect(() =>
      validateReportShareLifecycleMetadata({
        metadata: {
          report_share_request_lifecycle_expected: true,
          report_share_request_lifecycle_outcome: 'expected_but_missing',
          report_share_request_created: false,
          report_share_request_skipped_reason: null,
        },
      })
    ).not.toThrow();
  });

  it('builds a durable delivered report audit payload', () => {
    const record = buildReportDeliveryAuditRecord({
      actorId: 'learner-1',
      actorRole: 'learner',
      learnerId: 'learner-1',
      reportAction: 'export_pdf',
      reportDelivery: 'downloaded',
      siteId: 'site-1',
      details: {
        report_share_policy_declared: true,
        report_meets_delivery_contract: true,
      },
    });

    expect(record).toMatchObject({
      actorId: 'learner-1',
      actorRole: 'learner',
      userId: 'learner-1',
      action: 'report.delivery_recorded',
      entityType: 'learnerReport',
      entityId: 'learner-1',
      targetType: 'learner',
      targetId: 'learner-1',
      siteId: 'site-1',
    });
    expect(record.details).toMatchObject({
      learnerId: 'learner-1',
      reportAction: 'export_pdf',
      reportDelivery: 'downloaded',
      report_share_policy_declared: true,
      report_meets_delivery_contract: true,
    });
    expect(record.metadata).toEqual(record.details);
    expect(record.createdAt).toBeDefined();
  });

  it('builds a durable blocked report audit payload with the block reason', () => {
    const record = buildReportDeliveryAuditRecord({
      actorId: 'parent-1',
      actorRole: 'parent',
      learnerId: 'learner-1',
      reportAction: 'share',
      reportDelivery: 'contract-failed',
      siteId: 'site-1',
      reportBlockReason: 'missing_share_policy',
      details: {
        report_share_policy_declared: false,
        report_missing_delivery_contract_fields: ['sharePolicy'],
      },
    });

    expect(record.action).toBe('report.delivery_blocked');
    expect(record.details).toMatchObject({
      learnerId: 'learner-1',
      reportAction: 'share',
      reportDelivery: 'contract-failed',
      reportBlockReason: 'missing_share_policy',
      report_share_policy_declared: false,
      report_missing_delivery_contract_fields: ['sharePolicy'],
    });
  });

  it('writes the report delivery audit record to auditLogs', async () => {
    const id = await persistReportDeliveryAuditRecord({
      actorId: 'site-operator-1',
      actorRole: 'site',
      learnerId: 'learner-2',
      reportAction: 'export_text',
      reportDelivery: 'downloaded',
      siteId: 'site-9',
      details: { surface: 'guardian_passport' },
    });
    const writes = mockSet.mock.calls as unknown as Array<[Record<string, unknown>]>;

    expect(id).toBe('audit-report-123');
    expect(mockCollection).toHaveBeenCalledWith('auditLogs');
    expect(mockDoc).toHaveBeenCalledTimes(1);
    expect(mockSet).toHaveBeenCalledTimes(1);
    expect(writes[0][0]).toMatchObject({
      actorId: 'site-operator-1',
      actorRole: 'site',
      action: 'report.delivery_recorded',
      entityType: 'learnerReport',
      entityId: 'learner-2',
      targetId: 'learner-2',
      siteId: 'site-9',
      details: {
        surface: 'guardian_passport',
        learnerId: 'learner-2',
        reportAction: 'export_text',
        reportDelivery: 'downloaded',
      },
    });
  });
});
