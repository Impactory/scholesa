jest.mock('@/src/firebase/client-init', () => ({
  auth: { app: 'test-auth' },
  createFederatedAuthProvider: jest.fn(),
  firestore: {},
}));

jest.mock('firebase/auth', () => ({
  onAuthStateChanged: jest.fn(),
  signInWithPopup: jest.fn(),
  signOut: jest.fn(),
}));

jest.mock('firebase/firestore', () => ({
  doc: jest.fn(),
  onSnapshot: jest.fn(),
}));

jest.mock('@/src/firebase/auth/sessionClient', () => ({
  clearSessionCookie: jest.fn(),
  syncSessionCookie: jest.fn(),
}));

import { finalizeFederatedSignInSession, performSignOutCleanup } from '@/src/firebase/auth/AuthProvider';

describe('AuthProvider failure-path helpers', () => {
  it('rolls back Firebase auth when session sync fails after federated sign-in', async () => {
    const syncError = new Error('session sync failed');
    const syncSessionCookieFn = jest.fn().mockRejectedValue(syncError);
    const firebaseSignOutFn = jest.fn().mockResolvedValue(undefined);

    await expect(finalizeFederatedSignInSession({ uid: 'user-1' } as never, {
      authInstance: { app: 'auth' } as never,
      locale: 'zh-CN',
      syncSessionCookieFn,
      firebaseSignOutFn,
    })).rejects.toBe(syncError);

    expect(syncSessionCookieFn).toHaveBeenCalledWith(expect.objectContaining({ uid: 'user-1' }), 'zh-CN');
    expect(firebaseSignOutFn).toHaveBeenCalledWith({ app: 'auth' });
  });

  it('logs rollback failures but preserves the original federated sign-in error', async () => {
    const syncError = new Error('session sync failed');
    const rollbackError = new Error('firebase sign-out failed');
    const logger = { error: jest.fn() };

    await expect(finalizeFederatedSignInSession({ uid: 'user-2' } as never, {
      syncSessionCookieFn: jest.fn().mockRejectedValue(syncError),
      firebaseSignOutFn: jest.fn().mockRejectedValue(rollbackError),
      logger,
    })).rejects.toBe(syncError);

    expect(logger.error).toHaveBeenCalledWith(
      'Failed to clear Firebase Auth state after federated session setup failure.',
      rollbackError,
    );
  });

  it('clears local auth state even when session cookie clearing and Firebase sign-out both fail', async () => {
    const clearError = new Error('session logout failed');
    const firebaseError = new Error('firebase sign-out failed');
    const logger = { error: jest.fn() };
    const onLocalStateCleared = jest.fn();

    await expect(performSignOutCleanup({
      clearSessionCookieFn: jest.fn().mockRejectedValue(clearError),
      firebaseSignOutFn: jest.fn().mockRejectedValue(firebaseError),
      logger,
      onLocalStateCleared,
    })).rejects.toBe(firebaseError);

    expect(logger.error).toHaveBeenNthCalledWith(1, 'Failed to clear session cookie before sign-out.', clearError);
    expect(logger.error).toHaveBeenNthCalledWith(2, 'Failed to sign out from Firebase auth.', firebaseError);
    expect(onLocalStateCleared).toHaveBeenCalledTimes(1);
  });

  it('continues Firebase sign-out when clearing the session cookie fails', async () => {
    const clearError = new Error('session logout failed');
    const logger = { error: jest.fn() };
    const firebaseSignOutFn = jest.fn().mockResolvedValue(undefined);
    const onLocalStateCleared = jest.fn();

    await expect(performSignOutCleanup({
      clearSessionCookieFn: jest.fn().mockRejectedValue(clearError),
      firebaseSignOutFn,
      logger,
      onLocalStateCleared,
    })).resolves.toBeUndefined();

    expect(firebaseSignOutFn).toHaveBeenCalledTimes(1);
    expect(onLocalStateCleared).toHaveBeenCalledTimes(1);
  });
});