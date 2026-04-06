'use client';

import { useCallback, useEffect, useMemo, useState } from 'react';
import {
  addDoc,
  getDocs,
  orderBy,
  query,
  serverTimestamp,
  where,
  limit,
} from 'firebase/firestore';
import { useAuthContext } from '@/src/firebase/auth/AuthProvider';
import {
  evidenceRecordsCollection,
  sessionOccurrencesCollection,
  sessionsCollection,
  usersCollection,
} from '@/src/firebase/firestore/collections';
import { Timestamp } from 'firebase/firestore';
import { useCapabilities } from '@/src/lib/capabilities/useCapabilities';
import { RoleRouteGuard } from '@/src/components/auth/RoleRouteGuard';
import { RubricReviewPanel } from '@/src/components/evidence/RubricReviewPanel';
import { Spinner } from '@/src/components/ui/Spinner';
import type { EvidenceRecord } from '@/src/types/schema';

const PHASE_OPTIONS: { value: EvidenceRecord['phaseKey']; label: string }[] = [
  { value: 'retrieval_warm_up', label: 'Retrieval / Warm-up' },
  { value: 'mini_lesson', label: 'Mini Lesson' },
  { value: 'build_sprint', label: 'Build Sprint' },
  { value: 'checkpoint', label: 'Checkpoint' },
  { value: 'share_out', label: 'Share Out' },
  { value: 'reflection', label: 'Reflection' },
];

interface SessionOption {
  occurrenceId: string;
  label: string;
}

interface LearnerOption {
  uid: string;
  displayName: string;
}

interface RecentEvidence {
  id: string;
  learnerName: string;
  learnerId: string;
  description: string;
  capabilityId?: string;
  capabilityMapped: boolean;
  rubricStatus: string;
  phaseKey: string | null;
  portfolioCandidate: boolean;
}

