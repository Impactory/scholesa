'use client';

/**
 * Learner Progress Report / Passport Renderer (S4-2)
 *
 * Wraps the existing LearnerPassportExport component into the
 * custom route renderer system. Renders on /learner/today to give
 * learners a capability-first view of their progress.
 */

import dynamic from 'next/dynamic';
import type { CustomRouteRendererProps } from '../customRouteRenderers';

const LearnerPassportExport = dynamic(
  () =>
    import('@/src/components/passport/LearnerPassportExport').then(
      (mod) => mod.LearnerPassportExport
    ),
  { loading: () => <div className="p-6 text-center text-gray-500">Loading progress report...</div> }
);

export default function LearnerProgressReportRenderer({ ctx }: CustomRouteRendererProps) {
  return (
    <div className="space-y-4">
      <div>
        <h2 className="text-xl font-bold text-gray-900">My Progress</h2>
        <p className="text-sm text-gray-500">
          Your capability growth, evidence, and learning passport.
        </p>
      </div>
      <LearnerPassportExport />
    </div>
  );
}
