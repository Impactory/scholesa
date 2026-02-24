# Scholesa Voice-First Copilot (BOS) — Full Deployment MD Pack
Generated: 2026-02-23T04:22:38Z
Scope: Internal-only STT + Internal-only TTS (no external vendors), Voice-first student UX, multi-role support, Firebase + Cloud Run.

## What this pack contains
- BOS system spec (voice input + voice output)
- COPPA-safe rules and enforcement
- API contracts (scholesa-api, scholesa-ai, scholesa-tts, scholesa-stt)
- Security + privacy + logging boundaries
- Deployment guides (Cloud Run + Firebase Hosting)
- VIBE regression gates + artifact outputs
- Runbooks (incident/DR/ops) and monitoring requirements
- Multilingual enablement (en, zh-CN, zh-TW, th)

## Non-negotiable constraints
- No data egress to external model providers
- No voice cloning of children
- Voice-first defaults for students (typed optional by policy, but nudged to voice)
- Tenant isolation absolute (siteId from claims)

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `Scholesa_TTS_Full_Deployment_MD_Pack/README.md`
<!-- TELEMETRY_WIRING:END -->
