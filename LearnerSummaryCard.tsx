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

  const scores = kpi?.pillarScores || {
    FUTURE_SKILLS: 0,
    LEADERSHIP_AGENCY: 0,
    IMPACT_INNOVATION: 0,
  };

  return (
    <div className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
      <div className="flex items-center gap-4 mb-6">
        <div className="h-12 w-12 rounded-full bg-indigo-100 flex items-center justify-center text-indigo-700 font-bold text-lg">
          {learner.displayName?.slice(0, 2).toUpperCase()}
        </div>
        <div>
          <h3 className="text-lg font-bold text-gray-900">{learner.displayName}</h3>
          <p className="text-sm text-gray-500">{learner.email}</p>
        </div>
      </div>

      <div className="grid gap-6 md:grid-cols-2">
        {/* Stats */}
        <div className="space-y-4">
          <div>
            <p className="text-sm font-medium text-gray-500">Attendance</p>
            <p className="text-2xl font-semibold text-gray-900">{kpi?.attendancePct ?? 0}%</p>
          </div>
          <div>
            <p className="text-sm font-medium text-gray-500">Missions Completed</p>
            <p className="text-2xl font-semibold text-gray-900">{kpi?.missionsCompleted ?? 0}</p>
          </div>
        </div>

        {/* Pillars */}
        <div className="space-y-3">
          {(Object.keys(PILLAR_LABELS) as PillarCode[]).map((code) => (
            <div key={code}>
              <div className="flex justify-between text-xs mb-1">
                <span className="font-medium text-gray-600">{PILLAR_LABELS[code]}</span>
                <span className="text-gray-900">{scores[code]}/100</span>
              </div>
              <div className="h-1.5 w-full overflow-hidden rounded-full bg-gray-100">
                <div 
                  className="h-full bg-indigo-500" 
                  style={{ width: `${Math.min(scores[code], 100)}%` }} 
                />
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}