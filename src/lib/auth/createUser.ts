import { deleteDoc, doc, getDoc, serverTimestamp, setDoc } from 'firebase/firestore';
import { firestore } from '@/src/firebase/client-init';
import type { User, Role } from '@/schema';
import type { AgeBand } from '@/src/types/user';

export interface RegistrationConsentParams {
  consentAccepted: boolean;
  tosAccepted: boolean;
  ageBand: AgeBand;
  parentConsentConfirmed: boolean;
  pipedaCrossBorderAcknowledged: boolean;
}

export interface CreateUserParams {
  uid: string;
  email: string;
  role: Role;
  displayName?: string;
  photoURL?: string;
  siteIds?: string[];
  organizationId?: string;
  registrationConsent?: RegistrationConsentParams;
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
  registrationConsent,
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

    const newUser = {
      uid,
      email,
      role,
      displayName: displayName || '',
      photoURL: photoURL || '',
      siteIds,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
      // Only include organizationId if defined to avoid Firestore "undefined" errors
      ...(organizationId ? { organizationId } : {}),
      // Include registration consent metadata if provided
      ...(registrationConsent
        ? {
            registrationConsent: {
              ...registrationConsent,
              consentTimestamp: serverTimestamp(),
            },
          }
        : {}),
    };

    await setDoc(userRef, newUser as unknown as User);
  } catch (error) {
    console.error('Error creating user document:', error);
    throw error;
  }
}

export async function deleteUserDocument(uid: string): Promise<void> {
  if (!uid) return;

  try {
    await deleteDoc(doc(firestore, 'users', uid));
  } catch (error) {
    console.error('Error deleting user document:', error);
    throw error;
  }
}