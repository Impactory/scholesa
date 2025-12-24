# Scholesa Platform

This is the repository for the Scholesa Platform, an Education 2.0 operating system for K-9 learning studios and schools.

## Getting Started

### Prerequisites

- Node.js (v18 or later)
- npm, yarn, or pnpm
- Firebase CLI

### Installation

1.  Install root dependencies:

    ```bash
    npm install
    ```

2.  Install Firebase Functions dependencies:

    ```bash
    cd functions && npm install && cd ..
    ```

### Running the Development Server

```bash
npm run dev
```

### Running the Firebase Emulators

```bash
firebase emulators:start
```

### Building for Production

```bash
npm run build
```

### Deployment

To deploy the application to Firebase:

```bash
firebase deploy
```

To deploy only the Firebase Functions:

```bash
cd functions
npm run build
firebase deploy --only functions
```

## Production & PWA notes

This project expects runtime configuration via environment variables. Do NOT commit secrets into the repository. Use your hosting provider's secret store (Vercel, Netlify, Firebase, GCP Secret Manager, etc.).

- Create a `.env` locally for testing (use `.env.example` as a template).
- Required client vars (public): `NEXT_PUBLIC_FIREBASE_API_KEY`, `NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN`, `NEXT_PUBLIC_FIREBASE_PROJECT_ID`, `NEXT_PUBLIC_FIREBASE_APP_ID`, `NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET`, `NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID`.
- Server-side (admin) options:
    - Preferred: set `FIREBASE_SERVICE_ACCOUNT` to the service account JSON (raw) or base64-encoded JSON. The app will parse and use it.
    - Alternative: set `GOOGLE_APPLICATION_CREDENTIALS` in the environment (path to service account) and let Application Default Credentials be used.
    - Fallback: set `FIREBASE_ADMIN_CLIENT_EMAIL`, `FIREBASE_ADMIN_PRIVATE_KEY`, and `NEXT_PUBLIC_FIREBASE_PROJECT_ID` (private key must preserve newlines; on Vercel replace newlines with `\n`).

- Service worker and PWA:
    - By default the service worker registers only in production. To enable during dev, set `NEXT_PUBLIC_ENABLE_SW=true` and specify `NEXT_PUBLIC_SW_PATH` if your SW is at a custom location.
    - Ensure `public/sw.js` exists and is the SW you want deployed. The project ships with a minimal SW — replace or enhance it as needed.

Deployment tips:

- Vercel: Add the env vars in the Project Settings → Environment Variables. For `FIREBASE_SERVICE_ACCOUNT`, paste the JSON or base64 string as a secret (mark it as protected if needed). Vercel will expose `process.env` at build/runtime depending on variable naming (`NEXT_PUBLIC_` are exposed to client builds).
- Firebase Hosting / Functions: Use `firebase functions:config:set` or set env vars in your CI. For server-side service accounts prefer using `GOOGLE_APPLICATION_CREDENTIALS` on CI with the service account file stored in secrets.

### Google Cloud (Cloud Run) + Firebase

This repository includes a GitHub Actions workflow to build and deploy to Cloud Run: `.github/workflows/deploy-cloud-run.yml`.

Overview steps (automatable via the workflow):

1. Create or download the Firebase service account JSON (from Firebase Console → Project Settings → Service accounts → Generate new private key). This JSON will be used by server-side code (Admin SDK).
2. Create a GCP service account for deployment and grant it permissions to deploy to Cloud Run and push images to Container Registry / Artifact Registry. Recommended roles: `roles/run.admin`, `roles/iam.serviceAccountUser`, `roles/storage.admin` (or `roles/storage.objectAdmin`), and `roles/cloudbuild.builds.editor`.
3. Add repository secrets in GitHub (Repository Settings → Secrets and variables → Actions):
    - `GCP_SA_KEY`: the JSON key for the GCP deploy service account (use the full JSON content).
    - `GCP_PROJECT_ID`: your GCP project id.
    - `GCP_REGION`: e.g., `us-central1`.
    - `CLOUD_RUN_SERVICE`: desired Cloud Run service name (e.g., `scholesa-web`).
    - Client/public Firebase vars: `NEXT_PUBLIC_FIREBASE_API_KEY`, `NEXT_PUBLIC_FIREBASE_PROJECT_ID`, `NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN`, `NEXT_PUBLIC_FIREBASE_APP_ID`, `NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET`, `NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID`.
    - `NEXT_PUBLIC_ENABLE_SW` (true/false).
    - `FIREBASE_SERVICE_ACCOUNT_SECRET` (optional): the name of a Secret Manager secret containing the Firebase service account JSON. If you store the service account JSON in Secret Manager, set this to the secret name; the workflow will reference it when deploying. Alternatively, add `FIREBASE_SERVICE_ACCOUNT` as a GitHub secret containing base64(service-account.json) and create a Secret Manager secret manually.

Quick `gcloud` commands (local):

```bash
# Authenticate locally
gcloud auth login
gcloud config set project YOUR_PROJECT_ID

# Create deploy service account (adjust name as needed):
gcloud iam service-accounts create gh-deployer --display-name "GitHub Deployer"

# Grant roles to deploy account (run as project owner or admin):
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID --member="serviceAccount:gh-deployer@${GCP_PROJECT_ID}.iam.gserviceaccount.com" --role="roles/run.admin"
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID --member="serviceAccount:gh-deployer@${GCP_PROJECT_ID}.iam.gserviceaccount.com" --role="roles/iam.serviceAccountUser"
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID --member="serviceAccount:gh-deployer@${GCP_PROJECT_ID}.iam.gserviceaccount.com" --role="roles/storage.admin"
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID --member="serviceAccount:gh-deployer@${GCP_PROJECT_ID}.iam.gserviceaccount.com" --role="roles/cloudbuild.builds.editor"

# Create and download key (keep this secret):
gcloud iam service-accounts keys create gh-deployer-key.json --iam-account=gh-deployer@${GCP_PROJECT_ID}.iam.gserviceaccount.com

# (Optional) Create a Secret Manager secret for the Firebase service account JSON:
gcloud secrets create firebase-service-account --replication-policy="automatic"
gcloud secrets versions add firebase-service-account --data-file="path/to/firebase-service-account.json"

# Deploy manually (example):
docker build -t gcr.io/$GCP_PROJECT_ID/scholesa:latest .
docker push gcr.io/$GCP_PROJECT_ID/scholesa:latest
gcloud run deploy $CLOUD_RUN_SERVICE --image gcr.io/$GCP_PROJECT_ID/scholesa:latest --region $GCP_REGION --platform managed --allow-unauthenticated --set-env-vars "NEXT_PUBLIC_FIREBASE_API_KEY=$NEXT_PUBLIC_FIREBASE_API_KEY,NEXT_PUBLIC_FIREBASE_PROJECT_ID=$NEXT_PUBLIC_FIREBASE_PROJECT_ID" --update-secrets "FIREBASE_SERVICE_ACCOUNT=firebase-service-account:latest"
```

Notes:
- The workflow I added expects the deploy SA key in `GCP_SA_KEY`, and optionally uses a Secret Manager secret name in `FIREBASE_SERVICE_ACCOUNT_SECRET`.
- For production, ensure your Firebase Admin service account has the appropriate Firebase permissions (create the key via Firebase Console for the Admin SDK if unsure).


If you want help wiring a specific provider (Vercel, Netlify, Firebase), tell me which one and I will provide exact steps and a sample CI snippet.
