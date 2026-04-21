import type { UserProfile } from '@/src/types/user';

type SiteScopedProfile = Pick<UserProfile, 'activeSiteId' | 'siteIds' | 'studioId'>;

export function resolveActiveSiteId(profile: SiteScopedProfile | null | undefined): string | null {
  const directSiteId = typeof profile?.activeSiteId === 'string' ? profile.activeSiteId.trim() : '';
  if (directSiteId) {
    return directSiteId;
  }

  const firstSiteId = profile?.siteIds?.find((siteId) => typeof siteId === 'string' && siteId.trim())?.trim();
  if (firstSiteId) {
    return firstSiteId;
  }

  const legacyStudioId = typeof profile?.studioId === 'string' ? profile.studioId.trim() : '';
  return legacyStudioId || null;
}
