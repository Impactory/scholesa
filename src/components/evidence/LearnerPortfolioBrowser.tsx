'use client';

import { useCallback, useEffect, useMemo, useState } from 'react';
import { getDocs, orderBy, query, where } from 'firebase/firestore';
import { useAuthContext } from '@/src/firebase/auth/AuthProvider';
import { portfolioItemsCollection } from '@/src/firebase/firestore/collections';
import { useCapabilities } from '@/src/lib/capabilities/useCapabilities';
import { getLegacyPillarFamilyLabel } from '@/src/lib/curriculum/architecture';
import { Spinner } from '@/src/components/ui/Spinner';
import type { PortfolioItem, PillarCode } from '@/src/types/schema';

const LEGACY_FAMILY_LABELS: Record<PillarCode, string> = {
  FUTURE_SKILLS: getLegacyPillarFamilyLabel('FUTURE_SKILLS'),
  LEADERSHIP_AGENCY: getLegacyPillarFamilyLabel('LEADERSHIP_AGENCY'),
  IMPACT_INNOVATION: getLegacyPillarFamilyLabel('IMPACT_INNOVATION'),
};

type FilterVerification = 'all' | 'pending' | 'reviewed' | 'verified';
type FilterSource = 'all' | 'artifact' | 'reflection' | 'checkpoint';

