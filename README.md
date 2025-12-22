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

If you want help wiring a specific provider (Vercel, Netlify, Firebase), tell me which one and I will provide exact steps and a sample CI snippet.
