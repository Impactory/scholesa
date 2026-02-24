# Cloud Run Baseline Standards

For every service:
- Dedicated service account (no default compute SA)
- Ingress: internal+LB OR justified public
- Authentication: verified tokens at edge
- Concurrency: explicitly set
- Min instances: set for prod low-latency (if budget allows)
- CPU allocation: explicit
- Timeouts: explicit
- Egress: controlled if required
- Revision pinning: container digest pinned in release evidence

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `Scholesa_Enterprise_Audit_MD_Pack/02-infrastructure/CLOUD_RUN_BASELINE.md`
<!-- TELEMETRY_WIRING:END -->
