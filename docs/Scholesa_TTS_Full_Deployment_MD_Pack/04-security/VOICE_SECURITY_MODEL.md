# Voice Security Model

## Threats
- Cross-tenant leakage via voice requests
- Voice prompt injection via spoken instructions
- Accidental disclosure via read-aloud of PII
- Audio retention creating sensitive archives
- Replay attacks (reusing signed URLs)

## Controls
- Tenant isolation enforcement in all services
- Input safety filter on transcripts
- Output redaction before TTS (PII masking)
- Signed URLs short TTL + single-use tokens (optional)
- Rate limiting per user/session
- No raw audio stored long-term

## Evidence required
- VIBE tenant isolation tests
- Egress proof: no external calls
- Logs demonstrate redaction flags

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `Scholesa_TTS_Full_Deployment_MD_Pack/04-security/VOICE_SECURITY_MODEL.md`
<!-- TELEMETRY_WIRING:END -->
