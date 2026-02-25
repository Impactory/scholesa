'use client';

import { useEffect, useMemo, useState } from 'react';
import Link from 'next/link';
import { getDocs, limit, query } from 'firebase/firestore';
import { useAuthContext } from '@/src/firebase/auth/AuthProvider';
import { RoleRouteGuard } from '@/src/components/auth/RoleRouteGuard';
import {
  fetchRoleDashboardSnapshot,
  fetchRoleLinkedRoster,
  type RoleDashboardStat,
  type RoleLinkedRoster,
} from '@/src/lib/dashboard/roleDashboardApi';
import { useInteractionTracking, usePageViewTracking } from '@/src/hooks/useTelemetry';
import { sitesCollection } from '@/src/lib/firestore/collections';
import { useI18n } from '@/src/lib/i18n/useI18n';
import type { Site } from '@/schema';

export default function HQDashboard() {
  const { profile, loading: authLoading } = useAuthContext();
  const { locale, t } = useI18n();
  const trackInteraction = useInteractionTracking();
  usePageViewTracking('hq_dashboard', { role: 'hq' });

  const [sites, setSites] = useState<Site[]>([]);
  const [stats, setStats] = useState<RoleDashboardStat[]>([]);
  const [roster, setRoster] = useState<RoleLinkedRoster | null>(null);
  const [loading, setLoading] = useState(true);

  const activeSiteId = useMemo(
    () => profile?.activeSiteId || profile?.siteIds?.[0] || undefined,
    [profile?.activeSiteId, profile?.siteIds],
  );

  useEffect(() => {
    async function fetchHQData() {
      try {
        const [sitesSnap, snapshot, linkedRoster] = await Promise.all([
          getDocs(query(sitesCollection, limit(12))),
          fetchRoleDashboardSnapshot({
            role: 'hq',
            siteId: activeSiteId,
            period: 'week',
          }),
          activeSiteId
            ? fetchRoleLinkedRoster({
                role: 'hq',
                siteId: activeSiteId,
              })
            : Promise.resolve(null),
        ]);
        setSites(sitesSnap.docs.map((doc) => doc.data()));
        setStats(snapshot.stats);
        setRoster(linkedRoster);
      } catch (error) {
        console.error('Error fetching HQ dashboard data:', error);
        setSites([]);
        setStats([]);
        setRoster(null);
      } finally {
        setLoading(false);
      }
    }

    if (!authLoading) {
      void fetchHQData();
    }
  }, [activeSiteId, authLoading]);

  const visibleStats = stats.length > 0 ? stats : [
    { label: t('role.hq.fallback.activeSites'), value: String(sites.length) },
    { label: t('role.hq.fallback.totalUsers'), value: '0' },
    { label: t('role.hq.fallback.pending'), value: '0' },
  ];
  const activeSitesValue =
    visibleStats.find((stat) => stat.label.toLowerCase().includes('site'))?.value ||
    String(sites.length);
  const activeUsersValue =
    visibleStats.find((stat) => stat.label.toLowerCase().includes('user'))?.value || '0';

  return (
    <RoleRouteGuard allowedRoles={['hq']}>
      {authLoading || loading ? (
        <div className="flex min-h-screen items-center justify-center">
          <div className="text-lg text-app-muted">{t('role.hq.loading')}</div>
        </div>
      ) : (
        <div className="min-h-screen bg-app-canvas p-4 sm:p-8">
          <div className="mx-auto max-w-7xl">
            <header className="mb-8 border-b border-app pb-4">
              <h1 className="text-3xl font-bold tracking-tight text-app-foreground">
                {t('role.hq.title')}
              </h1>
              <p className="mt-2 text-sm text-app-muted">
                {t('role.hq.subtitle', {
                  name: profile?.displayName || t('role.hq.defaultName'),
                })}
              </p>
            </header>

            <div className="grid grid-cols-1 gap-6 lg:grid-cols-3">
              <div className="space-y-6 lg:col-span-2">
                <section>
                  <div className="mb-4 flex items-center justify-between">
                    <h2 className="text-lg font-medium leading-6 text-app-foreground">
                      {t('role.hq.networkSites')}
                    </h2>
                    <Link
                      href={`/${locale}/hq`}
                      className="text-sm font-medium text-indigo-600 hover:text-indigo-500"
                      onClick={() =>
                        trackInteraction('feature_discovered', {
                          cta: 'hq_view_all_sites',
                        })
                      }
                    >
                      {t('common.viewAll')}
                    </Link>
                  </div>

                  {sites.length === 0 ? (
                    <div className="overflow-hidden rounded-lg bg-app-surface-raised p-6 text-center text-app-muted shadow">
                      <p>{t('role.hq.noSites')}</p>
                    </div>
                  ) : (
                    <div className="grid gap-4 sm:grid-cols-2">
                      {sites.map((site) => (
                        <div
                          key={site.id}
                          className="overflow-hidden rounded-lg bg-app-surface-raised shadow transition-shadow hover:shadow-md"
                        >
                          <div className="p-5">
                            <h3 className="text-lg font-medium text-app-foreground">{site.name}</h3>
                            <p className="text-sm text-app-muted">
                              {site.location || t('role.hq.locationFallback')}
                            </p>
                            <div className="mt-4 flex items-center justify-between">
                              <span className="inline-flex items-center rounded-full bg-green-50 px-2 py-1 text-xs font-medium text-green-700">
                                {t('common.operational')}
                              </span>
                              <span className="text-xs text-app-muted">
                                {t('role.hq.siteIdPrefix')}: {site.id.substring(0, 6)}...
                              </span>
                            </div>
                          </div>
                          <div className="bg-app-canvas px-5 py-3">
                            <Link
                              href={`/${locale}/hq`}
                              className="text-sm font-medium text-indigo-700 hover:text-indigo-900"
                              onClick={() =>
                                trackInteraction('feature_discovered', {
                                  cta: 'hq_manage_site',
                                  siteId: site.id,
                                })
                              }
                            >
                              {t('role.hq.manageSite')}
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
                      {t('role.hq.systemHealth')}
                    </h3>
                    <div className="mt-4 border-t border-app pt-4">
                      <dl className="divide-y divide-app">
                        {visibleStats.map((stat) => (
                          <div key={stat.label} className="flex justify-between py-2 text-sm">
                            <dt className="text-app-muted">{stat.label}</dt>
                            <dd className="font-medium text-app-foreground">{stat.value}</dd>
                          </div>
                        ))}
                        {roster && (
                          <div className="flex justify-between py-2 text-sm">
                            <dt className="text-app-muted">{t('role.hq.activeSiteRoster')}</dt>
                            <dd className="font-medium text-app-foreground">
                              {roster.counts.learners + roster.counts.parents + roster.counts.educators}
                            </dd>
                          </div>
                        )}
                      </dl>
                    </div>
                  </div>
                </div>

                <div className="overflow-hidden rounded-lg bg-app-surface-raised shadow">
                  <div className="p-5">
                    <h3 className="text-base font-semibold leading-6 text-app-foreground">
                      {t('role.hq.adminActions')}
                    </h3>
                    <div className="mt-4 space-y-3">
                      <Link
                        href={`/${locale}/hq`}
                        className="block w-full rounded-md bg-indigo-600 px-3 py-2 text-center text-sm font-semibold text-white shadow-sm hover:bg-indigo-500"
                        onClick={() =>
                          trackInteraction('feature_discovered', {
                            cta: 'hq_add_new_site',
                          })
                        }
                      >
                        {t('role.hq.addSite')}
                      </Link>
                      <Link
                        href={`/${locale}/hq`}
                        className="block w-full rounded-md bg-app-surface-raised px-3 py-2 text-center text-sm font-semibold text-app-foreground shadow-sm ring-1 ring-inset ring-app hover:bg-app-canvas"
                        onClick={() =>
                          trackInteraction('feature_discovered', {
                            cta: 'hq_user_management',
                          })
                        }
                      >
                        {t('role.hq.userManagement')}
                      </Link>
                    </div>
                  </div>
                </div>

                <div className="overflow-hidden rounded-lg bg-app-surface-raised shadow">
                  <div className="p-5 text-sm text-app-muted">
                    <div>{t('role.hq.totalSites')}: {activeSitesValue}</div>
                    <div className="mt-1">{t('role.hq.activeUsers')}: {activeUsersValue}</div>
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
