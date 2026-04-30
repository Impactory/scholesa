'use client';

import { useCallback, useEffect, useState } from 'react';
import dynamic from 'next/dynamic';
import {
  collection,
  getDocs,
  orderBy,
  query,
  where,
  limit,
  type DocumentData,
  type QueryDocumentSnapshot,
} from 'firebase/firestore';
import { firestore } from '@/src/firebase/client-init';
import { Spinner } from '@/src/components/ui/Spinner';
import { useInteractionTracking } from '@/src/hooks/useTelemetry';
import { resolveActiveSiteId } from '@/src/lib/auth/activeSite';
import { getTierForStage, getTierDescription } from '@/src/lib/policies/aiPolicyTierGate';
import type { StageId } from '@/src/types/schema';
import type { CustomRouteRendererProps } from '../customRouteRenderers';

const EducatorFeedbackForm = dynamic(
  () => import('@/src/components/motivation/EducatorFeedbackForm').then((m) => m.EducatorFeedbackForm),
  { loading: () => <div className="p-4 text-xs text-app-muted">Loading form…</div> }
);

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

type ActiveTab = 'roster' | 'ai-audit';

interface LearnerRow {
  id: string;
  displayName: string;
  email: string;
  stageId: StageId | null;
}

interface AiInteractionRow {
  id: string;
  learnerId: string;
  taskType: string;
  policyMode: string;
  safetyOutcome: string;
  safetyReasonCode: string;
  gradeBand: string;
  wasHelpful: boolean | null;
  studentRevised: boolean | null;
  modelUsed: string;
  createdAt: string | null;
}

interface LearnerAiSummary {
  learnerId: string;
  learnerName: string;
  stageId: StageId | null;
  tier: string;
  totalInteractions: number;
  byMode: Record<string, number>;
  blocked: number;
  helpfulCount: number;
  revisedCount: number;
  miloosSupport: MiloOSSupportSummary;
}

interface MiloOSInteractionEventRow {
  id: string;
  learnerId: string;
  eventType: string;
  createdAt: string | null;
}

