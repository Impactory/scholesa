'use client';

import { useEffect, useState } from 'react';
import { httpsCallable } from 'firebase/functions';
import { functions } from '@/src/firebase/client-init';
import { useAuthContext } from '@/src/firebase/auth/AuthProvider';
import { CapabilityGuidancePanel } from '@/src/components/analytics/CapabilityGuidancePanel';
import { Spinner } from '@/src/components/ui/Spinner';

interface LearnerSummary {
  learnerId: string;
  learnerName: string;
  capabilitySnapshot: {
    band: string | null;
    overall: number | null;
    futureSkills: number | null;
    leadership: number | null;
    impact: number | null;
  } | null;
  growthTimeline: GrowthTimelineEntry[];
  portfolioSnapshot: {
    artifactCount: number;
    verifiedArtifactCount: number;
  } | null;
  ideationPassport: {
    reflectionsSubmitted: number;
    completedMissions: number;
    summary: string;
  } | null;
  evidenceSummary: {
    recordCount: number;
    reviewedCount: number;
  } | null;
}

interface GrowthTimelineEntry {
  capabilityId: string;
  title: string;
  pillar: string;
  level: number;
  occurredAt: string | null;
}


const BAND_COLORS: Record<string, string> = {
  strong: 'bg-green-100 text-green-800 border-green-200',
  developing: 'bg-blue-100 text-blue-800 border-blue-200',
  emerging: 'bg-amber-100 text-amber-800 border-amber-200',
};

const LEVEL_LABELS: Record<number, string> = {
  1: 'Beginning',
  2: 'Developing',
  3: 'Proficient',
  4: 'Advanced',
};

