import admin from 'firebase-admin';

type ServiceAccountShape = {
  project_id?: string;
  client_email?: string;
  private_key?: string;
};

function isBuildPhase(): boolean {
  return (
    process.env.NEXT_PHASE === 'phase-production-build' ||
    process.env.__NEXT_PRIVATE_BUILD_WORKER === '1' ||
    process.env.npm_lifecycle_event === 'build'
  );
}

function parseServiceAccountFromEnv(): ServiceAccountShape | null {
  const raw = process.env.FIREBASE_SERVICE_ACCOUNT?.trim();
  if (!raw) {
    return null;
  }

  try {
    return JSON.parse(raw) as ServiceAccountShape;
  } catch {
    try {
      const decoded = Buffer.from(raw, 'base64').toString('utf8');
      return JSON.parse(decoded) as ServiceAccountShape;
    } catch {
      return null;
    }
  }
}

const initializeFirebaseAdmin = () => {
  if (admin.apps.length > 0) {
    return admin.apps[0]!;
  }

  // Check if we have credentials
  const serviceAccount = parseServiceAccountFromEnv();
  const projectId =
    process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID ??
    process.env.FIREBASE_PROJECT_ID ??
    process.env.GOOGLE_CLOUD_PROJECT ??
    process.env.GCLOUD_PROJECT ??
    serviceAccount?.project_id;
  const clientEmail =
    process.env.FIREBASE_ADMIN_CLIENT_EMAIL ?? serviceAccount?.client_email;
  const privateKey =
    process.env.FIREBASE_ADMIN_PRIVATE_KEY?.replace(/\\n/g, '\n') ??
    serviceAccount?.private_key?.replace(/\\n/g, '\n');
  const usingFirebaseEmulators = Boolean(
    process.env.FIREBASE_AUTH_EMULATOR_HOST || process.env.FIRESTORE_EMULATOR_HOST,
  );

  if (usingFirebaseEmulators && projectId) {
    return admin.initializeApp({ projectId });
  }

  if (!projectId || !clientEmail || !privateKey) {
    // During build time, skip noisy warnings and allow safe static evaluation.
    if (isBuildPhase()) {
      return null;
    }

    // During runtime when credentials are missing, initialize with default (for GCP environments)
    // or warn and skip initialization.
    if (process.env.NODE_ENV === 'production' && process.env.GOOGLE_CLOUD_PROJECT) {
      // On GCP (Cloud Run), use default credentials
      return admin.initializeApp({
        projectId: process.env.GOOGLE_CLOUD_PROJECT || projectId,
      });
    }
    // Build time or missing creds - log warning but don't throw
    console.warn('Firebase Admin: Missing credentials, some features may not work');
    return null;
  }

  try {
    return admin.initializeApp({
      credential: admin.credential.cert({
        projectId,
        clientEmail,
        privateKey,
      }),
    });
  } catch (error) {
    console.error('Firebase Admin initialization failed:', error);
    return null;
  }
};

// Initialize on module load
initializeFirebaseAdmin();

// Lazy getters that check if app exists
export const getAdminAuth = () => {
  if (!admin.apps.length) {
    throw new Error('Firebase Admin not initialized');
  }
  return admin.auth();
};

export const getAdminDb = () => {
  if (!admin.apps.length) {
    throw new Error('Firebase Admin not initialized');
  }
  return admin.firestore();
};

export const getAdminStorage = () => {
  if (!admin.apps.length) {
    throw new Error('Firebase Admin not initialized');
  }
  return admin.storage();
};

// Legacy exports (may throw if not initialized)
export const adminAuth = admin.apps.length ? admin.auth() : (null as unknown as admin.auth.Auth);
export const adminDb = admin.apps.length ? admin.firestore() : (null as unknown as admin.firestore.Firestore);
export const adminStorage = admin.apps.length ? admin.storage() : (null as unknown as admin.storage.Storage);

export default admin;
