'use client';

import React, { useCallback, useEffect, useRef, useState } from 'react';
import dynamic from 'next/dynamic';
import { httpsCallable } from 'firebase/functions';
import { functions } from '@/src/firebase/client-init';
import { Spinner } from '@/src/components/ui/Spinner';
import { resolveActiveSiteId } from '@/src/lib/auth/activeSite';
import { useInteractionTracking } from '@/src/hooks/useTelemetry';
import { downloadTextReport, shareTextWithFallback } from '@/src/lib/reports/shareExport';
import type { CustomRouteRendererProps } from '../customRouteRenderers';

const ParentAnalyticsDashboard = dynamic(
  () =>
    import('@/src/components/analytics/ParentAnalyticsDashboard').then(
      (m) => m.ParentAnalyticsDashboard
    ),
  { loading: () => <div className="p-4 text-xs text-app-muted">Loading engagement data…</div> }
);

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
  linkedEvidenceCount: number;
  linkedPortfolioCount: number;
  missionAttemptId: string | null;
  rubricScore: { raw: number; max: number } | null;
}

interface ProcessDomainSnapshotEntry {
  processDomainId: string;
  title: string;
  currentLevel: string;
  highestLevel: string;
  evidenceCount: number;
  updatedAt: string | null;
}

interface ProcessDomainGrowthEvent {
  id: string;
  processDomainTitle: string;
  fromLevel: string;
  toLevel: string;
  educatorName: string;
  date: string | null;
  evidenceCount: number;
}

interface PortfolioItem {
  id: string;
  title: string;
  capabilityTitles: string[];
  source?: string | null;
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
  reviewedAt?: string | null;
  evidenceCount?: number;
  proofCheckpointCount?: number;
  missionAttemptId?: string | null;
  verificationPrompt?: string | null;
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
  verifiedArtifactCount: number;
  portfolioItemCount: number;
  missionAttemptCount: number;
  proofStatus: 'verified' | 'partial' | 'missing';
  aiDisclosureStatus: string;
  reviewerName?: string;
  reviewedAt?: string | null;
  rubricScore?: { raw: number; max: number } | null;
  proofHasExplainItBack: boolean;
  proofHasOralCheck: boolean;
  proofHasMiniRebuild: boolean;
  proofCheckpointCount: number;
  progressionDescriptor?: string;
}

