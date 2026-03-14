jest.mock('@/src/firebase/admin-init', () => ({
  getAdminAuth: jest.fn(),
  getAdminDb: jest.fn(),
}));

import { getAdminAuth, getAdminDb } from '@/src/firebase/admin-init';
import { GET } from '@/app/api/healthz/route';

const mockedGetAdminAuth = getAdminAuth as jest.MockedFunction<typeof getAdminAuth>;
const mockedGetAdminDb = getAdminDb as jest.MockedFunction<typeof getAdminDb>;

describe('GET /api/healthz', () => {
  beforeEach(() => {
    mockedGetAdminAuth.mockReset();
    mockedGetAdminDb.mockReset();
  });

  it('returns healthy service statuses when admin services initialize', async () => {
    mockedGetAdminAuth.mockReturnValue({} as never);
    mockedGetAdminDb.mockReturnValue({} as never);

    const response = await GET();
    const body = await response.json();

    expect(response.status).toBe(200);
    expect(body.ok).toBe(true);
    expect(body.services.auth).toBe('ok');
    expect(body.services.firestore).toBe('ok');
  });

  it('degrades service statuses when admin services are unavailable', async () => {
    mockedGetAdminAuth.mockImplementation(() => {
      throw new Error('Firebase Admin not initialized');
    });
    mockedGetAdminDb.mockImplementation(() => {
      throw new Error('Firebase Admin not initialized');
    });

    const response = await GET();
    const body = await response.json();

    expect(response.status).toBe(200);
    expect(body.ok).toBe(true);
    expect(body.services.auth).toBe('unconfigured');
    expect(body.services.firestore).toBe('unconfigured');
  });
});