export function LearnerPortfolioBrowser() {
  const { user, profile, loading: authLoading } = useAuthContext();
  const siteId = profile?.studioId ?? null;
  const learnerId = user?.uid ?? null;
  const { resolveTitle, loading: capLoading } = useCapabilities(siteId);

  const [items, setItems] = useState<PortfolioItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [filterVerification, setFilterVerification] = useState<FilterVerification>('all');
  const [filterSource, setFilterSource] = useState<FilterSource>('all');
  const [filterPillar, setFilterPillar] = useState<PillarCode | 'all'>('all');

  const loadItems = useCallback(async () => {
    if (!learnerId) return;
    setLoading(true);
    try {
      const snap = await getDocs(
        query(
          portfolioItemsCollection,
          where('learnerId', '==', learnerId),
          orderBy('createdAt', 'desc')
        )
      );
      setItems(snap.docs.map((d) => ({ ...d.data(), id: d.id })));
    } catch (err) {
      console.error('Failed to load portfolio', err);
      alert('Failed to load data. Please try again.');
    } finally {
      setLoading(false);
    }
  }, [learnerId]);

  useEffect(() => {
    if (learnerId) void loadItems();
  }, [learnerId, loadItems]);

  const filtered = useMemo(() => {
    let result = items;
    if (filterVerification !== 'all') {
      result = result.filter((i) => (i.verificationStatus ?? 'pending') === filterVerification);
    }
    if (filterSource !== 'all') {
      result = result.filter((i) => (i.source ?? 'artifact') === filterSource);
    }
    if (filterPillar !== 'all') {
      result = result.filter((i) => i.pillarCodes?.includes(filterPillar));
    }
    return result;
  }, [items, filterVerification, filterSource, filterPillar]);

  if (authLoading || capLoading) {
    return (
      <div className="flex items-center gap-2 text-app-muted py-8 justify-center">
        <Spinner />
        <span className="text-sm">Loading portfolio...</span>
      </div>
    );
  }

  return (
    <div className="space-y-4" data-testid="portfolio-browser">
      <div className="flex items-center justify-between">
        <h2 className="text-lg font-bold text-app-foreground">My Portfolio</h2>
        <span className="text-xs text-app-muted">
          {filtered.length} of {items.length} item{items.length !== 1 ? 's' : ''}
        </span>
      </div>

      {/* Filters */}
      <div className="flex flex-wrap gap-2">
        <select
          aria-label="Filter by type"
          value={filterSource}
          onChange={(e) => setFilterSource(e.target.value as FilterSource)}
          className="rounded-md border border-app bg-app-surface px-2 py-1 text-xs"
        >
          <option value="all">All types</option>
          <option value="artifact">Artifacts</option>
          <option value="reflection">Reflections</option>
          <option value="checkpoint">Checkpoints</option>
        </select>
        <select
          aria-label="Filter by verification"
          value={filterVerification}
          onChange={(e) => setFilterVerification(e.target.value as FilterVerification)}
          className="rounded-md border border-app bg-app-surface px-2 py-1 text-xs"
        >
          <option value="all">All status</option>
          <option value="pending">Pending review</option>
          <option value="reviewed">Reviewed</option>
          <option value="verified">Verified</option>
        </select>
        <select
          aria-label="Filter by legacy family"
          value={filterPillar}
          onChange={(e) => setFilterPillar(e.target.value as typeof filterPillar)}
          className="rounded-md border border-app bg-app-surface px-2 py-1 text-xs"
        >
          <option value="all">All legacy families</option>
          {(Object.entries(LEGACY_FAMILY_LABELS) as [PillarCode, string][]).map(([code, label]) => (
            <option key={code} value={code}>{label}</option>
          ))}
        </select>
      </div>

      {/* Items */}
      {loading ? (
        <div className="flex items-center gap-2 text-app-muted py-8 justify-center">
          <Spinner />
          <span className="text-sm">Loading...</span>
        </div>
      ) : filtered.length === 0 ? (
        <div className="py-10 text-center text-sm text-app-muted">
          {items.length === 0
            ? 'No portfolio items yet. Submit an artifact or reflection to get started!'
            : 'No items match the current filters.'}
        </div>
      ) : (
        <ul className="space-y-3">
          {filtered.map((item) => (
            <li
              key={item.id}
              className="rounded-lg border border-app bg-app-canvas p-4 text-sm"
            >
              <div className="flex items-start justify-between gap-2">
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2">
                    <span className="font-medium text-app-foreground">{item.title}</span>
                    {item.source && (
                      <span className="rounded bg-gray-100 px-1.5 py-0.5 text-[10px] font-medium text-gray-600 uppercase">
                        {item.source}
                      </span>
                    )}
                  </div>
                  {item.description && (
                    <p className="mt-1 text-app-muted line-clamp-3">{item.description}</p>
                  )}
                </div>
                <div className="flex flex-col gap-1 shrink-0 items-end">
                  {statusBadge(item.verificationStatus)}
                  {polBadge(item.proofOfLearningStatus)}
                </div>
              </div>

              {/* Capabilities */}
              {(item.capabilityIds?.length ?? 0) > 0 && (
                <div className="mt-2 flex flex-wrap gap-1.5">
                  {item.capabilityIds!.map((cid) => (
                    <span
                      key={cid}
                      className="rounded bg-app-surface px-1.5 py-0.5 text-xs text-app-muted"
                    >
                      {resolveTitle(cid)}
                    </span>
                  ))}
                </div>
              )}

              {/* Metadata row */}
              <div className="mt-2 flex flex-wrap gap-2 text-xs text-app-muted">
                {(item.artifacts?.length ?? 0) > 0 && (
                  <span className="rounded bg-blue-50 text-blue-700 px-1.5 py-0.5">
                    {item.artifacts.length} file{item.artifacts.length !== 1 ? 's' : ''}
                  </span>
                )}
                {item.aiAssistanceUsed && (
                  <span className="rounded bg-purple-50 text-purple-700 px-1.5 py-0.5">
                    AI assisted
                  </span>
                )}
                {item.growthEventIds && item.growthEventIds.length > 0 && (
                  <span className="rounded bg-emerald-50 text-emerald-700 px-1.5 py-0.5">
                    Linked to growth
                  </span>
                )}
                {item.proofBundleId && (
                  <span className="rounded bg-indigo-50 text-indigo-700 px-1.5 py-0.5">
                    Proof bundle
                  </span>
                )}
              </div>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

function statusBadge(status?: string) {
  if (!status || status === 'pending')
    return <span className="rounded bg-yellow-100 px-1.5 py-0.5 text-xs font-medium text-yellow-800">Pending review</span>;
  if (status === 'reviewed')
    return <span className="rounded bg-blue-100 px-1.5 py-0.5 text-xs font-medium text-blue-800">Reviewed</span>;
  if (status === 'verified')
    return <span className="rounded bg-green-100 px-1.5 py-0.5 text-xs font-medium text-green-800">Verified</span>;
  return <span className="rounded bg-gray-100 px-1.5 py-0.5 text-xs font-medium text-gray-700">{status}</span>;
}

function polBadge(status?: string) {
  if (!status || status === 'not-available') return null;
  if (status === 'verified')
    return <span className="rounded bg-green-100 px-1.5 py-0.5 text-xs font-medium text-green-800">PoL verified</span>;
  if (status === 'partial')
    return <span className="rounded bg-amber-100 px-1.5 py-0.5 text-xs font-medium text-amber-800">PoL partial</span>;
  if (status === 'missing')
    return <span className="rounded bg-red-100 px-1.5 py-0.5 text-xs font-medium text-red-800">PoL needed</span>;
  return null;
}
