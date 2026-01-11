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
Choose ONE and standardize:
- Firebase Hosting (recommended)
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
