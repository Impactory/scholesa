'use client';

import { useEffect, useMemo, useState } from 'react';
import Link from 'next/link';
import { useAuthContext } from '@/src/firebase/auth/AuthProvider';
import { RoleRouteGuard } from '@/src/components/auth/RoleRouteGuard';
import {
  fetchParentDashboardBundle,
  fetchRoleDashboardSnapshot,
  type ParentDashboardBundle,
  type RoleDashboardStat,
} from '@/src/lib/dashboard/roleDashboardApi';
import { useInteractionTracking, usePageViewTracking } from '@/src/hooks/useTelemetry';
import { useI18n } from '@/src/lib/i18n/useI18n';

export default function ParentDashboard() {
  const { profile, loading: authLoading } = useAuthContext();
  const { locale, t } = useI18n();
  const trackInteraction = useInteractionTracking();
  usePageViewTracking('parent_dashboard', { role: 'parent' });

  const [bundle, setBundle] = useState<ParentDashboardBundle | null>(null);
  const [stats, setStats] = useState<RoleDashboardStat[]>([]);
  const [loading, setLoading] = useState(true);

  const activeSiteId = useMemo(
    () => profile?.activeSiteId || profile?.siteIds?.[0] || undefined,
    [profile?.activeSiteId, profile?.siteIds],
  );

  useEffect(() => {
    async function fetchParentData() {
      if (!profile) {
        setLoading(false);
        return;
      }

      try {
        const [parentBundle, snapshot] = await Promise.all([
          fetchParentDashboardBundle({
            siteId: activeSiteId,
            locale,
            range: 'week',
          }),
          fetchRoleDashboardSnapshot({
            role: 'parent',
            siteId: activeSiteId,
            period: 'week',
          }),
        ]);
        setBundle(parentBundle);
        setStats(snapshot.stats);
      } catch (error) {
        console.error('Error fetching parent dashboard bundle:', error);
        setBundle(null);
        setStats([]);
      } finally {
        setLoading(false);
      }
    }

    if (!authLoading) {
      void fetchParentData();
    }
  }, [activeSiteId, authLoading, locale, profile]);

  const learnerCards = bundle?.learners || [];
  const visibleStats = stats.length > 0 ? stats : [
    { label: t('role.parent.fallback.linkedLearners'), value: String(bundle?.linkedLearnerCount || 0) },
    { label: t('role.parent.fallback.upcomingSessions'), value: '0' },
    { label: t('role.parent.fallback.alerts'), value: '0' },
  ];

  return (
    <RoleRouteGuard allowedRoles={['parent']}>
      {authLoading || loading ? (
        <div className="flex min-h-screen items-center justify-center">
          <div className="text-lg text-app-muted">{t('role.parent.loading')}</div>
        </div>
      ) : (
        <div className="min-h-screen bg-app-canvas p-4 sm:p-8">
          <div className="mx-auto max-w-7xl">
            <header className="mb-8 border-b border-app pb-4">
              <h1 className="text-3xl font-bold tracking-tight text-app-foreground">
                {t('role.parent.welcome', {
                  name: profile?.displayName || t('role.parent.defaultName'),
                })}
              </h1>
              <p className="mt-2 text-sm text-app-muted">{t('role.parent.subtitle')}</p>
            </header>

            <div className="grid grid-cols-1 gap-6 lg:grid-cols-3">
              <div className="space-y-6 lg:col-span-2">
                <section>
                  <h2 className="mb-4 text-lg font-medium leading-6 text-app-foreground">
                    {t('role.parent.children')}
                  </h2>
                  {learnerCards.length === 0 ? (
                    <div className="overflow-hidden rounded-lg bg-app-surface-raised p-8 text-center text-app-muted shadow">
                      <h3 className="text-xl font-semibold text-app-foreground">
                        {t('role.parent.emptyWelcome')}
                      </h3>
                      <p className="mt-2">{t('role.parent.emptyMessage')}</p>
                      <Link
                        href={`/${locale}/site`}
                        className="mt-6 inline-block rounded-md bg-indigo-600 px-4 py-2 text-sm font-semibold text-white hover:bg-indigo-700"
                        onClick={() =>
                          trackInteraction('feature_discovered', {
                            cta: 'parent_request_linked_learner',
                          })
                        }
                      >
                        {t('role.parent.askSiteLinkLearner')}
                      </Link>
                    </div>
                  ) : (
                    <div className="grid gap-4 sm:grid-cols-2">
                      {learnerCards.map((learner) => (
                        <div
                          key={learner.learnerId}
                          className="overflow-hidden rounded-lg bg-app-surface-raised shadow transition-shadow hover:shadow-md"
                        >
                          <div className="p-5">
                            <div className="flex items-center space-x-4">
                              <div className="flex h-10 w-10 items-center justify-center rounded-full bg-indigo-100 font-bold text-indigo-600">
                                {learner.learnerName?.charAt(0) || t('role.parent.defaultLearnerInitial')}
                              </div>
                              <div>
                                <h3 className="text-lg font-medium text-app-foreground">
                                  {learner.learnerName}
                                </h3>
                                <p className="text-sm text-app-muted">
                                  {t('role.parent.levelXp', {
                                    level: learner.currentLevel,
                                    xp: learner.totalXp,
                                  })}
                                </p>
                              </div>
                            </div>
                            <div className="mt-4 grid grid-cols-2 gap-3 text-xs text-app-muted">
                              <div className="rounded-md bg-app-canvas px-3 py-2">
                                {t('role.parent.missionsCount', { count: learner.missionsCompleted })}
                              </div>
                              <div className="rounded-md bg-app-canvas px-3 py-2">
                                {t('role.parent.streakCount', { count: learner.currentStreak })}
                              </div>
                            </div>
                          </div>
                          <div className="bg-app-canvas px-5 py-3">
                            <Link
                              href={`/${locale}/parent`}
                              className="text-sm font-medium text-indigo-700 hover:text-indigo-900"
                              onClick={() =>
                                trackInteraction('feature_discovered', {
                                  cta: 'parent_view_progress',
                                  learnerId: learner.learnerId,
                                })
                              }
                            >
                              {t('role.parent.viewProgress')}
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
                      </dl>
                    </div>
                  </div>
                </div>

                <div className="overflow-hidden rounded-lg bg-app-surface-raised shadow">
                  <div className="p-5">
                    <h3 className="text-base font-semibold leading-6 text-app-foreground">
                      {t('role.parent.quickActions')}
                    </h3>
                    <div className="mt-4 space-y-4">
                      <Link
                        href={`/${locale}/parent`}
                        className="block w-full rounded-md bg-indigo-600 px-3 py-2 text-center text-sm font-semibold text-white shadow-sm hover:bg-indigo-500"
                        onClick={() =>
                          trackInteraction('feature_discovered', {
                            cta: 'parent_message_educator',
                          })
                        }
                      >
                        {t('role.parent.messageEducator')}
                      </Link>
                      <Link
                        href={`/${locale}/parent`}
                        className="block w-full rounded-md bg-app-surface-raised px-3 py-2 text-center text-sm font-semibold text-app-foreground shadow-sm ring-1 ring-inset ring-app hover:bg-app-canvas"
                        onClick={() =>
                          trackInteraction('feature_discovered', {
                            cta: 'parent_view_schedule',
                          })
                        }
                      >
                        {t('role.parent.viewSchedule')}
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
