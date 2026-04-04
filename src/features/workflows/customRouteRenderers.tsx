'use client';

import type { ComponentType } from 'react';
import type { UserProfile, UserRole } from '@/src/types/user';
import type { WorkflowPath } from '@/src/lib/routing/workflowRoutes';

/**
 * Context provided to every custom route renderer.
 * Custom renderers replace the generic card-list UI for evidence chain routes.
 */
export interface CustomRouteContext {
  routePath: WorkflowPath;
  locale: string;
  uid: string;
  role: UserRole;
  profile: UserProfile | null;
}

/**
 * Props passed to a custom route renderer component.
 */
export interface CustomRouteRendererProps {
  ctx: CustomRouteContext;
}

/**
 * Registry mapping specific workflow paths to domain-specific renderer components.
 * Routes without a custom renderer fall back to the generic WorkflowRoutePage card list.
 */

import { lazy } from 'react';

const HqCapabilityFrameworkRenderer = lazy(
  () => import('./renderers/HqCapabilityFrameworkRenderer')
);
const EducatorEvidenceReviewRenderer = lazy(
  () => import('./renderers/EducatorEvidenceReviewRenderer')
);
const LearnerPortfolioCurationRenderer = lazy(
  () => import('./renderers/LearnerPortfolioCurationRenderer')
);
const GuardianCapabilityViewRenderer = lazy(
  () => import('./renderers/GuardianCapabilityViewRenderer')
);
const HqCapabilityAnalyticsRenderer = lazy(
  () => import('./renderers/HqCapabilityAnalyticsRenderer')
);

const CUSTOM_ROUTE_RENDERERS: Partial<
  Record<WorkflowPath, ComponentType<CustomRouteRendererProps>>
> = {
  '/hq/curriculum': HqCapabilityFrameworkRenderer,
  '/hq/analytics': HqCapabilityAnalyticsRenderer,
  '/educator/missions/review': EducatorEvidenceReviewRenderer,
  '/learner/portfolio': LearnerPortfolioCurationRenderer,
  '/parent/summary': GuardianCapabilityViewRenderer,
  '/parent/portfolio': GuardianCapabilityViewRenderer,
};

/**
 * Returns the custom renderer for a route, or null if it should use the generic renderer.
 */
export function getCustomRouteRenderer(
  routePath: WorkflowPath
): ComponentType<CustomRouteRendererProps> | null {
  return CUSTOM_ROUTE_RENDERERS[routePath] ?? null;
}
