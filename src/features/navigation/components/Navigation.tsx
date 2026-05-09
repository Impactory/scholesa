'use client';

import Image from 'next/image';
import Link from 'next/link';
import { useAuthContext } from '@/src/firebase/auth/AuthProvider';
import { Button } from '@/src/components/ui/Button';
import { usePathname, useRouter } from 'next/navigation';
import { useInteractionTracking } from '@/src/hooks/useTelemetry';
import { useI18n } from '@/src/lib/i18n/useI18n';
import { ThemeModeToggle } from '@/src/lib/theme/ThemeModeToggle';
import { normalizeUserRole } from '@/src/lib/auth/roleAliases';
import { getRoleNavigationPaths, type WorkflowPath } from '@/src/lib/routing/workflowRoutes';

function formatRouteLabel(path: WorkflowPath): string {
  if (path === '/messages') return 'messages';
  if (path === '/notifications') return 'notifications';
  if (path === '/profile') return 'profile';
  if (path === '/settings') return 'settings';
  const parts = path.split('/').filter(Boolean);
  if (parts.length <= 1) return path.replace('/', '');
  return parts.slice(1).join(' / ');
}

export function Navigation() {
  const { user, profile, signOut } = useAuthContext();
  const router = useRouter();
  const pathname = usePathname();
  const trackInteraction = useInteractionTracking();
  const { locale, t } = useI18n();
  const normalizedRole = normalizeUserRole(profile?.role);
  const roleRoutes: WorkflowPath[] = normalizedRole
    ? getRoleNavigationPaths(normalizedRole)
    : ['/messages', '/notifications', '/profile', '/settings'];

  const handleSignOut = async () => {
    await signOut();
    router.replace(`/${locale}/login`);
    router.refresh();
  };

  if (!user) {
    return null;
  }

  return (
    <nav className="border-b border-cyan-200 bg-white/95 shadow-sm shadow-cyan-900/5 backdrop-blur dark:border-slate-800 dark:bg-slate-950/95">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex min-h-16 flex-wrap items-center justify-between gap-3 py-2">
          <div className="flex items-center gap-4">
            <div className="flex-shrink-0 flex items-center">
              <Link
                href={`/${locale}/dashboard`}
                className="flex items-center gap-2 rounded-md focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-app-primary"
                aria-label="Scholesa dashboard"
              >
                <Image
                  src="/logo/scholesa-logo-192.png"
                  alt=""
                  aria-hidden="true"
                  width={32}
                  height={32}
                  priority
                  className="h-8 w-8 shrink-0"
                />
                <span className="font-bold text-xl text-app-foreground">Scholesa</span>
              </Link>
            </div>
            <div className="hidden xl:flex flex-wrap items-center gap-2">
              {roleRoutes.map((routePath) => {
                const href = `/${locale}${routePath}`;
                const active = pathname === href;
                return (
                  <Link
                    key={routePath}
                    href={href}
                    onClick={() =>
                      trackInteraction('feature_discovered', {
                        cta: 'navigation_workflow_route',
                        routePath,
                      })
                    }
                    className={`rounded-md px-2.5 py-1.5 text-xs font-medium transition-colors ${
                      active
                        ? 'bg-cyan-700 text-white dark:bg-cyan-300 dark:text-slate-950'
                        : 'text-slate-600 hover:bg-cyan-50 hover:text-cyan-800 dark:text-slate-300 dark:hover:bg-slate-800 dark:hover:text-cyan-200'
                    }`}
                  >
                    {formatRouteLabel(routePath)}
                  </Link>
                );
              })}
            </div>
          </div>
          <div className="flex items-center gap-3">
            <ThemeModeToggle
              compact
              onPreferenceChange={(themePreference) => {
                trackInteraction('feature_discovered', {
                  cta: 'navigation_theme_preference_changed',
                  theme: themePreference,
                });
              }}
            />
            <span className="hidden md:inline text-sm text-app-muted">
              {t('navigation.signedInAs', { identity: user.displayName || user.email || '' })}
            </span>
            <Button
              onClick={async () => {
                trackInteraction('help_accessed', { cta: 'navigation_sign_out' });
                await handleSignOut();
              }}
              variant="ghost"
              size="sm"
            >
              {t('navigation.signOut')}
            </Button>
          </div>
        </div>
        <div className="flex flex-wrap items-center gap-2 pb-3 xl:hidden">
          {roleRoutes.map((routePath) => {
            const href = `/${locale}${routePath}`;
            const active = pathname === href;
            return (
              <Link
                key={`${routePath}-mobile`}
                href={href}
                onClick={() =>
                  trackInteraction('feature_discovered', {
                    cta: 'navigation_workflow_route_mobile',
                    routePath,
                  })
                }
                  className={`rounded-md px-2.5 py-1.5 text-xs font-medium transition-colors ${
                  active
                    ? 'bg-cyan-700 text-white dark:bg-cyan-300 dark:text-slate-950'
                    : 'text-slate-600 hover:bg-cyan-50 hover:text-cyan-800 dark:text-slate-300 dark:hover:bg-slate-800 dark:hover:text-cyan-200'
                }`}
              >
                {formatRouteLabel(routePath)}
              </Link>
            );
          })}
        </div>
      </div>
    </nav>
  );
}
