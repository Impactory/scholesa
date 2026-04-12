'use client';

import React, { useCallback, useEffect, useRef, useState } from 'react';
import { httpsCallable } from 'firebase/functions';
import { functions } from '@/src/firebase/client-init';
import { Spinner } from '@/src/components/ui/Spinner';
import { useInteractionTracking } from '@/src/hooks/useTelemetry';
import type { CustomRouteRendererProps } from '../customRouteRenderers';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface PillarProgress {
  pillarCode: 'FUTURE_SKILLS' | 'LEADERSHIP_AGENCY' | 'IMPACT_INNOVATION';
  label: string;
  percent: number;
  bandLabel: string;
}

interface GrowthEvent {
  id: string;
  capabilityTitle: string;
  levelAchieved: string;
  educatorName: string;
  date: string;
  proofStatus: 'verified' | 'partial' | 'missing';
}

interface PortfolioItem {
  id: string;
  title: string;
  verificationStatus: 'verified' | 'unverified' | 'pending';
  aiDisclosure:
    | 'none'
    | 'assisted'
    | 'generated'
    | 'learner-ai-not-used'
    | 'learner-ai-verified'
    | 'learner-ai-verification-gap'
    | 'educator-feedback-ai'
    | 'no-learner-ai-signal'
    | 'not-available';
  proofDetails: {
    explainItBack: boolean;
    oralCheck: boolean;
    miniRebuild: boolean;
    explainItBackExcerpt?: string;
    oralCheckExcerpt?: string;
    miniRebuildExcerpt?: string;
    educatorVerifierName?: string;
  };
  evidenceCount?: number;
  rubricScore?: { raw: number; max: number; level: string } | null;
}

interface IdeationPassportSummary {
  missionCount: number;
  reflectionsCount: number;
  capabilityClaimsCount: number;
  summaryText: string;
  claims?: PassportClaim[];
}

interface PassportClaim {
  capabilityId: string;
  capabilityTitle: string;
  pillarCode: string;
  level: string;
  evidenceCount: number;
  proofStatus: 'verified' | 'partial' | 'missing';
  aiDisclosureStatus: string;
  reviewerName?: string;
}

interface LearnerSummary {
  learnerId: string;
  name: string;
  currentLevelBand: 'strong' | 'developing' | 'emerging';
  attendanceRate: number;
  pillars: PillarProgress[];
  growthTimeline: GrowthEvent[];
  portfolioHighlights: PortfolioItem[];
  ideationPassport: IdeationPassportSummary | null;
  evidenceSummary?: {
    recordCount: number;
    reviewedCount: number;
    portfolioLinkedCount: number;
  };
  growthSummary?: {
    capabilityCount: number;
    updatedCount: number;
    averageLevel: number;
  };
  portfolioSnapshot?: {
    artifactCount: number;
    verifiedCount: number;
    badgeCount: number;
  };
}

