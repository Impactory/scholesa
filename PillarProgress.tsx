'use client';

import React from 'react';
import { useAuthContext } from '@/src/firebase/auth/AuthProvider';
import { useCollection } from 'react-firebase-hooks/firestore';
import { query, where, limit, orderBy } from 'firebase/firestore';
import { accountabilityKPIsCollection } from '@/src/firebase/firestore/collections';
import { PillarCode } from '@/src/types/schema';

const PILLAR_LABELS: Record<PillarCode, string> = {
  FUTURE_SKILLS: 'Future Skills',
  LEADERSHIP_AGENCY: 'Leadership & Agency',
  IMPACT_INNOVATION: 'Impact & Innovation',
};

export function PillarProgress() {
  const { user } = useAuthContext();

  // Fetch latest KPI
  const [kpiSnap, loading] = useCollection(
    user ? query(accountabilityKPIsCollection, where('learnerId', '==', user.uid), limit(1)) : null
  );

  if (loading) return <div className="h-32 animate-pulse bg-gray-100 rounded-xl" />;

  const kpi = kpiSnap?.docs[0]?.data();
  
  // Default scores if no KPI exists yet
  const scores = kpi?.pillarScores || {
    FUTURE_SKILLS: 0,
    LEADERSHIP_AGENCY: 0,
    IMPACT_INNOVATION: 0,
  };

  return (
    <div className="grid gap-4 sm:grid-cols-3">
      {(Object.keys(PILLAR_LABELS) as PillarCode[]).map((code) => (
        <div key={code} className="rounded-xl border border-gray-200 bg-white p-4 shadow-sm">
          <dt className="truncate text-sm font-medium text-gray-500">{PILLAR_LABELS[code]}</dt>
          <dd className="mt-2 flex items-baseline">
            <span className="text-3xl font-semibold text-gray-900">{scores[code]}</span>
            <span className="ml-2 text-sm text-gray-400">/ 100</span>
          </dd>
          <div className="mt-2 h-2 w-full overflow-hidden rounded-full bg-gray-100">
            <div 
              className="h-full bg-indigo-600 transition-all duration-500" 
              style={{ width: `${Math.min(scores[code], 100)}%` }} 
            />
          </div>
        </div>
      ))}
    </div>
  );
}