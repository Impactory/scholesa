import { normalizeLocale, type SupportedLocale } from '@/src/lib/i18n/config';
import { aiSafeFetch } from '@/src/lib/ai/egressGuard';

const DEFAULT_TIMEOUT_MS = 25_000;

export interface CopilotVoiceRequest {
  idToken: string;
  message: string;
  siteId?: string;
  locale?: SupportedLocale | string;
  screenId?: string;
  traceId?: string;
  context?: Record<string, unknown>;
  voice?: {
    enabled?: boolean;
    output?: boolean;
  };
  gradeBand?: string;
}

export interface CopilotVoiceResponse {
  text: string;
  metadata: {
    requestId?: string;
    traceId: string;
    safetyOutcome: 'allowed' | 'blocked' | 'modified' | 'escalated';
    safetyReasonCode: string;
    policyVersion: string;
    modelVersion: string | null;
    locale: SupportedLocale;
    role: 'student' | 'teacher' | 'parent' | 'admin';
    gradeBand: string;
    toolsInvoked: string[];
    quietModeActive: boolean;
    redactionApplied: boolean;
    redactionCount: number;
    understandingSource?: 'heuristic' | 'model' | 'blended' | null;
    responseGenerationSource?: 'local' | 'model' | 'guardrail' | null;
    understanding?: {
      intent?: string | null;
      complexity?: string | null;
      needsScaffold?: boolean | null;
      emotionalState?: string | null;
      confidence?: number | null;
      responseMode?: string | null;
      topicTags?: string[] | null;
    };
  };
  tts: {
    available: boolean;
    audioUrl?: string;
    voiceProfile?: string;
  };
}

export interface TranscribeVoiceRequest {
  idToken: string;
  audioBlob: Blob;
  siteId?: string;
  locale?: SupportedLocale | string;
  partial?: boolean;
  traceId?: string;
  context?: Record<string, unknown>;
}

export interface TranscribeVoiceResponse {
  transcript: string;
  confidence: number;
  metadata: {
    requestId?: string;
    traceId: string;
    locale: SupportedLocale;
    latencyMs: number;
    partial: boolean;
    modelVersion: string | null;
    understandingSource?: 'heuristic' | 'model' | 'blended' | null;
    understanding?: {
      intent?: string | null;
      complexity?: string | null;
      needsScaffold?: boolean | null;
      emotionalState?: string | null;
      confidence?: number | null;
      responseMode?: string | null;
      topicTags?: string[] | null;
    };
  };
}

function createVoiceRequestId(prefix: string): string {
  if (typeof globalThis !== 'undefined' && globalThis.crypto?.randomUUID) {
    return `${prefix}-${globalThis.crypto.randomUUID()}`;
  }
  return `${prefix}-${Date.now()}-${Math.random().toString(16).slice(2, 10)}`;
}

function createVoiceTraceId(prefix: string): string {
  if (typeof globalThis !== 'undefined' && globalThis.crypto?.randomUUID) {
    return `${prefix}-${globalThis.crypto.randomUUID()}`;
  }
  return `${prefix}-${Date.now()}-${Math.random().toString(16).slice(2, 10)}`;
}

function defaultVoiceApiBaseUrl(): string | null {
  const explicit = process.env.NEXT_PUBLIC_VOICE_API_BASE_URL?.trim();
  if (explicit) return explicit.replace(/\/+$/g, '');
  const projectId = process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID?.trim();
  if (!projectId) return null;
  return `https://us-central1-${projectId}.cloudfunctions.net/voiceApi`;
}

function withTimeout<T>(promise: Promise<T>, timeoutMs: number): Promise<T> {
  return new Promise<T>((resolve, reject) => {
    const timeout = setTimeout(() => reject(new Error('Voice help took too long to respond. Please try again.')), timeoutMs);
    promise.then(
      (value) => {
        clearTimeout(timeout);
        resolve(value);
      },
      (error: unknown) => {
        clearTimeout(timeout);
        reject(error);
      },
    );
  });
}

async function parseErrorResponse(response: Response): Promise<string> {
  try {
    const json = await response.json() as { message?: string; error?: string };
    return json.message || json.error || `HTTP ${response.status}`;
  } catch {
    return `HTTP ${response.status}`;
  }
}

