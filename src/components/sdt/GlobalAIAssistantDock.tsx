'use client';

import { useEffect, useMemo, useState } from 'react';
import { usePathname } from 'next/navigation';
import { useAuthContext } from '@/src/firebase/auth/AuthProvider';
import { AICoachPopup } from './AICoachPopup';
import { useI18n } from '@/src/lib/i18n/useI18n';
import { fetchRoleLinkedRoster } from '@/src/lib/dashboard/roleDashboardApi';
import { normalizeUserRole } from '@/src/lib/auth/roleAliases';
import { resolveActiveSiteId } from '@/src/lib/auth/activeSite';

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
  const { t } = useI18n();
  const pathname = usePathname();
  const [selectedLearnerId, setSelectedLearnerId] = useState<string | undefined>(undefined);
  const [linkedLearnerIds, setLinkedLearnerIds] = useState<string[]>([]);
  const [linkedParentIds, setLinkedParentIds] = useState<string[]>([]);
  const [linkedEducatorIds, setLinkedEducatorIds] = useState<string[]>([]);

  const activeSiteId = useMemo(
    () => resolveActiveSiteId(profile) ?? '',
    [profile],
  );
  const actorRole = normalizeUserRole(profile?.role) || 'learner';

  useEffect(() => {
    if (!user || !profile || !activeSiteId) {
      setSelectedLearnerId(undefined);
      setLinkedLearnerIds([]);
      setLinkedParentIds([]);
      setLinkedEducatorIds([]);
      return;
    }

    if (actorRole === 'learner') {
      setSelectedLearnerId(user.uid);
      setLinkedLearnerIds([user.uid]);
      setLinkedParentIds([]);
      setLinkedEducatorIds([]);
      return;
    }

    let cancelled = false;
    const loadRoster = async () => {
      try {
        const roster = await fetchRoleLinkedRoster({
          role: actorRole,
          siteId: activeSiteId,
        });
        if (cancelled) return;
        const learnerIds = roster.learners.map((item) => item.uid || item.id);
        setLinkedLearnerIds(learnerIds);
        setLinkedParentIds(roster.parents.map((item) => item.uid || item.id));
        setLinkedEducatorIds(roster.educators.map((item) => item.uid || item.id));
        setSelectedLearnerId(
          actorRole === 'parent' || actorRole === 'educator'
            ? learnerIds[0] || undefined
            : undefined,
        );
      } catch (error) {
        console.error('Failed to load linked roster for AI assistant dock.', error);
        if (cancelled) return;
        setSelectedLearnerId(undefined);
        setLinkedLearnerIds([]);
        setLinkedParentIds([]);
        setLinkedEducatorIds([]);
      }
    };

    void loadRoster();
    return () => {
      cancelled = true;
    };
  }, [activeSiteId, actorRole, profile?.uid, user?.uid]);

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
      actorId={user.uid}
      actorRole={actorRole}
      actorDisplayName={profile.displayName || t('common.userLabel')}
      siteId={activeSiteId}
      grade={defaultGradeForRole(profile.role)}
      selectedLearnerId={selectedLearnerId}
      linkedLearnerIds={linkedLearnerIds}
      linkedParentIds={linkedParentIds}
      linkedEducatorIds={linkedEducatorIds}
    />
  );
}
