import 'server-only';
import { admin } from '@/src/firebase/admin-init';
import { getFirestore } from 'firebase-admin/firestore';
import { getCurrentUserServer } from './getCurrentUserServer';

export async function getUserRoleServer(): Promise<string | null> {
  const user = await getCurrentUserServer();

  if (!user) {
    return null;
  }

  try {
    const firestore = getFirestore(admin.app());
    const userDocRef = firestore.collection('users').doc(user.uid);
    const userDoc = await userDocRef.get();

    if (userDoc.exists) {
      return userDoc.data()?.role || null;
    }

    return null;
  } catch (error) {
    console.error('Error getting user role:', error);
    return null;
  }
}
