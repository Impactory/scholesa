/** @jest-environment jsdom */

import '@testing-library/jest-dom';
import React from 'react';
import { render, screen } from '@testing-library/react';
import EducatorAiAuditRenderer from '@/src/features/workflows/renderers/EducatorAiAuditRenderer';

const getDocsMock = jest.fn();
const collectionMock = jest.fn((_firestore, collectionName: string) => ({ collectionName }));
const limitMock = jest.fn((value: number) => ({ type: 'limit', value }));
const orderByMock = jest.fn((field: string, direction?: string) => ({
  type: 'orderBy',
  field,
  direction,
}));
const queryMock = jest.fn((ref: { collectionName: string }, ...constraints: unknown[]) => ({
  collectionName: ref.collectionName,
  constraints,
}));
const whereMock = jest.fn((field: string, op: string, value: unknown) => ({
  type: 'where',
  field,
  op,
  value,
}));
const mockTrackInteraction = jest.fn();

jest.mock('next/dynamic', () => ({
  __esModule: true,
  default: () => function MockEducatorFeedbackForm() {
    return <div>Mock educator feedback form</div>;
  },
}));

jest.mock('@/src/firebase/client-init', () => ({
  firestore: { app: 'test-firestore' },
}));

jest.mock('@/src/hooks/useTelemetry', () => ({
  useInteractionTracking: () => mockTrackInteraction,
}));

jest.mock('firebase/firestore', () => ({
  collection: (firestoreRef: unknown, collectionName: string) =>
    collectionMock(firestoreRef, collectionName),
  getDocs: (queryRef: unknown) => getDocsMock(queryRef),
  limit: (value: number) => limitMock(value),
  orderBy: (field: string, direction?: string) => orderByMock(field, direction),
  query: (ref: { collectionName: string }, ...constraints: unknown[]) =>
    queryMock(ref, ...constraints),
  where: (field: string, op: string, value: unknown) => whereMock(field, op, value),
}));

function makeDoc(id: string, data: Record<string, unknown>) {
  return {
    id,
    data: () => data,
  };
}

function makeSnap(docs: Array<ReturnType<typeof makeDoc>>) {
  return { docs };
}

describe('EducatorAiAuditRenderer MiloOS provenance', () => {
  beforeEach(() => {
    collectionMock.mockClear();
    getDocsMock.mockReset();
    limitMock.mockClear();
    orderByMock.mockClear();
    queryMock.mockClear();
    mockTrackInteraction.mockClear();
    whereMock.mockClear();

    getDocsMock.mockImplementation((queryRef: { collectionName: string }) => {
      if (queryRef.collectionName === 'users') {
        return Promise.resolve(makeSnap([
          makeDoc('learner-1', {
            displayName: 'Ari Learner',
            email: 'ari@example.test',
            stageId: 'explorers',
          }),
          makeDoc('learner-2', {
            displayName: 'Bao Learner',
            email: 'bao@example.test',
            stageId: 'builders',
          }),
        ]));
      }
      if (queryRef.collectionName === 'aiInteractionLogs') {
        return Promise.resolve(makeSnap([
          makeDoc('log-1', {
            learnerId: 'learner-1',
            taskType: 'hint_generation',
            policyMode: 'guided',
            safetyOutcome: 'allowed',
            wasHelpful: true,
            studentRevised: true,
            modelUsed: 'internal',
            createdAt: '2026-04-29T10:00:00.000Z',
          }),
        ]));
      }
      if (queryRef.collectionName === 'interactionEvents') {
        return Promise.resolve(makeSnap([
          makeDoc('opened-1', {
            siteId: 'site-1',
            actorId: 'learner-1',
            eventType: 'ai_help_opened',
            createdAt: '2026-04-29T10:01:00.000Z',
          }),
          makeDoc('opened-2', {
            siteId: 'site-1',
            actorId: 'learner-1',
            eventType: 'ai_help_opened',
            createdAt: '2026-04-29T10:02:00.000Z',
          }),
          makeDoc('used-1', {
            siteId: 'site-1',
            actorId: 'learner-1',
            eventType: 'ai_help_used',
            createdAt: '2026-04-29T10:03:00.000Z',
          }),
          makeDoc('explain-1', {
            siteId: 'site-1',
            actorId: 'learner-1',
            eventType: 'explain_it_back_submitted',
            createdAt: '2026-04-29T10:04:00.000Z',
          }),
          makeDoc('opened-3', {
            siteId: 'site-1',
            actorId: 'learner-2',
            eventType: 'ai_help_opened',
            createdAt: '2026-04-29T10:05:00.000Z',
          }),
        ]));
      }
      return Promise.resolve(makeSnap([]));
    });
  });

  it('renders per-learner MiloOS support and explain-back gaps without mastery claims', async () => {
    render(
      <EducatorAiAuditRenderer
        ctx={{
          routePath: '/educator/learners',
          locale: 'en',
          uid: 'educator-1',
          role: 'educator',
          profile: {
            role: 'educator',
            activeSiteId: 'site-1',
            siteIds: ['site-1'],
          } as never,
        }}
      />
    );

    const ariSupport = await screen.findByTestId('miloos-support-learner-1');
    expect(ariSupport).toHaveTextContent('MiloOS support provenance');
    expect(ariSupport).toHaveTextContent('Opened: 2');
    expect(ariSupport).toHaveTextContent('Used: 1');
    expect(ariSupport).toHaveTextContent('Explain-backs: 1');
    expect(ariSupport).toHaveTextContent('Pending: 1');
    expect(ariSupport).toHaveTextContent('support signals and verification gaps, not capability mastery');

    const baoSupport = await screen.findByTestId('miloos-support-learner-2');
    expect(baoSupport).toHaveTextContent('Opened: 1');
    expect(baoSupport).toHaveTextContent('Pending: 1');

    expect(collectionMock).toHaveBeenCalledWith(expect.anything(), 'interactionEvents');
    expect(whereMock).toHaveBeenCalledWith('siteId', '==', 'site-1');
  });
});
