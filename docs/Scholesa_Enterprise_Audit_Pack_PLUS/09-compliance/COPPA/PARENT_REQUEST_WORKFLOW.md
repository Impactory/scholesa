# Parent Request Workflow (Access/Deletion)

## Principle
Scholesa supports parent rights via the school/district coordination model.

## Workflow
1) Parent contacts school/district.
2) School verifies identity and authority.
3) School submits request (export, correction, deletion) to Scholesa support channel.
4) Scholesa executes scoped export/delete (siteId + learnerId).
5) Scholesa provides completion evidence to school.
6) School confirms completion with parent.

## Evidence captured
- request ticket id (district)
- traceId/run id (Scholesa)
- export/delete report JSON

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `Scholesa_Enterprise_Audit_Pack_PLUS/09-compliance/COPPA/PARENT_REQUEST_WORKFLOW.md`
<!-- TELEMETRY_WIRING:END -->
