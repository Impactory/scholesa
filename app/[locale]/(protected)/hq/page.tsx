'use client';

import { useEffect, useState } from 'react';
import { query, getDocs, limit } from 'firebase/firestore';
import Link from 'next/link';
import { useAuthContext } from '@/src/firebase/auth/AuthProvider';
import { useInteractionTracking } from '@/src/hooks/useTelemetry';
import { sitesCollection } from '@/src/lib/firestore/collections';
import type { Site } from '@/schema';
import { useI18n } from '@/src/lib/i18n/useI18n';

export default function HQDashboard() {
  const { profile, loading: authLoading } = useAuthContext();
  const { locale, t } = useI18n();
  const trackInteraction = useInteractionTracking();
  const [sites, setSites] = useState<Site[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function fetchHQData() {
      // HQ users typically have access to all sites.
      // We'll fetch a subset for the dashboard overview.
      try {
        const qSites = query(
          sitesCollection, 
          // orderBy('createdAt', 'desc'), // Requires index, skipping for now to avoid runtime error if index missing
          limit(12)
        );
        const sitesSnap = await getDocs(qSites);
        setSites(sitesSnap.docs.map(doc => doc.data()));
      } catch (error) {
        console.error('Error fetching HQ data:', error);
      } finally {
        setLoading(false);
      }
    }

    if (!authLoading) {
      fetchHQData();
    }
  }, [authLoading]);

  if (authLoading || loading) {
    return (
      <div className="flex min-h-screen items-center justify-center">
        <div className="text-lg text-gray-600">{t('role.hq.loading')}</div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50 p-4 sm:p-8">
      <div className="mx-auto max-w-7xl">
        <header className="mb-8 border-b border-gray-200 pb-4">
          <h1 className="text-3xl font-bold tracking-tight text-gray-900">
            {t('role.hq.title')}
          </h1>
          <p className="mt-2 text-sm text-gray-500">
            {t('role.hq.subtitle', { name: profile?.displayName || t('role.hq.defaultName') })}
          </p>
        </header>

        <div className="grid grid-cols-1 gap-6 lg:grid-cols-3">
          {/* Main Content: Site List */}
          <div className="lg:col-span-2 space-y-6">
            <section>
              <div className="flex items-center justify-between mb-4">
                <h2 className="text-lg font-medium leading-6 text-gray-900">{t('role.hq.networkSites')}</h2>
                <Link
                  href={`/${locale}/hq`}
                  className="text-sm font-medium text-indigo-600 hover:text-indigo-500"
                  onClick={() => trackInteraction('feature_discovered', { cta: 'hq_view_all_sites' })}
                >
                  {t('common.viewAll')}
                </Link>
              </div>
              
              {sites.length === 0 ? (
                <div className="overflow-hidden rounded-lg bg-white shadow p-6 text-center text-gray-500">
                  <p>{t('role.hq.noSites')}</p>
                </div>
              ) : (
                <div className="grid gap-4 sm:grid-cols-2">
                  {sites.map((site) => (
                    <div key={site.id} className="overflow-hidden rounded-lg bg-white shadow hover:shadow-md transition-shadow">
                      <div className="p-5">
                        <h3 className="text-lg font-medium text-gray-900">{site.name}</h3>
                        <p className="text-sm text-gray-500">{site.location || t('role.hq.locationFallback')}</p>
                        <div className="mt-4 flex items-center justify-between">
                          <span className="inline-flex items-center rounded-full bg-green-50 px-2 py-1 text-xs font-medium text-green-700">
                            {t('common.operational')}
                          </span>
                          <span className="text-xs text-gray-400">
                            {t('role.hq.siteIdPrefix')}: {site.id.substring(0, 6)}...
                          </span>
                        </div>
                      </div>
                      <div className="bg-gray-50 px-5 py-3">
                        <div className="text-sm">
                          <Link
                            href={`/${locale}/hq`}
                            className="font-medium text-indigo-700 hover:text-indigo-900"
                            onClick={() => trackInteraction('feature_discovered', { cta: 'hq_manage_site', siteId: site.id })}
                          >
                            {t('role.hq.manageSite')}
                          </Link>
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </section>
          </div>

          {/* Sidebar: System Stats */}
          <div className="space-y-6">
            <div className="overflow-hidden rounded-lg bg-white shadow">
              <div className="p-5">
                <h3 className="text-base font-semibold leading-6 text-gray-900">{t('role.hq.systemHealth')}</h3>
                <div className="mt-4 border-t border-gray-100 pt-4">
                  <dl className="divide-y divide-gray-100">
                    <div className="flex justify-between py-2 text-sm">
                      <dt className="text-gray-500">{t('role.hq.totalSites')}</dt>
                      <dd className="font-medium text-gray-900">{sites.length}</dd>
                    </div>
                    <div className="flex justify-between py-2 text-sm">
                      <dt className="text-gray-500">{t('role.hq.activeUsers')}</dt>
                      <dd className="font-medium text-gray-900">-</dd>
                    </div>
                    <div className="flex justify-between py-2 text-sm">
                      <dt className="text-gray-500">{t('role.hq.systemStatus')}</dt>
                      <dd className="font-medium text-green-600">{t('common.healthy')}</dd>
                    </div>
                  </dl>
                </div>
              </div>
            </div>

            <div className="overflow-hidden rounded-lg bg-white shadow">
              <div className="p-5">
                <h3 className="text-base font-semibold leading-6 text-gray-900">{t('role.hq.adminActions')}</h3>
                <div className="mt-4 space-y-3">
                  <Link
                    href={`/${locale}/hq`}
                    className="block w-full rounded-md bg-indigo-600 px-3 py-2 text-center text-sm font-semibold text-white shadow-sm hover:bg-indigo-500"
                    onClick={() => trackInteraction('feature_discovered', { cta: 'hq_add_new_site' })}
                  >
                    {t('role.hq.addSite')}
                  </Link>
                  <Link
                    href={`/${locale}/hq`}
                    className="block w-full rounded-md bg-white px-3 py-2 text-center text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50"
                    onClick={() => trackInteraction('feature_discovered', { cta: 'hq_user_management' })}
                  >
                    {t('role.hq.userManagement')}
                  </Link>
                  <Link
                    href={`/${locale}/hq`}
                    className="block w-full rounded-md bg-white px-3 py-2 text-center text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50"
                    onClick={() => trackInteraction('feature_discovered', { cta: 'hq_global_settings' })}
                  >
                    {t('role.hq.globalSettings')}
                  </Link>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
