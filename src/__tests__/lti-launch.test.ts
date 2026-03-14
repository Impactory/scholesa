jest.mock('@/src/firebase/admin-init', () => ({
  getAdminDb: jest.fn(),
}));

import { createPrivateKey, createPublicKey, createSign, generateKeyPairSync } from 'node:crypto';
import { getAdminDb } from '@/src/firebase/admin-init';
import { POST } from '@/app/api/lti/launch/route';

const mockedGetAdminDb = getAdminDb as jest.MockedFunction<typeof getAdminDb>;

function base64UrlEncode(input: Buffer | string): string {
  const buffer = Buffer.isBuffer(input) ? input : Buffer.from(input);
  return buffer.toString('base64url');
}

function buildSignedLtiToken(overrides: Record<string, unknown> = {}) {
  const { privateKey, publicKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
  const jwk = createPublicKey(publicKey).export({ format: 'jwk' }) as JsonWebKey;
  const header = { alg: 'RS256', typ: 'JWT', kid: 'test-kid' };
  const nowSeconds = Math.floor(Date.now() / 1000);
  const payload = {
    iss: 'https://canvas.example',
    aud: 'scholesa-lti-client',
    sub: 'learner-123',
    exp: nowSeconds + 600,
    iat: nowSeconds,
    'https://purl.imsglobal.org/spec/lti/claim/deployment_id': 'deployment-1',
    'https://purl.imsglobal.org/spec/lti/claim/message_type': 'LtiResourceLinkRequest',
    'https://purl.imsglobal.org/spec/lti/claim/version': '1.3.0',
    'https://purl.imsglobal.org/spec/lti/claim/resource_link': { id: 'resource-1' },
    'https://purl.imsglobal.org/spec/lti/claim/custom': {
      locale: 'zh-TW',
    },
    ...overrides,
  };

  const encodedHeader = base64UrlEncode(JSON.stringify(header));
  const encodedPayload = base64UrlEncode(JSON.stringify(payload));
  const signer = createSign('RSA-SHA256');
  signer.update(`${encodedHeader}.${encodedPayload}`);
  signer.end();
  const signature = signer.sign(createPrivateKey(privateKey));

  return {
    token: `${encodedHeader}.${encodedPayload}.${base64UrlEncode(signature)}`,
    jwk: {
      ...jwk,
      kid: 'test-kid',
      alg: 'RS256',
      use: 'sig',
    },
  };
}

function buildQueryMock(docs: Array<{ id: string; data: () => Record<string, unknown> }>) {
  const query = {
    where: jest.fn().mockReturnThis(),
    limit: jest.fn().mockReturnThis(),
    get: jest.fn().mockResolvedValue({ docs }),
  };

  return query;
}

describe('POST /api/lti/launch', () => {
  const fetchSpy = jest.spyOn(global, 'fetch');

  beforeEach(() => {
    mockedGetAdminDb.mockReset();
    fetchSpy.mockReset();
  });

  it('verifies the launch token and redirects with LTI context', async () => {
    const { token, jwk } = buildSignedLtiToken();
    const platformQuery = buildQueryMock([
      {
        id: 'registration-1',
        data: () => ({
          siteId: 'site-1',
          issuer: 'https://canvas.example',
          clientId: 'scholesa-lti-client',
          deploymentId: 'deployment-1',
          jwksUrl: 'https://canvas.example/jwks',
          status: 'active',
        }),
      },
    ]);
    const resourceQuery = buildQueryMock([
      {
        id: 'resource-doc-1',
        data: () => ({
          registrationId: 'registration-1',
          siteId: 'site-1',
          resourceLinkId: 'resource-1',
          missionId: 'mission-1',
          targetPath: '/zh-TW/learner?from=lti',
          lineItemId: 'line-item-1',
        }),
      },
    ]);
    const auditAdd = jest.fn().mockResolvedValue(undefined);
    mockedGetAdminDb.mockReturnValue({
      collection: jest.fn((name: string) => {
        if (name === 'ltiPlatformRegistrations') return platformQuery;
        if (name === 'ltiResourceLinks') return resourceQuery;
        if (name === 'auditLogs') return { add: auditAdd };
        throw new Error(`Unexpected collection ${name}`);
      }),
    } as never);
    fetchSpy.mockResolvedValue(new Response(JSON.stringify({ keys: [jwk] }), { status: 200 }) as never);

    const formData = new FormData();
    formData.set('id_token', token);

    const response = await POST(new Request('https://scholesa.test/api/lti/launch', {
      method: 'POST',
      body: formData,
    }));

    expect(response.status).toBe(302);
    expect(response.headers.get('location')).toContain('/zh-TW/learner?from=lti');
    expect(response.headers.get('location')).toContain('ltiRegistrationId=registration-1');
    expect(response.headers.get('location')).toContain('missionId=mission-1');
    expect(response.cookies.get('scholesa_locale')?.value).toBe('zh-TW');
    expect(auditAdd).toHaveBeenCalledTimes(1);
  });

  it('rejects invalid or expired LTI launches', async () => {
    const { token, jwk } = buildSignedLtiToken({ exp: Math.floor(Date.now() / 1000) - 60 });
    const platformQuery = buildQueryMock([
      {
        id: 'registration-1',
        data: () => ({
          siteId: 'site-1',
          issuer: 'https://canvas.example',
          clientId: 'scholesa-lti-client',
          deploymentId: 'deployment-1',
          jwksUrl: 'https://canvas.example/jwks',
          status: 'active',
        }),
      },
    ]);
    mockedGetAdminDb.mockReturnValue({
      collection: jest.fn((name: string) => {
        if (name === 'ltiPlatformRegistrations') return platformQuery;
        if (name === 'ltiResourceLinks') return buildQueryMock([]);
        if (name === 'auditLogs') return { add: jest.fn() };
        throw new Error(`Unexpected collection ${name}`);
      }),
    } as never);
    fetchSpy.mockResolvedValue(new Response(JSON.stringify({ keys: [jwk] }), { status: 200 }) as never);

    const formData = new FormData();
    formData.set('id_token', token);
    const response = await POST(new Request('https://scholesa.test/api/lti/launch', {
      method: 'POST',
      body: formData,
    }));
    const body = await response.json();

    expect(response.status).toBe(401);
    expect(body.error).toBe('Expired LTI launch token.');
  });
});