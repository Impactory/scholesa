import { NextResponse } from 'next/server';
import { getAdminDb } from '@/src/firebase/admin-init';
import { resolveRequestLocale } from '@/src/lib/i18n/localeHeaders';
import {
  buildEnterpriseSsoButtonLabel,
  filterEnterpriseSsoProviders,
  sanitizeEnterpriseSsoProvider,
} from '@/src/lib/auth/enterpriseSso';

export async function GET(request: Request) {
  const locale = resolveRequestLocale(request.headers);
  const { searchParams } = new URL(request.url);
  const email = searchParams.get('email');
  const siteId = searchParams.get('siteId');

  if (process.env.NEXT_PUBLIC_E2E_TEST_MODE === '1') {
    return NextResponse.json({ providers: [] }, { status: 200 });
  }

  const db = getAdminDb();
  const snap = await db.collection('enterpriseSsoProviders')
    .where('enabled', '==', true)
    .limit(50)
    .get()
    .catch(async () => db.collection('enterpriseSsoProviders').limit(50).get());

  const providers = filterEnterpriseSsoProviders(
    snap.docs
      .map((docSnap) => sanitizeEnterpriseSsoProvider({ id: docSnap.id, ...(docSnap.data() as Record<string, unknown>) }))
      .filter((provider): provider is NonNullable<typeof provider> => provider !== null),
    { email, siteId },
  ).map((provider) => ({
    providerId: provider.providerId,
    providerType: provider.providerType,
    displayName: provider.displayName,
    buttonLabel: buildEnterpriseSsoButtonLabel(provider, locale),
    siteIds: provider.siteIds,
    allowedDomains: provider.allowedDomains || [],
    jitProvisioning: provider.jitProvisioning !== false,
  }));

  return NextResponse.json({ providers }, { status: 200 });
}