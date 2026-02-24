# Golden Flows (Must Pass)

## A) Student Mission Attempt
Enroll -> assign -> start attempt -> checkpoint(s) -> reflection -> artifact -> teacher view.

## B) Teacher Orchestration
Create course/session -> assign missions -> monitor -> intervene -> feedback.

## C) Tenant Isolation
Attempt to access other site -> denied.

## D) AI Guardrails
Injection -> blocked; normal tutoring -> allowed with metadata.

## E) LMS Integration (if enabled)
Create coursework -> link courseworkId/submissionId -> grade push.

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `Scholesa_Enterprise_Audit_MD_Pack/06-quality/GOLDEN_FLOWS.md`
<!-- TELEMETRY_WIRING:END -->
