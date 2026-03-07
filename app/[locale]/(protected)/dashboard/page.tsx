'use client';

import { useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { useAuthContext } from '@/src/firebase/auth/AuthProvider';
import { useI18n } from '@/src/lib/i18n/useI18n';
import { getRoleDefaultRoute } from '@/src/lib/routing/workflowRoutes';
import { normalizeUserRole } from '@/src/lib/auth/roleAliases';

export default function DashboardRedirect() {
  const { user, profile, loading } = useAuthContext();
  const router = useRouter();
  const { locale, t } = useI18n();

  useEffect(() => {
    if (loading) return;

    if (!user) {
      // Not logged in -> Login
      router.replace(`/${locale}/login`);
      return;
    }

    const normalizedRole = normalizeUserRole(profile?.role);
    if (normalizedRole) {
      // Logged in with role -> canonical workflow route.
      router.replace(`/${locale}/${getRoleDefaultRoute(normalizedRole)}`);
    } else {
      // Logged in but no role -> Onboarding or Error
      console.warn('User has no role assigned:', user.uid);
      // router.replace(`/${locale}/onboarding`); // Uncomment if you have onboarding
    }
  }, [user, profile, loading, router, locale]);

  return (
    <div className="flex min-h-screen items-center justify-center bg-app-canvas">
      <div className="animate-pulse text-lg font-medium text-app-muted">
        {t('dashboard.redirecting')}
      </div>
    </div>
  );
}
