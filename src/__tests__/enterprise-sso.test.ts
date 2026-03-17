jest.mock('@/src/firebase/admin-init', () => ({
  getAdminAuth: jest.fn(),
  getAdminDb: jest.fn(),
}));

import { getAdminAuth, getAdminDb } from '@/src/firebase/admin-init';
import { GET as getEnterpriseProviders } from '@/app/api/auth/sso/providers/route';
import { POST as postSessionLogin } from '@/app/api/auth/session-login/route';

const mockedGetAdminAuth = getAdminAuth as jest.MockedFunction<typeof getAdminAuth>;
const mockedGetAdminDb = getAdminDb as jest.MockedFunction<typeof getAdminDb>;

function buildQueryMock(docs: Array<{ id: string; data: () => Record<string, unknown> }>) {
  return {
    where: jest.fn().mockReturnThis(),
    limit: jest.fn().mockReturnThis(),
    get: jest.fn().mockResolvedValue({ docs }),
  };
}

describe('enterprise SSO auth routes', () => {
  beforeEach(() => {
    mockedGetAdminAuth.mockReset();
    mockedGetAdminDb.mockReset();
  });

  it('lists enabled enterprise providers with locale-aware labels', async () => {
    const providerQuery = buildQueryMock([
      {
        id: 'provider-1',
        data: () => ({
          providerId: 'oidc.acme',
          displayName: 'Acme Identity',
          siteIds: ['site-1'],
          allowedDomains: ['acme.edu'],
          enabled: true,
        }),
      },
      {
        id: 'provider-2',
        data: () => ({
          providerId: 'saml.other',
          displayName: 'Other Identity',
          siteIds: ['site-2'],
          allowedDomains: ['other.edu'],
          enabled: true,
        }),
      },
    ]);
    mockedGetAdminDb.mockReturnValue({
      collection: jest.fn((name: string) => {
        if (name === 'enterpriseSsoProviders') return providerQuery;
        throw new Error(`Unexpected collection ${name}`);
      }),
    } as never);

    const response = await getEnterpriseProviders(new Request('https://scholesa.test/api/auth/sso/providers?email=teacher@acme.edu', {
      headers: {
        'Accept-Language': 'zh-CN',
      },
    }));
    const body = await response.json();

    expect(response.status).toBe(200);
    expect(body.providers).toHaveLength(1);
    expect(body.providers[0]).toMatchObject({
      providerId: 'oidc.acme',
      providerType: 'oidc',
      displayName: 'Acme Identity',
    });
    expect(body.providers[0].buttonLabel).toContain('Acme Identity');
    expect(body.providers[0].buttonLabel).toContain('登录');
  });

  it('creates a session and JIT provisions enterprise users from configured providers', async () => {
    const verifyIdToken = jest.fn().mockResolvedValue({
      uid: 'user-1',
      email: 'teacher@acme.edu',
      name: 'Acme Teacher',
      firebase: {
        sign_in_provider: 'oidc.acme',
      },
      scholesa_role: 'educator',
      scholesa_site_ids: ['site-1'],
    });
    const createSessionCookie = jest.fn().mockResolvedValue('session-cookie-value');
    mockedGetAdminAuth.mockReturnValue({
      verifyIdToken,
      createSessionCookie,
    } as never);

    const providerQuery = buildQueryMock([
      {
        id: 'provider-1',
        data: () => ({
          providerId: 'oidc.acme',
          providerType: 'oidc',
          displayName: 'Acme Identity',
          siteIds: ['site-1'],
          defaultRole: 'educator',
          defaultSiteId: 'site-1',
          organizationId: 'org-acme',
          enabled: true,
        }),
      },
    ]);
    const userSet = jest.fn().mockResolvedValue(undefined);
    const auditAdd = jest.fn().mockResolvedValue(undefined);
    mockedGetAdminDb.mockReturnValue({
      collection: jest.fn((name: string) => {
        if (name === 'enterpriseSsoProviders') return providerQuery;
        if (name === 'users') {
          return {
            doc: jest.fn(() => ({
              get: jest.fn().mockResolvedValue({ exists: false }),
              set: userSet,
            })),
          };
        }
        if (name === 'auditLogs') {
          return { add: auditAdd };
        }
        throw new Error(`Unexpected collection ${name}`);
      }),
    } as never);

    const response = await postSessionLogin(new Request('https://scholesa.test/api/auth/session-login', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Scholesa-Locale': 'zh-TW',
      },
      body: JSON.stringify({ idToken: 'firebase-token' }),
    }));
    const body = await response.json();

    expect(response.status).toBe(200);
    expect(body.status).toBe('success');
    expect(verifyIdToken).toHaveBeenCalledWith('firebase-token');
    expect(createSessionCookie).toHaveBeenCalledWith('firebase-token', expect.objectContaining({ expiresIn: expect.any(Number) }));
    expect(userSet).toHaveBeenCalledWith(expect.objectContaining({
      uid: 'user-1',
      role: 'educator',
      siteIds: ['site-1'],
      activeSiteId: 'site-1',
      organizationId: 'org-acme',
      authProviderId: 'oidc.acme',
      authProviderType: 'oidc',
      jitProvisioned: true,
      preferredLocale: 'zh-TW',
    }), { merge: true });
    expect(auditAdd).toHaveBeenCalledWith(expect.objectContaining({
      action: 'auth.sso.login',
      documentId: 'provider-1',
    }));
    expect(response.cookies.get('__session')?.value).toBe('session-cookie-value');
  });

  it('rejects enterprise sign-in when the provider is not configured', async () => {
    mockedGetAdminAuth.mockReturnValue({
      verifyIdToken: jest.fn().mockResolvedValue({
        uid: 'user-2',
        email: 'teacher@missing.edu',
        firebase: {
          sign_in_provider: 'saml.missing',
        },
      }),
      createSessionCookie: jest.fn(),
    } as never);
    mockedGetAdminDb.mockReturnValue({
      collection: jest.fn((name: string) => {
        if (name === 'enterpriseSsoProviders') return buildQueryMock([]);
        if (name === 'users') {
          return {
            doc: jest.fn(() => ({
              get: jest.fn().mockResolvedValue({ exists: false }),
              set: jest.fn(),
            })),
          };
        }
        if (name === 'auditLogs') {
          return { add: jest.fn() };
        }
        throw new Error(`Unexpected collection ${name}`);
      }),
    } as never);

    const response = await postSessionLogin(new Request('https://scholesa.test/api/auth/session-login', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ idToken: 'firebase-token' }),
    }));
    const body = await response.json();

    expect(response.status).toBe(403);
    expect(body.error).toBe('Enterprise SSO provider is not configured.');
  });

  it('rejects non-enterprise sign-in when the user is not provisioned', async () => {
    mockedGetAdminAuth.mockReturnValue({
      verifyIdToken: jest.fn().mockResolvedValue({
        uid: 'user-3',
        email: 'teacher@scholesa.dev',
        name: 'Teacher Three',
        firebase: {
          sign_in_provider: 'google.com',
        },
      }),
      createSessionCookie: jest.fn(),
    } as never);

    mockedGetAdminDb.mockReturnValue({
      collection: jest.fn((name: string) => {
        if (name === 'enterpriseSsoProviders') return buildQueryMock([]);
        if (name === 'users') {
          return {
            doc: jest.fn(() => ({
              get: jest.fn().mockResolvedValue({ exists: false }),
              set: jest.fn(),
            })),
          };
        }
        throw new Error(`Unexpected collection ${name}`);
      }),
    } as never);

    const response = await postSessionLogin(new Request('https://scholesa.test/api/auth/session-login', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ idToken: 'firebase-token' }),
    }));
    const body = await response.json();

    expect(response.status).toBe(403);
    expect(body.error).toBe(
      'Your account is not provisioned for this sign-in method. Contact your site or HQ admin.',
    );
  });

  it('rejects non-enterprise sign-in when the existing user profile has no role', async () => {
    const userSet = jest.fn();
    mockedGetAdminAuth.mockReturnValue({
      verifyIdToken: jest.fn().mockResolvedValue({
        uid: 'user-4',
        email: 'parent@scholesa.dev',
        name: 'Parent Four',
        firebase: {
          sign_in_provider: 'google.com',
        },
      }),
      createSessionCookie: jest.fn(),
    } as never);

    mockedGetAdminDb.mockReturnValue({
      collection: jest.fn((name: string) => {
        if (name === 'enterpriseSsoProviders') return buildQueryMock([]);
        if (name === 'users') {
          return {
            doc: jest.fn(() => ({
              get: jest.fn().mockResolvedValue({
                exists: true,
                data: () => ({
                  uid: 'user-4',
                  email: 'parent@scholesa.dev',
                  displayName: 'Parent Four',
                }),
              }),
              set: userSet,
            })),
          };
        }
        throw new Error(`Unexpected collection ${name}`);
      }),
    } as never);

    const response = await postSessionLogin(new Request('https://scholesa.test/api/auth/session-login', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ idToken: 'firebase-token' }),
    }));
    const body = await response.json();

    expect(response.status).toBe(403);
    expect(body.error).toBe(
      'Your account is not provisioned for this sign-in method. Contact your site or HQ admin.',
    );
    expect(userSet).not.toHaveBeenCalled();
  });
});