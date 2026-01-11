import { doc, getDoc, setDoc } from 'firebase/firestore';
import { firestore } from '@/src/firebase/client-init';
import type { User, Role } from '@/schema';

export interface CreateUserParams {
  uid: string;
  email: string;
  role: Role;
  displayName?: string;
  photoURL?: string;
  siteIds?: string[];
  organizationId?: string;
}

/**
 * Creates a user document in Firestore.
 * Ensures critical fields like role, siteIds, and timestamps are set.
 * Idempotent: will not overwrite if the user doc already exists.
 */
export async function createUserDocument({
  uid,
  email,
  role,
  displayName,
  photoURL,
  siteIds = [],
  organizationId,
}: CreateUserParams): Promise<void> {
  if (!uid) throw new Error('User UID is required');
  if (!email) throw new Error('User email is required');
  if (!role) throw new Error('User role is required');

  const userRef = doc(firestore, 'users', uid);
  
  try {
    const userSnap = await getDoc(userRef);

    if (userSnap.exists()) {
      // User already exists, skip creation
      return;
    }

    const newUser: User = {
      uid,
      email,
      role,
      displayName: displayName || '',
      photoURL: photoURL || '',
      siteIds,
      createdAt: Date.now(),
      updatedAt: Date.now(),
      // Only include organizationId if defined to avoid Firestore "undefined" errors
      ...(organizationId ? { organizationId } : {}),
    };

    await setDoc(userRef, newUser);
  } catch (error) {
    console.error('Error creating user document:', error);
    throw error;
  }
}