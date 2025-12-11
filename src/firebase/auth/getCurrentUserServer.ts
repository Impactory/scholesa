import 'server-only';
import { initializeServerApp } from '@/src/firebase/admin-init';
import { getAuth } from 'firebase-admin/auth';
import { cookies } from 'next/headers';

export async function getCurrentUserServer() {
  const { app } = initializeServerApp();
  const auth = getAuth(app);
  
  const sessionCookie = cookies().get('__session')?.value;

  if (!sessionCookie) {
    return null;
  }

  try {
    const decodedIdToken = await auth.verifySessionCookie(sessionCookie, true);
    const user = await auth.getUser(decodedIdToken.uid);
    return user;
  } catch (error) {
    console.error("Error verifying session cookie:", error);
    return null;
  }
}
