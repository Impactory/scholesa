import 'server-only';
import { getAdminDb } from '@/src/firebase/admin-init';
import { getCurrentUserServer } from './getCurrentUserServer';

export async function getUserRoleServer(): Promise<string | null> {
  const user = await getCurrentUserServer();

  if (!user) {
    return null;
  }

  const e2eRole = (user as { customClaims?: { role?: string } }).customClaims?.role;
  if (typeof e2eRole === 'string' && e2eRole.length > 0) {
    return e2eRole;
  }

  try {
    const firestore = getAdminDb();
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
