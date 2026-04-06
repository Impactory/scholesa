'use client';

import { LearnerEvidenceSubmission } from '@/src/components/evidence/LearnerEvidenceSubmission';
import type { CustomRouteRendererProps } from '../customRouteRenderers';

export default function LearnerCheckpointRenderer(_props: CustomRouteRendererProps) {
  return <LearnerEvidenceSubmission />;
}
