'use client';

import { createContext, useContext, useEffect, useState, ReactNode } from 'react';
import { onAuthStateChanged, signInWithPopup, signOut as firebaseSignOut, User as FirebaseUser } from 'firebase/auth';
import { doc, onSnapshot } from 'firebase/firestore';
import { auth, firestore, googleProvider } from '@/src/firebase/client-init';
import { UserProfile } from '@/src/types/user';
import { clearSessionCookie, syncSessionCookie } from './sessionClient';

interface AuthContextType {
  user: FirebaseUser | null;
  profile: UserProfile | null;
  loading: boolean;
  signInWithGoogle: () => Promise<void>;
  signOut: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType>({
  user: null,
  profile: null,
  loading: true,
  signInWithGoogle: async () => {},
  signOut: async () => {},
});

export const useAuthContext = () => useContext(AuthContext);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<FirebaseUser | null>(null);
  const [profile, setProfile] = useState<UserProfile | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
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
    const credential = await signInWithPopup(auth, googleProvider);
    await syncSessionCookie(credential.user);
  };

  const signOut = async () => {
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
    <AuthContext.Provider value={{ user, profile, loading, signInWithGoogle, signOut }}>
      {children}
    </AuthContext.Provider>
  );
}
