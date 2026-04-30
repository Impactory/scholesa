'use client';

/**
 * MiloOS Learner Intelligence Surface (S5-2)
 *
 * Wraps AICoachScreen with learner-loop support journey state.
 * Shows learners the server-owned MiloOS support and verification trail
 * without presenting support signals as capability mastery.
 */

import React, { useCallback, useEffect, useMemo, useState } from 'react';
import dynamic from 'next/dynamic';
import { resolveActiveSiteId } from '@/src/lib/auth/activeSite';
import {
  getMiloOSLearnerLoopInsights,
  type MiloOSLearnerLoopInsights,
} from '@/src/lib/miloos/learnerLoopInsights';
import type { CustomRouteRendererProps } from '../customRouteRenderers';
import {
  BrainIcon,
  ActivityIcon,
  CheckCircleIcon,
  AlertTriangleIcon,
  ShieldCheckIcon,
} from 'lucide-react';

const AICoachScreen = dynamic(
  () =>
    import('@/src/components/sdt/AICoachScreen').then((mod) => mod.AICoachScreen),
  { loading: () => <div className="p-4 text-gray-500">Loading MiloOS...</div> }
);

type SupportJourneyStatus = 'ready' | 'building' | 'needsExplainBack';

function formatCount(value: unknown): number {
  return typeof value === 'number' && Number.isFinite(value) ? value : 0;
}

function deriveSupportJourneyStatus(
  insights: MiloOSLearnerLoopInsights | null
): SupportJourneyStatus {
  const pendingExplainBack = formatCount(insights?.verification.pendingExplainBack);
  const supportOpened = formatCount(insights?.verification.aiHelpOpened);
  const explainBackSubmitted = formatCount(insights?.verification.explainBackSubmitted);

  if (pendingExplainBack > 0) return 'needsExplainBack';
  if (supportOpened > 0 && explainBackSubmitted === 0) return 'building';
  return 'ready';
}

