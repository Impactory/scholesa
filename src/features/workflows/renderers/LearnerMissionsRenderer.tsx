'use client';

import { LearnerEvidenceSubmission } from '@/src/components/evidence/LearnerEvidenceSubmission';
import type { CustomRouteRendererProps } from '../customRouteRenderers';

export default function LearnerMissionsRenderer(_props: CustomRouteRendererProps) {
  return <LearnerEvidenceSubmission />;
}
