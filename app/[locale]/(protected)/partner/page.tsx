'use client';

import { useEffect, useState } from 'react';
import { query, where, getDocs, documentId } from 'firebase/firestore';
import { useAuthContext } from '@/src/firebase/auth/AuthProvider';
import { sitesCollection } from '@/src/lib/firestore/collections';
import type { Site } from '@/schema';

export default function PartnerDashboard() {
  const { profile, loading: authLoading } = useAuthContext();
  const [sites, setSites] = useState<Site[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function fetchPartnerSites() {
      if (!profile?.siteIds?.length) {
        setLoading(false);
        return;
      }

      try {
        // Fetch sites linked to this partner
        // Firestore 'in' query is limited to 10 items.
        // For a real app, chunking would be needed if a partner has > 10 sites.
        const safeSiteIds = profile.siteIds.slice(0, 10);
        const qSites = query(
          sitesCollection,
          where(documentId(), 'in', safeSiteIds)
        );
        
        const sitesSnap = await getDocs(qSites);
        setSites(sitesSnap.docs.map(doc => doc.data()));
      } catch (error) {
        console.error('Error fetching partner sites:', error);
      } finally {
        setLoading(false);
      }
    }

    if (!authLoading) {
      fetchPartnerSites();
    }
  }, [profile, authLoading]);

  if (authLoading || loading) {
    return (
      <div className="flex min-h-screen items-center justify-center">
        <div className="text-lg text-gray-600">Loading partner dashboard...</div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50 p-4 sm:p-8">
      <div className="mx-auto max-w-7xl">
        <header className="mb-8 border-b border-gray-200 pb-4">
          <h1 className="text-3xl font-bold tracking-tight text-gray-900">
            Partner Portal
          </h1>
          <p className="mt-2 text-sm text-gray-500">
            Welcome, {profile?.displayName || 'Partner'}. 
            {profile?.organizationId && <span className="ml-1">Organization: {profile.organizationId}</span>}
          </p>
        </header>

        <div className="grid grid-cols-1 gap-6 lg:grid-cols-3">
          {/* Main Content */}
          <div className="lg:col-span-2 space-y-6">
            <section>
              <h2 className="text-lg font-medium leading-6 text-gray-900 mb-4">Associated Sites</h2>
              {sites.length === 0 ? (
                <div className="overflow-hidden rounded-lg bg-white shadow p-6 text-center text-gray-500">
                  <p>No sites linked to your account.</p>
                </div>
              ) : (
                <div className="grid gap-4 sm:grid-cols-2">
                  {sites.map((site) => (
                    <div key={site.id} className="overflow-hidden rounded-lg bg-white shadow hover:shadow-md transition-shadow">
                      <div className="p-5">
                        <h3 className="text-lg font-medium text-gray-900">{site.name}</h3>
                        <p className="text-sm text-gray-500">{site.location || 'No location'}</p>
                        <div className="mt-4">
                          <span className="inline-flex items-center rounded-full bg-blue-50 px-2 py-1 text-xs font-medium text-blue-700">
                            Active
                          </span>
                        </div>
                      </div>
                      <div className="bg-gray-50 px-5 py-3">
                        <div className="text-sm">
                          <a href="#" className="font-medium text-indigo-700 hover:text-indigo-900">
                            View Reports
                          </a>
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </section>
          </div>

          {/* Sidebar */}
          <div className="space-y-6">
            <div className="overflow-hidden rounded-lg bg-white shadow">
              <div className="p-5">
                <h3 className="text-base font-semibold leading-6 text-gray-900">Impact Overview</h3>
                <div className="mt-4 border-t border-gray-100 pt-4">
                  <dl className="divide-y divide-gray-100">
                    <div className="flex justify-between py-2 text-sm">
                      <dt className="text-gray-500">Total Learners Supported</dt>
                      <dd className="font-medium text-gray-900">-</dd>
                    </div>
                    <div className="flex justify-between py-2 text-sm">
                      <dt className="text-gray-500">Active Programs</dt>
                      <dd className="font-medium text-gray-900">-</dd>
                    </div>
                  </dl>
                </div>
              </div>
            </div>
            
            <div className="overflow-hidden rounded-lg bg-white shadow">
              <div className="p-5">
                <h3 className="text-base font-semibold leading-6 text-gray-900">Resources</h3>
                <div className="mt-4 space-y-2">
                  <a href="#" className="block text-sm text-indigo-600 hover:text-indigo-500">Download Impact Report</a>
                  <a href="#" className="block text-sm text-indigo-600 hover:text-indigo-500">Partner Guidelines</a>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}