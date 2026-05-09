'use client';

import React from 'react';
import { AuthProvider } from '@/src/firebase/auth/AuthProvider';

export default function AuthLayout({ children }: { children: React.ReactNode }) {
  return <AuthProvider>{children}</AuthProvider>;
}