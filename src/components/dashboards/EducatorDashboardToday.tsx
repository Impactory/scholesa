'use client';

import { useEffect, useState } from 'react';
import {
  getDocs,
  limit,
  orderBy,
  query,
  where,
} from 'firebase/firestore';
import { useAuthContext } from '@/src/firebase/auth/AuthProvider';
import {
  sessionsCollection,
  evidenceRecordsCollection,
  portfolioItemsCollection,
  capabilityMasteryCollection,
} from '@/src/firebase/firestore/collections';
import { Spinner } from '@/src/components/ui/Spinner';
import type { EvidenceRecord, CapabilityMastery, PillarCode } from '@/src/types/schema';

interface SessionInfo {
  id: string;
  title: string;
  description?: string;
  status?: string;
  learnerCount?: number;
}

interface ReviewQueueStats {
  pendingEvidence: number;
  pendingVerification: number;
}

interface PillarSnapshot {
  pillarCode: PillarCode;
  label: string;
  averageLevel: number;
  learnerCount: number;
}

const PILLAR_LABELS: Record<PillarCode, string> = {
  FUTURE_SKILLS: 'Future Skills',
  LEADERSHIP_AGENCY: 'Leadership & Agency',
  IMPACT_INNOVATION: 'Impact & Innovation',
};

