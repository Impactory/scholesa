import { adminDb } from '@/src/firebase/admin-init';
import type { User, Role } from '@/schema';

/**
 * Retrieves the user's role from the 'users' collection in Firestore.
 * 
 * This function is designed for Server Components, Server Actions, or API Routes
 * where you have a trusted UID (e.g. from a verified session cookie or token).
 * 
 * @param uid - The user's unique ID (from Auth).
 * @returns The user's role (e.g., 'learner', 'educator') or null if not found.
 */
export async function getUserRoleServer(uid: string): Promise<Role | null> {
  if (!uid) return null;

  try {
    const userDoc = await adminDb.collection('users').doc(uid).get();

    if (!userDoc.exists) {
      return null;
    }

    const userData = userDoc.data() as User;
    return userData.role || null;
  } catch (error) {
    console.error('getUserRoleServer: Error fetching user role:', error);
    return null;
  }
}