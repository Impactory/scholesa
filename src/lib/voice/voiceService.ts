import { normalizeLocale, type SupportedLocale } from '@/src/lib/i18n/config';
import { aiSafeFetch } from '@/src/lib/ai/egressGuard';

const DEFAULT_TIMEOUT_MS = 25_000;

export interface CopilotVoiceRequest {
  idToken: string;
  message: string;
  locale?: SupportedLocale | string;
  screenId?: string;
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
    modelVersion: string;
    locale: SupportedLocale;
    role: 'student' | 'teacher' | 'admin';
    gradeBand: string;
    toolsInvoked: string[];
    quietModeActive: boolean;
    redactionApplied: boolean;
    redactionCount: number;
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
  locale?: SupportedLocale | string;
  partial?: boolean;
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
    modelVersion: string;
  };
}

function createVoiceRequestId(prefix: string): string {
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
    const timeout = setTimeout(() => reject(new Error('Voice API request timed out.')), timeoutMs);
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
  if (!baseUrl) throw new Error('Voice API base URL is not configured.');
  const localeHeader = typeof body.locale === 'string' ? normalizeLocale(body.locale) : 'en';
  const requestId = createVoiceRequestId('voice-json');
  const response = await withTimeout(
    aiSafeFetch(`${baseUrl}${path}`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${idToken}`,
        'Content-Type': 'application/json',
        'x-request-id': requestId,
        'x-scholesa-locale': localeHeader,
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
    screenId: req.screenId || 'ai_coach_popup',
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
  if (!baseUrl) throw new Error('Voice API base URL is not configured.');
  const locale = normalizeLocale(req.locale);
  const requestId = createVoiceRequestId('voice-stt');
  const formData = new FormData();
  formData.append('audio', req.audioBlob, 'voice-input.webm');
  formData.append('locale', locale);
  formData.append('partial', req.partial ? 'true' : 'false');

  const response = await withTimeout(
    aiSafeFetch(`${baseUrl}/voice/transcribe`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${req.idToken}`,
        'x-request-id': requestId,
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

export function voiceApiConfigured(): boolean {
  return Boolean(defaultVoiceApiBaseUrl());
}