interface ParentDashboardBundle {
  learners: LearnerSummary[];
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const LEVEL_BAND_CONFIG: Record<string, { label: string; className: string }> = {
  strong: { label: 'Strong', className: 'bg-green-100 text-green-800' },
  developing: { label: 'Developing', className: 'bg-yellow-100 text-yellow-800' },
  emerging: { label: 'Emerging', className: 'bg-orange-100 text-orange-800' },
};

const PROOF_STATUS_CONFIG: Record<string, { label: string; className: string }> = {
  verified: { label: 'Verified', className: 'bg-green-100 text-green-800' },
  partial: { label: 'Partial', className: 'bg-yellow-100 text-yellow-800' },
  missing: { label: 'Missing', className: 'bg-red-100 text-red-700' },
};

const VERIFICATION_CONFIG: Record<string, { label: string; className: string }> = {
  verified: { label: 'Verified', className: 'bg-green-100 text-green-800' },
  pending: { label: 'Pending', className: 'bg-yellow-100 text-yellow-800' },
  unverified: { label: 'Unverified', className: 'bg-gray-100 text-gray-600' },
};

const AI_DISCLOSURE_CONFIG: Record<string, { label: string; className: string }> = {
  // Legacy 3-value
  none: { label: 'No AI used', className: 'bg-gray-100 text-gray-600' },
  assisted: { label: 'AI-assisted', className: 'bg-blue-100 text-blue-700' },
  generated: { label: 'AI-generated', className: 'bg-purple-100 text-purple-700' },
  // Full 6-value from buildParentLearnerSummary
  'learner-ai-not-used': { label: 'No AI used', className: 'bg-gray-100 text-gray-600' },
  'learner-ai-verified': { label: 'AI used, verified', className: 'bg-green-100 text-green-700' },
  'learner-ai-verification-gap': { label: 'AI used, unverified', className: 'bg-orange-100 text-orange-700' },
  'educator-feedback-ai': { label: 'AI noted by educator', className: 'bg-blue-100 text-blue-700' },
  'no-learner-ai-signal': { label: 'AI status unknown', className: 'bg-yellow-100 text-yellow-700' },
  'not-available': { label: 'Not assessed', className: 'bg-gray-100 text-gray-500' },
};

const PILLAR_BAR_COLORS: Record<string, string> = {
  FUTURE_SKILLS: 'bg-blue-500',
  LEADERSHIP_AGENCY: 'bg-purple-500',
  IMPACT_INNOVATION: 'bg-emerald-500',
};

function formatDate(iso: string): string {
  try {
    return new Date(iso).toLocaleDateString(undefined, {
      month: 'short',
      day: 'numeric',
      year: 'numeric',
    });
  } catch {
    return iso;
  }
}

// ---------------------------------------------------------------------------
// Sub-components
// ---------------------------------------------------------------------------

function CheckMark({ checked, label }: { checked: boolean; label: string }): React.JSX.Element {
  return (
    <span className="inline-flex items-center gap-1 text-xs text-app-muted">
      {checked ? (
        <svg className="h-4 w-4 text-green-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
          <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
        </svg>
      ) : (
        <svg className="h-4 w-4 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
          <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
        </svg>
      )}
      {label}
    </span>
  );
}

function PillarProgressBar({ pillar }: { key?: React.Key; pillar: PillarProgress }): React.JSX.Element {
  const barColor = PILLAR_BAR_COLORS[pillar.pillarCode] ?? 'bg-gray-400';
  const clampedPercent = Math.max(0, Math.min(100, pillar.percent));

  return (
    <div data-testid={`pillar-${pillar.pillarCode}`}>
      <div className="mb-1 flex items-center justify-between text-sm">
        <span className="font-medium text-app-foreground">{pillar.label}</span>
        <span className="text-xs text-app-muted">
          {clampedPercent}% &middot; {pillar.bandLabel}
        </span>
      </div>
      <div className="h-2.5 w-full overflow-hidden rounded-full bg-app-canvas">
        <div
          className={`h-full rounded-full transition-all ${barColor}`}
          style={{ width: `${clampedPercent}%` }}
        />
      </div>
    </div>
  );
}

// ---------------------------------------------------------------------------
// Main Component
// ---------------------------------------------------------------------------

export default function GuardianCapabilityViewRenderer({ ctx }: CustomRouteRendererProps) {
  const trackInteraction = useInteractionTracking();
  const [learners, setLearners] = useState<LearnerSummary[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Route-specific focus: scroll to the section that matches the current URL
  const ROUTE_FOCUS: Record<string, { sectionId: string; subtitle: string }> = {
    '/parent/growth-timeline': {
      sectionId: 'guardian-growth-timeline',
      subtitle: "Track your child's capability growth over time — each step verified by their educator.",
    },
    '/parent/portfolio': {
      sectionId: 'guardian-portfolio-highlights',
      subtitle: "Review your child's portfolio work and proof of learning.",
    },
  };
  const focus = ROUTE_FOCUS[ctx.routePath ?? ''] ?? null;
  const focusRef = useRef<HTMLDivElement | null>(null);

  const fetchData = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const callable = httpsCallable<{ parentId: string }, ParentDashboardBundle>(
        functions,
        'getParentDashboardBundle'
      );
      const result = await callable({ parentId: ctx.uid });
      const bundle = result.data;

      setLearners(bundle.learners ?? []);
      trackInteraction('feature_discovered', { cta: 'guardian_capability_view_loaded' });
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Unable to load your family dashboard.');
    } finally {
      setLoading(false);
    }
  }, [ctx, trackInteraction]);

  useEffect(() => {
    void fetchData();
  }, [fetchData]);

  // Scroll to the focused section once data loads and the ref is attached
  useEffect(() => {
    if (!loading && focus && focusRef.current) {
      focusRef.current.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }
  }, [loading, focus]);

  // -- Loading state --
  if (loading) {
    return (
      <section
        className="flex min-h-[320px] items-center justify-center rounded-xl border border-app bg-app-surface"
        data-testid="guardian-view-loading"
      >
        <div className="flex items-center gap-2 text-app-muted">
          <Spinner />
          <span>Loading your family dashboard...</span>
        </div>
      </section>
    );
  }

  // -- Error state --
  if (error) {
    return (
      <section data-testid="guardian-view-error" className="space-y-4">
        <div className="rounded-xl border border-red-200 bg-red-50 p-4 text-sm text-red-700">
          {error}
        </div>
        <button
          type="button"
          onClick={() => void fetchData()}
          className="rounded-md bg-primary px-4 py-2 text-sm font-semibold text-primary-foreground"
        >
          Try again
        </button>
      </section>
    );
  }

  // -- Empty state: no linked learners --
  if (learners.length === 0) {
    return (
      <section
        className="rounded-xl border border-app bg-app-surface p-8 text-center"
        data-testid="guardian-view-empty"
      >
        <h2 className="text-lg font-semibold text-app-foreground">No learners linked yet</h2>
        <p className="mt-2 text-sm text-app-muted">
          Once your children are linked to your account, their learning progress will appear here.
        </p>
      </section>
    );
  }

  // -- Main view --
  return (
    <section className="space-y-8" data-testid="guardian-capability-view">
      <header className="rounded-xl border border-app bg-app-surface-raised p-6">
        <h1 className="text-2xl font-bold text-app-foreground">Family Learning Dashboard</h1>
        <p className="mt-2 text-sm text-app-muted">
          {focus?.subtitle ??
            'See what your children are learning, how they are growing, and the proof behind their achievements.'}
        </p>
      </header>

      {learners.map((learner: LearnerSummary, learnerIdx: number) => {
        const band = LEVEL_BAND_CONFIG[learner.currentLevelBand] ?? LEVEL_BAND_CONFIG.emerging;

        return (
          <article
            key={learner.learnerId}
            className="space-y-5 rounded-xl border border-app bg-app-surface p-5"
            data-testid={`learner-${learner.learnerId}`}
          >
            {/* ---- Learner Header ---- */}
            <div
              className="flex flex-wrap items-center gap-3"
              data-testid={`learner-header-${learner.learnerId}`}
            >
              <h2 className="text-xl font-bold text-app-foreground">{learner.name}</h2>
              <span className={`rounded-full px-2.5 py-0.5 text-xs font-medium ${band.className}`}>
                {band.label}
              </span>
              <span className="text-sm text-app-muted">
                Attendance: {Math.round(learner.attendanceRate * 100)}%
              </span>
            </div>

            {/* ---- Capability Snapshot ---- */}
            {learner.pillars.length > 0 && (
              <div
                className="rounded-lg border border-app bg-app-surface-raised p-4"
                data-testid={`capability-snapshot-${learner.learnerId}`}
              >
                <h3 className="mb-3 text-sm font-semibold text-app-foreground">
                  What {learner.name} can do
                </h3>
                <div className="space-y-3">
                  {learner.pillars.map((pillar: PillarProgress) => (
                    <PillarProgressBar key={pillar.pillarCode} pillar={pillar} />
                  ))}
                </div>
              </div>
            )}

            {/* ---- Evidence & Growth Summary ---- */}
            {(learner.evidenceSummary || learner.growthSummary || learner.portfolioSnapshot) && (
              <div
                className="grid grid-cols-2 gap-3 sm:grid-cols-3"
                data-testid={`summary-stats-${learner.learnerId}`}
              >
                {learner.evidenceSummary && (
                  <div className="rounded-lg border border-app bg-app-surface-raised p-3 text-center">
                    <p className="text-2xl font-bold text-app-foreground">
                      {learner.evidenceSummary.recordCount}
                    </p>
                    <p className="text-xs text-app-muted">Evidence records</p>
                    <p className="text-xs text-app-muted">
                      {learner.evidenceSummary.reviewedCount} reviewed &middot;{' '}
                      {learner.evidenceSummary.portfolioLinkedCount} in portfolio
                    </p>
                  </div>
                )}
                {learner.growthSummary && (
                  <div className="rounded-lg border border-app bg-app-surface-raised p-3 text-center">
                    <p className="text-2xl font-bold text-app-foreground">
                      {learner.growthSummary.updatedCount}/{learner.growthSummary.capabilityCount}
                    </p>
                    <p className="text-xs text-app-muted">Capabilities assessed</p>
                    <p className="text-xs text-app-muted">
                      Avg level: {learner.growthSummary.averageLevel.toFixed(1)}
                    </p>
                  </div>
                )}
                {learner.portfolioSnapshot && (
                  <div className="rounded-lg border border-app bg-app-surface-raised p-3 text-center">
                    <p className="text-2xl font-bold text-app-foreground">
                      {learner.portfolioSnapshot.artifactCount}
                    </p>
                    <p className="text-xs text-app-muted">Portfolio items</p>
                    <p className="text-xs text-app-muted">
                      {learner.portfolioSnapshot.verifiedCount} verified &middot;{' '}
                      {learner.portfolioSnapshot.badgeCount} badges
                    </p>
                  </div>
                )}
              </div>
            )}

            {/* ---- Growth Timeline ---- */}
            {learner.growthTimeline.length > 0 && (
              <div
                id="guardian-growth-timeline"
                ref={focus?.sectionId === 'guardian-growth-timeline' && learnerIdx === 0 ? focusRef : undefined}
                className="rounded-lg border border-app bg-app-surface-raised p-4"
                data-testid={`growth-timeline-${learner.learnerId}`}
              >
                <h3 className="mb-3 text-sm font-semibold text-app-foreground">
                  Recent growth
                </h3>
                <ul className="space-y-3">
                  {learner.growthTimeline.map((event: GrowthEvent) => {
                    const proofCfg =
                      PROOF_STATUS_CONFIG[event.proofStatus] ?? PROOF_STATUS_CONFIG.missing;
                    return (
                      <li
                        key={event.id}
                        className="flex flex-wrap items-start justify-between gap-2 rounded-md border border-app bg-app-canvas p-3"
                        data-testid={`growth-event-${event.id}`}
                      >
                        <div className="space-y-0.5">
                          <p className="text-sm font-medium text-app-foreground">
                            {event.capabilityTitle}
                          </p>
                          <p className="text-xs text-app-muted">
                            Achievement level: {event.levelAchieved}
                          </p>
                          <p className="text-xs text-app-muted">
                            Reviewed by {event.educatorName} &middot; {formatDate(event.date)}
                          </p>
                        </div>
                        <span
                          className={`whitespace-nowrap rounded-full px-2 py-0.5 text-xs font-medium ${proofCfg.className}`}
                        >
                          {proofCfg.label}
                        </span>
                      </li>
                    );
                  })}
                </ul>
              </div>
            )}

            {/* ---- Portfolio Highlights ---- */}
            {learner.portfolioHighlights.length > 0 && (
              <div
                id="guardian-portfolio-highlights"
                ref={focus?.sectionId === 'guardian-portfolio-highlights' && learnerIdx === 0 ? focusRef : undefined}
                className="rounded-lg border border-app bg-app-surface-raised p-4"
                data-testid={`portfolio-highlights-${learner.learnerId}`}
              >
                <h3 className="mb-3 text-sm font-semibold text-app-foreground">
                  Proof of learning
                </h3>
                <ul className="space-y-3">
                  {learner.portfolioHighlights.slice(0, 5).map((item: PortfolioItem) => {
                    const verifCfg =
                      VERIFICATION_CONFIG[item.verificationStatus] ??
                      VERIFICATION_CONFIG.unverified;
                    const aiCfg =
                      AI_DISCLOSURE_CONFIG[item.aiDisclosure] ?? AI_DISCLOSURE_CONFIG.none;

                    return (
                      <li
                        key={item.id}
                        className="rounded-md border border-app bg-app-canvas p-3"
                        data-testid={`portfolio-item-${item.id}`}
                      >
                        <div className="flex flex-wrap items-start justify-between gap-2">
                          <p className="text-sm font-medium text-app-foreground">{item.title}</p>
                          <div className="flex gap-1.5">
                            <span
                              className={`rounded-full px-2 py-0.5 text-xs font-medium ${verifCfg.className}`}
                            >
                              {verifCfg.label}
                            </span>
                            <span
                              className={`rounded-full px-2 py-0.5 text-xs font-medium ${aiCfg.className}`}
                            >
                              {aiCfg.label}
                            </span>
                          </div>
                        </div>
                        <div className="mt-2 flex flex-wrap gap-3">
                          <CheckMark
                            checked={item.proofDetails.explainItBack}
                            label="ExplainItBack"
                          />
                          <CheckMark checked={item.proofDetails.oralCheck} label="OralCheck" />
                          <CheckMark
                            checked={item.proofDetails.miniRebuild}
                            label="MiniRebuild"
                          />
                        </div>

                        {/* S3-4: Proof excerpts for parent transparency */}
                        {(item.proofDetails.explainItBackExcerpt ||
                          item.proofDetails.oralCheckExcerpt ||
                          item.proofDetails.miniRebuildExcerpt) && (
                          <div className="mt-2 space-y-1 rounded-md bg-blue-50 p-2 text-xs text-blue-900">
                            {item.proofDetails.explainItBackExcerpt && (
                              <p>
                                <span className="font-medium">Explained:</span>{' '}
                                &ldquo;{item.proofDetails.explainItBackExcerpt.slice(0, 120)}
                                {item.proofDetails.explainItBackExcerpt.length > 120 ? '…' : ''}&rdquo;
                              </p>
                            )}
                            {item.proofDetails.oralCheckExcerpt && (
                              <p>
                                <span className="font-medium">Oral check:</span>{' '}
                                &ldquo;{item.proofDetails.oralCheckExcerpt.slice(0, 120)}
                                {item.proofDetails.oralCheckExcerpt.length > 120 ? '…' : ''}&rdquo;
                              </p>
                            )}
                            {item.proofDetails.miniRebuildExcerpt && (
                              <p>
                                <span className="font-medium">Mini rebuild:</span>{' '}
                                &ldquo;{item.proofDetails.miniRebuildExcerpt.slice(0, 120)}
                                {item.proofDetails.miniRebuildExcerpt.length > 120 ? '…' : ''}&rdquo;
                              </p>
                            )}
                          </div>
                        )}

                        {/* S3-4: Educator verification and evidence count */}
                        <div className="mt-2 flex flex-wrap gap-3 text-xs text-app-muted">
                          {item.proofDetails.educatorVerifierName && (
                            <span>Verified by: {item.proofDetails.educatorVerifierName}</span>
                          )}
                          {typeof item.evidenceCount === 'number' && item.evidenceCount > 0 && (
                            <span>{item.evidenceCount} evidence record{item.evidenceCount !== 1 ? 's' : ''}</span>
                          )}
                          {item.rubricScore && (
                            <span>
                              Rubric: {item.rubricScore.raw}/{item.rubricScore.max} ({item.rubricScore.level})
                            </span>
                          )}
                        </div>
                      </li>
                    );
                  })}
                </ul>
              </div>
            )}

            {/* ---- Ideation Passport Summary ---- */}
            {learner.ideationPassport && (
              <div
                className="rounded-lg border border-app bg-app-surface-raised p-4"
                data-testid={`ideation-passport-${learner.learnerId}`}
              >
                <h3 className="mb-3 text-sm font-semibold text-app-foreground">
                  Ideation Passport
                </h3>
                <div className="mb-3 flex flex-wrap gap-4 text-sm text-app-muted">
                  <span>
                    <strong className="text-app-foreground">
                      {learner.ideationPassport.missionCount}
                    </strong>{' '}
                    missions
                  </span>
                  <span>
                    <strong className="text-app-foreground">
                      {learner.ideationPassport.reflectionsCount}
                    </strong>{' '}
                    reflections
                  </span>
                  <span>
                    <strong className="text-app-foreground">
                      {learner.ideationPassport.capabilityClaimsCount}
                    </strong>{' '}
                    capability claims
                  </span>
                </div>
                {learner.ideationPassport.summaryText && (
                  <p className="text-sm text-app-muted">
                    {learner.ideationPassport.summaryText}
                  </p>
                )}
                {/* Passport Claims Detail */}
                {learner.ideationPassport.claims && learner.ideationPassport.claims.length > 0 && (
                  <div className="mt-3 space-y-2">
                    <h4 className="text-xs font-semibold text-app-foreground">Capability claims</h4>
                    <ul className="space-y-1.5">
                      {learner.ideationPassport.claims.map((claim: PassportClaim) => {
                        const claimProofCfg = PROOF_STATUS_CONFIG[claim.proofStatus] ?? PROOF_STATUS_CONFIG.missing;
                        const claimAiCfg = AI_DISCLOSURE_CONFIG[claim.aiDisclosureStatus] ?? AI_DISCLOSURE_CONFIG['not-available'];
                        return (
                          <li
                            key={claim.capabilityId}
                            className="flex flex-wrap items-center gap-2 rounded-md border border-app bg-app-canvas px-2.5 py-1.5 text-xs"
                          >
                            <span className="font-medium text-app-foreground">{claim.capabilityTitle}</span>
                            <span className="text-app-muted">{claim.level}</span>
                            <span className={`rounded-full px-1.5 py-0.5 text-[10px] font-medium ${claimProofCfg.className}`}>
                              {claimProofCfg.label}
                            </span>
                            <span className={`rounded-full px-1.5 py-0.5 text-[10px] font-medium ${claimAiCfg.className}`}>
                              {claimAiCfg.label}
                            </span>
                            <span className="text-app-muted">{claim.evidenceCount} evidence</span>
                            {claim.reviewerName && (
                              <span className="text-app-muted">by {claim.reviewerName}</span>
                            )}
                          </li>
                        );
                      })}
                    </ul>
                  </div>
                )}
              </div>
            )}
          </article>
        );
      })}
    </section>
  );
}
