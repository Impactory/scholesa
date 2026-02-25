'use client';

import { useEffect, useMemo, useState } from 'react';
import Link from 'next/link';
import { documentId, getDocs, query, where } from 'firebase/firestore';
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

export default function PartnerDashboard() {
  const { profile, loading: authLoading } = useAuthContext();
  const { locale, t } = useI18n();
  const trackInteraction = useInteractionTracking();
  usePageViewTracking('partner_dashboard', { role: 'partner' });

  const [sites, setSites] = useState<Site[]>([]);
  const [stats, setStats] = useState<RoleDashboardStat[]>([]);
  const [roster, setRoster] = useState<RoleLinkedRoster | null>(null);
  const [loading, setLoading] = useState(true);

  const activeSiteId = useMemo(
    () => profile?.activeSiteId || profile?.siteIds?.[0] || undefined,
    [profile?.activeSiteId, profile?.siteIds],
  );

  useEffect(() => {
    async function fetchPartnerData() {
      if (!profile) {
        setLoading(false);
        return;
      }

      try {
        const siteIds = (profile.siteIds || []).filter((id) => typeof id === 'string' && id.trim().length > 0);
        const safeSiteIds = siteIds.slice(0, 10);

        const sitePromise =
          safeSiteIds.length > 0
            ? getDocs(query(sitesCollection, where(documentId(), 'in', safeSiteIds)))
            : Promise.resolve(null);

        const [sitesSnap, snapshot, linkedRoster] = await Promise.all([
          sitePromise,
          fetchRoleDashboardSnapshot({
            role: 'partner',
            siteId: activeSiteId,
            period: 'week',
          }),
          activeSiteId
            ? fetchRoleLinkedRoster({
                role: 'partner',
                siteId: activeSiteId,
              })
            : Promise.resolve(null),
        ]);

        setSites(sitesSnap ? sitesSnap.docs.map((doc) => doc.data()) : []);
        setStats(snapshot.stats);
        setRoster(linkedRoster);
      } catch (error) {
        console.error('Error fetching partner dashboard data:', error);
        setSites([]);
        setStats([]);
        setRoster(null);
      } finally {
        setLoading(false);
      }
    }

    if (!authLoading) {
      void fetchPartnerData();
    }
  }, [activeSiteId, authLoading, profile]);

  const visibleStats = stats.length > 0 ? stats : [
    { label: 'Associated Sites', value: String(sites.length) },
    { label: 'Learners Supported', value: String(roster?.counts.learners || 0) },
    { label: 'Active Programs', value: '0' },
  ];

  return (
    <RoleRouteGuard allowedRoles={['partner']}>
      {authLoading || loading ? (
        <div className="flex min-h-screen items-center justify-center">
          <div className="text-lg text-gray-600">{t('role.partner.loading')}</div>
        </div>
      ) : (
        <div className="min-h-screen bg-gray-50 p-4 sm:p-8">
          <div className="mx-auto max-w-7xl">
            <header className="mb-8 border-b border-gray-200 pb-4">
              <h1 className="text-3xl font-bold tracking-tight text-gray-900">
                {t('role.partner.title')}
              </h1>
              <p className="mt-2 text-sm text-gray-500">
                {t('role.partner.subtitle', {
                  name: profile?.displayName || t('role.partner.defaultName'),
                })}
                {profile?.organizationId && (
                  <span className="ml-1">
                    {t('role.partner.organization', {
                      organizationId: profile.organizationId,
                    })}
                  </span>
                )}
              </p>
            </header>

            <div className="grid grid-cols-1 gap-6 lg:grid-cols-3">
              <div className="space-y-6 lg:col-span-2">
                <section>
                  <h2 className="mb-4 text-lg font-medium leading-6 text-gray-900">
                    {t('role.partner.associatedSites')}
                  </h2>
                  {sites.length === 0 ? (
                    <div className="overflow-hidden rounded-lg bg-white p-6 text-center text-gray-500 shadow">
                      <p>{t('role.partner.noSites')}</p>
                    </div>
                  ) : (
                    <div className="grid gap-4 sm:grid-cols-2">
                      {sites.map((site) => (
                        <div
                          key={site.id}
                          className="overflow-hidden rounded-lg bg-white shadow transition-shadow hover:shadow-md"
                        >
                          <div className="p-5">
                            <h3 className="text-lg font-medium text-gray-900">{site.name}</h3>
                            <p className="text-sm text-gray-500">
                              {site.location || t('role.partner.noLocation')}
                            </p>
                            <div className="mt-4">
                              <span className="inline-flex items-center rounded-full bg-blue-50 px-2 py-1 text-xs font-medium text-blue-700">
                                {t('common.active')}
                              </span>
                            </div>
                          </div>
                          <div className="bg-gray-50 px-5 py-3">
                            <Link
                              href={`/${locale}/partner`}
                              className="text-sm font-medium text-indigo-700 hover:text-indigo-900"
                              onClick={() =>
                                trackInteraction('feature_discovered', {
                                  cta: 'partner_view_reports',
                                  siteId: site.id,
                                })
                              }
                            >
                              {t('role.partner.viewReports')}
                            </Link>
                          </div>
                        </div>
                      ))}
                    </div>
                  )}
                </section>
              </div>

              <div className="space-y-6">
                <div className="overflow-hidden rounded-lg bg-white shadow">
                  <div className="p-5">
                    <h3 className="text-base font-semibold leading-6 text-gray-900">
                      {t('role.partner.impactOverview')}
                    </h3>
                    <div className="mt-4 border-t border-gray-100 pt-4">
                      <dl className="divide-y divide-gray-100">
                        {visibleStats.map((stat) => (
                          <div key={stat.label} className="flex justify-between py-2 text-sm">
                            <dt className="text-gray-500">{stat.label}</dt>
                            <dd className="font-medium text-gray-900">{stat.value}</dd>
                          </div>
                        ))}
                        {roster && (
                          <div className="flex justify-between py-2 text-sm">
                            <dt className="text-gray-500">Selected site parents</dt>
                            <dd className="font-medium text-gray-900">{roster.counts.parents}</dd>
                          </div>
                        )}
                      </dl>
                    </div>
                  </div>
                </div>

                <div className="overflow-hidden rounded-lg bg-white shadow">
                  <div className="p-5">
                    <h3 className="text-base font-semibold leading-6 text-gray-900">
                      {t('role.partner.resources')}
                    </h3>
                    <div className="mt-4 space-y-2">
                      <Link
                        href={`/${locale}/partner`}
                        className="block text-sm text-indigo-600 hover:text-indigo-500"
                        onClick={() =>
                          trackInteraction('feature_discovered', {
                            cta: 'partner_download_impact_report',
                          })
                        }
                      >
                        {t('role.partner.downloadImpactReport')}
                      </Link>
                      <Link
                        href={`/${locale}/partner`}
                        className="block text-sm text-indigo-600 hover:text-indigo-500"
                        onClick={() =>
                          trackInteraction('feature_discovered', {
                            cta: 'partner_view_guidelines',
                          })
                        }
                      >
                        {t('role.partner.partnerGuidelines')}
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
