'use client';

import { useCallback, useEffect, useMemo, useState } from 'react';
import {
  addDoc,
  collection,
  documentId,
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
  portfolioItemsCollection,
  sessionOccurrencesCollection,
  sessionsCollection,
  usersCollection,
} from '@/src/firebase/firestore/collections';
import { firestore } from '@/src/firebase/client-init';
import { Timestamp } from 'firebase/firestore';
import { resolveActiveSiteId } from '@/src/lib/auth/activeSite';
import { useCapabilities } from '@/src/lib/capabilities/useCapabilities';
import { RoleRouteGuard } from '@/src/components/auth/RoleRouteGuard';
import { RubricReviewPanel } from '@/src/components/evidence/RubricReviewPanel';
import { Spinner } from '@/src/components/ui/Spinner';
import type { EvidenceRecord, PortfolioItem, Session, SessionOccurrence } from '@/src/types/schema';

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
  sessionId: string;
  label: string;
  status: string;
  rosterSource: 'attendance' | 'enrollment' | 'none';
  learners: LearnerOption[];
}

interface LearnerOption {
  uid: string;
  displayName: string;
  attendanceStatus?: 'present' | 'late' | 'absent';
}

interface RecentEvidence {
  id: string;
  learnerName: string;
  learnerId: string;
  portfolioItemId?: string;
  description: string;
  capabilityId?: string;
  capabilityMapped: boolean;
  rubricStatus: string;
  phaseKey: string | null;
  portfolioCandidate: boolean;
}

type SessionRecord = Session & Record<string, unknown>;
type SessionOccurrenceRecord = SessionOccurrence & Record<string, unknown>;

function asString(value: unknown, fallback: string): string {
  return typeof value === 'string' && value.trim().length > 0 ? value.trim() : fallback;
}

function chunkValues<T>(values: T[], size: number): T[][] {
  const chunks: T[][] = [];
  for (let index = 0; index < values.length; index += size) {
    chunks.push(values.slice(index, index + size));
  }
  return chunks;
}

function formatSessionTime(value: unknown): string | null {
  if (
    value &&
    typeof value === 'object' &&
    'toDate' in value &&
    typeof (value as { toDate: () => Date }).toDate === 'function'
  ) {
    return (value as { toDate: () => Date }).toDate().toLocaleTimeString([], {
      hour: '2-digit',
      minute: '2-digit',
    });
  }

  if (typeof value === 'string') {
    return value;
  }

  return null;
}

