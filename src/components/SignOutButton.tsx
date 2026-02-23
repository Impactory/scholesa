'use client';

import { signOut } from 'firebase/auth';
import { useRouter, useParams } from 'next/navigation';
import { auth } from '@/src/firebase/client-init';
import { useInteractionTracking } from '@/src/hooks/useTelemetry';
import { useI18n } from '@/src/lib/i18n/useI18n';

export function SignOutButton() {
  const router = useRouter();
  const params = useParams();
  const { t } = useI18n();
  const locale = (params?.locale as string) || 'en';
  const trackInteraction = useInteractionTracking();

  const handleSignOut = async () => {
    try {
      await signOut(auth);
      router.push(`/${locale}/login`);
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
      className="text-sm font-medium text-gray-500 hover:text-gray-900"
    >
      {t('navigation.signOut')}
    </button>
  );
}
