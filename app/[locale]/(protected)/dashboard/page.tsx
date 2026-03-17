'use client';

import { useEffect, useRef } from 'react';
import { useRouter } from 'next/navigation';
import { useAuthContext } from '@/src/firebase/auth/AuthProvider';
import { useI18n } from '@/src/lib/i18n/useI18n';
import { getRoleDefaultRoute } from '@/src/lib/routing/workflowRoutes';
import { normalizeUserRole } from '@/src/lib/auth/roleAliases';

export default function DashboardRedirect() {
  const { user, profile, loading, signOut } = useAuthContext();
  const router = useRouter();
  const { locale, t } = useI18n();
  const handledInvalidProfileRef = useRef(false);

  useEffect(() => {
    if (loading) return;

    if (!user) {
      // Not logged in -> Login
      router.replace(`/${locale}/login`);
      return;
    }

    const normalizedRole = normalizeUserRole(profile?.role);
    if (normalizedRole) {
      handledInvalidProfileRef.current = false;
      // Logged in with role -> canonical workflow route.
      router.replace(`/${locale}/${getRoleDefaultRoute(normalizedRole)}`);
    } else {
      if (handledInvalidProfileRef.current) {
        return;
      }
      handledInvalidProfileRef.current = true;
      console.warn('User session is missing a provisioned role:', user.uid);
      void signOut()
        .catch((error) => {
          console.error('Failed to clear invalid session before redirecting to login.', error);
        })
        .finally(() => {
          router.replace(`/${locale}/login`);
        });
    }
  }, [user, profile, loading, router, locale, signOut]);

  return (
    <div className="flex min-h-screen items-center justify-center bg-app-canvas">
      <div className="animate-pulse text-lg font-medium text-app-muted">
        {t('dashboard.redirecting')}
      </div>
    </div>
  );
}
