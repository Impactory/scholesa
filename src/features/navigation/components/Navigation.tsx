'use client';

import { useAuthContext } from '@/src/firebase/auth/AuthProvider';
import { Button } from '@/src/components/ui/Button';
import { useRouter } from 'next/navigation';
import { useInteractionTracking } from '@/src/hooks/useTelemetry';
import { useI18n } from '@/src/lib/i18n/useI18n';

export function Navigation() {
  const { user, signOut } = useAuthContext();
  const router = useRouter();
  const trackInteraction = useInteractionTracking();
  const { locale, t } = useI18n();

  const handleSignOut = async () => {
    await signOut();
    router.push(`/${locale}/login`);
  };

  if (!user) {
    return null;
  }

  return (
    <nav className="bg-white border-b border-gray-200">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex justify-between h-16">
          <div className="flex">
            <div className="flex-shrink-0 flex items-center">
              <span className="font-bold text-xl text-indigo-600">Scholesa</span>
            </div>
          </div>
          <div className="flex items-center">
            <span className="mr-4 text-sm text-gray-700">
              {t('navigation.signedInAs', { identity: user.displayName || user.email || '' })}
            </span>
            <Button
              onClick={() => {
                trackInteraction('help_accessed', { cta: 'navigation_sign_out' });
                handleSignOut();
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
