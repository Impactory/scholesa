'use client';

import { useEffect, useMemo, useState } from 'react';
import Link from 'next/link';
import { documentId, getDocs, query, where } from 'firebase/firestore';
import { useAuthContext } from '@/src/firebase/auth/AuthProvider';
import { RoleRouteGuard } from '@/src/components/auth/RoleRouteGuard';
import type { RoleDashboardStat } from '@/src/lib/dashboard/roleDashboardApi';
import { fetchRoleDashboardSnapshot } from '@/src/lib/dashboard/roleDashboardApi';
import { enrollmentsCollection, sessionsCollection } from '@/src/lib/firestore/collections';
import { useI18n } from '@/src/lib/i18n/useI18n';
import { useInteractionTracking, usePageViewTracking } from '@/src/hooks/useTelemetry';
import type { Session } from '@/schema';

function formatSessionDate(rawDate: unknown, fallback: string): string {
  if (typeof rawDate === 'number') {
    return new Date(rawDate).toLocaleDateString();
  }
  if (typeof rawDate === 'string' && rawDate.trim().length > 0) {
    const parsed = Date.parse(rawDate);
    if (!Number.isNaN(parsed)) {
      return new Date(parsed).toLocaleDateString();
    }
  }
  return fallback;
}

export default function LearnerDashboard() {
  const { user, profile, loading: authLoading } = useAuthContext();
  const { locale, t } = useI18n();
  const trackInteraction = useInteractionTracking();
  usePageViewTracking('learner_dashboard', { role: 'learner' });

  const [sessions, setSessions] = useState<Session[]>([]);
  const [sessionsLoading, setSessionsLoading] = useState(true);
  const [stats, setStats] = useState<RoleDashboardStat[]>([]);
  const [statsLoading, setStatsLoading] = useState(true);

  const activeSiteId = useMemo(
    () => profile?.activeSiteId || profile?.siteIds?.[0] || undefined,
    [profile?.activeSiteId, profile?.siteIds],
  );

  useEffect(() => {
    async function fetchLearnerData() {
      if (!user) {
        setSessionsLoading(false);
        return;
      }

      try {
        const enrollmentsSnap = await getDocs(
          query(
            enrollmentsCollection,
            where('learnerId', '==', user.uid),
            where('status', '==', 'active'),
          ),
        );

        if (enrollmentsSnap.empty) {
          setSessions([]);
          return;
        }

        const sessionIds = enrollmentsSnap.docs
          .map((doc) => doc.data().sessionId)
          .filter((value): value is string => typeof value === 'string' && value.trim().length > 0)
          .slice(0, 10);

        if (sessionIds.length === 0) {
          setSessions([]);
          return;
        }

        const sessionsSnap = await getDocs(
          query(sessionsCollection, where(documentId(), 'in', sessionIds)),
        );
        setSessions(sessionsSnap.docs.map((doc) => doc.data()));
      } catch (error) {
        console.error('Error fetching learner data:', error);
        setSessions([]);
      } finally {
        setSessionsLoading(false);
      }
    }

    if (!authLoading) {
      void fetchLearnerData();
    }
  }, [authLoading, user]);

  useEffect(() => {
    async function fetchStats() {
      if (!profile) {
        setStatsLoading(false);
        return;
      }

      try {
        const snapshot = await fetchRoleDashboardSnapshot({
          role: 'learner',
          siteId: activeSiteId,
          period: 'week',
        });
        setStats(snapshot.stats);
      } catch (error) {
        console.error('Error fetching learner dashboard snapshot:', error);
        setStats([]);
      } finally {
        setStatsLoading(false);
      }
    }

    if (!authLoading) {
      void fetchStats();
    }
  }, [activeSiteId, authLoading, profile]);

  const visibleStats = stats.length > 0 ? stats : [
    { label: t('role.learner.fallback.activeSessions'), value: '0' },
    { label: t('role.learner.fallback.activeMissions'), value: '0' },
    { label: t('role.learner.fallback.unreadMessages'), value: '0' },
  ];
  const activeMissionsValue =
    visibleStats.find((stat) =>
      stat.label.toLowerCase().includes('mission'),
    )?.value ||
    visibleStats[1]?.value ||
    '0';

  const loading = authLoading || sessionsLoading || statsLoading;

  return (
    <RoleRouteGuard allowedRoles={['learner']}>
      {loading ? (
        <div className="flex min-h-screen items-center justify-center">
          <div className="text-lg text-app-muted">{t('role.learner.loading')}</div>
        </div>
      ) : (
        <div className="min-h-screen bg-app-canvas p-4 sm:p-8">
          <div className="mx-auto max-w-7xl">
            <header className="mb-8 border-b border-app pb-4">
              <h1 className="text-3xl font-bold tracking-tight text-app-foreground">
                {t('role.learner.welcome', {
                  name: profile?.displayName || t('role.learner.defaultName'),
                })}
              </h1>
              <p className="mt-2 text-sm text-app-muted">{t('role.learner.subtitle')}</p>
            </header>

            <div className="grid grid-cols-1 gap-6 lg:grid-cols-3">
              <div className="space-y-6 lg:col-span-2">
                <section>
                  <h2 className="mb-4 text-lg font-medium leading-6 text-app-foreground">
                    {t('role.learner.activeSessions')}
                  </h2>
                  {sessions.length === 0 ? (
                    <div className="overflow-hidden rounded-lg bg-app-surface-raised p-6 text-center text-app-muted shadow">
                      {t('role.learner.noSessions')}
                    </div>
                  ) : (
                    <div className="grid gap-4 sm:grid-cols-2">
                      {sessions.map((session) => (
                        <div
                          key={session.id}
                          className="overflow-hidden rounded-lg bg-app-surface-raised shadow transition-shadow hover:shadow-md"
                        >
                          <div className="p-5">
                            <h3 className="text-lg font-medium text-app-foreground">{session.title}</h3>
                            <p className="mt-1 line-clamp-2 text-sm text-app-muted">
                              {session.description}
                            </p>
                            <div className="mt-4 flex items-center justify-between text-xs text-app-muted">
                              <span className="rounded-full bg-indigo-50 px-2 py-1 font-medium text-indigo-700">
                                {session.pillarCodes?.[0] || t('common.general')}
                              </span>
                              <span>{formatSessionDate(session.startDate, t('common.tbd'))}</span>
                            </div>
                          </div>
                          <div className="bg-app-canvas px-5 py-3">
                            <Link
                              href={`/${locale}/learner`}
                              className="text-sm font-medium text-indigo-700 hover:text-indigo-900"
                              onClick={() =>
                                trackInteraction('feature_discovered', {
                                  cta: 'learner_open_session',
                                  sessionId: session.id,
                                })
                              }
                            >
                              {t('role.learner.viewSession')}
                            </Link>
                          </div>
                        </div>
                      ))}
                    </div>
                  )}
                </section>

                <section>
                  <h2 className="mb-4 text-lg font-medium leading-6 text-app-foreground">
                    {t('role.learner.recentMissions')}
                  </h2>
                  <div className="overflow-hidden rounded-lg bg-app-surface-raised shadow">
                    <div className="p-6 text-sm text-app-muted">
                      {t('role.learner.activeMissionsThisWeek', {
                        count: activeMissionsValue,
                      })}
                    </div>
                  </div>
                </section>
              </div>

              <div className="space-y-6">
                <div className="overflow-hidden rounded-lg bg-app-surface-raised shadow">
                  <div className="p-5">
                    <h3 className="text-base font-semibold leading-6 text-app-foreground">
                      {t('role.learner.myStats')}
                    </h3>
                    <div className="mt-4 border-t border-app pt-4">
                      <dl className="divide-y divide-app">
                        {visibleStats.map((stat) => (
                          <div key={stat.label} className="flex justify-between py-2 text-sm">
                            <dt className="text-app-muted">{stat.label}</dt>
                            <dd className="font-medium text-app-foreground">{stat.value}</dd>
                          </div>
                        ))}
                      </dl>
                    </div>
                    <Link
                      href={`/${locale}/learner`}
                      className="mt-4 block rounded-md bg-indigo-600 px-3 py-2 text-center text-sm font-semibold text-white shadow-sm hover:bg-indigo-500"
                      onClick={() =>
                        trackInteraction('feature_discovered', {
                          cta: 'learner_open_missions',
                        })
                      }
                    >
                      {t('role.learner.openMissionBoard')}
                    </Link>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      )}
    </RoleRouteGuard>
  );
}
