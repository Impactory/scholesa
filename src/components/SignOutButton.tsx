'use client';

import { signOut } from 'firebase/auth';
import { useRouter, useParams } from 'next/navigation';
import { auth } from '@/src/firebase/client-init';

export function SignOutButton() {
  const router = useRouter();
  const params = useParams();
  const locale = (params?.locale as string) || 'en';

  const handleSignOut = async () => {
    try {
      await signOut(auth);
      router.push(`/${locale}/login`);
    } catch (error) {
      console.error('Error signing out:', error);
    }
  };

  return (
    <button onClick={handleSignOut} className="text-sm font-medium text-gray-500 hover:text-gray-900">
      Sign out
    </button>
  );
}