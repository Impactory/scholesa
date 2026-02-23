'use client';
import React from 'react';

import { useAuthContext } from '@/src/firebase/auth/AuthProvider';
import { useRouter } from 'next/navigation';
import { useEffect } from 'react';
import { Spinner } from '@/src/components/ui/Spinner';
import { Navigation } from '@/src/features/navigation/components/Navigation';
import { useI18n } from '@/src/lib/i18n/useI18n';

export default function ProtectedLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const { user, loading } = useAuthContext();
  const router = useRouter();
  const { locale, t } = useI18n();

  useEffect(() => {
    if (!loading && !user) {
      router.replace(`/${locale}/login`);
    }
  }, [user, loading, router, locale]);

  if (loading) {
    return (
      <div className="flex h-screen items-center justify-center bg-app-canvas">
        <div className="flex items-center gap-3 text-app-muted">
          <Spinner />
          <span>{t('common.loading')}</span>
        </div>
      </div>
    );
  }

  if (!user) {
    return null; // Will redirect in useEffect
  }

  return (
    <div className="min-h-screen bg-app-canvas">
      <Navigation />
      <main className="py-10">
        <div className="max-w-7xl mx-auto sm:px-6 lg:px-8">
          {children}
        </div>
      </main>
    </div>
  );
}
