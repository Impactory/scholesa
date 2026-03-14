import type { SupportedLocale } from '@/src/lib/i18n/config';
import type { UserRole } from '@/src/types/user';

export type EnterpriseSsoProviderType = 'oidc' | 'saml';

export interface EnterpriseSsoProviderRecord {
  id: string;
  providerId: string;
  providerType: EnterpriseSsoProviderType;
  displayName: string;
  siteIds: string[];
  defaultSiteId?: string | null;
  defaultRole?: UserRole | null;
  allowedDomains?: string[];
  organizationId?: string | null;
  buttonText?: string | null;
  jitProvisioning?: boolean;
  enabled?: boolean;
}

export interface EnterpriseDecodedToken {
  uid: string;
  email?: string | null;
  name?: string | null;
  [key: string]: unknown;
}

const USER_ROLES = new Set<UserRole>(['learner', 'parent', 'educator', 'site', 'partner', 'hq']);

function normalizeString(value: unknown): string {
  return typeof value === 'string' ? value.trim() : '';
}

export function toStringArray(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return Array.from(new Set(value
    .filter((entry): entry is string => typeof entry === 'string' && entry.trim().length > 0)
    .map((entry) => entry.trim())));
}

export function isEnterpriseSsoProviderId(providerId: string | null | undefined): boolean {
  const normalized = normalizeString(providerId).toLowerCase();
  return normalized.startsWith('oidc.') || normalized.startsWith('saml.');
}

export function getEnterpriseSsoProviderType(providerId: string): EnterpriseSsoProviderType | null {
  const normalized = normalizeString(providerId).toLowerCase();
  if (normalized.startsWith('oidc.')) return 'oidc';
  if (normalized.startsWith('saml.')) return 'saml';
  return null;
}

export function normalizeUserRole(value: unknown): UserRole | null {
  const normalized = normalizeString(value).toLowerCase();
  if (!normalized) return null;
  if (normalized === 'sitelead' || normalized === 'site_lead') return 'site';
  return USER_ROLES.has(normalized as UserRole) ? normalized as UserRole : null;
}

function extractMappedRole(token: EnterpriseDecodedToken): UserRole | null {
  const direct = normalizeUserRole(token.scholesa_role || token.role);
  if (direct) return direct;
  const firebaseClaims = token.firebase;
  if (firebaseClaims && typeof firebaseClaims === 'object' && !Array.isArray(firebaseClaims)) {
    return normalizeUserRole((firebaseClaims as Record<string, unknown>).scholesa_role);
  }
  return null;
}

function extractMappedSiteIds(token: EnterpriseDecodedToken): string[] {
  if (Array.isArray(token.scholesa_site_ids)) {
    return toStringArray(token.scholesa_site_ids);
  }
  if (Array.isArray(token.siteIds)) {
    return toStringArray(token.siteIds);
  }
  const firebaseClaims = token.firebase;
  if (firebaseClaims && typeof firebaseClaims === 'object' && !Array.isArray(firebaseClaims)) {
    return toStringArray((firebaseClaims as Record<string, unknown>).scholesa_site_ids);
  }
  return [];
}

function extractActiveSiteId(token: EnterpriseDecodedToken): string {
  const direct = normalizeString(token.scholesa_active_site_id || token.activeSiteId);
  if (direct) return direct;
  const firebaseClaims = token.firebase;
  if (firebaseClaims && typeof firebaseClaims === 'object' && !Array.isArray(firebaseClaims)) {
    return normalizeString((firebaseClaims as Record<string, unknown>).scholesa_active_site_id);
  }
  return '';
}

