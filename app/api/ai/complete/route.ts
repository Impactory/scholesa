import { randomUUID } from 'crypto';
import { NextResponse } from 'next/server';
import { getCurrentUserServer } from '@/src/firebase/auth/getCurrentUserServer';
import { resolveRequestLocale } from '@/src/lib/i18n/localeHeaders';
import { normalizeLocale, type SupportedLocale } from '@/src/lib/i18n/config';
import type { ModelRequest, ModelResponse } from '@/src/lib/ai/modelAdapter';
import { callInternalInferenceJson, isInternalInferenceRequired } from '@/src/lib/server/internalInferenceGateway';
import { localizedLowConfidenceSupport, localizedServiceUnavailable } from '@/src/lib/ai/multilingualGuardrails';

type SessionUser = Awaited<ReturnType<typeof getCurrentUserServer>>;
type AllowedRole = 'learner' | 'educator' | 'parent' | 'site' | 'partner' | 'hq';
type VoiceRequesterRole = 'student' | 'teacher' | 'parent' | 'admin';

type ParsedLlmPayload = {
  text?: string;
  modelVersion?: string;
  toolSuggestions?: string[];
  understanding?: {
    confidence?: number;
  };
};

const MIN_AUTONOMOUS_LEARNER_CONFIDENCE = 0.97;

function parseBody(body: unknown): ModelRequest | null {
  if (!body || typeof body !== 'object') return null;
  return body as ModelRequest;
}

function normalizeRole(value: unknown): AllowedRole | null {
  if (typeof value !== 'string') return null;
  const role = value.trim().toLowerCase();
  if (role === 'learner' || role === 'educator' || role === 'parent' || role === 'site' || role === 'partner' || role === 'hq') {
    return role;
  }
  return null;
}

function normalizeSiteIds(user: SessionUser): string[] {
  if (!user) return [];
  const claims = (user.customClaims ?? {}) as Record<string, unknown>;
  const values = [
    ...(Array.isArray(claims.siteIds) ? claims.siteIds : []),
    claims.activeSiteId,
  ];
  return values
    .filter((entry): entry is string => typeof entry === 'string' && entry.trim().length > 0)
    .map((entry) => entry.trim());
}

function ensureAccess(user: SessionUser, request: ModelRequest): NextResponse | null {
  if (!user) {
    return NextResponse.json({ error: 'unauthenticated' }, { status: 401 });
  }

  const claimsRole = normalizeRole((user.customClaims ?? {}).role);
  const requestRole = normalizeRole(request.role);
  if (!claimsRole || !requestRole) {
    return NextResponse.json({ error: 'forbidden' }, { status: 403 });
  }

  const siteIds = normalizeSiteIds(user);
  if (request.siteId && !siteIds.includes(request.siteId)) {
    return NextResponse.json({ error: 'site_access_denied' }, { status: 403 });
  }

  if (claimsRole === 'learner' && request.learnerId !== user.uid) {
    return NextResponse.json({ error: 'learner_scope_denied' }, { status: 403 });
  }

  return null;
}

function mapRequesterRole(role: AllowedRole): VoiceRequesterRole {
  if (role === 'learner') return 'student';
  if (role === 'educator') return 'teacher';
  if (role === 'parent') return 'parent';
  return 'admin';
}

function gradeBandFromAgeBand(ageBand: ModelRequest['gradeBand']): string {
  switch (ageBand) {
    case 'grades_1_3':
    case 'grades_4_6':
      return 'K-5';
    case 'grades_7_9':
      return '6-8';
    case 'grades_10_12':
      return '9-12';
    default:
      return 'All';
  }
}

