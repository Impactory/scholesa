jest.mock('firebase/firestore', () => ({
  doc: jest.fn((_collection, id: string) => ({ id })),
  getDoc: jest.fn(),
}));

jest.mock('@/src/firebase/firestore/collections', () => ({
  sessionsCollection: { id: 'sessions' },
  missionsCollection: { id: 'missions' },
  usersCollection: { id: 'users' },
  programsCollection: { id: 'programs' },
  coursesCollection: { id: 'courses' },
  sitesCollection: { id: 'sites' },
}));

import { getDoc } from 'firebase/firestore';
import {
  verifyMissionId,
  verifyProgramAndCourse,
  verifySessionId,
  verifySiteId,
  verifyUserId,
} from '@/invariants';

type MockSnapshot = {
  exists: () => boolean;
  data: () => Record<string, unknown> | undefined;
};

const mockedGetDoc = getDoc as jest.MockedFunction<typeof getDoc>;

function existingSnapshot(data?: Record<string, unknown>): MockSnapshot {
  return {
    exists: () => true,
    data: () => data,
  };
}

function missingSnapshot(): MockSnapshot {
  return {
    exists: () => false,
    data: () => undefined,
  };
}

describe('Invariant enforcement', () => {
  beforeEach(() => {
    mockedGetDoc.mockReset();
  });

  it('accepts existing session, mission, and site references', async () => {
    mockedGetDoc
      .mockResolvedValueOnce(existingSnapshot() as never)
      .mockResolvedValueOnce(existingSnapshot() as never)
      .mockResolvedValueOnce(existingSnapshot() as never);

    await expect(verifySessionId('session-1')).resolves.toBeUndefined();
    await expect(verifyMissionId('mission-1')).resolves.toBeUndefined();
    await expect(verifySiteId('site-1')).resolves.toBeUndefined();
  });

  it('rejects missing references with invariant errors', async () => {
    mockedGetDoc.mockResolvedValueOnce(missingSnapshot() as never);
    await expect(verifySessionId('missing-session')).rejects.toThrow(
      'Invariant Violation: Session missing-session does not exist.',
    );

    mockedGetDoc.mockResolvedValueOnce(missingSnapshot() as never);
    await expect(verifyMissionId('missing-mission')).rejects.toThrow(
      'Invariant Violation: Mission missing-mission does not exist.',
    );

    mockedGetDoc.mockResolvedValueOnce(missingSnapshot() as never);
    await expect(verifySiteId('missing-site')).rejects.toThrow(
      'Invariant Violation: Site missing-site does not exist.',
    );
  });

  it('enforces user role checks when requested', async () => {
    mockedGetDoc.mockResolvedValueOnce(existingSnapshot({ role: 'educator' }) as never);
    await expect(verifyUserId('user-1', 'educator')).resolves.toBeUndefined();

    mockedGetDoc.mockResolvedValueOnce(existingSnapshot({ role: 'parent' }) as never);
    await expect(verifyUserId('user-2', 'educator')).rejects.toThrow(
      'Invariant Violation: User user-2 is not a educator.',
    );
  });

  it('enforces program and course hierarchy', async () => {
    mockedGetDoc
      .mockResolvedValueOnce(existingSnapshot() as never)
      .mockResolvedValueOnce(existingSnapshot({ programId: 'program-1' }) as never);
    await expect(verifyProgramAndCourse('program-1', 'course-1')).resolves.toBeUndefined();

    mockedGetDoc
      .mockResolvedValueOnce(existingSnapshot() as never)
      .mockResolvedValueOnce(existingSnapshot({ programId: 'program-2' }) as never);
    await expect(verifyProgramAndCourse('program-1', 'course-1')).rejects.toThrow(
      'Invariant Violation: Course course-1 does not belong to Program program-1.',
    );
  });
});