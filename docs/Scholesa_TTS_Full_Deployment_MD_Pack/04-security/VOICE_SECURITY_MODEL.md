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
