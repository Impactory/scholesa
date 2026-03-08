import { initializeApp, getApps, getApp } from 'firebase/app';
import {
  connectAuthEmulator,
  getAuth,
  GoogleAuthProvider,
  signInWithCustomToken as firebaseSignInWithCustomToken,
  signOut as firebaseSignOut,
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
import { clearSessionCookie, syncSessionCookie } from '@/src/firebase/auth/sessionClient';

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

const firebaseConfig = {
  apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY || 'demo-api-key',
  authDomain: process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN || 'demo.firebaseapp.com',
  projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID || 'demo-project',
  storageBucket: process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET || 'demo.appspot.com',
  messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID || '000000000000',
  appId: process.env.NEXT_PUBLIC_FIREBASE_APP_ID || '1:000000000000:web:demo',
};

if (!hasFullFirebaseClientConfig && typeof window === 'undefined' && !isBuildPhase) {
  console.warn('Firebase client env vars are missing; using safe server-side placeholder config for build/runtime.');
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

if (functionsEmulatorHost && typeof window !== 'undefined' && !(globalThis as Record<string, unknown>).__scholesaFunctionsEmulatorConnected) {
  const [host, portRaw] = functionsEmulatorHost.split(':');
  const port = Number(portRaw || '5001');
  connectFunctionsEmulator(functions, host, port);
  (globalThis as Record<string, unknown>).__scholesaFunctionsEmulatorConnected = true;
}

if (typeof window !== 'undefined' && process.env.NEXT_PUBLIC_E2E_TEST_MODE === '1') {
  (window as typeof window & {
    __scholesaE2E?: {
      signInWithCustomToken: (customToken: string, locale?: string) => Promise<{ uid: string | null }>;
      signOut: (locale?: string) => Promise<void>;
      currentUid: () => string | null;
    };
  }).__scholesaE2E = {
    signInWithCustomToken: async (customToken: string, locale?: string) => {
      const credential = await firebaseSignInWithCustomToken(auth, customToken);
      await syncSessionCookie(credential.user, locale);
      return { uid: credential.user.uid };
    },
    signOut: async (locale?: string) => {
      try {
        await clearSessionCookie(locale);
      } finally {
        await firebaseSignOut(auth).catch(() => undefined);
      }
    },
    currentUid: () => auth.currentUser?.uid || null,
  };
}
