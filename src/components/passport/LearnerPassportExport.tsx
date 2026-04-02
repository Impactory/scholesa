'use client';

import { useCallback, useEffect, useMemo, useState } from 'react';
import { httpsCallable } from 'firebase/functions';
import { functions } from '@/src/firebase/client-init';
import { useAuthContext } from '@/src/firebase/auth/AuthProvider';
import { RoleRouteGuard } from '@/src/components/auth/RoleRouteGuard';
import { Spinner } from '@/src/components/ui/Spinner';

/* ───── Types (match buildParentLearnerSummary return) ───── */

interface PassportClaim {
  capabilityId: string;
  title: string;
  pillar: string | null;
  latestLevel: number | null;
  evidenceCount: number;
  verifiedArtifactCount: number;
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
}

interface PortfolioItemPreview {
  id: string;
  title: string;
  pillar: string | null;
  type: string;
  completedAt: string;
  verificationStatus: string | null;
  evidenceLinked: boolean;
  capabilityTitles: string[];
  proofOfLearningStatus: string;
  aiDisclosureStatus: string;
  proofHasExplainItBack: boolean;
  proofHasOralCheck: boolean;
  proofHasMiniRebuild: boolean;
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
        completedAt: str(r.completedAt, new Date().toISOString()),
        verificationStatus: str(r.verificationStatus) || null,
        evidenceLinked: r.evidenceLinked === true,
        capabilityTitles: Array.isArray(r.capabilityTitles) ? r.capabilityTitles.filter((v): v is string => typeof v === 'string') : [],
        proofOfLearningStatus: str(r.proofOfLearningStatus, 'missing'),
        aiDisclosureStatus: str(r.aiDisclosureStatus, 'not-available'),
        proofHasExplainItBack: r.proofHasExplainItBack === true,
        proofHasOralCheck: r.proofHasOralCheck === true,
        proofHasMiniRebuild: r.proofHasMiniRebuild === true,
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

/* ───── Pillar colours ───── */

const PILLAR_COLORS: Record<string, { bg: string; text: string; border: string }> = {
  'Future Skills': { bg: 'bg-blue-50', text: 'text-blue-800', border: 'border-blue-200' },
  'Leadership & Agency': { bg: 'bg-amber-50', text: 'text-amber-800', border: 'border-amber-200' },
  'Impact & Innovation': { bg: 'bg-emerald-50', text: 'text-emerald-800', border: 'border-emerald-200' },
};

function pillarColor(pillar: string | null) {
  return PILLAR_COLORS[pillar ?? ''] ?? { bg: 'bg-gray-50', text: 'text-gray-700', border: 'border-gray-200' };
}

/* ───── Component ───── */

export function LearnerPassportExport() {
  const { user, profile, loading: authLoading } = useAuthContext();
  const [learners, setLearners] = useState<LearnerPassportData[]>([]);
  const [selectedIndex, setSelectedIndex] = useState(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const siteId = profile?.activeSiteId ?? profile?.siteIds?.[0] ?? null;

  const fetchPassport = useCallback(async () => {
    if (!user) return;
    setLoading(true);
    setError(null);
    try {
      const callable = httpsCallable(functions, 'getParentDashboardBundle');
      const response = await callable({ siteId: siteId || undefined, locale: 'en', range: 'all' });
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

  const handlePrint = useCallback(() => { window.print(); }, []);

  const handleExportText = useCallback(() => {
    if (!learner) return;
    const lines: string[] = [];
    lines.push('═══════════════════════════════════════════');
    lines.push('  SCHOLESA IDEATION PASSPORT');
    lines.push('═══════════════════════════════════════════');
    lines.push('');
    lines.push(`Learner: ${learner.learnerName ?? 'Unknown'}`);
    lines.push(`Generated: ${formatDate(learner.ideationPassport.generatedAt)}`);
    lines.push(`Capability Band: ${bandLabel(learner.capabilitySnapshot.band)}`);
    lines.push('');
    lines.push('── Pillar Progress ──');
    lines.push(`  Future Skills:        ${pct(learner.capabilitySnapshot.futureSkills)}`);
    lines.push(`  Leadership & Agency:  ${pct(learner.capabilitySnapshot.leadership)}`);
    lines.push(`  Impact & Innovation:  ${pct(learner.capabilitySnapshot.impact)}`);
    lines.push(`  Overall:              ${pct(learner.capabilitySnapshot.overall)}`);
    lines.push('');
    lines.push('── Evidence Summary ──');
    lines.push(`  Evidence Records:     ${learner.evidenceSummary.recordCount}`);
    lines.push(`  Reviewed:             ${learner.evidenceSummary.reviewedCount}`);
    lines.push(`  Portfolio-Linked:     ${learner.evidenceSummary.portfolioLinkedCount}`);
    lines.push(`  Latest Evidence:      ${formatDate(learner.evidenceSummary.latestEvidenceAt)}`);
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
      lines.push(`    Pillar:          ${claim.pillar ?? '—'}`);
      lines.push(`    Level:           ${levelLabel(claim.latestLevel)}`);
      lines.push(`    Evidence:        ${claim.evidenceCount} records, ${claim.verifiedArtifactCount} verified artifacts`);
      lines.push(`    Proof-of-Learn:  ${proofLabel(claim.proofOfLearningStatus)}`);
      lines.push(`    AI Disclosure:   ${aiLabel(claim.aiDisclosureStatus)}`);
      if (claim.reviewingEducatorName) {
        lines.push(`    Reviewed by:     ${claim.reviewingEducatorName} (${formatDate(claim.reviewedAt)})`);
      }
      if (claim.rubricRawScore != null && claim.rubricMaxScore != null) {
        lines.push(`    Rubric Score:    ${claim.rubricRawScore}/${claim.rubricMaxScore}`);
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
      <RoleRouteGuard allowedRoles={['parent', 'site', 'hq']}>
        <div className="flex items-center justify-center min-h-[400px]">
          <Spinner />
        </div>
      </RoleRouteGuard>
    );
  }

  if (error) {
    return (
      <RoleRouteGuard allowedRoles={['parent', 'site', 'hq']}>
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
      <RoleRouteGuard allowedRoles={['parent', 'site', 'hq']}>
        <div className="p-6">
          <div className="bg-gray-50 border border-gray-200 rounded-lg p-8 text-center">
            <p className="text-gray-600">No linked learners found. Passport data will appear once learners have evidence.</p>
          </div>
        </div>
      </RoleRouteGuard>
    );
  }

  return (
    <RoleRouteGuard allowedRoles={['parent', 'site', 'hq']}>
      <div className="max-w-4xl mx-auto p-6 print:p-0 print:max-w-none">
        {/* ── Header (screen only) ── */}
        <div className="flex items-center justify-between mb-6 print:hidden">
          <div>
            <h1 className="text-2xl font-bold text-gray-900">Ideation Passport</h1>
            <p className="text-sm text-gray-500 mt-1">Evidence-backed learner capability report</p>
          </div>
          <div className="flex gap-2">
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
              onClick={handleExportText}
              className="inline-flex items-center gap-1.5 px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50"
            >
              Export Text
            </button>
            <button
              onClick={handlePrint}
              className="inline-flex items-center gap-1.5 px-4 py-2 text-sm font-medium text-white bg-indigo-600 rounded-md hover:bg-indigo-700"
            >
              Print / PDF
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
      const key = c.pillar ?? 'Other';
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

      {/* ── Pillar Progress ── */}
      <section className="mb-6">
        <h3 className="text-sm font-semibold text-gray-500 uppercase tracking-wider mb-3">Pillar Progress</h3>
        <div className="grid grid-cols-3 gap-4">
          <PillarCard label="Future Skills" value={learner.capabilitySnapshot.futureSkills} />
          <PillarCard label="Leadership & Agency" value={learner.capabilitySnapshot.leadership} />
          <PillarCard label="Impact & Innovation" value={learner.capabilitySnapshot.impact} />
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
                  <th className="pb-2 pr-3">Pillar</th>
                  <th className="pb-2 pr-3">Status</th>
                  <th className="pb-2 pr-3">Proof</th>
                  <th className="pb-2 pr-3">AI</th>
                  <th className="pb-2">Reviewed</th>
                </tr>
              </thead>
              <tbody>
                {learner.portfolioItemsPreview.slice(0, 20).map((item) => (
                  <tr key={item.id} className="border-b border-gray-100">
                    <td className="py-1.5 pr-3 font-medium text-gray-900">{item.title}</td>
                    <td className="py-1.5 pr-3 text-gray-600">{item.pillar ?? '—'}</td>
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
                <span className="font-medium text-gray-800 flex-1">{entry.title}</span>
                <span className="text-xs px-1.5 py-0.5 rounded bg-gray-100 text-gray-600">
                  L{entry.level} {levelLabel(entry.level)}
                </span>
                {entry.rubricRawScore != null && entry.rubricMaxScore != null && (
                  <span className="text-xs text-gray-500">{entry.rubricRawScore}/{entry.rubricMaxScore}</span>
                )}
                {entry.reviewingEducatorName && (
                  <span className="text-xs text-gray-400">{entry.reviewingEducatorName}</span>
                )}
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
          {claim.reviewingEducatorName && <span>by {claim.reviewingEducatorName}</span>}
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
