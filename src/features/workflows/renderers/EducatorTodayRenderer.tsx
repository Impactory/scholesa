'use client';

import React, { useCallback, useEffect, useState } from 'react';
import {
  addDoc,
  collection,
  documentId,
  getDocs,
  orderBy,
  query,
  serverTimestamp,
  Timestamp,
  where,
  limit,
} from 'firebase/firestore';
import { firestore } from '@/src/firebase/client-init';
import {
  missionAttemptsCollection,
  portfolioItemsCollection,
} from '@/src/firebase/firestore/collections';
import { Spinner } from '@/src/components/ui/Spinner';
import { useInteractionTracking } from '@/src/hooks/useTelemetry';
import { resolveActiveSiteId } from '@/src/lib/auth/activeSite';
import { useCapabilities } from '@/src/lib/capabilities/useCapabilities';
import type { CustomRouteRendererProps } from '../customRouteRenderers';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface SessionRow {
  occurrenceId: string;
  sessionId: string;
  title: string;
  description: string;
  status: string;
  startDate: string | null;
  siteId: string;
  rosterSource: 'attendance' | 'enrollment' | 'none';
  learners: LearnerOption[];
}

interface LearnerOption {
  id: string;
  displayName: string;
  attendanceStatus?: 'present' | 'late' | 'absent';
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

function chunkValues<T>(values: T[], size: number): T[][] {
  const chunks: T[][] = [];
  for (let index = 0; index < values.length; index += size) {
    chunks.push(values.slice(index, index + size));
  }
  return chunks;
}

// ---------------------------------------------------------------------------
// Quick Evidence Capture — writes to evidenceRecords (evidence chain)
// ---------------------------------------------------------------------------

function QuickEvidenceCapture({
  learnerId,
  learnerName,
  educatorId,
  siteId,
  sessionOccurrenceId,
  onSuccess,
  onCancel,
}: {
  learnerId: string;
  learnerName: string;
  educatorId: string;
  siteId: string;
  sessionOccurrenceId?: string;
  onSuccess: () => void;
  onCancel: () => void;
}) {
  const { capabilityList, resolveTitle } = useCapabilities(siteId);
  const [description, setDescription] = useState('');
  const [portfolioCandidate, setPortfolioCandidate] = useState(false);
  const [selectedCapabilityId, setSelectedCapabilityId] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [submitError, setSubmitError] = useState<string | null>(null);

  const handleSubmit = async () => {
    const trimmed = description.trim();
    if (!trimmed) {
      setSubmitError('Please describe what you observed.');
      return;
    }
    if (portfolioCandidate && !selectedCapabilityId) {
      setSubmitError('Select a capability before flagging this observation as portfolio evidence.');
      return;
    }
    setSubmitting(true);
    setSubmitError(null);
    try {
      const selectedCapability = capabilityList.find((cap) => cap.id === selectedCapabilityId) ?? null;
      const evidenceRef = await addDoc(collection(firestore, 'evidenceRecords'), {
        learnerId,
        educatorId,
        siteId,
        sessionOccurrenceId: sessionOccurrenceId || undefined,
        description: trimmed,
        capabilityId: selectedCapabilityId || undefined,
        capabilityMapped: Boolean(selectedCapabilityId),
        portfolioCandidate,
        rubricStatus: 'pending',
        growthStatus: 'pending',
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      });

      // When flagged as portfolio candidate, also create a linked portfolioItem
      if (portfolioCandidate) {
        try {
          await addDoc(portfolioItemsCollection, {
            learnerId,
            siteId,
            title: `Observation: ${trimmed.slice(0, 60)}${trimmed.length > 60 ? '...' : ''}`,
            description: trimmed,
            pillarCodes: selectedCapability?.pillarCode ? [selectedCapability.pillarCode] : [],
            artifacts: [],
            evidenceRecordIds: [evidenceRef.id],
            capabilityIds: selectedCapabilityId ? [selectedCapabilityId] : [],
            capabilityTitles: selectedCapabilityId ? [resolveTitle(selectedCapabilityId)] : [],
            aiAssistanceUsed: false,
            aiDisclosureStatus: 'not-available',
            verificationStatus: 'pending',
            proofOfLearningStatus: 'missing',
            source: 'educator_observation',
            educatorId,
            createdAt: serverTimestamp(),
          } as unknown as Omit<import('@/src/types/schema').PortfolioItem, 'id'>);
        } catch (err) {
          console.warn('Failed to create linked portfolio item:', err);
        }
      }

      onSuccess();
    } catch (err) {
      setSubmitError(err instanceof Error ? err.message : 'Failed to save evidence.');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="space-y-3" data-testid="quick-evidence-form">
      <p className="text-xs font-medium text-app-foreground">
        Observing: {learnerName}
      </p>
      <textarea
        className="w-full rounded-md border border-app bg-app-canvas p-2 text-sm text-app-foreground placeholder:text-app-muted"
        placeholder="What did you observe? (e.g., explained their approach clearly, collaborated well...)"
        rows={3}
        value={description}
        onChange={(e) => setDescription(e.target.value)}
        data-testid="evidence-description"
      />
      <label className="block space-y-1">
        <span className="text-xs font-medium text-app-muted">
          Capability {portfolioCandidate ? '*' : '(optional unless saving to portfolio)'}
        </span>
        {capabilityList.length > 0 ? (
          <select
            value={selectedCapabilityId}
            onChange={(e) => setSelectedCapabilityId(e.target.value)}
            className="w-full rounded-md border border-app bg-app-canvas px-3 py-2 text-sm text-app-foreground"
            data-testid="quick-evidence-capability"
          >
            <option value="">Select a capability…</option>
            {capabilityList.map((cap) => (
              <option key={cap.id} value={cap.id}>
                {cap.title ?? cap.name} ({cap.pillarCode.replace(/_/g, ' ')})
              </option>
            ))}
          </select>
        ) : (
          <p className="rounded-md border border-amber-200 bg-amber-50 px-3 py-2 text-xs text-amber-900">
            Define capabilities in HQ before saving live observations as portfolio evidence.
          </p>
        )}
      </label>
      <label className="flex items-center gap-2 text-xs text-app-muted">
        <input
          type="checkbox"
          checked={portfolioCandidate}
          onChange={(e) => setPortfolioCandidate(e.target.checked)}
        />
        Flag as portfolio candidate
      </label>
      {submitError && (
        <p className="text-xs text-red-600">{submitError}</p>
      )}
      <div className="flex gap-2">
        <button
          type="button"
          disabled={submitting || !description.trim() || (portfolioCandidate && !selectedCapabilityId)}
          onClick={() => void handleSubmit()}
          className="rounded-md bg-primary px-3 py-1.5 text-xs font-semibold text-primary-foreground disabled:opacity-50"
          data-testid="submit-evidence"
        >
          {submitting ? 'Saving...' : 'Save Evidence'}
        </button>
        <button
          type="button"
          onClick={onCancel}
          className="rounded-md border border-app px-3 py-1.5 text-xs font-medium text-app-foreground"
        >
          Cancel
        </button>
      </div>
    </div>
  );
}

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

export default function EducatorTodayRenderer({ ctx }: CustomRouteRendererProps) {
  const trackInteraction = useInteractionTracking();

  const [sessions, setSessions] = useState<SessionRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [selectedSessionOccurrenceId, setSelectedSessionOccurrenceId] = useState('');

  // Quick observation state
  const [observationOpen, setObservationOpen] = useState(false);
  const [selectedLearnerId, setSelectedLearnerId] = useState<string | null>(null);
  const [selectedLearnerName, setSelectedLearnerName] = useState('');

  // Review queue counts
  const [pendingReviewCount, setPendingReviewCount] = useState(0);
  const [awaitingRevisionCount, setAwaitingRevisionCount] = useState(0);

  const educatorSiteId = resolveActiveSiteId(ctx.profile) ?? '';

  const loadData = useCallback(async () => {
    setError(null);
    if (!educatorSiteId) {
      setSessions([]);
      setLoading(false);
      return;
    }
    setLoading(true);
    try {
      const todayStart = new Date();
      todayStart.setHours(0, 0, 0, 0);
      const todayEnd = new Date();
      todayEnd.setHours(23, 59, 59, 999);

      const [occurrencesSnap, siteLearnersSnap, legacyLearnersSnap] = await Promise.all([
        getDocs(
          query(
            collection(firestore, 'sessionOccurrences'),
            where('siteId', '==', educatorSiteId),
            where('educatorId', '==', ctx.uid),
            where('date', '>=', Timestamp.fromDate(todayStart)),
            where('date', '<=', Timestamp.fromDate(todayEnd)),
            limit(20)
          )
        ),
        getDocs(
          query(
            collection(firestore, 'users'),
            where('role', '==', 'learner'),
            where('siteIds', 'array-contains', educatorSiteId),
            limit(200)
          )
        ),
        getDocs(
          query(
            collection(firestore, 'users'),
            where('role', '==', 'learner'),
            where('studioId', '==', educatorSiteId),
            limit(200)
          )
        ),
      ]);

      const occurrenceDocs = occurrencesSnap.docs.map((d) => ({
        occurrenceId: d.id,
        data: d.data() as Record<string, unknown>,
      }));
      const sessionIds = Array.from(
        new Set(
          occurrenceDocs
            .map((entry) => asString(entry.data['sessionId'], ''))
            .filter((value) => value.length > 0)
        )
      );
      const occurrenceIds = occurrenceDocs.map((entry) => entry.occurrenceId);

      const [sessionBatchSnaps, enrollmentBatchSnaps, attendanceBatchSnaps] = await Promise.all([
        Promise.all(
          chunkValues(sessionIds, 10).map((ids) =>
            getDocs(query(collection(firestore, 'sessions'), where(documentId(), 'in', ids)))
          )
        ),
        Promise.all(
          chunkValues(sessionIds, 10).map((ids) =>
            getDocs(
              query(
                collection(firestore, 'enrollments'),
                where('sessionId', 'in', ids),
                where('status', '==', 'active'),
                limit(200)
              )
            )
          )
        ),
        Promise.all(
          chunkValues(occurrenceIds, 10).map((ids) =>
            getDocs(
              query(
                collection(firestore, 'attendanceRecords'),
                where('sessionOccurrenceId', 'in', ids),
                limit(200)
              )
            )
          )
        ),
      ]);

      const sessionMap = new Map<string, Record<string, unknown>>();
      for (const snap of sessionBatchSnaps) {
        for (const docSnap of snap.docs) {
          sessionMap.set(docSnap.id, docSnap.data() as Record<string, unknown>);
        }
      }

      const learnerMap = new Map<string, LearnerOption>();
      for (const learnersSnap of [siteLearnersSnap, legacyLearnersSnap]) {
        for (const learnerDoc of learnersSnap.docs) {
          const data = learnerDoc.data() as Record<string, unknown>;
          const learnerId = asString(data['uid'], learnerDoc.id);
          if (!learnerMap.has(learnerId)) {
            learnerMap.set(learnerId, {
              id: learnerId,
              displayName: asString(data['displayName'], learnerId),
            });
          }
        }
      }

      const enrollmentMap = new Map<string, Set<string>>();
      for (const snap of enrollmentBatchSnaps) {
        for (const enrollmentDoc of snap.docs) {
          const data = enrollmentDoc.data() as Record<string, unknown>;
          const sessionId = asString(data['sessionId'], '');
          const learnerId = asString(data['learnerId'], '');
          if (!sessionId || !learnerId) continue;
          const learnersForSession = enrollmentMap.get(sessionId) ?? new Set<string>();
          learnersForSession.add(learnerId);
          enrollmentMap.set(sessionId, learnersForSession);
        }
      }

      const attendanceMap = new Map<string, Map<string, 'present' | 'late' | 'absent'>>();
      for (const snap of attendanceBatchSnaps) {
        for (const attendanceDoc of snap.docs) {
          const data = attendanceDoc.data() as Record<string, unknown>;
          const occurrenceId = asString(data['sessionOccurrenceId'], '');
          const learnerId = asString(data['learnerId'] || data['userId'], '');
          const status = asString(data['status'], '');
          if (
            !occurrenceId ||
            !learnerId ||
            (status !== 'present' && status !== 'late' && status !== 'absent')
          ) {
            continue;
          }
          const statusMap = attendanceMap.get(occurrenceId) ?? new Map<string, 'present' | 'late' | 'absent'>();
          statusMap.set(learnerId, status);
          attendanceMap.set(occurrenceId, statusMap);
        }
      }

      const loadedSessions = occurrenceDocs
        .map((entry) => {
          const sessionId = asString(entry.data['sessionId'], '');
          const sessionData = sessionMap.get(sessionId) ?? {};
          const enrollmentIds = Array.from(enrollmentMap.get(sessionId) ?? []);
          const attendanceStatusMap = attendanceMap.get(entry.occurrenceId);
          const liveLearnerIds = attendanceStatusMap
            ? Array.from(attendanceStatusMap.entries())
                .filter(([, status]) => status === 'present' || status === 'late')
                .map(([learnerId]) => learnerId)
            : enrollmentIds;
          const rosterSource: SessionRow['rosterSource'] = attendanceStatusMap
            ? 'attendance'
            : liveLearnerIds.length > 0
              ? 'enrollment'
              : 'none';

          const learners = liveLearnerIds
            .map((learnerId) => ({
              id: learnerId,
              displayName: learnerMap.get(learnerId)?.displayName ?? learnerId,
              attendanceStatus: attendanceStatusMap?.get(learnerId),
            }))
            .sort((left, right) => left.displayName.localeCompare(right.displayName));

          return {
            occurrenceId: entry.occurrenceId,
            sessionId,
            title: asString(sessionData['title'] || sessionData['name'], sessionId || entry.occurrenceId),
            description: asString(sessionData['description'], ''),
            status: asString(sessionData['status'], 'scheduled'),
            startDate: toIso(entry.data['date'] || sessionData['startTime'] || sessionData['startDate']),
            siteId: asString(entry.data['siteId'] || sessionData['siteId'], ''),
            rosterSource,
            learners,
          };
        })
        .sort((left, right) => {
          const leftTime = left.startDate ? new Date(left.startDate).getTime() : Number.MAX_SAFE_INTEGER;
          const rightTime = right.startDate ? new Date(right.startDate).getTime() : Number.MAX_SAFE_INTEGER;
          return leftTime - rightTime;
        });

      setSessions(loadedSessions);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load today view.');
    } finally {
      setLoading(false);
    }
  }, [ctx.uid, educatorSiteId]);

  useEffect(() => {
    void loadData();
  }, [loadData]);

  useEffect(() => {
    if (sessions.length === 0) {
      setSelectedSessionOccurrenceId('');
      return;
    }
    if (sessions.some((session) => session.occurrenceId === selectedSessionOccurrenceId)) {
      return;
    }
    const preferredSession =
      sessions.find((session) => session.status === 'in_progress') ?? sessions[0];
    setSelectedSessionOccurrenceId(preferredSession.occurrenceId);
  }, [sessions, selectedSessionOccurrenceId]);

  // Load review queue counts
  const loadQueueCounts = useCallback(async () => {
    if (!educatorSiteId) {
      setPendingReviewCount(0);
      setAwaitingRevisionCount(0);
      return;
    }
    try {
      const [pendingSnap, revisionSnap] = await Promise.all([
        getDocs(
          query(
            missionAttemptsCollection,
            where('siteId', '==', educatorSiteId),
            where('status', 'in', ['submitted', 'pending_review']),
            limit(50)
          )
        ),
        getDocs(
          query(
            missionAttemptsCollection,
            where('siteId', '==', educatorSiteId),
            where('status', '==', 'revision'),
            where('revisionRequestedBy', '==', ctx.uid),
            limit(50)
          )
        ),
      ]);
      setPendingReviewCount(pendingSnap.size);
      setAwaitingRevisionCount(revisionSnap.size);
    } catch {
      // non-critical
    }
  }, [educatorSiteId, ctx.uid]);

  useEffect(() => {
    void loadQueueCounts();
  }, [loadQueueCounts]);

  const handleOpenObservation = (learner: LearnerOption) => {
    setSelectedLearnerId(learner.id);
    setSelectedLearnerName(learner.displayName);
    setObservationOpen(true);
    trackInteraction('feature_discovered', { cta: 'quick_observation_opened' });
  };

  const selectedSession =
    sessions.find((session) => session.occurrenceId === selectedSessionOccurrenceId) ?? sessions[0] ?? null;
  const quickObservationLearners = selectedSession?.learners ?? [];

  useEffect(() => {
    if (!selectedLearnerId) return;
    if (quickObservationLearners.some((learner) => learner.id === selectedLearnerId)) return;
    setObservationOpen(false);
    setSelectedLearnerId(null);
    setSelectedLearnerName('');
  }, [quickObservationLearners, selectedLearnerId]);

  return (
    <section className="space-y-6" data-testid="educator-today">
      <header className="rounded-xl border border-app bg-app-surface-raised p-6">
        <h1 className="text-2xl font-bold text-app-foreground">Today</h1>
        <p className="mt-2 text-sm text-app-muted">
          Your sessions for today and quick observation capture.
        </p>
        <div className="mt-3 flex items-center gap-3">
          <button
            type="button"
            onClick={() => void loadData()}
            className="rounded-md border border-app px-3 py-1.5 text-xs font-medium text-app-foreground hover:bg-app-canvas"
          >
            Refresh
          </button>
        </div>
      </header>

      {/* Evidence Chain quick actions */}
      <div className="flex flex-wrap gap-2">
        <a
          href={`/${ctx.locale}/educator/evidence`}
          className="rounded-md bg-primary px-4 py-2 text-sm font-semibold text-primary-foreground hover:opacity-90"
          data-testid="nav-evidence-capture"
        >
          Capture Evidence
        </a>
        <a
          href={`/${ctx.locale}/educator/observations`}
          className="rounded-md border border-app bg-app-surface-raised px-4 py-2 text-sm font-medium text-app-foreground hover:bg-app-canvas"
          data-testid="nav-observations"
        >
          Observations
        </a>
        <a
          href={`/${ctx.locale}/educator/rubrics/apply`}
          className="rounded-md border border-app bg-app-surface-raised px-4 py-2 text-sm font-medium text-app-foreground hover:bg-app-canvas"
          data-testid="nav-rubric-apply"
        >
          Apply Rubric
        </a>
        <a
          href={`/${ctx.locale}/educator/verification`}
          className="rounded-md border border-app bg-app-surface-raised px-4 py-2 text-sm font-medium text-app-foreground hover:bg-app-canvas"
          data-testid="nav-verification"
        >
          Verify Portfolios
        </a>
      </div>

      {/* Review queue status */}
      {(pendingReviewCount > 0 || awaitingRevisionCount > 0) && (
        <div className="flex flex-wrap gap-3" data-testid="queue-status">
          {pendingReviewCount > 0 && (
            <a
              href={`/${ctx.locale}/educator/missions/review`}
              className="flex items-center gap-3 rounded-xl border border-blue-200 bg-blue-50 p-4 hover:bg-blue-100 transition-colors flex-1 min-w-[200px]"
              data-testid="pending-review-link"
            >
              <span className="flex h-8 w-8 items-center justify-center rounded-full bg-blue-200 text-sm font-bold text-blue-900">
                {pendingReviewCount}
              </span>
              <div>
                <p className="text-sm font-semibold text-blue-900">
                  {pendingReviewCount === 1 ? 'Submission' : 'Submissions'} awaiting review
                </p>
                <p className="text-xs text-blue-700">Tap to open evidence review</p>
              </div>
            </a>
          )}
          {awaitingRevisionCount > 0 && (
            <a
              href={`/${ctx.locale}/educator/missions/review`}
              className="flex items-center gap-3 rounded-xl border border-amber-200 bg-amber-50 p-4 hover:bg-amber-100 transition-colors flex-1 min-w-[200px]"
              data-testid="awaiting-revision-link"
            >
              <span className="flex h-8 w-8 items-center justify-center rounded-full bg-amber-200 text-sm font-bold text-amber-900">
                {awaitingRevisionCount}
              </span>
              <div>
                <p className="text-sm font-semibold text-amber-900">
                  Awaiting learner revision
                </p>
                <p className="text-xs text-amber-700">
                  {awaitingRevisionCount === 1
                    ? 'You requested a revision — waiting for the learner'
                    : `You requested ${awaitingRevisionCount} revisions — waiting for learners`}
                </p>
              </div>
            </a>
          )}
        </div>
      )}

      {error && (
        <div className="rounded-xl border border-red-200 bg-red-50 p-4 text-sm text-red-700">
          {error}
        </div>
      )}

      {!educatorSiteId ? (
        <div
          className="rounded-xl border border-amber-200 bg-amber-50 p-8 text-center text-sm text-amber-900"
          data-testid="educator-today-site-required"
        >
          <p className="font-semibold">Active site required</p>
          <p className="mt-1 text-amber-700">
            Select an active site before capturing live classroom observations.
          </p>
        </div>
      ) : loading ? (
        <div className="flex min-h-[240px] items-center justify-center rounded-xl border border-app bg-app-surface">
          <div className="flex items-center gap-2 text-app-muted">
            <Spinner />
            <span>Loading...</span>
          </div>
        </div>
      ) : (
        <>
          {/* Quick Observation Section (S2-4) */}
          <div
            className="rounded-xl border border-app bg-app-surface-raised p-5 space-y-3"
            data-testid="quick-observation"
          >
            <h2 className="text-base font-semibold text-app-foreground">
              Quick Observation
            </h2>
            <p className="text-xs text-app-muted">
              Capture a learner observation in under 10 seconds from the live session roster.
            </p>

            {sessions.length > 0 ? (
              <label className="block space-y-1">
                <span className="text-xs font-medium text-app-muted">Live session</span>
                <select
                  value={selectedSessionOccurrenceId}
                  onChange={(event) => {
                    setSelectedSessionOccurrenceId(event.target.value);
                    setObservationOpen(false);
                    setSelectedLearnerId(null);
                    setSelectedLearnerName('');
                  }}
                  className="w-full rounded-md border border-app bg-app-canvas px-3 py-2 text-sm text-app-foreground"
                  data-testid="quick-observation-session"
                >
                  {sessions.map((session) => (
                    <option key={session.occurrenceId} value={session.occurrenceId}>
                      {session.title} {session.startDate ? `• ${formatDate(session.startDate)}` : ''}
                    </option>
                  ))}
                </select>
              </label>
            ) : null}

            {selectedSession ? (
              <div
                className="rounded-lg border border-app bg-app-canvas px-3 py-2 text-xs text-app-muted"
                data-testid="quick-observation-roster-source"
              >
                {selectedSession.rosterSource === 'attendance'
                  ? 'Showing present learners from attendance for this session occurrence.'
                  : selectedSession.rosterSource === 'enrollment'
                    ? 'Attendance is not recorded yet. Showing the enrolled learner roster for this session.'
                    : 'No enrolled learners were found for this session yet.'}
              </div>
            ) : null}

            {observationOpen && selectedLearnerId ? (
              <QuickEvidenceCapture
                learnerId={selectedLearnerId}
                learnerName={selectedLearnerName}
                educatorId={ctx.uid}
                siteId={educatorSiteId}
                sessionOccurrenceId={selectedSession?.occurrenceId}
                onSuccess={() => {
                  setObservationOpen(false);
                  setSelectedLearnerId(null);
                  trackInteraction('feature_discovered', {
                    cta: 'evidence_captured',
                  });
                }}
                onCancel={() => {
                  setObservationOpen(false);
                  setSelectedLearnerId(null);
                }}
              />
            ) : (
              <div className="flex flex-wrap gap-2">
                {!selectedSession ? (
                  <span className="text-xs text-app-muted">
                    No live session occurrence found for today.
                  </span>
                ) : quickObservationLearners.length === 0 ? (
                  <span className="text-xs text-app-muted">
                    No learners are available for quick capture in this session yet.
                  </span>
                ) : (
                  quickObservationLearners.map((l) => (
                    <button
                      key={l.id}
                      type="button"
                      onClick={() => handleOpenObservation(l)}
                      className="rounded-md border border-app bg-app-canvas px-3 py-1.5 text-xs font-medium text-app-foreground hover:bg-app-surface-raised"
                      data-testid={`observe-${l.id}`}
                    >
                      {l.displayName}
                    </button>
                  ))
                )}
              </div>
            )}
          </div>

          {/* Sessions List */}
          <div className="space-y-3">
            <h2 className="text-base font-semibold text-app-foreground">
              Sessions ({sessions.length})
            </h2>
            {sessions.length === 0 ? (
              <div className="rounded-xl border border-app bg-app-surface p-8 text-center text-sm text-app-muted">
                No sessions scheduled. Check back later.
              </div>
            ) : (
              <ul className="space-y-2" data-testid="sessions-list">
                {sessions.map((s) => (
                  <li
                    key={s.occurrenceId}
                    className="flex items-center justify-between rounded-lg border border-app bg-app-surface p-3"
                  >
                    <div>
                      <span className="text-sm font-medium text-app-foreground">
                        {s.title}
                      </span>
                      {s.description && (
                        <p className="text-xs text-app-muted mt-0.5">{s.description}</p>
                      )}
                      <p className="mt-1 text-xs text-app-muted">
                        {s.learners.length}{' '}
                        {s.learners.length === 1 ? 'learner' : 'learners'} ready for quick capture
                        {s.rosterSource === 'attendance'
                          ? ' from attendance'
                          : s.rosterSource === 'enrollment'
                            ? ' from enrollment'
                            : ''}
                      </p>
                    </div>
                    <div className="flex items-center gap-2">
                      <span
                        className={`rounded-full px-2 py-0.5 text-xs font-medium ${
                          s.status === 'in_progress'
                            ? 'bg-green-100 text-green-800'
                            : 'bg-gray-100 text-gray-600'
                        }`}
                      >
                        {s.status}
                      </span>
                      <span className="text-xs text-app-muted">
                        {formatDate(s.startDate)}
                      </span>
                    </div>
                  </li>
                ))}
              </ul>
            )}
          </div>
        </>
      )}
    </section>
  );
}
