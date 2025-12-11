import { initializeApp, getApps, App } from 'firebase-admin/app';
import { credential } from 'firebase-admin';

const serviceAccount = process.env.FIREBASE_SERVICE_ACCOUNT_KEY
  ? JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_KEY)
  : undefined;

let app: App;

export function initializeServerApp() {
  if (getApps().length > 0) {
    app = getApps()[0];
    return { app };
  }

  if (!serviceAccount) {
    throw new Error('FIREBASE_SERVICE_ACCOUNT_KEY environment variable not set.');
  }

  app = initializeApp({
    credential: credential.cert(serviceAccount),
  });

  return { app };
}