interface LearnerSummary {
  learnerId: string;
  name: string;
  currentLevelBand: 'strong' | 'developing' | 'emerging' | 'not-yet-assessed';
  attendanceRate: number | null;
  pillars: PillarProgress[];
  growthTimeline: GrowthEvent[];
  processDomainSnapshot: ProcessDomainSnapshotEntry[];
  processDomainGrowthTimeline: ProcessDomainGrowthEvent[];
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
  learners: Array<Record<string, unknown>>;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const LEVEL_BAND_CONFIG: Record<string, { label: string; className: string }> = {
  strong: { label: 'Strong', className: 'bg-green-100 text-green-800' },
  developing: { label: 'Developing', className: 'bg-yellow-100 text-yellow-800' },
  emerging: { label: 'Emerging', className: 'bg-orange-100 text-orange-800' },
  'not-yet-assessed': { label: 'Not yet assessed', className: 'bg-gray-100 text-gray-600' },
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

function asRecord(value: unknown): Record<string, unknown> | null {
  return value && typeof value === 'object' && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : null;
}

function asString(value: unknown, fallback = ''): string {
  return typeof value === 'string' && value.trim().length > 0 ? value.trim() : fallback;
}

function asNumber(value: unknown): number | null {
  return typeof value === 'number' && Number.isFinite(value) ? value : null;
}

function asStringArray(value: unknown): string[] {
  return Array.isArray(value)
    ? value.filter((entry): entry is string => typeof entry === 'string' && entry.trim().length > 0).map((entry) => entry.trim())
    : [];
}

function toLevelBand(value: number | null): LearnerSummary['currentLevelBand'] {
  if (value == null) return 'not-yet-assessed';
  if (value >= 0.75) return 'strong';
  if (value >= 0.45) return 'developing';
  return 'emerging';
}

function toBandLabel(value: number | null): string {
  return LEVEL_BAND_CONFIG[toLevelBand(value)].label;
}

function toPercent(value: number | null): number {
  if (value == null) return 0;
  return Math.max(0, Math.min(100, Math.round(value * 100)));
}

function normalizeProofStatus(value: unknown): GrowthEvent['proofStatus'] {
  return value === 'verified' || value === 'partial' || value === 'missing'
    ? value
    : 'missing';
}

function normalizeVerificationStatus(value: unknown): PortfolioItem['verificationStatus'] {
  if (value === 'verified' || value === 'reviewed') return 'verified';
  if (value === 'pending' || value === 'captured') return 'pending';
  return 'unverified';
}

function normalizeAiDisclosure(value: unknown): PortfolioItem['aiDisclosure'] {
  const normalized = asString(value, 'not-available');
  return [
    'none',
    'assisted',
    'generated',
    'learner-ai-not-used',
    'learner-ai-verified',
    'learner-ai-verification-gap',
    'educator-feedback-ai',
    'no-learner-ai-signal',
    'not-available',
  ].includes(normalized)
    ? (normalized as PortfolioItem['aiDisclosure'])
    : 'not-available';
}

function normalizeLearnerBand(summary: Record<string, unknown>): LearnerSummary['currentLevelBand'] {
  const capabilitySnapshot = asRecord(summary.capabilitySnapshot);
  const band = asString(capabilitySnapshot?.band);
  if (
    band === 'strong' ||
    band === 'developing' ||
    band === 'emerging'
  ) {
    return band;
  }
  return toLevelBand(asNumber(capabilitySnapshot?.overall));
}

function formatLevel(value: unknown): string {
  const numeric = asNumber(value);
  return numeric != null && numeric > 0 ? `Level ${numeric}/4` : 'Not yet assessed';
}

function normalizePillarProgress(summary: Record<string, unknown>): PillarProgress[] {
  const pillarProgress = asRecord(summary.pillarProgress) ?? {};
  const capabilitySnapshot = asRecord(summary.capabilitySnapshot) ?? {};
  const familyLabels = asRecord(capabilitySnapshot.familyLabels) ?? {};
  const pillars: Array<{ key: 'futureSkills' | 'leadership' | 'impact'; pillarCode: PillarProgress['pillarCode'] }> = [
    { key: 'futureSkills', pillarCode: 'FUTURE_SKILLS' },
    { key: 'leadership', pillarCode: 'LEADERSHIP_AGENCY' },
    { key: 'impact', pillarCode: 'IMPACT_INNOVATION' },
  ];

  return pillars.map(({ key, pillarCode }) => {
    const ratio = asNumber(pillarProgress[key]);
    return {
      pillarCode,
      label: asString(familyLabels[key], pillarCode),
      percent: toPercent(ratio),
      bandLabel: toBandLabel(ratio),
    };
  });
}

function normalizeGrowthTimeline(summary: Record<string, unknown>): GrowthEvent[] {
  const growthTimeline = Array.isArray(summary.growthTimeline) ? summary.growthTimeline : [];
  return growthTimeline
    .map((entry, index) => {
      const row = asRecord(entry);
      if (!row) return null;
      const capabilityTitle = asString(row.title, asString(row.capabilityId, `Capability ${index + 1}`));
      return {
        id: asString(row.capabilityId, capabilityTitle) + ':' + asString(row.occurredAt, String(index)),
        capabilityTitle,
        levelAchieved: formatLevel(row.level),
        educatorName: asString(row.reviewingEducatorName, 'Educator review pending'),
        date: asString(row.occurredAt),
        proofStatus: normalizeProofStatus(row.proofOfLearningStatus),
        linkedEvidenceCount: asStringArray(row.linkedEvidenceRecordIds).length,
        linkedPortfolioCount: asStringArray(row.linkedPortfolioItemIds).length,
        missionAttemptId: asString(row.missionAttemptId) || null,
        rubricScore:
          asNumber(row.rubricRawScore) != null && asNumber(row.rubricMaxScore) != null
            ? {
                raw: asNumber(row.rubricRawScore) ?? 0,
                max: asNumber(row.rubricMaxScore) ?? 0,
              }
            : null,
      };
    })
    .filter((entry): entry is GrowthEvent => entry !== null);
}

function normalizePortfolioHighlights(summary: Record<string, unknown>): PortfolioItem[] {
  const previewRows = Array.isArray(summary.portfolioItemsPreview) ? summary.portfolioItemsPreview : [];
  const normalized: PortfolioItem[] = [];
  previewRows.forEach((entry, index) => {
    const row = asRecord(entry);
    if (!row) return;
    const rubricRawScore = asNumber(row.rubricRawScore);
    const rubricMaxScore = asNumber(row.rubricMaxScore);
    const rubricLevel = asNumber(row.rubricLevel);
    normalized.push({
      id: asString(row.id, `portfolio-item-${index + 1}`),
      title: asString(row.title, 'Portfolio artifact'),
      capabilityTitles: asStringArray(row.capabilityTitles),
      source: asString(row.source) || null,
      verificationStatus: normalizeVerificationStatus(row.verificationStatus),
      aiDisclosure: normalizeAiDisclosure(row.aiDisclosureStatus),
      proofDetails: {
        explainItBack: row.proofHasExplainItBack === true,
        oralCheck: row.proofHasOralCheck === true,
        miniRebuild: row.proofHasMiniRebuild === true,
        explainItBackExcerpt: asString(row.proofExplainItBackExcerpt) || undefined,
        oralCheckExcerpt: asString(row.proofOralCheckExcerpt) || undefined,
        miniRebuildExcerpt: asString(row.proofMiniRebuildExcerpt) || undefined,
        educatorVerifierName: asString(row.reviewingEducatorName) || undefined,
      },
      reviewedAt: asString(row.reviewedAt) || null,
      evidenceCount: asStringArray(row.evidenceRecordIds).length || undefined,
      proofCheckpointCount: asNumber(row.proofCheckpointCount) ?? undefined,
      missionAttemptId: asString(row.missionAttemptId) || null,
      verificationPrompt: asString(row.verificationPrompt) || null,
      rubricScore:
        rubricRawScore != null && rubricMaxScore != null
          ? {
              raw: rubricRawScore,
              max: rubricMaxScore,
              level: rubricLevel != null ? `Level ${rubricLevel}/4` : 'Scored',
            }
          : null,
    });
  });
  return normalized;
}

function normalizeIdeationPassport(summary: Record<string, unknown>): IdeationPassportSummary | null {
  const ideationPassport = asRecord(summary.ideationPassport);
  if (!ideationPassport) return null;
  const claims = Array.isArray(ideationPassport.claims) ? ideationPassport.claims : [];
  const normalizedClaims: PassportClaim[] = [];
  claims.forEach((entry) => {
    const row = asRecord(entry);
    if (!row) return;
    normalizedClaims.push({
      capabilityId: asString(row.capabilityId),
      capabilityTitle: asString(row.title, asString(row.capabilityId, 'Capability')),
      pillarCode: asString(row.pillar),
      level: formatLevel(row.latestLevel),
      evidenceCount: asNumber(row.evidenceCount) ?? 0,
      verifiedArtifactCount: asNumber(row.verifiedArtifactCount) ?? 0,
      portfolioItemCount: asStringArray(row.portfolioItemIds).length,
      missionAttemptCount: asStringArray(row.missionAttemptIds).length,
      proofStatus: normalizeProofStatus(row.proofOfLearningStatus),
      aiDisclosureStatus: asString(row.aiDisclosureStatus, 'not-available'),
      reviewerName: asString(row.reviewingEducatorName) || undefined,
      reviewedAt: asString(row.reviewedAt) || null,
      rubricScore:
        asNumber(row.rubricRawScore) != null && asNumber(row.rubricMaxScore) != null
          ? {
              raw: asNumber(row.rubricRawScore) ?? 0,
              max: asNumber(row.rubricMaxScore) ?? 0,
            }
          : null,
      proofHasExplainItBack: row.proofHasExplainItBack === true,
      proofHasOralCheck: row.proofHasOralCheck === true,
      proofHasMiniRebuild: row.proofHasMiniRebuild === true,
      proofCheckpointCount: asNumber(row.proofCheckpointCount) ?? 0,
      progressionDescriptor: asStringArray(row.progressionDescriptors)[0] || undefined,
    });
  });
  return {
    missionCount: asNumber(ideationPassport.completedMissions) ?? asNumber(ideationPassport.missionAttempts) ?? 0,
    reflectionsCount: asNumber(ideationPassport.reflectionsSubmitted) ?? 0,
    capabilityClaimsCount: normalizedClaims.length,
    summaryText: asString(ideationPassport.summary),
    claims: normalizedClaims,
  };
}

function normalizeProcessDomainSnapshot(summary: Record<string, unknown>): ProcessDomainSnapshotEntry[] {
  const snapshot = Array.isArray(summary.processDomainSnapshot) ? summary.processDomainSnapshot : [];
  return snapshot
    .map((entry, index) => {
      const row = asRecord(entry);
      if (!row) return null;
      return {
        processDomainId: asString(row.processDomainId, `process-domain-${index + 1}`),
        title: asString(row.title, asString(row.processDomainId, 'Process domain')),
        currentLevel: formatLevel(row.currentLevel),
        highestLevel: formatLevel(row.highestLevel),
        evidenceCount: asNumber(row.evidenceCount) ?? 0,
        updatedAt: asString(row.updatedAt) || null,
      };
    })
    .filter((entry): entry is ProcessDomainSnapshotEntry => entry !== null);
}

function normalizeProcessDomainGrowthTimeline(summary: Record<string, unknown>): ProcessDomainGrowthEvent[] {
  const growthTimeline = Array.isArray(summary.processDomainGrowthTimeline)
    ? summary.processDomainGrowthTimeline
    : [];
  return growthTimeline
    .map((entry, index) => {
      const row = asRecord(entry);
      if (!row) return null;
      return {
        id: `${asString(row.processDomainId, `process-domain-${index + 1}`)}:${asString(row.createdAt, String(index))}`,
        processDomainTitle: asString(row.title, asString(row.processDomainId, 'Process domain')),
        fromLevel: formatLevel(row.fromLevel),
        toLevel: formatLevel(row.toLevel),
        educatorName: asString(row.reviewingEducatorName, 'Educator review pending'),
        date: asString(row.createdAt) || null,
        evidenceCount: asNumber(row.evidenceCount) ?? 0,
      };
    })
    .filter((entry): entry is ProcessDomainGrowthEvent => entry !== null);
}

function normalizeLearnerSummary(summary: Record<string, unknown>): LearnerSummary {
  const growthSummary = asRecord(summary.growthSummary);
  const portfolioSnapshot = asRecord(summary.portfolioSnapshot);
  const evidenceSummary = asRecord(summary.evidenceSummary);

  return {
    learnerId: asString(summary.learnerId),
    name: asString(summary.learnerName, 'Learner'),
    currentLevelBand: normalizeLearnerBand(summary),
    attendanceRate: asNumber(summary.attendanceRate),
    pillars: normalizePillarProgress(summary),
    growthTimeline: normalizeGrowthTimeline(summary),
    processDomainSnapshot: normalizeProcessDomainSnapshot(summary),
    processDomainGrowthTimeline: normalizeProcessDomainGrowthTimeline(summary),
    portfolioHighlights: normalizePortfolioHighlights(summary),
    ideationPassport: normalizeIdeationPassport(summary),
    evidenceSummary: evidenceSummary
      ? {
          recordCount: asNumber(evidenceSummary.recordCount) ?? 0,
          reviewedCount: asNumber(evidenceSummary.reviewedCount) ?? 0,
          portfolioLinkedCount: asNumber(evidenceSummary.portfolioLinkedCount) ?? 0,
        }
      : undefined,
    growthSummary: growthSummary
      ? {
          capabilityCount: asNumber(growthSummary.capabilityCount) ?? 0,
          updatedCount: asNumber(growthSummary.updatedCapabilityCount) ?? 0,
          averageLevel: asNumber(growthSummary.averageLevel) ?? 0,
        }
      : undefined,
    portfolioSnapshot: portfolioSnapshot
      ? {
          artifactCount: asNumber(portfolioSnapshot.artifactCount) ?? 0,
          verifiedCount:
            asNumber(portfolioSnapshot.verifiedArtifactCount) ??
            asNumber(portfolioSnapshot.publishedArtifactCount) ??
            0,
          badgeCount: asNumber(portfolioSnapshot.badgeCount) ?? 0,
        }
      : undefined,
  };
}

function buildGuardianPassportTextLines(learner: LearnerSummary): string[] {
  const pendingPrompts = learner.portfolioHighlights.filter(
    (item) => typeof item.verificationPrompt === 'string' && item.verificationPrompt.trim().length > 0,
  );
  const lines: string[] = [];
  lines.push('═══════════════════════════════════════════');
  lines.push('  SCHOLESA FAMILY PASSPORT SUMMARY');
  lines.push('═══════════════════════════════════════════');
  lines.push('');
  lines.push(`Learner: ${learner.name}`);
  lines.push(`Prepared: ${formatDate(new Date().toISOString())}`);
  lines.push(`Capability Band: ${LEVEL_BAND_CONFIG[learner.currentLevelBand]?.label ?? 'Not yet assessed'}`);
  lines.push('');
  lines.push('── Report Basis ──');
  lines.push('  This summary reflects reviewed evidence, linked portfolio artifacts, and recorded growth events.');
  lines.push('  Participation signals do not replace capability judgments.');
  lines.push(`  Pending verification prompts: ${pendingPrompts.length}`);
  lines.push('');
  lines.push('── Capability Snapshot ──');
  if (learner.pillars.length === 0) {
    lines.push('  No capability snapshot is available yet.');
  }
  for (const pillar of learner.pillars) {
    lines.push(`  ${pillar.label}: ${pillar.percent}% (${pillar.bandLabel})`);
  }
  lines.push('');
  lines.push('── Evidence Summary ──');
  if (learner.evidenceSummary) {
    lines.push(`  Evidence records:      ${learner.evidenceSummary.recordCount}`);
    lines.push(`  Reviewed:              ${learner.evidenceSummary.reviewedCount}`);
    lines.push(`  Portfolio-linked:      ${learner.evidenceSummary.portfolioLinkedCount}`);
  } else {
    lines.push('  Evidence summary unavailable.');
  }
  lines.push('');
  lines.push('── Process Domains ──');
  if (learner.processDomainSnapshot.length === 0) {
    lines.push('  No process domain progress has been recorded yet.');
  } else {
    for (const domain of learner.processDomainSnapshot) {
      lines.push(`  ${domain.title}`);
      lines.push(`    Current level:   ${domain.currentLevel}`);
      lines.push(`    Highest level:   ${domain.highestLevel}`);
      lines.push(`    Evidence:        ${domain.evidenceCount}`);
      if (domain.updatedAt) {
        lines.push(`    Updated:         ${formatDate(domain.updatedAt)}`);
      }
    }
  }
  lines.push('');
  lines.push('── Capability Claims ──');
  if (!learner.ideationPassport?.claims || learner.ideationPassport.claims.length === 0) {
    lines.push('  No capability claims backed by reviewed evidence yet.');
  } else {
    for (const claim of learner.ideationPassport.claims) {
      lines.push('');
      lines.push(`  ${claim.capabilityTitle}`);
      lines.push(`    Level:           ${claim.level}`);
      lines.push(`    Evidence:        ${claim.evidenceCount} evidence, ${claim.verifiedArtifactCount} verified artifacts`);
      lines.push(`    Provenance:      ${claim.portfolioItemCount} portfolio item(s), ${claim.missionAttemptCount} mission attempt(s)`);
      lines.push(`    Proof-of-Learn:  ${PROOF_STATUS_CONFIG[claim.proofStatus]?.label ?? 'Missing'}`);
      lines.push(`    AI Disclosure:   ${AI_DISCLOSURE_CONFIG[claim.aiDisclosureStatus]?.label ?? 'Not assessed'}`);
      if (claim.reviewerName) {
        lines.push(`    Reviewed by:     ${claim.reviewerName}${claim.reviewedAt ? ` (${formatDate(claim.reviewedAt)})` : ''}`);
      }
      if (claim.rubricScore) {
        lines.push(`    Rubric Score:    ${claim.rubricScore.raw}/${claim.rubricScore.max}`);
      }
      if (claim.progressionDescriptor) {
        lines.push(`    Descriptor:      ${claim.progressionDescriptor}`);
      }
    }
  }
  lines.push('');
  lines.push('── Portfolio Highlights ──');
  if (learner.portfolioHighlights.length === 0) {
    lines.push('  No portfolio highlights are available yet.');
  } else {
    for (const item of learner.portfolioHighlights.slice(0, 5)) {
      lines.push('');
      lines.push(`  ${item.title}`);
      lines.push(`    Status:          ${VERIFICATION_CONFIG[item.verificationStatus]?.label ?? 'Unverified'}`);
      lines.push(`    AI Disclosure:   ${AI_DISCLOSURE_CONFIG[item.aiDisclosure]?.label ?? 'Not assessed'}`);
      lines.push(`    Proof methods:   ${[
        item.proofDetails.explainItBack ? 'ExplainItBack' : null,
        item.proofDetails.oralCheck ? 'OralCheck' : null,
        item.proofDetails.miniRebuild ? 'MiniRebuild' : null,
      ].filter(Boolean).join(' · ') || '—'}`);
      if (item.verificationPrompt) {
        lines.push(`    Verify next:     ${item.verificationPrompt}`);
      }
    }
  }
  lines.push('');
  lines.push('── Recent Process Domain Growth ──');
  if (learner.processDomainGrowthTimeline.length === 0) {
    lines.push('  No process domain growth events have been recorded yet.');
  } else {
    for (const event of learner.processDomainGrowthTimeline.slice(0, 5)) {
      lines.push(`  ${formatDate(event.date ?? new Date().toISOString())} · ${event.processDomainTitle}`);
      lines.push(`    Level change:    ${event.fromLevel} -> ${event.toLevel}`);
      lines.push(`    Reviewed by:     ${event.educatorName}`);
      lines.push(`    Evidence:        ${event.evidenceCount}`);
    }
  }
  lines.push('');
  lines.push('── Recent Growth ──');
  if (learner.growthTimeline.length === 0) {
    lines.push('  No growth events have been recorded yet.');
  } else {
    for (const event of learner.growthTimeline.slice(0, 5)) {
      lines.push(`  ${formatDate(event.date)} · ${event.capabilityTitle}`);
      lines.push(`    Level:           ${event.levelAchieved}`);
      lines.push(`    Proof status:    ${PROOF_STATUS_CONFIG[event.proofStatus]?.label ?? 'Missing'}`);
      lines.push(`    Provenance:      ${event.linkedEvidenceCount} evidence, ${event.linkedPortfolioCount} portfolio${event.missionAttemptId ? ', mission-linked' : ''}`);
    }
  }
  lines.push('');
  lines.push('═══════════════════════════════════════════');
  lines.push(`  ${learner.ideationPassport?.summaryText ?? 'No family passport summary available yet.'}`);
  lines.push('═══════════════════════════════════════════');
  return lines;
}

function buildGuardianFamilyShareSummary(learner: LearnerSummary): string {
  const pendingPrompts = learner.portfolioHighlights
    .filter((item) => typeof item.verificationPrompt === 'string' && item.verificationPrompt.trim().length > 0)
    .slice(0, 2);
  const topClaims = learner.ideationPassport?.claims?.slice(0, 3) ?? [];
  const featuredAiDisclosure = topClaims.length > 0
    ? AI_DISCLOSURE_CONFIG[topClaims[0].aiDisclosureStatus]?.label ?? 'Not assessed'
    : null;

  return [
    `Scholesa family summary for ${learner.name}`,
    `Prepared ${formatDate(new Date().toISOString())}`,
    'This summary reflects reviewed evidence, linked artifacts, and recorded growth events.',
    `Capability band: ${LEVEL_BAND_CONFIG[learner.currentLevelBand]?.label ?? 'Not yet assessed'}`,
    `Reviewed evidence: ${learner.evidenceSummary?.reviewedCount ?? 0}`,
    ...(featuredAiDisclosure ? [`Featured AI disclosure: ${featuredAiDisclosure}`] : []),
    `Pending verification prompts: ${pendingPrompts.length}`,
    '',
    'Current evidence-backed claims:',
    ...(topClaims.length > 0
      ? topClaims.map((claim) => `- ${claim.capabilityTitle}: ${claim.level} with ${claim.evidenceCount} evidence record(s)`)
      : ['- No capability claims backed by reviewed evidence yet.']),
    '',
    'Next verification prompts:',
    ...(pendingPrompts.length > 0
      ? pendingPrompts.map((item) => `- ${item.title}: ${item.verificationPrompt}`)
      : ['- No pending verification prompts in this summary.']),
  ].join('\n');
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
  const siteId = resolveActiveSiteId(ctx.profile);
  const [learners, setLearners] = useState<LearnerSummary[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [shareFeedback, setShareFeedback] = useState<{ learnerId: string; message: string } | null>(null);

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
    '/parent/passport': {
      sectionId: 'guardian-ideation-passport',
      subtitle: "See the capability claims, proof, and review trail that make up your child's passport.",
    },
  };
  const focus = ROUTE_FOCUS[ctx.routePath ?? ''] ?? null;
  const isSummaryRoute = ctx.routePath === '/parent/summary';
  const isPassportRoute = ctx.routePath === '/parent/passport';
  const showGuardianShareActions = isPassportRoute || isSummaryRoute;
  const focusRef = useRef<HTMLDivElement | null>(null);

  const fetchData = useCallback(async () => {
    if (!siteId) {
      setLearners([]);
      setError(null);
      setLoading(false);
      return;
    }
    setLoading(true);
    setError(null);
    try {
      const callable = httpsCallable<{ parentId: string; siteId?: string }, ParentDashboardBundle>(
        functions,
        'getParentDashboardBundle'
      );
      const result = await callable({ parentId: ctx.uid, siteId });
      const bundle = result.data;

      setLearners((bundle.learners ?? []).map(normalizeLearnerSummary));
      trackInteraction('feature_discovered', { cta: 'guardian_capability_view_loaded' });
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Unable to load your family dashboard.');
    } finally {
      setLoading(false);
    }
  }, [ctx.uid, siteId, trackInteraction]);

  useEffect(() => {
    void fetchData();
  }, [fetchData]);

  // Scroll to the focused section once data loads and the ref is attached
  useEffect(() => {
    if (!loading && focus && focusRef.current) {
      focusRef.current.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }
  }, [loading, focus]);

  useEffect(() => {
    if (!shareFeedback) return;
    const timeout = window.setTimeout(() => setShareFeedback(null), 4000);
    return () => window.clearTimeout(timeout);
  }, [shareFeedback]);

  const handleShareSummary = useCallback(async (learner: LearnerSummary) => {
    const shareText = buildGuardianFamilyShareSummary(learner);
    const result = await shareTextWithFallback({
      title: `Scholesa family summary for ${learner.name}`,
      text: shareText,
    });

    if (result === 'aborted') return;
    if (result === 'shared') {
      setShareFeedback({ learnerId: learner.learnerId, message: 'Family summary ready to share.' });
      return;
    }

    setShareFeedback({
      learnerId: learner.learnerId,
      message:
        result === 'copied'
          ? 'Family summary copied to clipboard.'
          : 'Sharing is unavailable in this browser. Use Export Text instead.',
    });
  }, []);

  const handleExportText = useCallback((learner: LearnerSummary) => {
    downloadTextReport({
      fileName: `family-passport-${learner.learnerId}.txt`,
      lines: buildGuardianPassportTextLines(learner),
    });
  }, []);

  const handleExportPdf = useCallback(async (learner: LearnerSummary) => {
    const { jsPDF } = await import('jspdf');
    const pdf = new jsPDF({ unit: 'pt', format: 'letter' });
    const pageWidth = pdf.internal.pageSize.getWidth();
    const pageHeight = pdf.internal.pageSize.getHeight();
    const marginX = 40;
    const marginY = 48;
    const lineHeight = 14;
    const maxWidth = pageWidth - (marginX * 2);
    let y = marginY;

    pdf.setFont('courier', 'normal');
    pdf.setFontSize(10);

    for (const line of buildGuardianPassportTextLines(learner)) {
      const wrapped = pdf.splitTextToSize(line, maxWidth) as string[];
      if (y + (wrapped.length * lineHeight) > pageHeight - marginY) {
        pdf.addPage();
        y = marginY;
      }
      pdf.text(wrapped, marginX, y);
      y += Math.max(wrapped.length, 1) * lineHeight;
    }

    pdf.save(`family-passport-${learner.learnerId}.pdf`);
  }, []);

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

  if (!siteId) {
    return (
      <section
        className="rounded-xl border border-amber-200 bg-amber-50 p-8 text-center"
        data-testid="guardian-view-site-required"
      >
        <h2 className="text-lg font-semibold text-amber-900">Active site required</h2>
        <p className="mt-2 text-sm text-amber-700">
          Select an active site before viewing your family evidence summary.
        </p>
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
              {learner.attendanceRate != null ? (
                <span className="text-sm text-app-muted">
                  Attendance: {Math.round(learner.attendanceRate * 100)}%
                </span>
              ) : (
                <span className="text-sm text-app-muted">Attendance evidence unavailable</span>
              )}
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
                          <p className="text-xs text-app-muted">
                            {event.linkedEvidenceCount} evidence &middot; {event.linkedPortfolioCount} portfolio item{event.linkedPortfolioCount === 1 ? '' : 's'}
                            {event.missionAttemptId ? ' · mission-linked' : ''}
                            {event.rubricScore ? ` · rubric ${event.rubricScore.raw}/${event.rubricScore.max}` : ''}
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
            {(learner.processDomainSnapshot.length > 0 || learner.processDomainGrowthTimeline.length > 0) && (
              <div className="rounded-lg border border-app bg-app-surface-raised p-4">
                <h3 className="mb-3 text-sm font-semibold text-app-foreground">
                  Process domains
                </h3>
                {learner.processDomainSnapshot.length > 0 ? (
                  <div className="grid gap-3 md:grid-cols-2">
                    {learner.processDomainSnapshot.map((domain) => (
                      <div
                        key={domain.processDomainId}
                        className="rounded-md border border-app bg-app-canvas p-3"
                      >
                        <p className="text-sm font-medium text-app-foreground">{domain.title}</p>
                        <p className="mt-1 text-xs text-app-muted">
                          Current {domain.currentLevel} · Highest {domain.highestLevel}
                        </p>
                        <p className="mt-1 text-xs text-app-muted">
                          {domain.evidenceCount} evidence{domain.evidenceCount === 1 ? '' : ' records'}
                          {domain.updatedAt ? ` · Updated ${formatDate(domain.updatedAt)}` : ''}
                        </p>
                      </div>
                    ))}
                  </div>
                ) : (
                  <p className="text-sm text-app-muted">No process domain progress has been recorded yet.</p>
                )}
                {learner.processDomainGrowthTimeline.length > 0 && (
                  <div className="mt-4">
                    <h4 className="mb-2 text-xs font-semibold text-app-foreground">Recent process domain growth</h4>
                    <ul className="space-y-2">
                      {learner.processDomainGrowthTimeline.slice(0, 5).map((event) => (
                        <li
                          key={event.id}
                          className="rounded-md border border-app bg-app-canvas p-3"
                        >
                          <p className="text-sm font-medium text-app-foreground">{event.processDomainTitle}</p>
                          <p className="mt-1 text-xs text-app-muted">
                            {event.fromLevel} to {event.toLevel}
                          </p>
                          <p className="mt-1 text-xs text-app-muted">
                            Reviewed by {event.educatorName}
                            {event.date ? ` · ${formatDate(event.date)}` : ''}
                            {event.evidenceCount > 0 ? ` · ${event.evidenceCount} evidence` : ''}
                          </p>
                        </li>
                      ))}
                    </ul>
                  </div>
                )}
              </div>
            )}

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
                          <div>
                            <p className="text-sm font-medium text-app-foreground">{item.title}</p>
                            {item.capabilityTitles.length > 0 && (
                              <p className="mt-1 text-xs text-app-muted">
                                {item.capabilityTitles.join(', ')}
                              </p>
                            )}
                          </div>
                          <div className="flex gap-1.5">
                            {item.source === 'educator_observation' && (
                              <span className="rounded-full bg-indigo-100 px-2 py-0.5 text-xs font-medium text-indigo-800">
                                Educator observed
                              </span>
                            )}
                            {item.source === 'reflection' && (
                              <span className="rounded-full bg-teal-100 px-2 py-0.5 text-xs font-medium text-teal-800">
                                Reflection
                              </span>
                            )}
                            {item.source === 'checkpoint_submission' && (
                              <span className="rounded-full bg-sky-100 px-2 py-0.5 text-xs font-medium text-sky-800">
                                Checkpoint
                              </span>
                            )}
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
                          {item.reviewedAt && <span>Reviewed: {formatDate(item.reviewedAt)}</span>}
                          {typeof item.evidenceCount === 'number' && item.evidenceCount > 0 && (
                            <span>{item.evidenceCount} evidence record{item.evidenceCount !== 1 ? 's' : ''}</span>
                          )}
                          {typeof item.proofCheckpointCount === 'number' && item.proofCheckpointCount > 0 && (
                            <span>{item.proofCheckpointCount} checkpoint{item.proofCheckpointCount !== 1 ? 's' : ''}</span>
                          )}
                          {item.missionAttemptId && <span>Mission-linked</span>}
                          {item.rubricScore && (
                            <span>
                              Rubric: {item.rubricScore.raw}/{item.rubricScore.max} ({item.rubricScore.level})
                            </span>
                          )}
                          {item.verificationPrompt && <span>Prompt: {item.verificationPrompt}</span>}
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
                id="guardian-ideation-passport"
                ref={focus?.sectionId === 'guardian-ideation-passport' && learnerIdx === 0 ? focusRef : undefined}
                className="rounded-lg border border-app bg-app-surface-raised p-4"
                data-testid={`ideation-passport-${learner.learnerId}`}
              >
                <div className="mb-3 flex flex-wrap items-start justify-between gap-3">
                  <div>
                    <h3 className="text-sm font-semibold text-app-foreground">
                      Ideation Passport
                    </h3>
                    {showGuardianShareActions && (
                      <p className="mt-1 max-w-2xl text-xs text-app-muted">
                        Export or share a family-safe summary of reviewed evidence, linked artifacts, and recorded growth for {learner.name}.
                      </p>
                    )}
                    {shareFeedback?.learnerId === learner.learnerId && (
                      <p className="mt-1 text-xs font-medium text-emerald-700" data-testid={`guardian-passport-share-feedback-${learner.learnerId}`}>
                        {shareFeedback.message}
                      </p>
                    )}
                  </div>
                  {showGuardianShareActions && (
                    <div className="flex flex-wrap gap-2">
                      <button
                        type="button"
                        onClick={() => { void handleShareSummary(learner); }}
                        className="rounded-md border border-app bg-app-canvas px-3 py-2 text-xs font-medium text-app-foreground"
                      >
                        Share family summary
                      </button>
                      <button
                        type="button"
                        onClick={() => handleExportText(learner)}
                        className="rounded-md border border-app bg-app-canvas px-3 py-2 text-xs font-medium text-app-foreground"
                      >
                        Export text
                      </button>
                      <button
                        type="button"
                        onClick={() => { void handleExportPdf(learner); }}
                        className="rounded-md border border-app bg-app-canvas px-3 py-2 text-xs font-medium text-app-foreground"
                      >
                        Export PDF
                      </button>
                    </div>
                  )}
                </div>
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
                            <span className="text-app-muted">{claim.verifiedArtifactCount} verified artifacts</span>
                            {claim.portfolioItemCount > 0 && <span className="text-app-muted">{claim.portfolioItemCount} portfolio item{claim.portfolioItemCount === 1 ? '' : 's'}</span>}
                            {claim.missionAttemptCount > 0 && <span className="text-app-muted">{claim.missionAttemptCount} mission attempt{claim.missionAttemptCount === 1 ? '' : 's'}</span>}
                            {claim.reviewerName && (
                              <span className="text-app-muted">by {claim.reviewerName}</span>
                            )}
                            {claim.reviewedAt && <span className="text-app-muted">{formatDate(claim.reviewedAt)}</span>}
                            {claim.rubricScore && <span className="text-app-muted">rubric {claim.rubricScore.raw}/{claim.rubricScore.max}</span>}
                            {(claim.proofHasExplainItBack || claim.proofHasOralCheck || claim.proofHasMiniRebuild) && (
                              <span className="text-app-muted">
                                proof: {[claim.proofHasExplainItBack ? 'E' : null, claim.proofHasOralCheck ? 'O' : null, claim.proofHasMiniRebuild ? 'R' : null].filter(Boolean).join('·')}
                              </span>
                            )}
                            {claim.proofCheckpointCount > 0 && <span className="text-app-muted">{claim.proofCheckpointCount} checkpoints</span>}
                            {claim.progressionDescriptor && <span className="italic text-app-muted">&ldquo;{claim.progressionDescriptor}&rdquo;</span>}
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

      {/* ---- Engagement & SDT analytics (summary route only) ---- */}
      {ctx.routePath === '/parent/summary' && (
        <div
          className="rounded-xl border border-app bg-app-surface-raised p-4"
          data-testid="parent-analytics-section"
        >
          <h2 className="mb-3 text-sm font-semibold text-app-foreground">
            Supplemental engagement signals
          </h2>
          <p className="mb-3 text-xs text-app-muted">
            These participation and motivation signals do not replace the evidence-backed capability,
            proof, and growth judgments shown above.
          </p>
          <ParentAnalyticsDashboard />
        </div>
      )}
    </section>
  );
}
