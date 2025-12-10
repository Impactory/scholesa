'use client';

import { useEffect } from 'react';
import { useRouter, useParams } from 'next/navigation';
import { useAuth } from '@/src/lib/auth/useUser';
import { Spinner } from '@/src/components/ui/Spinner';

export default function DashboardRedirect() {
  const { user, loading } = useAuth();
  const router = useRouter();
  const params = useParams();
  const locale = params.locale as string;

  useEffect(() => {
    if (!loading) {
      if (!user) {
        router.push(`/${locale}/login`);
      } else {
        // TODO: Fetch user role from Firestore or Auth Claims
        // For now, defaulting to 'learner' or based on some mock logic
        // This will be enhanced in Phase 3
        const role = 'learner'; 
        router.push(`/${locale}/${role}`);
      }
    }
  }, [user, loading, router, locale]);

  return (
    <div className="flex h-screen items-center justify-center">
      <Spinner />
    </div>
  );
}
