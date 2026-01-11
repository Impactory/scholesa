'use client';

import { useEffect, useState } from 'react';
import { doc, getDoc } from 'firebase/firestore';
import { useAuthContext } from '@/src/firebase/auth/AuthProvider';
import { sitesCollection } from '@/src/lib/firestore/collections';
import type { Site } from '@/schema';

export default function SiteDashboard() {
  const { profile, loading: authLoading } = useAuthContext();
  const [site, setSite] = useState<Site | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function fetchSiteData() {
      if (!profile?.siteIds?.length) {
        setLoading(false);
        return;
      }

      try {
        // Fetch the first site assigned to the user
        // In a multi-site scenario, you might show a site selector here
        const siteId = profile.siteIds[0];
        const siteRef = doc(sitesCollection, siteId);
        const siteSnap = await getDoc(siteRef);

        if (siteSnap.exists()) {
          setSite(siteSnap.data());
        }
      } catch (error) {
        console.error('Error fetching site data:', error);
      } finally {
        setLoading(false);
      }
    }

    if (!authLoading) {
      fetchSiteData();
    }
  }, [profile, authLoading]);

  if (authLoading || loading) {
    return (
      <div className="flex min-h-screen items-center justify-center">
        <div className="text-lg text-gray-600">Loading dashboard...</div>
      </div>
    );
  }

  if (!site) {
    return (
      <div className="flex min-h-screen items-center justify-center">
        <div className="text-center">
          <h1 className="text-2xl font-bold text-gray-900">No Site Found</h1>
          <p className="mt-2 text-gray-600">
            You are logged in as a Site Lead, but no site is linked to your account.
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50 p-4 sm:p-8">
      <div className="mx-auto max-w-7xl">
        <header className="mb-8 border-b border-gray-200 pb-4">
          <h1 className="text-3xl font-bold tracking-tight text-gray-900">
            {site.name}
          </h1>
          <p className="mt-2 text-sm text-gray-500">
            Site Lead Dashboard • {site.location || 'No location set'}
          </p>
        </header>

        <div className="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
          {/* Stat Card 1: Learners */}
          <div className="overflow-hidden rounded-lg bg-white shadow">
            <div className="p-5">
              <div className="flex items-center">
                <div className="flex-shrink-0">
                  <div className="flex h-10 w-10 items-center justify-center rounded-full bg-indigo-100 text-indigo-600">
                    👥
                  </div>
                </div>
                <div className="ml-5 w-0 flex-1">
                  <dl>
                    <dt className="truncate text-sm font-medium text-gray-500">Total Learners</dt>
                    <dd>
                      <div className="text-lg font-medium text-gray-900">-</div>
                    </dd>
                  </dl>
                </div>
              </div>
            </div>
            <div className="bg-gray-50 px-5 py-3">
              <div className="text-sm">
                <a href="#" className="font-medium text-indigo-700 hover:text-indigo-900">View all</a>
              </div>
            </div>
          </div>

          {/* Stat Card 2: Sessions */}
          <div className="overflow-hidden rounded-lg bg-white shadow">
            <div className="p-5">
              <div className="flex items-center">
                <div className="flex-shrink-0">
                  <div className="flex h-10 w-10 items-center justify-center rounded-full bg-green-100 text-green-600">
                    📅
                  </div>
                </div>
                <div className="ml-5 w-0 flex-1">
                  <dl>
                    <dt className="truncate text-sm font-medium text-gray-500">Active Sessions</dt>
                    <dd>
                      <div className="text-lg font-medium text-gray-900">-</div>
                    </dd>
                  </dl>
                </div>
              </div>
            </div>
            <div className="bg-gray-50 px-5 py-3">
              <div className="text-sm">
                <a href="#" className="font-medium text-indigo-700 hover:text-indigo-900">Manage schedule</a>
              </div>
            </div>
          </div>
        </div>

        <div className="mt-8">
          <h2 className="text-lg font-medium leading-6 text-gray-900">Recent Activity</h2>
          <div className="mt-4 overflow-hidden rounded-lg bg-white shadow">
            <div className="p-6 text-center text-gray-500">No recent activity to show.</div>
          </div>
        </div>
      </div>
    </div>
  );
}