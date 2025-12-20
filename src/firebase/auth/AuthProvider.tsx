'use client';
/* eslint-disable react-hooks/rules-of-hooks, react-hooks/exhaustive-deps, no-unused-vars */

import React, { useContext } from 'react';
import { AuthContext } from './AuthContext';
import {
  getAuth,
  GoogleAuthProvider,
  signInWithPopup,
  createUserWithEmailAndPassword,
  signOut as firebaseSignOut,
} from 'firebase/auth';
import { getFirestore, doc, onSnapshot } from 'firebase/firestore';
import { app } from '@/src/firebase/client-init';
import { useAuthState } from 'react-firebase-hooks/auth';

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const isBrowser = typeof window !== 'undefined';
  if (!isBrowser) {
    const value = {
      user: null,
      loading: false,
      profile: null,
      signInWithGoogle: async () => {},
      signUp: async (_email: string, _password: string) => {},
      signOut: async () => {},
    } as any;
    return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
  }

  const auth = React.useMemo(() => getAuth(app as any), []);
  const db = React.useMemo(() => getFirestore(app as any), []);
  const [user, loading] = useAuthState(auth);
  const [profile, setProfile] = React.useState<any>(null);

  React.useEffect(() => {
    if (user) {
      const unsub = onSnapshot(doc(db, 'users', user.uid), (snap) => {
        setProfile(snap.data() ?? null);
      });
      return () => unsub();
    }
  }, [user]);

  const signInWithGoogle = async () => {
    const provider = new GoogleAuthProvider();
    try {
      await signInWithPopup(auth, provider);
    } catch (error) {
      console.error(error);
    }
  };

  const signUp = async (email: string, password: string) => {
    try {
      await createUserWithEmailAndPassword(auth, email, password);
    } catch (error) {
      console.error(error);
    }
  };

  const signOut = async () => {
    try {
      await firebaseSignOut(auth);
    } catch (error) {
      console.error(error);
    }
  };

  const value = { user: user ?? null, loading, profile, signInWithGoogle, signUp, signOut };

  return (
    <AuthContext.Provider value={value}>
      {!loading && children}
    </AuthContext.Provider>
  );
}

export const useAuthContext = () => useContext(AuthContext);
