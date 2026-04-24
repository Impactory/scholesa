'use client';

import { useCallback, useEffect, useMemo, useState } from 'react';
import { httpsCallable } from 'firebase/functions';
import { functions } from '@/src/firebase/client-init';
import { useAuthContext } from '@/src/firebase/auth/AuthProvider';
import { RoleRouteGuard } from '@/src/components/auth/RoleRouteGuard';
import { Spinner } from '@/src/components/ui/Spinner';
import { resolveActiveSiteId } from '@/src/lib/auth/activeSite';
import {
  getLegacyPillarFamilyLabel,
  normalizeLegacyPillarCode,
} from '@/src/lib/curriculum/architecture';

/* ───── Types (match buildParentLearnerSummary return) ───── */

interface PassportClaim {
  capabilityId: string;
  title: string;
  pillar: string | null;
  latestLevel: number | null;
  evidenceCount: number;
  verifiedArtifactCount: number;
  evidenceRecordIds: string[];
  portfolioItemIds: string[];
  missionAttemptIds: string[];
  proofOfLearningStatus: string;
  aiDisclosureStatus: string;
  proofHasExplainItBack: boolean;
  proofHasOralCheck: boolean;
  proofHasMiniRebuild: boolean;
  proofCheckpointCount: number;
  reviewingEducatorName: string | null;
  reviewedAt: string | null;
  rubricRawScore: number | null;
  rubricMaxScore: number | null;
  progressionDescriptors: string[];
}

interface GrowthTimelineEntry {
  capabilityId: string;
  title: string;
  pillar: string | null;
  level: number;
  occurredAt: string | null;
  reviewingEducatorName: string | null;
  rubricRawScore: number | null;
  rubricMaxScore: number | null;
  proofOfLearningStatus: string | null;
  linkedEvidenceRecordIds: string[];
  linkedPortfolioItemIds: string[];
  missionAttemptId: string | null;
}

interface ProcessDomainSnapshotEntry {
  processDomainId: string;
  title: string;
  currentLevel: number | null;
  highestLevel: number | null;
  evidenceCount: number;
  updatedAt: string | null;
}

interface ProcessDomainGrowthEntry {
  processDomainId: string;
  title: string;
  fromLevel: number | null;
  toLevel: number | null;
  reviewingEducatorName: string | null;
  evidenceCount: number;
  createdAt: string | null;
}

interface PortfolioItemPreview {
  id: string;
  title: string;
  pillar: string | null;
  type: string;
  source: string | null;
  completedAt: string;
  verificationStatus: string | null;
  evidenceLinked: boolean;
  evidenceRecordIds: string[];
  missionAttemptId: string | null;
  verificationPrompt: string | null;
  capabilityTitles: string[];
  proofOfLearningStatus: string;
  aiDisclosureStatus: string;
  aiAssistanceDetails: string | null;
  proofHasExplainItBack: boolean;
  proofHasOralCheck: boolean;
  proofHasMiniRebuild: boolean;
  proofCheckpointCount: number;
  reviewingEducatorName: string | null;
  reviewedAt: string | null;
  rubricRawScore: number | null;
  rubricMaxScore: number | null;
}

interface LearnerPassportData {
  learnerId: string;
  learnerName: string | null;
  currentLevel: number | null;
  totalXp: number | null;
  missionsCompleted: number | null;
  attendanceRate: number | null;
  pillarProgress: { futureSkills: number | null; leadership: number | null; impact: number | null };
  capabilitySnapshot: {
    futureSkills: number | null;
    leadership: number | null;
    impact: number | null;
    overall: number | null;
    band: string | null;
  };
  evidenceSummary: {
    recordCount: number;
    reviewedCount: number;
    portfolioLinkedCount: number;
    verificationPromptCount: number;
    latestEvidenceAt: string | null;
  };
  growthSummary: {
    capabilityCount: number;
    updatedCapabilityCount: number;
    averageLevel: number | null;
    latestLevel: number | null;
    latestGrowthAt: string | null;
  };
  growthTimeline: GrowthTimelineEntry[];
  processDomainSnapshot: ProcessDomainSnapshotEntry[];
  processDomainGrowthTimeline: ProcessDomainGrowthEntry[];
  portfolioSnapshot: {
    artifactCount: number;
    publishedArtifactCount: number;
    badgeCount: number;
    projectCount: number;
    evidenceLinkedArtifactCount: number;
    verifiedArtifactCount: number;
    latestArtifactAt: string | null;
  };
  portfolioItemsPreview: PortfolioItemPreview[];
  ideationPassport: {
    missionAttempts: number;
    completedMissions: number;
    reflectionsSubmitted: number;
    voiceInteractions: number;
    collaborationSignals: number;
    lastReflectionAt: string | null;
    generatedAt: string;
    summary: string;
    claims: PassportClaim[];
  };
}

/* ───── Helpers ───── */

function fin(v: unknown): number | null {
  return typeof v === 'number' && Number.isFinite(v) ? v : null;
}

function str(v: unknown, fallback = ''): string {
  return typeof v === 'string' && v.trim().length > 0 ? v.trim() : fallback;
}

function pct(v: number | null): string {
  if (v == null) return '—';
  return `${Math.round(v * 100)}%`;
}

function levelLabel(level: number | null): string {
  if (level == null) return '—';
  const rounded = Math.round(level);
  if (rounded >= 4) return 'Advanced';
  if (rounded >= 3) return 'Proficient';
  if (rounded >= 2) return 'Developing';
  return 'Beginning';
}

function bandLabel(band: string | null): string {
  if (!band) return '—';
  return band.charAt(0).toUpperCase() + band.slice(1);
}

function proofLabel(status: string): string {
  switch (status) {
    case 'verified': return 'Verified';
    case 'partial': return 'Partial';
    case 'missing': return 'Missing';
    default: return 'N/A';
  }
}

function aiLabel(status: string): string {
  switch (status) {
    case 'learner-ai-verified': return 'AI used — verified';
    case 'learner-ai-verification-gap': return 'AI used — not verified';
    case 'learner-ai-not-used': return 'AI not used';
    case 'educator-feedback-ai': return 'Educator AI feedback';
    case 'no-learner-ai-signal': return 'No AI signal';
    default: return '—';
  }
}

function formatDate(iso: string | null): string {
  if (!iso) return '—';
  try {
    return new Date(iso).toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: 'numeric' });
  } catch {
    return '—';
  }
}

