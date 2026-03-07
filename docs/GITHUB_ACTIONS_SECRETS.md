# GitHub Actions Secrets Inventory (Scholesa)

This document is the source of truth for repository secrets used by workflows under `.github/workflows/`.

## Scope

- Primary automated pipeline: `.github/workflows/ci.yml`
- Manual fallback deploy pipeline: `.github/workflows/deploy-cloud-run.yml`
- Nightly compliance checks (`.github/workflows/compliance-nightly.yml`) do not require cloud deploy secrets.

## Required Secrets

These must exist in **GitHub Repository Secrets** for production deploy flows to succeed.

### Core GCP / Deploy

- `GCP_SA_KEY` — JSON key for GCP service account used by `google-github-actions/auth@v2`.
- `GCP_PROJECT_ID` — GCP project ID for image/build/deploy operations.
- `GCP_REGION` — Cloud Run region (for example `us-central1`).
- `CLOUD_RUN_SERVICE` — primary web Cloud Run service name.
- `CLOUD_RUN_COMPLIANCE_SERVICE` — compliance Cloud Run service name.

### Firebase / Runtime

- `FIREBASE_SERVICE_ACCOUNT_SECRET` — Secret Manager secret name (mounted into Cloud Run as `FIREBASE_SERVICE_ACCOUNT`).
- `FIREBASE_TOKEN` — Firebase CLI token for CI usage where Firebase CLI auth is required.

### Public Runtime Config (injected during deploy)

- `NEXT_PUBLIC_FIREBASE_API_KEY`
- `NEXT_PUBLIC_FIREBASE_PROJECT_ID`
- `NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN`
- `NEXT_PUBLIC_FIREBASE_APP_ID`
- `NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET`
- `NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID`
- `NEXT_PUBLIC_ENABLE_SW`

## Workflow Mapping

### `.github/workflows/ci.yml`

- `platform-full` job requires:
  - `GCP_SA_KEY`
  - `FIREBASE_TOKEN`
  - Any deploy/runtime secrets consumed by scripts invoked through `npm run flow:platform:full`
- Includes a fail-fast validation step before cloud auth/deploy work starts.

### `.github/workflows/deploy-cloud-run.yml` (manual fallback)

- Requires all **Core GCP / Deploy** and **Public Runtime Config** secrets above.
- Uses `FIREBASE_SERVICE_ACCOUNT_SECRET` for Cloud Run secret injection.
- Includes a fail-fast validation step that checks every required deploy/config secret.

## Setup Checklist

1. Open GitHub repository settings → **Secrets and variables** → **Actions**.
2. Add all keys listed in this document exactly (case-sensitive).
3. Re-run `CI` workflow (`workflow_dispatch`) and verify `platform-full` succeeds.
4. Keep this file updated whenever workflow secret keys change.
