import admin from 'firebase-admin';
import { ensureEnv, optionalEnv } from '@/src/lib/ensureEnv';

if (!admin.apps.length) {
  try {
    // Prefer a single env var containing service account JSON (base64 or raw JSON)
    const svc = optionalEnv('FIREBASE_SERVICE_ACCOUNT');

    if (svc) {
      let serviceAccount: any;
      try {
        const maybeJson = svc.trim();
        // If looks like base64, decode
        if (/^[A-Za-z0-9+/=\n]+$/.test(maybeJson) && maybeJson.includes('ey')) {
          // best-effort decode; not strict
          const decoded = Buffer.from(maybeJson, 'base64').toString('utf8');
          serviceAccount = JSON.parse(decoded);
        } else if (maybeJson.startsWith('{')) {
          serviceAccount = JSON.parse(maybeJson);
        } else {
          // fallback: try to decode base64 anyway
          try {
            const decoded = Buffer.from(maybeJson, 'base64').toString('utf8');
            serviceAccount = JSON.parse(decoded);
          } catch (e) {
            throw new Error('Unable to parse FIREBASE_SERVICE_ACCOUNT');
          }
        }
      } catch (err) {
        // Re-throw with context
        throw new Error(`Failed to parse FIREBASE_SERVICE_ACCOUNT: ${String(err)}`);
      }

      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
      });
    } else if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
      // Use ADC (Application Default Credentials) when available in environment
      admin.initializeApp({
        credential: admin.credential.applicationDefault(),
      });
    } else {
      // Support explicit client email + private key method for platforms like Vercel
      const clientEmail = process.env.FIREBASE_ADMIN_CLIENT_EMAIL;
      const privateKey = process.env.FIREBASE_ADMIN_PRIVATE_KEY;
      const projectId = process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID || process.env.FIREBASE_PROJECT_ID;

      if (clientEmail && privateKey && projectId) {
        admin.initializeApp({
          credential: admin.credential.cert({
            projectId,
            clientEmail,
            privateKey: privateKey.replace(/\\n/g, '\n'),
          }),
        });
      } else {
        // Fail fast with clear guidance
        throw new Error(
          'Firebase Admin SDK not configured. Set FIREBASE_SERVICE_ACCOUNT (JSON/base64) or GOOGLE_APPLICATION_CREDENTIALS or FIREBASE_ADMIN_CLIENT_EMAIL + FIREBASE_ADMIN_PRIVATE_KEY.',
        );
      }
    }
  } catch (error) {
    // initialization errors should be loud during build/start
    // eslint-disable-next-line no-console
    console.error('Firebase Admin initialization failed:', error);
    throw error;
  }
}

export const adminAuth = admin.auth();
export const adminDb = admin.firestore();
export const adminStorage = admin.storage();

export default admin;