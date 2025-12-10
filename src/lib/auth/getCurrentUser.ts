import { auth } from '@/firebase/client';

export const getCurrentUser = () => {
  return auth.currentUser;
};
