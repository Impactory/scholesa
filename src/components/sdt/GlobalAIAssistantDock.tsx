'use client';

import { useMemo } from 'react';
import { usePathname } from 'next/navigation';
import { useAuthContext } from '@/src/firebase/auth/AuthProvider';
import { AICoachPopup } from './AICoachPopup';

function defaultGradeForRole(role: string | undefined): number {
  switch (role) {
    case 'learner':
      return 5;
    case 'parent':
      return 6;
    case 'educator':
      return 7;
    case 'site':
    case 'partner':
    case 'hq':
      return 10;
    default:
      return 6;
  }
}

export function GlobalAIAssistantDock() {
  const { user, profile, loading } = useAuthContext();
  const pathname = usePathname();

  const activeSiteId = useMemo(
    () => profile?.activeSiteId || profile?.siteIds?.[0] || '',
    [profile?.activeSiteId, profile?.siteIds],
  );

  if (loading || !user || !profile) {
    return null;
  }

  if (!activeSiteId) {
    return null;
  }

  if (pathname?.includes('/login') || pathname?.includes('/register')) {
    return null;
  }

  return (
    <AICoachPopup
      learnerId={user.uid}
      studentName={profile.displayName || 'Scholesa User'}
      siteId={activeSiteId}
      grade={defaultGradeForRole(profile.role)}
    />
  );
}
