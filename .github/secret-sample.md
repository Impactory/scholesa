# GitHub Actions Secrets (sample)

Add these repository secrets (GitHub → Settings → Secrets and variables → Actions).

- `GCP_SA_KEY` — JSON contents of a GCP service account key with permissions to deploy (roles/run.admin, roles/iam.serviceAccountUser, roles/storage.admin, roles/cloudbuild.builds.editor).
- `GCP_PROJECT_ID` — your Google Cloud project id.
- `GCP_REGION` — e.g., `us-central1`.
- `CLOUD_RUN_SERVICE` — Cloud Run service name, e.g., `scholesa-web`.
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

Notes:
- Keep service account keys secret. Prefer Secret Manager in production and grant minimal IAM roles.
