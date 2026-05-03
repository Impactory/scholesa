const callableMock = jest.fn(async () => ({ data: { status: 'ok', id: 'audit-1' } }));
const httpsCallableMock = jest.fn((_functionsArg: unknown, _name: string) => callableMock);

jest.mock('firebase/functions', () => ({
  httpsCallable: (functionsArg: unknown, name: string) => httpsCallableMock(functionsArg, name),
}));

jest.mock('@/src/firebase/client-init', () => ({
  functions: { app: 'test-app' },
}));

import {
  recordReportDeliveryAudit,
  resolveReportDeliveryBlockReason,
} from '@/src/lib/reports/reportDeliveryAudit';
import { recordReportDeliveryLifecycle } from '@/src/lib/reports/reportDeliveryLifecycle';
import {
  createReportShareRequest,
  shouldCreateReportShareRequest,
} from '@/src/lib/reports/reportShareRequests';
import type { ReportProvenanceMetadata } from '@/src/lib/reports/shareExport';

function buildMetadata(
  overrides: Partial<ReportProvenanceMetadata> = {}
): ReportProvenanceMetadata {
  return {
    report_provenance_signal_count: 8,
    report_provenance_contract_required: true,
    report_has_evidence_signal: true,
    report_has_growth_signal: true,
    report_has_portfolio_signal: true,
    report_has_mission_signal: true,
    report_has_proof_signal: true,
    report_has_ai_disclosure_signal: true,
    report_has_rubric_signal: true,
    report_has_reviewer_signal: true,
    report_has_verification_prompt_signal: true,
    report_expected_provenance_signals: ['evidence', 'growth'],
    report_missing_provenance_signals: [],
    report_meets_provenance_contract: true,
    report_share_policy_declared: true,
    report_share_audience: 'guardian',
    report_share_visibility: 'family',
    report_share_requires_evidence_provenance: true,
    report_share_requires_guardian_context: true,
    report_share_allows_external_sharing: false,
    report_share_includes_learner_identifiers: true,
    report_share_family_safe: true,
    report_missing_delivery_contract_fields: [],
    report_meets_delivery_contract: true,
    ...overrides,
  };
}

describe('recordReportDeliveryAudit', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('persists delivered report audit attempts through the callable', async () => {
    const metadata = buildMetadata();

    await recordReportDeliveryAudit({
      siteId: 'site-1',
      learnerId: 'learner-1',
      reportAction: 'export_pdf',
      reportDelivery: 'downloaded',
      metadata,
      module: 'passport',
      surface: 'guardian_capability_view',
      cta: 'guardian_passport_export_pdf',
      fileName: 'family-passport-learner-1.pdf',
    });

    expect(httpsCallableMock).toHaveBeenCalledWith(
      { app: 'test-app' },
      'recordReportDeliveryAudit'
    );
    expect(callableMock).toHaveBeenCalledWith({
      siteId: 'site-1',
      learnerId: 'learner-1',
      reportAction: 'export_pdf',
      reportDelivery: 'downloaded',
      reportBlockReason: undefined,
      module: 'passport',
      surface: 'guardian_capability_view',
      cta: 'guardian_passport_export_pdf',
      fileName: 'family-passport-learner-1.pdf',
      shareRequestId: undefined,
      metadata,
    });
  });

  it('adds a block reason for missing share policy attempts', async () => {
    const metadata = buildMetadata({
      report_share_policy_declared: false,
      report_missing_delivery_contract_fields: ['sharePolicy'],
      report_meets_delivery_contract: false,
    });

    await recordReportDeliveryAudit({
      siteId: 'site-1',
      learnerId: 'learner-1',
      reportAction: 'share',
      reportDelivery: 'contract-failed',
      metadata,
      module: 'passport',
      surface: 'learner_passport_export',
      cta: 'learner_passport_share_family_summary',
    });

    expect(callableMock).toHaveBeenCalledWith(
      expect.objectContaining({
        reportDelivery: 'contract-failed',
        reportBlockReason: 'missing_share_policy',
      })
    );
  });

  it('does not call the server when required site, learner, or metadata is unavailable', async () => {
    await recordReportDeliveryAudit({
      siteId: null,
      learnerId: 'learner-1',
      reportAction: 'share',
      reportDelivery: 'copied',
      metadata: buildMetadata(),
      module: 'passport',
      surface: 'guardian_capability_view',
      cta: 'guardian_passport_share_family_summary',
    });

    expect(httpsCallableMock).not.toHaveBeenCalled();
  });

  it('passes share request linkage to the delivery audit callable', async () => {
    const metadata = buildMetadata();

    await recordReportDeliveryAudit({
      siteId: 'site-1',
      learnerId: 'learner-1',
      reportAction: 'share',
      reportDelivery: 'copied',
      metadata,
      module: 'passport',
      surface: 'guardian_capability_view',
      cta: 'guardian_passport_share_family_summary',
      shareRequestId: 'share-request-1',
    });

    expect(callableMock).toHaveBeenCalledWith(
      expect.objectContaining({
        shareRequestId: 'share-request-1',
      })
    );
  });
});

