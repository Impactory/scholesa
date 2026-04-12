'use client';

import { useCallback, useEffect, useState } from 'react';
import {
  collection,
  doc,
  getDoc,
  getDocs,
  orderBy,
  query,
  serverTimestamp,
  updateDoc,
  where,
  type DocumentData,
  type QueryDocumentSnapshot,
} from 'firebase/firestore';
import { httpsCallable } from 'firebase/functions';
import { firestore, functions } from '@/src/firebase/client-init';
import { rubricTemplatesCollection } from '@/src/firebase/firestore/collections';
import { Spinner } from '@/src/components/ui/Spinner';
import { useInteractionTracking } from '@/src/hooks/useTelemetry';
import {
  RubricManager,
  type AssessmentRubric,
  type RubricCriterion,
  type RubricLevel as RubricLevelType,
} from '@/src/lib/ai/rubricManager';
import type { RubricTemplate } from '@/src/types/schema';
import type { CustomRouteRendererProps } from '../customRouteRenderers';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

type SimpleLevelName = 'Emerging' | 'Developing' | 'Proficient' | 'Advanced';

const FALLBACK_LEVELS: { value: SimpleLevelName; score: number }[] = [
  { value: 'Emerging', score: 1 },
  { value: 'Developing', score: 2 },
  { value: 'Proficient', score: 3 },
  { value: 'Advanced', score: 4 },
];

interface MissionAttempt {
  id: string;
  learnerId: string;
  missionId: string;
  status: string;
  content: string;
  attachmentUrls: string[];
  aiDisclosure: boolean;
  aiToolsUsed: string | null;
  submittedAt: string | null;
  capabilityId: string | null;
}

interface LearnerInfo {
  displayName: string;
  email: string;
}

interface MissionInfo {
  title: string;
  capabilityId: string | null;
  siteId: string | null;
  grade: number | null;
}

/** Per-criterion score entry */
interface CriterionScore {
  criterionName: string;
  levelName: string;
  score: number;
  weight: number;
}

interface RubricFormState {
  /** Used when no structured rubric is available (fallback mode) */
  level: SimpleLevelName;
  feedback: string;
  proofVerified: boolean;
  /** Per-criterion scores when a structured rubric is loaded */
  criterionScores: Record<string, CriterionScore>;
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
  if (typeof value === 'number') return new Date(value).toISOString();
  return null;
}

function asString(value: unknown, fallback: string): string {
  return typeof value === 'string' && value.trim().length > 0 ? value.trim() : fallback;
}

