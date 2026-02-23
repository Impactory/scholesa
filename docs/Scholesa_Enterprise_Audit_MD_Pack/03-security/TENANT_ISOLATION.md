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