interface MiloOSSupportSummary {
  opened: number;
  used: number;
  explainBackSubmitted: number;
  pendingExplainBack: number;
  recentEventAt: string | null;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function toIso(value: unknown): string | null {
  if (value instanceof Date) return value.toISOString();
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

function createMiloOSSupportSummary(): MiloOSSupportSummary {
  return {
    opened: 0,
    used: 0,
    explainBackSubmitted: 0,
    pendingExplainBack: 0,
    recentEventAt: null,
  };
}

const MILOOS_SUPPORT_EVENT_TYPES = new Set([
  'ai_help_opened',
  'ai_help_used',
  'explain_it_back_submitted',
]);

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

export default function EducatorAiAuditRenderer({ ctx }: CustomRouteRendererProps) {
  const trackInteraction = useInteractionTracking();

  const [tab, setTab] = useState<ActiveTab>('ai-audit');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [learners, setLearners] = useState<LearnerRow[]>([]);
  const [_interactions, setInteractions] = useState<AiInteractionRow[]>([]);
  const [summaries, setSummaries] = useState<LearnerAiSummary[]>([]);
  const [openMotivationId, setOpenMotivationId] = useState<string | null>(null);
  const [motivationSavedIds, setMotivationSavedIds] = useState<Set<string>>(new Set());

  const siteId = resolveActiveSiteId(ctx.profile);

  const loadData = useCallback(async () => {
    if (!siteId) {
      setLearners([]);
      setInteractions([]);
      setSummaries([]);
      setLoading(false);
      return;
    }

    setLoading(true);
    setError(null);
    try {
      const learnersQuery = query(
        collection(firestore, 'users'),
        where('role', '==', 'learner'),
        where('siteIds', 'array-contains', siteId),
        limit(100)
      );

      const interactionsQuery = query(
        collection(firestore, 'aiInteractionLogs'),
        where('siteId', '==', siteId),
        orderBy('createdAt', 'desc'),
        limit(200)
      );

      const miloosEventsQuery = query(
        collection(firestore, 'interactionEvents'),
        where('siteId', '==', siteId),
        limit(500)
      );

      const [learnersSnap, interactionsSnap, miloosEventsSnap] = await Promise.all([
        getDocs(learnersQuery),
        getDocs(interactionsQuery),
        getDocs(miloosEventsQuery),
      ]);

      const loadedLearners: LearnerRow[] = learnersSnap.docs.map(
        (d: QueryDocumentSnapshot<DocumentData>) => {
          const data = d.data();
          return {
            id: d.id,
            displayName: asString(data.displayName, 'Unknown'),
            email: asString(data.email, ''),
            stageId: (data.stageId as StageId) || null,
          };
        }
      );

      const loadedInteractions: AiInteractionRow[] = interactionsSnap.docs.map(
        (d: QueryDocumentSnapshot<DocumentData>) => {
          const data = d.data();
          return {
            id: d.id,
            learnerId: asString(data.learnerId, ''),
            taskType: asString(data.taskType, 'unknown'),
            policyMode: asString(data.policyMode, ''),
            safetyOutcome: asString(data.safetyOutcome, 'unknown'),
            safetyReasonCode: asString(data.safetyReasonCode, ''),
            gradeBand: asString(data.gradeBand, ''),
            wasHelpful: typeof data.wasHelpful === 'boolean' ? data.wasHelpful : null,
            studentRevised: typeof data.studentRevised === 'boolean' ? data.studentRevised : null,
            modelUsed: asString(data.modelUsed, ''),
            createdAt: toIso(data.createdAt),
          };
        }
      );

      const learnerMap: Record<string, LearnerRow> = {};
      for (const learner of loadedLearners) learnerMap[learner.id] = learner;

      const loadedMiloOSEvents: MiloOSInteractionEventRow[] = miloosEventsSnap.docs
        .map((d: QueryDocumentSnapshot<DocumentData>) => {
          const data = d.data();
          const eventType = asString(data.eventType, 'unknown');
          const learnerId = asString(data.actorId, asString(data.learnerId, ''));
          return {
            id: d.id,
            learnerId,
            eventType,
            createdAt: toIso(data.createdAt) ?? toIso(data.timestamp),
          };
        })
        .filter((event) =>
          Boolean(learnerMap[event.learnerId]) && MILOOS_SUPPORT_EVENT_TYPES.has(event.eventType)
        );

      setLearners(loadedLearners);
      setInteractions(loadedInteractions);

      // Build per-learner summaries
      const summaryMap: Record<string, LearnerAiSummary> = {};

      const ensureSummary = (learnerId: string): LearnerAiSummary | null => {
        if (!learnerId) return null;
        if (!summaryMap[learnerId]) {
          const learner = learnerMap[learnerId];
          const stageId = learner?.stageId ?? null;
          summaryMap[learnerId] = {
            learnerId,
            learnerName: learner?.displayName ?? learnerId,
            stageId,
            tier: getTierForStage(stageId ?? undefined),
            totalInteractions: 0,
            byMode: {},
            blocked: 0,
            helpfulCount: 0,
            revisedCount: 0,
            miloosSupport: createMiloOSSupportSummary(),
          };
        }
        return summaryMap[learnerId];
      };

      for (const interaction of loadedInteractions) {
        const summary = ensureSummary(interaction.learnerId);
        if (!summary) continue;
        summary.totalInteractions++;
        summary.byMode[interaction.taskType] = (summary.byMode[interaction.taskType] || 0) + 1;
        if (interaction.safetyOutcome === 'blocked') summary.blocked++;
        if (interaction.wasHelpful === true) summary.helpfulCount++;
        if (interaction.studentRevised === true) summary.revisedCount++;
      }

      for (const event of loadedMiloOSEvents) {
        const summary = ensureSummary(event.learnerId);
        if (!summary) continue;
        if (event.eventType === 'ai_help_opened') summary.miloosSupport.opened++;
        if (event.eventType === 'ai_help_used') summary.miloosSupport.used++;
        if (event.eventType === 'explain_it_back_submitted') {
          summary.miloosSupport.explainBackSubmitted++;
        }
        if (
          event.createdAt &&
          (!summary.miloosSupport.recentEventAt || event.createdAt > summary.miloosSupport.recentEventAt)
        ) {
          summary.miloosSupport.recentEventAt = event.createdAt;
        }
      }

      for (const summary of Object.values(summaryMap)) {
        summary.miloosSupport.pendingExplainBack = Math.max(
          summary.miloosSupport.opened - summary.miloosSupport.explainBackSubmitted,
          0
        );
      }

      setSummaries(
        Object.values(summaryMap).sort(
          (a, b) =>
            b.miloosSupport.pendingExplainBack - a.miloosSupport.pendingExplainBack ||
            b.miloosSupport.opened + b.totalInteractions - (a.miloosSupport.opened + a.totalInteractions)
        )
      );

      trackInteraction('feature_discovered', { cta: 'ai_audit_loaded' });
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load AI audit data.');
    } finally {
      setLoading(false);
    }
  }, [siteId, trackInteraction]);

  useEffect(() => {
    void loadData();
  }, [loadData]);

  if (!siteId) {
    return (
      <section
        className="rounded-xl border border-amber-200 bg-amber-50 p-8 text-center text-sm text-amber-900"
        data-testid="educator-ai-audit-site-required"
      >
        <p className="font-semibold">Active site required</p>
        <p className="mt-1 text-amber-700">
          Select an active site before reviewing learner AI and MiloOS support provenance.
        </p>
      </section>
    );
  }

  return (
    <section className="space-y-6" data-testid="educator-ai-audit">
      <header className="rounded-xl border border-app bg-app-surface-raised p-6">
        <h1 className="text-2xl font-bold text-app-foreground">Learners & AI Audit</h1>
        <p className="mt-2 text-sm text-app-muted">
          View your learners, AI usage, and MiloOS explain-back gaps with policy tier enforcement data.
        </p>
        <div className="mt-3 flex items-center gap-3">
          <div className="flex rounded-md border border-app overflow-hidden">
            {(['ai-audit', 'roster'] as ActiveTab[]).map((t) => (
              <button
                key={t}
                type="button"
                onClick={() => setTab(t)}
                className={`px-3 py-1.5 text-xs font-medium ${
                  tab === t
                    ? 'bg-primary text-primary-foreground'
                    : 'bg-app-canvas text-app-muted hover:text-app-foreground'
                }`}
                data-testid={`tab-${t}`}
              >
                {t === 'ai-audit' ? 'AI Audit' : 'Learner Roster'}
              </button>
            ))}
          </div>
          <button
            type="button"
            onClick={() => void loadData()}
            className="rounded-md border border-app px-3 py-1.5 text-xs font-medium text-app-foreground hover:bg-app-canvas"
          >
            Refresh
          </button>
        </div>
      </header>

      {error && (
        <div className="rounded-xl border border-red-200 bg-red-50 p-4 text-sm text-red-700">
          {error}
        </div>
      )}

      {loading ? (
        <div className="flex min-h-[240px] items-center justify-center rounded-xl border border-app bg-app-surface">
          <div className="flex items-center gap-2 text-app-muted">
            <Spinner />
            <span>Loading...</span>
          </div>
        </div>
      ) : tab === 'ai-audit' ? (
        /* ---- AI Audit Tab ---- */
        <div className="space-y-4" data-testid="ai-audit-tab">
          {summaries.length === 0 ? (
            <div className="rounded-xl border border-app bg-app-surface p-8 text-center text-sm text-app-muted">
              No AI interactions or MiloOS support events recorded yet.
            </div>
          ) : (
            <div className="space-y-3">
              {summaries.map((s) => (
                <div
                  key={s.learnerId}
                  className="rounded-xl border border-app bg-app-surface-raised p-4 space-y-2"
                  data-testid={`audit-row-${s.learnerId}`}
                >
                  <div className="flex items-start justify-between gap-3">
                    <div>
                      <h3 className="text-sm font-semibold text-app-foreground">
                        {s.learnerName}
                      </h3>
                      <p className="text-xs text-app-muted">
                        Stage: {s.stageId ?? 'unassigned'} &middot; Tier {s.tier}
                      </p>
                    </div>
                    <span className="rounded-full bg-app-canvas px-3 py-0.5 text-xs font-medium text-app-foreground">
                      {s.totalInteractions} interactions
                    </span>
                  </div>

                  {/* Mode breakdown */}
                  <div className="flex flex-wrap gap-2">
                    {Object.entries(s.byMode).map(([mode, count]) => (
                      <span
                        key={mode}
                        className="rounded-md bg-app-canvas px-2 py-0.5 text-xs text-app-muted"
                      >
                        {mode}: {count}
                      </span>
                    ))}
                    {s.blocked > 0 && (
                      <span className="rounded-md bg-red-100 px-2 py-0.5 text-xs font-medium text-red-700">
                        {s.blocked} blocked
                      </span>
                    )}
                  </div>

                  {/* Outcome metrics */}
                  <div className="flex gap-4 text-xs text-app-muted">
                    <span>
                      Helpful: {s.helpfulCount}/{s.totalInteractions}
                    </span>
                    <span>
                      Revised after: {s.revisedCount}
                    </span>
                    <span title={getTierDescription(s.tier as 'A' | 'B' | 'C' | 'D')}>
                      Policy: Tier {s.tier}
                    </span>
                  </div>

                  <div
                    className="rounded-lg border border-indigo-100 bg-indigo-50 p-3 text-xs text-indigo-900"
                    data-testid={`miloos-support-${s.learnerId}`}
                  >
                    <div className="flex flex-wrap items-center justify-between gap-2">
                      <p className="font-medium">MiloOS support provenance</p>
                      {s.miloosSupport.pendingExplainBack > 0 ? (
                        <span className="rounded-full bg-red-100 px-2 py-0.5 font-medium text-red-700">
                          {s.miloosSupport.pendingExplainBack} explain-back pending
                        </span>
                      ) : (
                        <span className="rounded-full bg-green-100 px-2 py-0.5 font-medium text-green-700">
                          Explain-back current
                        </span>
                      )}
                    </div>
                    <div className="mt-2 grid grid-cols-2 gap-2 md:grid-cols-4">
                      <span>Opened: {s.miloosSupport.opened}</span>
                      <span>Used: {s.miloosSupport.used}</span>
                      <span>Explain-backs: {s.miloosSupport.explainBackSubmitted}</span>
                      <span>Pending: {s.miloosSupport.pendingExplainBack}</span>
                    </div>
                    <p className="mt-2 text-indigo-800">
                      These are support signals and verification gaps, not capability mastery.
                    </p>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      ) : (
        /* ---- Roster Tab ---- */
        <div className="space-y-3" data-testid="roster-tab">
          {learners.length === 0 ? (
            <div className="rounded-xl border border-app bg-app-surface p-8 text-center text-sm text-app-muted">
              No learners found for this site.
            </div>
          ) : (
            <ul className="space-y-2">
              {learners.map((l) => (
                <li
                  key={l.id}
                  className="rounded-lg border border-app bg-app-surface"
                >
                  <div className="flex items-center justify-between p-3">
                    <div>
                      <span className="text-sm font-medium text-app-foreground">
                        {l.displayName}
                      </span>
                      {l.email && (
                        <span className="ml-2 text-xs text-app-muted">({l.email})</span>
                      )}
                    </div>
                    <div className="flex items-center gap-2 text-xs text-app-muted">
                      {l.stageId && (
                        <span className="rounded-full bg-app-canvas px-2 py-0.5">
                          {l.stageId}
                        </span>
                      )}
                      <span className="rounded-full bg-app-canvas px-2 py-0.5">
                        Tier {getTierForStage(l.stageId ?? undefined)}
                      </span>
                      {motivationSavedIds.has(l.id) ? (
                        <span className="rounded-full bg-green-100 px-2 py-0.5 text-green-700">
                          ✓ Saved
                        </span>
                      ) : (
                        <button
                          type="button"
                          onClick={() =>
                            setOpenMotivationId((prev) => (prev === l.id ? null : l.id))
                          }
                          className="rounded-full bg-indigo-50 px-2 py-0.5 text-indigo-700 hover:bg-indigo-100"
                          data-testid={`log-motivation-${l.id}`}
                        >
                          {openMotivationId === l.id ? 'Cancel' : 'Log motivation'}
                        </button>
                      )}
                    </div>
                  </div>
                  {openMotivationId === l.id && siteId && (
                    <div
                      className="border-t border-app p-4"
                      data-testid={`motivation-form-${l.id}`}
                    >
                      <EducatorFeedbackForm
                        learnerId={l.id}
                        learnerName={l.displayName}
                        siteId={siteId}
                        onSuccess={() => {
                          setMotivationSavedIds((prev) => {
                          const next = new Set(prev);
                          next.add(l.id);
                          return next;
                        });
                          setOpenMotivationId(null);
                        }}
                        onCancel={() => setOpenMotivationId(null)}
                      />
                    </div>
                  )}
                </li>
              ))}
            </ul>
          )}
        </div>
      )}
    </section>
  );
}
