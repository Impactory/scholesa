'use client';

/**
 * MiloOS Learner Intelligence Surface (S5-2)
 *
 * Wraps AICoachScreen with autonomy risk awareness and intervention
 * state display. Shows learners their current learning state and
 * why MiloOS may be gating certain AI modes.
 */

import React, { useCallback, useEffect, useState } from 'react';
import dynamic from 'next/dynamic';
import {
  collection,
  getDocs,
  query,
  where,
  orderBy,
  limit,
} from 'firebase/firestore';
import { firestore } from '@/src/firebase/client-init';
import type { CustomRouteRendererProps } from '../customRouteRenderers';
import {
  BrainIcon,
  ShieldAlertIcon,
  ActivityIcon,
  ZapIcon,
  CheckCircleIcon,
  AlertTriangleIcon,
} from 'lucide-react';

const AICoachScreen = dynamic(
  () =>
    import('@/src/components/sdt/AICoachScreen').then((mod) => mod.AICoachScreen),
  { loading: () => <div className="p-4 text-gray-500">Loading MiloOS...</div> }
);

interface LearnerState {
  recentAiUseCount: number;
  recentCheckpointCount: number;
  hasVerificationGap: boolean;
  independentAttempts: number;
  autonomyRiskLevel: 'low' | 'medium' | 'high';
}

function computeLocalRiskLevel(state: LearnerState): 'low' | 'medium' | 'high' {
  const aiRatio =
    state.recentAiUseCount + state.recentCheckpointCount > 0
      ? state.recentAiUseCount / (state.recentAiUseCount + state.recentCheckpointCount)
      : 0;

  if (aiRatio > 0.6 || state.hasVerificationGap) return 'high';
  if (aiRatio > 0.3) return 'medium';
  return 'low';
}

export default function LearnerMiloOSRenderer({ ctx }: CustomRouteRendererProps) {
  const learnerId = ctx.uid;
  const siteId = ctx.profile?.siteIds?.[0] || '';
  const [learnerState, setLearnerState] = useState<LearnerState | null>(null);
  const [loading, setLoading] = useState(true);

  const loadState = useCallback(async () => {
    if (!learnerId) return;
    setLoading(true);
    try {
      // Load recent interaction events to compute local risk display
      const [aiSnap, checkpointSnap, explainSnap] = await Promise.all([
        getDocs(
          query(
            collection(firestore, 'aiInteractionLogs'),
            where('learnerId', '==', learnerId),
            orderBy('createdAt', 'desc'),
            limit(20)
          )
        ),
        getDocs(
          query(
            collection(firestore, 'checkpointHistory'),
            where('learnerId', '==', learnerId),
            where('status', '==', 'passed'),
            orderBy('createdAt', 'desc'),
            limit(20)
          )
        ),
        getDocs(
          query(
            collection(firestore, 'missionAttempts'),
            where('learnerId', '==', learnerId),
            orderBy('submittedAt', 'desc'),
            limit(10)
          )
        ),
      ]);

      const aiCount = aiSnap.size;
      const cpCount = checkpointSnap.size;
      const independentAttempts = explainSnap.size;

      // Check for verification gap: AI used but no explain-it-back
      const hasVerificationGap = aiCount > 2 && independentAttempts === 0;

      const state: LearnerState = {
        recentAiUseCount: aiCount,
        recentCheckpointCount: cpCount,
        hasVerificationGap,
        independentAttempts,
        autonomyRiskLevel: 'low',
      };
      state.autonomyRiskLevel = computeLocalRiskLevel(state);
      setLearnerState(state);
    } catch (err) {
      console.error('Failed to load learner state:', err);
    } finally {
      setLoading(false);
    }
  }, [learnerId]);

  useEffect(() => {
    loadState();
  }, [loadState]);

  const riskConfig = {
    low: {
      label: 'Independent Learner',
      color: 'bg-green-100 text-green-800 border-green-200',
      icon: <CheckCircleIcon className="h-4 w-4" />,
      message: 'You are showing strong independent learning. All AI modes are available.',
    },
    medium: {
      label: 'Building Independence',
      color: 'bg-amber-100 text-amber-800 border-amber-200',
      icon: <ActivityIcon className="h-4 w-4" />,
      message:
        'Try working on your own before asking MiloOS for help. You learn more by trying first!',
    },
    high: {
      label: 'Independence Check',
      color: 'bg-red-100 text-red-800 border-red-200',
      icon: <AlertTriangleIcon className="h-4 w-4" />,
      message:
        'MiloOS has noticed you may be relying heavily on AI help. Try an independent attempt first — you might surprise yourself!',
    },
  };

  return (
    <div className="space-y-4">
      {/* Header */}
      <div className="flex items-center gap-3">
        <BrainIcon className="h-7 w-7 text-indigo-600" />
        <div>
          <h2 className="text-xl font-bold text-gray-900">MiloOS Coach</h2>
          <p className="text-sm text-gray-500">
            Your AI learning companion — hints, rubric checks, and debugging help.
          </p>
        </div>
      </div>

      {/* Autonomy awareness banner */}
      {learnerState && !loading && (
        <div
          className={`flex items-start gap-3 rounded-lg border p-3 ${
            riskConfig[learnerState.autonomyRiskLevel].color
          }`}
        >
          {riskConfig[learnerState.autonomyRiskLevel].icon}
          <div>
            <p className="text-sm font-medium">
              {riskConfig[learnerState.autonomyRiskLevel].label}
            </p>
            <p className="text-xs mt-0.5">
              {riskConfig[learnerState.autonomyRiskLevel].message}
            </p>
          </div>
        </div>
      )}

      {/* Learning state summary */}
      {learnerState && !loading && (
        <div className="grid grid-cols-3 gap-3">
          <div className="bg-white border border-gray-200 rounded-lg p-3 text-center">
            <p className="text-lg font-bold text-indigo-600">{learnerState.independentAttempts}</p>
            <p className="text-xs text-gray-500">Independent attempts</p>
          </div>
          <div className="bg-white border border-gray-200 rounded-lg p-3 text-center">
            <p className="text-lg font-bold text-purple-600">{learnerState.recentAiUseCount}</p>
            <p className="text-xs text-gray-500">AI interactions</p>
          </div>
          <div className="bg-white border border-gray-200 rounded-lg p-3 text-center">
            <p className="text-lg font-bold text-green-600">{learnerState.recentCheckpointCount}</p>
            <p className="text-xs text-gray-500">Checkpoints passed</p>
          </div>
        </div>
      )}

      {/* AI Coach Screen */}
      <div className="bg-white border border-gray-200 rounded-lg p-4">
        <AICoachScreen learnerId={learnerId} siteId={siteId} />
      </div>
    </div>
  );
}
