'use client';

import { useRouter, useParams } from 'next/navigation';
import { useInteractionTracking } from '@/src/hooks/useTelemetry';
import { useI18n } from '@/src/lib/i18n/useI18n';
import { useAuthContext } from '@/src/firebase/auth/AuthProvider';

export function SignOutButton() {
  const router = useRouter();
  const params = useParams();
  const { t } = useI18n();
  const locale = (params?.locale as string) || 'en';
  const trackInteraction = useInteractionTracking();
  const { signOut } = useAuthContext();

  const handleSignOut = async () => {
    try {
      await signOut();
      router.replace(`/${locale}/login`);
      router.refresh();
    } catch (error) {
      console.error('Error signing out:', error);
    }
  };

  return (
    <button
      onClick={() => {
        trackInteraction('help_accessed', { cta: 'sign_out_button' });
        handleSignOut();
      }}
      className="text-sm font-medium text-app-muted hover:text-app-foreground"
    >
      {t('navigation.signOut')}
    </button>
  );
}
