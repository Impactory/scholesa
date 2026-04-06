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
const EducatorAiAuditRenderer = lazy(
  () => import('./renderers/EducatorAiAuditRenderer')
);
const EducatorTodayRenderer = lazy(
  () => import('./renderers/EducatorTodayRenderer')
);
const LearnerProofAssemblyRenderer = lazy(
  () => import('./renderers/LearnerProofAssemblyRenderer')
);
const LearnerProgressReportRenderer = lazy(
  () => import('./renderers/LearnerProgressReportRenderer')
);
const SiteImplementationHealthRenderer = lazy(
  () => import('./renderers/SiteImplementationHealthRenderer')
);
const EducatorEvidenceCaptureRenderer = lazy(
  () => import('./renderers/EducatorEvidenceCaptureRenderer')
);
const EducatorProofReviewRenderer = lazy(
  () => import('./renderers/EducatorProofReviewRenderer')
);
const EducatorRubricApplyRenderer = lazy(
  () => import('./renderers/EducatorRubricApplyRenderer')
);
const LearnerCheckpointRenderer = lazy(
  () => import('./renderers/LearnerCheckpointRenderer')
);
const LearnerReflectionsRenderer = lazy(
  () => import('./renderers/LearnerReflectionsRenderer')
);
const LearnerShowcasePeerReviewRenderer = lazy(
  () => import('./renderers/LearnerShowcasePeerReviewRenderer')
);
const HqRubricBuilderRenderer = lazy(
  () => import('./renderers/HqRubricBuilderRenderer')
);
const GuardianPassportRenderer = lazy(
  () => import('./renderers/GuardianPassportRenderer')
);
const LearnerMiloOSRenderer = lazy(
  () => import('./renderers/LearnerMiloOSRenderer')
);

const CUSTOM_ROUTE_RENDERERS: Partial<
  Record<WorkflowPath, ComponentType<CustomRouteRendererProps>>
> = {
  // HQ
  '/hq/curriculum': HqCapabilityFrameworkRenderer,
  '/hq/capabilities': HqCapabilityFrameworkRenderer,
  '/hq/capability-frameworks': HqCapabilityFrameworkRenderer,
  '/hq/rubric-builder': HqRubricBuilderRenderer,
  '/hq/analytics': HqCapabilityAnalyticsRenderer,
  // Educator
  '/educator/today': EducatorTodayRenderer,
  '/educator/missions/review': EducatorEvidenceReviewRenderer,
  '/educator/learners': EducatorAiAuditRenderer,
  '/educator/evidence': EducatorEvidenceCaptureRenderer,
  '/educator/observations': EducatorEvidenceCaptureRenderer,
  '/educator/proof-review': EducatorProofReviewRenderer,
  '/educator/verification': EducatorProofReviewRenderer,
  '/educator/rubrics/apply': EducatorRubricApplyRenderer,
  // Learner
  '/learner/today': LearnerProgressReportRenderer,
  '/learner/portfolio': LearnerPortfolioCurationRenderer,
  '/learner/missions': LearnerProofAssemblyRenderer,
  '/learner/proof-assembly': LearnerProofAssemblyRenderer,
  '/learner/checkpoints': LearnerCheckpointRenderer,
  '/learner/reflections': LearnerReflectionsRenderer,
  '/learner/peer-feedback': LearnerShowcasePeerReviewRenderer,
  '/learner/habits': LearnerMiloOSRenderer,
  // Parent / Guardian
  '/parent/summary': GuardianCapabilityViewRenderer,
  '/parent/portfolio': GuardianCapabilityViewRenderer,
  '/parent/growth-timeline': GuardianCapabilityViewRenderer,
  '/parent/passport': GuardianPassportRenderer,
  // Site
  '/site/dashboard': SiteImplementationHealthRenderer,
};

/**
 * Returns the custom renderer for a route, or null if it should use the generic renderer.
 */
export function getCustomRouteRenderer(
  routePath: WorkflowPath
): ComponentType<CustomRouteRendererProps> | null {
  return CUSTOM_ROUTE_RENDERERS[routePath] ?? null;
}
