/** @jest-environment jsdom */

import '@testing-library/jest-dom';
import React from 'react';
import { fireEvent, render, screen, waitFor } from '@testing-library/react';

const httpsCallableMock = jest.fn();

jest.mock('@/src/firebase/client-init', () => ({
  firestore: { app: 'test-firestore' },
  functions: { app: 'test-functions' },
}));

jest.mock('firebase/functions', () => ({
  httpsCallable: (...args: unknown[]) => httpsCallableMock.apply(undefined, args),
}));

jest.mock('firebase/firestore', () => ({
  addDoc: jest.fn(),
  arrayRemove: jest.fn(),
  arrayUnion: jest.fn(),
  collection: jest.fn(),
  deleteDoc: jest.fn(),
  doc: jest.fn(),
  documentId: jest.fn(),
  getDoc: jest.fn(),
  getDocs: jest.fn(),
  increment: jest.fn(),
  limit: jest.fn(),
  orderBy: jest.fn(),
  query: jest.fn(),
  serverTimestamp: jest.fn(() => 'SERVER_TIMESTAMP'),
  setDoc: jest.fn(),
  updateDoc: jest.fn(),
  where: jest.fn(),
}));

jest.mock('next/link', () => ({
  __esModule: true,
  default: ({ children, href, ...props }: React.AnchorHTMLAttributes<HTMLAnchorElement> & { href: string }) => (
    <a href={href} {...props}>{children}</a>
  ),
}));

const replaceMock = jest.fn();

jest.mock('next/navigation', () => ({
  useParams: () => ({ locale: 'en' }),
  useRouter: () => ({ replace: replaceMock }),
}));

jest.mock('@/src/firebase/auth/AuthProvider', () => ({
  useAuthContext: () => ({
    user: { uid: 'hq-user-1' },
    profile: {
      role: 'hq',
      activeSiteId: 'site-1',
      siteIds: ['site-1'],
      displayName: 'HQ User',
    },
    loading: false,
  }),
}));

const trackInteractionMock = jest.fn();

jest.mock('@/src/hooks/useTelemetry', () => ({
  useInteractionTracking: () => trackInteractionMock,
  usePageViewTracking: jest.fn(),
}));

jest.mock('@/src/lib/i18n/useI18n', () => ({
  useI18n: () => ({
    locale: 'en',
    t: (key: string) => key,
  }),
}));

import { WorkflowRoutePage } from '@/src/features/workflows/WorkflowRoutePage';

type CallableHandler = jest.Mock<Promise<{ data: Record<string, unknown> }>, [Record<string, unknown>?]>;

const callableHandlers = new Map<string, CallableHandler>();

function setCallableHandler(name: string, handler?: CallableHandler) {
  if (handler) {
    callableHandlers.set(name, handler);
    return handler;
  }
  const fallback = jest.fn().mockResolvedValue({ data: {} }) as CallableHandler;
  callableHandlers.set(name, fallback);
  return fallback;
}

describe('WorkflowRoutePage feature flags', () => {
  beforeEach(() => {
    replaceMock.mockReset();
    trackInteractionMock.mockReset();
    callableHandlers.clear();
    httpsCallableMock.mockReset();
    httpsCallableMock.mockImplementation((_functions: unknown, name: string) => {
      const handler = callableHandlers.get(name);
      return handler || jest.fn().mockResolvedValue({ data: {} });
    });
  });

  it('renders canonical ai_help_loop labels and submits canonical feature flag names', async () => {
    const listFeatureFlags = setCallableHandler('listFeatureFlags', jest.fn().mockResolvedValue({
      data: {
        flags: [{
          id: 'flag-1',
          name: 'miloos_loop',
          description: 'Enable spoken AI help loop runtime',
          enabled: true,
          status: 'enabled',
          scope: 'global',
        }],
      },
    }) as CallableHandler);
    const upsertFeatureFlag = setCallableHandler('upsertFeatureFlag');

    render(<WorkflowRoutePage routePath="/hq/feature-flags" />);

    expect(await screen.findByText('HQ Feature Flags')).toBeInTheDocument();
    expect(await screen.findByText('ai_help_loop')).toBeInTheDocument();
    expect(screen.getByText('Enable spoken AI help loop runtime')).toBeInTheDocument();
    expect(screen.getByText('Status: enabled')).toBeInTheDocument();

    fireEvent.click(screen.getByTestId('workflow-create-toggle'));

    const nameInput = await screen.findByTestId('workflow-field-name');
    const descriptionInput = await screen.findByTestId('workflow-field-description');
    fireEvent.change(nameInput, { target: { value: 'miloos_loop' } });
    fireEvent.change(descriptionInput, { target: { value: 'Enable spoken AI help loop runtime' } });
    fireEvent.click(screen.getByTestId('workflow-create-submit'));

    await waitFor(() => {
      expect(upsertFeatureFlag).toHaveBeenCalledWith(expect.objectContaining({
        name: 'ai_help_loop',
        description: 'Enable spoken AI help loop runtime',
        enabled: false,
      }));
    });

    expect(listFeatureFlags).toHaveBeenCalled();
  });
});