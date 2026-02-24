# Dataflow Diagram (Text)

Document the core flows:

1) Authenticated request
Firebase Auth token -> API middleware verifies -> resolves siteId/role -> handles request.

2) Learning attempt
Student starts mission -> creates missionAttemptId -> checkpoints -> reflection -> artifact storage -> teacher review.

3) AI interaction
Student prompt -> AI policy + guardrails -> tool calls (scoped) -> response + metadata logged.

4) LMS integration
Coursework push -> store courseworkId -> submissions -> submissionId -> grade push.

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `Scholesa_Enterprise_Audit_MD_Pack/01-architecture/DATAFLOW_DIAGRAM_TEXT.md`
<!-- TELEMETRY_WIRING:END -->