function formatDate(iso: string | null): string {
  if (!iso) return 'Unknown date';
  try {
    return new Date(iso).toLocaleDateString(undefined, {
      year: 'numeric',
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
// Component
// ---------------------------------------------------------------------------

export default function EducatorEvidenceReviewRenderer({ ctx }: CustomRouteRendererProps) {
  const trackInteraction = useInteractionTracking();

  const [attempts, setAttempts] = useState<MissionAttempt[]>([]);
  const [learners, setLearners] = useState<Record<string, LearnerInfo>>({});
  const [missions, setMissions] = useState<Record<string, MissionInfo>>({});
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState<string | null>(null);

  // Rubric form: keyed by attempt id
  const [rubricOpen, setRubricOpen] = useState<string | null>(null);
  const [rubricForm, setRubricForm] = useState<RubricFormState>({
    level: 'Proficient',
    feedback: '',
    proofVerified: false,
    criterionScores: {},
  });

  // Loaded structured rubric for the currently open attempt
  const [activeRubric, setActiveRubric] = useState<AssessmentRubric | null>(null);
  const [rubricLoading, setRubricLoading] = useState(false);

  // Revision form: keyed by attempt id
  const [revisionOpen, setRevisionOpen] = useState<string | null>(null);
  const [revisionFeedback, setRevisionFeedback] = useState('');

  // ---- Checkpoint review state ----
  interface CheckpointItem {
    id: string;
    learnerId: string;
    siteId: string;
    answer: string;
    explainItBack: string | null;
    aiAssistanceUsed: boolean;
    aiAssistanceDetails: string | null;
    status: string;
    createdAt: string | null;
  }
  const [checkpoints, setCheckpoints] = useState<CheckpointItem[]>([]);
  const [checkpointLoading, setCheckpointLoading] = useState(false);
  const [checkpointSaving, setCheckpointSaving] = useState<string | null>(null);

  // ---- Data loading ----
  const loadAttempts = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const snap = await getDocs(
        query(
          collection(firestore, 'missionAttempts'),
          where('status', 'in', ['submitted', 'pending_review']),
          orderBy('submittedAt', 'desc')
        )
      );

      const loaded: MissionAttempt[] = snap.docs.map((d: QueryDocumentSnapshot<DocumentData>) => {
        const data = d.data();
        return {
          id: d.id,
          learnerId: asString(data.learnerId, ''),
          missionId: asString(data.missionId, ''),
          status: asString(data.status, 'submitted'),
          content: asString(data.content, ''),
          attachmentUrls: Array.isArray(data.attachmentUrls) ? data.attachmentUrls : [],
          aiDisclosure: Boolean(data.aiDisclosure),
          aiToolsUsed: typeof data.aiToolsUsed === 'string' ? data.aiToolsUsed : null,
          submittedAt: toIso(data.submittedAt),
          capabilityId: typeof data.capabilityId === 'string' ? data.capabilityId : null,
        };
      });

      setAttempts(loaded);

      // Fetch unique learner and mission info in parallel
      const learnerIds = Array.from(new Set(loaded.map((a) => a.learnerId).filter(Boolean)));
      const missionIds = Array.from(new Set(loaded.map((a) => a.missionId).filter(Boolean)));

      const [learnerResults, missionResults] = await Promise.all([
        Promise.all(
          learnerIds.map(async (uid) => {
            try {
              const userDoc = await getDoc(doc(firestore, 'users', uid));
              if (userDoc.exists()) {
                const data = userDoc.data();
                return [
                  uid,
                  {
                    displayName: asString(data.displayName, 'Unknown Learner'),
                    email: asString(data.email, ''),
                  },
                ] as const;
              }
            } catch (err) {
              console.warn('Failed to fetch learner profile:', uid, err);
            }
            return [uid, { displayName: 'Unknown Learner', email: '' }] as const;
          })
        ),
        Promise.all(
          missionIds.map(async (mid) => {
            try {
              const missionDoc = await getDoc(doc(firestore, 'missions', mid));
              if (missionDoc.exists()) {
                const data = missionDoc.data();
                return [
                  mid,
                  {
                    title: asString(data.title, mid),
                    capabilityId:
                      typeof data.capabilityId === 'string' ? data.capabilityId : null,
                    siteId: typeof data.siteId === 'string' ? data.siteId : null,
                    grade: typeof data.grade === 'number' ? data.grade : null,
                  },
                ] as const;
              }
            } catch (err) {
              console.warn('Failed to fetch mission:', mid, err);
            }
            return [mid, { title: mid, capabilityId: null, siteId: null, grade: null }] as const;
          })
        ),
      ]);

      setLearners(Object.fromEntries(learnerResults));
      setMissions(Object.fromEntries(missionResults));
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load submissions.');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void loadAttempts();
  }, [loadAttempts]);

  // ---- Checkpoint loading ----
  const loadCheckpoints = useCallback(async () => {
    setCheckpointLoading(true);
    try {
      const snap = await getDocs(
        query(
          collection(firestore, 'checkpointHistory'),
          where('status', '==', 'submitted'),
          orderBy('createdAt', 'desc')
        )
      );
      setCheckpoints(
        snap.docs.map((d) => {
          const data = d.data();
          return {
            id: d.id,
            learnerId: asString(data.learnerId, ''),
            siteId: asString(data.siteId, ''),
            answer: asString(data.answer, ''),
            explainItBack: typeof data.explainItBack === 'string' ? data.explainItBack : null,
            aiAssistanceUsed: Boolean(data.aiAssistanceUsed),
            aiAssistanceDetails: typeof data.aiAssistanceDetails === 'string' ? data.aiAssistanceDetails : null,
            status: asString(data.status, 'submitted'),
            createdAt: toIso(data.createdAt),
          };
        })
      );
    } catch (err) {
      console.warn('Failed to load checkpoints:', err);
    } finally {
      setCheckpointLoading(false);
    }
  }, []);

  useEffect(() => {
    void loadCheckpoints();
  }, [loadCheckpoints]);

  // ---- Mark checkpoint correct/incorrect ----
  const handleCheckpointReview = useCallback(
    async (cp: CheckpointItem, isCorrect: boolean) => {
      setCheckpointSaving(cp.id);
      try {
        // 1. Update checkpoint status
        await updateDoc(doc(firestore, 'checkpointHistory', cp.id), {
          isCorrect,
          status: 'reviewed',
          reviewedBy: ctx.uid,
          reviewedAt: serverTimestamp(),
        });

        // 2. If correct, call processCheckpointMasteryUpdate to trigger growth
        if (isCorrect) {
          const processCheckpoint = httpsCallable(functions, 'processCheckpointMasteryUpdate');
          await processCheckpoint({
            learnerId: cp.learnerId,
            siteId: cp.siteId,
            checkpointId: cp.id,
            skillIds: [], // checkpoint doesn't carry skill mapping yet
            passed: true,
            educatorId: ctx.uid,
          });
        }

        trackInteraction('feature_discovered', { feature: 'checkpoint_reviewed', checkpointId: cp.id, isCorrect });

        // Remove from list
        setCheckpoints((prev) => prev.filter((c) => c.id !== cp.id));
      } catch (err) {
        console.error('Failed to review checkpoint:', err);
        setError('Failed to review checkpoint. Please try again.');
      } finally {
        setCheckpointSaving(null);
      }
    },
    [ctx.uid, trackInteraction]
  );

  // ---- Load structured rubric for an attempt ----
  const loadRubricForAttempt = useCallback(
    async (attempt: MissionAttempt) => {
      setRubricLoading(true);
      setActiveRubric(null);
      try {
        const mission = missions[attempt.missionId];
        const rubric = await RubricManager.getActiveRubric({
          siteId: mission?.siteId || ctx.profile?.siteIds?.[0] || '*',
          missionId: attempt.missionId,
          grade: mission?.grade ?? undefined,
        });
        setActiveRubric(rubric);
        if (rubric) {
          // Pre-populate criterion scores with empty selections
          const initial: Record<string, CriterionScore> = {};
          for (const criterion of rubric.criteria) {
            initial[criterion.name] = {
              criterionName: criterion.name,
              levelName: '',
              score: 0,
              weight: criterion.weight,
            };
          }
          setRubricForm((prev: RubricFormState) => ({ ...prev, criterionScores: initial }));
        }
      } catch (err) {
        console.warn('Rubric loading failed, falling back to simple mode:', err);
      } finally {
        setRubricLoading(false);
      }
    },
    [missions, ctx.profile?.siteIds]
  );

  // ---- Apply rubric ----
  const handleApplyRubric = async (attempt: MissionAttempt) => {
    if (!rubricForm.feedback.trim()) return;
    setSaving(attempt.id);
    try {
      const capabilityId =
        attempt.capabilityId || missions[attempt.missionId]?.capabilityId || null;
      const siteId = missions[attempt.missionId]?.siteId || ctx.profile?.siteIds?.[0] || '';

      // Build scores array for the callable
      let callableScores: { criterionId: string; capabilityId: string; pillarCode: string; score: number; maxScore: number }[];

      if (activeRubric && Object.keys(rubricForm.criterionScores).length > 0) {
        const criterionScoresArray = (
          Object.values(rubricForm.criterionScores) as CriterionScore[]
        ).filter((cs) => cs.score > 0);
        if (criterionScoresArray.length === 0) return;

        callableScores = criterionScoresArray.map((cs) => ({
          criterionId: cs.criterionName,
          capabilityId: capabilityId || '',
          pillarCode: '',
          score: cs.score,
          maxScore: 4,
        }));
      } else {
        const fallbackScore = FALLBACK_LEVELS.find((l) => l.value === rubricForm.level)?.score ?? 3;
        callableScores = capabilityId
          ? [{
              criterionId: 'overall',
              capabilityId,
              pillarCode: '',
              score: fallbackScore,
              maxScore: 4,
            }]
          : [];
      }

      if (callableScores.length === 0) {
        setError('No capability linked to this mission. Cannot apply rubric without a capability.');
        setSaving(null);
        return;
      }

      // Call the server-side callable for atomic batch write:
      // rubricApplications + capabilityMastery + capabilityGrowthEvents + missionAttempt status
      const applyRubric = httpsCallable(functions, 'applyRubricToEvidence');
      await applyRubric({
        evidenceRecordIds: [],
        missionAttemptId: attempt.id,
        learnerId: attempt.learnerId,
        siteId,
        rubricId: activeRubric?.id ?? undefined,
        scores: callableScores,
      });

      trackInteraction('feature_discovered', {
        cta: 'rubric_applied',
        level: callableScores.length > 0
          ? (callableScores.reduce((s, c) => s + c.score, 0) / callableScores.length).toFixed(1)
          : undefined,
        missionId: attempt.missionId,
        rubricId: activeRubric?.id,
        criteriaCount: callableScores.length || undefined,
      });

      setRubricOpen(null);
      setActiveRubric(null);
      setRubricForm({
        level: 'Proficient',
        feedback: '',
        proofVerified: false,
        criterionScores: {},
      });
      await loadAttempts();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to apply rubric.');
    } finally {
      setSaving(null);
    }
  };

  // ---- Request revision ----
  const handleRequestRevision = async (attempt: MissionAttempt) => {
    if (!revisionFeedback.trim()) return;
    setSaving(attempt.id);
    try {
      await updateDoc(doc(firestore, 'missionAttempts', attempt.id), {
        status: 'revision',
        revisionFeedback: revisionFeedback.trim(),
        revisionRequestedBy: ctx.uid,
        revisionRequestedAt: serverTimestamp(),
      });

      trackInteraction('feature_discovered', {
        cta: 'revision_requested',
        missionId: attempt.missionId,
      });

      setRevisionOpen(null);
      setRevisionFeedback('');
      await loadAttempts();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to request revision.');
    } finally {
      setSaving(null);
    }
  };

  // ---- Render ----
  return (
    <section className="space-y-6" data-testid="educator-evidence-review">
      <header className="rounded-xl border border-app bg-app-surface-raised p-6">
        <h1 className="text-2xl font-bold text-app-foreground">Evidence Review</h1>
        <p className="mt-2 text-sm text-app-muted">
          Review learner mission submissions, apply rubrics, and record capability growth. Submissions
          awaiting your review appear below.
        </p>
        <div className="mt-3 flex items-center gap-3">
          <span className="rounded-full bg-app-canvas px-3 py-1 text-xs font-medium text-app-muted">
            {attempts.length} pending
          </span>
          <button
            type="button"
            onClick={() => void loadAttempts()}
            className="rounded-md border border-app px-3 py-1.5 text-xs font-medium text-app-foreground hover:bg-app-canvas"
            data-testid="refresh-submissions"
          >
            Refresh
          </button>
        </div>
      </header>

      {error && (
        <div
          className="rounded-xl border border-red-200 bg-red-50 p-4 text-sm text-red-700"
          data-testid="error-message"
        >
          {error}
          <button
            type="button"
            onClick={() => setError(null)}
            className="ml-3 text-xs font-medium underline"
          >
            Dismiss
          </button>
        </div>
      )}

      {loading ? (
        <div
          className="flex min-h-[240px] items-center justify-center rounded-xl border border-app bg-app-surface"
          data-testid="loading-state"
        >
          <div className="flex items-center gap-2 text-app-muted">
            <Spinner />
            <span>Loading submissions...</span>
          </div>
        </div>
      ) : attempts.length === 0 ? (
        <div
          className="rounded-xl border border-app bg-app-surface p-8 text-center text-app-muted"
          data-testid="empty-state"
        >
          No submissions awaiting review. Check back later or refresh.
        </div>
      ) : (
        <ul className="space-y-4" data-testid="submissions-list">
          {attempts.map((attempt: MissionAttempt) => {
            const learner = learners[attempt.learnerId];
            const mission = missions[attempt.missionId];
            const isRubricOpen = rubricOpen === attempt.id;
            const isRevisionOpen = revisionOpen === attempt.id;
            const isSaving = saving === attempt.id;

            return (
              <li
                key={attempt.id}
                className="rounded-xl border border-app bg-app-surface-raised p-5 space-y-4"
                data-testid={`submission-${attempt.id}`}
              >
                {/* Header row */}
                <div className="flex flex-wrap items-start justify-between gap-3">
                  <div className="space-y-1">
                    <h3 className="text-base font-semibold text-app-foreground">
                      {mission?.title ?? attempt.missionId}
                    </h3>
                    <p className="text-sm text-app-muted">
                      <span data-testid={`learner-name-${attempt.id}`}>
                        {learner?.displayName ?? 'Unknown Learner'}
                      </span>
                      {learner?.email && (
                        <span className="ml-1 text-xs text-app-muted">({learner.email})</span>
                      )}
                    </p>
                    <div className="flex flex-wrap items-center gap-2 text-xs">
                      <span
                        className={`rounded-full px-2 py-0.5 font-medium ${
                          attempt.status === 'pending_review'
                            ? 'bg-amber-100 text-amber-800'
                            : 'bg-blue-100 text-blue-800'
                        }`}
                        data-testid={`status-${attempt.id}`}
                      >
                        {attempt.status === 'pending_review' ? 'Pending Review' : 'Submitted'}
                      </span>
                      <span className="text-app-muted">{formatDate(attempt.submittedAt)}</span>
                      {attempt.aiDisclosure && (
                        <span
                          className="inline-flex items-center gap-1 rounded-full bg-purple-100 px-2 py-0.5 font-medium text-purple-800"
                          title={attempt.aiToolsUsed ? `Tools: ${attempt.aiToolsUsed}` : 'AI tools were used'}
                          data-testid={`ai-disclosure-${attempt.id}`}
                        >
                          AI Assisted
                          {attempt.aiToolsUsed && (
                            <span className="font-normal">({attempt.aiToolsUsed})</span>
                          )}
                        </span>
                      )}
                    </div>
                  </div>
                </div>

                {/* Submission content */}
                {attempt.content && (
                  <div
                    className="rounded-lg border border-app bg-app-canvas p-4 text-sm text-app-foreground whitespace-pre-wrap"
                    data-testid={`content-${attempt.id}`}
                  >
                    {attempt.content}
                  </div>
                )}

                {/* Evidence artifacts */}
                {attempt.attachmentUrls.length > 0 && (
                  <div className="space-y-2" data-testid={`attachments-${attempt.id}`}>
                    <span className="text-xs font-medium text-app-muted">
                      Evidence Artifacts ({attempt.attachmentUrls.length})
                    </span>
                    <div className="flex flex-wrap gap-2">
                      {attempt.attachmentUrls.map((url: string, i: number) => (
                        <a
                          key={i}
                          href={url}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="inline-flex items-center gap-1.5 rounded-md border border-app bg-app-canvas px-3 py-1.5 text-xs font-medium text-app-foreground hover:bg-app-surface"
                        >
                          Attachment {i + 1}
                        </a>
                      ))}
                    </div>
                  </div>
                )}

                {/* Action buttons */}
                {!isRubricOpen && !isRevisionOpen && (
                  <div className="flex gap-2 pt-1">
                    <button
                      type="button"
                      disabled={isSaving}
                      onClick={() => {
                        setRubricOpen(attempt.id);
                        setRevisionOpen(null);
                        setRubricForm({
                          level: 'Proficient',
                          feedback: '',
                          proofVerified: false,
                          criterionScores: {},
                        });
                        void loadRubricForAttempt(attempt);
                      }}
                      className="rounded-md bg-primary px-4 py-2 text-sm font-semibold text-primary-foreground hover:bg-primary/90 disabled:opacity-50"
                      data-testid={`apply-rubric-btn-${attempt.id}`}
                    >
                      Apply Rubric
                    </button>
                    <button
                      type="button"
                      disabled={isSaving}
                      onClick={() => {
                        setRevisionOpen(attempt.id);
                        setRubricOpen(null);
                        setRevisionFeedback('');
                      }}
                      className="rounded-md border border-app px-4 py-2 text-sm font-medium text-app-foreground hover:bg-app-canvas disabled:opacity-50"
                      data-testid={`request-revision-btn-${attempt.id}`}
                    >
                      Request Revision
                    </button>
                  </div>
                )}

                {/* Inline rubric form */}
                {isRubricOpen && (
                  <div
                    className="rounded-lg border border-app bg-app-surface p-4 space-y-4"
                    data-testid={`rubric-form-${attempt.id}`}
                  >
                    <h4 className="text-sm font-semibold text-app-foreground">Apply Rubric</h4>

                    {rubricLoading ? (
                      <div className="flex items-center gap-2 text-app-muted text-sm py-2">
                        <Spinner /> Loading rubric...
                      </div>
                    ) : activeRubric ? (
                      /* ---- Per-criterion scoring (structured rubric) ---- */
                      <div className="space-y-4" data-testid={`rubric-criteria-${attempt.id}`}>
                        <div className="rounded-md bg-app-canvas px-3 py-2 text-xs text-app-muted">
                          Rubric: <span className="font-medium text-app-foreground">{activeRubric.name}</span>
                          <span className="ml-2">v{activeRubric.version}</span>
                          {activeRubric.criteria.length > 0 && (
                            <span className="ml-2">
                              ({activeRubric.criteria.length} criteria)
                            </span>
                          )}
                        </div>

                        {activeRubric.criteria.map((criterion: RubricCriterion) => {
                          const currentScore = rubricForm.criterionScores[criterion.name];
                          return (
                            <div
                              key={criterion.name}
                              className="rounded-lg border border-app p-3 space-y-2"
                              data-testid={`criterion-${criterion.name}-${attempt.id}`}
                            >
                              <div className="flex items-start justify-between gap-2">
                                <div>
                                  <h5 className="text-sm font-semibold text-app-foreground">
                                    {criterion.name}
                                  </h5>
                                  <p className="text-xs text-app-muted">{criterion.description}</p>
                                </div>
                                <span className="shrink-0 rounded-full bg-app-canvas px-2 py-0.5 text-xs text-app-muted">
                                  {Math.round(criterion.weight * 100)}%
                                </span>
                              </div>
                              <div className="flex flex-wrap gap-1.5">
                                {criterion.levels.map((level: RubricLevelType) => {
                                  const isSelected = currentScore?.levelName === level.name;
                                  return (
                                    <button
                                      key={level.name}
                                      type="button"
                                      onClick={() =>
                                        setRubricForm((prev: RubricFormState) => ({
                                          ...prev,
                                          criterionScores: {
                                            ...prev.criterionScores,
                                            [criterion.name]: {
                                              criterionName: criterion.name,
                                              levelName: level.name,
                                              score: level.score,
                                              weight: criterion.weight,
                                            },
                                          },
                                        }))
                                      }
                                      title={level.description}
                                      className={`rounded-md px-3 py-1.5 text-xs font-medium transition-colors ${
                                        isSelected
                                          ? 'bg-primary text-primary-foreground ring-2 ring-primary/30'
                                          : 'bg-app-canvas text-app-muted hover:text-app-foreground hover:bg-app-surface-raised'
                                      }`}
                                      data-testid={`criterion-level-${criterion.name}-${level.score}-${attempt.id}`}
                                    >
                                      {level.name}
                                      <span className="ml-1 opacity-60">({level.score})</span>
                                    </button>
                                  );
                                })}
                              </div>
                              {/* Show selected level description */}
                              {currentScore?.levelName && (() => {
                                const selectedLevel = criterion.levels.find(
                                  (l: RubricLevelType) => l.name === currentScore.levelName
                                );
                                return selectedLevel ? (
                                  <p className="text-xs text-app-muted italic pl-1">
                                    {selectedLevel.description}
                                  </p>
                                ) : null;
                              })()}
                            </div>
                          );
                        })}

                        {/* Weighted score preview */}
                        {(() => {
                          const scored = (
                            Object.values(rubricForm.criterionScores) as CriterionScore[]
                          ).filter((cs) => cs.score > 0);
                          if (scored.length === 0) return null;
                          const totalWeight = scored.reduce((s, cs) => s + cs.weight, 0);
                          const weighted =
                            totalWeight > 0
                              ? scored.reduce((s, cs) => s + cs.score * cs.weight, 0) / totalWeight
                              : 0;
                          return (
                            <div className="rounded-md bg-app-canvas px-3 py-2 text-xs text-app-muted">
                              Weighted score:{' '}
                              <span className="font-semibold text-app-foreground">
                                {weighted.toFixed(2)}
                              </span>
                              <span className="ml-2">
                                ({scored.length}/{activeRubric.criteria.length} criteria scored)
                              </span>
                            </div>
                          );
                        })()}
                      </div>
                    ) : (
                      /* ---- Fallback: simple 4-level scoring ---- */
                      <div className="space-y-1">
                        <span className="text-xs font-medium text-app-muted">
                          Proficiency Level *
                        </span>
                        <div className="flex flex-wrap gap-2">
                          {FALLBACK_LEVELS.map(({ value }) => (
                            <button
                              key={value}
                              type="button"
                              onClick={() =>
                                setRubricForm((prev: RubricFormState) => ({ ...prev, level: value }))
                              }
                              className={`rounded-md px-3 py-1.5 text-sm font-medium ${
                                rubricForm.level === value
                                  ? 'bg-primary text-primary-foreground'
                                  : 'bg-app-canvas text-app-muted hover:text-app-foreground'
                              }`}
                              data-testid={`rubric-level-${value.toLowerCase()}-${attempt.id}`}
                            >
                              {value}
                            </button>
                          ))}
                        </div>
                        <p className="text-xs text-app-muted mt-1">
                          No structured rubric found for this mission. Using default levels.
                        </p>
                      </div>
                    )}

                    <label className="block space-y-1">
                      <span className="text-xs font-medium text-app-muted">Feedback *</span>
                      <textarea
                        value={rubricForm.feedback}
                        onChange={(e: React.ChangeEvent<HTMLTextAreaElement>) =>
                          setRubricForm((prev: RubricFormState) => ({
                            ...prev,
                            feedback: e.target.value,
                          }))
                        }
                        placeholder="Provide specific feedback on the evidence and demonstrated capability..."
                        className="w-full rounded-md border border-app bg-app-canvas px-3 py-2 text-sm text-app-foreground min-h-24"
                        data-testid={`rubric-feedback-${attempt.id}`}
                      />
                    </label>

                    <label className="flex items-center gap-2 text-sm text-app-foreground">
                      <input
                        type="checkbox"
                        checked={rubricForm.proofVerified}
                        onChange={(e: React.ChangeEvent<HTMLInputElement>) =>
                          setRubricForm((prev: RubricFormState) => ({
                            ...prev,
                            proofVerified: e.target.checked,
                          }))
                        }
                        className="rounded border-app"
                        data-testid={`rubric-proof-verified-${attempt.id}`}
                      />
                      Proof of learning verified
                    </label>

                    <div className="flex gap-2">
                      <button
                        type="button"
                        disabled={isSaving || !rubricForm.feedback.trim()}
                        onClick={() => void handleApplyRubric(attempt)}
                        className="rounded-md bg-primary px-4 py-2 text-sm font-semibold text-primary-foreground disabled:opacity-50"
                        data-testid={`rubric-submit-${attempt.id}`}
                      >
                        {isSaving ? 'Saving...' : 'Submit Review'}
                      </button>
                      <button
                        type="button"
                        disabled={isSaving}
                        onClick={() => {
                          setRubricOpen(null);
                          setActiveRubric(null);
                        }}
                        className="rounded-md border border-app px-3 py-2 text-sm text-app-foreground"
                      >
                        Cancel
                      </button>
                    </div>
                  </div>
                )}

                {/* Inline revision form */}
                {isRevisionOpen && (
                  <div
                    className="rounded-lg border border-app bg-app-surface p-4 space-y-4"
                    data-testid={`revision-form-${attempt.id}`}
                  >
                    <h4 className="text-sm font-semibold text-app-foreground">Request Revision</h4>

                    <label className="block space-y-1">
                      <span className="text-xs font-medium text-app-muted">
                        Revision Feedback *
                      </span>
                      <textarea
                        value={revisionFeedback}
                        onChange={(e: React.ChangeEvent<HTMLTextAreaElement>) => setRevisionFeedback(e.target.value)}
                        placeholder="Explain what needs to be revised or improved..."
                        className="w-full rounded-md border border-app bg-app-canvas px-3 py-2 text-sm text-app-foreground min-h-24"
                        data-testid={`revision-feedback-${attempt.id}`}
                      />
                    </label>

                    <div className="flex gap-2">
                      <button
                        type="button"
                        disabled={isSaving || !revisionFeedback.trim()}
                        onClick={() => void handleRequestRevision(attempt)}
                        className="rounded-md border border-amber-300 bg-amber-50 px-4 py-2 text-sm font-semibold text-amber-800 disabled:opacity-50"
                        data-testid={`revision-submit-${attempt.id}`}
                      >
                        {isSaving ? 'Saving...' : 'Send Revision Request'}
                      </button>
                      <button
                        type="button"
                        disabled={isSaving}
                        onClick={() => setRevisionOpen(null)}
                        className="rounded-md border border-app px-3 py-2 text-sm text-app-foreground"
                      >
                        Cancel
                      </button>
                    </div>
                  </div>
                )}
              </li>
            );
          })}
        </ul>
      )}

      {/* ---- Checkpoint Review Section ---- */}
      {(checkpoints.length > 0 || checkpointLoading) && (
        <div className="mt-8 space-y-4">
          <div className="flex items-center justify-between">
            <h2 className="text-lg font-semibold text-app-foreground">
              Pending Checkpoints
            </h2>
            <span className="rounded-full bg-app-canvas px-3 py-1 text-xs font-medium text-app-muted">
              {checkpoints.length} pending
            </span>
          </div>
          {checkpointLoading ? (
            <div className="flex items-center gap-2 text-app-muted text-sm">
              <Spinner /> Loading checkpoints...
            </div>
          ) : (
            <ul className="space-y-3">
              {checkpoints.map((cp) => {
                const cpSaving = checkpointSaving === cp.id;
                const learner = learners[cp.learnerId];
                return (
                  <li
                    key={cp.id}
                    className="rounded-xl border border-app bg-app-surface-raised p-4 space-y-3"
                  >
                    <div className="flex items-start justify-between gap-3">
                      <div className="space-y-1">
                        <p className="text-sm font-medium text-app-foreground">
                          {learner?.displayName ?? cp.learnerId}
                        </p>
                        <p className="text-xs text-app-muted">{formatDate(cp.createdAt)}</p>
                      </div>
                      <div className="flex items-center gap-1.5">
                        {cp.aiAssistanceUsed && (
                          <span
                            className="rounded-full bg-purple-100 px-2 py-0.5 text-xs font-medium text-purple-800"
                            title={cp.aiAssistanceDetails ?? 'AI tools were used'}
                          >
                            AI Assisted
                          </span>
                        )}
                        <span className="rounded-full bg-blue-100 px-2 py-0.5 text-xs font-medium text-blue-800">
                          Checkpoint
                        </span>
                      </div>
                    </div>
                    <div className="rounded-lg bg-app-canvas p-3 text-sm text-app-foreground">
                      {cp.answer}
                    </div>
                    {cp.explainItBack && (
                      <div className="rounded-lg border border-emerald-200 bg-emerald-50 p-3 text-sm text-emerald-800">
                        <span className="text-xs font-semibold uppercase tracking-wide text-emerald-600">
                          Explain-it-back
                        </span>
                        <p className="mt-1">{cp.explainItBack}</p>
                      </div>
                    )}
                    <div className="flex gap-2">
                      <button
                        type="button"
                        disabled={cpSaving}
                        onClick={() => void handleCheckpointReview(cp, true)}
                        className="rounded-md bg-green-600 px-4 py-2 text-sm font-semibold text-white hover:bg-green-700 disabled:opacity-50"
                      >
                        {cpSaving ? 'Saving...' : 'Correct'}
                      </button>
                      <button
                        type="button"
                        disabled={cpSaving}
                        onClick={() => void handleCheckpointReview(cp, false)}
                        className="rounded-md border border-red-300 bg-red-50 px-4 py-2 text-sm font-semibold text-red-800 hover:bg-red-100 disabled:opacity-50"
                      >
                        {cpSaving ? 'Saving...' : 'Incorrect'}
                      </button>
                    </div>
                  </li>
                );
              })}
            </ul>
          )}
        </div>
      )}
    </section>
  );
}
