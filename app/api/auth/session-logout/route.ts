import { NextResponse } from 'next/server';

export async function POST() {
  const options = {
    name: '__session',
    value: '',
    maxAge: -1, // Expire the cookie immediately
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    path: '/',
  };

  const response = NextResponse.json({ status: 'success' }, { status: 200 });
  response.cookies.set(options);

  return response;
}
