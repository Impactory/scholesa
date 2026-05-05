'use client';

import React, { useCallback, useEffect, useState } from 'react';
import {
  collection,
  doc,
  getDocs,
  orderBy,
  query,
  serverTimestamp,
  updateDoc,
  where,
} from 'firebase/firestore';
import { firestore } from '@/src/firebase/client-init';
import { Spinner } from '@/src/components/ui/Spinner';
import { useInteractionTracking } from '@/src/hooks/useTelemetry';
import type { CustomRouteRendererProps } from '../customRouteRenderers';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface SessionRow {
  id: string;
  title: string;
  description: string;
  status: string;
  startDate: string | null;
  endDate: string | null;
  siteId: string;
  evidenceCount: number;
  checkpointCount: number;
  learnerCount: number;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function toIso(value: unknown): string | null {
  if (
    value &&
    typeof value === 'object' &&
    'toDate' in value &&
    typeof (value as { toDate: () => Date }).toDate === 'function'
  ) {
    return (value as { toDate: () => Date }).toDate().toISOString();
  }
  if (typeof value === 'string') return value;
  return null;
}

function asString(value: unknown, fallback: string): string {
  return typeof value === 'string' && value.trim().length > 0 ? value.trim() : fallback;
}

function formatDate(iso: string | null): string {
  if (!iso) return '';
  try {
    return new Date(iso).toLocaleDateString(undefined, {
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  } catch {
    return iso;
  }
}

function statusColor(status: string): string {
  switch (status) {
    case 'in_progress':
      return 'bg-green-100 text-green-800';
    case 'completed':
      return 'bg-blue-100 text-blue-800';
    case 'scheduled':
      return 'bg-yellow-100 text-yellow-800';
    case 'cancelled':
      return 'bg-red-100 text-red-800';
    default:
      return 'bg-gray-100 text-gray-800';
  }
}

function statusLabel(status: string): string {
  switch (status) {
    case 'in_progress':
      return 'In Progress';
    case 'completed':
      return 'Completed';
    case 'scheduled':
      return 'Scheduled';
    case 'cancelled':
      return 'Cancelled';
    default:
      return status;
  }
}

function sessionCoverageRowsFromRecords(params: {
  sessions: Record<string, unknown>[];
  evidenceRecords: Record<string, unknown>[];
  checkpointHistory: Record<string, unknown>[];
  siteId: string;
}): SessionRow[] {
  const sessionIds = params.sessions
    .filter((session) => session.siteId === params.siteId)
    .map((session) => String(session.id));
  const evidenceCounts = new Map<string, number>();
  const checkpointCounts = new Map<string, number>();
  const learnerSets = new Map<string, Set<string>>();

  params.evidenceRecords
    .filter((record) => record.siteId === params.siteId)
    .forEach((record) => {
      const sid = record.sessionId || record.sessionOccurrenceId;
      if (typeof sid === 'string' && sessionIds.includes(sid)) {
        evidenceCounts.set(sid, (evidenceCounts.get(sid) || 0) + 1);
        if (typeof record.learnerId === 'string') {
          const set = learnerSets.get(sid) || new Set<string>();
          set.add(record.learnerId);
          learnerSets.set(sid, set);
        }
      }
    });

  params.checkpointHistory
    .filter((record) => record.siteId === params.siteId)
    .forEach((record) => {
      const sid = record.sprintSessionId;
      if (typeof sid === 'string' && sessionIds.includes(sid)) {
        checkpointCounts.set(sid, (checkpointCounts.get(sid) || 0) + 1);
        if (typeof record.learnerId === 'string') {
          const set = learnerSets.get(sid) || new Set<string>();
          set.add(record.learnerId);
          learnerSets.set(sid, set);
        }
      }
    });

  return params.sessions
    .filter((session) => session.siteId === params.siteId)
    .map((session) => {
      const id = String(session.id);
      return {
        id,
        title: asString(session.title || session.name, 'Untitled Session'),
        description: asString(session.description, ''),
        status: asString(session.status, 'scheduled'),
        startDate: toIso(session.startDate || session.startTime),
        endDate: toIso(session.endDate || session.endTime),
        siteId: asString(session.siteId, ''),
        evidenceCount: evidenceCounts.get(id) || 0,
        checkpointCount: checkpointCounts.get(id) || 0,
        learnerCount: learnerSets.get(id)?.size || 0,
      };
    });
}

// ---------------------------------------------------------------------------
// Main Component
// ---------------------------------------------------------------------------

export default function EducatorSessionsRenderer({ ctx }: CustomRouteRendererProps) {
  const [sessions, setSessions] = useState<SessionRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [expandedId, setExpandedId] = useState<string | null>(null);
  const [actionLoading, setActionLoading] = useState<string | null>(null);
  const trackInteraction = useInteractionTracking();

  const siteId = ctx.profile?.siteIds?.[0] ?? ctx.profile?.studioId ?? null;

  const loadSessions = useCallback(async () => {
    if (!siteId) {
      setSessions([]);
      setLoading(false);
      return;
    }
    setLoading(true);
    setError(null);
    try {
      if (process.env.NEXT_PUBLIC_E2E_TEST_MODE === '1') {
        const { getE2ECollection } = await import('@/src/testing/e2e/fakeWebBackend');
        setSessions(sessionCoverageRowsFromRecords({
          sessions: getE2ECollection('sessions'),
          evidenceRecords: getE2ECollection('evidenceRecords'),
          checkpointHistory: getE2ECollection('checkpointHistory'),
          siteId,
        }));
        return;
      }

      const sessionsQuery = query(
        collection(firestore, 'sessions'),
        where('siteId', '==', siteId),
        orderBy('startDate', 'desc')
      );
      const snap = await getDocs(sessionsQuery);
      const sessionIds = snap.docs.map((d) => d.id);

      // Batch-load evidence and checkpoint counts for these sessions
      const evidenceCounts = new Map<string, number>();
      const checkpointCounts = new Map<string, number>();
      const learnerSets = new Map<string, Set<string>>();

      if (sessionIds.length > 0) {
        // Evidence records linked to sessions
        const evidenceQuery = query(
          collection(firestore, 'evidenceRecords'),
          where('siteId', '==', siteId)
        );
        const evidenceSnap = await getDocs(evidenceQuery);
        for (const d of evidenceSnap.docs) {
          const data = d.data();
          const sid = data.sessionId || data.sessionOccurrenceId;
          if (typeof sid === 'string' && sessionIds.includes(sid)) {
            evidenceCounts.set(sid, (evidenceCounts.get(sid) || 0) + 1);
            if (typeof data.learnerId === 'string') {
              const set = learnerSets.get(sid) || new Set();
              set.add(data.learnerId);
              learnerSets.set(sid, set);
            }
          }
        }

        // Checkpoints linked to sessions
        const checkpointQuery = query(
          collection(firestore, 'checkpointHistory'),
          where('siteId', '==', siteId)
        );
        const checkpointSnap = await getDocs(checkpointQuery);
        for (const d of checkpointSnap.docs) {
          const data = d.data();
          const sid = data.sprintSessionId;
          if (typeof sid === 'string' && sessionIds.includes(sid)) {
            checkpointCounts.set(sid, (checkpointCounts.get(sid) || 0) + 1);
            if (typeof data.learnerId === 'string') {
              const set = learnerSets.get(sid) || new Set();
              set.add(data.learnerId);
              learnerSets.set(sid, set);
            }
          }
        }
      }

      const rows: SessionRow[] = snap.docs.map((d) => {
        const data = d.data();
        return {
          id: d.id,
          title: asString(data.title || data.name, 'Untitled Session'),
          description: asString(data.description, ''),
          status: asString(data.status, 'scheduled'),
          startDate: toIso(data.startDate || data.startTime),
          endDate: toIso(data.endDate || data.endTime),
          siteId: asString(data.siteId, ''),
          evidenceCount: evidenceCounts.get(d.id) || 0,
          checkpointCount: checkpointCounts.get(d.id) || 0,
          learnerCount: learnerSets.get(d.id)?.size || 0,
        };
      });

      setSessions(rows);
    } catch (err) {
      console.error('Failed to load sessions:', err);
      setError('Failed to load sessions.');
    } finally {
      setLoading(false);
    }
  }, [siteId]);

  useEffect(() => {
    void loadSessions();
  }, [loadSessions]);

  const handleStatusChange = useCallback(
    async (sessionId: string, newStatus: string) => {
      setActionLoading(sessionId);
      try {
        const ref = doc(firestore, 'sessions', sessionId);
        await updateDoc(ref, {
          status: newStatus,
          ...(newStatus === 'completed' ? { endTime: serverTimestamp() } : {}),
          ...(newStatus === 'in_progress' ? { startTime: serverTimestamp() } : {}),
          updatedAt: serverTimestamp(),
        });
        trackInteraction('feature_discovered', {
          feature: 'session_status_change',
          sessionId,
          newStatus,
        });
        setSessions((prev) =>
          prev.map((s) => (s.id === sessionId ? { ...s, status: newStatus } : s))
        );
      } catch (err) {
        console.error('Failed to update session status:', err);
        setError('Failed to update session.');
      } finally {
        setActionLoading(null);
      }
    },
    [trackInteraction]
  );

  // ---- Render ----

  if (loading) {
    return (
      <div className="flex items-center justify-center py-16">
        <Spinner />
      </div>
    );
  }

  if (error) {
    return (
      <div className="rounded-lg border border-red-200 bg-red-50 p-4 text-sm text-red-700">
        {error}
      </div>
    );
  }

  // Separate sessions by status
  const activeSessions = sessions.filter((s) => s.status === 'in_progress');
  const upcomingSessions = sessions.filter((s) => s.status === 'scheduled');
  const pastSessions = sessions.filter(
    (s) => s.status === 'completed' || s.status === 'cancelled'
  );

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-bold text-app-foreground">Sessions</h1>
        <button
          onClick={() => void loadSessions()}
          className="rounded-md border border-app px-3 py-1.5 text-xs font-medium text-app-muted hover:bg-app-canvas"
        >
          Refresh
        </button>
      </div>

      {sessions.length === 0 ? (
        <div className="rounded-lg border border-dashed border-app p-8 text-center text-app-muted">
          <p className="text-sm">No sessions found for this site.</p>
          <p className="mt-1 text-xs">
            Sessions are created from the generic session management page or via the API.
          </p>
        </div>
      ) : (
        <>
          {/* Active Sessions */}
          {activeSessions.length > 0 && (
            <section>
              <h2 className="mb-3 text-sm font-semibold text-green-700">
                Active Sessions ({activeSessions.length})
              </h2>
              <div className="space-y-2">
                {activeSessions.map((s) => (
                  <SessionCard
                    key={s.id}
                    session={s}
                    expanded={expandedId === s.id}
                    onToggle={() => setExpandedId(expandedId === s.id ? null : s.id)}
                    onStatusChange={handleStatusChange}
                    actionLoading={actionLoading === s.id}
                  />
                ))}
              </div>
            </section>
          )}

          {/* Upcoming Sessions */}
          {upcomingSessions.length > 0 && (
            <section>
              <h2 className="mb-3 text-sm font-semibold text-yellow-700">
                Upcoming ({upcomingSessions.length})
              </h2>
              <div className="space-y-2">
                {upcomingSessions.map((s) => (
                  <SessionCard
                    key={s.id}
                    session={s}
                    expanded={expandedId === s.id}
                    onToggle={() => setExpandedId(expandedId === s.id ? null : s.id)}
                    onStatusChange={handleStatusChange}
                    actionLoading={actionLoading === s.id}
                  />
                ))}
              </div>
            </section>
          )}

          {/* Past Sessions */}
          {pastSessions.length > 0 && (
            <section>
              <h2 className="mb-3 text-sm font-semibold text-app-muted">
                Completed ({pastSessions.length})
              </h2>
              <div className="space-y-2">
                {pastSessions.map((s) => (
                  <SessionCard
                    key={s.id}
                    session={s}
                    expanded={expandedId === s.id}
                    onToggle={() => setExpandedId(expandedId === s.id ? null : s.id)}
                    onStatusChange={handleStatusChange}
                    actionLoading={actionLoading === s.id}
                  />
                ))}
              </div>
            </section>
          )}
        </>
      )}
    </div>
  );
}

// ---------------------------------------------------------------------------
// Session Card
// ---------------------------------------------------------------------------

function SessionCard({
  session,
  expanded,
  onToggle,
  onStatusChange,
  actionLoading,
}: {
  session: SessionRow;
  expanded: boolean;
  onToggle: () => void;
  onStatusChange: (id: string, status: string) => void;
  actionLoading: boolean;
}) {
  return (
    <div className="rounded-lg border border-app bg-white shadow-sm">
      <button
        type="button"
        onClick={onToggle}
        className="flex w-full items-center justify-between px-4 py-3 text-left"
      >
        <div className="min-w-0 flex-1">
          <div className="flex items-center gap-2">
            <h3 className="truncate text-sm font-semibold text-app-foreground">
              {session.title}
            </h3>
            <span
              className={`rounded-full px-2 py-0.5 text-[10px] font-medium ${statusColor(session.status)}`}
            >
              {statusLabel(session.status)}
            </span>
          </div>
          <div className="mt-1 flex flex-wrap items-center gap-3 text-xs text-app-muted">
            {session.startDate && <span>{formatDate(session.startDate)}</span>}
            {session.endDate && (
              <span>
                &rarr; {formatDate(session.endDate)}
              </span>
            )}
          </div>
        </div>
        <div className="flex items-center gap-4 text-xs text-app-muted">
          {session.learnerCount > 0 && (
            <span title="Learners observed">{session.learnerCount} learners</span>
          )}
          {session.evidenceCount > 0 && (
            <span title="Evidence records">{session.evidenceCount} evidence</span>
          )}
          {session.checkpointCount > 0 && (
            <span title="Checkpoints">{session.checkpointCount} checkpoints</span>
          )}
          <span className="text-app-muted">{expanded ? '\u25B2' : '\u25BC'}</span>
        </div>
      </button>

      {expanded && (
        <div className="border-t border-app px-4 py-3 space-y-3">
          {session.description && (
            <p className="text-xs text-app-muted">{session.description}</p>
          )}

          <div className="grid grid-cols-3 gap-3">
            <div className="rounded-md bg-gray-50 p-2 text-center">
              <p className="text-lg font-bold text-app-foreground">{session.learnerCount}</p>
              <p className="text-[10px] text-app-muted">Learners</p>
            </div>
            <div className="rounded-md bg-gray-50 p-2 text-center">
              <p className="text-lg font-bold text-app-foreground">{session.evidenceCount}</p>
              <p className="text-[10px] text-app-muted">Evidence Records</p>
            </div>
            <div className="rounded-md bg-gray-50 p-2 text-center">
              <p className="text-lg font-bold text-app-foreground">{session.checkpointCount}</p>
              <p className="text-[10px] text-app-muted">Checkpoints</p>
            </div>
          </div>

          <div className="flex gap-2">
            {session.status === 'scheduled' && (
              <button
                disabled={actionLoading}
                onClick={() => onStatusChange(session.id, 'in_progress')}
                className="rounded-md bg-green-600 px-3 py-1.5 text-xs font-semibold text-white hover:bg-green-700 disabled:opacity-50"
              >
                {actionLoading ? 'Starting...' : 'Start Session'}
              </button>
            )}
            {session.status === 'in_progress' && (
              <button
                disabled={actionLoading}
                onClick={() => onStatusChange(session.id, 'completed')}
                className="rounded-md bg-blue-600 px-3 py-1.5 text-xs font-semibold text-white hover:bg-blue-700 disabled:opacity-50"
              >
                {actionLoading ? 'Completing...' : 'Complete Session'}
              </button>
            )}
            {(session.status === 'scheduled' || session.status === 'in_progress') && (
              <button
                disabled={actionLoading}
                onClick={() => onStatusChange(session.id, 'cancelled')}
                className="rounded-md border border-red-300 px-3 py-1.5 text-xs font-medium text-red-700 hover:bg-red-50 disabled:opacity-50"
              >
                Cancel
              </button>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
