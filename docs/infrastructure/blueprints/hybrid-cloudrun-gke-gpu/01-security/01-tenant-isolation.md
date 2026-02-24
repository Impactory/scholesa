# Tenant Isolation (Absolute)

## Invariant
`siteId` is derived ONLY from verified auth claims (Firebase token).
It must never be accepted from client input or query params.

## Enforcement layers
1) Cloud Run gateway (`scholesa-api`) middleware:
- resolves claims → attaches `{siteId, role, gradeBand, locale}` to request context
- rejects if siteId missing or invalid

2) Firestore security rules:
- tenant data stored under `/sites/{siteId}/...`
- access allowed only if `request.auth.token.siteId == siteId`

3) Server-side queries:
- every query must include `siteId` filter from context
- no “global” queries in tenant collections

4) Tests (release blocker)
- integration tests attempt cross-tenant read/write and must fail
- results stored in `audit-pack/reports/tenant-isolation.json`

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `infrastructure/blueprints/hybrid-cloudrun-gke-gpu/01-security/01-tenant-isolation.md`
<!-- TELEMETRY_WIRING:END -->
