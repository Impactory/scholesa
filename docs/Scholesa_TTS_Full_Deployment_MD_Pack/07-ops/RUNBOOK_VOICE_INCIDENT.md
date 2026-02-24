# Runbook — Voice System Incidents

## Common incidents
- STT latency spike
- TTS latency spike
- Audio URL playback failures
- Wrong locale voice
- Redaction failure suspected

## Immediate steps
1) Check dashboards (latency, errors)
2) Disable student voice temporarily via tenant flag if needed
3) Preserve logs by traceId (do not export raw content)
4) Confirm GCS lifecycle settings intact
5) Post-incident: add regression test for the failure

## Communication
- Notify impacted school/district through established channels

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `Scholesa_TTS_Full_Deployment_MD_Pack/07-ops/RUNBOOK_VOICE_INCIDENT.md`
<!-- TELEMETRY_WIRING:END -->
