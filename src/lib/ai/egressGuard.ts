export const AI_BLOCKED_HOST_MARKERS = [
  'generativelanguage.googleapis.com',
  'ai.google.dev',
  'vertexai.googleapis.com',
  'aiplatform.googleapis.com',
];

const DEFAULT_INTERNAL_AI_HOST_MARKERS = [
  'scholesa-ai',
  'scholesa-tts',
  'scholesa-stt',
  'cloudfunctions.net',
  'a.run.app',
  'localhost',
  '127.0.0.1',
];

interface SecurityEgressBlockedEvent {
  event: 'SECURITY_EGRESS_BLOCKED';
  source: string;
  url: string;
  host: string;
  reason: 'blocked_host' | 'non_internal_host';
  timestamp: string;
}

function hostFromUrl(rawUrl: string): string {
  try {
    const parsed = rawUrl.startsWith('http://') || rawUrl.startsWith('https://')
      ? new URL(rawUrl)
      : (typeof window !== 'undefined'
          ? new URL(rawUrl, window.location.origin)
          : new URL(rawUrl, 'http://localhost'));
    return parsed.hostname.toLowerCase();
  } catch {
    return '';
  }
}

function matchesHostMarker(host: string, marker: string): boolean {
  return host === marker || host.endsWith(`.${marker}`) || host.includes(marker);
}

function getInternalAllowMarkers(): string[] {
  const custom = process.env.NEXT_PUBLIC_INTERNAL_AI_HOST_ALLOWLIST;
  if (!custom) return DEFAULT_INTERNAL_AI_HOST_MARKERS;
  const parsed = custom
    .split(',')
    .map((entry) => entry.trim().toLowerCase())
    .filter(Boolean);
  return parsed.length > 0 ? parsed : DEFAULT_INTERNAL_AI_HOST_MARKERS;
}

function emitSecurityEgressBlocked(payload: SecurityEgressBlockedEvent): void {
  console.error('SECURITY_EGRESS_BLOCKED', payload);
}

export function assertInternalAiEgress(url: string, source: string): void {
  const host = hostFromUrl(url);
  if (!host) {
    throw new Error(`Invalid URL for AI egress guard: ${url}`);
  }

  const blockedMarker = AI_BLOCKED_HOST_MARKERS.find((marker) => matchesHostMarker(host, marker));
  if (blockedMarker) {
    emitSecurityEgressBlocked({
      event: 'SECURITY_EGRESS_BLOCKED',
      source,
      url,
      host,
      reason: 'blocked_host',
      timestamp: new Date().toISOString(),
    });
    throw new Error(`Blocked AI egress host: ${host}`);
  }

  const allowMarkers = getInternalAllowMarkers();
  const allowed = allowMarkers.some((marker) => matchesHostMarker(host, marker));
  if (!allowed) {
    emitSecurityEgressBlocked({
      event: 'SECURITY_EGRESS_BLOCKED',
      source,
      url,
      host,
      reason: 'non_internal_host',
      timestamp: new Date().toISOString(),
    });
    throw new Error(`Non-internal AI egress host blocked: ${host}`);
  }
}

export async function aiSafeFetch(
  url: string,
  init: RequestInit,
  source: string
): Promise<Response> {
  assertInternalAiEgress(url, source);
  return fetch(url, init);
}
