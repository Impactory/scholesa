import { webcrypto } from 'node:crypto';
import { normalizeLocale, type SupportedLocale } from '@/src/lib/i18n/config';

const subtle = globalThis.crypto?.subtle ?? webcrypto.subtle;
const LTI_DEPLOYMENT_CLAIM = 'https://purl.imsglobal.org/spec/lti/claim/deployment_id';
const LTI_MESSAGE_TYPE_CLAIM = 'https://purl.imsglobal.org/spec/lti/claim/message_type';
const LTI_VERSION_CLAIM = 'https://purl.imsglobal.org/spec/lti/claim/version';
const LTI_RESOURCE_LINK_CLAIM = 'https://purl.imsglobal.org/spec/lti/claim/resource_link';
const LTI_TARGET_LINK_URI_CLAIM = 'https://purl.imsglobal.org/spec/lti/claim/target_link_uri';
const LTI_CUSTOM_CLAIM = 'https://purl.imsglobal.org/spec/lti/claim/custom';

export interface LtiPlatformRegistrationRecord {
  id: string;
  siteId: string;
  issuer: string;
  clientId: string;
  deploymentId: string;
  jwksUrl: string;
  status?: string;
}

export interface LtiResourceLinkRecord {
  id: string;
  registrationId: string;
  siteId: string;
  resourceLinkId: string;
  missionId?: string;
  sessionId?: string;
  targetPath?: string;
  locale?: string;
  lineItemId?: string;
  lineItemUrl?: string;
}

export interface ResolveLtiLaunchDependencies {
  loadPlatformRegistration: (input: {
    issuer: string;
    deploymentId: string;
    audiences: string[];
  }) => Promise<LtiPlatformRegistrationRecord | null>;
  loadResourceLink: (input: {
    registrationId: string;
    resourceLinkId: string;
  }) => Promise<LtiResourceLinkRecord | null>;
  recordLaunchAudit?: (entry: {
    issuer: string;
    clientId: string;
    deploymentId: string;
    registrationId: string;
    resourceLinkId: string;
    siteId: string | null;
    missionId: string | null;
    targetPath: string;
    locale: SupportedLocale;
    subject: string;
  }) => Promise<void>;
  fetchJson?: typeof fetch;
  now?: () => number;
}

export interface ResolvedLtiLaunch {
  locale: SupportedLocale;
  targetPath: string;
  registrationId: string;
  resourceLinkId: string;
  siteId: string | null;
  missionId: string | null;
  lineItemId: string | null;
  lineItemUrl: string | null;
  subject: string;
}

interface JwtHeader {
  alg?: string;
  kid?: string;
}

interface JwtClaims {
  iss?: string;
  aud?: string | string[];
  sub?: string;
  exp?: number;
  nbf?: number;
  iat?: number;
  [key: string]: unknown;
}

class LtiLaunchError extends Error {
  status: number;

  constructor(message: string, status = 400) {
    super(message);
    this.name = 'LtiLaunchError';
    this.status = status;
  }
}

function decodeBase64UrlSegment(input: string): Buffer {
  const normalized = input.replace(/-/g, '+').replace(/_/g, '/');
  const paddingLength = (4 - (normalized.length % 4 || 4)) % 4;
  const padded = normalized + '='.repeat(paddingLength);
  return Buffer.from(padded, 'base64');
}

function parseTokenPart<T>(segment: string, label: string): T {
  try {
    return JSON.parse(decodeBase64UrlSegment(segment).toString('utf8')) as T;
  } catch {
    throw new LtiLaunchError(`Invalid ${label}.`, 400);
  }
}

function stringifyAudience(aud: string | string[] | undefined): string[] {
  if (typeof aud === 'string' && aud.trim().length > 0) return [aud.trim()];
  if (!Array.isArray(aud)) return [];
  return aud.filter((value): value is string => typeof value === 'string' && value.trim().length > 0);
}

