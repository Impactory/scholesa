'use client';

import React, { useContext } from 'react';
import { useAuth } from '@/src/firebase/auth/useAuth';
import { AuthContext } from '@/src/firebase/auth/AuthContext';

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const { user, loading } = useAuth();

  return (
    <AuthContext.Provider value={{ user, loading }}>
      {children}
    </AuthContext.Provider>
  );
}

export const useAuthContext = () => useContext(AuthContext);
