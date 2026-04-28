'use client';

import dynamic from 'next/dynamic';
import { useCallback, useEffect, useMemo, useState } from 'react';
import { ActivityIcon, BrainIcon, CheckCircle2Icon, ShieldCheckIcon } from 'lucide-react';
import {
  getMiloOSLearnerLoopInsights,
  type MiloOSLearnerLoopInsights,
} from '@/src/lib/miloos/learnerLoopInsights';

const AICoachScreen = dynamic(
  () => import('@/src/components/sdt/AICoachScreen').then((mod) => mod.AICoachScreen),
  { loading: () => <div className="p-4 text-sm text-gray-500">Loading MiloOS...</div> }
);

function formatSignal(value: number | null | undefined): string {
  return typeof value === 'number' && Number.isFinite(value) ? `${Math.round(value * 100)}%` : '--';
}

function formatCount(value: unknown): number {
  return typeof value === 'number' && Number.isFinite(value) ? value : 0;
}

function summarizeTrend(insights: MiloOSLearnerLoopInsights | null): string {
  const score = insights?.trend?.improvementScore;
  if (typeof score !== 'number' || !Number.isFinite(score)) {
    return 'Waiting for more learner-loop samples';
  }
  if (score > 0.05) return 'Support signals are strengthening';
  if (score < -0.05) return 'Support signals need attention';
  return 'Support signals are steady';
}

export function MiloOSLearnerSupportSnapshot({
  learnerId,
  siteId,
}: {
  learnerId: string;
  siteId: string;
}) {
  const [insights, setInsights] = useState<MiloOSLearnerLoopInsights | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [showCoach, setShowCoach] = useState(false);

  const loadInsights = useCallback(async (isCancelled: () => boolean = () => false) => {
    setLoading(true);
    setError(null);
    try {
      const nextInsights = await getMiloOSLearnerLoopInsights({ learnerId, siteId, lookbackDays: 30 });
      if (!isCancelled()) {
        setInsights(nextInsights);
      }
    } catch (loadErr) {
      console.error('Failed to load MiloOS learner loop insights', loadErr);
      if (!isCancelled()) {
        setInsights(null);
        setError('MiloOS support snapshot is unavailable right now.');
      }
    } finally {
      if (!isCancelled()) {
        setLoading(false);
      }
    }
  }, [learnerId, siteId]);

  useEffect(() => {
    let cancelled = false;
    void loadInsights(() => cancelled);
    return () => {
      cancelled = true;
    };
  }, [loadInsights]);

  const eventCounts = insights?.eventCounts ?? {};
  const verification = insights?.verification;
  const hasCurrentState = insights?.stateAvailability.hasCurrentState === true;
  const trendSummary = useMemo(() => summarizeTrend(insights), [insights]);

  return (
    <section className="rounded-lg border border-indigo-100 bg-white p-4 shadow-sm">
      <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
        <div className="flex items-start gap-3">
          <span className="flex h-10 w-10 items-center justify-center rounded-lg bg-indigo-50 text-indigo-700">
            <BrainIcon className="h-5 w-5" />
          </span>
          <div>
            <h2 className="text-lg font-semibold text-gray-900">MiloOS Support Snapshot</h2>
            <p className="mt-1 text-sm text-gray-500">
              Server-read learning support signals, separate from capability mastery.
            </p>
          </div>
        </div>
        <button
          type="button"
          onClick={() => setShowCoach((current) => !current)}
          className="inline-flex items-center justify-center rounded-lg bg-indigo-600 px-3 py-2 text-sm font-medium text-white transition-colors hover:bg-indigo-700"
        >
          {showCoach ? 'Close MiloOS coach' : 'Open MiloOS coach'}
        </button>
      </div>

      {loading ? (
        <div className="mt-4 rounded-lg border border-gray-100 bg-gray-50 p-4 text-sm text-gray-500">
          Loading MiloOS support snapshot...
        </div>
      ) : error ? (
        <div className="mt-4 rounded-lg border border-amber-200 bg-amber-50 p-4 text-sm text-amber-800">
          {error}
        </div>
      ) : hasCurrentState ? (
        <div className="mt-4 grid gap-3 md:grid-cols-3">
          <div className="rounded-lg border border-gray-100 bg-gray-50 p-3">
            <p className="text-xs font-medium uppercase text-gray-500">Cognition signal</p>
            <p className="mt-2 text-xl font-semibold text-gray-900">{formatSignal(insights?.state?.cognition)}</p>
          </div>
          <div className="rounded-lg border border-gray-100 bg-gray-50 p-3">
            <p className="text-xs font-medium uppercase text-gray-500">Engagement signal</p>
            <p className="mt-2 text-xl font-semibold text-gray-900">{formatSignal(insights?.state?.engagement)}</p>
          </div>
          <div className="rounded-lg border border-gray-100 bg-gray-50 p-3">
            <p className="text-xs font-medium uppercase text-gray-500">Integrity signal</p>
            <p className="mt-2 text-xl font-semibold text-gray-900">{formatSignal(insights?.state?.integrity)}</p>
          </div>
        </div>
      ) : (
        <div className="mt-4 rounded-lg border border-gray-100 bg-gray-50 p-4 text-sm text-gray-500">
          No MiloOS support snapshot yet. Signals appear after real learner-loop events.
        </div>
      )}

      <div className="mt-4 grid gap-3 md:grid-cols-3">
        <div className="flex items-center gap-3 rounded-lg border border-gray-100 bg-gray-50 p-3">
          <ActivityIcon className="h-5 w-5 text-indigo-600" />
          <div>
            <p className="text-sm font-semibold text-gray-900">{trendSummary}</p>
            <p className="text-xs text-gray-500">{insights?.stateAvailability.validSamples ?? 0} state samples</p>
          </div>
        </div>
        <div className="flex items-center gap-3 rounded-lg border border-gray-100 bg-gray-50 p-3">
          <CheckCircle2Icon className="h-5 w-5 text-emerald-600" />
          <div>
            <p className="text-sm font-semibold text-gray-900">
              {formatCount(eventCounts.ai_help_opened)} support sessions opened
            </p>
            <p className="text-xs text-gray-500">
              {formatCount(eventCounts.explain_it_back_submitted)} explain-backs /{' '}
              {formatCount(verification?.pendingExplainBack)} pending
            </p>
          </div>
        </div>
        <div className="flex items-center gap-3 rounded-lg border border-gray-100 bg-gray-50 p-3">
          <ShieldCheckIcon className="h-5 w-5 text-amber-600" />
          <div>
            <p className="text-sm font-semibold text-gray-900">
              {formatCount(insights?.mvl.active)} active verification checks
            </p>
            <p className="text-xs text-gray-500">
              {formatCount(insights?.mvl.passed)} passed / {formatCount(insights?.mvl.failed)} needs review
            </p>
          </div>
        </div>
      </div>

      {showCoach ? (
        <div className="mt-4 border-t border-gray-100 pt-4">
          <AICoachScreen
            learnerId={learnerId}
            siteId={siteId}
            onLearnerLoopUpdated={() => loadInsights()}
          />
        </div>
      ) : null}
    </section>
  );
}
