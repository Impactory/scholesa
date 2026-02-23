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