export function sanitizeEnterpriseSsoProvider(record: Record<string, unknown>): EnterpriseSsoProviderRecord | null {
  const providerId = normalizeString(record.providerId);
  const providerType = getEnterpriseSsoProviderType(providerId);
  if (!providerId || !providerType) return null;

  return {
    id: normalizeString(record.id) || providerId,
    providerId,
    providerType,
    displayName: normalizeString(record.displayName) || providerId,
    siteIds: toStringArray(record.siteIds),
    defaultSiteId: normalizeString(record.defaultSiteId) || null,
    defaultRole: normalizeUserRole(record.defaultRole),
    allowedDomains: toStringArray(record.allowedDomains),
    organizationId: normalizeString(record.organizationId) || null,
    buttonText: normalizeString(record.buttonText) || null,
    jitProvisioning: record.jitProvisioning !== false,
    enabled: record.enabled !== false,
  };
}

export function buildEnterpriseSsoButtonLabel(provider: EnterpriseSsoProviderRecord, locale: SupportedLocale): string {
  if (provider.buttonText && provider.buttonText.trim().length > 0) {
    return provider.buttonText.trim();
  }

  switch (locale) {
    case 'zh-CN':
      return `使用 ${provider.displayName} 登录`;
    case 'zh-TW':
      return `使用 ${provider.displayName} 登入`;
    case 'th':
      return `ลงชื่อเข้าใช้ด้วย ${provider.displayName}`;
    default:
      return `Continue with ${provider.displayName}`;
  }
}

export function filterEnterpriseSsoProviders(
  providers: EnterpriseSsoProviderRecord[],
  input: { email?: string | null; siteId?: string | null },
): EnterpriseSsoProviderRecord[] {
  const emailDomain = normalizeString(input.email).split('@')[1]?.toLowerCase() || '';
  const requestedSiteId = normalizeString(input.siteId);

  return providers.filter((provider) => {
    if (provider.enabled === false) return false;
    if (requestedSiteId && provider.siteIds.length > 0 && !provider.siteIds.includes(requestedSiteId)) {
      return false;
    }
    if (emailDomain && provider.allowedDomains && provider.allowedDomains.length > 0) {
      return provider.allowedDomains.map((domain) => domain.toLowerCase()).includes(emailDomain);
    }
    return true;
  });
}

export function buildEnterpriseSsoProfileUpdate(input: {
  token: EnterpriseDecodedToken;
  existingUser: Record<string, unknown> | null;
  provider: EnterpriseSsoProviderRecord;
  locale: SupportedLocale;
}): Record<string, unknown> {
  const { token, existingUser, provider, locale } = input;
  const existingSiteIds = toStringArray(existingUser?.siteIds);
  const mappedSiteIds = extractMappedSiteIds(token);
  const siteIds = Array.from(new Set([
    ...existingSiteIds,
    ...(mappedSiteIds.length > 0 ? mappedSiteIds : provider.siteIds),
  ])).filter((value) => value.length > 0);
  const activeSiteId = normalizeString(existingUser?.activeSiteId)
    || extractActiveSiteId(token)
    || normalizeString(provider.defaultSiteId)
    || siteIds[0]
    || null;
  const role = normalizeUserRole(existingUser?.role)
    || extractMappedRole(token)
    || provider.defaultRole
    || 'educator';

  return {
    email: normalizeString(token.email) || normalizeString(existingUser?.email) || null,
    displayName: normalizeString(token.name) || normalizeString(existingUser?.displayName) || normalizeString(token.email) || 'Enterprise user',
    preferredLocale: locale,
    role,
    siteIds,
    activeSiteId,
    organizationId: normalizeString(existingUser?.organizationId) || provider.organizationId || null,
    authProviderId: provider.providerId,
    authProviderType: provider.providerType,
    authMethods: Array.from(new Set([
      ...toStringArray(existingUser?.authMethods),
      provider.providerId,
    ])),
    jitProvisioned: true,
    updatedAt: new Date(),
  };
}

export function extractSignInProvider(decodedToken: EnterpriseDecodedToken): string {
  const firebaseClaims = decodedToken.firebase;
  if (firebaseClaims && typeof firebaseClaims === 'object' && !Array.isArray(firebaseClaims)) {
    return normalizeString((firebaseClaims as Record<string, unknown>).sign_in_provider);
  }
  return '';
}