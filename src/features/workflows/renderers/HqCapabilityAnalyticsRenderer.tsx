'use client';

import { useCallback, useEffect, useState } from 'react';
import {
  collection,
  getDocs,
  orderBy,
  query,
  limit,
  type DocumentData,
  type QueryDocumentSnapshot,
} from 'firebase/firestore';
import { firestore } from '@/src/firebase/client-init';
import { Spinner } from '@/src/components/ui/Spinner';
import { useInteractionTracking } from '@/src/hooks/useTelemetry';
import {
  getLegacyPillarCompatibilityNote,
  getLegacyPillarFamilyLabel,
  normalizeLegacyPillarCode,
} from '@/src/lib/curriculum/architecture';
import type { CustomRouteRendererProps } from '../customRouteRenderers';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

type MasteryLevel = 'emerging' | 'developing' | 'proficient' | 'advanced';
type PillarCode = 'FUTURE_SKILLS' | 'LEADERSHIP_AGENCY' | 'IMPACT_INNOVATION';

interface MasteryRecord {
  learnerId: string;
  capabilityId: string;
  currentLevel: MasteryLevel;
  evidenceCount: number;
}

interface GrowthEvent {
  learnerId: string;
  capabilityId: string;
  fromLevel: MasteryLevel | null;
  toLevel: MasteryLevel;
  educatorId: string;
  createdAt: string | null;
}

interface CapabilityDef {
  id: string;
  name: string;
  pillarCode: PillarCode | string;
  domain: string;
}

