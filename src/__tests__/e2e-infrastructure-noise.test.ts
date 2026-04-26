const httpsCallableMock = jest.fn();

jest.mock('@/src/firebase/client-init', () => ({
  db: {},
  functions: {},
}));

jest.mock('firebase/functions', () => ({
  httpsCallable: (...args: unknown[]) => httpsCallableMock(...args),
}));

jest.mock('firebase/firestore', () => ({
  Timestamp: {
    now: jest.fn(() => ({
      toDate: () => new Date('2026-04-26T00:00:00.000Z'),
    })),
  },
  collection: jest.fn(),
  doc: jest.fn(),
  getDocs: jest.fn(),
  increment: jest.fn(),
  query: jest.fn(),
  serverTimestamp: jest.fn(),
  setDoc: jest.fn(),
  where: jest.fn(),
}));

import { TelemetryService } from '@/src/lib/telemetry/telemetryService';

describe('E2E infrastructure noise guards', () => {
  const originalE2EMode = process.env.NEXT_PUBLIC_E2E_TEST_MODE;

  beforeEach(() => {
    httpsCallableMock.mockReset();
    if (originalE2EMode === undefined) {
      delete process.env.NEXT_PUBLIC_E2E_TEST_MODE;
    } else {
      process.env.NEXT_PUBLIC_E2E_TEST_MODE = originalE2EMode;
    }
  });

  afterAll(() => {
    if (originalE2EMode === undefined) {
      delete process.env.NEXT_PUBLIC_E2E_TEST_MODE;
    } else {
      process.env.NEXT_PUBLIC_E2E_TEST_MODE = originalE2EMode;
    }
  });

  it('does not call Firebase telemetry functions in explicit E2E mode', async () => {
    process.env.NEXT_PUBLIC_E2E_TEST_MODE = '1';

    const id = await TelemetryService.track({
      event: 'feature_discovered',
      category: 'navigation',
      userId: 'learner-alpha',
      userRole: 'learner',
      siteId: 'site-alpha',
      metadata: { cta: 'mobile-evidence-qa' },
    });

    expect(id).toMatch(/^e2e-cta\.clicked-/);
    expect(httpsCallableMock).not.toHaveBeenCalled();
  });
});