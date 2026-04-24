'use client';

import { LearnerDashboardToday } from '@/src/components/dashboards/LearnerDashboardToday';
import type { CustomRouteRendererProps } from '../customRouteRenderers';

export default function LearnerTodayRenderer(_props: CustomRouteRendererProps) {
  return <LearnerDashboardToday />;
}