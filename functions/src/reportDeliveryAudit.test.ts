import {
  buildReportDeliveryAuditRecord,
  persistReportDeliveryAuditRecord,
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
