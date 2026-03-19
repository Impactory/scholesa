# GitHub Actions Secrets (sample)

Add these repository secrets (GitHub → Settings → Secrets and variables → Actions).

- `GCP_SA_KEY` — JSON contents of a GCP service account key with permissions to deploy (roles/run.admin, roles/iam.serviceAccountUser, roles/storage.admin, roles/cloudbuild.builds.editor).
- `GCP_PROJECT_ID` — your Google Cloud project id.
- `GCP_REGION` — e.g., `us-central1`.
- `CLOUD_RUN_SERVICE` — Cloud Run service name, e.g., `scholesa-web`.
- `CLOUD_RUN_FLUTTER_SERVICE` — Flutter web Cloud Run service name, e.g., `empire-web`.
- `NEXT_PUBLIC_FIREBASE_API_KEY` — Firebase public API key (client-side).
- `NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN`
- `NEXT_PUBLIC_FIREBASE_PROJECT_ID`
- `NEXT_PUBLIC_FIREBASE_APP_ID`
- `NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET`
- `NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID`
- `NEXT_PUBLIC_ENABLE_SW` — `true` or `false`.

Optional secrets for admin/service account:

- `FIREBASE_SERVICE_ACCOUNT` — base64-encoded Firebase service account JSON (used if you prefer storing the full JSON in GH secrets). Do NOT store plain JSON if your policies forbid it.
- `FIREBASE_SERVICE_ACCOUNT_SECRET` — (optional) Secret Manager secret name if you store the Firebase service account JSON in GCP Secret Manager. The workflow references this when deploying.

Optional secrets for Apple release automation:

- `APP_STORE_CONNECT_API_KEY_P8_BASE64` — base64-encoded contents of the App Store Connect `.p8` API key file.
- `APP_STORE_CONNECT_KEY_ID` — the 10-character App Store Connect key id, usually derived from the `AuthKey_<KEYID>.p8` filename.
- `APP_STORE_CONNECT_ISSUER_ID` — the App Store Connect issuer UUID from Users and Access → Keys.
- `APPLE_DEVELOPER_TEAM_ID` — Apple Developer team id used for the iOS target (`CEUD8LB243` in the current project).
- `IOS_SIGNING_CERT_P12_BASE64` — base64-encoded iOS distribution certificate in `.p12` format.
- `IOS_SIGNING_CERT_PASSWORD` — password for the `.p12` certificate.
- `IOS_PROVISIONING_PROFILE_BASE64` — base64-encoded App Store provisioning profile for `com.scholesa.app`.

Notes:
- Keep service account keys secret. Prefer Secret Manager in production and grant minimal IAM roles.
- Keep Apple `.p8` keys out of the repository. Store them in GitHub Actions secrets or a local ignored path such as `.secrets/app_store_connect/`.
- Use `.github/workflows/apple-release.yml` for App Store Connect key verification and optional TestFlight upload on a macOS runner.
