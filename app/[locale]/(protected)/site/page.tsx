'use client';

import { useEffect, useMemo, useState } from 'react';
import Link from 'next/link';
import { doc, getDoc } from 'firebase/firestore';
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

export default function SiteDashboard() {
  const { profile, loading: authLoading } = useAuthContext();
  const { locale, t } = useI18n();
  const trackInteraction = useInteractionTracking();
  usePageViewTracking('site_dashboard', { role: 'site' });

  const [site, setSite] = useState<Site | null>(null);
  const [stats, setStats] = useState<RoleDashboardStat[]>([]);
  const [roster, setRoster] = useState<RoleLinkedRoster | null>(null);
  const [loading, setLoading] = useState(true);

  const activeSiteId = useMemo(
    () => profile?.activeSiteId || profile?.siteIds?.[0] || undefined,
    [profile?.activeSiteId, profile?.siteIds],
  );

  useEffect(() => {
    async function fetchSiteData() {
      if (!activeSiteId) {
        setLoading(false);
        return;
      }

      try {
        const [siteSnap, snapshot, linkedRoster] = await Promise.all([
          getDoc(doc(sitesCollection, activeSiteId)),
          fetchRoleDashboardSnapshot({
            role: 'site',
            siteId: activeSiteId,
            period: 'week',
          }),
          fetchRoleLinkedRoster({
            role: 'site',
            siteId: activeSiteId,
          }),
        ]);

        if (siteSnap.exists()) {
          setSite(siteSnap.data());
        } else {
          setSite(null);
        }
        setStats(snapshot.stats);
        setRoster(linkedRoster);
      } catch (error) {
        console.error('Error fetching site dashboard data:', error);
        setSite(null);
        setStats([]);
        setRoster(null);
      } finally {
        setLoading(false);
      }
    }

    if (!authLoading) {
      void fetchSiteData();
    }
  }, [activeSiteId, authLoading]);

  const visibleStats = stats.length > 0 ? stats : [
    { label: 'On Site', value: String(roster?.counts.learners || 0) },
    { label: 'Checked In', value: '0' },
    { label: 'Open Incidents', value: '0' },
  ];

  const statByLabel = (labelPart: string): string =>
    visibleStats.find((stat) => stat.label.toLowerCase().includes(labelPart))?.value || '0';

  return (
    <RoleRouteGuard allowedRoles={['site']}>
      {authLoading || loading ? (
        <div className="flex min-h-screen items-center justify-center">
          <div className="text-lg text-gray-600">{t('role.site.loading')}</div>
        </div>
      ) : !site ? (
        <div className="flex min-h-screen items-center justify-center">
          <div className="text-center">
            <h1 className="text-2xl font-bold text-gray-900">{t('role.site.noSiteTitle')}</h1>
            <p className="mt-2 text-gray-600">{t('role.site.noSiteMessage')}</p>
          </div>
        </div>
      ) : (
        <div className="min-h-screen bg-gray-50 p-4 sm:p-8">
          <div className="mx-auto max-w-7xl">
            <header className="mb-8 border-b border-gray-200 pb-4">
              <h1 className="text-3xl font-bold tracking-tight text-gray-900">{site.name}</h1>
              <p className="mt-2 text-sm text-gray-500">
                {t('role.site.subtitle', {
                  location: site.location || t('role.site.noLocation'),
                })}
              </p>
            </header>

            <div className="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
              <div className="overflow-hidden rounded-lg bg-white shadow">
                <div className="p-5">
                  <div className="flex items-center">
                    <div className="flex h-10 w-10 flex-shrink-0 items-center justify-center rounded-full bg-indigo-100 text-indigo-600">
                      👥
                    </div>
                    <div className="ml-5 w-0 flex-1">
                      <dl>
                        <dt className="truncate text-sm font-medium text-gray-500">
                          {t('role.site.totalLearners')}
                        </dt>
                        <dd>
                          <div className="text-lg font-medium text-gray-900">
                            {roster?.counts.learners ?? statByLabel('site')}
                          </div>
                        </dd>
                      </dl>
                    </div>
                  </div>
                </div>
                <div className="bg-gray-50 px-5 py-3">
                  <Link
                    href={`/${locale}/site`}
                    className="text-sm font-medium text-indigo-700 hover:text-indigo-900"
                    onClick={() =>
                      trackInteraction('feature_discovered', {
                        cta: 'site_view_all',
                      })
                    }
                  >
                    {t('common.viewAll')}
                  </Link>
                </div>
              </div>

              <div className="overflow-hidden rounded-lg bg-white shadow">
                <div className="p-5">
                  <div className="flex items-center">
                    <div className="flex h-10 w-10 flex-shrink-0 items-center justify-center rounded-full bg-green-100 text-green-600">
                      📅
                    </div>
                    <div className="ml-5 w-0 flex-1">
                      <dl>
                        <dt className="truncate text-sm font-medium text-gray-500">
                          {t('role.site.activeSessions')}
                        </dt>
                        <dd>
                          <div className="text-lg font-medium text-gray-900">
                            {statByLabel('checked') === '0' ? statByLabel('session') : statByLabel('checked')}
                          </div>
                        </dd>
                      </dl>
                    </div>
                  </div>
                </div>
                <div className="bg-gray-50 px-5 py-3">
                  <Link
                    href={`/${locale}/site`}
                    className="text-sm font-medium text-indigo-700 hover:text-indigo-900"
                    onClick={() =>
                      trackInteraction('feature_discovered', {
                        cta: 'site_manage_schedule',
                      })
                    }
                  >
                    {t('role.site.manageSchedule')}
                  </Link>
                </div>
              </div>

              <div className="overflow-hidden rounded-lg bg-white shadow">
                <div className="p-5">
                  <h3 className="text-base font-semibold leading-6 text-gray-900">Live roster</h3>
                  <dl className="mt-4 divide-y divide-gray-100 border-t border-gray-100 pt-4">
                    <div className="flex justify-between py-2 text-sm">
                      <dt className="text-gray-500">Learners</dt>
                      <dd className="font-medium text-gray-900">{roster?.counts.learners ?? 0}</dd>
                    </div>
                    <div className="flex justify-between py-2 text-sm">
                      <dt className="text-gray-500">Parents</dt>
                      <dd className="font-medium text-gray-900">{roster?.counts.parents ?? 0}</dd>
                    </div>
                    <div className="flex justify-between py-2 text-sm">
                      <dt className="text-gray-500">Educators</dt>
                      <dd className="font-medium text-gray-900">{roster?.counts.educators ?? 0}</dd>
                    </div>
                  </dl>
                </div>
              </div>
            </div>

            <div className="mt-8">
              <h2 className="text-lg font-medium leading-6 text-gray-900">Live metrics</h2>
              <div className="mt-4 overflow-hidden rounded-lg bg-white shadow">
                <div className="divide-y divide-gray-100 p-6">
                  {visibleStats.map((stat) => (
                    <div key={stat.label} className="flex items-center justify-between py-2 text-sm">
                      <span className="text-gray-500">{stat.label}</span>
                      <span className="font-medium text-gray-900">{stat.value}</span>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </div>
        </div>
      )}
    </RoleRouteGuard>
  );
}
