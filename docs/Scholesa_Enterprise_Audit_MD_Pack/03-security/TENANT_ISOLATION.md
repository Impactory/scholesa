# Tenant Isolation (Critical Control)

## Non-negotiable rule
siteId is derived from verified auth token claims and enforced everywhere.

## Enforced at:
- API middleware (reject mismatches)
- Firestore security rules (path + claim equality)
- Storage access (bucket prefixes or metadata)
- Logs and analytics events (always tagged)

## Tests
- Cross-tenant read/write attempts must fail
- Admin role does NOT bypass tenant boundary without explicit multi-tenant super-admin policy

Evidence:
- reports/tenant-isolation-test.json

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `Scholesa_Enterprise_Audit_MD_Pack/03-security/TENANT_ISOLATION.md`
<!-- TELEMETRY_WIRING:END -->
