/* eslint-disable no-unused-vars */
import { createContext } from 'react';
import { User } from 'firebase/auth';
import { UserProfile } from '@/src/types/user';

interface AuthContextType {
  user: User | null;
  loading: boolean;
  profile: UserProfile | null;
  signInWithGoogle: () => Promise<void>;
  signUp: (email: string, password: string) => Promise<void>;
  signOut: () => Promise<void>;
}

export const AuthContext = createContext<AuthContextType>({
  user: null,
  loading: true,
  profile: null,
  signInWithGoogle: async () => {},
  // eslint-disable-next-line no-unused-vars
  signUp: async (email: string, password: string) => {},
  signOut: async () => {},
});
