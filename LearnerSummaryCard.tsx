'use client';

import React from 'react';
import { useDocument, useCollection } from 'react-firebase-hooks/firestore';
import { doc, query, where, limit } from 'firebase/firestore';
import { usersCollection, accountabilityKPIsCollection } from '@/src/firebase/firestore/collections';
import { PillarCode } from '@/src/types/schema';

const PILLAR_LABELS: Record<PillarCode, string> = {
  FUTURE_SKILLS: 'Future Skills',
  LEADERSHIP_AGENCY: 'Leadership & Agency',
  IMPACT_INNOVATION: 'Impact & Innovation',
};

type PillarScores = Partial<Record<PillarCode, number>>;

function formatMetric(value: unknown, suffix = ''): string {
  return typeof value === 'number' && Number.isFinite(value)
    ? `${value}${suffix}`
    : 'No evidence yet';
}

export function LearnerSummaryCard({ learnerId }: { learnerId: string }) {
  // 1. Fetch Learner Profile
  const [userSnap, loadingUser] = useDocument(doc(usersCollection, learnerId));
  
  // 2. Fetch Latest KPI (Assuming one active cycle for MVP)
  const [kpiSnap, loadingKpi] = useCollection(
    query(
      accountabilityKPIsCollection, 
      where('learnerId', '==', learnerId), 
      limit(1)
    )
  );

  if (loadingUser || loadingKpi) return <div className="h-48 animate-pulse rounded-lg bg-gray-100" />;

  const learner = userSnap?.data();
  const kpi = kpiSnap?.docs[0]?.data();

  if (!learner) return <div className="rounded-lg border border-red-200 bg-red-50 p-4 text-red-700">Learner not found</div>;

  const scores = (kpi?.pillarScores as PillarScores | undefined) ?? {};
  const displayName = typeof learner.displayName === 'string' && learner.displayName.trim().length > 0
    ? learner.displayName
    : 'Learner unavailable';
  const avatarLabel = displayName.slice(0, 2).toUpperCase();

  return (
    <div className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
      <div className="flex items-center gap-4 mb-6">
        <div className="h-12 w-12 rounded-full bg-indigo-100 flex items-center justify-center text-indigo-700 font-bold text-lg">
          {avatarLabel}
        </div>
        <div>
          <h3 className="text-lg font-bold text-gray-900">{displayName}</h3>
          <p className="text-sm text-gray-500">{learner.email}</p>
        </div>
      </div>

      <div className="grid gap-6 md:grid-cols-2">
        {/* Stats */}
        <div className="space-y-4">
          <div>
            <p className="text-sm font-medium text-gray-500">Attendance</p>
            <p className="text-2xl font-semibold text-gray-900">{formatMetric(kpi?.attendancePct, '%')}</p>
          </div>
          <div>
            <p className="text-sm font-medium text-gray-500">Missions Completed</p>
            <p className="text-2xl font-semibold text-gray-900">{formatMetric(kpi?.missionsCompleted)}</p>
          </div>
        </div>

        {/* Pillars */}
        <div className="space-y-3">
          {(Object.keys(PILLAR_LABELS) as PillarCode[]).map((code) => (
            <div key={code}>
              {(() => {
                const score = typeof scores[code] === 'number' && Number.isFinite(scores[code])
                  ? scores[code] as number
                  : null;
                return (
                  <>
              <div className="flex justify-between text-xs mb-1">
                <span className="font-medium text-gray-600">{PILLAR_LABELS[code]}</span>
                <span className="text-gray-900">{score != null ? `${score}/100` : 'No evidence yet'}</span>
              </div>
              <div className="h-1.5 w-full overflow-hidden rounded-full bg-gray-100">
                <div 
                  className="h-full bg-indigo-500" 
                  style={{ width: `${score != null ? Math.min(score, 100) : 0}%` }} 
                />
              </div>
                  </>
                );
              })()}
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}