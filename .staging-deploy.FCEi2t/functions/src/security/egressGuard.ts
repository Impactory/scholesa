import * as admin from 'firebase-admin';

const BLOCKED_AI_HOST_MARKERS = [
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

type GuardMode = 'general' | 'internal-ai-only';
type BlockReason = 'blocked_host' | 'non_internal_host' | 'invalid_url';

function hostnameFromUrl(url: string): string {
  try {
    return new URL(url).hostname.toLowerCase();
  } catch {
    return '';
  }
}

function matchesHostMarker(host: string, marker: string): boolean {
  return host === marker || host.endsWith(`.${marker}`) || host.includes(marker);
}

function internalAllowMarkers(): string[] {
  const fromEnv = process.env.INTERNAL_AI_HOST_ALLOWLIST;
  if (!fromEnv) return DEFAULT_INTERNAL_AI_HOST_MARKERS;
  const parsed = fromEnv
    .split(',')
    .map((entry) => entry.trim().toLowerCase())
    .filter(Boolean);
  return parsed.length > 0 ? parsed : DEFAULT_INTERNAL_AI_HOST_MARKERS;
}

async function emitSecurityEgressBlocked(details: {
  source: string;
  url: string;
  host: string;
  reason: BlockReason;
}) {
  const payload = {
    eventType: 'SECURITY_EGRESS_BLOCKED',
    source: details.source,
    url: details.url,
    host: details.host,
    reason: details.reason,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  };
  console.error('SECURITY_EGRESS_BLOCKED', payload);
  try {
    await admin.firestore().collection('securityAlerts').add(payload);
  } catch (error) {
    console.error('Failed to persist SECURITY_EGRESS_BLOCKED alert', error);
  }
}

export async function guardedFetch(
  url: string,
  init: RequestInit,
  options: { source: string; mode?: GuardMode }
): Promise<Response> {
  const host = hostnameFromUrl(url);
  if (!host) {
    await emitSecurityEgressBlocked({
      source: options.source,
      url,
      host: '',
      reason: 'invalid_url',
    });
    throw new Error(`Invalid outbound URL: ${url}`);
  }

  const blocked = BLOCKED_AI_HOST_MARKERS.some((marker) => matchesHostMarker(host, marker));
  if (blocked) {
    await emitSecurityEgressBlocked({
      source: options.source,
      url,
      host,
      reason: 'blocked_host',
    });
    throw new Error(`Blocked outbound host: ${host}`);
  }

  if (options.mode === 'internal-ai-only') {
    const allowed = internalAllowMarkers().some((marker) => matchesHostMarker(host, marker));
    if (!allowed) {
      await emitSecurityEgressBlocked({
        source: options.source,
        url,
        host,
        reason: 'non_internal_host',
      });
      throw new Error(`Non-internal AI host blocked: ${host}`);
    }
  }

  return fetch(url, init);
}

