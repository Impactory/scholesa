'use client';

import { useEffect, useMemo, useState } from 'react';
import Link from 'next/link';
import { getDocs, query, where } from 'firebase/firestore';
import { useAuthContext } from '@/src/firebase/auth/AuthProvider';
import { RoleRouteGuard } from '@/src/components/auth/RoleRouteGuard';
import {
  fetchRoleDashboardSnapshot,
  fetchRoleLinkedRoster,
  type RoleDashboardStat,
  type RoleLinkedRoster,
} from '@/src/lib/dashboard/roleDashboardApi';
import { useInteractionTracking, usePageViewTracking } from '@/src/hooks/useTelemetry';
import { sessionsCollection } from '@/src/lib/firestore/collections';
import { useI18n } from '@/src/lib/i18n/useI18n';
import type { Session } from '@/schema';

function formatDate(rawDate: unknown): string {
  if (typeof rawDate === 'number') return new Date(rawDate).toLocaleDateString();
  if (typeof rawDate === 'string' && rawDate.trim().length > 0) {
    const parsed = Date.parse(rawDate);
    if (!Number.isNaN(parsed)) return new Date(parsed).toLocaleDateString();
  }
  return 'TBD';
}

export default function EducatorDashboard() {
  const { user, profile, loading: authLoading } = useAuthContext();
  const { locale, t } = useI18n();
  const trackInteraction = useInteractionTracking();
  usePageViewTracking('educator_dashboard', { role: 'educator' });

  const [sessions, setSessions] = useState<Session[]>([]);
  const [sessionsLoading, setSessionsLoading] = useState(true);
  const [stats, setStats] = useState<RoleDashboardStat[]>([]);
  const [roster, setRoster] = useState<RoleLinkedRoster | null>(null);
  const [snapshotLoading, setSnapshotLoading] = useState(true);

  const activeSiteId = useMemo(
    () => profile?.activeSiteId || profile?.siteIds?.[0] || undefined,
    [profile?.activeSiteId, profile?.siteIds],
  );

  useEffect(() => {
    async function fetchEducatorData() {
      if (!user) {
        setSessionsLoading(false);
        return;
      }

      try {
        const sessionsSnap = await getDocs(
          query(sessionsCollection, where('educatorIds', 'array-contains', user.uid)),
        );
        setSessions(sessionsSnap.docs.map((doc) => doc.data()));
      } catch (error) {
        console.error('Error fetching educator sessions:', error);
        setSessions([]);
      } finally {
        setSessionsLoading(false);
      }
    }

    if (!authLoading) {
      void fetchEducatorData();
    }
  }, [authLoading, user]);

  useEffect(() => {
    async function fetchSnapshotAndRoster() {
      if (!profile) {
        setSnapshotLoading(false);
        return;
      }

      try {
        const [snapshot, linkedRoster] = await Promise.all([
          fetchRoleDashboardSnapshot({
            role: 'educator',
            siteId: activeSiteId,
            period: 'week',
          }),
          fetchRoleLinkedRoster({
            role: 'educator',
            siteId: activeSiteId,
            educatorId: user?.uid,
          }),
        ]);
        setStats(snapshot.stats);
        setRoster(linkedRoster);
      } catch (error) {
        console.error('Error fetching educator dashboard snapshot:', error);
        setStats([]);
        setRoster(null);
      } finally {
        setSnapshotLoading(false);
      }
    }

    if (!authLoading) {
      void fetchSnapshotAndRoster();
    }
  }, [activeSiteId, authLoading, profile, user?.uid]);

  const visibleStats = stats.length > 0 ? stats : [
    { label: t('role.educator.fallback.studentsToday'), value: '0' },
    { label: t('role.educator.fallback.attendance'), value: '0%' },
    { label: t('role.educator.fallback.toReview'), value: '0' },
  ];
  const loading = authLoading || sessionsLoading || snapshotLoading;

  return (
    <RoleRouteGuard allowedRoles={['educator']}>
      {loading ? (
        <div className="flex min-h-screen items-center justify-center">
          <div className="text-lg text-app-muted">{t('role.educator.loading')}</div>
        </div>
      ) : (
        <div className="min-h-screen bg-app-canvas p-4 sm:p-8">
          <div className="mx-auto max-w-7xl">
            <header className="mb-8 border-b border-app pb-4">
              <h1 className="text-3xl font-bold tracking-tight text-app-foreground">
                {t('role.educator.hello', {
                  name: profile?.displayName || t('role.educator.defaultName'),
                })}
              </h1>
              <p className="mt-2 text-sm text-app-muted">{t('role.educator.subtitle')}</p>
            </header>

            <div className="grid grid-cols-1 gap-6 lg:grid-cols-3">
              <div className="space-y-6 lg:col-span-2">
                <section>
                  <h2 className="mb-4 text-lg font-medium leading-6 text-app-foreground">
                    {t('role.educator.assignedSessions')}
                  </h2>
                  {sessions.length === 0 ? (
                    <div className="overflow-hidden rounded-lg bg-app-surface-raised p-6 text-center text-app-muted shadow">
                      {t('role.educator.noSessions')}
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
                            <div className="mt-4 flex items-center justify-between">
                              <span className="inline-flex items-center rounded-full bg-indigo-50 px-2 py-1 text-xs font-medium text-indigo-700">
                                {session.pillarCodes?.[0] || t('common.general')}
                              </span>
                              <span className="text-xs text-app-muted">
                                {formatDate(session.startDate)}
                              </span>
                            </div>
                          </div>
                          <div className="bg-app-canvas px-5 py-3">
                            <Link
                              href={`/${locale}/educator`}
                              className="text-sm font-medium text-indigo-700 hover:text-indigo-900"
                              onClick={() =>
                                trackInteraction('feature_discovered', {
                                  cta: 'educator_view_details',
                                  sessionId: session.id,
                                })
                              }
                            >
                              {t('role.educator.viewDetails')}
                            </Link>
                          </div>
                        </div>
                      ))}
                    </div>
                  )}
                </section>
              </div>

              <div className="space-y-6">
                <div className="overflow-hidden rounded-lg bg-app-surface-raised shadow">
                  <div className="p-5">
                    <h3 className="text-base font-semibold leading-6 text-app-foreground">
                      {t('common.liveStats')}
                    </h3>
                    <div className="mt-4 border-t border-app pt-4">
                      <dl className="divide-y divide-app">
                        {visibleStats.map((stat) => (
                          <div key={stat.label} className="flex justify-between py-2 text-sm">
                            <dt className="text-app-muted">{stat.label}</dt>
                            <dd className="font-medium text-app-foreground">{stat.value}</dd>
                          </div>
                        ))}
                        <div className="flex justify-between py-2 text-sm">
                          <dt className="text-app-muted">{t('role.educator.linkedLearners')}</dt>
                          <dd className="font-medium text-app-foreground">
                            {roster?.counts.learners ?? 0}
                          </dd>
                        </div>
                      </dl>
                    </div>
                  </div>
                </div>

                <div className="overflow-hidden rounded-lg bg-app-surface-raised shadow">
                  <div className="p-5">
                    <h3 className="text-base font-semibold leading-6 text-app-foreground">
                      {t('role.educator.quickActions')}
                    </h3>
                    <div className="mt-4 space-y-4">
                      <Link
                        href={`/${locale}/educator`}
                        className="block w-full rounded-md bg-indigo-600 px-3 py-2 text-center text-sm font-semibold text-white shadow-sm hover:bg-indigo-500"
                        onClick={() =>
                          trackInteraction('feature_discovered', {
                            cta: 'educator_take_attendance',
                          })
                        }
                      >
                        {t('role.educator.takeAttendance')}
                      </Link>
                      <Link
                        href={`/${locale}/educator`}
                        className="block w-full rounded-md bg-app-surface-raised px-3 py-2 text-center text-sm font-semibold text-app-foreground shadow-sm ring-1 ring-inset ring-app hover:bg-app-canvas"
                        onClick={() =>
                          trackInteraction('feature_discovered', {
                            cta: 'educator_create_mission',
                          })
                        }
                      >
                        {t('role.educator.createMission')}
                      </Link>
                    </div>
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
