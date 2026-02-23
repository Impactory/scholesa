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
        const userRef = doc(firestore, 'users', currentUser.uid);
        unsubscribeProfile = onSnapshot(userRef, (docSnap) => {
          setProfile(docSnap.exists() ? (docSnap.data() as UserProfile) : null);
          setLoading(false);
        });
      } else {
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
    const errors: string[] = [];

    try {
      await clearSessionCookie();
    } catch (error) {
      console.error('Failed to clear session cookie before sign-out.', error);
      errors.push('session');
    }

    try {
      await firebaseSignOut(auth);
    } catch (error) {
      console.error('Failed to sign out from Firebase auth.', error);
      errors.push('firebase');
    } finally {
      setUser(null);
      setProfile(null);
    }

    if (errors.length > 0) {
      throw new Error(`Sign-out completed with partial failures: ${errors.join(', ')}`);
    }
  };

  return (
    <AuthContext.Provider value={{ user, profile, loading, signInWithGoogle, signOut }}>
      {children}
    </AuthContext.Provider>
  );
}
