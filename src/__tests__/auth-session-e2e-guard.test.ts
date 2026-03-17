jest.mock('server-only', () => ({}), { virtual: true });

jest.mock('next/headers', () => ({
  cookies: jest.fn(),
}));

jest.mock('@/src/firebase/admin-init', () => ({
  getAdminAuth: jest.fn(),
}));

import { cookies } from 'next/headers';
import { getAdminAuth } from '@/src/firebase/admin-init';
import { getCurrentUserServer } from '@/src/firebase/auth/getCurrentUserServer';

const mockedCookies = cookies as jest.MockedFunction<typeof cookies>;
const mockedGetAdminAuth = getAdminAuth as jest.MockedFunction<typeof getAdminAuth>;

describe('server auth E2E session guards', () => {
  const originalE2EMode = process.env.NEXT_PUBLIC_E2E_TEST_MODE;
  let consoleErrorSpy: jest.SpyInstance;

  beforeEach(() => {
    mockedCookies.mockReset();
    mockedGetAdminAuth.mockReset();
    delete process.env.NEXT_PUBLIC_E2E_TEST_MODE;
    consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation(() => {});
  });

  afterEach(() => {
    consoleErrorSpy.mockRestore();
  });

  afterAll(() => {
    if (originalE2EMode === undefined) {
      delete process.env.NEXT_PUBLIC_E2E_TEST_MODE;
    } else {
      process.env.NEXT_PUBLIC_E2E_TEST_MODE = originalE2EMode;
    }
  });

  it('does not accept E2E session cookies outside explicit E2E mode', async () => {
    mockedCookies.mockResolvedValue({
      get: jest.fn().mockReturnValue({
        value: 'e2e:eyJ1aWQiOiJmYWtlLXVzZXIiLCJlbWFpbCI6ImZha2VAc2Nob2xlc2EudGVzdCIsImRpc3BsYXlOYW1lIjoiRmFrZSBVc2VyIiwicm9sZSI6ImhxIn0',
      }),
    } as never);

    const verifySessionCookie = jest.fn().mockRejectedValue(new Error('invalid session'));
    mockedGetAdminAuth.mockReturnValue({
      verifySessionCookie,
      getUser: jest.fn(),
    } as never);

    await expect(getCurrentUserServer()).resolves.toBeNull();
    expect(verifySessionCookie).toHaveBeenCalledTimes(1);
  });

  it('accepts encoded E2E sessions only when explicit E2E mode is enabled', async () => {
    process.env.NEXT_PUBLIC_E2E_TEST_MODE = '1';
    mockedCookies.mockResolvedValue({
      get: jest.fn().mockReturnValue({
        value: 'e2e:eyJ1aWQiOiJlcTJlLXVzZXIiLCJlbWFpbCI6ImV4MkVAc2Nob2xlc2EudGVzdCIsImRpc3BsYXlOYW1lIjoiRTJFIFVzZXIiLCJyb2xlIjoic2l0ZSIsInNpdGVJZHMiOlsic2l0ZS1hbHBoYSJdLCJhY3RpdmVTaXRlSWQiOiJzaXRlLWFscGhhIn0',
      }),
    } as never);

    const user = await getCurrentUserServer();

    expect(user).toMatchObject({
      uid: 'eq2e-user',
      email: 'ex2E@scholesa.test',
      displayName: 'E2E User',
      customClaims: {
        role: 'site',
        siteIds: ['site-alpha'],
        activeSiteId: 'site-alpha',
      },
    });
    expect(mockedGetAdminAuth).not.toHaveBeenCalled();
  });
});