'use client';

import { useEffect, useMemo, useState } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { doc, getDoc } from 'firebase/firestore';
import { EducatorEvidenceCapture } from '@/src/components/evidence/EducatorEvidenceCapture';
import { RubricReviewPanel } from '@/src/components/evidence/RubricReviewPanel';
import { Spinner } from '@/src/components/ui/Spinner';
import { portfolioItemsCollection, usersCollection } from '@/src/firebase/firestore/collections';
import { resolveActiveSiteId } from '@/src/lib/auth/activeSite';
import type { PortfolioItem } from '@/src/types/schema';
import type { CustomRouteRendererProps } from '../customRouteRenderers';

type SelectedPortfolioItem = Pick<
  PortfolioItem,
  'id' | 'learnerId' | 'siteId' | 'title' | 'description' | 'evidenceRecordIds' | 'missionAttemptId' | 'capabilityIds'
> & {
  learnerName: string;
};

/**
 * Rubric application keeps the existing embedded evidence flow, but it can also
 * continue directly from proof verification on the same verified portfolio item.
 */
export default function EducatorRubricApplyRenderer({ ctx }: CustomRouteRendererProps) {
  const searchParams = useSearchParams();
  const router = useRouter();
  const activeSiteId = resolveActiveSiteId(ctx.profile);
  const portfolioItemId = searchParams?.get('portfolioItemId')?.trim() ?? '';
  const baseRubricHref = useMemo(
    () => `/${ctx.locale}/educator/rubrics/apply`,
    [ctx.locale]
  );
  const [selectedItem, setSelectedItem] = useState<SelectedPortfolioItem | null>(null);
  const [loading, setLoading] = useState(Boolean(portfolioItemId));
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!portfolioItemId) {
      setSelectedItem(null);
      setError(null);
      setLoading(false);
      return;
    }

    if (!activeSiteId) {
      setSelectedItem(null);
      setError('Select an active site before applying a rubric to verified proof.');
      setLoading(false);
      return;
    }

    let alive = true;

    void (async () => {
      setLoading(true);
      setError(null);
      try {
        const portfolioSnap = await getDoc(doc(portfolioItemsCollection, portfolioItemId));
        if (!portfolioSnap.exists()) {
          throw new Error('Verified portfolio item not found.');
        }

        const portfolioData = portfolioSnap.data();
        const rowSiteId = typeof portfolioData.siteId === 'string' ? portfolioData.siteId.trim() : '';
        if (rowSiteId && rowSiteId !== activeSiteId) {
          throw new Error('This verified portfolio item belongs to a different site.');
        }
        if (portfolioData.proofOfLearningStatus !== 'verified') {
          throw new Error('Only verified proof-of-learning items can enter direct rubric application.');
        }

        const learnerSnap = await getDoc(doc(usersCollection, portfolioData.learnerId));
        const learnerName = learnerSnap.exists()
          ? learnerSnap.data().displayName || portfolioData.learnerId
          : portfolioData.learnerId;

        if (!alive) {
          return;
        }

        setSelectedItem({
          id: portfolioSnap.id,
          learnerId: portfolioData.learnerId,
          learnerName,
          siteId: rowSiteId || activeSiteId,
          title: portfolioData.title,
          description: portfolioData.description,
          evidenceRecordIds: Array.isArray(portfolioData.evidenceRecordIds) ? portfolioData.evidenceRecordIds : [],
          missionAttemptId: typeof portfolioData.missionAttemptId === 'string' ? portfolioData.missionAttemptId : undefined,
          capabilityIds: Array.isArray(portfolioData.capabilityIds) ? portfolioData.capabilityIds : [],
        });
      } catch (loadError) {
        if (!alive) {
          return;
        }
        setSelectedItem(null);
        setError(loadError instanceof Error ? loadError.message : 'Unable to load the verified portfolio item.');
      } finally {
        if (alive) {
          setLoading(false);
        }
      }
    })();

    return () => {
      alive = false;
    };
  }, [activeSiteId, portfolioItemId]);

  if (!portfolioItemId) {
    return <EducatorEvidenceCapture />;
  }

  if (loading) {
    return (
      <div
        data-testid="educator-rubric-portfolio-loading"
        className="rounded-xl border border-slate-200 bg-white p-6 shadow-sm"
      >
        <div className="flex items-center gap-3 text-sm text-slate-600">
          <Spinner className="h-4 w-4" />
          Loading verified proof for rubric application...
        </div>
      </div>
    );
  }

  if (!activeSiteId || error || !selectedItem) {
    return (
      <div
        data-testid="educator-rubric-portfolio-blocked"
        className="rounded-xl border border-amber-200 bg-amber-50 p-6 shadow-sm"
      >
        <h2 className="text-lg font-semibold text-amber-950">Rubric handoff unavailable</h2>
        <p className="mt-2 text-sm text-amber-900">
          {error ?? 'Select an active site before continuing verified proof into rubric application.'}
        </p>
        <button
          type="button"
          onClick={() => router.replace(baseRubricHref)}
          className="mt-4 inline-flex rounded-md border border-amber-300 bg-white px-3 py-2 text-sm font-medium text-amber-950 hover:bg-amber-100"
        >
          Open general rubric flow
        </button>
      </div>
    );
  }

  return (
    <div
      data-testid="educator-rubric-portfolio-handoff"
      className="space-y-6"
    >
      <section className="rounded-xl border border-slate-200 bg-white p-6 shadow-sm">
        <div className="flex flex-wrap items-center gap-2">
          <span className="inline-flex rounded-full bg-emerald-100 px-2.5 py-1 text-xs font-semibold uppercase tracking-wide text-emerald-800">
            Verified proof
          </span>
          <span className="text-sm text-slate-600">Continuing rubric application on the same portfolio artifact.</span>
        </div>
        <h1 className="mt-3 text-2xl font-semibold text-slate-900">{selectedItem.title}</h1>
        <p className="mt-2 text-sm text-slate-600">
          Learner: {selectedItem.learnerName}
        </p>
        {selectedItem.description ? (
          <p className="mt-3 text-sm leading-6 text-slate-700">{selectedItem.description}</p>
        ) : null}
      </section>

      <RubricReviewPanel
        portfolioItemId={selectedItem.id}
        evidenceRecordIds={selectedItem.evidenceRecordIds ?? []}
        missionAttemptId={selectedItem.missionAttemptId}
        learnerId={selectedItem.learnerId}
        learnerName={selectedItem.learnerName}
        siteId={selectedItem.siteId ?? activeSiteId}
        description={selectedItem.description || selectedItem.title}
        capabilityId={selectedItem.capabilityIds?.[0]}
        proofVerified
        onComplete={() => router.replace(baseRubricHref)}
        onCancel={() => router.replace(baseRubricHref)}
      />
    </div>
  );
}