function extractLlmPayload(data: unknown): ParsedLlmPayload | undefined {
  const root = data && typeof data === 'object' ? data as Record<string, unknown> : undefined;
  if (!root) return undefined;
  const response = root.response && typeof root.response === 'object' ? root.response as Record<string, unknown> : undefined;
  const output = response?.output && typeof response.output === 'object' ? response.output as Record<string, unknown> : undefined;
  const result = root.result && typeof root.result === 'object' ? root.result as Record<string, unknown> : undefined;
  const metadata = root.metadata && typeof root.metadata === 'object' ? root.metadata as Record<string, unknown> : undefined;

  const firstString = (...values: unknown[]): string | undefined => {
    const match = values.find((value) => typeof value === 'string' && value.trim().length > 0) as string | undefined;
    return match?.trim();
  };

  const toolSuggestions = [root.toolSuggestions, result?.toolSuggestions, output?.toolSuggestions, metadata?.toolSuggestions]
    .find((value) => Array.isArray(value)) as unknown[] | undefined;

  const understandingSource = [root.understanding, result?.understanding, output?.understanding, metadata?.understanding]
    .find((value) => value && typeof value === 'object') as Record<string, unknown> | undefined;

  return {
    text: firstString(root.text, result?.text, output?.text, response?.text, root.message, result?.message),
    modelVersion: firstString(root.modelVersion, result?.modelVersion, output?.modelVersion, metadata?.modelVersion),
    toolSuggestions: Array.isArray(toolSuggestions)
      ? toolSuggestions.filter((entry): entry is string => typeof entry === 'string' && entry.trim().length > 0).slice(0, 3)
      : undefined,
    understanding: understandingSource
      ? {
          confidence: typeof understandingSource.confidence === 'number' ? understandingSource.confidence : undefined,
        }
      : undefined,
  };
}

function parseConfidence(value: unknown): number | undefined {
  const numeric = typeof value === 'number' ? value : Number(value);
  if (!Number.isFinite(numeric)) return undefined;
  if (numeric < 0) return 0;
  if (numeric > 1) return 1;
  return numeric;
}

function requiresStrictConfidence(request: ModelRequest): boolean {
  return request.role === 'learner' || request.safetyConstraints.requireChildSafe;
}

function buildEscalatedGuardResponse(input: {
  request: ModelRequest;
  traceId: string;
  modelVersion: string;
  safetyReasonCode: string;
  confidence?: number;
  answer: string;
}): ModelResponse {
  return {
    answer: input.answer,
    followUpQuestions: undefined,
    citations: undefined,
    modelUsed: 'scholesa_server_inference_guard',
    modelVersion: input.modelVersion,
    promptTemplateId: input.request.promptTemplateId,
    policyVersion: input.request.policyVersion,
    safetyOutcome: 'escalated',
    safetyReasonCode: input.safetyReasonCode,
    toolCallIds: [],
    targetLocale: input.targetLocale,
    gradeBand: input.request.gradeBand,
    traceId: input.traceId,
    missionAttemptId: input.request.missionAttemptId,
    confidence: input.confidence,
    safetyFlags: ['coppa_confidence_guard'],
    tokensUsed: 0,
    latencyMs: 0,
  };
}

