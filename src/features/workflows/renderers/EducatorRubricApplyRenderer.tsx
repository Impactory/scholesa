'use client';

import { EducatorEvidenceCapture } from '@/src/components/evidence/EducatorEvidenceCapture';
import type { CustomRouteRendererProps } from '../customRouteRenderers';

/**
 * Rubric application shares the evidence capture surface which embeds the
 * RubricReviewPanel for scoring evidence against rubric criteria.
 */
export default function EducatorRubricApplyRenderer(_props: CustomRouteRendererProps) {
  return <EducatorEvidenceCapture />;
}
