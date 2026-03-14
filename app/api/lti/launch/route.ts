import { NextResponse } from 'next/server';
import { getAdminDb } from '@/src/firebase/admin-init';
import { resolveLtiLaunch, getLtiErrorMessage, getLtiErrorStatus } from '@/src/lib/lti/launch';

async function loadPlatformRegistration(input: { issuer: string; deploymentId: string; audiences: string[] }) {
  const db = getAdminDb();
  const snap = await db.collection('ltiPlatformRegistrations')
    .where('issuer', '==', input.issuer)
    .where('deploymentId', '==', input.deploymentId)
    .limit(10)
    .get();

  const match = snap.docs
    .map((docSnap): Record<string, unknown> & { id: string } => ({
      id: docSnap.id,
      ...(docSnap.data() as Record<string, unknown>),
    }))
    .find((row) => typeof row.clientId === 'string' && input.audiences.includes(row.clientId));

  if (!match) return null;

  return {
    id: match.id,
    siteId: typeof match.siteId === 'string' ? match.siteId : '',
    issuer: typeof match.issuer === 'string' ? match.issuer : '',
    clientId: typeof match.clientId === 'string' ? match.clientId : '',
    deploymentId: typeof match.deploymentId === 'string' ? match.deploymentId : '',
    jwksUrl: typeof match.jwksUrl === 'string' ? match.jwksUrl : '',
    status: typeof match.status === 'string' ? match.status : 'active',
  };
}

async function loadResourceLink(input: { registrationId: string; resourceLinkId: string }) {
  const db = getAdminDb();
  const snap = await db.collection('ltiResourceLinks')
    .where('registrationId', '==', input.registrationId)
    .where('resourceLinkId', '==', input.resourceLinkId)
    .limit(1)
    .get();

  const docSnap = snap.docs[0];
  if (!docSnap) return null;

  const data = docSnap.data() as Record<string, unknown>;
  return {
    id: docSnap.id,
    registrationId: typeof data.registrationId === 'string' ? data.registrationId : '',
    siteId: typeof data.siteId === 'string' ? data.siteId : '',
    resourceLinkId: typeof data.resourceLinkId === 'string' ? data.resourceLinkId : '',
    missionId: typeof data.missionId === 'string' ? data.missionId : undefined,
    sessionId: typeof data.sessionId === 'string' ? data.sessionId : undefined,
    targetPath: typeof data.targetPath === 'string' ? data.targetPath : undefined,
    locale: typeof data.locale === 'string' ? data.locale : undefined,
    lineItemId: typeof data.lineItemId === 'string' ? data.lineItemId : undefined,
    lineItemUrl: typeof data.lineItemUrl === 'string' ? data.lineItemUrl : undefined,
  };
}

async function recordLaunchAudit(entry: {
  issuer: string;
  clientId: string;
  deploymentId: string;
  registrationId: string;
  resourceLinkId: string;
  siteId: string | null;
  missionId: string | null;
  targetPath: string;
  locale: string;
  subject: string;
}) {
  const db = getAdminDb();
  await db.collection('auditLogs').add({
    action: 'lti.launch.accepted',
    collection: 'ltiPlatformRegistrations',
    documentId: entry.registrationId,
    userId: entry.subject,
    timestamp: Date.now(),
    details: {
      issuer: entry.issuer,
      clientId: entry.clientId,
      deploymentId: entry.deploymentId,
      resourceLinkId: entry.resourceLinkId,
      siteId: entry.siteId,
      missionId: entry.missionId,
      targetPath: entry.targetPath,
      locale: entry.locale,
    },
  });
}

export async function POST(request: Request) {
  try {
    const formData = await request.formData();
    const idToken = formData.get('id_token');
    if (typeof idToken !== 'string' || idToken.trim().length === 0) {
      return NextResponse.json({ error: 'id_token is required' }, { status: 400 });
    }

    const launch = await resolveLtiLaunch(idToken, request.url, {
      loadPlatformRegistration,
      loadResourceLink,
      recordLaunchAudit,
    });

    const redirectUrl = new URL(launch.targetPath, request.url);
    redirectUrl.searchParams.set('ltiRegistrationId', launch.registrationId);
    redirectUrl.searchParams.set('ltiResourceLinkId', launch.resourceLinkId);
    if (launch.siteId) redirectUrl.searchParams.set('siteId', launch.siteId);
    if (launch.missionId) redirectUrl.searchParams.set('missionId', launch.missionId);
    if (launch.lineItemId) redirectUrl.searchParams.set('lineItemId', launch.lineItemId);
    if (launch.lineItemUrl) redirectUrl.searchParams.set('lineItemUrl', launch.lineItemUrl);

    const response = NextResponse.redirect(redirectUrl, { status: 302 });
    response.cookies.set({
      name: 'scholesa_locale',
      value: launch.locale,
      maxAge: 60 * 60 * 24 * 5,
      httpOnly: false,
      secure: process.env.NODE_ENV === 'production',
      path: '/',
      sameSite: 'lax',
    });
    return response;
  } catch (error) {
    return NextResponse.json(
      { error: getLtiErrorMessage(error) },
      { status: getLtiErrorStatus(error) },
    );
  }
}