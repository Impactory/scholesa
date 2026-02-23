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
