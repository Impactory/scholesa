'use client';

/**
 * Guardian Passport Renderer
 *
 * Reuses the GuardianCapabilityViewRenderer which already renders the full
 * evidence-backed ideation passport via the getParentDashboardBundle callable.
 * Import the component directly rather than re-exporting to keep the lazy
 * boundary intact.
 */

import GuardianCapabilityViewRenderer from './GuardianCapabilityViewRenderer';
import type { CustomRouteRendererProps } from '../customRouteRenderers';

export default function GuardianPassportRenderer(props: CustomRouteRendererProps) {
  return <GuardianCapabilityViewRenderer {...props} />;
}
