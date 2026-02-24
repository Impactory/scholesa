# Tools & Scopes

Every tool must define:
- name
- purpose
- required inputs schema
- allowed roles
- allowed gradeBands
- allowed data scope (siteId-bound)
- output redaction

Evidence:
- tool registry export
- tests for scope enforcement

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `Scholesa_Enterprise_Audit_MD_Pack/05-ai/TOOLS_AND_SCOPES.md`
<!-- TELEMETRY_WIRING:END -->
