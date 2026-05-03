'use client';

import { useCallback, useEffect, useState } from 'react';
import { getDocs, query, where, Timestamp } from 'firebase/firestore';
import { useAuthContext } from '@/src/firebase/auth/AuthProvider';
import {
  evidenceRecordsCollection,
  usersCollection,
} from '@/src/firebase/firestore/collections';
import { resolveActiveSiteId } from '@/src/lib/auth/activeSite';
import { RoleRouteGuard } from '@/src/components/auth/RoleRouteGuard';
import { Spinner } from '@/src/components/ui/Spinner';

interface EducatorMetric {
  educatorId: string;
  educatorName: string;
  evidenceCount: number;
  capabilityMappedCount: number;
  rubricAppliedCount: number;
}

interface HealthMetrics {
  totalLearners: number;
  totalEvidence: number;
  learnersWithEvidence: number;
  capabilityMappedRate: number;
  rubricAppliedRate: number;
  educatorMetrics: EducatorMetric[];
}

function pct(n: number, d: number): string {
  if (d === 0) return '—';
  return `${Math.round((n / d) * 100)}%`;
}

function HealthCard({ label, value, sub }: { label: string; value: string; sub?: string }) {
  return (
    <div className="rounded-lg border border-app bg-app-surface-raised p-4">
      <p className="text-xs font-medium text-app-muted">{label}</p>
      <p className="mt-1 text-2xl font-bold text-app-foreground">{value}</p>
      {sub && <p className="mt-0.5 text-xs text-app-muted">{sub}</p>}
    </div>
  );
}

