import { NextResponse } from 'next/server';
import { getAdminAuth, getAdminDb } from '@/src/firebase/admin-init';
import { resolveRequestLocale } from '@/src/lib/i18n/localeHeaders';
import { encodeE2ESession } from '@/src/testing/e2e/fakeSession';

export async function POST(request: Request) {
  const resolvedLocale = resolveRequestLocale(request.headers);
  const { idToken, e2eSession } = await request.json();
  const isE2ETestMode = process.env.NEXT_PUBLIC_E2E_TEST_MODE === '1';

  if (isE2ETestMode && e2eSession) {
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

    const userRef = db.collection('users').doc(uid);
    const userDoc = await userRef.get();

    if (!userDoc.exists) {
      await userRef.set({
        email: decodedToken.email,
        preferredLocale: resolvedLocale,
        createdAt: new Date(),
      });
    } else {
      await userRef.set(
        {
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
        event: 'auth.session.created',
        uid,
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
