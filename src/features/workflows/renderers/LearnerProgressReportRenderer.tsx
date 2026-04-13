'use client';

/**
 * Learner Progress Report / Passport + MiloOS Coach Renderer (S4-2, S5-2)
 *
 * Combines the existing LearnerPassportExport with MiloOS
 * on /learner/today — giving learners their progress + intelligence surface.
 */

import { useCallback, useEffect, useState } from 'react';
import dynamic from 'next/dynamic';
import Link from 'next/link';
import { getDocs, query, where, limit } from 'firebase/firestore';
import { missionAttemptsCollection } from '@/src/firebase/firestore/collections';
import type { CustomRouteRendererProps } from '../customRouteRenderers';
import { BrainIcon, ChevronDownIcon, ChevronUpIcon, BarChart3Icon } from 'lucide-react';

const LearnerPassportExport = dynamic(
  () =>
    import('@/src/components/passport/LearnerPassportExport').then(
      (mod) => mod.LearnerPassportExport
    ),
  { loading: () => <div className="p-6 text-center text-gray-500">Loading progress report...</div> }
);

const AICoachScreen = dynamic(
  () =>
    import('@/src/components/sdt/AICoachScreen').then((mod) => mod.AICoachScreen),
  { loading: () => <div className="p-4 text-gray-500">Loading MiloOS...</div> }
);

export default function LearnerProgressReportRenderer({ ctx }: CustomRouteRendererProps) {
  const [showCoach, setShowCoach] = useState(false);
  const [revisionCount, setRevisionCount] = useState(0);
  const siteId = ctx.profile?.siteIds?.[0] || '';

  const checkRevisions = useCallback(async () => {
    if (!ctx.uid) return;
    try {
      const snap = await getDocs(
        query(
          missionAttemptsCollection,
          where('learnerId', '==', ctx.uid),
          where('status', '==', 'revision'),
          limit(20)
        )
      );
      setRevisionCount(snap.size);
    } catch {
      // non-critical — don't block the page
    }
  }, [ctx.uid]);

  useEffect(() => {
    void checkRevisions();
  }, [checkRevisions]);

  return (
    <div className="space-y-6">
      {/* Revision alert */}
      {revisionCount > 0 && (
        <Link
          href={`/${ctx.locale}/learner/portfolio`}
          className="flex items-center justify-between rounded-xl border border-amber-300 bg-amber-50 p-4 hover:bg-amber-100 transition-colors"
          data-testid="revision-alert"
        >
          <div className="flex items-center gap-3">
            <span className="flex h-8 w-8 items-center justify-center rounded-full bg-amber-200 text-sm font-bold text-amber-900">
              {revisionCount}
            </span>
            <div>
              <p className="text-sm font-semibold text-amber-900">
                {revisionCount === 1 ? 'Revision needed' : 'Revisions needed'}
              </p>
              <p className="text-xs text-amber-700">
                Your educator has asked you to revise and resubmit
              </p>
            </div>
          </div>
          <span className="text-sm font-medium text-amber-800">View &rarr;</span>
        </Link>
      )}

      {/* Progress section */}
      <div>
        <div className="flex items-center gap-2 mb-2">
          <BarChart3Icon className="h-5 w-5 text-indigo-600" />
          <h2 className="text-xl font-bold text-gray-900">My Progress</h2>
        </div>
        <p className="text-sm text-gray-500 mb-4">
          Your capability growth, evidence, and learning passport.
        </p>
        <LearnerPassportExport />
      </div>

      {/* MiloOS Coach toggle */}
      <div className="border border-indigo-200 rounded-lg overflow-hidden">
        <button
          onClick={() => setShowCoach(!showCoach)}
          className="w-full flex items-center justify-between p-4 bg-indigo-50 hover:bg-indigo-100 transition-colors"
        >
          <div className="flex items-center gap-2">
            <BrainIcon className="h-5 w-5 text-indigo-600" />
            <span className="font-medium text-indigo-900">MiloOS Coach</span>
            <span className="text-xs text-indigo-600">— Hints, rubric checks & debugging</span>
          </div>
          {showCoach ? (
            <ChevronUpIcon className="h-4 w-4 text-indigo-600" />
          ) : (
            <ChevronDownIcon className="h-4 w-4 text-indigo-600" />
          )}
        </button>
        {showCoach && (
          <div className="p-4 bg-white">
            <AICoachScreen learnerId={ctx.uid} siteId={siteId} />
          </div>
        )}
      </div>
    </div>
  );
}
