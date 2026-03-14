export type DistrictProvider = 'clever' | 'classlink';

export function normalizeDistrictProvider(value: string | null | undefined): DistrictProvider | null {
  const normalized = typeof value === 'string' ? value.trim().toLowerCase() : '';
  if (!normalized) return null;
  if (['clever'].includes(normalized)) return 'clever';
  if (['classlink', 'class_link', 'class-link', 'oneroster', 'one_roster', 'one-roster'].includes(normalized)) {
    return 'classlink';
  }
  return null;
}

export function districtProviderDisplayName(provider: DistrictProvider): string {
  return provider === 'clever' ? 'Clever' : 'ClassLink';
}

export function districtProviderDefaultAuthBaseUrl(provider: DistrictProvider): string {
  return provider === 'clever'
    ? 'https://clever.com/oauth/authorize'
    : 'https://launchpad.classlink.com/oauth2/v2/auth';
}

export function districtProviderSchoolField(provider: DistrictProvider): string {
  return provider === 'clever' ? 'cleverSchools' : 'classlinkSchools';
}

export function districtProviderSectionsField(provider: DistrictProvider): string {
  return provider === 'clever' ? 'cleverSectionsBySchool' : 'classlinkSectionsBySchool';
}

export function buildDistrictConnectionDocId(provider: DistrictProvider, siteId: string): string {
  return `${provider}_${siteId.trim().replace(/[^a-zA-Z0-9_-]/g, '_')}`;
}

export function districtProviderAuditAction(provider: DistrictProvider, action: string): string {
  return `${provider}.${action}`;
}

export function districtProviderRosterSyncJobType(provider: DistrictProvider, mode: 'preview' | 'apply'): string {
  return `${provider}_roster_${mode}`;
}