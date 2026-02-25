import { randomUUID } from 'crypto';
import { guardedFetch } from './security/egressGuard';

export type InternalInferenceService = 'llm' | 'stt' | 'tts' | 'bos';
export type InternalInferenceAuthMode = 'metadata' | 'none' | 'static';

export interface InternalInferenceContextHeaders {
  traceId: string;
  siteId: string;
  role: string;
  gradeBand: string;
  locale: string;
  policyVersion: string;
  requestId?: string;
  callerService: string;
}

interface InternalInferenceInvocationOptions<TBody extends Record<string, unknown>> {
  service: InternalInferenceService;
  body: TBody;
  context: InternalInferenceContextHeaders;
  timeoutMs?: number;
}

export interface InternalInferenceCallResult<TResponse> {
  ok: boolean;
  data?: TResponse;
  errorCode?: string;
  meta: {
    service: InternalInferenceService;
    route: 'internal' | 'local';
    endpoint?: string;
    audience?: string;
    authMode: InternalInferenceAuthMode;
    statusCode?: number;
  };
}

const SERVICE_ENDPOINT_ENV: Record<InternalInferenceService, string> = {
  llm: 'INTERNAL_LLM_INFERENCE_URL',
  stt: 'INTERNAL_STT_INFERENCE_URL',
  tts: 'INTERNAL_TTS_INFERENCE_URL',
  bos: 'INTERNAL_BOS_POLICY_INFERENCE_URL',
};

const SERVICE_AUDIENCE_ENV: Record<InternalInferenceService, string> = {
  llm: 'INTERNAL_LLM_INFERENCE_AUDIENCE',
  stt: 'INTERNAL_STT_INFERENCE_AUDIENCE',
  tts: 'INTERNAL_TTS_INFERENCE_AUDIENCE',
  bos: 'INTERNAL_BOS_POLICY_INFERENCE_AUDIENCE',
};

const SERVICE_DEFAULT_PATH: Record<InternalInferenceService, string> = {
  llm: '/v1/chat',
  stt: '/v1/transcribe',
  tts: '/v1/speak',
  bos: '/v1/policy',
};

const DEFAULT_TIMEOUT_MS = 12_000;

function envString(name: string): string | undefined {
  const value = process.env[name];
  if (!value) return undefined;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : undefined;
}

function normalizeBaseUrl(url: string): string {
  return url.replace(/\/+$/g, '');
}

function joinUrl(baseUrl: string, path: string): string {
  const normalizedBase = normalizeBaseUrl(baseUrl);
  const normalizedPath = path.startsWith('/') ? path : `/${path}`;
  return `${normalizedBase}${normalizedPath}`;
}

function resolveEndpoint(service: InternalInferenceService): string | undefined {
  const specific = envString(SERVICE_ENDPOINT_ENV[service]);
  if (specific) return specific;
  const base = envString('INTERNAL_INFERENCE_GATEWAY_BASE_URL');
  if (!base) return undefined;
  return joinUrl(base, SERVICE_DEFAULT_PATH[service]);
}

export function isInternalInferenceEnabled(service: InternalInferenceService): boolean {
  return Boolean(resolveEndpoint(service));
}

function resolveAuthMode(): InternalInferenceAuthMode {
  const explicit = envString('INTERNAL_INFERENCE_AUTH_MODE')?.toLowerCase();
  if (explicit === 'none') return 'none';
  if (explicit === 'static') return 'static';
  if (explicit === 'metadata') return 'metadata';
  if (envString('INTERNAL_INFERENCE_STATIC_ID_TOKEN')) return 'static';
  return 'metadata';
}

function resolveAudience(service: InternalInferenceService, endpoint: string): string {
  const explicit = envString(SERVICE_AUDIENCE_ENV[service]) ?? envString('INTERNAL_INFERENCE_AUDIENCE');
  if (explicit) return explicit;
  try {
    const parsed = new URL(endpoint);
    return `${parsed.protocol}//${parsed.host}`;
  } catch {
    return endpoint;
  }
}

function metadataIdentityEndpoint(): string {
  return envString('INTERNAL_METADATA_IDENTITY_ENDPOINT') ??
    'http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/identity';
}

async function fetchMetadataIdentityToken(audience: string, timeoutMs: number): Promise<string> {
  const url = `${metadataIdentityEndpoint()}?audience=${encodeURIComponent(audience)}&format=full`;
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const response = await fetch(url, {
      method: 'GET',
      headers: {
        'Metadata-Flavor': 'Google',
      },
      signal: controller.signal,
    });
    if (!response.ok) {
      throw new Error(`metadata_identity_http_${response.status}`);
    }
    const token = (await response.text()).trim();
    if (!token) {
      throw new Error('metadata_identity_empty_token');
    }
    return token;
  } finally {
    clearTimeout(timer);
  }
}

