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
import type { CustomRouteRendererProps } from '../customRouteRenderers';

export function HqCapabilityFrameworkRenderer(_props: CustomRouteRendererProps) {
  return <CapabilityFrameworkEditor initialTab="capabilities" />;
}

export default HqCapabilityFrameworkRenderer;