export function SiteEvidenceHealthDashboard() {
  const { profile, loading: authLoading } = useAuthContext();
  const siteId = resolveActiveSiteId(profile);
  const [loading, setLoading] = useState(true);
  const [metrics, setMetrics] = useState<HealthMetrics | null>(null);
  const [period, setPeriod] = useState<'week' | 'month'>('week');

  const loadMetrics = useCallback(async () => {
    if (!siteId) {
      setMetrics(null);
      setLoading(false);
      return;
    }

    setLoading(true);

    try {
      const now = new Date();
      const periodStart = new Date();
      if (period === 'week') {
        periodStart.setDate(now.getDate() - 7);
      } else {
        periodStart.setDate(now.getDate() - 30);
      }
      periodStart.setHours(0, 0, 0, 0);

      if (process.env.NEXT_PUBLIC_E2E_TEST_MODE === '1') {
        const { getE2ECollection } = await import('@/src/testing/e2e/fakeWebBackend');
        const users = getE2ECollection('users');
        const learners = users.filter((user) => (
          user.role === 'learner' &&
          Array.isArray(user.siteIds) &&
          user.siteIds.includes(siteId)
        ));
        const educatorNames = new Map<string, string>();
        users
          .filter((user) => (
            user.role === 'educator' &&
            Array.isArray(user.siteIds) &&
            user.siteIds.includes(siteId)
          ))
          .forEach((user) => {
            const uid = typeof user.uid === 'string' ? user.uid : '';
            if (!uid) return;
            educatorNames.set(
              uid,
              typeof user.displayName === 'string' && user.displayName.trim().length > 0
                ? user.displayName
                : uid
            );
          });

        const learnerIds = new Set(
          learners
            .map((user) => (typeof user.uid === 'string' ? user.uid : ''))
            .filter(Boolean)
        );
        const evidence = getE2ECollection('evidenceRecords').filter((record) => {
          const createdAt = typeof record.createdAt === 'string' ? new Date(record.createdAt) : null;
          return record.siteId === siteId && (!createdAt || createdAt >= periodStart);
        });
        const learnersWithEvidenceSet = new Set<string>();
        const educatorMap = new Map<string, { count: number; mapped: number; rubric: number }>();

        evidence.forEach((record) => {
          const learnerId = typeof record.learnerId === 'string' ? record.learnerId : '';
          const educatorId = typeof record.educatorId === 'string' ? record.educatorId : '';
          if (learnerId && learnerIds.has(learnerId)) learnersWithEvidenceSet.add(learnerId);
          const existing = educatorMap.get(educatorId) ?? { count: 0, mapped: 0, rubric: 0 };
          existing.count++;
          if (record.capabilityMapped === true) existing.mapped++;
          if (record.rubricStatus === 'applied') existing.rubric++;
          educatorMap.set(educatorId, existing);
        });

        let totalMapped = 0;
        let totalRubric = 0;
        const educatorMetrics: EducatorMetric[] = [];
        educatorMap.forEach((agg, educatorId) => {
          totalMapped += agg.mapped;
          totalRubric += agg.rubric;
          educatorMetrics.push({
            educatorId,
            educatorName: educatorNames.get(educatorId) ?? educatorId.slice(0, 8),
            evidenceCount: agg.count,
            capabilityMappedCount: agg.mapped,
            rubricAppliedCount: agg.rubric,
          });
        });
        educatorMetrics.sort((a, b) => b.evidenceCount - a.evidenceCount);

        setMetrics({
          totalLearners: learnerIds.size,
          totalEvidence: evidence.length,
          learnersWithEvidence: learnersWithEvidenceSet.size,
          capabilityMappedRate: evidence.length > 0 ? totalMapped / evidence.length : 0,
          rubricAppliedRate: evidence.length > 0 ? totalRubric / evidence.length : 0,
          educatorMetrics,
        });
        return;
      }

      const [siteLearnerSnap, legacyLearnerSnap, evidenceSnap] = await Promise.all([
        getDocs(
          query(
            usersCollection,
            where('siteIds', 'array-contains', siteId),
            where('role', '==', 'learner')
          )
        ),
        getDocs(
          query(
            usersCollection,
            where('studioId', '==', siteId),
            where('role', '==', 'learner')
          )
        ),
        getDocs(
          query(
            evidenceRecordsCollection,
            where('siteId', '==', siteId),
            where('createdAt', '>=', Timestamp.fromDate(periodStart))
          )
        ),
      ]);

      // Also load educators for name resolution
      const [siteEducatorSnap, legacyEducatorSnap] = await Promise.all([
        getDocs(
          query(
            usersCollection,
            where('siteIds', 'array-contains', siteId),
            where('role', '==', 'educator')
          )
        ),
        getDocs(
          query(
            usersCollection,
            where('studioId', '==', siteId),
            where('role', '==', 'educator')
          )
        ),
      ]);

      const learnerMap = new Map<string, string>();
      for (const learnerSnap of [siteLearnerSnap, legacyLearnerSnap]) {
        for (const learnerDoc of learnerSnap.docs) {
          const data = learnerDoc.data();
          const uid = typeof data.uid === 'string' && data.uid.trim().length > 0 ? data.uid : learnerDoc.id;
          if (!learnerMap.has(uid)) {
            learnerMap.set(uid, uid);
          }
        }
      }

      const educatorNames = new Map<string, string>();
      for (const educatorSnap of [siteEducatorSnap, legacyEducatorSnap]) {
        for (const d of educatorSnap.docs) {
          const data = d.data();
          const uid = typeof data.uid === 'string' && data.uid.trim().length > 0 ? data.uid : d.id;
          if (!educatorNames.has(uid)) {
            educatorNames.set(
              uid,
              typeof data.displayName === 'string' && data.displayName.trim().length > 0
                ? data.displayName
                : uid,
            );
          }
        }
      }

      const totalLearners = learnerMap.size;
      const totalEvidence = evidenceSnap.size;

      // Aggregate per-educator and per-learner metrics
      const learnersWithEvidenceSet = new Set<string>();
      const educatorMap = new Map<string, { count: number; mapped: number; rubric: number }>();

      for (const doc of evidenceSnap.docs) {
        const data = doc.data();
        learnersWithEvidenceSet.add(data.learnerId);

        const existing = educatorMap.get(data.educatorId) ?? { count: 0, mapped: 0, rubric: 0 };
        existing.count++;
        if (data.capabilityMapped) existing.mapped++;
        if (data.rubricStatus === 'applied') existing.rubric++;
        educatorMap.set(data.educatorId, existing);
      }

      let totalMapped = 0;
      let totalRubric = 0;
      const educatorMetrics: EducatorMetric[] = [];

      for (const [educatorId, agg] of Array.from(educatorMap)) {
        totalMapped += agg.mapped;
        totalRubric += agg.rubric;
        educatorMetrics.push({
          educatorId,
          educatorName: educatorNames.get(educatorId) ?? educatorId.slice(0, 8),
          evidenceCount: agg.count,
          capabilityMappedCount: agg.mapped,
          rubricAppliedCount: agg.rubric,
        });
      }

      // Sort educators by evidence count descending
      educatorMetrics.sort((a, b) => b.evidenceCount - a.evidenceCount);

      setMetrics({
        totalLearners,
        totalEvidence,
        learnersWithEvidence: learnersWithEvidenceSet.size,
        capabilityMappedRate: totalEvidence > 0 ? totalMapped / totalEvidence : 0,
        rubricAppliedRate: totalEvidence > 0 ? totalRubric / totalEvidence : 0,
        educatorMetrics,
      });
    } catch (err) {
      console.error('Failed to load evidence health metrics', err);
      alert('Failed to load data. Please try again.');
    } finally {
      setLoading(false);
    }
  }, [siteId, period]);

  useEffect(() => {
    if (!authLoading && siteId) void loadMetrics();
  }, [authLoading, siteId, loadMetrics]);

  if (authLoading) {
    return (
      <div className="flex items-center justify-center py-12">
        <Spinner />
      </div>
    );
  }

  if (!siteId) {
    return (
      <RoleRouteGuard allowedRoles={['site', 'hq']}>
        <section
          data-testid="evidence-health-site-required"
          className="mx-auto max-w-4xl rounded-xl border border-amber-200 bg-amber-50 p-6 text-sm text-amber-900"
        >
          Select an active site before reviewing school evidence health.
        </section>
      </RoleRouteGuard>
    );
  }

  return (
    <RoleRouteGuard allowedRoles={['site', 'hq']}>
      <section className="mx-auto max-w-4xl space-y-6 p-4">
        <header className="flex items-center justify-between">
          <div>
            <h1 className="text-xl font-bold text-app-foreground">Evidence Health</h1>
            <p className="text-sm text-app-muted">
              School-level evidence coverage and educator capture rates
            </p>
          </div>
          <div className="flex gap-1 rounded-md border border-app bg-app-canvas p-0.5">
            <button
              type="button"
              onClick={() => setPeriod('week')}
              className={`rounded px-3 py-1 text-xs font-medium ${
                period === 'week'
                  ? 'bg-primary text-primary-foreground'
                  : 'text-app-muted hover:text-app-foreground'
              }`}
            >
              This Week
            </button>
            <button
              type="button"
              onClick={() => setPeriod('month')}
              className={`rounded px-3 py-1 text-xs font-medium ${
                period === 'month'
                  ? 'bg-primary text-primary-foreground'
                  : 'text-app-muted hover:text-app-foreground'
              }`}
            >
              This Month
            </button>
          </div>
        </header>

        {loading ? (
          <div className="flex items-center gap-2 py-12 justify-center text-app-muted">
            <Spinner />
            <span className="text-sm">Loading evidence health...</span>
          </div>
        ) : !metrics ? (
          <p className="text-sm text-app-muted py-8 text-center">
            No data available. Check site configuration.
          </p>
        ) : (
          <>
            {/* KPI cards */}
            <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4" data-testid="evidence-health-kpis">
              <HealthCard
                label="Learner Coverage"
                value={pct(metrics.learnersWithEvidence, metrics.totalLearners)}
                sub={`${metrics.learnersWithEvidence} of ${metrics.totalLearners} learners have evidence`}
              />
              <HealthCard
                label="Total Evidence"
                value={String(metrics.totalEvidence)}
                sub={`logged this ${period}`}
              />
              <HealthCard
                label="Capability Mapped"
                value={pct(Math.round(metrics.capabilityMappedRate * metrics.totalEvidence), metrics.totalEvidence)}
                sub="evidence linked to a capability"
              />
              <HealthCard
                label="Rubric Applied"
                value={pct(Math.round(metrics.rubricAppliedRate * metrics.totalEvidence), metrics.totalEvidence)}
                sub="evidence reviewed with rubric"
              />
            </div>

            {/* Educator breakdown table */}
            <div className="rounded-xl border border-app bg-app-surface p-4" data-testid="evidence-health-educators">
              <h2 className="text-sm font-semibold text-app-foreground mb-3">
                Educator Evidence Capture
              </h2>
              {metrics.educatorMetrics.length === 0 ? (
                <p className="text-sm text-app-muted py-4">
                  No evidence has been logged by educators this {period}.
                </p>
              ) : (
                <div className="overflow-x-auto">
                  <table className="w-full text-sm">
                    <thead>
                      <tr className="border-b border-app text-left text-xs font-medium text-app-muted">
                        <th className="pb-2 pr-4">Educator</th>
                        <th className="pb-2 pr-4 text-right">Evidence</th>
                        <th className="pb-2 pr-4 text-right">Mapped</th>
                        <th className="pb-2 text-right">Rubric</th>
                      </tr>
                    </thead>
                    <tbody>
                      {metrics.educatorMetrics.map((em) => (
                        <tr key={em.educatorId} className="border-b border-app/50">
                          <td className="py-2 pr-4 font-medium text-app-foreground">
                            {em.educatorName}
                          </td>
                          <td className="py-2 pr-4 text-right text-app-foreground">
                            {em.evidenceCount}
                          </td>
                          <td className="py-2 pr-4 text-right">
                            <span
                              className={
                                em.capabilityMappedCount / em.evidenceCount >= 0.7
                                  ? 'text-green-700'
                                  : em.capabilityMappedCount / em.evidenceCount >= 0.4
                                    ? 'text-amber-700'
                                    : 'text-red-700'
                              }
                            >
                              {pct(em.capabilityMappedCount, em.evidenceCount)}
                            </span>
                          </td>
                          <td className="py-2 text-right">
                            <span
                              className={
                                em.rubricAppliedCount / em.evidenceCount >= 0.5
                                  ? 'text-green-700'
                                  : em.rubricAppliedCount / em.evidenceCount >= 0.2
                                    ? 'text-amber-700'
                                    : 'text-red-700'
                              }
                            >
                              {pct(em.rubricAppliedCount, em.evidenceCount)}
                            </span>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </div>

            {/* Coverage gap alert */}
            {metrics.totalLearners > 0 &&
              metrics.learnersWithEvidence / metrics.totalLearners < 0.5 && (
                <div
                  className="rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800"
                  data-testid="evidence-health-alert"
                >
                  <strong>Low coverage:</strong> Fewer than half of enrolled learners have evidence
                  this {period}. Consider scheduling evidence capture sessions or reviewing educator
                  workflow adoption.
                </div>
              )}
          </>
        )}
      </section>
    </RoleRouteGuard>
  );
}
