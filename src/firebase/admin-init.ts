import admin from 'firebase-admin';

type ServiceAccountShape = {
  project_id?: string;
  client_email?: string;
  private_key?: string;
};

function hasNonEmptyString(value: unknown): value is string {
  return typeof value === 'string' && value.trim().length > 0;
}

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

function getExplicitCredentialConfig(serviceAccount: ServiceAccountShape | null): {
  projectId: string;
  clientEmail: string;
  privateKey: string;
} | null {
  const projectIdCandidate =
    process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID ??
    process.env.FIREBASE_PROJECT_ID ??
    process.env.GOOGLE_CLOUD_PROJECT ??
    process.env.GCLOUD_PROJECT ??
    serviceAccount?.project_id;
  const clientEmailCandidate =
    process.env.FIREBASE_ADMIN_CLIENT_EMAIL ?? serviceAccount?.client_email;
  const privateKeyCandidate =
    process.env.FIREBASE_ADMIN_PRIVATE_KEY?.replace(/\\n/g, '\n') ??
    serviceAccount?.private_key?.replace(/\\n/g, '\n');

  if (
    !hasNonEmptyString(projectIdCandidate) ||
    !hasNonEmptyString(clientEmailCandidate) ||
    !hasNonEmptyString(privateKeyCandidate)
  ) {
    return null;
  }

  return {
    projectId: projectIdCandidate,
    clientEmail: clientEmailCandidate,
    privateKey: privateKeyCandidate,
  };
}

const initializeFirebaseAdmin = () => {
  if (admin.apps.length > 0) {
    return admin.apps[0]!;
  }

  const serviceAccount = parseServiceAccountFromEnv();
  const projectId =
    process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID ??
    process.env.FIREBASE_PROJECT_ID ??
    process.env.GOOGLE_CLOUD_PROJECT ??
    process.env.GCLOUD_PROJECT ??
    serviceAccount?.project_id;
  const usingFirebaseEmulators = Boolean(
    process.env.FIREBASE_AUTH_EMULATOR_HOST || process.env.FIRESTORE_EMULATOR_HOST,
  );

  if (usingFirebaseEmulators && hasNonEmptyString(projectId)) {
    return admin.initializeApp({ projectId });
  }

  const explicitCredentials = getExplicitCredentialConfig(serviceAccount);
  if (explicitCredentials) {
    try {
      return admin.initializeApp({
        credential: admin.credential.cert({
          projectId: explicitCredentials.projectId,
          clientEmail: explicitCredentials.clientEmail,
          privateKey: explicitCredentials.privateKey,
        }),
      });
    } catch (error) {
      console.error('Firebase Admin initialization failed:', error);
      return null;
    }
  }

  if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    try {
      return admin.initializeApp({
        credential: admin.credential.applicationDefault(),
        ...(hasNonEmptyString(projectId) ? { projectId } : {}),
      });
    } catch (error) {
      if (isBuildPhase()) {
        return null;
      }
      console.error('Firebase Admin ADC initialization failed:', error);
      return null;
    }
  }

  if (isBuildPhase()) {
    return null;
  }

  if (process.env.NODE_ENV === 'production' && process.env.GOOGLE_CLOUD_PROJECT) {
    return admin.initializeApp({
      projectId: process.env.GOOGLE_CLOUD_PROJECT,
    });
  }

  console.warn('Firebase Admin: Missing credentials, some features may not work');
  return null;
};

function requireAdminApp(): admin.app.App {
  const app = initializeFirebaseAdmin();
  if (!app) {
    throw new Error('Firebase Admin not initialized');
  }
  return app;
}

// Lazy getters that check if app exists
export const getAdminAuth = () => {
  requireAdminApp();
  return admin.auth();
};

export const getAdminDb = () => {
  requireAdminApp();
  return admin.firestore();
};

export const getAdminStorage = () => {
  requireAdminApp();
  return admin.storage();
};

function createLazyServiceProxy<T extends object>(resolver: () => T): T {
  return new Proxy({} as T, {
    get(_target, property, receiver) {
      return Reflect.get(resolver() as unknown as object, property, receiver);
    },
  });
}

export const adminAuth = createLazyServiceProxy(() => getAdminAuth());
export const adminDb = createLazyServiceProxy(() => getAdminDb());
export const adminStorage = createLazyServiceProxy(() => getAdminStorage());

export default admin;
