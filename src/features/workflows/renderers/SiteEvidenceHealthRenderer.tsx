'use client';

import { SiteEvidenceHealthDashboard } from '@/src/components/analytics/SiteEvidenceHealthDashboard';
import type { CustomRouteRendererProps } from '../customRouteRenderers';

export default function SiteEvidenceHealthRenderer(_props: CustomRouteRendererProps) {
  return <SiteEvidenceHealthDashboard />;
}
