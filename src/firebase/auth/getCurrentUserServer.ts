import 'server-only';
import { getAdminAuth } from '@/src/firebase/admin-init';
import { cookies } from 'next/headers';

export async function getCurrentUserServer() {
  const cookieStore = await cookies();
  const sessionCookie = cookieStore.get('__session')?.value;

  if (!sessionCookie) {
    return null;
  }

  try {
    const auth = getAdminAuth();
    const decodedIdToken = await auth.verifySessionCookie(sessionCookie, true);
    const user = await auth.getUser(decodedIdToken.uid);
    return user;
  } catch (error) {
    console.error('Error verifying session cookie:', error);
    return null;
  }
}
