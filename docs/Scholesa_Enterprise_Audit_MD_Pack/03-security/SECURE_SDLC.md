# Secure SDLC

Required pipeline steps:
- Dependency scanning (SCA)
- Secrets scanning
- Static analysis / lint
- Container image scanning
- SBOM generation
- Signed release artifacts (recommended)

Evidence:
- CI logs
- scan reports
- SBOM file + hash

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `Scholesa_Enterprise_Audit_MD_Pack/03-security/SECURE_SDLC.md`
<!-- TELEMETRY_WIRING:END -->