interface PillarSummary {
  pillarCode: string;
  label: string;
  capabilityCount: number;
  learnerCount: number;
  distribution: Record<MasteryLevel, number>;
  avgScore: number;
  recentGrowthCount: number;
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

export default function HqCapabilityAnalyticsRenderer({ ctx: _ctx }: CustomRouteRendererProps) {
  const trackInteraction = useInteractionTracking();

  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [pillarSummaries, setPillarSummaries] = useState<PillarSummary[]>([]);
  const [totalLearners, setTotalLearners] = useState(0);
  const [totalCapabilities, setTotalCapabilities] = useState(0);
  const [totalGrowthEvents, setTotalGrowthEvents] = useState(0);
  const [recentGrowth, setRecentGrowth] = useState<GrowthEvent[]>([]);

  const loadData = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      // Fetch capabilities, mastery records, and recent growth events in parallel
      const [capSnap, masterySnap, growthSnap] = await Promise.all([
        getDocs(query(collection(firestore, 'capabilities'), orderBy('name', 'asc'), limit(200))),
        getDocs(query(collection(firestore, 'capabilityMastery'), limit(500))),
        getDocs(
          query(
            collection(firestore, 'capabilityGrowthEvents'),
            orderBy('createdAt', 'desc'),
            limit(100)
          )
        ),
      ]);

      // Parse capabilities
      const capabilities: Record<string, CapabilityDef> = {};
      capSnap.docs.forEach((d: QueryDocumentSnapshot<DocumentData>) => {
        const data = d.data();
        capabilities[d.id] = {
          id: d.id,
          name: asString(data.name, d.id),
          pillarCode: asString(data.pillarCode, 'FUTURE_SKILLS'),
          domain: asString(data.domain, 'technical'),
        };
      });

      // Parse mastery records
      const masteries: MasteryRecord[] = masterySnap.docs.map(
        (d: QueryDocumentSnapshot<DocumentData>) => {
          const data = d.data();
          return {
            learnerId: asString(data.learnerId, ''),
            capabilityId: asString(data.capabilityId, ''),
            currentLevel: (data.currentLevel as MasteryLevel) || 'emerging',
            evidenceCount: typeof data.evidenceCount === 'number' ? data.evidenceCount : 0,
          };
        }
      );

      // Parse growth events
      const growthEvents: GrowthEvent[] = growthSnap.docs.map(
        (d: QueryDocumentSnapshot<DocumentData>) => {
          const data = d.data();
          return {
            learnerId: asString(data.learnerId, ''),
            capabilityId: asString(data.capabilityId, ''),
            fromLevel: (data.fromLevel as MasteryLevel) || null,
            toLevel: (data.toLevel as MasteryLevel) || 'emerging',
            educatorId: asString(data.educatorId, ''),
            createdAt: toIso(data.createdAt),
          };
        }
      );

      // Aggregate by pillar
      const pillarMap: Record<string, PillarSummary> = {};
      const uniqueLearners = new Set<string>();
      const uniqueCapabilities = new Set<string>();

      for (const m of masteries) {
        uniqueLearners.add(m.learnerId);
        uniqueCapabilities.add(m.capabilityId);
        const cap = capabilities[m.capabilityId];
        const pillar = cap?.pillarCode ?? 'FUTURE_SKILLS';

        if (!pillarMap[pillar]) {
          const normalizedPillar = normalizeLegacyPillarCode(pillar);
          pillarMap[pillar] = {
            pillarCode: pillar,
            label: normalizedPillar ? getLegacyPillarFamilyLabel(normalizedPillar) : pillar,
            capabilityCount: 0,
            learnerCount: 0,
            distribution: { emerging: 0, developing: 0, proficient: 0, advanced: 0 },
            avgScore: 0,
            recentGrowthCount: 0,
          };
        }
        pillarMap[pillar].distribution[m.currentLevel]++;
      }

      // Count capabilities per pillar
      const pillarCapIds: Record<string, Set<string>> = {};
      const pillarLearnerIds: Record<string, Set<string>> = {};
      for (const m of masteries) {
        const cap = capabilities[m.capabilityId];
        const pillar = cap?.pillarCode ?? 'FUTURE_SKILLS';
        if (!pillarCapIds[pillar]) pillarCapIds[pillar] = new Set();
        if (!pillarLearnerIds[pillar]) pillarLearnerIds[pillar] = new Set();
        pillarCapIds[pillar].add(m.capabilityId);
        pillarLearnerIds[pillar].add(m.learnerId);
      }

      // Count recent growth per pillar
      for (const g of growthEvents) {
        const cap = capabilities[g.capabilityId];
        const pillar = cap?.pillarCode ?? 'FUTURE_SKILLS';
        if (pillarMap[pillar]) {
          pillarMap[pillar].recentGrowthCount++;
        }
      }

      // Compute averages
      for (const key of Object.keys(pillarMap)) {
        const p = pillarMap[key];
        const total =
          p.distribution.emerging +
          p.distribution.developing +
          p.distribution.proficient +
          p.distribution.advanced;
        if (total > 0) {
          p.avgScore =
            (p.distribution.emerging * 1 +
              p.distribution.developing * 2 +
              p.distribution.proficient * 3 +
              p.distribution.advanced * 4) /
            total;
        }
        p.capabilityCount = pillarCapIds[key]?.size ?? 0;
        p.learnerCount = pillarLearnerIds[key]?.size ?? 0;
      }

      setPillarSummaries(Object.values(pillarMap));
      setTotalLearners(uniqueLearners.size);
      setTotalCapabilities(uniqueCapabilities.size);
      setTotalGrowthEvents(growthEvents.length);
      setRecentGrowth(growthEvents.slice(0, 10));

      trackInteraction('feature_discovered', { cta: 'capability_analytics_loaded' });
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load analytics.');
    } finally {
      setLoading(false);
    }
  }, [trackInteraction]);

  useEffect(() => {
    void loadData();
  }, [loadData]);

  // ---- Render ----
  return (
    <section className="space-y-6" data-testid="hq-capability-analytics">
      <header className="rounded-xl border border-app bg-app-surface-raised p-6">
        <h1 className="text-2xl font-bold text-app-foreground">Capability Analytics</h1>
        <p className="mt-2 text-sm text-app-muted">
          Platform-wide capability mastery distribution, growth trends, and evidence coverage across
          legacy curriculum families.
        </p>
        <div className="mt-3 flex items-center gap-3">
          <button
            type="button"
            onClick={() => void loadData()}
            className="rounded-md border border-app px-3 py-1.5 text-xs font-medium text-app-foreground hover:bg-app-canvas"
            data-testid="refresh-analytics"
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
            <span>Loading analytics...</span>
          </div>
        </div>
      ) : (
        <>
          {/* KPI Cards */}
          <div className="grid grid-cols-2 gap-4 sm:grid-cols-4" data-testid="kpi-cards">
            <div className="rounded-xl border border-app bg-app-surface-raised p-4 text-center">
              <p className="text-2xl font-bold text-app-foreground">{totalLearners}</p>
              <p className="text-xs text-app-muted">Learners Assessed</p>
            </div>
            <div className="rounded-xl border border-app bg-app-surface-raised p-4 text-center">
              <p className="text-2xl font-bold text-app-foreground">{totalCapabilities}</p>
              <p className="text-xs text-app-muted">Capabilities Tracked</p>
            </div>
            <div className="rounded-xl border border-app bg-app-surface-raised p-4 text-center">
              <p className="text-2xl font-bold text-app-foreground">{totalGrowthEvents}</p>
              <p className="text-xs text-app-muted">Growth Events</p>
            </div>
            <div className="rounded-xl border border-app bg-app-surface-raised p-4 text-center">
              <p className="text-2xl font-bold text-app-foreground">
                {pillarSummaries.length}
              </p>
              <p className="text-xs text-app-muted">Legacy Families Active</p>
            </div>
          </div>

          {/* Legacy Family Breakdown */}
          <div className="space-y-4" data-testid="pillar-breakdown">
            <h2 className="text-lg font-semibold text-app-foreground">
              Mastery by Legacy Family
            </h2>
            <p className="text-sm text-app-muted">
              These compatibility buckets roll up the live six-strand curriculum.
            </p>
            {pillarSummaries.length === 0 ? (
              <p className="text-sm text-app-muted">
                No capability mastery data recorded yet.
              </p>
            ) : (
              pillarSummaries.map((pillar) => {
                const compatibilityNote = getLegacyPillarCompatibilityNote(pillar.pillarCode);
                const total =
                  pillar.distribution.emerging +
                  pillar.distribution.developing +
                  pillar.distribution.proficient +
                  pillar.distribution.advanced;
                return (
                  <div
                    key={pillar.pillarCode}
                    className="rounded-xl border border-app bg-app-surface-raised p-5 space-y-3"
                    data-testid={`pillar-${pillar.pillarCode}`}
                  >
                    <div className="flex items-start justify-between">
                      <div>
                        <h3 className="text-base font-semibold text-app-foreground">
                          {pillar.label}
                        </h3>
                        <p className="text-xs text-app-muted">
                          {pillar.capabilityCount} capabilities &middot;{' '}
                          {pillar.learnerCount} learners &middot;{' '}
                          {pillar.recentGrowthCount} recent growth events
                        </p>
                        {compatibilityNote && (
                          <p className="mt-1 text-xs text-app-muted">{compatibilityNote}</p>
                        )}
                      </div>
                      <span className="rounded-full bg-app-canvas px-3 py-1 text-sm font-semibold text-app-foreground">
                        {pillar.avgScore.toFixed(1)} avg
                      </span>
                    </div>

                    {/* Distribution bar */}
                    {total > 0 && (
                      <div className="space-y-1">
                        <div className="flex h-6 w-full overflow-hidden rounded-full">
                          {pillar.distribution.advanced > 0 && (
                            <div
                              className="bg-green-500"
                              style={{
                                width: `${(pillar.distribution.advanced / total) * 100}%`,
                              }}
                              title={`Advanced: ${pillar.distribution.advanced}`}
                            />
                          )}
                          {pillar.distribution.proficient > 0 && (
                            <div
                              className="bg-blue-500"
                              style={{
                                width: `${(pillar.distribution.proficient / total) * 100}%`,
                              }}
                              title={`Proficient: ${pillar.distribution.proficient}`}
                            />
                          )}
                          {pillar.distribution.developing > 0 && (
                            <div
                              className="bg-amber-400"
                              style={{
                                width: `${(pillar.distribution.developing / total) * 100}%`,
                              }}
                              title={`Developing: ${pillar.distribution.developing}`}
                            />
                          )}
                          {pillar.distribution.emerging > 0 && (
                            <div
                              className="bg-gray-300"
                              style={{
                                width: `${(pillar.distribution.emerging / total) * 100}%`,
                              }}
                              title={`Emerging: ${pillar.distribution.emerging}`}
                            />
                          )}
                        </div>
                        <div className="flex flex-wrap gap-3 text-xs text-app-muted">
                          <span className="flex items-center gap-1">
                            <span className="inline-block h-2.5 w-2.5 rounded-full bg-green-500" />
                            Advanced ({pillar.distribution.advanced})
                          </span>
                          <span className="flex items-center gap-1">
                            <span className="inline-block h-2.5 w-2.5 rounded-full bg-blue-500" />
                            Proficient ({pillar.distribution.proficient})
                          </span>
                          <span className="flex items-center gap-1">
                            <span className="inline-block h-2.5 w-2.5 rounded-full bg-amber-400" />
                            Developing ({pillar.distribution.developing})
                          </span>
                          <span className="flex items-center gap-1">
                            <span className="inline-block h-2.5 w-2.5 rounded-full bg-gray-300" />
                            Emerging ({pillar.distribution.emerging})
                          </span>
                        </div>
                      </div>
                    )}
                  </div>
                );
              })
            )}
          </div>

          {/* Recent Growth Timeline */}
          <div className="space-y-3" data-testid="recent-growth">
            <h2 className="text-lg font-semibold text-app-foreground">
              Recent Growth Events
            </h2>
            {recentGrowth.length === 0 ? (
              <p className="text-sm text-app-muted">No growth events recorded yet.</p>
            ) : (
              <ul className="space-y-2">
                {recentGrowth.map((event, i) => (
                  <li
                    key={`${event.learnerId}-${event.capabilityId}-${i}`}
                    className="flex items-center gap-3 rounded-lg border border-app bg-app-surface p-3 text-sm"
                  >
                    <span className="shrink-0 rounded-full bg-green-100 px-2 py-0.5 text-xs font-medium text-green-800">
                      {event.fromLevel ?? '—'} → {event.toLevel}
                    </span>
                    <span className="flex-1 text-app-foreground truncate">
                      {event.capabilityId}
                    </span>
                    <span className="shrink-0 text-xs text-app-muted">
                      {event.createdAt
                        ? new Date(event.createdAt).toLocaleDateString()
                        : ''}
                    </span>
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
