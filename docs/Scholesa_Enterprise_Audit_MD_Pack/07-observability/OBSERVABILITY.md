# Observability

## Metrics
- request latency p50/p95/p99
- error rate
- saturation/concurrency
- AI latency + tool error rates
- LMS sync failures

## Logs
- structured JSON
- traceId/requestId
- siteId tagging
- PII redaction

## Tracing
- service map (if using Cloud Trace/OpenTelemetry)

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `Scholesa_Enterprise_Audit_MD_Pack/07-observability/OBSERVABILITY.md`
<!-- TELEMETRY_WIRING:END -->
