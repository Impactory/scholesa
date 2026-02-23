# RUNBOOK_TENANT_ISOLATION

Purpose: Restore strict site-bound tenant isolation.

1. Validate API middleware derives `siteId` from verified auth claims.
2. Ensure Firestore rules enforce `request.auth` + site-scoped access.
3. Re-run rules integration tests (`npm run test:integration:rules`).
4. Re-run voice tenant isolation suite (`npm run vibe:voice:tenant-isolation`).
5. Re-run compliance operator and confirm `tenant-isolation-invariants.json` passes.
