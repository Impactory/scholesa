'use client';

import { useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { useAuthContext } from '@/src/firebase/auth/AuthProvider';

export default function DashboardRedirect({ params }: { params: { locale: string } }) {
  const { user, profile, loading } = useAuthContext();
  const router = useRouter();
  const locale = params.locale || 'en';

  useEffect(() => {
    if (loading) return;

    if (!user) {
      // Not logged in -> Login
      router.replace(`/${locale}/login`);
      return;
    }

    if (profile?.role) {
      // Logged in with role -> Role Dashboard
      // Note: (protected) is a route group, so it is omitted from the URL
      router.replace(`/${locale}/${profile.role}`);
    } else {
      // Logged in but no role -> Onboarding or Error
      console.warn('User has no role assigned:', user.uid);
      // router.replace(`/${locale}/onboarding`); // Uncomment if you have onboarding
    }
  }, [user, profile, loading, router, locale]);

  return (
    <div className="flex items-center justify-center min-h-screen">
      <div className="animate-pulse text-lg font-medium text-gray-600">
        Redirecting to your dashboard...
      </div>
    </div>
  );
}