function asStringRecord(value: unknown): Record<string, string> {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return {};
  return Object.entries(value as Record<string, unknown>).reduce<Record<string, string>>((accumulator, [key, entry]) => {
    if (typeof entry === 'string' && entry.trim().length > 0) {
      accumulator[key] = entry.trim();
    }
    return accumulator;
  }, {});
}

function sanitizeTargetPath(input: string | undefined, fallbackPath: string, origin: string): string {
  if (!input || input.trim().length === 0) return fallbackPath;
  try {
    const parsed = new URL(input, origin);
    if (parsed.origin !== origin) return fallbackPath;
    return `${parsed.pathname}${parsed.search}`;
  } catch {
    return fallbackPath;
  }
}

async function loadJwks(jwksUrl: string, fetchJson: typeof fetch): Promise<JsonWebKey[]> {
  const response = await fetchJson(jwksUrl, {
    headers: {
      Accept: 'application/json',
    },
    cache: 'no-store',
  });

  if (!response.ok) {
    throw new LtiLaunchError('Unable to fetch LTI JWKS.', 502);
  }

  const body = await response.json() as { keys?: JsonWebKey[] };
  if (!Array.isArray(body.keys) || body.keys.length === 0) {
    throw new LtiLaunchError('LTI JWKS is empty.', 502);
  }

  return body.keys;
}

async function verifyTokenSignature(token: string, header: JwtHeader, jwksUrl: string, fetchJson: typeof fetch): Promise<void> {
  if (header.alg !== 'RS256') {
    throw new LtiLaunchError('Unsupported LTI signing algorithm.', 400);
  }

  const [encodedHeader, encodedPayload, encodedSignature] = token.split('.');
  const signingInput = Buffer.from(`${encodedHeader}.${encodedPayload}`);
  const signature = decodeBase64UrlSegment(encodedSignature);
  const keys = await loadJwks(jwksUrl, fetchJson);
  const matchingKey = keys.find((key) => key.kid === header.kid) || keys[0];
  if (!matchingKey) {
    throw new LtiLaunchError('No matching LTI verification key found.', 401);
  }

  const cryptoKey = await subtle.importKey(
    'jwk',
    matchingKey,
    {
      name: 'RSASSA-PKCS1-v1_5',
      hash: 'SHA-256',
    },
    false,
    ['verify'],
  );

  const verified = await subtle.verify('RSASSA-PKCS1-v1_5', cryptoKey, signature, signingInput);
  if (!verified) {
    throw new LtiLaunchError('LTI token signature verification failed.', 401);
  }
}

function validateClaims(claims: JwtClaims, registration: LtiPlatformRegistrationRecord, nowMs: number): void {
  const audiences = stringifyAudience(claims.aud);
  const deploymentId = typeof claims[LTI_DEPLOYMENT_CLAIM] === 'string' ? claims[LTI_DEPLOYMENT_CLAIM] as string : '';
  const messageType = typeof claims[LTI_MESSAGE_TYPE_CLAIM] === 'string' ? claims[LTI_MESSAGE_TYPE_CLAIM] as string : '';
  const version = typeof claims[LTI_VERSION_CLAIM] === 'string' ? claims[LTI_VERSION_CLAIM] as string : '';

  if (claims.iss !== registration.issuer) {
    throw new LtiLaunchError('LTI issuer mismatch.', 401);
  }
  if (!audiences.includes(registration.clientId)) {
    throw new LtiLaunchError('LTI audience mismatch.', 401);
  }
  if (deploymentId !== registration.deploymentId) {
    throw new LtiLaunchError('LTI deployment mismatch.', 401);
  }
  if (messageType !== 'LtiResourceLinkRequest') {
    throw new LtiLaunchError('Unsupported LTI message type.', 400);
  }
  if (version !== '1.3.0') {
    throw new LtiLaunchError('Unsupported LTI version.', 400);
  }

  const nowSeconds = Math.floor(nowMs / 1000);
  if (typeof claims.exp === 'number' && claims.exp < nowSeconds - 30) {
    throw new LtiLaunchError('Expired LTI launch token.', 401);
  }
  if (typeof claims.nbf === 'number' && claims.nbf > nowSeconds + 30) {
    throw new LtiLaunchError('LTI launch token is not active yet.', 401);
  }
}