function escapeHtml(value: string | null): string {
  return (value ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function summarizeProofMethods(
  explainItBack: boolean,
  oralCheck: boolean,
  miniRebuild: boolean,
  checkpointCount: number,
): string {
  return [
    explainItBack ? 'Explain-it-back' : null,
    oralCheck ? 'Oral check' : null,
    miniRebuild ? 'Mini-rebuild' : null,
    checkpointCount > 0 ? `${checkpointCount} checkpoint(s)` : null,
  ].filter(Boolean).join(' · ') || '—';
}

function buildPassportTextLines(learner: LearnerPassportData): string[] {
  const lines: string[] = [];
  lines.push('═══════════════════════════════════════════');
  lines.push('  SCHOLESA IDEATION PASSPORT');
  lines.push('═══════════════════════════════════════════');
  lines.push('');
  lines.push(`Learner: ${learner.learnerName ?? 'Unknown'}`);
  lines.push(`Generated: ${formatDate(learner.ideationPassport.generatedAt)}`);
  lines.push(`Capability Band: ${bandLabel(learner.capabilitySnapshot.band)}`);
  lines.push('');
  lines.push('── Report Basis ──');
  lines.push('  This passport summarizes reviewed evidence, linked artifacts, and recorded growth events.');
  lines.push('  Participation signals do not replace capability judgments.');
  lines.push('  Legacy family progress is a compatibility roll-up of the current curriculum strands.');
  lines.push(`  Pending verification prompts: ${learner.evidenceSummary.verificationPromptCount}`);
  lines.push('');
  lines.push('── Legacy Family Progress ──');
  lines.push(`  Think, Make & Navigate AI: ${pct(learner.capabilitySnapshot.futureSkills)}`);
  lines.push(`  Communicate & Lead:       ${pct(learner.capabilitySnapshot.leadership)}`);
  lines.push(`  Build for the World:      ${pct(learner.capabilitySnapshot.impact)}`);
  lines.push(`  Overall:              ${pct(learner.capabilitySnapshot.overall)}`);
  lines.push('');
  lines.push('── Evidence Summary ──');
  lines.push(`  Evidence Records:     ${learner.evidenceSummary.recordCount}`);
  lines.push(`  Reviewed:             ${learner.evidenceSummary.reviewedCount}`);
  lines.push(`  Portfolio-Linked:     ${learner.evidenceSummary.portfolioLinkedCount}`);
  lines.push(`  Pending prompts:      ${learner.evidenceSummary.verificationPromptCount}`);
  lines.push(`  Latest Evidence:      ${formatDate(learner.evidenceSummary.latestEvidenceAt)}`);
  lines.push('');
  lines.push('── Process Domain Progress ──');
  if (learner.processDomainSnapshot.length === 0) {
    lines.push('  No process domain progress has been recorded yet.');
  }
  for (const domain of learner.processDomainSnapshot) {
    lines.push('');
    lines.push(`  ${domain.title}`);
    lines.push(`    Current level:   ${levelLabel(domain.currentLevel)}`);
    lines.push(`    Highest level:   ${levelLabel(domain.highestLevel)}`);
    lines.push(`    Evidence count:  ${domain.evidenceCount}`);
    if (domain.updatedAt) {
      lines.push(`    Updated:         ${formatDate(domain.updatedAt)}`);
    }
  }
  lines.push('');
  lines.push('── Recent Process Domain Growth ──');
  if (learner.processDomainGrowthTimeline.length === 0) {
    lines.push('  No process domain growth events have been recorded yet.');
  }
  for (const event of learner.processDomainGrowthTimeline.slice(0, 10)) {
    lines.push(`  ${formatDate(event.createdAt)} · ${event.title}`);
    lines.push(`    Level change:    ${levelLabel(event.fromLevel)} -> ${levelLabel(event.toLevel)}`);
    lines.push(`    Evidence count:  ${event.evidenceCount}`);
    if (event.reviewingEducatorName) {
      lines.push(`    Reviewed by:     ${event.reviewingEducatorName}`);
    }
  }
  lines.push('');
  lines.push('── Portfolio Snapshot ──');
  lines.push(`  Total Artifacts:      ${learner.portfolioSnapshot.artifactCount}`);
  lines.push(`  Verified Artifacts:   ${learner.portfolioSnapshot.verifiedArtifactCount}`);
  lines.push(`  Badges:               ${learner.portfolioSnapshot.badgeCount}`);
  lines.push(`  Projects:             ${learner.portfolioSnapshot.projectCount}`);
  lines.push('');
  lines.push('── Capability Claims ──');
  if (learner.ideationPassport.claims.length === 0) {
    lines.push('  No capability claims backed by evidence yet.');
  }
  for (const claim of learner.ideationPassport.claims) {
    lines.push('');
    lines.push(`  ${claim.title}`);
    lines.push(`    Legacy family:   ${legacyFamilyLabel(claim.pillar)}`);
    lines.push(`    Level:           ${levelLabel(claim.latestLevel)}`);
    lines.push(`    Evidence:        ${claim.evidenceCount} records, ${claim.verifiedArtifactCount} verified artifacts`);
    lines.push(`    Provenance:      ${claim.evidenceRecordIds.length} evidence, ${claim.portfolioItemIds.length} portfolio, ${claim.missionAttemptIds.length} mission`);
    lines.push(`    Proof-of-Learn:  ${proofLabel(claim.proofOfLearningStatus)}`);
    lines.push(`    AI Disclosure:   ${aiLabel(claim.aiDisclosureStatus)}`);
    if (claim.reviewingEducatorName) {
      lines.push(`    Reviewed by:     ${claim.reviewingEducatorName} (${formatDate(claim.reviewedAt)})`);
    }
    if (claim.rubricRawScore != null && claim.rubricMaxScore != null) {
      lines.push(`    Rubric Score:    ${claim.rubricRawScore}/${claim.rubricMaxScore}`);
    }
    if (claim.progressionDescriptors.length > 0) {
      lines.push(`    Descriptor:      ${claim.progressionDescriptors[0]}`);
    }
  }
  lines.push('');
  lines.push('── Portfolio Artifacts ──');
  if (learner.portfolioItemsPreview.length === 0) {
    lines.push('  No portfolio artifacts are linked into this passport yet.');
  }
  for (const item of learner.portfolioItemsPreview.slice(0, 20)) {
    lines.push('');
    lines.push(`  ${item.title}`);
    lines.push(`    Legacy family:   ${legacyFamilyLabel(item.pillar)}`);
    lines.push(`    Capabilities:    ${item.capabilityTitles.join(', ') || 'No capability tags'}`);
    lines.push(`    Status:          ${item.verificationStatus ?? 'pending'}`);
    lines.push(`    Proof-of-Learn:  ${proofLabel(item.proofOfLearningStatus)}`);
    lines.push(`    AI Disclosure:   ${aiLabel(item.aiDisclosureStatus)}`);
    if (item.aiAssistanceDetails) {
      lines.push(`    AI Details:      ${item.aiAssistanceDetails}`);
    }
    lines.push(`    Provenance:      ${item.evidenceRecordIds.length} evidence, ${item.missionAttemptId ? 'mission-linked' : 'standalone artifact'}, ${item.source ?? item.type}`);
    lines.push(`    Proof methods:   ${summarizeProofMethods(item.proofHasExplainItBack, item.proofHasOralCheck, item.proofHasMiniRebuild, item.proofCheckpointCount)}`);
    if (item.reviewingEducatorName) {
      lines.push(`    Reviewed by:     ${item.reviewingEducatorName} (${formatDate(item.reviewedAt)})`);
    }
    if (item.rubricRawScore != null && item.rubricMaxScore != null) {
      lines.push(`    Rubric Score:    ${item.rubricRawScore}/${item.rubricMaxScore}`);
    }
    if (item.verificationPrompt) {
      lines.push(`    Verify next:     ${item.verificationPrompt}`);
    }
  }
  lines.push('');
  lines.push('── Growth Timeline ──');
  if (learner.growthTimeline.length === 0) {
    lines.push('  No growth events have been recorded yet.');
  }
  for (const entry of learner.growthTimeline.slice(0, 15)) {
    lines.push(`  ${formatDate(entry.occurredAt)} · ${entry.title}`);
    lines.push(`    Level:           ${levelLabel(entry.level)}`);
    lines.push(`    Proof-of-Learn:  ${proofLabel(entry.proofOfLearningStatus ?? 'missing')}`);
    lines.push(`    Provenance:      ${entry.linkedEvidenceRecordIds.length} evidence, ${entry.linkedPortfolioItemIds.length} portfolio${entry.missionAttemptId ? ', mission-linked' : ''}`);
    if (entry.reviewingEducatorName) {
      lines.push(`    Reviewed by:     ${entry.reviewingEducatorName}`);
    }
    if (entry.rubricRawScore != null && entry.rubricMaxScore != null) {
      lines.push(`    Rubric Score:    ${entry.rubricRawScore}/${entry.rubricMaxScore}`);
    }
  }
  lines.push('');
  lines.push('── Ideation Activity ──');
  lines.push(`  Missions Attempted:   ${learner.ideationPassport.missionAttempts}`);
  lines.push(`  Missions Completed:   ${learner.ideationPassport.completedMissions}`);
  lines.push(`  Reflections:          ${learner.ideationPassport.reflectionsSubmitted}`);
  lines.push(`  Voice Interactions:   ${learner.ideationPassport.voiceInteractions}`);
  lines.push(`  Collaboration:        ${learner.ideationPassport.collaborationSignals}`);
  lines.push('');
  lines.push('═══════════════════════════════════════════');
  lines.push(`  ${learner.ideationPassport.summary}`);
  lines.push('═══════════════════════════════════════════');
  return lines;
}

function buildFamilyShareSummary(learner: LearnerPassportData): string {
  const topClaims = learner.ideationPassport.claims.slice(0, 3);
  const nextPrompts = learner.portfolioItemsPreview
    .filter((item) => typeof item.verificationPrompt === 'string' && item.verificationPrompt.trim().length > 0)
    .slice(0, 2);
  const featuredAiDisclosure = topClaims.length > 0
    ? aiLabel(topClaims[0].aiDisclosureStatus)
    : null;

  return [
    `Scholesa family summary for ${learner.learnerName ?? learner.learnerId}`,
    `Generated ${formatDate(learner.ideationPassport.generatedAt)}`,
    'This summary reflects reviewed evidence, linked artifacts, and recorded growth events.',
    `Capability band: ${bandLabel(learner.capabilitySnapshot.band)}`,
    `Reviewed evidence: ${learner.evidenceSummary.reviewedCount}`,
    `Verified artifacts: ${learner.portfolioSnapshot.verifiedArtifactCount}`,
    ...(featuredAiDisclosure ? [`Featured AI disclosure: ${featuredAiDisclosure}`] : []),
    `Pending verification prompts: ${learner.evidenceSummary.verificationPromptCount}`,
    '',
    'Current evidence-backed claims:',
    ...(topClaims.length > 0
      ? topClaims.map((claim) => `- ${claim.title}: ${levelLabel(claim.latestLevel)} with ${claim.evidenceCount} evidence record(s)`)
      : ['- No capability claims backed by reviewed evidence yet.']),
    '',
    'Next verification prompts:',
    ...(nextPrompts.length > 0
      ? nextPrompts.map((item) => `- ${item.title}: ${item.verificationPrompt}`)
      : ['- No pending verification prompts in this export.']),
  ].join('\n');
}

function normalizeLearner(raw: Record<string, unknown>): LearnerPassportData | null {
  const learnerId = str(raw.learnerId);
  if (!learnerId) return null;

  const cs = (raw.capabilitySnapshot ?? {}) as Record<string, unknown>;
  const es = (raw.evidenceSummary ?? {}) as Record<string, unknown>;
  const gs = (raw.growthSummary ?? {}) as Record<string, unknown>;
  const ps = (raw.portfolioSnapshot ?? {}) as Record<string, unknown>;
  const ip = (raw.ideationPassport ?? {}) as Record<string, unknown>;
  const pp = (raw.pillarProgress ?? {}) as Record<string, unknown>;

  const claims: PassportClaim[] = [];
  if (Array.isArray(ip.claims)) {
    for (const c of ip.claims) {
      if (!c || typeof c !== 'object') continue;
      const r = c as Record<string, unknown>;
      claims.push({
        capabilityId: str(r.capabilityId),
        title: str(r.title, 'Unnamed capability'),
        pillar: str(r.pillar) || null,
        latestLevel: fin(r.latestLevel),
        evidenceCount: fin(r.evidenceCount) ?? 0,
        verifiedArtifactCount: fin(r.verifiedArtifactCount) ?? 0,
        evidenceRecordIds: Array.isArray(r.evidenceRecordIds)
          ? r.evidenceRecordIds.filter((v): v is string => typeof v === 'string')
          : [],
        portfolioItemIds: Array.isArray(r.portfolioItemIds)
          ? r.portfolioItemIds.filter((v): v is string => typeof v === 'string')
          : [],
        missionAttemptIds: Array.isArray(r.missionAttemptIds)
          ? r.missionAttemptIds.filter((v): v is string => typeof v === 'string')
          : [],
        proofOfLearningStatus: str(r.proofOfLearningStatus, 'missing'),
        aiDisclosureStatus: str(r.aiDisclosureStatus, 'not-available'),
        proofHasExplainItBack: r.proofHasExplainItBack === true,
        proofHasOralCheck: r.proofHasOralCheck === true,
        proofHasMiniRebuild: r.proofHasMiniRebuild === true,
        proofCheckpointCount: fin(r.proofCheckpointCount) ?? 0,
        reviewingEducatorName: str(r.reviewingEducatorName) || null,
        reviewedAt: str(r.reviewedAt) || null,
        rubricRawScore: fin(r.rubricRawScore),
        rubricMaxScore: fin(r.rubricMaxScore),
        progressionDescriptors: Array.isArray(r.progressionDescriptors)
          ? r.progressionDescriptors.filter((v): v is string => typeof v === 'string')
          : [],
      });
    }
  }

  const growthTimeline: GrowthTimelineEntry[] = [];
  if (Array.isArray(raw.growthTimeline)) {
    for (const g of raw.growthTimeline) {
      if (!g || typeof g !== 'object') continue;
      const r = g as Record<string, unknown>;
      growthTimeline.push({
        capabilityId: str(r.capabilityId),
        title: str(r.title, 'Capability'),
        pillar: str(r.pillar) || null,
        level: fin(r.level) ?? 0,
        occurredAt: str(r.occurredAt) || null,
        reviewingEducatorName: str(r.reviewingEducatorName) || null,
        rubricRawScore: fin(r.rubricRawScore),
        rubricMaxScore: fin(r.rubricMaxScore),
        proofOfLearningStatus: str(r.proofOfLearningStatus) || null,
        linkedEvidenceRecordIds: Array.isArray(r.linkedEvidenceRecordIds)
          ? r.linkedEvidenceRecordIds.filter((v): v is string => typeof v === 'string')
          : [],
        linkedPortfolioItemIds: Array.isArray(r.linkedPortfolioItemIds)
          ? r.linkedPortfolioItemIds.filter((v): v is string => typeof v === 'string')
          : [],
        missionAttemptId: str(r.missionAttemptId) || null,
      });
    }
  }

  const processDomainSnapshot: ProcessDomainSnapshotEntry[] = [];
  if (Array.isArray(raw.processDomainSnapshot)) {
    for (const entry of raw.processDomainSnapshot) {
      if (!entry || typeof entry !== 'object') continue;
      const r = entry as Record<string, unknown>;
      processDomainSnapshot.push({
        processDomainId: str(r.processDomainId),
        title: str(r.title, str(r.processDomainId, 'Process domain')),
        currentLevel: fin(r.currentLevel),
        highestLevel: fin(r.highestLevel),
        evidenceCount: fin(r.evidenceCount) ?? 0,
        updatedAt: str(r.updatedAt) || null,
      });
    }
  }

  const processDomainGrowthTimeline: ProcessDomainGrowthEntry[] = [];
  if (Array.isArray(raw.processDomainGrowthTimeline)) {
    for (const entry of raw.processDomainGrowthTimeline) {
      if (!entry || typeof entry !== 'object') continue;
      const r = entry as Record<string, unknown>;
      processDomainGrowthTimeline.push({
        processDomainId: str(r.processDomainId),
        title: str(r.title, str(r.processDomainId, 'Process domain')),
        fromLevel: fin(r.fromLevel),
        toLevel: fin(r.toLevel),
        reviewingEducatorName: str(r.reviewingEducatorName) || null,
        evidenceCount: fin(r.evidenceCount) ?? 0,
        createdAt: str(r.createdAt) || null,
      });
    }
  }

  const portfolioItemsPreview: PortfolioItemPreview[] = [];
  if (Array.isArray(raw.portfolioItemsPreview)) {
    for (const p of raw.portfolioItemsPreview) {
      if (!p || typeof p !== 'object') continue;
      const r = p as Record<string, unknown>;
      portfolioItemsPreview.push({
        id: str(r.id),
        title: str(r.title, 'Artifact'),
        pillar: str(r.pillar) || null,
        type: str(r.type, 'project'),
        source: str(r.source) || null,
        completedAt: str(r.completedAt, new Date().toISOString()),
        verificationStatus: str(r.verificationStatus) || null,
        evidenceLinked: r.evidenceLinked === true,
        evidenceRecordIds: Array.isArray(r.evidenceRecordIds)
          ? r.evidenceRecordIds.filter((v): v is string => typeof v === 'string')
          : [],
        missionAttemptId: str(r.missionAttemptId) || null,
        verificationPrompt: str(r.verificationPrompt) || null,
        capabilityTitles: Array.isArray(r.capabilityTitles) ? r.capabilityTitles.filter((v): v is string => typeof v === 'string') : [],
        proofOfLearningStatus: str(r.proofOfLearningStatus, 'missing'),
        aiDisclosureStatus: str(r.aiDisclosureStatus, 'not-available'),
        aiAssistanceDetails: str(r.aiAssistanceDetails) || null,
        proofHasExplainItBack: r.proofHasExplainItBack === true,
        proofHasOralCheck: r.proofHasOralCheck === true,
        proofHasMiniRebuild: r.proofHasMiniRebuild === true,
        proofCheckpointCount: fin(r.proofCheckpointCount) ?? 0,
        reviewingEducatorName: str(r.reviewingEducatorName) || null,
        reviewedAt: str(r.reviewedAt) || null,
        rubricRawScore: fin(r.rubricRawScore),
        rubricMaxScore: fin(r.rubricMaxScore),
      });
    }
  }

  return {
    learnerId,
    learnerName: str(raw.learnerName) || null,
    currentLevel: fin(raw.currentLevel),
    totalXp: fin(raw.totalXp),
    missionsCompleted: fin(raw.missionsCompleted),
    attendanceRate: fin(raw.attendanceRate),
    pillarProgress: {
      futureSkills: fin(pp.futureSkills),
      leadership: fin(pp.leadership),
      impact: fin(pp.impact),
    },
    capabilitySnapshot: {
      futureSkills: fin(cs.futureSkills),
      leadership: fin(cs.leadership),
      impact: fin(cs.impact),
      overall: fin(cs.overall),
      band: str(cs.band) || null,
    },
    evidenceSummary: {
      recordCount: fin(es.recordCount) ?? 0,
      reviewedCount: fin(es.reviewedCount) ?? 0,
      portfolioLinkedCount: fin(es.portfolioLinkedCount) ?? 0,
      verificationPromptCount: fin(es.verificationPromptCount) ?? 0,
      latestEvidenceAt: str(es.latestEvidenceAt) || null,
    },
    growthSummary: {
      capabilityCount: fin(gs.capabilityCount) ?? 0,
      updatedCapabilityCount: fin(gs.updatedCapabilityCount) ?? 0,
      averageLevel: fin(gs.averageLevel),
      latestLevel: fin(gs.latestLevel),
      latestGrowthAt: str(gs.latestGrowthAt) || null,
    },
    growthTimeline,
    processDomainSnapshot,
    processDomainGrowthTimeline,
    portfolioSnapshot: {
      artifactCount: fin(ps.artifactCount) ?? 0,
      publishedArtifactCount: fin(ps.publishedArtifactCount) ?? 0,
      badgeCount: fin(ps.badgeCount) ?? 0,
      projectCount: fin(ps.projectCount) ?? 0,
      evidenceLinkedArtifactCount: fin(ps.evidenceLinkedArtifactCount) ?? 0,
      verifiedArtifactCount: fin(ps.verifiedArtifactCount) ?? 0,
      latestArtifactAt: str(ps.latestArtifactAt) || null,
    },
    portfolioItemsPreview,
    ideationPassport: {
      missionAttempts: fin(ip.missionAttempts) ?? 0,
      completedMissions: fin(ip.completedMissions) ?? 0,
      reflectionsSubmitted: fin(ip.reflectionsSubmitted) ?? 0,
      voiceInteractions: fin(ip.voiceInteractions) ?? 0,
      collaborationSignals: fin(ip.collaborationSignals) ?? 0,
      lastReflectionAt: str(ip.lastReflectionAt) || null,
      generatedAt: str(ip.generatedAt, new Date().toISOString()),
      summary: str(ip.summary, 'No passport data available yet.'),
      claims,
    },
  };
}

/* ───── Legacy family colours ───── */

const LEGACY_FAMILY_COLORS: Record<string, { bg: string; text: string; border: string }> = {
  FUTURE_SKILLS: { bg: 'bg-blue-50', text: 'text-blue-800', border: 'border-blue-200' },
  LEADERSHIP_AGENCY: { bg: 'bg-amber-50', text: 'text-amber-800', border: 'border-amber-200' },
  IMPACT_INNOVATION: { bg: 'bg-emerald-50', text: 'text-emerald-800', border: 'border-emerald-200' },
};

function legacyFamilyLabel(pillar: string | null) {
  const normalized = normalizeLegacyPillarCode(pillar);
  return normalized ? getLegacyPillarFamilyLabel(normalized) : (pillar ?? 'Other');
}

function pillarColor(pillar: string | null) {
  const normalized = normalizeLegacyPillarCode(pillar);
  return LEGACY_FAMILY_COLORS[normalized ?? ''] ?? { bg: 'bg-gray-50', text: 'text-gray-700', border: 'border-gray-200' };
}

/* ───── Component ───── */

export function LearnerPassportExport({ siteId: initialSiteId }: { siteId?: string | null } = {}) {
  const { user, profile, loading: authLoading } = useAuthContext();
  const [learners, setLearners] = useState<LearnerPassportData[]>([]);
  const [selectedIndex, setSelectedIndex] = useState(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [shareFeedback, setShareFeedback] = useState<string | null>(null);

  const siteId = initialSiteId ?? resolveActiveSiteId(profile) ?? null;

  const fetchPassport = useCallback(async () => {
    if (!user) {
      setLoading(false);
      return;
    }
    if (!siteId) {
      setLearners([]);
      setLoading(false);
      return;
    }
    setLoading(true);
    setError(null);
    try {
      const callable = httpsCallable(functions, 'getLearnerPassportBundle');
      const response = await callable({ siteId, locale: 'en', range: 'all' });
      const payload = (response.data ?? {}) as Record<string, unknown>;
      const rawLearners = Array.isArray(payload.learners) ? payload.learners : [];
      const normalized = rawLearners
        .filter((v): v is Record<string, unknown> => !!v && typeof v === 'object' && !Array.isArray(v))
        .map(normalizeLearner)
        .filter((v): v is LearnerPassportData => v !== null);
      setLearners(normalized);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load passport data.');
    } finally {
      setLoading(false);
    }
  }, [user, siteId]);

  useEffect(() => { fetchPassport(); }, [fetchPassport]);

  const learner = learners[selectedIndex] ?? null;

  useEffect(() => {
    if (!shareFeedback) return;
    const timeout = window.setTimeout(() => setShareFeedback(null), 4000);
    return () => window.clearTimeout(timeout);
  }, [shareFeedback]);

  const handlePrint = useCallback(() => { window.print(); }, []);

  const handleShareSummary = useCallback(async () => {
    if (!learner) return;
    const shareText = buildFamilyShareSummary(learner);

    try {
      if (typeof navigator !== 'undefined' && typeof navigator.share === 'function') {
        await navigator.share({
          title: `Scholesa family summary for ${learner.learnerName ?? learner.learnerId}`,
          text: shareText,
        });
        setShareFeedback('Family summary ready to share.');
        return;
      }

      if (typeof navigator !== 'undefined' && navigator.clipboard?.writeText) {
        await navigator.clipboard.writeText(shareText);
        setShareFeedback('Family summary copied to clipboard.');
        return;
      }

      setShareFeedback('Sharing is unavailable in this browser. Use Export Text instead.');
    } catch (err) {
      if (err instanceof DOMException && err.name === 'AbortError') return;
      setShareFeedback('Sharing is unavailable in this browser. Use Export Text instead.');
    }
  }, [learner]);

  const handleExportHtml = useCallback(() => {
    if (!learner) return;
    const claimsHtml = learner.ideationPassport.claims.length === 0
      ? '<p style="color:#6b7280;font-size:14px">No capability claims backed by evidence yet.</p>'
      : learner.ideationPassport.claims.map((c) => `
        <div style="border:1px solid #e5e7eb;border-radius:8px;padding:16px;margin-bottom:12px;background:#fafafa">
          <h3 style="margin:0 0 8px;font-size:16px;color:#111827">${escapeHtml(c.title)}</h3>
          <table style="border-collapse:collapse;font-size:13px;width:100%">
            <tr><td style="color:#6b7280;padding:2px 12px 2px 0;width:160px">Legacy family</td><td>${escapeHtml(legacyFamilyLabel(c.pillar))}</td></tr>
            <tr><td style="color:#6b7280;padding:2px 12px 2px 0">Level</td><td><strong>${levelLabel(c.latestLevel)}</strong></td></tr>
            <tr><td style="color:#6b7280;padding:2px 12px 2px 0">Evidence</td><td>${c.evidenceCount} records · ${c.verifiedArtifactCount} verified artifacts</td></tr>
            <tr><td style="color:#6b7280;padding:2px 12px 2px 0">Provenance links</td><td>${c.evidenceRecordIds.length} evidence · ${c.portfolioItemIds.length} portfolio · ${c.missionAttemptIds.length} mission</td></tr>
            <tr><td style="color:#6b7280;padding:2px 12px 2px 0">Proof-of-Learning</td><td>${proofLabel(c.proofOfLearningStatus)}</td></tr>
            <tr><td style="color:#6b7280;padding:2px 12px 2px 0">AI Disclosure</td><td>${aiLabel(c.aiDisclosureStatus)}</td></tr>
            ${c.reviewingEducatorName ? `<tr><td style="color:#6b7280;padding:2px 12px 2px 0">Reviewed by</td><td>${escapeHtml(c.reviewingEducatorName)} (${formatDate(c.reviewedAt)})</td></tr>` : ''}
            ${c.rubricRawScore != null && c.rubricMaxScore != null ? `<tr><td style="color:#6b7280;padding:2px 12px 2px 0">Rubric Score</td><td>${c.rubricRawScore}/${c.rubricMaxScore}</td></tr>` : ''}
            <tr><td style="color:#6b7280;padding:2px 12px 2px 0">Proof methods</td><td>${summarizeProofMethods(c.proofHasExplainItBack, c.proofHasOralCheck, c.proofHasMiniRebuild, c.proofCheckpointCount)}</td></tr>
            ${c.progressionDescriptors.length > 0 ? `<tr><td style="color:#6b7280;padding:2px 12px 2px 0">Descriptor</td><td>${escapeHtml(c.progressionDescriptors[0])}</td></tr>` : ''}
          </table>
        </div>`).join('');

    const portfolioHtml = learner.portfolioItemsPreview.length === 0
      ? '<p style="color:#6b7280;font-size:14px">No portfolio artifacts are linked into this passport yet.</p>'
      : learner.portfolioItemsPreview.slice(0, 20).map((item) => `
        <div style="border:1px solid #e5e7eb;border-radius:8px;padding:16px;margin-bottom:12px;background:#ffffff">
          <h3 style="margin:0 0 8px;font-size:15px;color:#111827">${escapeHtml(item.title)}</h3>
          <table style="border-collapse:collapse;font-size:13px;width:100%">
            <tr><td style="color:#6b7280;padding:2px 12px 2px 0;width:160px">Legacy family</td><td>${escapeHtml(legacyFamilyLabel(item.pillar))}</td></tr>
            <tr><td style="color:#6b7280;padding:2px 12px 2px 0">Capabilities</td><td>${escapeHtml(item.capabilityTitles.join(', ') || 'No capability tags')}</td></tr>
            <tr><td style="color:#6b7280;padding:2px 12px 2px 0">Status</td><td>${escapeHtml(item.verificationStatus ?? 'pending')}</td></tr>
            <tr><td style="color:#6b7280;padding:2px 12px 2px 0">Proof-of-Learning</td><td>${proofLabel(item.proofOfLearningStatus)}</td></tr>
            <tr><td style="color:#6b7280;padding:2px 12px 2px 0">AI Disclosure</td><td>${escapeHtml(aiLabel(item.aiDisclosureStatus))}</td></tr>
            ${item.aiAssistanceDetails ? `<tr><td style="color:#6b7280;padding:2px 12px 2px 0">AI Details</td><td>${escapeHtml(item.aiAssistanceDetails)}</td></tr>` : ''}
            <tr><td style="color:#6b7280;padding:2px 12px 2px 0">Provenance</td><td>${item.evidenceRecordIds.length} evidence · ${item.missionAttemptId ? 'mission-linked' : 'standalone artifact'} · ${escapeHtml(item.source ?? item.type)}</td></tr>
            <tr><td style="color:#6b7280;padding:2px 12px 2px 0">Proof methods</td><td>${summarizeProofMethods(item.proofHasExplainItBack, item.proofHasOralCheck, item.proofHasMiniRebuild, item.proofCheckpointCount)}</td></tr>
            ${item.reviewingEducatorName ? `<tr><td style="color:#6b7280;padding:2px 12px 2px 0">Reviewed by</td><td>${escapeHtml(item.reviewingEducatorName)} (${formatDate(item.reviewedAt)})</td></tr>` : ''}
            ${item.rubricRawScore != null && item.rubricMaxScore != null ? `<tr><td style="color:#6b7280;padding:2px 12px 2px 0">Rubric Score</td><td>${item.rubricRawScore}/${item.rubricMaxScore}</td></tr>` : ''}
            ${item.verificationPrompt ? `<tr><td style="color:#6b7280;padding:2px 12px 2px 0">Verification prompt</td><td>${escapeHtml(item.verificationPrompt)}</td></tr>` : ''}
          </table>
        </div>`).join('');

    const growthHtml = learner.growthTimeline.length === 0
      ? '<p style="color:#6b7280;font-size:14px">No growth events have been recorded yet.</p>'
      : learner.growthTimeline.slice(0, 15).map((entry) => `
        <div style="border:1px solid #e5e7eb;border-radius:8px;padding:12px;margin-bottom:10px;background:#ffffff">
          <div style="display:flex;justify-content:space-between;gap:12px;align-items:flex-start">
            <div>
              <div style="font-size:14px;font-weight:600;color:#111827">${escapeHtml(entry.title)}</div>
              <div style="font-size:12px;color:#6b7280;margin-top:4px">${formatDate(entry.occurredAt)} · ${escapeHtml(entry.reviewingEducatorName ?? 'Educator review pending')}</div>
            </div>
            <div style="font-size:12px;color:#374151;text-align:right">
              <div>${escapeHtml(levelLabel(entry.level))}</div>
              <div>${proofLabel(entry.proofOfLearningStatus ?? 'missing')}</div>
              ${entry.rubricRawScore != null && entry.rubricMaxScore != null ? `<div>${entry.rubricRawScore}/${entry.rubricMaxScore}</div>` : ''}
            </div>
          </div>
          <div style="font-size:12px;color:#6b7280;margin-top:6px">${entry.linkedEvidenceRecordIds.length} evidence · ${entry.linkedPortfolioItemIds.length} portfolio${entry.missionAttemptId ? ' · mission-linked' : ''}</div>
        </div>`).join('');

    const processDomainSnapshotHtml = learner.processDomainSnapshot.length === 0
      ? '<p style="color:#6b7280;font-size:14px">No process domain progress has been recorded yet.</p>'
      : learner.processDomainSnapshot.map((domain) => `
        <div style="border:1px solid #e5e7eb;border-radius:8px;padding:12px;margin-bottom:10px;background:#ffffff">
          <div style="font-size:14px;font-weight:600;color:#111827">${escapeHtml(domain.title)}</div>
          <div style="font-size:12px;color:#6b7280;margin-top:6px">Current level: ${escapeHtml(levelLabel(domain.currentLevel))} · Highest level: ${escapeHtml(levelLabel(domain.highestLevel))}</div>
          <div style="font-size:12px;color:#6b7280;margin-top:4px">${domain.evidenceCount} evidence · Updated ${escapeHtml(formatDate(domain.updatedAt))}</div>
        </div>`).join('');

    const processDomainGrowthHtml = learner.processDomainGrowthTimeline.length === 0
      ? '<p style="color:#6b7280;font-size:14px">No process domain growth events have been recorded yet.</p>'
      : learner.processDomainGrowthTimeline.slice(0, 10).map((entry) => `
        <div style="border:1px solid #e5e7eb;border-radius:8px;padding:12px;margin-bottom:10px;background:#ffffff">
          <div style="display:flex;justify-content:space-between;gap:12px;align-items:flex-start">
            <div>
              <div style="font-size:14px;font-weight:600;color:#111827">${escapeHtml(entry.title)}</div>
              <div style="font-size:12px;color:#6b7280;margin-top:4px">${escapeHtml(formatDate(entry.createdAt))}${entry.reviewingEducatorName ? ` · ${escapeHtml(entry.reviewingEducatorName)}` : ''}</div>
            </div>
            <div style="font-size:12px;color:#374151;text-align:right">
              <div>${escapeHtml(levelLabel(entry.fromLevel))} → ${escapeHtml(levelLabel(entry.toLevel))}</div>
              <div>${entry.evidenceCount} evidence</div>
            </div>
          </div>
        </div>`).join('');

    const reportBasisHtml = `<div style="border:1px solid #dbeafe;background:#eff6ff;border-radius:12px;padding:14px 16px;font-size:13px;color:#1e3a8a;line-height:1.6;margin-bottom:20px">
  <strong>Report basis</strong><br/>
  This export summarizes reviewed evidence, linked portfolio artifacts, and recorded growth events. Participation signals do not replace capability judgments.<br/>
  Legacy family progress is shown here as a compatibility roll-up of the current curriculum strands.<br/>
  Pending verification prompts: ${learner.evidenceSummary.verificationPromptCount}
</div>`;

    const html = `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1"/>
<title>Ideation Passport — ${learner.learnerName ?? learner.learnerId}</title>
<style>
  body{font-family:system-ui,-apple-system,sans-serif;max-width:800px;margin:0 auto;padding:32px;color:#111827}
  @media print{body{padding:0}}
  h1{font-size:24px;margin:0 0 4px}
  h2{font-size:17px;margin:24px 0 10px;color:#4f46e5;border-bottom:1px solid #e5e7eb;padding-bottom:4px}
  .meta{color:#6b7280;font-size:13px;margin-bottom:24px}
  .pill{display:inline-block;padding:3px 10px;border-radius:9999px;font-size:12px;font-weight:600}
  .strong{background:#d1fae5;color:#065f46}.developing{background:#fef3c7;color:#92400e}.emerging{background:#fee2e2;color:#991b1b}
  .stat-grid{display:grid;grid-template-columns:repeat(3,1fr);gap:12px;margin-bottom:8px}
  .stat{border:1px solid #e5e7eb;border-radius:8px;padding:12px;text-align:center}
  .stat-val{font-size:22px;font-weight:700;color:#4f46e5}
  .stat-label{font-size:12px;color:#6b7280;margin-top:2px}
  table{border-collapse:collapse;width:100%;font-size:13px}
  td{padding:4px 0}
  footer{margin-top:32px;font-size:11px;color:#9ca3af;border-top:1px solid #e5e7eb;padding-top:12px}
</style>
</head>
<body>
<h1>Ideation Passport</h1>
<p class="meta">
  <strong>${escapeHtml(learner.learnerName ?? learner.learnerId)}</strong> &middot;
  Generated ${formatDate(learner.ideationPassport.generatedAt)} &middot;
  <span class="pill ${learner.capabilitySnapshot.band === 'strong' ? 'strong' : learner.capabilitySnapshot.band === 'developing' ? 'developing' : 'emerging'}">
    ${bandLabel(learner.capabilitySnapshot.band)}
  </span>
</p>

${reportBasisHtml}

<h2>Legacy Family Progress</h2>
<div class="stat-grid">
  <div class="stat"><div class="stat-val">${pct(learner.capabilitySnapshot.futureSkills)}</div><div class="stat-label">${getLegacyPillarFamilyLabel('FUTURE_SKILLS')}</div></div>
  <div class="stat"><div class="stat-val">${pct(learner.capabilitySnapshot.leadership)}</div><div class="stat-label">${getLegacyPillarFamilyLabel('LEADERSHIP_AGENCY')}</div></div>
  <div class="stat"><div class="stat-val">${pct(learner.capabilitySnapshot.impact)}</div><div class="stat-label">${getLegacyPillarFamilyLabel('IMPACT_INNOVATION')}</div></div>
</div>

<h2>Evidence Summary</h2>
<table>
  <tr><td style="color:#6b7280;width:200px">Evidence Records</td><td>${learner.evidenceSummary.recordCount}</td></tr>
  <tr><td style="color:#6b7280">Reviewed</td><td>${learner.evidenceSummary.reviewedCount}</td></tr>
  <tr><td style="color:#6b7280">Portfolio-Linked</td><td>${learner.evidenceSummary.portfolioLinkedCount}</td></tr>
  <tr><td style="color:#6b7280">Pending Verification Prompts</td><td>${learner.evidenceSummary.verificationPromptCount}</td></tr>
  <tr><td style="color:#6b7280">Latest Evidence</td><td>${formatDate(learner.evidenceSummary.latestEvidenceAt)}</td></tr>
</table>

<h2>Portfolio Snapshot</h2>
<table>
  <tr><td style="color:#6b7280;width:200px">Total Artifacts</td><td>${learner.portfolioSnapshot.artifactCount}</td></tr>
  <tr><td style="color:#6b7280">Verified Artifacts</td><td>${learner.portfolioSnapshot.verifiedArtifactCount}</td></tr>
  <tr><td style="color:#6b7280">Badges</td><td>${learner.portfolioSnapshot.badgeCount}</td></tr>
  <tr><td style="color:#6b7280">Projects</td><td>${learner.portfolioSnapshot.projectCount}</td></tr>
</table>

<h2>Process Domain Progress</h2>
${processDomainSnapshotHtml}

<h2>Recent Process Domain Growth</h2>
${processDomainGrowthHtml}

<h2>Ideation Activity</h2>
<table>
  <tr><td style="color:#6b7280;width:200px">Missions Attempted</td><td>${learner.ideationPassport.missionAttempts}</td></tr>
  <tr><td style="color:#6b7280">Missions Completed</td><td>${learner.ideationPassport.completedMissions}</td></tr>
  <tr><td style="color:#6b7280">Reflections</td><td>${learner.ideationPassport.reflectionsSubmitted}</td></tr>
  <tr><td style="color:#6b7280">Voice Interactions</td><td>${learner.ideationPassport.voiceInteractions}</td></tr>
  <tr><td style="color:#6b7280">Collaboration Signals</td><td>${learner.ideationPassport.collaborationSignals}</td></tr>
</table>

<h2>Capability Claims</h2>
${claimsHtml}

<h2>Portfolio Artifacts</h2>
${portfolioHtml}

<h2>Growth Timeline</h2>
${growthHtml}

<h2>Summary</h2>
<p style="font-size:14px;color:#374151">${escapeHtml(learner.ideationPassport.summary)}</p>

<footer>Scholesa Ideation Passport · Evidence-backed learner capability record · ${formatDate(learner.ideationPassport.generatedAt)}</footer>
</body>
</html>`;

    const blob = new Blob([html], { type: 'text/html' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `ideation-passport-${learner.learnerId}.html`;
    a.click();
    URL.revokeObjectURL(url);
  }, [learner]);

  const handleExportPdf = useCallback(async () => {
    if (!learner) return;

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

    for (const line of buildPassportTextLines(learner)) {
      const wrapped = pdf.splitTextToSize(line, maxWidth) as string[];
      if (y + (wrapped.length * lineHeight) > pageHeight - marginY) {
        pdf.addPage();
        y = marginY;
      }
      pdf.text(wrapped, marginX, y);
      y += Math.max(wrapped.length, 1) * lineHeight;
    }

    pdf.save(`ideation-passport-${learner.learnerId}.pdf`);
  }, [learner]);

  const handleExportText = useCallback(() => {
    if (!learner) return;
    const lines = buildPassportTextLines(learner);

    const blob = new Blob([lines.join('\n')], { type: 'text/plain' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `ideation-passport-${learner.learnerId}.txt`;
    a.click();
    URL.revokeObjectURL(url);
  }, [learner]);

  if (authLoading || loading) {
    return (
      <RoleRouteGuard allowedRoles={['learner']}>
        <div className="flex items-center justify-center min-h-[400px]">
          <Spinner />
        </div>
      </RoleRouteGuard>
    );
  }

  if (!siteId) {
    return (
      <RoleRouteGuard allowedRoles={['learner']}>
        <div className="p-6">
          <div
            className="rounded-lg border border-amber-200 bg-amber-50 p-8 text-center text-sm text-amber-900"
            data-testid="learner-passport-site-required"
          >
            <p className="font-semibold">Active site required</p>
            <p className="mt-1 text-amber-700">
              Select an active site before viewing your evidence-backed passport.
            </p>
          </div>
        </div>
      </RoleRouteGuard>
    );
  }

  if (error) {
    return (
      <RoleRouteGuard allowedRoles={['learner']}>
        <div className="p-6">
          <div className="bg-red-50 border border-red-200 rounded-lg p-4">
            <p className="text-red-800 text-sm">{error}</p>
            <button onClick={fetchPassport} className="mt-2 text-sm text-red-600 underline">Retry</button>
          </div>
        </div>
      </RoleRouteGuard>
    );
  }

  if (learners.length === 0) {
    return (
      <RoleRouteGuard allowedRoles={['learner']}>
        <div className="p-6">
          <div className="bg-gray-50 border border-gray-200 rounded-lg p-8 text-center">
            <p className="text-gray-600">No passport evidence is available yet. Your passport will appear once reviewed evidence is linked into your growth record.</p>
          </div>
        </div>
      </RoleRouteGuard>
    );
  }

  return (
    <RoleRouteGuard allowedRoles={['learner']}>
      <div className="max-w-4xl mx-auto p-6 print:p-0 print:max-w-none">
        {/* ── Header (screen only) ── */}
        <div className="flex items-center justify-between mb-6 print:hidden">
          <div>
            <h1 className="text-2xl font-bold text-gray-900">Ideation Passport</h1>
            <p className="text-sm text-gray-500 mt-1">Evidence-backed learner capability report</p>
            <p className="mt-2 max-w-2xl text-xs text-gray-500">
              Export a family-safe copy of reviewed evidence, linked artifacts, and recorded growth.
              Pending verification prompts remain visible in the export as next questions, not completed claims.
            </p>
            {shareFeedback && (
              <p className="mt-2 text-xs font-medium text-emerald-700" data-testid="learner-passport-share-feedback">
                {shareFeedback}
              </p>
            )}
          </div>
          <div className="flex flex-wrap gap-2">
            {learners.length > 1 && (
              <select
                value={selectedIndex}
                onChange={(e) => setSelectedIndex(Number(e.target.value))}
                className="text-sm border border-gray-300 rounded-md px-3 py-2"
              >
                {learners.map((l, i) => (
                  <option key={l.learnerId} value={i}>{l.learnerName ?? l.learnerId}</option>
                ))}
              </select>
            )}
            <button
              type="button"
              onClick={() => { void handleShareSummary(); }}
              className="inline-flex items-center gap-1.5 px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50"
              title="Share a family-safe evidence summary with native share when available, or copy it to the clipboard"
            >
              Share Family Summary
            </button>
            <button
              type="button"
              onClick={handleExportText}
              className="inline-flex items-center gap-1.5 px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50"
            >
              Export Text
            </button>
            <button
              type="button"
              onClick={handleExportHtml}
              className="inline-flex items-center gap-1.5 px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50"
              title="Download a portable HTML file for browser viewing or archival"
            >
              Export HTML
            </button>
            <button
              type="button"
              onClick={() => { void handleExportPdf(); }}
              className="inline-flex items-center gap-1.5 px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50"
              title="Download a dedicated PDF artifact of this evidence-backed passport"
            >
              Export PDF
            </button>
            <button
              type="button"
              onClick={handlePrint}
              className="inline-flex items-center gap-1.5 px-4 py-2 text-sm font-medium text-white bg-indigo-600 rounded-md hover:bg-indigo-700"
            >
              Print
            </button>
          </div>
        </div>

        {learner && <PassportDocument learner={learner} />}
      </div>
    </RoleRouteGuard>
  );
}

/* ───── Passport Document (printable) ───── */

function PassportDocument({ learner }: { learner: LearnerPassportData }) {
  const claimsByPillar = useMemo(() => {
    const map = new Map<string, PassportClaim[]>();
    for (const c of learner.ideationPassport.claims) {
      const key = legacyFamilyLabel(c.pillar);
      if (!map.has(key)) map.set(key, []);
      map.get(key)!.push(c);
    }
    return map;
  }, [learner.ideationPassport.claims]);

  return (
    <div className="bg-white print:shadow-none">
      {/* ── Title block ── */}
      <div className="border-b-2 border-indigo-600 pb-4 mb-6 print:border-b print:border-gray-300">
        <div className="flex items-baseline justify-between">
          <div>
            <h2 className="text-xl font-bold text-gray-900 print:text-lg">
              {learner.learnerName ?? 'Learner'}
            </h2>
            <p className="text-sm text-gray-500 mt-0.5">Scholesa Ideation Passport</p>
          </div>
          <div className="text-right text-sm text-gray-500">
            <div>Generated {formatDate(learner.ideationPassport.generatedAt)}</div>
            <div className="font-medium text-gray-700">
              Band: <span className="text-indigo-600">{bandLabel(learner.capabilitySnapshot.band)}</span>
            </div>
          </div>
        </div>
      </div>

      {/* ── Legacy Family Progress ── */}
      <section className="mb-6">
        <h3 className="text-sm font-semibold text-gray-500 uppercase tracking-wider mb-3">Legacy Family Progress</h3>
        <div className="grid grid-cols-3 gap-4">
          <PillarCard label={getLegacyPillarFamilyLabel('FUTURE_SKILLS')} value={learner.capabilitySnapshot.futureSkills} />
          <PillarCard label={getLegacyPillarFamilyLabel('LEADERSHIP_AGENCY')} value={learner.capabilitySnapshot.leadership} />
          <PillarCard label={getLegacyPillarFamilyLabel('IMPACT_INNOVATION')} value={learner.capabilitySnapshot.impact} />
        </div>
      </section>

      {/* ── Evidence Summary ── */}
      <section className="mb-6">
        <h3 className="text-sm font-semibold text-gray-500 uppercase tracking-wider mb-3">Evidence Summary</h3>
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
          <StatCard label="Evidence Records" value={learner.evidenceSummary.recordCount} />
          <StatCard label="Reviewed" value={learner.evidenceSummary.reviewedCount} />
          <StatCard label="Portfolio-Linked" value={learner.evidenceSummary.portfolioLinkedCount} />
          <StatCard label="Verified Artifacts" value={learner.portfolioSnapshot.verifiedArtifactCount} />
        </div>
      </section>

      {/* ── Growth Summary ── */}
      <section className="mb-6">
        <h3 className="text-sm font-semibold text-gray-500 uppercase tracking-wider mb-3">Growth Summary</h3>
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
          <StatCard label="Capabilities Tracked" value={learner.growthSummary.capabilityCount} />
          <StatCard label="Updated" value={learner.growthSummary.updatedCapabilityCount} />
          <StatCard label="Average Level" value={levelLabel(learner.growthSummary.averageLevel)} />
          <StatCard label="Latest Level" value={levelLabel(learner.growthSummary.latestLevel)} />
        </div>
      </section>

      {(learner.processDomainSnapshot.length > 0 || learner.processDomainGrowthTimeline.length > 0) && (
        <section className="mb-6">
          <h3 className="text-sm font-semibold text-gray-500 uppercase tracking-wider mb-3">Process Domains</h3>
          {learner.processDomainSnapshot.length > 0 ? (
            <div className="grid gap-3 sm:grid-cols-2">
              {learner.processDomainSnapshot.map((domain) => (
                <div key={domain.processDomainId} className="rounded-lg border border-gray-200 bg-white p-3">
                  <div className="font-medium text-gray-900">{domain.title}</div>
                  <div className="mt-1 text-xs text-gray-500">
                    Current {levelLabel(domain.currentLevel)} · Highest {levelLabel(domain.highestLevel)}
                  </div>
                  <div className="mt-1 text-xs text-gray-500">
                    {domain.evidenceCount} evidence · Updated {formatDate(domain.updatedAt)}
                  </div>
                </div>
              ))}
            </div>
          ) : (
            <p className="text-sm text-gray-500 italic">No process domain progress has been recorded yet.</p>
          )}
          {learner.processDomainGrowthTimeline.length > 0 && (
            <div className="mt-4 space-y-1.5">
              <h4 className="text-xs font-semibold uppercase tracking-wider text-gray-500">Recent process domain growth</h4>
              {learner.processDomainGrowthTimeline.slice(0, 10).map((entry, index) => (
                <div key={`${entry.processDomainId}-${index}`} className="flex items-center gap-3 border-b border-gray-50 py-1 text-sm">
                  <span className="w-20 shrink-0 text-xs text-gray-400">{formatDate(entry.createdAt)}</span>
                  <div className="flex-1">
                    <div className="font-medium text-gray-800">{entry.title}</div>
                    <div className="mt-0.5 text-[11px] text-gray-500">
                      {levelLabel(entry.fromLevel)} to {levelLabel(entry.toLevel)}
                      {entry.reviewingEducatorName ? ` · ${entry.reviewingEducatorName}` : ''}
                      {entry.evidenceCount > 0 ? ` · ${entry.evidenceCount} evidence` : ''}
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </section>
      )}

      {/* ── Capability Claims ── */}
      <section className="mb-6">
        <h3 className="text-sm font-semibold text-gray-500 uppercase tracking-wider mb-3">
          Capability Claims ({learner.ideationPassport.claims.length})
        </h3>
        {learner.ideationPassport.claims.length === 0 ? (
          <p className="text-sm text-gray-500 italic">No capability claims backed by evidence yet.</p>
        ) : (
          <div className="space-y-4">
            {Array.from(claimsByPillar.entries()).map(([pillar, claims]) => {
              const colors = pillarColor(pillar);
              return (
                <div key={pillar}>
                  <h4 className={`text-xs font-semibold uppercase tracking-wider mb-2 ${colors.text}`}>{pillar}</h4>
                  <div className="space-y-2">
                    {claims.map((claim) => (
                      <ClaimRow key={claim.capabilityId} claim={claim} />
                    ))}
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </section>

      {/* ── Portfolio Highlights ── */}
      {learner.portfolioItemsPreview.length > 0 && (
        <section className="mb-6">
          <h3 className="text-sm font-semibold text-gray-500 uppercase tracking-wider mb-3">
            Portfolio Artifacts ({learner.portfolioItemsPreview.length})
          </h3>
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-gray-200 text-left text-gray-500 text-xs uppercase">
                  <th className="pb-2 pr-3">Artifact</th>
                  <th className="pb-2 pr-3">Legacy family</th>
                  <th className="pb-2 pr-3">Status</th>
                  <th className="pb-2 pr-3">Proof</th>
                  <th className="pb-2 pr-3">AI</th>
                  <th className="pb-2">Reviewed</th>
                </tr>
              </thead>
              <tbody>
                {learner.portfolioItemsPreview.slice(0, 20).map((item) => (
                  <tr key={item.id} className="border-b border-gray-100">
                    <td className="py-1.5 pr-3">
                      <div className="font-medium text-gray-900">{item.title}</div>
                      <div className="mt-0.5 text-[11px] text-gray-500">
                        {item.capabilityTitles.length > 0 ? item.capabilityTitles.join(', ') : 'No capability tags'}
                        {item.evidenceRecordIds.length > 0 ? ` · ${item.evidenceRecordIds.length} evidence` : ''}
                        {item.missionAttemptId ? ' · mission-linked' : ''}
                        {item.proofCheckpointCount > 0 ? ` · ${item.proofCheckpointCount} checkpoints` : ''}
                      </div>
                    </td>
                    <td className="py-1.5 pr-3 text-gray-600">{legacyFamilyLabel(item.pillar)}</td>
                    <td className="py-1.5 pr-3">
                      <VerificationBadge status={item.verificationStatus} />
                    </td>
                    <td className="py-1.5 pr-3">
                      <ProofBadge status={item.proofOfLearningStatus} />
                    </td>
                    <td className="py-1.5 pr-3 text-gray-500 text-xs">{aiLabel(item.aiDisclosureStatus)}</td>
                    <td className="py-1.5 text-gray-500 text-xs">{item.reviewingEducatorName ?? '—'}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
      )}

      {/* ── Growth Timeline ── */}
      {learner.growthTimeline.length > 0 && (
        <section className="mb-6">
          <h3 className="text-sm font-semibold text-gray-500 uppercase tracking-wider mb-3">
            Growth Timeline (recent)
          </h3>
          <div className="space-y-1.5">
            {learner.growthTimeline.slice(0, 15).map((entry, i) => (
              <div key={`${entry.capabilityId}-${i}`} className="flex items-center gap-3 text-sm py-1 border-b border-gray-50">
                <span className="text-xs text-gray-400 w-20 shrink-0">{formatDate(entry.occurredAt)}</span>
                <div className="flex-1">
                  <div className="font-medium text-gray-800">{entry.title}</div>
                  <div className="mt-0.5 text-[11px] text-gray-500">
                    {entry.linkedEvidenceRecordIds.length} evidence · {entry.linkedPortfolioItemIds.length} portfolio
                    {entry.missionAttemptId ? ' · mission-linked' : ''}
                    {entry.reviewingEducatorName ? ` · ${entry.reviewingEducatorName}` : ''}
                  </div>
                </div>
                <div className="flex shrink-0 items-center gap-2">
                  <span className="text-xs px-1.5 py-0.5 rounded bg-gray-100 text-gray-600">
                    L{entry.level} {levelLabel(entry.level)}
                  </span>
                  <ProofBadge status={entry.proofOfLearningStatus ?? 'missing'} />
                  {entry.rubricRawScore != null && entry.rubricMaxScore != null && (
                    <span className="text-xs text-gray-500">{entry.rubricRawScore}/{entry.rubricMaxScore}</span>
                  )}
                </div>
              </div>
            ))}
          </div>
        </section>
      )}

      {/* ── Ideation Activity ── */}
      <section className="mb-6">
        <h3 className="text-sm font-semibold text-gray-500 uppercase tracking-wider mb-3">Ideation Activity</h3>
        <div className="grid grid-cols-2 sm:grid-cols-5 gap-3">
          <StatCard label="Missions Attempted" value={learner.ideationPassport.missionAttempts} />
          <StatCard label="Missions Completed" value={learner.ideationPassport.completedMissions} />
          <StatCard label="Reflections" value={learner.ideationPassport.reflectionsSubmitted} />
          <StatCard label="Voice Interactions" value={learner.ideationPassport.voiceInteractions} />
          <StatCard label="Collaboration" value={learner.ideationPassport.collaborationSignals} />
        </div>
      </section>

      {/* ── Footer ── */}
      <div className="border-t border-gray-200 pt-4 mt-8">
        <p className="text-xs text-gray-400 italic">{learner.ideationPassport.summary}</p>
        <p className="text-xs text-gray-300 mt-1">
          Scholesa Ideation Passport — capability claims are backed by reviewed evidence and verified artifacts.
        </p>
      </div>
    </div>
  );
}

/* ───── Sub-components ───── */

function PillarCard({ label, value }: { label: string; value: number | null }) {
  const colors = pillarColor(label);
  const percentage = value != null ? Math.round(value * 100) : 0;
  return (
    <div className={`rounded-lg border p-3 ${colors.bg} ${colors.border}`}>
      <div className={`text-xs font-medium ${colors.text}`}>{label}</div>
      <div className={`text-2xl font-bold mt-1 ${colors.text}`}>{pct(value)}</div>
      <div className="mt-2 h-1.5 rounded-full bg-white/60">
        <div
          className="h-full rounded-full bg-current opacity-60"
          style={{ width: `${Math.min(100, percentage)}%` }}
        />
      </div>
    </div>
  );
}

function StatCard({ label, value }: { label: string; value: string | number }) {
  return (
    <div className="border border-gray-200 rounded-lg p-3 bg-white">
      <div className="text-xs text-gray-500">{label}</div>
      <div className="text-lg font-semibold text-gray-900 mt-0.5">{value}</div>
    </div>
  );
}

function ClaimRow({ claim }: { claim: PassportClaim }) {
  const proofChecks = [
    claim.proofHasExplainItBack ? 'E' : null,
    claim.proofHasOralCheck ? 'O' : null,
    claim.proofHasMiniRebuild ? 'R' : null,
  ].filter(Boolean);

  return (
    <div className="flex items-center gap-3 border border-gray-100 rounded-lg px-3 py-2 text-sm">
      <div className="flex-1">
        <div className="font-medium text-gray-900">{claim.title}</div>
        <div className="text-xs text-gray-500 mt-0.5 flex gap-3">
          <span>{claim.evidenceCount} evidence</span>
          <span>{claim.verifiedArtifactCount} verified</span>
          {claim.portfolioItemIds.length > 0 && <span>{claim.portfolioItemIds.length} portfolio</span>}
          {claim.missionAttemptIds.length > 0 && <span>{claim.missionAttemptIds.length} mission</span>}
          {claim.reviewingEducatorName && <span>by {claim.reviewingEducatorName}</span>}
          {claim.reviewedAt && <span>{formatDate(claim.reviewedAt)}</span>}
        </div>
        {claim.progressionDescriptors.length > 0 && (
          <p className="mt-1 text-xs text-gray-500 italic">
            &ldquo;{claim.progressionDescriptors[0]}&rdquo;
          </p>
        )}
      </div>
      <div className="text-right shrink-0 space-y-0.5">
        <div className="text-xs font-medium">
          <span className="px-1.5 py-0.5 rounded bg-indigo-50 text-indigo-700">
            {levelLabel(claim.latestLevel)}
          </span>
        </div>
        <div className="flex gap-1 justify-end">
          <ProofBadge status={claim.proofOfLearningStatus} />
          {proofChecks.length > 0 && (
            <span className="text-xs px-1 py-0.5 rounded bg-gray-100 text-gray-500">
              {proofChecks.join('·')}
            </span>
          )}
          {claim.proofCheckpointCount > 0 && (
            <span className="text-xs px-1 py-0.5 rounded bg-gray-100 text-gray-500">
              {claim.proofCheckpointCount} cp
            </span>
          )}
        </div>
      </div>
    </div>
  );
}

function ProofBadge({ status }: { status: string }) {
  const config: Record<string, { bg: string; text: string }> = {
    verified: { bg: 'bg-green-100', text: 'text-green-700' },
    partial: { bg: 'bg-yellow-100', text: 'text-yellow-700' },
    missing: { bg: 'bg-red-50', text: 'text-red-600' },
  };
  const c = config[status] ?? { bg: 'bg-gray-100', text: 'text-gray-500' };
  return (
    <span className={`text-xs px-1.5 py-0.5 rounded ${c.bg} ${c.text}`}>
      {proofLabel(status)}
    </span>
  );
}

function VerificationBadge({ status }: { status: string | null }) {
  if (!status) return <span className="text-xs text-gray-400">—</span>;
  const config: Record<string, { bg: string; text: string; label: string }> = {
    verified: { bg: 'bg-green-100', text: 'text-green-700', label: 'Verified' },
    reviewed: { bg: 'bg-blue-100', text: 'text-blue-700', label: 'Reviewed' },
    pending: { bg: 'bg-gray-100', text: 'text-gray-600', label: 'Pending' },
  };
  const c = config[status] ?? { bg: 'bg-gray-100', text: 'text-gray-500', label: status };
  return (
    <span className={`text-xs px-1.5 py-0.5 rounded ${c.bg} ${c.text}`}>
      {c.label}
    </span>
  );
}
