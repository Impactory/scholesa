import { doc, getDoc } from 'firebase/firestore';
import { usersCollection } from './collections';
import { UserProfile } from '@/types/user';

export const getUserProfile = async (uid: string) => {
  const docRef = doc(usersCollection, uid);
  const docSnap = await getDoc(docRef);
  return docSnap.exists() ? (docSnap.data() as UserProfile) : null;
};
