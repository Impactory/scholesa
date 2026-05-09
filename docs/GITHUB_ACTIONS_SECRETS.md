# GitHub Actions Secrets Inventory (Scholesa)

This document is the source of truth for repository secrets used by workflows under `.github/workflows/`.

## Scope

- Primary automated pipeline: `.github/workflows/ci.yml`
- Manual fallback deploy pipeline: `.github/workflows/deploy-cloud-run.yml`
- Native release pipelines: `.github/workflows/apple-release.yml`, `.github/workflows/android-release.yml`, `.github/workflows/macos-release.yml`, and `.github/workflows/native-distribution-proof.yml`
- Nightly compliance checks (`.github/workflows/compliance-nightly.yml`) do not require cloud deploy secrets.

## Required Secrets

These must exist in **GitHub Repository Secrets** for production deploy flows to succeed.

### Core GCP / Deploy

- `GCP_SA_KEY` — JSON key for GCP service account used by `google-github-actions/auth@v2`.
- `GCP_PROJECT_ID` — GCP project ID for image/build/deploy operations.
- `GCP_REGION` — Cloud Run region (for example `us-central1`).
- `CLOUD_RUN_SERVICE` — primary web Cloud Run service name.
- `CLOUD_RUN_FLUTTER_SERVICE` — Flutter web Cloud Run service name.
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

### Apple Native Release / Proof

These secrets are required before iOS TestFlight, macOS notarization, or aggregate native distribution proof can be claimed.

- `APP_STORE_CONNECT_API_KEY_P8_BASE64` — Base64-encoded App Store Connect API private key.
- `APP_STORE_CONNECT_KEY_ID` — App Store Connect API key ID.
- `APP_STORE_CONNECT_ISSUER_ID` — App Store Connect issuer UUID.
- `APPLE_DEVELOPER_TEAM_ID` — Apple Developer Team ID, currently expected to match team `CEUD8LB243`.
- `IOS_SIGNING_CERT_P12_BASE64` — Base64-encoded Apple Distribution certificate with private key for TestFlight uploads.
- `IOS_SIGNING_CERT_PASSWORD` — Password for the iOS Distribution `.p12`.
- `IOS_PROVISIONING_PROFILE_BASE64` — Base64-encoded App Store provisioning profile for `com.scholesa.app`.
- `MACOS_DEVELOPER_ID_CERT_P12_BASE64` — Base64-encoded Developer ID Application certificate with private key for macOS distribution.
- `MACOS_DEVELOPER_ID_CERT_PASSWORD` — Password for the Developer ID Application `.p12`.

### Android Native Release / Proof

These secrets are required before Google Play internal-track upload or aggregate native distribution proof can be claimed.

- `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_BASE64` — Base64-encoded Google Play service account JSON.
- `ANDROID_KEYSTORE_BASE64` — Base64-encoded Android release keystore.
- `ANDROID_KEYSTORE_PASSWORD` — Store password for the Android release keystore.
- `ANDROID_KEY_ALIAS` — Release signing key alias.
- `ANDROID_KEY_PASSWORD` — Password for the release signing key.

## Workflow Mapping

### `.github/workflows/ci.yml`

- `platform-full` job requires:
  - `GCP_SA_KEY`
  - `FIREBASE_TOKEN`
  - Any deploy/runtime secrets consumed by scripts invoked through `npm run flow:platform:full`
- Includes a fail-fast validation step before cloud auth/deploy work starts.

### `.github/workflows/deploy-cloud-run.yml` (manual fallback)

- Requires all **Core GCP / Deploy** and **Public Runtime Config** secrets above.
- Deploys the primary Node web service, the separate Flutter web service, and the compliance operator.
- Uses `FIREBASE_SERVICE_ACCOUNT_SECRET` for Cloud Run secret injection.
- Includes a fail-fast validation step that checks every required deploy/config secret.

### Native release workflows

- `.github/workflows/apple-release.yml` verifies App Store Connect auth and can upload to TestFlight when `upload_to_testflight` is enabled.
- `.github/workflows/android-release.yml` verifies Google Play auth and can upload to the internal testing track when `upload_to_internal` is enabled.
- `.github/workflows/macos-release.yml` verifies App Store Connect notarization auth and can sign/notarize/staple the macOS app when `notarize_macos` is enabled.
- `.github/workflows/native-distribution-proof.yml` is the aggregate native proof workflow. It requires `native_distribution_confirmation=I_UNDERSTAND_THIS_UPLOADS_NATIVE_BUILDS` and uploads per-channel proof artifacts for iOS TestFlight, Android Play internal, and macOS notarization.

## Setup Checklist

1. Open GitHub repository settings → **Secrets and variables** → **Actions**.
2. Add all keys listed in this document exactly (case-sensitive).
3. For native proof, run the relevant secret helper before checking GitHub Actions diagnostics: `./scripts/set_apple_github_secrets.sh` for Apple secrets and `./scripts/set_android_github_secrets.sh` for Android secrets.
4. Re-run `CI` workflow (`workflow_dispatch`) and verify `platform-full` succeeds.
5. Run `.github/workflows/native-distribution-proof.yml` only after release owners are ready for live native uploads.
6. Keep this file updated whenever workflow secret keys change.
