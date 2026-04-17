---
name: Voice System Architecture State
description: Current MiloOS voice pipeline architecture, model versions, locale gaps, and internal-AI constraint details as of 2026-04-17
type: project
---

MiloOS voice pipeline is fully self-hosted behind egress guards (blocks generativelanguage.googleapis.com, ai.google.dev, vertexai.googleapis.com, aiplatform.googleapis.com). Internal hosts allowed: scholesa-ai, scholesa-tts, scholesa-stt, cloudfunctions.net, a.run.app, localhost.

**Why:** Legal and pedagogical requirement — no external AI providers. Enforced at both functions (functions/src/security/egressGuard.ts) and web client (src/lib/ai/egressGuard.ts).

**How to apply:** Any model upgrade must be deployable to Cloud Run or equivalent internal infra. Model artifacts served from internal endpoints only.

Current state (2026-04-17):
- STT: `scholesa-stt-internal-v1`, 4 locales (en, zh-CN, zh-TW, th — missing es)
- TTS: `scholesa-tts-internal-v1`, 4 locales + browser Web Speech API fallback + procedural sine-wave fallback (disabled in prod, returns JSON "ttsAvailable: false")
- LLM: `scholesa-ai` internal, policy-gated
- BOS: Internal BOS policy inference
- Voice profiles: 3 per locale (k5_safe_neutral, student_neutral, professional_concise)
- SUPPORTED_VOICE_LOCALES: ['en', 'zh-CN', 'zh-TW', 'th'] — 'es' is missing
- LOCALE_ALIASES includes en, zh, th variants but no es
- Intent types: 7 (hint_request, explain_request, translation_request, planning_request, reflection, safety_support, general_support)
- Emotional state: 3 (frustrated, neutral, confident) — heuristic regex only
- No streaming (full WAV generation then token-gated URL delivery)
- Flutter client uses speech_to_text ^7.3.0 and flutter_tts ^4.2.5 for on-device
- Web client uses browser Web Speech API as TTS fallback (browserSpeech.ts)
- The backend inference gateway (internalInferenceGateway.ts) routes to 4 services: llm, stt, tts, bos via env vars

Key files:
- functions/src/voiceSystem.ts (3,922 lines) — full backend pipeline
- functions/src/internalInferenceGateway.ts — internal inference routing
- src/lib/voice/voiceService.ts — web client
- src/lib/voice/browserSpeech.ts — browser TTS fallback
- apps/empire_flutter/app/lib/runtime/voice_runtime_service.dart — Flutter client
- apps/empire_flutter/app/lib/runtime/ai_coach_widget.dart — Flutter AI coach UI
- src/components/sdt/AICoachPopup.tsx — Web AI coach UI
- locales/{en,es,th,zh-CN,zh-TW}.json — i18n (only 1 voice key: aiCoach.voiceRequirements)
