'use client';

import { signOut } from 'firebase/auth';
import { useRouter, useParams } from 'next/navigation';
import { auth } from '@/src/firebase/client-init';
import { useInteractionTracking } from '@/src/hooks/useTelemetry';

export function SignOutButton() {
  const router = useRouter();
  const params = useParams();
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
      Sign out
    </button>
  );
}