async function mintInternalAuthorizationToken(
  service: InternalInferenceService,
  endpoint: string,
  timeoutMs: number,
): Promise<{ authMode: InternalInferenceAuthMode; token?: string; audience?: string }> {
  const authMode = resolveAuthMode();
  if (authMode === 'none') {
    return { authMode };
  }

  if (authMode === 'static') {
    const token = envString('INTERNAL_INFERENCE_STATIC_ID_TOKEN');
    if (!token) {
      throw new Error('internal_static_token_missing');
    }
    return { authMode, token };
  }

  const audience = resolveAudience(service, endpoint);
  const token = await fetchMetadataIdentityToken(audience, timeoutMs);
  return { authMode, token, audience };
}

function parseJsonSafe<TValue = Record<string, unknown>>(raw: string): TValue | undefined {
  try {
    return JSON.parse(raw) as TValue;
  } catch {
    return undefined;
  }
}

function sanitizeErrorCode(error: unknown): string {
  const raw = error instanceof Error ? error.message : String(error);
  const normalized = raw.toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '');
  return normalized.length > 0 ? normalized.slice(0, 120) : 'unknown_error';
}

export async function callInternalInferenceJson<
  TBody extends Record<string, unknown>,
  TResponse = Record<string, unknown>,
>(options: InternalInferenceInvocationOptions<TBody>): Promise<InternalInferenceCallResult<TResponse>> {
  const endpoint = resolveEndpoint(options.service);
  const timeoutMs = Number.isFinite(options.timeoutMs) && (options.timeoutMs ?? 0) > 0
    ? Number(options.timeoutMs)
    : DEFAULT_TIMEOUT_MS;

  if (!endpoint) {
    return {
      ok: false,
      errorCode: 'endpoint_not_configured',
      meta: {
        service: options.service,
        route: 'local',
        authMode: resolveAuthMode(),
      },
    };
  }

  let auth: { authMode: InternalInferenceAuthMode; token?: string; audience?: string };
  try {
    auth = await mintInternalAuthorizationToken(options.service, endpoint, timeoutMs);
  } catch (error) {
    return {
      ok: false,
      errorCode: sanitizeErrorCode(error),
      meta: {
        service: options.service,
        route: 'internal',
        endpoint,
        authMode: resolveAuthMode(),
      },
    };
  }
  const requestId = options.context.requestId ?? `inference-${options.service}-${randomUUID()}`;
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
    'X-Trace-Id': options.context.traceId,
    'X-Site-Id': options.context.siteId,
    'X-Role': options.context.role,
    'X-Grade-Band': options.context.gradeBand,
    'X-Locale': options.context.locale,
    'X-Policy-Version': options.context.policyVersion,
    'X-Request-Id': requestId,
    'X-Caller-Service': options.context.callerService,
    'X-Inference-Service': options.service,
  };
  if (auth.token) {
    headers.Authorization = `Bearer ${auth.token}`;
  }

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const response = await guardedFetch(endpoint, {
      method: 'POST',
      headers,
      body: JSON.stringify(options.body),
      signal: controller.signal,
    }, { source: `internalInference.${options.service}`, mode: 'internal-ai-only' });

    const raw = await response.text();
    const parsed = parseJsonSafe<TResponse>(raw);
    if (!response.ok) {
      return {
        ok: false,
        errorCode: `http_${response.status}`,
        meta: {
          service: options.service,
          route: 'internal',
          endpoint,
          audience: auth.audience,
          authMode: auth.authMode,
          statusCode: response.status,
        },
      };
    }

    if (!parsed) {
      return {
        ok: false,
        errorCode: 'invalid_json_response',
        meta: {
          service: options.service,
          route: 'internal',
          endpoint,
          audience: auth.audience,
          authMode: auth.authMode,
          statusCode: response.status,
        },
      };
    }

    return {
      ok: true,
      data: parsed,
      meta: {
        service: options.service,
        route: 'internal',
        endpoint,
        audience: auth.audience,
        authMode: auth.authMode,
        statusCode: response.status,
      },
    };
  } catch (error) {
    return {
      ok: false,
      errorCode: sanitizeErrorCode(error),
      meta: {
        service: options.service,
        route: 'internal',
        endpoint,
        audience: auth.audience,
        authMode: auth.authMode,
      },
    };
  } finally {
    clearTimeout(timer);
  }
}
