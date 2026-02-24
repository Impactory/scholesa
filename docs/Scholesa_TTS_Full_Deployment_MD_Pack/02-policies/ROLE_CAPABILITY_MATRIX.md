# Role Capability Matrix — Voice Copilot

## Student
Allowed:
- Voice input (STT) for questions, reasoning, reflections
- Voice output (TTS) for hints, instructions, read-aloud
- Translation (if enabled)
Forbidden:
- Access other learners
- Teacher notes
- Admin configs
- Raw logs

## Teacher
Allowed:
- Voice summaries of class progress (aggregated)
- Draft feedback (teacher reviews before sending)
- Draft parent messages (teacher controls)
Forbidden:
- Cross-tenant access
- Secrets/raw system logs

## Admin
Allowed:
- Voice-guided setup help
- Non-sensitive troubleshooting guidance
Forbidden:
- Secrets, keys, credentials
- Raw student content exports via voice

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `Scholesa_TTS_Full_Deployment_MD_Pack/02-policies/ROLE_CAPABILITY_MATRIX.md`
<!-- TELEMETRY_WIRING:END -->
