import { NextResponse } from 'next/server';
import { getAdminAuth, getAdminDb } from '@/src/firebase/admin-init';

function detectServiceStatus(check: () => unknown): 'ok' | 'unconfigured' {
  try {
    check();
    return 'ok';
  } catch {
    return 'unconfigured';
  }
}

export async function GET() {
  const buildTag =
    process.env.VERCEL_GIT_COMMIT_SHA ||
    process.env.GIT_SHA ||
    process.env.K_REVISION ||
    'dev';

  return NextResponse.json({
    ok: true,
    version: process.env.npm_package_version || '0.1.0',
    buildTag,
    services: {
      auth: detectServiceStatus(() => getAdminAuth()),
      firestore: detectServiceStatus(() => getAdminDb()),
    },
  });
}