async function postJson<TResponse>(path: string, idToken: string, body: Record<string, unknown>): Promise<TResponse> {
  const baseUrl = defaultVoiceApiBaseUrl();
  if (!baseUrl) throw new Error('Voice help is unavailable right now. Complete voice setup and try again.');
  const localeHeader = typeof body.locale === 'string' ? normalizeLocale(body.locale) : 'en';
  const requestId = createVoiceRequestId('voice-json');
  const traceId = typeof body.traceId === 'string' && body.traceId.trim().length > 0
    ? body.traceId.trim()
    : undefined;
  const response = await withTimeout(
    aiSafeFetch(`${baseUrl}${path}`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${idToken}`,
        'Content-Type': 'application/json',
        'x-request-id': requestId,
        'x-scholesa-locale': localeHeader,
        ...(traceId ? { 'x-trace-id': traceId } : {}),
      },
      body: JSON.stringify(body),
    }, 'voiceService.postJson'),
    DEFAULT_TIMEOUT_MS,
  );
  if (!response.ok) {
    throw new Error(await parseErrorResponse(response));
  }
  return response.json() as Promise<TResponse>;
}

export async function sendCopilotVoiceMessage(req: CopilotVoiceRequest): Promise<CopilotVoiceResponse> {
  const locale = normalizeLocale(req.locale);
  return postJson<CopilotVoiceResponse>('/copilot/message', req.idToken, {
    message: req.message,
    siteId: req.siteId,
    screenId: req.screenId || 'ai_coach_popup',
    traceId: req.traceId,
    context: req.context || {},
    locale,
    gradeBand: req.gradeBand,
    voice: {
      enabled: req.voice?.enabled !== false,
      output: req.voice?.output !== false,
    },
  });
}

export async function transcribeVoiceAudio(req: TranscribeVoiceRequest): Promise<TranscribeVoiceResponse> {
  const baseUrl = defaultVoiceApiBaseUrl();
  if (!baseUrl) throw new Error('Voice help is unavailable right now. Complete voice setup and try again.');
  const locale = normalizeLocale(req.locale);
  const requestId = createVoiceRequestId('voice-stt');
  const traceId = req.traceId || createVoiceTraceId('voice-trace');
  const formData = new FormData();
  formData.append('audio', req.audioBlob, 'voice-input.webm');
  formData.append('locale', locale);
  formData.append('partial', req.partial ? 'true' : 'false');
  formData.append('traceId', traceId);
  if (req.siteId) {
    formData.append('siteId', req.siteId);
  }
  if (req.context && Object.keys(req.context).length > 0) {
    formData.append('context', JSON.stringify(req.context));
  }
  if (req.context?.voiceTraceId) {
    formData.append('voiceTraceId', String(req.context.voiceTraceId));
  }
  if (req.context?.voiceInputTraceId) {
    formData.append('voiceInputTraceId', String(req.context.voiceInputTraceId));
  }

  const response = await withTimeout(
    aiSafeFetch(`${baseUrl}/voice/transcribe`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${req.idToken}`,
        'x-request-id': requestId,
        'x-trace-id': traceId,
        'x-scholesa-locale': locale,
      },
      body: formData,
    }, 'voiceService.transcribe'),
    DEFAULT_TIMEOUT_MS,
  );
  if (!response.ok) {
    throw new Error(await parseErrorResponse(response));
  }
  return response.json() as Promise<TranscribeVoiceResponse>;
}

export interface StreamTtsRequest {
  idToken: string;
  text: string;
  locale: string;
  emotionalState?: string;
  needsScaffold?: boolean;
}

export async function streamTtsSpeech(req: StreamTtsRequest): Promise<Response> {
  const baseUrl = defaultVoiceApiBaseUrl();
  if (!baseUrl) throw new Error('Voice help is unavailable right now.');
  const locale = normalizeLocale(req.locale);
  const requestId = createVoiceRequestId('voice-tts-stream');

  return withTimeout(
    aiSafeFetch(`${baseUrl}/tts/stream`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${req.idToken}`,
        'Content-Type': 'application/json',
        'x-request-id': requestId,
        'x-scholesa-locale': locale,
      },
      body: JSON.stringify({
        text: req.text,
        locale,
        emotionalState: req.emotionalState ?? 'neutral',
        needsScaffold: req.needsScaffold ?? false,
      }),
    }, 'voiceService.ttsStream'),
    15_000,
  );
}

export function voiceApiConfigured(): boolean {
  return Boolean(defaultVoiceApiBaseUrl());
}
