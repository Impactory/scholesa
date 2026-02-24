# API Contracts (scholesa-api / scholesa-stt / scholesa-tts)

## 1) scholesa-api
### POST /copilot/message
Client body:
- message: string (from STT or typed)
- screenId: string
- context: object (optional ids already visible)
- locale: en|zh-CN|zh-TW|th
- voice: { enabled: boolean, output: boolean }

Server derives (from Firebase token):
- siteId, role, gradeBand, uid

Returns:
- text
- metadata: { traceId, safetyOutcome, policyVersion, modelVersion, locale }
- tts: { available: boolean, audioUrl?: string, voiceProfile?: string }

## 2) scholesa-stt
### POST /voice/transcribe
Headers: Authorization: Bearer <Firebase ID token>
Body (multipart):
- audio: wav/webm
- locale
- partial: boolean (optional)

Returns:
- transcript
- confidence
- metadata: { traceId, locale, latencyMs }

## 3) scholesa-tts
### POST /tts/speak
Headers: Authorization: internal service-to-service OR Firebase token (teacher/admin tools)
Body:
- text (already approved)
- locale
- voiceProfile (server-chosen)
- gradeBand
Returns:
- audioUrl (short TTL signed URL)
- metadata: { traceId, modelVersion, latencyMs }

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `Scholesa_TTS_Full_Deployment_MD_Pack/03-api/API_CONTRACTS.md`
<!-- TELEMETRY_WIRING:END -->
