'use client';
import React from 'react';
import { CheckCircle2, LockKeyhole, Network, ShieldCheck } from 'lucide-react';

import { AuthProvider, useAuthContext } from '@/src/firebase/auth/AuthProvider';
import { useRouter } from 'next/navigation';
import { useEffect } from 'react';
import { Spinner } from '@/src/components/ui/Spinner';
import { Navigation } from '@/src/features/navigation/components/Navigation';
import { useI18n } from '@/src/lib/i18n/useI18n';
import { GlobalAIAssistantDock } from '@/src/components/sdt/GlobalAIAssistantDock';

const showAssistantDock = process.env.NEXT_PUBLIC_E2E_TEST_MODE !== '1';

export default function ProtectedLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <AuthProvider>
      <ProtectedShell>{children}</ProtectedShell>
    </AuthProvider>
  );
}

function ProtectedShell({ children }: { children: React.ReactNode }) {
  const { user, profile, loading } = useAuthContext();
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
    <div className="min-h-screen bg-cyan-50 text-app-foreground dark:bg-slate-950">
      <Navigation />
      <main className="py-6 sm:py-8 lg:py-10">
        <div className="mx-auto max-w-7xl space-y-6 px-4 sm:px-6 lg:px-8">
          <section
            className="rounded-md border border-cyan-200 bg-white p-4 shadow-sm dark:border-slate-700 dark:bg-slate-900"
            aria-label="Gold evidence cockpit"
          >
            <div className="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
              <div className="flex items-start gap-3">
                <div className="rounded-md bg-cyan-100 p-2 text-cyan-700 dark:bg-cyan-950 dark:text-cyan-300">
                  <ShieldCheck className="h-5 w-5" aria-hidden="true" />
                </div>
                <div>
                  <p className="text-sm font-bold uppercase text-cyan-700 dark:text-cyan-300">
                    Current Gold operating surface
                  </p>
                  <h1 className="mt-1 text-xl font-bold text-slate-950 dark:text-white">
                    Evidence chain cockpit
                  </h1>
                  <p className="mt-1 max-w-3xl text-sm leading-6 text-slate-600 dark:text-slate-300">
                    Capture, verify, interpret, and communicate learner capability evidence with
                    provenance across the active role view.
                  </p>
                </div>
              </div>
              <div className="grid gap-2 sm:grid-cols-3 lg:min-w-[28rem]">
                <div className="rounded-md border border-emerald-200 bg-emerald-50 p-3 dark:border-emerald-800 dark:bg-emerald-950/30">
                  <div className="flex items-center gap-2 text-sm font-bold text-emerald-800 dark:text-emerald-200">
                    <CheckCircle2 className="h-4 w-4" aria-hidden="true" />
                    Web GO
                  </div>
                  <p className="mt-1 text-xs text-emerald-900 dark:text-emerald-100">Cloud Run evidence packet</p>
                </div>
                <div className="rounded-md border border-blue-200 bg-blue-50 p-3 dark:border-blue-800 dark:bg-blue-950/30">
                  <div className="flex items-center gap-2 text-sm font-bold text-blue-800 dark:text-blue-200">
                    <Network className="h-4 w-4" aria-hidden="true" />
                    {profile?.role || 'role'}
                  </div>
                  <p className="mt-1 text-xs text-blue-900 dark:text-blue-100">Role-scoped evidence view</p>
                </div>
                <div className="rounded-md border border-amber-200 bg-amber-50 p-3 dark:border-amber-800 dark:bg-amber-950/30">
                  <div className="flex items-center gap-2 text-sm font-bold text-amber-900 dark:text-amber-100">
                    <LockKeyhole className="h-4 w-4" aria-hidden="true" />
                    Native gated
                  </div>
                  <p className="mt-1 text-xs text-amber-950 dark:text-amber-100">Store proof still required</p>
                </div>
              </div>
            </div>
          </section>
          {children}
        </div>
      </main>
      {showAssistantDock ? <GlobalAIAssistantDock /> : null}
    </div>
  );
}
