# Internal AI Service Contracts (Canonical)

All AI services must be vendor-agnostic and use canonical schemas.

## Common headers
- `X-Trace-Id`
- `X-Site-Id` (from claims, injected by scholesa-api)
- `X-Role`
- `X-Grade-Band`
- `X-Locale`
- `X-Policy-Version`

## scholesa-ai: POST /v1/chat
Request: ChatRequest (canonical)
Response: ChatResponse (canonical)

## scholesa-stt: POST /v1/transcribe
Request:
- audio (multipart or URL reference in GCS)
- locale
Response:
- transcript
- confidence
- timings? (optional)

## scholesa-tts: POST /v1/speak
Request:
- text
- locale
- gradeBand
- voiceProfile (pre-approved)
Response:
- audioUrl (signed)
- expiresAt

## scholesa-embed: POST /v1/embed
Request:
- texts[]
- locale
Response:
- vectors[]

## scholesa-guard: POST /v1/check
Request:
- direction: input|output
- content: (text only)
- context metadata
Response:
- safetyOutcome
- reasonCode
- redactionsApplied?

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `infrastructure/blueprints/hybrid-cloudrun-gke-gpu/03-ai/01-internal-ai-service-contracts.md`
<!-- TELEMETRY_WIRING:END -->
