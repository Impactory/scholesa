'use client';

import { CapabilityFrameworkEditor } from '@/src/components/capabilities/CapabilityFrameworkEditor';
import { resolveActiveSiteId } from '@/src/lib/auth/activeSite';
import type { CustomRouteRendererProps } from '../customRouteRenderers';

export default function HqRubricBuilderRenderer({ ctx }: CustomRouteRendererProps) {
  return <CapabilityFrameworkEditor initialTab="rubricTemplates" siteId={resolveActiveSiteId(ctx.profile)} />;
}
