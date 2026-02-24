# Prompt Versioning

Each template has:
- promptTemplateId
- version
- owner
- lastModified
- allowed gradeBand(s)
- allowed tool set

Change management:
- PR required
- evaluation suite must pass
- rollback strategy

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `Scholesa_Enterprise_Audit_MD_Pack/05-ai/PROMPT_VERSIONING.md`
<!-- TELEMETRY_WIRING:END -->
