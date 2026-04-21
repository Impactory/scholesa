'use client';

/**
 * HQ Capability Framework Renderer
 *
 * Full capability framework management for Admin-HQ:
 * - Tab 1 — Capabilities: CRUD with pillar mapping, progression descriptors, unit/checkpoint mappings
 * - Tab 2 — Rubric Templates: build scoring rubrics linked to capabilities
 * - Tab 3 — Process Domains: cross-cutting skill domains with progression descriptors
 *
 * Delegates entirely to CapabilityFrameworkEditor which owns the data layer.
 */

import { CapabilityFrameworkEditor } from '@/src/components/capabilities/CapabilityFrameworkEditor';
import { resolveActiveSiteId } from '@/src/lib/auth/activeSite';
import type { CustomRouteRendererProps } from '../customRouteRenderers';

export function HqCapabilityFrameworkRenderer({ ctx }: CustomRouteRendererProps) {
  return <CapabilityFrameworkEditor initialTab="capabilities" siteId={resolveActiveSiteId(ctx.profile)} />;
}

export default HqCapabilityFrameworkRenderer;
