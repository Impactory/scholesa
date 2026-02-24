# VIBE Test Master — Voice System (STT + TTS)

## Required suites (release blockers)
1) voice:tenant-isolation
2) voice:role-policy
3) voice:egress-none
4) stt:locale-accuracy-smoke
5) tts:pronunciation-regression
6) tts:prosody-policy (K–5 safe mode)
7) voice:utf8-integrity
8) voice:quiet-mode
9) voice:abuse-and-safety-refusals

## Evidence artifacts
/audit-pack/reports/voice-tenant-isolation.json
/audit-pack/reports/voice-egress.json
/audit-pack/reports/stt-smoke.json
/audit-pack/reports/tts-pronunciation.json
/audit-pack/reports/tts-prosody-policy.json
/audit-pack/reports/voice-utf8.json

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `Scholesa_TTS_Full_Deployment_MD_Pack/06-vibe/VIBE_TEST_MASTER_VOICE.md`
<!-- TELEMETRY_WIRING:END -->
