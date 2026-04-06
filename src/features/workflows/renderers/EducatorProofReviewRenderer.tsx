'use client';

import { ProofOfLearningVerification } from '@/src/components/evidence/ProofOfLearningVerification';
import type { CustomRouteRendererProps } from '../customRouteRenderers';

export default function EducatorProofReviewRenderer(_props: CustomRouteRendererProps) {
  return <ProofOfLearningVerification />;
}
