import { NextRequest } from 'next/server';
import { proxy } from '@/proxy';
import { ALL_WORKFLOW_PATHS, ROLE_DEFAULT_WORKFLOW_ROUTE, WORKFLOW_ROUTE_DEFINITIONS } from '@/src/lib/routing/workflowRoutes';

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

  it('keeps the protected workflow inventory aligned to the current 62-path registry', () => {
    expect(ALL_WORKFLOW_PATHS).toHaveLength(62);
    expect(WORKFLOW_ROUTE_DEFINITIONS).toHaveLength(62);

    const counts = WORKFLOW_ROUTE_DEFINITIONS.reduce<Record<string, number>>((acc, route) => {
      const segment = route.path.split('/')[1] || 'common';
      acc[segment] = (acc[segment] ?? 0) + 1;
      return acc;
    }, {});

    expect(counts).toEqual({
      learner: 9,
      educator: 13,
      parent: 6,
      site: 11,
      partner: 5,
      hq: 14,
      messages: 1,
      notifications: 1,
      profile: 1,
      settings: 1,
    });
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

  it('includes the partner deliverables and integrations workflow routes', () => {
    expect(WORKFLOW_ROUTE_DEFINITIONS).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          path: '/partner/deliverables',
          allowedRoles: ['partner', 'hq'],
          dataMode: 'firestore',
        }),
        expect.objectContaining({
          path: '/partner/integrations',
          allowedRoles: ['partner', 'hq'],
          dataMode: 'firestore',
        }),
      ]),
    );
  });
});
