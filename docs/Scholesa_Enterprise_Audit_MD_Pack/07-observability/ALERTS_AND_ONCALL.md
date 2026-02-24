# Alerts & On-call

Required alerts:
- auth anomaly spikes
- cross-tenant access attempt spikes
- scholesa-api error rate > threshold
- scholesa-ai guardrail failures > threshold
- grade push failures > threshold

On-call:
- rotation (even small team)
- escalation steps
- comms channels

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `Scholesa_Enterprise_Audit_MD_Pack/07-observability/ALERTS_AND_ONCALL.md`
<!-- TELEMETRY_WIRING:END -->
