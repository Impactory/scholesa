'use client';

import { WorkflowRoutePage } from '@/src/features/workflows/WorkflowRoutePage';
import { RubricReviewPanel } from '@/src/components/evidence/RubricReviewPanel';

export default function MissionReviewPage() {
  return (
    <WorkflowRoutePage
      routePath='/educator/missions/review'
      detailActionLabel='Apply Rubric'
      renderRecordDetail={(record, onClose) => (
        <RubricReviewPanel
          evidenceRecordIds={[]}
          missionAttemptId={record.id}
          learnerId={record.metadata.learnerId || ''}
          learnerName={record.metadata.learnerName || record.metadata.learnerId || 'Learner'}
          siteId={record.siteId || ''}
          description={record.title}
          capabilityId={
            record.metadata.capabilityIds
              ? record.metadata.capabilityIds.split(',')[0]?.trim()
              : undefined
          }
          onComplete={onClose}
          onCancel={onClose}
        />
      )}
    />
  );
}
