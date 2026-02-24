# 10-Minute Walkthrough Script (Live)

1) Architecture Inventory
- Open ARCHITECTURE/COMPONENT_INVENTORY.md
- Show Cloud Run services list export + Firebase Hosting rewrites

2) Tenant Isolation
- Show SECURITY/TENANT_ISOLATION.md
- Run tenant isolation test → show JSON output

3) AI Governance
- Show AI/AI_SYSTEM_SPEC.md
- Run AI guardrail suite → show pass/fail cases and logs

4) Privacy Ops
- Show PRIVACY/RETENTION_DELETION.md + sample export/delete evidence

5) Release Gate
- Show OPS/RELEASE_GATE.md + last CI artifact bundle

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `Scholesa_Enterprise_Audit_MD_Pack/00-executive/WALKTHROUGH_SCRIPT_10MIN.md`
<!-- TELEMETRY_WIRING:END -->
