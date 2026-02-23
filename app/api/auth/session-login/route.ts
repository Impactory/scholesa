import { NextResponse } from 'next/server';
import { getAdminAuth, getAdminDb } from '@/src/firebase/admin-init';
import { resolveRequestLocale } from '@/src/lib/i18n/localeHeaders';

export async function POST(request: Request) {
  const resolvedLocale = resolveRequestLocale(request.headers);
  const { idToken } = await request.json();

  if (!idToken) {
    return NextResponse.json({ error: 'idToken is required' }, { status: 400 });
  }

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

    const expiresIn = 60 * 60 * 24 * 5 * 1000; // 5 days
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
    response.cookies.set({
      name: 'scholesa_locale',
      value: resolvedLocale,
      maxAge: expiresIn,
      httpOnly: false,
      secure: process.env.NODE_ENV === 'production',
      path: '/',
      sameSite: 'lax',
    });

    console.info(
      JSON.stringify({
        event: 'auth.session.created',
        uid,
        targetLocale: resolvedLocale,
      }),
    );

    return response;
  } catch (error) {
    console.error('Error creating session cookie:', error);
    return NextResponse.json({ error: 'Failed to create session' }, { status: 401 });
  }
}
