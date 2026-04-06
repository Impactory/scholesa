'use client';

import { useAuthContext } from '@/src/firebase/auth/AuthProvider';
import { ReflectionJournal } from '@/src/components/sdt/ReflectionJournal';
import type { CustomRouteRendererProps } from '../customRouteRenderers';

export default function LearnerReflectionsRenderer({ ctx }: CustomRouteRendererProps) {
  const { profile } = useAuthContext();
  const siteId =
    profile?.activeSiteId ??
    (profile?.siteIds && profile.siteIds.length > 0 ? profile.siteIds[0] : '');

  return <ReflectionJournal learnerId={ctx.uid} siteId={siteId} />;
}