describe('report share request client helpers', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('only creates lifecycle records for completed deliveries with passing contracts', () => {
    expect(shouldCreateReportShareRequest('copied', buildMetadata())).toBe(true);
    expect(shouldCreateReportShareRequest('downloaded', buildMetadata())).toBe(true);
    expect(shouldCreateReportShareRequest('contract-failed', buildMetadata())).toBe(false);
    expect(shouldCreateReportShareRequest('aborted', buildMetadata())).toBe(false);
    expect(
      shouldCreateReportShareRequest(
        'copied',
        buildMetadata({
          report_meets_delivery_contract: false,
        })
      )
    ).toBe(false);
    expect(
      shouldCreateReportShareRequest(
        'copied',
        buildMetadata({
          report_share_policy_declared: false,
        })
      )
    ).toBe(false);
    expect(
      shouldCreateReportShareRequest(
        'copied',
        buildMetadata({
          report_share_family_safe: false,
        })
      )
    ).toBe(false);
    expect(
      shouldCreateReportShareRequest(
        'copied',
        buildMetadata({
          report_share_allows_external_sharing: true,
        })
      )
    ).toBe(false);
  });

  it('creates a report share request through the callable with policy metadata', async () => {
    const metadata = buildMetadata();

    const id = await createReportShareRequest({
      siteId: 'site-1',
      learnerId: 'learner-1',
      reportAction: 'share',
      reportDelivery: 'copied',
      metadata,
      module: 'passport',
      surface: 'guardian_capability_view',
      cta: 'guardian_passport_share_family_summary',
    });

    expect(id).toBe('audit-1');
    expect(httpsCallableMock).toHaveBeenCalledWith({ app: 'test-app' }, 'createReportShareRequest');
    expect(callableMock).toHaveBeenCalledWith(
      expect.objectContaining({
        siteId: 'site-1',
        learnerId: 'learner-1',
        reportAction: 'share',
        reportDelivery: 'copied',
        audience: 'guardian',
        visibility: 'family',
        metadata,
      })
    );
  });

  it('creates a share request before recording the linked delivery audit', async () => {
    callableMock
      .mockResolvedValueOnce({ data: { status: 'ok', id: 'share-request-1' } })
      .mockResolvedValueOnce({ data: { status: 'ok', id: 'audit-1' } });

    const result = await recordReportDeliveryLifecycle({
      siteId: 'site-1',
      learnerId: 'learner-1',
      reportAction: 'share',
      reportDelivery: 'copied',
      metadata: buildMetadata(),
      module: 'passport',
      surface: 'guardian_capability_view',
      cta: 'guardian_passport_share_family_summary',
    });

    expect(result).toEqual({ shareRequestId: 'share-request-1', deliveryAuditId: 'audit-1' });
    expect(httpsCallableMock).toHaveBeenNthCalledWith(
      1,
      { app: 'test-app' },
      'createReportShareRequest'
    );
    expect(httpsCallableMock).toHaveBeenNthCalledWith(
      2,
      { app: 'test-app' },
      'recordReportDeliveryAudit'
    );
    expect(callableMock).toHaveBeenNthCalledWith(
      2,
      expect.objectContaining({
        reportDelivery: 'copied',
        shareRequestId: 'share-request-1',
      })
    );
  });
});

describe('resolveReportDeliveryBlockReason', () => {
  it('prefers missing share policy over missing provenance', () => {
    expect(
      resolveReportDeliveryBlockReason(
        buildMetadata({
          report_missing_delivery_contract_fields: ['sharePolicy'],
          report_missing_provenance_signals: ['evidence'],
        })
      )
    ).toBe('missing_share_policy');
  });

  it('returns missing provenance when expected signals are absent', () => {
    expect(
      resolveReportDeliveryBlockReason(
        buildMetadata({
          report_missing_provenance_signals: ['proof'],
        })
      )
    ).toBe('missing_provenance');
  });
});