export default function LearnerMiloOSRenderer({ ctx }: CustomRouteRendererProps) {
  const learnerId = ctx.uid;
  const siteId = resolveActiveSiteId(ctx.profile);
  const [insights, setInsights] = useState<MiloOSLearnerLoopInsights | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const loadInsights = useCallback(async (isCancelled: () => boolean = () => false) => {
    if (!learnerId || !siteId) {
      setInsights(null);
      setLoading(false);
      return;
    }
    setLoading(true);
    setError(null);
    try {
      const nextInsights = await getMiloOSLearnerLoopInsights({
        learnerId,
        siteId,
        lookbackDays: 30,
      });
      if (!isCancelled()) {
        setInsights(nextInsights);
      }
    } catch (err) {
      console.error('Failed to load MiloOS learner-loop insights:', err);
      if (!isCancelled()) {
        setInsights(null);
        setError('MiloOS support signals are unavailable right now. Try again in a moment.');
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

  const supportJourneyStatus = useMemo(
    () => deriveSupportJourneyStatus(insights),
    [insights]
  );

  const statusConfig = {
    ready: {
      label: 'Learning Loop Ready',
      color: 'bg-green-100 text-green-800 border-green-200',
      icon: <CheckCircleIcon className="h-4 w-4" />,
      message:
        'MiloOS support is connected to your verification trail without creating mastery by itself.',
    },
    building: {
      label: 'Building Independence',
      color: 'bg-amber-100 text-amber-800 border-amber-200',
      icon: <ActivityIcon className="h-4 w-4" />,
      message:
        'Use MiloOS for a thinking nudge, then explain what changed in your own words.',
    },
    needsExplainBack: {
      label: 'Explain-Back Needed',
      color: 'bg-red-100 text-red-800 border-red-200',
      icon: <AlertTriangleIcon className="h-4 w-4" />,
      message:
        'One or more MiloOS support turns still need your own explanation before they are trustworthy.',
    },
  };

  const supportOpened = formatCount(insights?.verification.aiHelpOpened);
  const supportUsed = formatCount(insights?.verification.aiHelpUsed);
  const explainBackSubmitted = formatCount(insights?.verification.explainBackSubmitted);
  const pendingExplainBack = formatCount(insights?.verification.pendingExplainBack);
  const activeMvl = formatCount(insights?.mvl.active);
  const validSamples = formatCount(insights?.stateAvailability.validSamples);

  if (!siteId) {
    return (
      <div
        className="rounded-xl border border-amber-200 bg-amber-50 p-8 text-center text-sm text-amber-900"
        data-testid="learner-miloos-site-required"
      >
        <p className="font-semibold">Active site required</p>
        <p className="mt-1 text-amber-700">
          Select an active site before using MiloOS learning support.
        </p>
      </div>
    );
  }

  return (
    <div className="space-y-4">
      <div className="flex items-center gap-3">
        <BrainIcon className="h-7 w-7 text-indigo-600" />
        <div>
          <h2 className="text-xl font-bold text-gray-900">MiloOS Coach</h2>
          <p className="text-sm text-gray-500">
            Your learning support companion for hints, rubric checks, debugging, and explain-back.
          </p>
        </div>
      </div>

      {error ? (
        <div className="rounded-lg border border-red-200 bg-red-50 p-4 text-sm text-red-800">
          {error}
        </div>
      ) : null}

      {loading ? (
        <div className="rounded-lg border border-gray-200 bg-gray-50 p-4 text-sm text-gray-600">
          Loading MiloOS learner-loop signals...
        </div>
      ) : (
        <div
          className={`flex items-start gap-3 rounded-lg border p-3 ${
            statusConfig[supportJourneyStatus].color
          }`}
          data-testid="learner-miloos-loop-status"
        >
          {statusConfig[supportJourneyStatus].icon}
          <div>
            <p className="text-sm font-medium">
              {statusConfig[supportJourneyStatus].label}
            </p>
            <p className="text-xs mt-0.5">
              {statusConfig[supportJourneyStatus].message}
            </p>
          </div>
        </div>
      )}

      {!loading ? (
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <div
            className="bg-white border border-gray-200 rounded-lg p-3 text-center"
            data-testid="learner-miloos-support-opened"
          >
            <p className="text-lg font-bold text-indigo-600">{supportOpened}</p>
            <p className="text-xs text-gray-500">Support opened</p>
          </div>
          <div
            className="bg-white border border-gray-200 rounded-lg p-3 text-center"
            data-testid="learner-miloos-support-used"
          >
            <p className="text-lg font-bold text-purple-600">{supportUsed}</p>
            <p className="text-xs text-gray-500">Support used</p>
          </div>
          <div
            className="bg-white border border-gray-200 rounded-lg p-3 text-center"
            data-testid="learner-miloos-explain-backs"
          >
            <p className="text-lg font-bold text-green-600">{explainBackSubmitted}</p>
            <p className="text-xs text-gray-500">Explain-backs</p>
          </div>
          <div
            className="bg-white border border-gray-200 rounded-lg p-3 text-center"
            data-testid="learner-miloos-pending-checks"
          >
            <p className="text-lg font-bold text-red-600">{pendingExplainBack}</p>
            <p className="text-xs text-gray-500">Pending checks</p>
          </div>
        </div>
      ) : null}

      {!loading ? (
        <div className="flex items-start gap-3 rounded-lg border border-gray-200 bg-gray-50 p-3 text-sm text-gray-700">
          <ShieldCheckIcon className="mt-0.5 h-4 w-4 text-amber-600" />
          <p>
            {activeMvl} active verification checks and {validSamples} learner-loop state samples are
            visible here as support provenance, not capability mastery.
          </p>
        </div>
      ) : null}

      <div className="bg-white border border-gray-200 rounded-lg p-4">
        <AICoachScreen
          learnerId={learnerId}
          siteId={siteId}
          onLearnerLoopUpdated={() => loadInsights()}
        />
      </div>
    </div>
  );
}
