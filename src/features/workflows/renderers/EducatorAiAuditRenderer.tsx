'use client';

import { useCallback, useEffect, useState } from 'react';
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
import { getTierForStage, getTierDescription } from '@/src/lib/policies/aiPolicyTierGate';
import type { StageId } from '@/src/types/schema';
import type { CustomRouteRendererProps } from '../customRouteRenderers';

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

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

export default function EducatorAiAuditRenderer({ ctx }: CustomRouteRendererProps) {
  const trackInteraction = useInteractionTracking();

  const [tab, setTab] = useState<ActiveTab>('ai-audit');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [learners, setLearners] = useState<LearnerRow[]>([]);
  const [interactions, setInteractions] = useState<AiInteractionRow[]>([]);
  const [summaries, setSummaries] = useState<LearnerAiSummary[]>([]);

  const siteId = ctx.profile?.siteIds?.[0] ?? null;

  const loadData = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      // Fetch learners and AI interaction logs in parallel
      const learnersQuery = siteId
        ? query(
            collection(firestore, 'users'),
            where('role', '==', 'learner'),
            where('siteIds', 'array-contains', siteId),
            limit(100)
          )
        : query(
            collection(firestore, 'users'),
            where('role', '==', 'learner'),
            limit(100)
          );

      const interactionsQuery = siteId
        ? query(
            collection(firestore, 'aiInteractionLogs'),
            where('siteId', '==', siteId),
            orderBy('createdAt', 'desc'),
            limit(200)
          )
        : query(
            collection(firestore, 'aiInteractionLogs'),
            orderBy('createdAt', 'desc'),
            limit(200)
          );

      const [learnersSnap, interactionsSnap] = await Promise.all([
        getDocs(learnersQuery),
        getDocs(interactionsQuery),
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

      setLearners(loadedLearners);
      setInteractions(loadedInteractions);

      // Build per-learner summaries
      const learnerMap: Record<string, LearnerRow> = {};
      for (const l of loadedLearners) learnerMap[l.id] = l;

      const summaryMap: Record<string, LearnerAiSummary> = {};
      for (const ix of loadedInteractions) {
        if (!summaryMap[ix.learnerId]) {
          const learner = learnerMap[ix.learnerId];
          const stageId = learner?.stageId ?? null;
          summaryMap[ix.learnerId] = {
            learnerId: ix.learnerId,
            learnerName: learner?.displayName ?? ix.learnerId,
            stageId,
            tier: getTierForStage(stageId ?? undefined),
            totalInteractions: 0,
            byMode: {},
            blocked: 0,
            helpfulCount: 0,
            revisedCount: 0,
          };
        }
        const s = summaryMap[ix.learnerId];
        s.totalInteractions++;
        s.byMode[ix.taskType] = (s.byMode[ix.taskType] || 0) + 1;
        if (ix.safetyOutcome === 'blocked') s.blocked++;
        if (ix.wasHelpful === true) s.helpfulCount++;
        if (ix.studentRevised === true) s.revisedCount++;
      }

      setSummaries(
        Object.values(summaryMap).sort(
          (a, b) => b.totalInteractions - a.totalInteractions
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

  return (
    <section className="space-y-6" data-testid="educator-ai-audit">
      <header className="rounded-xl border border-app bg-app-surface-raised p-6">
        <h1 className="text-2xl font-bold text-app-foreground">Learners & AI Audit</h1>
        <p className="mt-2 text-sm text-app-muted">
          View your learners and their AI usage with policy tier enforcement data.
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
              No AI interactions recorded yet.
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
                  className="flex items-center justify-between rounded-lg border border-app bg-app-surface p-3"
                >
                  <div>
                    <span className="text-sm font-medium text-app-foreground">
                      {l.displayName}
                    </span>
                    {l.email && (
                      <span className="ml-2 text-xs text-app-muted">({l.email})</span>
                    )}
                  </div>
                  <div className="flex gap-2 text-xs text-app-muted">
                    {l.stageId && (
                      <span className="rounded-full bg-app-canvas px-2 py-0.5">
                        {l.stageId}
                      </span>
                    )}
                    <span className="rounded-full bg-app-canvas px-2 py-0.5">
                      Tier {getTierForStage(l.stageId ?? undefined)}
                    </span>
                  </div>
                </li>
              ))}
            </ul>
          )}
        </div>
      )}
    </section>
  );
}
