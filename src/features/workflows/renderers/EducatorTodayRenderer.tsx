'use client';

import React, { useCallback, useEffect, useState } from 'react';
import {
  addDoc,
  collection,
  getDocs,
  orderBy,
  query,
  serverTimestamp,
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
  siteId: string;
}

interface LearnerOption {
  id: string;
  displayName: string;
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

// ---------------------------------------------------------------------------
// Quick Evidence Capture — writes to evidenceRecords (evidence chain)
// ---------------------------------------------------------------------------

function QuickEvidenceCapture({
  learnerId,
  learnerName,
  educatorId,
  siteId,
  sessionId,
  onSuccess,
  onCancel,
}: {
  learnerId: string;
  learnerName: string;
  educatorId: string;
  siteId: string;
  sessionId?: string;
  onSuccess: () => void;
  onCancel: () => void;
}) {
  const [description, setDescription] = useState('');
  const [portfolioCandidate, setPortfolioCandidate] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [submitError, setSubmitError] = useState<string | null>(null);

  const handleSubmit = async () => {
    const trimmed = description.trim();
    if (!trimmed) {
      setSubmitError('Please describe what you observed.');
      return;
    }
    setSubmitting(true);
    setSubmitError(null);
    try {
      const evidenceRef = await addDoc(collection(firestore, 'evidenceRecords'), {
        learnerId,
        educatorId,
        siteId,
        sessionId: sessionId || null,
        description: trimmed,
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
            pillarCodes: [],
            artifacts: [],
            capabilityIds: [],
            capabilityTitles: [],
            evidenceRecordId: evidenceRef.id,
            aiAssistanceUsed: false,
            aiDisclosureStatus: 'not-available',
            verificationStatus: 'pending',
            proofOfLearningStatus: 'not-available',
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
          disabled={submitting}
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
  const [learners, setLearners] = useState<LearnerOption[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

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
      setLearners([]);
      setLoading(false);
      return;
    }
    setLoading(true);
    try {
      // Load sessions and learners in parallel
      const sessionsQuery = query(
        collection(firestore, 'sessions'),
        where('siteId', '==', educatorSiteId),
        where('educatorIds', 'array-contains', ctx.uid),
        orderBy('startDate', 'asc'),
        limit(20)
      );

      const learnersQuery = query(
        collection(firestore, 'users'),
        where('role', '==', 'learner'),
        where('siteIds', 'array-contains', educatorSiteId),
        limit(50)
      );

      const results = await Promise.all([getDocs(sessionsQuery), getDocs(learnersQuery)]);
      const sessionsSnap = results[0] as Awaited<ReturnType<typeof getDocs>>;

      setSessions(
        sessionsSnap.docs.map((d) => {
          const data = d.data() as Record<string, unknown>;
          return {
            id: d.id,
            title: asString(data['title'] || data['name'], d.id),
            description: asString(data['description'], ''),
            status: asString(data['status'], 'scheduled'),
            startDate: toIso(data['startTime'] || data['startDate']),
            siteId: asString(data['siteId'], ''),
          };
        })
      );

      const learnersSnap = results[1] as Awaited<ReturnType<typeof getDocs>>;
      setLearners(
        learnersSnap.docs.map((d) => ({
          id: d.id,
          displayName: asString((d.data() as Record<string, unknown>)['displayName'], d.id),
        }))
      );
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load today view.');
    } finally {
      setLoading(false);
    }
  }, [ctx.uid, educatorSiteId]);

  useEffect(() => {
    void loadData();
  }, [loadData]);

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
              Capture a learner observation in under 10 seconds. Select a learner to begin.
            </p>

            {observationOpen && selectedLearnerId ? (
              <QuickEvidenceCapture
                learnerId={selectedLearnerId}
                learnerName={selectedLearnerName}
                educatorId={ctx.uid}
                siteId={educatorSiteId}
                sessionId={sessions.find((s) => s.status === 'active')?.id ?? sessions[0]?.id}
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
                {learners.length === 0 ? (
                  <span className="text-xs text-app-muted">
                    No learners found for this site.
                  </span>
                ) : (
                  learners.map((l) => (
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
                    key={s.id}
                    className="flex items-center justify-between rounded-lg border border-app bg-app-surface p-3"
                  >
                    <div>
                      <span className="text-sm font-medium text-app-foreground">
                        {s.title}
                      </span>
                      {s.description && (
                        <p className="text-xs text-app-muted mt-0.5">{s.description}</p>
                      )}
                    </div>
                    <div className="flex items-center gap-2">
                      <span
                        className={`rounded-full px-2 py-0.5 text-xs font-medium ${
                          s.status === 'active'
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