export function EducatorDashboardToday() {
  const { user, profile, loading: authLoading } = useAuthContext();
  const siteId = profile?.studioId ?? profile?.activeSiteId ?? null;
  const educatorId = user?.uid ?? null;

  const [sessions, setSessions] = useState<SessionInfo[]>([]);
  const [reviewQueue, setReviewQueue] = useState<ReviewQueueStats>({ pendingEvidence: 0, pendingVerification: 0 });
  const [pillarSnapshots, setPillarSnapshots] = useState<PillarSnapshot[]>([]);
  const [recentEvidence, setRecentEvidence] = useState<EvidenceRecord[]>([]);
  const [loading, setLoading] = useState(false);
  const [loadError, setLoadError] = useState(false);

  useEffect(() => {
    if (!educatorId) return;
    let cancelled = false;

    async function load() {
      setLoading(true);
      try {
        // 1. Load educator's sessions
        const sessionsSnap = await getDocs(
          query(
            sessionsCollection,
            where('educatorIds', 'array-contains', educatorId),
            orderBy('startDate', 'asc'),
            limit(20),
          ),
        );
        const sessionList: SessionInfo[] = sessionsSnap.docs.map((d) => {
          const raw = d.data() as unknown as Record<string, unknown>;
          return {
            id: d.id,
            title: (raw.title ?? raw.name ?? 'Untitled Session') as string,
            description: (raw.description ?? '') as string,
            status: (raw.status ?? '') as string,
          };
        });

        // 2. Count pending evidence (needs rubric review)
        const pendingEvidenceConstraints = siteId
          ? [where('siteId', '==', siteId), where('rubricStatus', '==', 'pending'), limit(100)]
          : [where('rubricStatus', '==', 'pending'), limit(100)];
        const pendingEvidenceSnap = await getDocs(
          query(evidenceRecordsCollection, ...pendingEvidenceConstraints),
        );

        // 3. Count pending verification (portfolio items)
        const pendingVerifConstraints = siteId
          ? [where('siteId', '==', siteId), where('verificationStatus', '==', 'pending'), limit(100)]
          : [where('verificationStatus', '==', 'pending'), limit(100)];
        const pendingVerifSnap = await getDocs(
          query(portfolioItemsCollection, ...pendingVerifConstraints),
        );

        // 4. Load recent evidence (last 5) 
        const recentEvidenceConstraints = siteId
          ? [where('siteId', '==', siteId), orderBy('createdAt', 'desc'), limit(5)]
          : [orderBy('createdAt', 'desc'), limit(5)];
        const recentEvidenceSnap = await getDocs(
          query(evidenceRecordsCollection, ...recentEvidenceConstraints),
        );
        const recentList = recentEvidenceSnap.docs.map((d) => ({ ...d.data(), id: d.id }) as EvidenceRecord);

        // 5. Build class capability snapshot from mastery records
        const masteryConstraints = siteId
          ? [where('siteId', '==', siteId)]
          : [];
        const masterySnap = await getDocs(
          query(capabilityMasteryCollection, ...masteryConstraints),
        );
        const masteryList = masterySnap.docs.map((d) => d.data() as CapabilityMastery);

        const pillarMap = new Map<PillarCode, { levels: number[]; learnerIds: Set<string> }>();
        const MASTERY_SCORE: Record<string, number> = { emerging: 1, developing: 2, proficient: 3, advanced: 4 };
        for (const m of masteryList) {
          const pc = m.pillarCode as PillarCode | undefined;
          if (!pc) continue;
          const entry = pillarMap.get(pc) ?? { levels: [], learnerIds: new Set() };
          entry.levels.push(MASTERY_SCORE[m.latestLevel] ?? 0);
          entry.learnerIds.add(m.learnerId);
          pillarMap.set(pc, entry);
        }

        const snapshots: PillarSnapshot[] = (['FUTURE_SKILLS', 'LEADERSHIP_AGENCY', 'IMPACT_INNOVATION'] as PillarCode[]).map((pc) => {
          const data = pillarMap.get(pc);
          if (!data || data.levels.length === 0) {
            return { pillarCode: pc, label: PILLAR_LABELS[pc], averageLevel: 0, learnerCount: 0 };
          }
          const avg = data.levels.reduce((a, b) => a + b, 0) / data.levels.length;
          return {
            pillarCode: pc,
            label: PILLAR_LABELS[pc],
            averageLevel: Math.round(avg * 10) / 10,
            learnerCount: data.learnerIds.size,
          };
        });

        if (cancelled) return;
        setSessions(sessionList);
        setReviewQueue({
          pendingEvidence: pendingEvidenceSnap.size,
          pendingVerification: pendingVerifSnap.size,
        });
        setRecentEvidence(recentList);
        setPillarSnapshots(snapshots);
      } catch (err) {
        console.error('Failed to load educator dashboard', err);
        if (!cancelled) setLoadError(true);
      } finally {
        if (!cancelled) setLoading(false);
      }
    }

    void load();
    return () => { cancelled = true; };
  }, [educatorId, siteId]);

  if (authLoading) {
    return (
      <div className="flex items-center justify-center min-h-[300px]">
        <Spinner />
        <span className="ml-2 text-sm text-gray-500">Loading educator dashboard...</span>
      </div>
    );
  }

  if (!educatorId) {
    return (
      <div className="rounded-lg border border-gray-200 bg-white p-8 text-center text-sm text-gray-500">
        Please sign in to view your dashboard.
      </div>
    );
  }

  if (loadError) {
    return (
      <div className="rounded-lg border border-amber-200 bg-amber-50 p-8 text-center text-sm text-amber-700">
        Could not load dashboard data. Please refresh to try again.
      </div>
    );
  }

  const totalPending = reviewQueue.pendingEvidence + reviewQueue.pendingVerification;

  return (
    <div className="space-y-6 max-w-4xl mx-auto" data-testid="educator-dashboard-today">
      {/* Header */}
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Educator Dashboard</h1>
        <p className="mt-1 text-sm text-gray-500">
          Your sessions, review queue, and class capability snapshot.
        </p>
      </div>

      {/* Review Queue Alert */}
      {totalPending > 0 && (
        <div className="rounded-lg border border-amber-200 bg-amber-50 p-4">
          <h2 className="text-sm font-semibold text-amber-800">Review Queue</h2>
          <div className="mt-2 flex gap-6 text-sm">
            {reviewQueue.pendingEvidence > 0 && (
              <div>
                <span className="text-2xl font-bold text-amber-700">{reviewQueue.pendingEvidence}</span>
                <span className="ml-1 text-amber-600">evidence items awaiting rubric</span>
              </div>
            )}
            {reviewQueue.pendingVerification > 0 && (
              <div>
                <span className="text-2xl font-bold text-amber-700">{reviewQueue.pendingVerification}</span>
                <span className="ml-1 text-amber-600">portfolio items pending verification</span>
              </div>
            )}
          </div>
        </div>
      )}
      {totalPending === 0 && (
        <div className="rounded-lg border border-green-200 bg-green-50 p-4 text-sm text-green-700">
          All caught up — no pending evidence reviews or verification tasks.
        </div>
      )}

      {/* Today's Sessions */}
      <section>
        <h2 className="text-lg font-semibold text-gray-900 mb-3">Your Sessions</h2>
        {sessions.length === 0 ? (
          <div className="rounded-lg border border-gray-200 bg-gray-50 p-4 text-sm text-gray-500">
            No sessions assigned.
          </div>
        ) : (
          <div className="grid gap-3 sm:grid-cols-2">
            {sessions.map((s) => (
              <div key={s.id} className="rounded-lg border border-gray-200 bg-white p-4 shadow-sm">
                <h3 className="text-sm font-semibold text-gray-900">{s.title}</h3>
                {s.description && (
                  <p className="mt-1 text-xs text-gray-500 line-clamp-2">{s.description}</p>
                )}
                {s.status && (
                  <span className="mt-2 inline-block rounded-full bg-blue-50 px-2 py-0.5 text-xs text-blue-700">
                    {s.status}
                  </span>
                )}
              </div>
            ))}
          </div>
        )}
      </section>

      {/* Class Capability Snapshot */}
      <section>
        <h2 className="text-lg font-semibold text-gray-900 mb-3">Class Capability Snapshot</h2>
        <div className="grid gap-3 sm:grid-cols-3">
          {pillarSnapshots.map((ps) => {
            const pct = Math.round((ps.averageLevel / 4) * 100);
            const barColor = pct >= 75 ? 'bg-green-500' : pct >= 45 ? 'bg-blue-500' : pct > 0 ? 'bg-amber-400' : 'bg-gray-300';
            return (
              <div key={ps.pillarCode} className="rounded-lg border border-gray-200 bg-white p-4">
                <h3 className="text-xs font-semibold text-gray-700 uppercase tracking-wide">{ps.label}</h3>
                <div className="mt-2 w-full bg-gray-100 rounded-full h-2">
                  <div className={`h-2 rounded-full transition-all ${barColor}`} style={{ width: `${pct}%` }} />
                </div>
                <div className="mt-1 flex justify-between text-xs text-gray-500">
                  <span>Avg {ps.averageLevel}/4</span>
                  <span>{ps.learnerCount} learners</span>
                </div>
              </div>
            );
          })}
        </div>
      </section>

      {/* Recent Evidence */}
      <section>
        <h2 className="text-lg font-semibold text-gray-900 mb-3">Recent Evidence</h2>
        {recentEvidence.length === 0 ? (
          <div className="rounded-lg border border-gray-200 bg-gray-50 p-4 text-sm text-gray-500">
            No evidence recorded yet.
          </div>
        ) : (
          <div className="space-y-2">
            {recentEvidence.map((e) => (
              <div key={e.id} className="rounded-lg border border-gray-100 bg-white p-3 flex items-center justify-between">
                <div>
                  <span className="text-sm font-medium text-gray-900 line-clamp-1">{e.description || 'Evidence observation'}</span>
                  <div className="mt-0.5 flex gap-2 text-xs text-gray-500">
                    <span>Learner: {e.learnerId.slice(0, 8)}...</span>
                    {e.phaseKey && <span>Phase: {e.phaseKey.replace(/_/g, ' ')}</span>}
                  </div>
                </div>
                <span className={`rounded-full px-2 py-0.5 text-xs font-medium ${
                  e.rubricStatus === 'applied'
                    ? 'bg-green-50 text-green-700'
                    : e.rubricStatus === 'pending'
                    ? 'bg-amber-50 text-amber-700'
                    : 'bg-gray-50 text-gray-500'
                }`}>
                  {e.rubricStatus}
                </span>
              </div>
            ))}
          </div>
        )}
      </section>
    </div>
  );
}
