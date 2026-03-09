export interface E2ESessionPayload {
  uid: string;
  email: string;
  displayName: string;
  role: string;
  siteIds?: string[];
  activeSiteId?: string | null;
}

const E2E_SESSION_PREFIX = 'e2e:';

export function encodeE2ESession(payload: E2ESessionPayload): string {
  return `${E2E_SESSION_PREFIX}${Buffer.from(JSON.stringify(payload), 'utf8').toString('base64url')}`;
}

export function decodeE2ESession(value: string | null | undefined): E2ESessionPayload | null {
  if (!value || !value.startsWith(E2E_SESSION_PREFIX)) {
    return null;
  }

  try {
    const raw = Buffer.from(value.slice(E2E_SESSION_PREFIX.length), 'base64url').toString('utf8');
    const parsed = JSON.parse(raw) as Partial<E2ESessionPayload>;

    if (
      typeof parsed.uid !== 'string' ||
      typeof parsed.email !== 'string' ||
      typeof parsed.displayName !== 'string' ||
      typeof parsed.role !== 'string'
    ) {
      return null;
    }

    return {
      uid: parsed.uid,
      email: parsed.email,
      displayName: parsed.displayName,
      role: parsed.role,
      siteIds: Array.isArray(parsed.siteIds) ? parsed.siteIds.filter((entry): entry is string => typeof entry === 'string') : [],
      activeSiteId: typeof parsed.activeSiteId === 'string' ? parsed.activeSiteId : null,
    };
  } catch {
    return null;
  }
}