'use client';

import { useAuthContext } from '@/src/firebase/auth/AuthProvider';
import { Button } from '@/src/components/ui/Button';
import { useRouter } from 'next/navigation';
import { useInteractionTracking } from '@/src/hooks/useTelemetry';
import { useI18n } from '@/src/lib/i18n/useI18n';
import { ThemeModeToggle } from '@/src/lib/theme/ThemeModeToggle';

export function Navigation() {
  const { user, signOut } = useAuthContext();
  const router = useRouter();
  const trackInteraction = useInteractionTracking();
  const { locale, t } = useI18n();

  const handleSignOut = async () => {
    await signOut();
    router.replace(`/${locale}/login`);
    router.refresh();
  };

  if (!user) {
    return null;
  }

  return (
    <nav className="bg-app-surface border-b border-app">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex justify-between h-16">
          <div className="flex">
            <div className="flex-shrink-0 flex items-center">
              <span className="font-bold text-xl text-app-foreground">Scholesa</span>
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
      </div>
    </nav>
  );
}
