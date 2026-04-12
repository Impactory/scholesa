'use client';

import { useEffect, useState } from 'react';
import {
  collection,
  documentId,
  getDocs,
  limit,
  orderBy,
  query,
  where,
} from 'firebase/firestore';
import { firestore } from '@/src/firebase/client-init';
import { useAuthContext } from '@/src/firebase/auth/AuthProvider';
import {
  capabilityGrowthEventsCollection,
  missionAttemptsCollection,
} from '@/src/firebase/firestore/collections';
import { CapabilityGuidancePanel } from '@/src/components/analytics/CapabilityGuidancePanel';
import { useCapabilities } from '@/src/lib/capabilities/useCapabilities';
import { Spinner } from '@/src/components/ui/Spinner';
import type { CapabilityGrowthEvent } from '@/src/types/schema';

interface SessionInfo {
  id: string;
  title: string;
  description?: string;
  status?: string;
}

interface MissionAttemptInfo {
  id: string;
  missionTitle?: string;
  status?: string;
  completedAt?: string | null;
}

const isE2ETestMode = process.env.NEXT_PUBLIC_E2E_TEST_MODE === '1';

export function LearnerDashboardToday() {
  const { user, profile, loading: authLoading } = useAuthContext();
  const siteId = profile?.studioId ?? profile?.activeSiteId ?? null;
  const learnerId = user?.uid ?? null;

  const [sessions, setSessions] = useState<SessionInfo[]>([]);
  const [recentGrowth, setRecentGrowth] = useState<CapabilityGrowthEvent[]>([]);
  const [activeMissions, setActiveMissions] = useState<MissionAttemptInfo[]>([]);
  const [loading, setLoading] = useState(!isE2ETestMode);
  const [loadError, setLoadError] = useState(false);
  const { resolveTitle, loading: capLoading } = useCapabilities(isE2ETestMode ? null : siteId);

  useEffect(() => {
    if (isE2ETestMode) return; // E2E: skip Firestore queries; render with empty state
    if (!learnerId) return;
    let cancelled = false;

    async function load() {
      setLoading(true);
      try {
        // 1. Load enrolled sessions
        const enrollmentsSnap = await getDocs(
          query(
            collection(firestore, 'enrollments'),
            where('learnerId', '==', learnerId),
            where('status', '==', 'active'),
            limit(25),
          ),
        );
        const sessionIds = enrollmentsSnap.docs
          .map((d) => d.data().sessionId)
          .filter((v): v is string => typeof v === 'string' && v.trim().length > 0)
          .slice(0, 10);

        let sessionList: SessionInfo[] = [];
        if (sessionIds.length > 0) {
          const sessionsSnap = await getDocs(
            query(collection(firestore, 'sessions'), where(documentId(), 'in', sessionIds)),
          );
          sessionList = sessionsSnap.docs.map((d) => {
            const data = d.data() as Record<string, unknown>;
            return {
              id: d.id,
              title: (data.title ?? data.name ?? 'Untitled Session') as string,
              description: (data.description ?? '') as string,
              status: (data.status ?? '') as string,
            };
          });
        }

        // 2. Load recent growth events (last 10)
        const growthSnap = await getDocs(
          query(
            capabilityGrowthEventsCollection,
            where('learnerId', '==', learnerId),
            orderBy('createdAt', 'desc'),
            limit(10),
          ),
        );
        const growthList = growthSnap.docs.map((d) => ({ ...d.data(), id: d.id }) as CapabilityGrowthEvent);

        // 3. Load active mission attempts
        const missionsSnap = await getDocs(
          query(
            missionAttemptsCollection,
            where('learnerId', '==', learnerId),
            where('status', '==', 'in_progress'),
            limit(10),
          ),
        );
        const missionList = missionsSnap.docs.map((d) => {
          const data = d.data() as Record<string, unknown>;
          return {
            id: d.id,
            missionTitle: (data.missionTitle ?? data.title ?? 'Mission') as string,
            status: (data.status ?? '') as string,
            completedAt: null,
          } as MissionAttemptInfo;
        });

        if (cancelled) return;
        setSessions(sessionList);
        setRecentGrowth(growthList);
        setActiveMissions(missionList);
      } catch (err) {
        console.error('Failed to load learner dashboard', err);
        if (!cancelled) setLoadError(true);
      } finally {
        if (!cancelled) setLoading(false);
      }
    }

    void load();
    return () => { cancelled = true; };
  }, [learnerId]);

  if (authLoading || loading || capLoading) {
    return (
      <div className="flex items-center justify-center min-h-[300px]">
        <Spinner />
        <span className="ml-2 text-sm text-gray-500">Loading your dashboard...</span>
      </div>
    );
  }

  if (!learnerId || !siteId) {
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

  const LEVEL_LABELS: Record<string, string> = {
    '1': 'Beginning', '2': 'Developing', '3': 'Proficient', '4': 'Advanced',
    emerging: 'Beginning', developing: 'Developing', proficient: 'Proficient', advanced: 'Advanced',
  };

  return (
    <div className="space-y-6 max-w-4xl mx-auto" data-testid="learner-dashboard-today">
      {/* Page header */}
      <div>
        <h1 className="text-2xl font-bold text-gray-900">My Progress</h1>
        <p className="mt-1 text-sm text-gray-500">
          Your capability growth, active sessions, and current missions.
        </p>
      </div>

      {/* Capability Growth Panel */}
      <CapabilityGuidancePanel learnerId={learnerId} siteId={siteId} />

      {/* Today's Sessions */}
      <section>
        <h2 className="text-lg font-semibold text-gray-900 mb-3">Active Sessions</h2>
        {sessions.length === 0 ? (
          <div className="rounded-lg border border-gray-200 bg-gray-50 p-4 text-sm text-gray-500">
            No active sessions right now. Check back soon!
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

      {/* Recent Capability Growth */}
      <section>
        <h2 className="text-lg font-semibold text-gray-900 mb-3">Recent Growth</h2>
        {recentGrowth.length === 0 ? (
          <div className="rounded-lg border border-gray-200 bg-gray-50 p-4 text-sm text-gray-500">
            No capability growth events yet. Submit evidence and complete checkpoints to build your record!
          </div>
        ) : (
          <div className="space-y-2">
            {recentGrowth.map((g) => {
              const capTitle = resolveTitle(g.capabilityId) || g.capabilityId;
              return (
                <div key={g.id} className="rounded-lg border border-gray-100 bg-white p-3 flex items-center justify-between">
                  <div>
                    <span className="text-sm font-medium text-gray-900">{capTitle}</span>
                    <span className="ml-2 text-xs text-gray-500">
                      {g.level} — {LEVEL_LABELS[g.level] ?? g.level}
                    </span>
                  </div>
                  <div className="text-right">
                    <span className="text-xs text-gray-400">
                      {g.rawScore}/{g.maxScore} score
                    </span>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </section>

      {/* Active Missions */}
      <section>
        <h2 className="text-lg font-semibold text-gray-900 mb-3">Active Missions</h2>
        {activeMissions.length === 0 ? (
          <div className="rounded-lg border border-gray-200 bg-gray-50 p-4 text-sm text-gray-500">
            No active missions. Ask your educator about upcoming challenges!
          </div>
        ) : (
          <div className="space-y-2">
            {activeMissions.map((m) => (
              <div key={m.id} className="rounded-lg border border-gray-100 bg-white p-3 flex items-center justify-between">
                <span className="text-sm font-medium text-gray-900">{m.missionTitle}</span>
                <span className="inline-block rounded-full bg-amber-50 px-2 py-0.5 text-xs text-amber-700">
                  In Progress
                </span>
              </div>
            ))}
          </div>
        )}
      </section>
    </div>
  );
}
