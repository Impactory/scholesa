import { NextResponse } from 'next/server';
import { getAdminAuth, getAdminDb } from '@/src/firebase/admin-init';
import { resolveRequestLocale } from '@/src/lib/i18n/localeHeaders';
import {
  buildEnterpriseSsoProfileUpdate,
  extractSignInProvider,
  isEnterpriseSsoProviderId,
  sanitizeEnterpriseSsoProvider,
} from '@/src/lib/auth/enterpriseSso';

async function loadEnterpriseSsoProvider(db: ReturnType<typeof getAdminDb>, providerId: string) {
  if (!isEnterpriseSsoProviderId(providerId)) return null;

  const snap = await db.collection('enterpriseSsoProviders')
    .where('providerId', '==', providerId)
    .limit(1)
    .get();
  const docSnap = snap.docs[0];
  if (!docSnap) return null;
  return sanitizeEnterpriseSsoProvider({ id: docSnap.id, ...(docSnap.data() as Record<string, unknown>) });
}

export async function POST(request: Request) {
  const resolvedLocale = resolveRequestLocale(request.headers);
  const { idToken, e2eSession } = await request.json();
  const isE2ETestMode = process.env.NEXT_PUBLIC_E2E_TEST_MODE === '1';

  if (isE2ETestMode && e2eSession) {
    const { encodeE2ESession } = await import('@/src/testing/e2e/fakeSession');
    const expiresIn = 60 * 60 * 24 * 5 * 1000;
    const response = NextResponse.json({ status: 'success' }, { status: 200 });
    response.cookies.set({
      name: '__session',
      value: encodeE2ESession(e2eSession),
      maxAge: expiresIn,
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      path: '/',
      sameSite: 'lax',
    });
    response.cookies.set({
      name: 'scholesa_locale',
      value: resolvedLocale,
      maxAge: expiresIn,
      httpOnly: false,
      secure: process.env.NODE_ENV === 'production',
      path: '/',
      sameSite: 'lax',
    });
    return response;
  }

  if (!idToken) {
    return NextResponse.json({ error: 'idToken is required' }, { status: 400 });
  }

  const expiresIn = 60 * 60 * 24 * 5 * 1000; // 5 days
  const localeCookieOptions = {
    name: 'scholesa_locale',
    value: resolvedLocale,
    maxAge: expiresIn,
    httpOnly: false,
    secure: process.env.NODE_ENV === 'production',
    path: '/',
    sameSite: 'lax' as const,
  };

  try {
    const auth = getAdminAuth();
    const db = getAdminDb();

    const decodedToken = await auth.verifyIdToken(idToken);
    const uid = decodedToken.uid;
    const signInProvider = extractSignInProvider(decodedToken as Record<string, unknown> & { uid: string });
    const enterpriseSsoProvider = await loadEnterpriseSsoProvider(db, signInProvider);
    if (isEnterpriseSsoProviderId(signInProvider) && !enterpriseSsoProvider) {
      return NextResponse.json({ error: 'Enterprise SSO provider is not configured.' }, { status: 403 });
    }

    const userRef = db.collection('users').doc(uid);
    const userDoc = await userRef.get();
    const existingUser = userDoc.exists ? (userDoc.data() as Record<string, unknown>) : null;
    const existingRole =
      typeof existingUser?.role === 'string' ? existingUser.role.trim() : '';

    if (enterpriseSsoProvider) {
      const nextProfile = buildEnterpriseSsoProfileUpdate({
        token: decodedToken as Record<string, unknown> & { uid: string },
        existingUser,
        provider: enterpriseSsoProvider,
        locale: resolvedLocale,
      });

      await userRef.set(
        userDoc.exists
          ? nextProfile
          : {
              uid,
              ...nextProfile,
              createdAt: new Date(),
            },
        { merge: true },
      );

      await db.collection('auditLogs').add({
        userId: uid,
        action: 'auth.sso.login',
        collection: 'enterpriseSsoProviders',
        documentId: enterpriseSsoProvider.id,
        timestamp: Date.now(),
        details: {
          providerId: enterpriseSsoProvider.providerId,
          providerType: enterpriseSsoProvider.providerType,
          role: nextProfile.role,
          activeSiteId: nextProfile.activeSiteId,
          locale: resolvedLocale,
        },
      });
    }

    if (!enterpriseSsoProvider && (!userDoc.exists || !existingRole)) {
      return NextResponse.json(
        {
          error:
              'Your account is not provisioned for this sign-in method. Contact your site or HQ admin.',
        },
        { status: 403 },
      );
    }

    if (!enterpriseSsoProvider) {
      await userRef.set(
        {
          email: decodedToken.email,
          displayName: decodedToken.name || existingUser?.displayName || decodedToken.email || 'User',
          preferredLocale: resolvedLocale,
          updatedAt: new Date(),
        },
        { merge: true },
      );
    }

    const sessionCookie = await auth.createSessionCookie(idToken, { expiresIn });

    const options = {
      name: '__session',
      value: sessionCookie,
      maxAge: expiresIn,
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      path: '/',
    };

    const response = NextResponse.json({ status: 'success' }, { status: 200 });
    response.cookies.set(options);
    response.cookies.set(localeCookieOptions);

    console.info(
      JSON.stringify({
        event: enterpriseSsoProvider ? 'auth.sso.login' : 'auth.session.created',
        uid,
        providerId: enterpriseSsoProvider?.providerId || signInProvider || 'password',
        targetLocale: resolvedLocale,
      }),
    );

    return response;
  } catch (error) {
    const isAdminMissing =
      error instanceof Error &&
      error.message.includes('Firebase Admin not initialized');

    if (isAdminMissing) {
      console.error('Firebase Admin credentials are missing for session creation.');
      return NextResponse.json(
        {
          error:
            'Firebase Admin is not initialized. Configure FIREBASE_SERVICE_ACCOUNT or FIREBASE_ADMIN_* env vars.',
        },
        { status: 503 },
      );
    }

    console.error('Error creating session cookie:', error);
    return NextResponse.json({ error: 'Failed to create session' }, { status: 401 });
  }
}
