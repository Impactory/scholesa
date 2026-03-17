'use client';

import { createContext, useContext, useEffect, useState, ReactNode } from 'react';
import { onAuthStateChanged, signInWithPopup, signOut as firebaseSignOut, User as FirebaseUser } from 'firebase/auth';
import { doc, onSnapshot } from 'firebase/firestore';
import { auth, createFederatedAuthProvider, firestore } from '@/src/firebase/client-init';
import { UserProfile } from '@/src/types/user';
import { clearSessionCookie, syncSessionCookie } from './sessionClient';

interface AuthContextType {
  user: FirebaseUser | null;
  profile: UserProfile | null;
  loading: boolean;
  signInWithGoogle: () => Promise<void>;
  signInWithProvider: (providerId: string, locale?: string) => Promise<void>;
  signOut: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType>({
  user: null,
  profile: null,
  loading: true,
  signInWithGoogle: async () => {},
  signInWithProvider: async () => {},
  signOut: async () => {},
});

export const useAuthContext = () => useContext(AuthContext);

const isE2ETestMode = process.env.NEXT_PUBLIC_E2E_TEST_MODE === '1';

async function loadE2EAuthBackend() {
  return import('@/src/testing/e2e/fakeWebBackend');
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<FirebaseUser | null>(null);
  const [profile, setProfile] = useState<UserProfile | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (isE2ETestMode) {
      let unsubscribe: (() => void) | null = null;
      let cancelled = false;

      void loadE2EAuthBackend()
        .then(({ subscribeE2EAuthState }) => {
          if (cancelled) return;
          unsubscribe = subscribeE2EAuthState((currentUser, currentProfile) => {
            setUser(currentUser);
            setProfile(currentProfile);
            setLoading(false);
          });
        })
        .catch((error) => {
          console.error('Failed to initialize E2E auth backend.', error);
          if (!cancelled) {
            setUser(null);
            setProfile(null);
            setLoading(false);
          }
        });

      return () => {
        cancelled = true;
        unsubscribe?.();
      };
    }

    let unsubscribeProfile: (() => void) | null = null;

    const unsubscribeAuth = onAuthStateChanged(auth, (currentUser) => {
      setUser(currentUser);

      // Clean up previous profile listener if it exists
      if (unsubscribeProfile) {
        unsubscribeProfile();
        unsubscribeProfile = null;
      }

      if (currentUser) {
        void syncSessionCookie(currentUser).catch((error) => {
          console.error('Failed to sync Firebase session cookie after auth state change.', error);
        });

        const userRef = doc(firestore, 'users', currentUser.uid);
        unsubscribeProfile = onSnapshot(
          userRef,
          (docSnap) => {
            setProfile(docSnap.exists() ? (docSnap.data() as UserProfile) : null);
            setLoading(false);
          },
          (error) => {
            console.error('Failed to subscribe to Firebase profile snapshot.', error);
            setProfile(null);
            setLoading(false);
          },
        );
      } else {
        void clearSessionCookie().catch((error) => {
          console.error('Failed to clear Firebase session cookie after auth state cleared.', error);
        });
        setProfile(null);
        setLoading(false);
      }
    });

    return () => {
      unsubscribeAuth();
      if (unsubscribeProfile) unsubscribeProfile();
    };
  }, []);

  const signInWithGoogle = async () => {
    if (isE2ETestMode) {
      throw new Error('Google sign-in is disabled in E2E test mode.');
    }

    await signInWithProvider('google.com');
  };

  const signInWithProvider = async (providerId: string, locale?: string) => {
    if (isE2ETestMode) {
      throw new Error('Federated sign-in is disabled in E2E test mode.');
    }

    const provider = createFederatedAuthProvider(providerId);
    const credential = await signInWithPopup(auth, provider);

    try {
      await syncSessionCookie(credential.user, locale);
    } catch (error) {
      try {
        await firebaseSignOut(auth);
      } catch (signOutError) {
        console.error('Failed to clear Firebase Auth state after federated session setup failure.', signOutError);
      }
      throw error;
    }
  };

  const signOut = async () => {
    if (isE2ETestMode) {
      const { signOutE2EUser } = await loadE2EAuthBackend();
      await signOutE2EUser();
      setUser(null);
      setProfile(null);
      return;
    }

    let firebaseError: unknown = null;

    try {
      await clearSessionCookie();
    } catch (error) {
      console.error('Failed to clear session cookie before sign-out.', error);
    }

    try {
      await firebaseSignOut(auth);
    } catch (error) {
      console.error('Failed to sign out from Firebase auth.', error);
      firebaseError = error;
    } finally {
      setUser(null);
      setProfile(null);
    }

    if (firebaseError) {
      throw firebaseError;
    }
  };

  return (
    <AuthContext.Provider value={{ user, profile, loading, signInWithGoogle, signInWithProvider, signOut }}>
      {children}
    </AuthContext.Provider>
  );
}
