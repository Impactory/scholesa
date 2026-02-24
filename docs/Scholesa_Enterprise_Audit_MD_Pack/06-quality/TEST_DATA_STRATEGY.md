# Test Data Strategy

- Use synthetic learner IDs
- Use seeded sites A/B for tenant tests
- Redact any real student information
- Keep deterministic fixtures for regression

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `Scholesa_Enterprise_Audit_MD_Pack/06-quality/TEST_DATA_STRATEGY.md`
<!-- TELEMETRY_WIRING:END -->
