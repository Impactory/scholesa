# Release Gate — Voice System

Block release if:
- voice:egress-none fails
- voice:tenant-isolation fails
- tts:prosody-policy fails (K–5)
- stt locale smoke fails for enabled locales
- utf8 integrity fails

Required artifacts per release:
- audit-pack voice reports JSON
- dashboard screenshots/links
- confirmation of GCS lifecycle TTL

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `Scholesa_TTS_Full_Deployment_MD_Pack/12-release/RELEASE_GATE_VOICE.md`
<!-- TELEMETRY_WIRING:END -->
