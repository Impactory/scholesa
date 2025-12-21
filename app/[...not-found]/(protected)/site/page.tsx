'use client';

import React from 'react';
import { useAuthContext } from '@/src/firebase/auth/AuthProvider';
import { SiteStats } from '@/src/features/site/components/SiteStats';

export default function SiteDashboard() {
  const { profile } = useAuthContext();

  return (
    <div className="container mx-auto max-w-6xl p-6 space-y-8">
      <header>
        <h1 className="text-3xl font-bold text-gray-900">Site Lead Dashboard</h1>
        <p className="text-gray-500 mt-1">
          Overview for {profile?.studioId ? `Site ${profile.studioId}` : 'your site'}.
        </p>
      </header>

      <section>
        <SiteStats />
      </section>
    </div>
  );
}