export function getLtiErrorStatus(error: unknown): number {
  return error instanceof LtiLaunchError ? error.status : 500;
}

export function getLtiErrorMessage(error: unknown): string {
  return error instanceof Error ? error.message : 'Unexpected LTI launch failure.';
}

export async function resolveLtiLaunch(
  idToken: string,
  requestUrl: string,
  deps: ResolveLtiLaunchDependencies,
): Promise<ResolvedLtiLaunch> {
  const parts = idToken.split('.');
  if (parts.length !== 3) {
    throw new LtiLaunchError('Invalid LTI token.', 400);
  }

  const header = parseTokenPart<JwtHeader>(parts[0], 'LTI token header');
  const claims = parseTokenPart<JwtClaims>(parts[1], 'LTI token claims');
  const issuer = typeof claims.iss === 'string' ? claims.iss.trim() : '';
  const deploymentId = typeof claims[LTI_DEPLOYMENT_CLAIM] === 'string'
    ? String(claims[LTI_DEPLOYMENT_CLAIM]).trim()
    : '';
  const subject = typeof claims.sub === 'string' ? claims.sub.trim() : '';
  const resourceLinkClaim = claims[LTI_RESOURCE_LINK_CLAIM];
  const resourceLink =
    resourceLinkClaim && typeof resourceLinkClaim === 'object' && !Array.isArray(resourceLinkClaim)
      ? resourceLinkClaim as Record<string, unknown>
      : {};
  const resourceLinkId = typeof resourceLink.id === 'string' ? resourceLink.id.trim() : '';
  const audiences = stringifyAudience(claims.aud);

  if (!issuer || !deploymentId || !subject || !resourceLinkId || audiences.length === 0) {
    throw new LtiLaunchError('Missing required LTI claims.', 400);
  }

  const registration = await deps.loadPlatformRegistration({ issuer, deploymentId, audiences });
  if (!registration || registration.status === 'revoked') {
    throw new LtiLaunchError('No active LTI platform registration found.', 404);
  }

  const fetchJson = deps.fetchJson ?? fetch;
  const now = deps.now ?? Date.now;
  await verifyTokenSignature(idToken, header, registration.jwksUrl, fetchJson);
  validateClaims(claims, registration, now());

  const link = await deps.loadResourceLink({
    registrationId: registration.id,
    resourceLinkId,
  });
  const custom = asStringRecord(claims[LTI_CUSTOM_CLAIM]);
  const locale = normalizeLocale(custom.locale || link?.locale);
  const origin = new URL(requestUrl).origin;
  const fallbackPath = `/${locale}/learner`;
  const mappedTarget = link?.targetPath || custom.targetPath || undefined;
  const claimTarget = typeof claims[LTI_TARGET_LINK_URI_CLAIM] === 'string'
    ? claims[LTI_TARGET_LINK_URI_CLAIM] as string
    : undefined;
  const targetPath = sanitizeTargetPath(mappedTarget || claimTarget, fallbackPath, origin);
  const siteId = link?.siteId || custom.siteId || null;
  const missionId = link?.missionId || custom.missionId || null;
  const lineItemId = link?.lineItemId || custom.lineItemId || null;
  const lineItemUrl = link?.lineItemUrl || custom.lineItemUrl || null;

  await deps.recordLaunchAudit?.({
    issuer,
    clientId: registration.clientId,
    deploymentId,
    registrationId: registration.id,
    resourceLinkId,
    siteId,
    missionId,
    targetPath,
    locale,
    subject,
  });

  return {
    locale,
    targetPath,
    registrationId: registration.id,
    resourceLinkId,
    siteId,
    missionId,
    lineItemId,
    lineItemUrl,
    subject,
  };
}