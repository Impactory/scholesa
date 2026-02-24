# 12_CLOUD_RUN_FIREBASE_DEPLOYMENT.md

## Environments
Recommended: dev / staging / prod with separate Firebase projects.

## API (Cloud Run)
Required:
- GET /health
- Firebase token verification for protected routes
- Stripe webhook endpoint (billing)
- structured logs
- requestId propagation

Secrets:
- store in Secret Manager (not repo)

## Flutter web hosting
Standardized target:
- Cloud Run static hosting

PWA:
- Prefer Flutter’s built-in service worker approach.
- Avoid custom SW hacks unless you own and test the full caching lifecycle.

## Release checklist
- builds pass (docs/09)
- deploy rules/indexes
- deploy API
- deploy web app
- smoke test: login + provisioning + attendance

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `12_CLOUD_RUN_FIREBASE_DEPLOYMENT.md`
<!-- TELEMETRY_WIRING:END -->
