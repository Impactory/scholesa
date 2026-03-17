import 'server-only';
import { getAdminAuth } from '@/src/firebase/admin-init';
import { cookies } from 'next/headers';

export async function getCurrentUserServer() {
  const cookieStore = await cookies();
  const sessionCookie = cookieStore.get('__session')?.value;
  const isE2ETestMode = process.env.NEXT_PUBLIC_E2E_TEST_MODE === '1';

  if (!sessionCookie) {
    return null;
  }

  if (isE2ETestMode && sessionCookie.startsWith('e2e:')) {
    const { decodeE2ESession } = await import('@/src/testing/e2e/fakeSession');
    const e2eSession = decodeE2ESession(sessionCookie);
    if (e2eSession) {
      return {
        uid: e2eSession.uid,
        email: e2eSession.email,
        displayName: e2eSession.displayName,
        customClaims: {
          role: e2eSession.role,
          siteIds: e2eSession.siteIds || [],
          activeSiteId: e2eSession.activeSiteId || null,
        },
      };
    }
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
