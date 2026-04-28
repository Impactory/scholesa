export type BrowserShareStatus = 'shared' | 'copied' | 'unavailable' | 'aborted';

export type ReportProvenanceSignal =
  | 'evidence'
  | 'growth'
  | 'portfolio'
  | 'mission'
  | 'proof'
  | 'aiDisclosure'
  | 'rubric'
  | 'reviewer'
  | 'verificationPrompt';

export interface ReportProvenanceMetadata {
  report_provenance_signal_count: number;
  report_provenance_contract_required: boolean;
  report_has_evidence_signal: boolean;
  report_has_growth_signal: boolean;
  report_has_portfolio_signal: boolean;
  report_has_mission_signal: boolean;
  report_has_proof_signal: boolean;
  report_has_ai_disclosure_signal: boolean;
  report_has_rubric_signal: boolean;
  report_has_reviewer_signal: boolean;
  report_has_verification_prompt_signal: boolean;
  report_expected_provenance_signals: ReportProvenanceSignal[];
  report_missing_provenance_signals: ReportProvenanceSignal[];
  report_meets_provenance_contract: boolean;
}

type ReportProvenanceHandler = (metadata: ReportProvenanceMetadata) => void;

export const passportReportProvenanceSignals: ReportProvenanceSignal[] = [
  'evidence',
  'growth',
  'portfolio',
  'mission',
  'proof',
  'aiDisclosure',
  'rubric',
  'reviewer',
  'verificationPrompt',
];

export const familySummaryProvenanceSignals: ReportProvenanceSignal[] = [
  'evidence',
  'growth',
  'portfolio',
  'proof',
  'aiDisclosure',
  'rubric',
  'reviewer',
  'verificationPrompt',
];

export function reportProvenanceMetadata({
  text,
  expectedSignals = [],
}: {
  text: string;
  expectedSignals?: readonly ReportProvenanceSignal[];
}): ReportProvenanceMetadata {
  const normalized = text.toLowerCase();
  const hasEvidence = containsAny(normalized, [
    'evidence id',
    'evidence record',
    'evidence link',
    'linked evidence',
    'reviewed evidence',
    'evidence-backed',
  ]);
  const hasGrowth = containsAny(normalized, [
    'growth provenance',
    'growth timeline',
    'growth event',
    'recorded growth',
    'recent growth',
  ]);
  const hasPortfolio = containsAny(normalized, [
    'portfolio evidence',
    'portfolio item',
    'portfolio artifact',
    'portfolio artifacts',
    'portfolio link',
    'portfolio highlights',
  ]);
  const hasMission = containsAny(normalized, [
    'mission attempt id',
    'mission attempt ids',
    'mission-linked',
    'mission link',
    'mission links',
    'missions attempted',
  ]);
  const hasProof = containsAny(normalized, [
    'proof-of-learning',
    'proof of learning',
    'proof status',
    'proof detail',
    'proof methods',
    ' proof ',
  ]);
  const hasAiDisclosure = containsAny(normalized, [
    'ai disclosure',
    'ai-assisted',
    'ai use',
    'learner ai',
  ]);
  const hasRubric = containsAny(normalized, ['rubric score', 'rubric level', 'rubric ']);
  const hasReviewer = containsAny(normalized, [
    'reviewed by',
    'verified by',
    'educator review',
    'educator verifier',
  ]);
  const hasVerificationPrompt = containsAny(normalized, [
    'verification prompt',
    'verify next',
    'next verification prompt',
    'pending verification prompts',
  ]);
  const signalPresence: Record<ReportProvenanceSignal, boolean> = {
    evidence: hasEvidence,
    growth: hasGrowth,
    portfolio: hasPortfolio,
    mission: hasMission,
    proof: hasProof,
    aiDisclosure: hasAiDisclosure,
    rubric: hasRubric,
    reviewer: hasReviewer,
    verificationPrompt: hasVerificationPrompt,
  };
  const expected = Array.from(new Set(expectedSignals)).filter((signal) => signal in signalPresence);
  const missing = expected.filter((signal) => !signalPresence[signal]);

  return {
    report_provenance_signal_count: Object.values(signalPresence).filter(Boolean).length,
    report_provenance_contract_required: expected.length > 0,
    report_has_evidence_signal: hasEvidence,
    report_has_growth_signal: hasGrowth,
    report_has_portfolio_signal: hasPortfolio,
    report_has_mission_signal: hasMission,
    report_has_proof_signal: hasProof,
    report_has_ai_disclosure_signal: hasAiDisclosure,
    report_has_rubric_signal: hasRubric,
    report_has_reviewer_signal: hasReviewer,
    report_has_verification_prompt_signal: hasVerificationPrompt,
    report_expected_provenance_signals: expected,
    report_missing_provenance_signals: missing,
    report_meets_provenance_contract: missing.length === 0,
  };
}

export function assertReportProvenanceContract({
  text,
  expectedSignals,
  reportName = 'report',
}: {
  text: string;
  expectedSignals: readonly ReportProvenanceSignal[];
  reportName?: string;
}): ReportProvenanceMetadata {
  const metadata = reportProvenanceMetadata({ text, expectedSignals });
  if (!metadata.report_meets_provenance_contract) {
    throw new Error(
      `${reportName} is missing report provenance signals: ${metadata.report_missing_provenance_signals.join(', ')}`
    );
  }
  return metadata;
}

function containsAny(normalized: string, terms: readonly string[]): boolean {
  return terms.some((term) => normalized.includes(term));
}

export async function shareTextWithFallback({
  title,
  text,
  expectedProvenanceSignals = [],
  onReportProvenance,
}: {
  title: string;
  text: string;
  expectedProvenanceSignals?: readonly ReportProvenanceSignal[];
  onReportProvenance?: ReportProvenanceHandler;
}): Promise<BrowserShareStatus> {
  onReportProvenance?.(
    reportProvenanceMetadata({ text, expectedSignals: expectedProvenanceSignals })
  );

  try {
    if (typeof navigator !== 'undefined' && typeof navigator.share === 'function') {
      await navigator.share({ title, text });
      return 'shared';
    }

    if (typeof navigator !== 'undefined' && navigator.clipboard?.writeText) {
      await navigator.clipboard.writeText(text);
      return 'copied';
    }

    return 'unavailable';
  } catch (err) {
    if (typeof DOMException !== 'undefined' && err instanceof DOMException && err.name === 'AbortError') {
      return 'aborted';
    }

    return 'unavailable';
  }
}

export function downloadTextReport({
  fileName,
  lines,
  expectedProvenanceSignals = [],
  onReportProvenance,
}: {
  fileName: string;
  lines: string[];
  expectedProvenanceSignals?: readonly ReportProvenanceSignal[];
  onReportProvenance?: ReportProvenanceHandler;
}): boolean {
  const text = lines.join('\n');
  onReportProvenance?.(
    reportProvenanceMetadata({ text, expectedSignals: expectedProvenanceSignals })
  );

  if (
    typeof document === 'undefined' ||
    typeof URL === 'undefined' ||
    typeof URL.createObjectURL !== 'function' ||
    typeof URL.revokeObjectURL !== 'function' ||
    typeof Blob === 'undefined'
  ) {
    return false;
  }

  const blob = new Blob([text], { type: 'text/plain' });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement('a');
  anchor.href = url;
  anchor.download = fileName;
  anchor.style.display = 'none';

  try {
    document.body?.appendChild(anchor);
    anchor.click();
    anchor.remove();
  } finally {
    URL.revokeObjectURL(url);
  }

  return true;
}