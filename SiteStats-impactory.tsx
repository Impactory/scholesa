'use client';

import React from 'react';
import { useAuthContext } from '@/src/firebase/auth/AuthProvider';
import { AccountabilityCycle, AccountabilityKPI, UserProfile, PillarCode } from '@/src/types/schema';
import { useCollection } from 'react-firebase-hooks/firestore';
import { query, where, orderBy, limit } from 'firebase/firestore';
import { accountabilityCyclesCollection, accountabilityKPIsCollection } from '@/src/firebase/firestore/collections';

const PILLAR_LABELS: Record<PillarCode, string> = {
  FUTURE_SKILLS: 'Future Skills',
  LEADERSHIP_AGENCY: 'Leadership & Agency',
  IMPACT_INNOVATION: 'Impact & Innovation',
};

export function SiteStats() {
  const { profile } = useAuthContext();
  const siteId = (profile as UserProfile)?.studioId;

  // 1. Fetch Latest Cycle for Site
  // Note: This query requires a composite index on [siteId, endDate]. 
  // If it fails in dev, check the console for the index creation link.
  const [cyclesSnap, loadingCycles] = useCollection(
    siteId 
      ? query(accountabilityCyclesCollection, where('siteId', '==', siteId), orderBy('endDate', 'desc'), limit(1))
      : null
  );

  const currentCycle = cyclesSnap?.docs[0];
  const cycleId = currentCycle?.id;

  // 2. Fetch KPIs for that Cycle
  const [kpisSnap, loadingKpis] = useCollection(
    cycleId 
      ? query(accountabilityKPIsCollection, where('cycleId', '==', cycleId))
      : null
  );

  if (!siteId) return <div>No site assigned to this user.</div>;
  if (loadingCycles || loadingKpis) return <div className="h-64 animate-pulse rounded-xl bg-gray-100" />;
  if (!currentCycle) return <div>No active accountability cycles found for this site.</div>;

  const kpis = kpisSnap?.docs.map(d => d.data()) || [];
  const learnerCount = kpis.length;

  if (learnerCount === 0) return <div>No data available for the current cycle ({currentCycle.data().name}).</div>;

  // Aggregation
  const avgAttendance = Math.round(kpis.reduce((acc, k) => acc + k.attendancePct, 0) / learnerCount);
  const totalMissions = kpis.reduce((acc, k) => acc + k.missionsCompleted, 0);
  
  const avgPillars: Record<PillarCode, number> = {
    FUTURE_SKILLS: 0,
    LEADERSHIP_AGENCY: 0,
    IMPACT_INNOVATION: 0,
  };

  kpis.forEach(k => {
    (Object.keys(avgPillars) as PillarCode[]).forEach(p => {
      avgPillars[p] += (k.pillarScores[p] || 0);
    });
  });

  (Object.keys(avgPillars) as PillarCode[]).forEach(p => {
    avgPillars[p] = Math.round(avgPillars[p] / learnerCount);
  });

  return (
    <div className="space-y-6">
      <div className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
        <h2 className="text-lg font-semibold text-gray-900 mb-4">Site Overview: {currentCycle.data().name}</h2>
        <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-4">
          <StatCard label="Active Learners" value={learnerCount} />
          <StatCard label="Avg Attendance" value={`${avgAttendance}%`} />
          <StatCard label="Total Missions" value={totalMissions} />
          <StatCard label="Avg Future Skills" value={avgPillars.FUTURE_SKILLS} />
        </div>
      </div>

      <div className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
        <h3 className="text-md font-semibold text-gray-900 mb-4">Pillar Performance</h3>
        <div className="space-y-4">
           {(Object.keys(PILLAR_LABELS) as PillarCode[]).map(code => (
             <div key={code}>
               <div className="flex justify-between text-sm mb-1">
                 <span className="text-gray-600">{PILLAR_LABELS[code]}</span>
                 <span className="font-medium text-gray-900">{avgPillars[code]} / 100</span>
               </div>
               <div className="h-2 w-full overflow-hidden rounded-full bg-gray-100">
                 <div className="h-full bg-indigo-600" style={{ width: `${avgPillars[code]}%` }} />
               </div>
             </div>
           ))}
        </div>
      </div>
    </div>
  );
}

function StatCard({ label, value }: { label: string, value: string | number }) {
  return (
    <div className="rounded-lg bg-gray-50 p-4">
      <p className="text-sm font-medium text-gray-500">{label}</p>
      <p className="mt-1 text-2xl font-semibold text-gray-900">{value}</p>
    </div>
  );
}