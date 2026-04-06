'use client';

import { CapabilityFrameworkEditor } from '@/src/components/capabilities/CapabilityFrameworkEditor';
import type { CustomRouteRendererProps } from '../customRouteRenderers';

export default function HqRubricBuilderRenderer(_props: CustomRouteRendererProps) {
  return <CapabilityFrameworkEditor initialTab="rubricTemplates" />;
}
