import admin from 'firebase-admin';

const initializeFirebaseAdmin = () => {
  if (admin.apps.length > 0) {
    return admin.apps[0]!;
  }

  // Check if we have credentials
  const projectId = process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID;
  const clientEmail = process.env.FIREBASE_ADMIN_CLIENT_EMAIL;
  const privateKey = process.env.FIREBASE_ADMIN_PRIVATE_KEY?.replace(/\\n/g, '\n');

  if (!projectId || !clientEmail || !privateKey) {
    // During build time or when credentials are missing, initialize with default (for GCP environments)
    // or skip initialization
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