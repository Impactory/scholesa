'use client';

import { useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { Spinner } from '@/src/components/ui/Spinner';
import { useAuthContext } from '@/src/firebase/auth/AuthProvider';
import { useI18n } from '@/src/lib/i18n/useI18n';
import { normalizeUserRole, roleIsAllowed } from '@/src/lib/auth/roleAliases';
import { getRoleDefaultRoute } from '@/src/lib/routing/workflowRoutes';
import type { UserRole } from '@/src/types/user';

interface RoleRouteGuardProps {
  allowedRoles: UserRole[];
  children: React.ReactNode;
}

export function RoleRouteGuard({ allowedRoles, children }: RoleRouteGuardProps) {
  const { user, profile, loading } = useAuthContext();
  const { locale, t } = useI18n();
  const router = useRouter();

  const normalizedRole = normalizeUserRole(profile?.role);
  const hasAccess = roleIsAllowed(profile?.role, allowedRoles);

  useEffect(() => {
    if (loading) return;
    if (!user) {
      router.replace(`/${locale}/login`);
      return;
    }
    if (!hasAccess) {
      const fallback = normalizedRole ? getRoleDefaultRoute(normalizedRole) : 'dashboard';
      router.replace(`/${locale}/${fallback}`);
    }
  }, [hasAccess, loading, locale, normalizedRole, router, user]);

  if (loading || !user || !hasAccess) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-app-canvas">
        <div className="flex items-center gap-3 text-app-muted">
          <Spinner />
          <span>{t('common.loading')}</span>
        </div>
      </div>
    );
  }

  return <>{children}</>;
}
