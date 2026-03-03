export interface CoppaConsentRecord {
  active?: boolean;
  agreementSigned?: boolean;
  educationalUseOnly?: boolean;
  parentNoticeProvided?: boolean;
  noStudentMarketing?: boolean;
}

export interface CoppaUserProfile {
  role?: string;
  siteIds?: string[];
  activeSiteId?: string;
}

export function normalizeString(value: unknown): string | undefined {
  if (typeof value !== 'string') return undefined;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : undefined;
}

export function normalizeStringArray(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value
    .filter((entry): entry is string => typeof entry === 'string' && entry.trim().length > 0)
    .map((entry) => entry.trim());
}

export function dedupeStrings(values: string[]): string[] {
  const seen = new Set<string>();
  const out: string[] = [];
  for (const value of values) {
    if (seen.has(value)) continue;
    seen.add(value);
    out.push(value);
  }
  return out;
}

export function isCoppaConsentActive(consent: CoppaConsentRecord | null | undefined): boolean {
  if (!consent) return false;
  return consent.active === true
    && consent.agreementSigned === true
    && consent.educationalUseOnly === true
    && consent.parentNoticeProvided === true
    && consent.noStudentMarketing === true;
}

export function hasSiteAccess(profile: CoppaUserProfile | null | undefined, siteId: string): boolean {
  if (!profile) return false;

  const role = normalizeString(profile.role)?.toLowerCase();
  if (role === 'hq') return true;

  const siteIds = dedupeStrings([
    ...normalizeStringArray(profile.siteIds),
    ...(normalizeString(profile.activeSiteId) ? [normalizeString(profile.activeSiteId)!] : []),
  ]);

  return siteIds.includes(siteId);
}