export function EducatorEvidenceCapture() {
  const { user, profile, loading: authLoading } = useAuthContext();
  const siteId = resolveActiveSiteId(profile);

  const { capabilityList: capabilities, resolveTitle } = useCapabilities(siteId);
  const [siteLearners, setSiteLearners] = useState<LearnerOption[]>([]);
  const [todaySessions, setTodaySessions] = useState<SessionOption[]>([]);
  const [recentEvidence, setRecentEvidence] = useState<RecentEvidence[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);
  const [formError, setFormError] = useState<string | null>(null);

  // Form state
  const [selectedLearnerId, setSelectedLearnerId] = useState('');
  const [description, setDescription] = useState('');
  const [selectedCapabilityId, setSelectedCapabilityId] = useState('');
  const [phaseKey, setPhaseKey] = useState<EvidenceRecord['phaseKey']>(undefined);
  const [portfolioCandidate, setPortfolioCandidate] = useState(false);
  const [aiAssistanceNoted, setAiAssistanceNoted] = useState(false);
  const [selectedSessionOccurrenceId, setSelectedSessionOccurrenceId] = useState('');
  const [reviewingEvidence, setReviewingEvidence] = useState<RecentEvidence | null>(null);

  const selectedSession = useMemo(
    () =>
      todaySessions.find((session) => session.occurrenceId === selectedSessionOccurrenceId) ??
      todaySessions[0] ??
      null,
    [todaySessions, selectedSessionOccurrenceId]
  );

  const learners = useMemo(
    () => (selectedSession ? selectedSession.learners : siteLearners),
    [selectedSession, siteLearners]
  );

  const learnerNameMap = useMemo(() => {
    const map = new Map<string, string>();
    for (const learner of siteLearners) map.set(learner.uid, learner.displayName);
    for (const session of todaySessions) {
      for (const learner of session.learners) {
        map.set(learner.uid, learner.displayName);
      }
    }
    return map;
  }, [siteLearners, todaySessions]);

  const selectedCapability = useMemo(
    () => capabilities.find((c) => c.id === selectedCapabilityId) ?? null,
    [capabilities, selectedCapabilityId]
  );

  const loadData = useCallback(async () => {
    if (!siteId || !user) {
      setLoading(false);
      return;
    }
    setLoading(true);
    try {
      const todayStart = new Date();
      todayStart.setHours(0, 0, 0, 0);
      const todayEnd = new Date();
      todayEnd.setHours(23, 59, 59, 999);

      const [siteLearnerSnap, legacyLearnerSnap, evidenceSnap, occurrenceSnap] = await Promise.all([
        getDocs(
          query(
            usersCollection,
            where('siteIds', 'array-contains', siteId),
            where('role', '==', 'learner'),
            limit(200)
          )
        ),
        getDocs(
          query(
            usersCollection,
            where('studioId', '==', siteId),
            where('role', '==', 'learner'),
            limit(200)
          )
        ),
        getDocs(
          query(evidenceRecordsCollection, where('siteId', '==', siteId), orderBy('createdAt', 'desc'), limit(20))
        ),
        getDocs(
          query(
            sessionOccurrencesCollection,
            where('siteId', '==', siteId),
            where('educatorId', '==', user.uid),
            where('date', '>=', Timestamp.fromDate(todayStart)),
            where('date', '<=', Timestamp.fromDate(todayEnd))
          )
        ),
      ]);

      const occurrenceDocs = occurrenceSnap.docs.map((docSnap) => ({
        occurrenceId: docSnap.id,
        data: docSnap.data() as SessionOccurrenceRecord,
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
            getDocs(query(sessionsCollection, where(documentId(), 'in', ids)))
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

      const sessionMap = new Map<string, SessionRecord>();
      for (const sessionSnap of sessionBatchSnaps) {
        for (const sessionDoc of sessionSnap.docs) {
          sessionMap.set(sessionDoc.id, sessionDoc.data() as SessionRecord);
        }
      }

      const learnerMap = new Map<string, LearnerOption>();
      for (const learnerSnap of [siteLearnerSnap, legacyLearnerSnap]) {
        for (const learnerDoc of learnerSnap.docs) {
          const data = learnerDoc.data();
          const uid = typeof data.uid === 'string' && data.uid.trim().length > 0 ? data.uid : learnerDoc.id;
          if (!learnerMap.has(uid)) {
            learnerMap.set(uid, {
              uid,
              displayName: typeof data.displayName === 'string' && data.displayName.trim().length > 0
                ? data.displayName
                : uid,
            });
          }
        }
      }
      const learnerList = Array.from(learnerMap.values()).sort((left, right) =>
        left.displayName.localeCompare(right.displayName)
      );

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
          const statuses = attendanceMap.get(occurrenceId) ?? new Map<string, 'present' | 'late' | 'absent'>();
          statuses.set(learnerId, status);
          attendanceMap.set(occurrenceId, statuses);
        }
      }

      const loadedSessions = occurrenceDocs
        .map((entry) => {
          const sessionId = asString(entry.data['sessionId'], '');
          const sessionData = sessionMap.get(sessionId);
          const sessionEnrollments = Array.from(enrollmentMap.get(sessionId) ?? []);
          const attendanceStatuses = attendanceMap.get(entry.occurrenceId);
          const liveLearnerIds = attendanceStatuses
            ? Array.from(attendanceStatuses.entries())
                .filter(([, status]) => status === 'present' || status === 'late')
                .map(([learnerId]) => learnerId)
            : sessionEnrollments;
          const rosterSource: SessionOption['rosterSource'] = attendanceStatuses
            ? 'attendance'
            : liveLearnerIds.length > 0
              ? 'enrollment'
              : 'none';
          const learners = liveLearnerIds
            .map((learnerId) => ({
              uid: learnerId,
              displayName: learnerMap.get(learnerId)?.displayName ?? learnerId,
              attendanceStatus: attendanceStatuses?.get(learnerId),
            }))
            .sort((left, right) => left.displayName.localeCompare(right.displayName));
          const sessionTitle = asString(
            sessionData?.['title'] || sessionData?.['name'],
            sessionId ? `Session ${sessionId.slice(0, 6)}` : `Session ${entry.occurrenceId.slice(0, 6)}`
          );
          const startLabel = formatSessionTime(sessionData?.['startTime']);
          const endLabel = formatSessionTime(sessionData?.['endTime']);
          const timeLabel =
            startLabel && endLabel ? `${startLabel} – ${endLabel}` : startLabel ?? endLabel;
          return {
            occurrenceId: entry.occurrenceId,
            sessionId,
            status: asString(entry.data['status'] || sessionData?.['status'], 'scheduled'),
            label: timeLabel ? `${sessionTitle} • ${timeLabel}` : sessionTitle,
            rosterSource,
            learners,
          };
        })
        .sort((left, right) => left.label.localeCompare(right.label));

      setTodaySessions(loadedSessions);

      setSiteLearners(learnerList);

      const evidenceIds = evidenceSnap.docs.map((docSnap) => docSnap.id);
      const portfolioByEvidenceId = new Map<string, { id: string; source: string }>();
      if (evidenceIds.length > 0) {
        const portfolioSnap = await getDocs(
          query(
            portfolioItemsCollection,
            where('evidenceRecordIds', 'array-contains-any', evidenceIds)
          )
        );
        for (const portfolioDoc of portfolioSnap.docs) {
          const portfolioData = portfolioDoc.data();
          const portfolioSource = asString(portfolioData.source, '');
          const isRubricArtifact = portfolioSource.includes('rubric');
          const linkedEvidenceIds = Array.isArray(portfolioData.evidenceRecordIds)
            ? portfolioData.evidenceRecordIds
            : [];
          for (const evidenceId of linkedEvidenceIds) {
            const existing = portfolioByEvidenceId.get(evidenceId);
            if (!existing || (existing.source.includes('rubric') && !isRubricArtifact)) {
              portfolioByEvidenceId.set(evidenceId, {
                id: portfolioDoc.id,
                source: portfolioSource,
              });
            }
          }
        }
      }

      const learnerNames = new Map<string, string>();
      for (const learner of learnerList) learnerNames.set(learner.uid, learner.displayName);
      for (const session of loadedSessions) {
        for (const learner of session.learners) {
          learnerNames.set(learner.uid, learner.displayName);
        }
      }

      setRecentEvidence(
        evidenceSnap.docs.map((d) => {
          const data = d.data();
          return {
            id: d.id,
            learnerName: learnerNames.get(data.learnerId) ?? data.learnerId,
            learnerId: data.learnerId ?? '',
            portfolioItemId: portfolioByEvidenceId.get(d.id)?.id,
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
      alert('Failed to load data. Please try again.');
    } finally {
      setLoading(false);
    }
  }, [siteId, user]);

  useEffect(() => {
    if (!authLoading && siteId && user) void loadData();
  }, [authLoading, siteId, user, loadData]);

  useEffect(() => {
    if (todaySessions.length === 0) {
      setSelectedSessionOccurrenceId('');
      return;
    }

    if (todaySessions.some((session) => session.occurrenceId === selectedSessionOccurrenceId)) {
      return;
    }

    const preferredSession =
      todaySessions.find((session) => session.status === 'in_progress') ?? todaySessions[0];
    setSelectedSessionOccurrenceId(preferredSession.occurrenceId);
  }, [todaySessions, selectedSessionOccurrenceId]);

  useEffect(() => {
    if (!selectedLearnerId) return;
    if (learners.some((learner) => learner.uid === selectedLearnerId)) return;
    setSelectedLearnerId('');
  }, [learners, selectedLearnerId]);

  const resetForm = () => {
    setDescription('');
    setSelectedCapabilityId('');
    setPhaseKey(undefined);
    setPortfolioCandidate(false);
    setAiAssistanceNoted(false);
    setFormError(null);
    // Keep selectedLearnerId and selectedSessionOccurrenceId for quick successive logs
  };

  const handleSubmit = async () => {
    const trimmed = description.trim();
    if (!user || !siteId || !selectedLearnerId || !trimmed) return;
    if (portfolioCandidate && !selectedCapabilityId) {
      setFormError('Select a capability before flagging this observation as portfolio evidence.');
      return;
    }
    setSaving(true);
    setSuccessMessage(null);
    setFormError(null);

    const capabilityId = selectedCapability?.id ?? null;
    const mapped = !!capabilityId;

    try {
      const evidenceRef = await addDoc(evidenceRecordsCollection, {
        learnerId: selectedLearnerId,
        educatorId: user.uid,
        siteId,
        sessionOccurrenceId: selectedSession?.occurrenceId ?? undefined,
        description: trimmed,
        capabilityId: capabilityId ?? undefined,
        capabilityMapped: mapped,
        phaseKey,
        portfolioCandidate,
        aiAssistanceNoted,
        rubricStatus: 'pending' as const,
        growthStatus: 'pending' as const,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      } as unknown as Omit<EvidenceRecord, 'id'>);

      let portfolioItemId: string | undefined;
      if (portfolioCandidate) {
        const portfolioRef = await addDoc(portfolioItemsCollection, {
          learnerId: selectedLearnerId,
          siteId,
          title: `Observation: ${trimmed.slice(0, 60)}${trimmed.length > 60 ? '...' : ''}`,
          description: trimmed,
          pillarCodes: selectedCapability?.pillarCode ? [selectedCapability.pillarCode] : [],
          artifacts: [],
          evidenceRecordIds: [evidenceRef.id],
          capabilityIds: capabilityId ? [capabilityId] : [],
          capabilityTitles: capabilityId ? [resolveTitle(capabilityId)] : [],
          aiAssistanceUsed: false,
          aiDisclosureStatus: 'not-available',
          verificationStatus: 'pending',
          proofOfLearningStatus: 'missing',
          source: 'educator_observation',
          educatorId: user.uid,
          createdAt: serverTimestamp(),
        } as unknown as Omit<PortfolioItem, 'id'>);
        portfolioItemId = portfolioRef.id;
      }

      const learnerName = learnerNameMap.get(selectedLearnerId) ?? selectedLearnerId;
      setSuccessMessage(`Logged for ${learnerName}`);
      resetForm();

      // Prepend to recent evidence for instant feedback
      setRecentEvidence((prev: RecentEvidence[]) => [
        {
          id: `temp-${Date.now()}`,
          learnerName,
          learnerId: selectedLearnerId,
          portfolioItemId,
          description: trimmed,
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
      setSuccessMessage(null);
      alert('Failed to save evidence record. Please try again.');
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
      <div
        data-testid="evidence-capture-site-required"
        className="rounded-xl border border-amber-200 bg-amber-50 p-6 text-sm text-amber-900"
      >
        Select an active site before capturing evidence during live sessions.
      </div>
    );
  }

  const canSubmit =
    !!selectedLearnerId &&
    description.trim().length > 0 &&
    (!portfolioCandidate || !!selectedCapabilityId) &&
    !saving;

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
                {todaySessions.map((s) => (
                  <option key={s.occurrenceId} value={s.occurrenceId}>
                    {s.label}
                  </option>
                ))}
              </select>
            ) : (
              <p className="text-xs text-app-muted bg-app-surface rounded-md px-3 py-2 border border-app">
                No live session occurrence is available today. Evidence will be saved without a
                session link.
              </p>
            )}
          </label>

          {selectedSession && (
            <div
              className="rounded-md border border-app bg-app-canvas px-3 py-2 text-xs text-app-muted"
              data-testid="evidence-roster-source"
            >
              {selectedSession.rosterSource === 'attendance'
                ? 'Showing present learners from attendance for this session occurrence.'
                : selectedSession.rosterSource === 'enrollment'
                  ? 'Attendance is not recorded yet. Showing the enrolled learner roster for this session.'
                  : 'No enrolled learners were found for this session yet.'}
            </div>
          )}

          {/* Row 1: Learner + Phase */}
          <div className="grid gap-3 sm:grid-cols-2">
            <label className="space-y-1">
              <span className="text-xs font-medium text-app-muted">
                Learner {selectedSession ? '(live roster)' : '(active site)'} *
              </span>
              <select
                data-testid="evidence-learner"
                value={selectedLearnerId}
                onChange={(e) => setSelectedLearnerId(e.target.value)}
                disabled={learners.length === 0}
                className="w-full rounded-md border border-app bg-app-canvas px-3 py-2 text-sm text-app-foreground"
              >
                <option value="">
                  {selectedSession ? 'Select learner from this session' : 'Select learner'}
                </option>
                {learners.map((l) => (
                  <option key={l.uid} value={l.uid}>
                    {l.displayName}
                  </option>
                ))}
              </select>
              {selectedSession && learners.length === 0 ? (
                <p className="text-xs text-app-muted">
                  No learners are available from attendance or active enrollments for this session
                  yet.
                </p>
              ) : null}
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

            <div className="flex flex-col gap-2 justify-end pb-1">
              <label className="flex items-center gap-2 rounded-md border border-app bg-app-canvas px-3 py-2">
                <input
                  data-testid="evidence-portfolio"
                  type="checkbox"
                  checked={portfolioCandidate}
                  onChange={(e) => setPortfolioCandidate(e.target.checked)}
                />
                <span className="text-sm text-app-foreground">Portfolio candidate</span>
              </label>
              <label className="flex items-center gap-2 rounded-md border border-app bg-app-canvas px-3 py-2">
                <input
                  data-testid="evidence-ai-noted"
                  type="checkbox"
                  checked={aiAssistanceNoted}
                  onChange={(e) => setAiAssistanceNoted(e.target.checked)}
                />
                <span className="text-sm text-app-foreground">AI assistance noted</span>
              </label>
            </div>
          </div>

          {formError && (
            <p className="text-sm text-red-600" data-testid="evidence-form-error">
              {formError}
            </p>
          )}



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
            portfolioItemId={reviewingEvidence.portfolioItemId}
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