export async function POST(request: Request) {
  const locale = resolveRequestLocale(request.headers);
  const body = parseBody(await request.json());
  if (!body) {
    return NextResponse.json({ error: 'invalid_body' }, { status: 400 });
  }

  const user = await getCurrentUserServer();
  const accessError = ensureAccess(user, body);
  if (accessError) {
    return accessError;
  }

  const requesterRole = mapRequesterRole(normalizeRole(body.role) ?? 'learner');
  const traceId = body.traceId || `web-ai-${randomUUID()}`;
  const siteId = body.siteId;
  const targetLocale = normalizeLocale(body.targetLocale || locale);
  const inference = await callInternalInferenceJson<Record<string, unknown>, Record<string, unknown>>({
    service: 'llm',
    body: {
      message: `${body.localeInstruction}\n\n${body.studentQuestion}`,
      locale: targetLocale,
      localeInstruction: body.localeInstruction,
      role: body.role,
      requesterRole,
      gradeBand: gradeBandFromAgeBand(body.gradeBand),
      taskType: body.taskType,
      studentLevel: body.studentLevel,
      promptTemplateId: body.promptTemplateId,
      policyMode: body.policyMode,
      safetyConstraints: body.safetyConstraints,
      responseFormat: body.responseFormat,
      contextBlocks: body.contextBlocks.map((block) => ({
        type: block.type,
        content: block.content,
        id: block.id,
        relevance: block.relevance,
      })),
      missionAttemptId: body.missionAttemptId,
      rubricId: body.rubricId,
      maxTokens: body.safetyConstraints.maxTokens,
    },
    context: {
      traceId,
      siteId,
      role: body.role,
      gradeBand: gradeBandFromAgeBand(body.gradeBand),
      locale: targetLocale,
      policyVersion: body.policyVersion,
      callerService: 'scholesa-web-ai',
    },
  });

  if (isInternalInferenceRequired() && !inference.ok) {
    if (requiresStrictConfidence(body)) {
      return NextResponse.json(buildEscalatedGuardResponse({
        request: body,
        traceId,
        modelVersion: 'confidence-guard-v1',
        safetyReasonCode: 'child_inference_unavailable',
        answer: localizedServiceUnavailable(targetLocale),
      }), { status: 200 });
    }
    return NextResponse.json({ error: 'inference_unavailable', code: inference.errorCode }, { status: 503 });
  }

  if (!inference.ok) {
    if (requiresStrictConfidence(body)) {
      return NextResponse.json(buildEscalatedGuardResponse({
        request: body,
        traceId,
        modelVersion: 'confidence-guard-v1',
        safetyReasonCode: 'child_inference_unavailable',
        answer: localizedServiceUnavailable(targetLocale),
      }), { status: 200 });
    }
    return NextResponse.json({ error: 'inference_unavailable', code: inference.errorCode }, { status: 503 });
  }

  const llmPayload = extractLlmPayload(inference.data);
  if (!llmPayload?.text) {
    if (requiresStrictConfidence(body)) {
      return NextResponse.json(buildEscalatedGuardResponse({
        request: body,
        traceId,
        modelVersion: llmPayload?.modelVersion || 'confidence-guard-v1',
        safetyReasonCode: 'child_empty_inference_response',
        answer: localizedServiceUnavailable(targetLocale),
      }), { status: 200 });
    }
    return NextResponse.json({ error: 'empty_inference_response' }, { status: 503 });
  }

  const certifiedConfidence = parseConfidence(llmPayload.understanding?.confidence);
  if (requiresStrictConfidence(body) && (certifiedConfidence == null || certifiedConfidence < MIN_AUTONOMOUS_LEARNER_CONFIDENCE)) {
    return NextResponse.json(buildEscalatedGuardResponse({
      request: body,
      traceId,
      modelVersion: llmPayload.modelVersion || 'confidence-guard-v1',
      safetyReasonCode: certifiedConfidence == null ? 'child_confidence_unavailable' : 'child_low_confidence_guard',
      confidence: certifiedConfidence,
      answer: localizedLowConfidenceSupport(targetLocale),
    }), { status: 200 });
  }

  const response: ModelResponse = {
    answer: llmPayload.text,
    followUpQuestions: body.responseFormat.includeFollowUp ? llmPayload.toolSuggestions : undefined,
    citations: body.responseFormat.includeCitations
      ? body.contextBlocks.filter((block) => Boolean(block.id)).slice(0, 3).map((block) => ({
          contextBlockId: block.id as string,
          snippet: block.content.slice(0, 120),
        }))
      : undefined,
    modelUsed: 'scholesa_server_inference',
    modelVersion: llmPayload.modelVersion || 'internal-llm',
    promptTemplateId: body.promptTemplateId,
    policyVersion: body.policyVersion,
    safetyOutcome: 'allowed',
    safetyReasonCode: 'none',
    toolCallIds: llmPayload.toolSuggestions || [],
    targetLocale,
    gradeBand: body.gradeBand,
    traceId,
    missionAttemptId: body.missionAttemptId,
    confidence: certifiedConfidence,
    tokensUsed: Math.max(1, Math.ceil(llmPayload.text.split(/\s+/).filter(Boolean).length * 1.3)),
    latencyMs: 0,
  };

  return NextResponse.json(response, { status: 200 });
}
