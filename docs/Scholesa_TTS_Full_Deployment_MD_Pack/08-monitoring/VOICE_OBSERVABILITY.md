# Voice Observability (Dashboards + Alerts)

## Metrics
- STT latency p95, error rate
- TTS latency p95, error rate
- Audio playback errors (client-reported)
- RedactionApplied rate (should be >0 for K–5 flows)
- Locale distribution
- Quiet-mode activation rate

## Alerts
- STT error rate spike
- TTS error rate spike
- Playback failures > threshold
- Redaction policy anomaly (unexpected 0 in K–5)

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `Scholesa_TTS_Full_Deployment_MD_Pack/08-monitoring/VOICE_OBSERVABILITY.md`
<!-- TELEMETRY_WIRING:END -->