export function EducatorEvidenceCapture() {
  const { user, profile, loading: authLoading } = useAuthContext();
  const siteId = profile?.studioId ?? null;

  const { capabilityList: capabilities, resolveTitle } = useCapabilities(siteId);
  const [learners, setLearners] = useState<LearnerOption[]>([]);
  const [todaySessions, setTodaySessions] = useState<SessionOption[]>([]);
  const [recentEvidence, setRecentEvidence] = useState<RecentEvidence[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);

  // Form state
  const [selectedLearnerId, setSelectedLearnerId] = useState('');
  const [description, setDescription] = useState('');
  const [selectedCapabilityId, setSelectedCapabilityId] = useState('');
  const [phaseKey, setPhaseKey] = useState<EvidenceRecord['phaseKey']>(undefined);
  const [portfolioCandidate, setPortfolioCandidate] = useState(false);
  const [selectedSessionOccurrenceId, setSelectedSessionOccurrenceId] = useState('');
  const [reviewingEvidence, setReviewingEvidence] = useState<RecentEvidence | null>(null);

  const learnerNameMap = useMemo(() => {
    const map = new Map<string, string>();
    for (const l of learners) map.set(l.uid, l.displayName);
    return map;
  }, [learners]);

  const selectedCapability = useMemo(
    () => capabilities.find((c) => c.id === selectedCapabilityId) ?? null,
    [capabilities, selectedCapabilityId]
  );

  const loadData = useCallback(async () => {
    if (!siteId) return;
    setLoading(true);
    try {
      // Build today's date range for session occurrence query
      const todayStart = new Date();
      todayStart.setHours(0, 0, 0, 0);
      const todayEnd = new Date();
      todayEnd.setHours(23, 59, 59, 999);

      const [learnerSnap, evidenceSnap, occurrenceSnap] = await Promise.all([
        getDocs(
          query(usersCollection, where('studioId', '==', siteId), where('role', '==', 'learner'), orderBy('displayName'))
        ),
        getDocs(
          query(evidenceRecordsCollection, where('siteId', '==', siteId), orderBy('createdAt', 'desc'), limit(20))
        ),
        getDocs(
          query(
            sessionOccurrencesCollection,
            where('siteId', '==', siteId),
            where('date', '>=', Timestamp.fromDate(todayStart)),
            where('date', '<=', Timestamp.fromDate(todayEnd))
          )
        ),
      ]);

      // Resolve parent session docs for time labels
      const sessionIds = Array.from(new Set(occurrenceSnap.docs.map((d) => d.data().sessionId)));
      const sessionTimeMap = new Map<string, { start: Date; end: Date }>();
      if (sessionIds.length > 0) {
        // Firestore 'in' supports up to 30 values, should be fine for daily sessions
        const sessionSnap = await getDocs(
          query(sessionsCollection, where('__name__', 'in', sessionIds.slice(0, 30)))
        );
        for (const sd of sessionSnap.docs) {
          const s = sd.data();
          sessionTimeMap.set(sd.id, {
            start: s.startTime?.toDate?.() ?? new Date(),
            end: s.endTime?.toDate?.() ?? new Date(),
          });
        }
      }

      const fmt = (d: Date) => d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
      setTodaySessions(
        occurrenceSnap.docs.map((d) => {
          const occ = d.data();
          const times = sessionTimeMap.get(occ.sessionId);
          const label = times
            ? `${fmt(times.start)} – ${fmt(times.end)}`
            : `Session ${occ.sessionId.slice(0, 6)}`;
          return { occurrenceId: d.id, label };
        })
      );

      setLearners(
        learnerSnap.docs.map((d) => ({
          uid: d.data().uid,
          displayName: d.data().displayName,
        }))
      );

      const learnerNames = new Map<string, string>();
      for (const d of learnerSnap.docs) learnerNames.set(d.data().uid, d.data().displayName);

      setRecentEvidence(
        evidenceSnap.docs.map((d) => {
          const data = d.data();
          return {
            id: d.id,
            learnerName: learnerNames.get(data.learnerId) ?? data.learnerId,
            learnerId: data.learnerId ?? '',
            description: data.description,
            capabilityId: data.capabilityId ?? undefined,
            capabilityMapped: data.capabilityMapped ?? false,
            rubricStatus: data.rubricStatus ?? 'pending',
            phaseKey: data.phaseKey ?? null,
            portfolioCandidate: data.portfolioCandidate ?? false,
          };
        })
      );
    } catch (err) {
      console.error('Failed to load evidence capture data', err);
    } finally {
      setLoading(false);
    }
  }, [siteId]);

  useEffect(() => {
    if (!authLoading && siteId) void loadData();
  }, [authLoading, siteId, loadData]);

  const resetForm = () => {
    setDescription('');
    setSelectedCapabilityId('');
    setPhaseKey(undefined);
    setPortfolioCandidate(false);
    // Keep selectedLearnerId and selectedSessionOccurrenceId for quick successive logs
  };

  const handleSubmit = async () => {
    if (!user || !siteId || !selectedLearnerId || !description.trim()) return;
    setSaving(true);
    setSuccessMessage(null);

    const capabilityId = selectedCapability?.id ?? null;
    const mapped = !!capabilityId;

    try {
      await addDoc(evidenceRecordsCollection, {
        learnerId: selectedLearnerId,
        educatorId: user.uid,
        siteId,
        sessionOccurrenceId: selectedSessionOccurrenceId || undefined,
        description: description.trim(),
        capabilityId: capabilityId ?? undefined,
        capabilityMapped: mapped,
        phaseKey,
        portfolioCandidate,
        rubricStatus: 'pending' as const,
        growthStatus: 'pending' as const,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      } as unknown as Omit<EvidenceRecord, 'id'>);

      const learnerName = learnerNameMap.get(selectedLearnerId) ?? selectedLearnerId;
      setSuccessMessage(`Logged for ${learnerName}`);
      resetForm();

      // Prepend to recent evidence for instant feedback
      setRecentEvidence((prev: RecentEvidence[]) => [
        {
          id: `temp-${Date.now()}`,
          learnerName,
          learnerId: selectedLearnerId,
          description: description.trim(),
          capabilityId: capabilityId ?? undefined,
          capabilityMapped: mapped,
          rubricStatus: 'pending',
          phaseKey: phaseKey ?? null,
          portfolioCandidate,
        },
        ...prev.slice(0, 19),
      ]);
    } catch (err) {
      console.error('Failed to save evidence record', err);
    } finally {
      setSaving(false);
    }
  };

  // Auto-clear success message
  useEffect(() => {
    if (!successMessage) return;
    const timeout = setTimeout(() => setSuccessMessage(null), 3000);
    return () => clearTimeout(timeout);
  }, [successMessage]);

  if (authLoading) {
    return (
      <div className="flex min-h-[240px] items-center justify-center">
        <Spinner />
      </div>
    );
  }

  if (!siteId) {
    return (
      <div className="rounded-xl border border-amber-200 bg-amber-50 p-6 text-sm text-amber-900">
        No site assigned. Evidence capture requires a site context.
      </div>
    );
  }

  const canSubmit = !!selectedLearnerId && description.trim().length > 0 && !saving;

  return (
    <RoleRouteGuard allowedRoles={['educator', 'site', 'hq']}>
      <section className="space-y-4" data-testid="evidence-capture-page">
        <header className="rounded-xl border border-app bg-app-surface-raised p-4">
          <h1 className="text-xl font-bold text-app-foreground">Live Evidence Capture</h1>
          <p className="mt-1 text-sm text-app-muted">
            Log learner observations during sessions. Designed for speed — under 10 seconds per entry.
          </p>
        </header>

        {/* Success banner */}
        {successMessage && (
          <div className="rounded-lg border border-green-200 bg-green-50 px-4 py-2 text-sm font-medium text-green-800" data-testid="evidence-success">
            {successMessage}
          </div>
        )}

        {/* Quick capture form */}
        <div className="rounded-xl border border-app bg-app-surface-raised p-4 space-y-3" data-testid="evidence-form">
          {/* Row 0: Session context */}
          <label className="block space-y-1">
            <span className="text-xs font-medium text-app-muted">Session</span>
            {todaySessions.length > 0 ? (
              <select
                data-testid="evidence-session"
                value={selectedSessionOccurrenceId}
                onChange={(e) => setSelectedSessionOccurrenceId(e.target.value)}
                className="w-full rounded-md border border-app bg-app-canvas px-3 py-2 text-sm text-app-foreground"
              >
                <option value="">(not linked to a session)</option>
                {todaySessions.map((s) => (
                  <option key={s.occurrenceId} value={s.occurrenceId}>
                    {s.label}
                  </option>
                ))}
              </select>
            ) : (
              <p className="text-xs text-app-muted bg-app-surface rounded-md px-3 py-2 border border-app">
                No sessions scheduled today. Evidence will be saved without a session link.
              </p>
            )}
          </label>

          {/* Row 1: Learner + Phase */}
          <div className="grid gap-3 sm:grid-cols-2">
            <label className="space-y-1">
              <span className="text-xs font-medium text-app-muted">Learner *</span>
              <select
                data-testid="evidence-learner"
                value={selectedLearnerId}
                onChange={(e) => setSelectedLearnerId(e.target.value)}
                className="w-full rounded-md border border-app bg-app-canvas px-3 py-2 text-sm text-app-foreground"
              >
                <option value="">Select learner</option>
                {learners.map((l) => (
                  <option key={l.uid} value={l.uid}>
                    {l.displayName}
                  </option>
                ))}
              </select>
            </label>

            <label className="space-y-1">
              <span className="text-xs font-medium text-app-muted">Session Phase</span>
              <select
                data-testid="evidence-phase"
                value={phaseKey ?? ''}
                onChange={(e) =>
                  setPhaseKey((e.target.value || undefined) as EvidenceRecord['phaseKey'])
                }
                className="w-full rounded-md border border-app bg-app-canvas px-3 py-2 text-sm text-app-foreground"
              >
                <option value="">Any phase</option>
                {PHASE_OPTIONS.map((p) => (
                  <option key={p.value} value={p.value}>
                    {p.label}
                  </option>
                ))}
              </select>
            </label>
          </div>

          {/* Row 2: Observation description */}
          <label className="block space-y-1">
            <span className="text-xs font-medium text-app-muted">What did you observe? *</span>
            <textarea
              data-testid="evidence-description"
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              placeholder="e.g., 'Built a working prototype and explained the logic to their partner'"
              className="w-full rounded-md border border-app bg-app-canvas px-3 py-2 text-sm text-app-foreground min-h-20"
            />
          </label>

          {/* Row 3: Capability + Portfolio flag */}
          <div className="grid gap-3 sm:grid-cols-2">
            <label className="space-y-1">
              <span className="text-xs font-medium text-app-muted">Capability</span>
              {capabilities.length > 0 ? (
                <select
                  data-testid="evidence-capability"
                  value={selectedCapabilityId}
                  onChange={(e) => setSelectedCapabilityId(e.target.value)}
                  className="w-full rounded-md border border-app bg-app-canvas px-3 py-2 text-sm text-app-foreground"
                >
                  <option value="">(unmapped — select a capability)</option>
                  {capabilities.map((c) => (
                    <option key={c.id} value={c.id}>
                      {c.title} ({c.pillarCode.replace(/_/g, ' ')})
                    </option>
                  ))}
                </select>
              ) : (
                <p className="text-xs text-amber-700 bg-amber-50 rounded-md px-3 py-2 border border-amber-200">
                  No capabilities defined for this site. Ask HQ to create the capability framework.
                  Evidence will be saved as unmapped.
                </p>
              )}
            </label>

            <div className="flex items-end pb-1">
              <label className="flex items-center gap-2 rounded-md border border-app bg-app-canvas px-3 py-2">
                <input
                  data-testid="evidence-portfolio"
                  type="checkbox"
                  checked={portfolioCandidate}
                  onChange={(e) => setPortfolioCandidate(e.target.checked)}
                />
                <span className="text-sm text-app-foreground">Portfolio candidate</span>
              </label>
            </div>
          </div>



          {/* Submit */}
          <button
            type="button"
            data-testid="evidence-submit"
            disabled={!canSubmit}
            onClick={() => void handleSubmit()}
            className="w-full rounded-md bg-primary px-4 py-2.5 text-sm font-semibold text-primary-foreground disabled:opacity-50 sm:w-auto"
          >
            {saving ? 'Saving...' : 'Log Evidence'}
          </button>
        </div>

        {/* Rubric review panel */}
        {reviewingEvidence && siteId && (
          <RubricReviewPanel
            evidenceRecordIds={[reviewingEvidence.id]}
            learnerId={reviewingEvidence.learnerId}
            learnerName={reviewingEvidence.learnerName}
            siteId={siteId}
            description={reviewingEvidence.description}
            capabilityId={reviewingEvidence.capabilityId}
            onComplete={() => {
              setReviewingEvidence(null);
              void loadData();
            }}
            onCancel={() => setReviewingEvidence(null)}
          />
        )}

        {/* Recent evidence log */}
        <div className="rounded-xl border border-app bg-app-surface p-4" data-testid="evidence-recent">
          <h2 className="text-sm font-semibold text-app-foreground mb-3">Recent Observations</h2>
          {loading ? (
            <div className="flex items-center gap-2 text-app-muted py-4">
              <Spinner />
              <span className="text-sm">Loading...</span>
            </div>
          ) : recentEvidence.length === 0 ? (
            <p className="text-sm text-app-muted py-4">No evidence logged yet for this site.</p>
          ) : (
            <ul className="space-y-2">
              {recentEvidence.map((ev) => (
                <li
                  key={ev.id}
                  className="rounded-lg border border-app bg-app-canvas p-3 text-sm"
                >
                  <div className="flex items-start justify-between gap-2">
                    <div>
                      <span className="font-medium text-app-foreground">{ev.learnerName}</span>
                      <span className="mx-1 text-app-muted">—</span>
                      <span className="text-app-foreground">{ev.description}</span>
                    </div>
                    {ev.portfolioCandidate && (
                      <span className="shrink-0 rounded bg-blue-100 px-1.5 py-0.5 text-xs font-medium text-blue-800">
                        Portfolio
                      </span>
                    )}
                    {ev.rubricStatus === 'pending' && (
                      <button
                        type="button"
                        onClick={() => setReviewingEvidence(ev)}
                        className="shrink-0 rounded bg-primary/10 px-2 py-0.5 text-xs font-medium text-primary hover:bg-primary/20"
                      >
                        Review
                      </button>
                    )}
                    {ev.rubricStatus === 'applied' && (
                      <span className="shrink-0 rounded bg-green-100 px-1.5 py-0.5 text-xs font-medium text-green-800">
                        Reviewed
                      </span>
                    )}
                  </div>
                  <div className="mt-1 flex flex-wrap gap-2 text-xs text-app-muted">
                    {ev.capabilityId && (
                      <span className="rounded bg-app-surface px-1.5 py-0.5">{resolveTitle(ev.capabilityId)}</span>
                    )}
                    {!ev.capabilityMapped && (
                      <span className="rounded bg-amber-50 text-amber-700 px-1.5 py-0.5">unmapped</span>
                    )}
                    {ev.phaseKey && (
                      <span className="rounded bg-app-surface px-1.5 py-0.5">
                        {PHASE_OPTIONS.find((p) => p.value === ev.phaseKey)?.label ?? ev.phaseKey}
                      </span>
                    )}
                  </div>
                </li>
              ))}
            </ul>
          )}
        </div>
      </section>
    </RoleRouteGuard>
  );
}
