import { initializeApp, getApps, getApp } from 'firebase/app';
import { getAuth, GoogleAuthProvider } from 'firebase/auth';
import { initializeFirestore, persistentLocalCache, persistentMultipleTabManager } from 'firebase/firestore';
import { getStorage } from 'firebase/storage';

const firebaseConfig = {
  apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY,
  authDomain: process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN,
  projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID,
  storageBucket: process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID,
  appId: process.env.NEXT_PUBLIC_FIREBASE_APP_ID,
};

// Only initialize the client Firebase SDK when running in a browser and a public API key is present.
const isClient = typeof window !== 'undefined' && Boolean(process.env.NEXT_PUBLIC_FIREBASE_API_KEY);
const app = isClient ? (!getApps().length ? initializeApp(firebaseConfig) : getApp()) : (undefined as unknown as ReturnType<typeof getApp>);

export { app };

export const auth = isClient ? getAuth(app) : (undefined as any);

// Initialize Firestore only on the client for offline persistence; server should use the Admin SDK.
export const db = isClient
  ? initializeFirestore(app, { localCache: persistentLocalCache({ tabManager: persistentMultipleTabManager() }) })
  : (undefined as any);

export const firestore = db;
export const storage = isClient ? getStorage(app) : (undefined as any);
export const googleProvider = isClient ? new GoogleAuthProvider() : (undefined as any);