export function ParentSummaryDashboard() {
  const { user, profile, loading: authLoading } = useAuthContext();
  const siteId = profile?.studioId ?? null;
  const parentId = user?.uid ?? null;

  const [learners, setLearners] = useState<LearnerSummary[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!parentId) return;
    let cancelled = false;

    async function load() {
      setLoading(true);
      setError(null);
      try {
        const callable = httpsCallable(functions, 'getParentDashboardBundle');
        const result = await callable({
          siteId: siteId || undefined,
          range: 'week',
        });
        const data = (result.data || {}) as Record<string, unknown>;
        const rawLearners = Array.isArray(data.learners) ? data.learners : [];

        const parsed: LearnerSummary[] = rawLearners
          .filter((l): l is Record<string, unknown> => !!l && typeof l === 'object' && !Array.isArray(l))
          .map((l) => ({
            learnerId: String(l.learnerId ?? ''),
            learnerName: String(l.learnerName ?? 'Learner'),
            capabilitySnapshot: l.capabilitySnapshot && typeof l.capabilitySnapshot === 'object'
              ? l.capabilitySnapshot as LearnerSummary['capabilitySnapshot']
              : null,
            growthTimeline: Array.isArray(l.growthTimeline)
              ? (l.growthTimeline as GrowthTimelineEntry[]).slice(0, 15)
              : [],
            portfolioSnapshot: l.portfolioSnapshot && typeof l.portfolioSnapshot === 'object'
              ? l.portfolioSnapshot as LearnerSummary['portfolioSnapshot']
              : null,
            ideationPassport: l.ideationPassport && typeof l.ideationPassport === 'object'
              ? l.ideationPassport as LearnerSummary['ideationPassport']
              : null,
            evidenceSummary: l.evidenceSummary && typeof l.evidenceSummary === 'object'
              ? l.evidenceSummary as LearnerSummary['evidenceSummary']
              : null,
          }))
          .filter((l) => l.learnerId.length > 0);

        if (cancelled) return;
        setLearners(parsed);
      } catch (err) {
        console.error('Failed to load parent dashboard', err);
        if (!cancelled) setError('Failed to load dashboard. Please try again.');
      } finally {
        if (!cancelled) setLoading(false);
      }
    }

    void load();
    return () => { cancelled = true; };
  }, [parentId, siteId]);

  if (authLoading || loading) {
    return (
      <div className="flex items-center justify-center min-h-[300px]">
        <Spinner />
        <span className="ml-2 text-sm text-gray-500">Loading family dashboard...</span>
      </div>
    );
  }

  if (error) {
    return (
      <div className="rounded-lg border border-red-200 bg-red-50 p-6 text-sm text-red-700">
        {error}
      </div>
    );
  }

  if (!parentId) {
    return (
      <div className="rounded-lg border border-gray-200 bg-white p-8 text-center text-sm text-gray-500">
        Please sign in to view your family dashboard.
      </div>
    );
  }

  if (learners.length === 0) {
    return (
      <div className="max-w-4xl mx-auto space-y-6" data-testid="parent-summary-dashboard">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Family Dashboard</h1>
          <p className="mt-1 text-sm text-gray-500">Your children&apos;s capability growth and evidence at a glance.</p>
        </div>
        <div className="rounded-lg border border-gray-200 bg-gray-50 p-6 text-sm text-gray-500 text-center">
          No linked learners found. Please contact your school to link your children to your account.
        </div>
      </div>
    );
  }

  return (
    <div className="max-w-4xl mx-auto space-y-8" data-testid="parent-summary-dashboard">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Family Dashboard</h1>
        <p className="mt-1 text-sm text-gray-500">
          Your children&apos;s capability growth and evidence at a glance.
        </p>
      </div>

      {learners.map((learner) => (
        <div key={learner.learnerId} className="space-y-4">
          {/* Learner Header */}
          <div className="flex items-center gap-3">
            <h2 className="text-xl font-semibold text-gray-900">{learner.learnerName}</h2>
            {learner.capabilitySnapshot?.band && (
              <span className={`rounded-full border px-3 py-0.5 text-xs font-medium ${
                BAND_COLORS[learner.capabilitySnapshot.band] ?? 'bg-gray-100 text-gray-600'
              }`}>
                {learner.capabilitySnapshot.band.charAt(0).toUpperCase() + learner.capabilitySnapshot.band.slice(1)}
              </span>
            )}
          </div>

          {/* Capability Guidance Panel — the rich, evidence-backed view */}
          {siteId && (
            <CapabilityGuidancePanel
              learnerId={learner.learnerId}
              siteId={siteId}
              learnerName={learner.learnerName}
            />
          )}

          {/* Evidence & Portfolio Summary */}
          <div className="grid gap-3 sm:grid-cols-3">
            <div className="rounded-lg border border-gray-200 bg-white p-4">
              <h3 className="text-xs font-semibold text-gray-500 uppercase tracking-wide">Evidence</h3>
              <p className="mt-1 text-2xl font-bold text-gray-900">
                {learner.evidenceSummary?.recordCount ?? 0}
              </p>
              <p className="text-xs text-gray-500">
                {learner.evidenceSummary?.reviewedCount ?? 0} reviewed
              </p>
            </div>
            <div className="rounded-lg border border-gray-200 bg-white p-4">
              <h3 className="text-xs font-semibold text-gray-500 uppercase tracking-wide">Portfolio</h3>
              <p className="mt-1 text-2xl font-bold text-gray-900">
                {learner.portfolioSnapshot?.artifactCount ?? 0}
              </p>
              <p className="text-xs text-gray-500">
                {learner.portfolioSnapshot?.verifiedArtifactCount ?? 0} verified
              </p>
            </div>
            <div className="rounded-lg border border-gray-200 bg-white p-4">
              <h3 className="text-xs font-semibold text-gray-500 uppercase tracking-wide">Missions</h3>
              <p className="mt-1 text-2xl font-bold text-gray-900">
                {learner.ideationPassport?.completedMissions ?? 0}
              </p>
              <p className="text-xs text-gray-500">
                {learner.ideationPassport?.reflectionsSubmitted ?? 0} reflections
              </p>
            </div>
          </div>

          {/* Growth Timeline */}
          <section>
            <h3 className="text-sm font-semibold text-gray-900 mb-2">Recent Growth</h3>
            {learner.growthTimeline.length === 0 ? (
              <div className="rounded-lg border border-gray-200 bg-gray-50 p-3 text-xs text-gray-500">
                No capability growth events yet. Evidence is still being collected.
              </div>
            ) : (
              <div className="space-y-1.5">
                {learner.growthTimeline.slice(0, 8).map((g, i) => (
                  <div key={`${g.capabilityId}-${i}`} className="rounded border border-gray-100 bg-white px-3 py-2 flex items-center justify-between">
                    <div>
                      <span className="text-xs font-medium text-gray-900">{g.title}</span>
                      <span className="ml-2 text-xs text-gray-400">{g.pillar}</span>
                    </div>
                    <div className="text-right">
                      <span className="text-xs font-medium text-gray-700">
                        Level {g.level}/4
                      </span>
                      <span className="ml-1 text-xs text-gray-400">
                        {LEVEL_LABELS[g.level] ?? ''}
                      </span>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </section>

          {/* Passport Summary */}
          {learner.ideationPassport?.summary && (
            <div className="rounded-lg border border-indigo-100 bg-indigo-50 p-4">
              <h3 className="text-sm font-semibold text-indigo-800 mb-1">Learning Passport Summary</h3>
              <p className="text-xs text-indigo-700">{learner.ideationPassport.summary}</p>
            </div>
          )}

          {/* Separator between children */}
          {learners.indexOf(learner) < learners.length - 1 && (
            <hr className="border-gray-200" />
          )}
        </div>
      ))}
    </div>
  );
}
