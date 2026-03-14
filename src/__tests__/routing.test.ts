import { NextRequest } from 'next/server';
import { proxy } from '@/proxy';
import { ROLE_DEFAULT_WORKFLOW_ROUTE, WORKFLOW_ROUTE_DEFINITIONS } from '@/src/lib/routing/workflowRoutes';

describe('Routing contracts', () => {
  it('redirects locale aliases to canonical locales', () => {
    const request = new NextRequest('https://scholesa.test/es/login');
    const response = proxy(request);

    expect(response?.status).toBe(307);
    expect(response?.headers.get('location')).toBe('https://scholesa.test/en/login');
  });

  it('redirects unauthenticated protected routes to localized login', () => {
    const request = new NextRequest('https://scholesa.test/en/site/dashboard');
    const response = proxy(request);

    expect(response?.status).toBe(307);
    expect(response?.headers.get('location')).toBe(
      'https://scholesa.test/en/login?from=%2Fen%2Fsite%2Fdashboard',
    );
  });

  it('redirects authenticated auth routes to the dashboard shell', () => {
    const request = new NextRequest('https://scholesa.test/en/login', {
      headers: {
        cookie: '__session=test-session',
      },
    });
    const response = proxy(request);

    expect(response?.status).toBe(307);
    expect(response?.headers.get('location')).toBe('https://scholesa.test/en/dashboard');
  });

  it('keeps role defaults aligned to defined workflow routes', () => {
    const workflowPaths = new Set(WORKFLOW_ROUTE_DEFINITIONS.map((route) => route.path));

    for (const route of Object.values(ROLE_DEFAULT_WORKFLOW_ROUTE)) {
      expect(workflowPaths.has(`/${route}` as (typeof WORKFLOW_ROUTE_DEFINITIONS)[number]['path'])).toBe(true);
    }
  });

  it('includes the governed site Clever workflow route', () => {
    expect(WORKFLOW_ROUTE_DEFINITIONS).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          path: '/site/clever',
          allowedRoles: ['site', 'hq'],
          dataMode: 'hybrid',
        }),
      ]),
    );
  });
});