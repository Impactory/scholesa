import {
  assertReportProvenanceContract,
  downloadTextReport,
  familyReportSharePolicy,
  familySummaryProvenanceSignals,
  learnerPrivateReportSharePolicy,
  passportReportProvenanceSignals,
  reportProvenanceMetadata,
  shareTextWithFallback,
  type ReportProvenanceMetadata,
} from '@/src/lib/reports/shareExport';

const richEvidenceReport = `
Family summary
Recent growth provenance:
- Evidence-backed reasoning: Proficient • proof Verified • rubric 3/4 • reviewed by Coach Rivera • 1 evidence links • 1 portfolio links • mission-linked
Featured portfolio evidence:
- Prototype Evidence • capabilities Evidence-backed reasoning • 1 evidence links • mission-linked • proof Verified • AI Learner declared no AI support used • rubric 3/4 • reviewed by Coach Rivera
Featured AI disclosure: Learner declared no AI support used
Mission Attempt ID: attempt-1
Next verification prompt: Explain the prototype tradeoff.
`;

describe('report share/export helpers', () => {
  const originalNavigator = Object.getOwnPropertyDescriptor(globalThis, 'navigator');

  afterEach(() => {
    if (originalNavigator) {
      Object.defineProperty(globalThis, 'navigator', originalNavigator);
    } else {
      Reflect.deleteProperty(globalThis, 'navigator');
    }
  });

  it('uses native share when available', async () => {
    const share = jest.fn().mockResolvedValue(undefined);
    Object.defineProperty(globalThis, 'navigator', {
      configurable: true,
      value: { share },
    });

    await expect(shareTextWithFallback({ title: 'Family summary', text: 'Evidence-backed' }))
      .resolves.toBe('shared');
    expect(share).toHaveBeenCalledWith({ title: 'Family summary', text: 'Evidence-backed' });
  });

  it('falls back to clipboard when native share is unavailable', async () => {
    const writeText = jest.fn().mockResolvedValue(undefined);
    Object.defineProperty(globalThis, 'navigator', {
      configurable: true,
      value: { clipboard: { writeText } },
    });

    await expect(shareTextWithFallback({ title: 'Family summary', text: 'Evidence-backed' }))
      .resolves.toBe('copied');
    expect(writeText).toHaveBeenCalledWith('Evidence-backed');
  });

  it('returns unavailable when no browser share channel exists', async () => {
    Reflect.deleteProperty(globalThis, 'navigator');

    await expect(shareTextWithFallback({ title: 'Family summary', text: 'Evidence-backed' }))
      .resolves.toBe('unavailable');
  });

  it('detects expected evidence-chain provenance signals', () => {
    const metadata = reportProvenanceMetadata({
      text: richEvidenceReport,
      expectedSignals: passportReportProvenanceSignals,
      sharePolicy: familyReportSharePolicy,
    });

    expect(metadata.report_provenance_signal_count).toBe(9);
    expect(metadata.report_has_evidence_signal).toBe(true);
    expect(metadata.report_has_growth_signal).toBe(true);
    expect(metadata.report_has_portfolio_signal).toBe(true);
    expect(metadata.report_has_mission_signal).toBe(true);
    expect(metadata.report_has_proof_signal).toBe(true);
    expect(metadata.report_has_ai_disclosure_signal).toBe(true);
    expect(metadata.report_has_rubric_signal).toBe(true);
    expect(metadata.report_has_reviewer_signal).toBe(true);
    expect(metadata.report_has_verification_prompt_signal).toBe(true);
    expect(metadata.report_missing_provenance_signals).toEqual([]);
    expect(metadata.report_meets_provenance_contract).toBe(true);
    expect(metadata.report_share_policy_declared).toBe(true);
    expect(metadata.report_share_audience).toBe('guardian');
    expect(metadata.report_share_visibility).toBe('family');
    expect(metadata.report_share_requires_guardian_context).toBe(true);
    expect(metadata.report_share_family_safe).toBe(true);
    expect(metadata.report_missing_delivery_contract_fields).toEqual([]);
    expect(metadata.report_meets_delivery_contract).toBe(true);
    expect(metadata.report_provenance_contract_required).toBe(true);
  });

  it('exposes missing provenance signals for weak evidence-bearing reports', () => {
    const metadata = reportProvenanceMetadata({
      text: 'Family summary\nReviewed evidence: 1 evidence record',
      expectedSignals: familySummaryProvenanceSignals,
    });

    expect(metadata.report_has_evidence_signal).toBe(true);
    expect(metadata.report_meets_provenance_contract).toBe(false);
    expect(metadata.report_provenance_contract_required).toBe(true);
    expect(metadata.report_missing_provenance_signals).toEqual(
      expect.arrayContaining([
        'growth',
        'portfolio',
        'proof',
        'aiDisclosure',
        'rubric',
        'reviewer',
        'verificationPrompt',
      ])
    );
  });

  it('passes provenance metadata through share and download callbacks', async () => {
    const writeText = jest.fn().mockResolvedValue(undefined);
    const shareMetadata: ReportProvenanceMetadata[] = [];
    const downloadMetadata: ReportProvenanceMetadata[] = [];
    Object.defineProperty(globalThis, 'navigator', {
      configurable: true,
      value: { clipboard: { writeText } },
    });

    await expect(
      shareTextWithFallback({
        title: 'Family summary',
        text: richEvidenceReport,
        expectedProvenanceSignals: familySummaryProvenanceSignals,
        sharePolicy: familyReportSharePolicy,
        onReportProvenance: (metadata) => shareMetadata.push(metadata),
      })
    ).resolves.toBe('copied');

    const downloaded = downloadTextReport({
      fileName: 'passport.txt',
      lines: richEvidenceReport.trim().split('\n'),
      expectedProvenanceSignals: passportReportProvenanceSignals,
      sharePolicy: learnerPrivateReportSharePolicy,
      onReportProvenance: (metadata) => downloadMetadata.push(metadata),
    });

    expect(downloaded).toBe('unavailable');
    expect(shareMetadata).toHaveLength(1);
    expect(downloadMetadata).toHaveLength(1);
    expect(shareMetadata[0].report_meets_provenance_contract).toBe(true);
    expect(downloadMetadata[0].report_missing_provenance_signals).toEqual([]);
    expect(shareMetadata[0].report_share_audience).toBe('guardian');
    expect(downloadMetadata[0].report_share_visibility).toBe('private');
  });

  it('fails closed when enforced evidence-bearing reports omit a share policy', async () => {
    const share = jest.fn().mockResolvedValue(undefined);
    const metadataEvents: ReportProvenanceMetadata[] = [];
    Object.defineProperty(globalThis, 'navigator', {
      configurable: true,
      value: { share },
    });

    await expect(
      shareTextWithFallback({
        title: 'Passport',
        text: richEvidenceReport,
        expectedProvenanceSignals: passportReportProvenanceSignals,
        enforceProvenanceContract: true,
        onReportProvenance: (metadata) => metadataEvents.push(metadata),
      })
    ).resolves.toBe('contract-failed');

    expect(share).not.toHaveBeenCalled();
    expect(metadataEvents[0].report_meets_provenance_contract).toBe(true);
    expect(metadataEvents[0].report_share_policy_declared).toBe(false);
    expect(metadataEvents[0].report_missing_delivery_contract_fields).toEqual(['sharePolicy']);
    expect(metadataEvents[0].report_meets_delivery_contract).toBe(false);
  });

  it('fails closed before sharing or downloading weak evidence-bearing reports', async () => {
    const share = jest.fn().mockResolvedValue(undefined);
    const metadataEvents: ReportProvenanceMetadata[] = [];
    Object.defineProperty(globalThis, 'navigator', {
      configurable: true,
      value: { share },
    });

    await expect(
      shareTextWithFallback({
        title: 'Weak family summary',
        text: 'Family summary\nReviewed evidence: 1 evidence record',
        expectedProvenanceSignals: familySummaryProvenanceSignals,
        enforceProvenanceContract: true,
        sharePolicy: familyReportSharePolicy,
        onReportProvenance: (metadata) => metadataEvents.push(metadata),
      })
    ).resolves.toBe('contract-failed');

    const downloaded = downloadTextReport({
      fileName: 'weak-passport.txt',
      lines: ['Family summary', 'Reviewed evidence: 1 evidence record'],
      expectedProvenanceSignals: passportReportProvenanceSignals,
      enforceProvenanceContract: true,
      sharePolicy: learnerPrivateReportSharePolicy,
      onReportProvenance: (metadata) => metadataEvents.push(metadata),
    });

    expect(share).not.toHaveBeenCalled();
    expect(downloaded).toBe('contract-failed');
    expect(metadataEvents).toHaveLength(2);
    expect(metadataEvents[0].report_meets_provenance_contract).toBe(false);
    expect(metadataEvents[1].report_missing_provenance_signals).toEqual(
      expect.arrayContaining(['growth', 'portfolio', 'mission', 'proof'])
    );
    expect(metadataEvents[1].report_missing_delivery_contract_fields).toEqual([]);
  });

  it('supports release-gate assertions for evidence-bearing reports', () => {
    expect(() =>
      assertReportProvenanceContract({
        text: richEvidenceReport,
        expectedSignals: passportReportProvenanceSignals,
        reportName: 'learner passport',
      })
    ).not.toThrow();

    expect(() =>
      assertReportProvenanceContract({
        text: 'Family summary\nReviewed evidence: 1 evidence record',
        expectedSignals: familySummaryProvenanceSignals,
        reportName: 'weak family summary',
      })
    ).toThrow('weak family summary is missing report provenance signals: growth, portfolio, proof, aiDisclosure, rubric, reviewer, verificationPrompt');
  });
});