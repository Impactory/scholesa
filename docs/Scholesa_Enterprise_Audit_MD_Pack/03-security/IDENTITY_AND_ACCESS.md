# Identity & Access Management

## Firebase Auth
- Providers used:
- Account lifecycle (join/leave):
- Custom claims schema: siteId, role, gradeBand, mfa

## Admin controls
- MFA enforced for admin roles
- Break-glass process documented

## IAM (GCP)
- Service accounts per service
- Role bindings minimal
- Quarterly access review procedure

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `Scholesa_Enterprise_Audit_MD_Pack/03-security/IDENTITY_AND_ACCESS.md`
<!-- TELEMETRY_WIRING:END -->
