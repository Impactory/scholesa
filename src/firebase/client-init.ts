import { initializeApp, getApps, getApp } from 'firebase/app';
import {
  connectAuthEmulator,
  getAuth,
  GoogleAuthProvider,
  OAuthProvider,
  SAMLAuthProvider,
} from 'firebase/auth';
import {
  initializeFirestore,
  persistentLocalCache,
  persistentMultipleTabManager,
  getFirestore,
  connectFirestoreEmulator,
} from 'firebase/firestore';
import { getStorage } from 'firebase/storage';
import { connectFunctionsEmulator, getFunctions } from 'firebase/functions';
import {
  currentE2EUid,
  getE2ECollection,
  resetE2EState,
  signInE2EUser,
  signOutE2EUser,
} from '@/src/testing/e2e/fakeWebBackend';

const hasFullFirebaseClientConfig = Boolean(
  process.env.NEXT_PUBLIC_FIREBASE_API_KEY &&
  process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN &&
  process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID &&
  process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET &&
  process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID &&
  process.env.NEXT_PUBLIC_FIREBASE_APP_ID
);

const isBuildPhase =
  process.env.NEXT_PHASE === 'phase-production-build' ||
  process.env.__NEXT_PRIVATE_BUILD_WORKER === '1' ||
  process.env.npm_lifecycle_event === 'build';

const isE2ETestMode = process.env.NEXT_PUBLIC_E2E_TEST_MODE === '1';
const allowPlaceholderClientConfig = typeof window === 'undefined' || isBuildPhase || isE2ETestMode;

if (!hasFullFirebaseClientConfig && !allowPlaceholderClientConfig) {
  throw new Error(
    'Missing required Firebase client env vars. Refusing to initialize the client SDK with demo placeholders.',
  );
}

const firebaseConfig = hasFullFirebaseClientConfig
  ? {
      apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY as string,
      authDomain: process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN as string,
      projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID as string,
      storageBucket: process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET as string,
      messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID as string,
      appId: process.env.NEXT_PUBLIC_FIREBASE_APP_ID as string,
    }
  : {
      apiKey: 'build-placeholder-api-key',
      authDomain: 'build-placeholder.firebaseapp.com',
      projectId: 'build-placeholder-project',
      storageBucket: 'build-placeholder.appspot.com',
      messagingSenderId: '000000000000',
      appId: '1:000000000000:web:build-placeholder',
    };

if (!hasFullFirebaseClientConfig && typeof window === 'undefined' && !isBuildPhase) {
  console.warn('Firebase client env vars are missing; using server-side placeholder config only outside browser runtime.');
}

const firestoreEmulatorHost =
  process.env.NEXT_PUBLIC_FIRESTORE_EMULATOR_HOST ||
  process.env.FIRESTORE_EMULATOR_HOST ||
  '';
const authEmulatorHost =
  process.env.NEXT_PUBLIC_FIREBASE_AUTH_EMULATOR_HOST ||
  process.env.FIREBASE_AUTH_EMULATOR_HOST ||
  '';
const functionsEmulatorHost =
  process.env.NEXT_PUBLIC_FIREBASE_FUNCTIONS_EMULATOR_HOST ||
  process.env.FIREBASE_FUNCTIONS_EMULATOR_HOST ||
  '';

// Initialize Firebase (Isomorphic: works on client and server/build)
const app = !getApps().length ? initializeApp(firebaseConfig) : getApp();

export { app };

export const auth = getAuth(app);
export const functions = getFunctions(app, 'us-central1');
export const storage = getStorage(app);

if (authEmulatorHost && typeof window !== 'undefined' && !(globalThis as Record<string, unknown>).__scholesaAuthEmulatorConnected) {
  connectAuthEmulator(auth, `http://${authEmulatorHost}`, { disableWarnings: true });
  (globalThis as Record<string, unknown>).__scholesaAuthEmulatorConnected = true;
}

// Initialize Firestore
// Client: Enable offline persistence
// Server: Use standard instance (avoids build errors)
export const db = typeof window !== 'undefined'
  ? initializeFirestore(app, {
      localCache: persistentLocalCache({
        tabManager: persistentMultipleTabManager(),
      }),
    })
  : getFirestore(app);

if (firestoreEmulatorHost && !(globalThis as Record<string, unknown>).__scholesaFirestoreEmulatorConnected) {
  const [host, portRaw] = firestoreEmulatorHost.split(':');
  const port = Number(portRaw || '8080');
  connectFirestoreEmulator(db, host, port);
  (globalThis as Record<string, unknown>).__scholesaFirestoreEmulatorConnected = true;
}

export const firestore = db;
export const googleProvider = new GoogleAuthProvider();

export function createFederatedAuthProvider(providerId: string) {
  const normalized = providerId.trim();
  if (normalized === 'google.com') {
    return googleProvider;
  }
  if (normalized.startsWith('oidc.')) {
    return new OAuthProvider(normalized);
  }
  if (normalized.startsWith('saml.')) {
    return new SAMLAuthProvider(normalized);
  }

  throw new Error(`Unsupported auth provider: ${providerId}`);
}

if (functionsEmulatorHost && typeof window !== 'undefined' && !(globalThis as Record<string, unknown>).__scholesaFunctionsEmulatorConnected) {
  const [host, portRaw] = functionsEmulatorHost.split(':');
  const port = Number(portRaw || '5001');
  connectFunctionsEmulator(functions, host, port);
  (globalThis as Record<string, unknown>).__scholesaFunctionsEmulatorConnected = true;
}

if (typeof window !== 'undefined' && isE2ETestMode) {
  (window as typeof window & {
    __scholesaE2E?: {
      signInAs: (uid: string, locale?: string) => Promise<{ uid: string | null }>;
      reset: (locale?: string) => Promise<void>;
      signOut: (locale?: string) => Promise<void>;
      currentUid: () => string | null;
      getCollection: (collectionName: string) => Array<Record<string, unknown>>;
    };
  }).__scholesaE2E = {
    signInAs: async (uid: string, locale?: string) => {
      return signInE2EUser(uid, locale);
    },
    reset: async (locale?: string) => {
      await resetE2EState(locale);
    },
    signOut: async (locale?: string) => {
      await signOutE2EUser(locale);
    },
    currentUid: () => currentE2EUid(),
    getCollection: (collectionName: string) => getE2ECollection(collectionName),
  };
}
