'use client';

/**
 * Learner Proof-of-Learning Assembly Renderer (S2-3)
 *
 * Allows learners to assemble proof bundles for their portfolio items.
 * Three verification methods: ExplainItBack, OralCheck, MiniRebuild.
 * Proof status: missing → partial → verified (once educator signs off).
 */

import React, { useEffect, useState, useCallback } from 'react';
import {
  getDocs,
  query,
  where,
  addDoc,
  updateDoc,
  doc,
  serverTimestamp,
  Timestamp,
} from 'firebase/firestore';
import { db } from '@/src/firebase/client-init';
import {
  portfolioItemsCollection,
  proofOfLearningBundlesCollection,
} from '@/src/firebase/firestore/collections';
import type { CustomRouteRendererProps } from '../customRouteRenderers';
import type { PortfolioItem, ProofOfLearningBundle } from '@/src/types/schema';
import {
  ShieldCheckIcon,
  FileTextIcon,
  MicIcon,
  HammerIcon,
  ChevronDownIcon,
  ChevronUpIcon,
  CheckCircleIcon,
  AlertCircleIcon,
  ClockIcon,
} from 'lucide-react';
import { resolveActiveSiteId } from '@/src/lib/auth/activeSite';

interface PortfolioItemSummary {
  id: string;
  title: string;
  type: string;
  createdAt: Timestamp | null;
  proofBundleId?: string;
  proofOfLearningStatus?: 'not-available' | 'missing' | 'partial' | 'pending_review' | 'verified';
  proofHasExplainItBack?: boolean;
  proofHasOralCheck?: boolean;
  proofHasMiniRebuild?: boolean;
  proofExplainItBackExcerpt?: string;
  proofOralCheckExcerpt?: string;
  proofMiniRebuildExcerpt?: string;
}

interface ProofBundle {
  id: string;
  portfolioItemId: string;
  capabilityId?: string;
  hasExplainItBack: boolean;
  hasOralCheck: boolean;
  hasMiniRebuild: boolean;
  explainItBackExcerpt?: string;
  oralCheckExcerpt?: string;
  miniRebuildExcerpt?: string;
  verificationStatus: 'missing' | 'partial' | 'pending_review' | 'verified';
  educatorVerifierId?: string;
  version: number;
}

function statusBadge(status: string) {
  switch (status) {
    case 'verified':
      return (
        <span className="inline-flex items-center gap-1 text-xs font-medium px-2 py-0.5 rounded-full bg-green-100 text-green-800">
          <CheckCircleIcon className="h-3 w-3" /> Verified by educator
        </span>
      );
    case 'pending_review':
      return (
        <span className="inline-flex items-center gap-1 text-xs font-medium px-2 py-0.5 rounded-full bg-blue-100 text-blue-800">
          <ClockIcon className="h-3 w-3" /> Ready for review
        </span>
      );
    case 'partial':
      return (
        <span className="inline-flex items-center gap-1 text-xs font-medium px-2 py-0.5 rounded-full bg-amber-100 text-amber-800">
          <ClockIcon className="h-3 w-3" /> Partial
        </span>
      );
    default:
      return (
        <span className="inline-flex items-center gap-1 text-xs font-medium px-2 py-0.5 rounded-full bg-gray-100 text-gray-600">
          <AlertCircleIcon className="h-3 w-3" /> Missing
        </span>
      );
  }
}

function computeVerificationStatus(
  hasExplainItBack: boolean,
  hasOralCheck: boolean,
  hasMiniRebuild: boolean
): 'missing' | 'partial' | 'pending_review' {
  const count = [hasExplainItBack, hasOralCheck, hasMiniRebuild].filter(Boolean).length;
  // Learner assembly can reach 'pending_review' when all 3 methods are present.
  // Only an educator (via verifyProofOfLearning callable) can set 'verified'.
  if (count === 3) return 'pending_review';
  if (count > 0) return 'partial';
  return 'missing';
}

function portfolioProofFallback(
  item: PortfolioItemSummary | undefined
): ProofBundle | null {
  if (!item) return null;
  const hasExplainItBack = item.proofHasExplainItBack === true;
  const hasOralCheck = item.proofHasOralCheck === true;
  const hasMiniRebuild = item.proofHasMiniRebuild === true;
  const explainItBackExcerpt = item.proofExplainItBackExcerpt?.trim() || undefined;
  const oralCheckExcerpt = item.proofOralCheckExcerpt?.trim() || undefined;
  const miniRebuildExcerpt = item.proofMiniRebuildExcerpt?.trim() || undefined;
  const proofOfLearningStatus = item.proofOfLearningStatus;

  if (
    !proofOfLearningStatus &&
    !hasExplainItBack &&
    !hasOralCheck &&
    !hasMiniRebuild &&
    !explainItBackExcerpt &&
    !oralCheckExcerpt &&
    !miniRebuildExcerpt
  ) {
    return null;
  }

  return {
    id: item.proofBundleId ?? `portfolio-${item.id}`,
    portfolioItemId: item.id,
    hasExplainItBack,
    hasOralCheck,
    hasMiniRebuild,
    explainItBackExcerpt,
    oralCheckExcerpt,
    miniRebuildExcerpt,
    verificationStatus:
      proofOfLearningStatus === 'verified'
        ? 'verified'
        : proofOfLearningStatus === 'partial'
          ? 'partial'
          : 'missing',
    version: 1,
  };
}

export default function LearnerProofAssemblyRenderer({ ctx }: CustomRouteRendererProps) {
  const learnerId = ctx.uid;
  const siteId = resolveActiveSiteId(ctx.profile);
  const [portfolioItems, setPortfolioItems] = useState<PortfolioItemSummary[]>([]);
  const [bundles, setBundles] = useState<Map<string, ProofBundle>>(new Map());
  const [loading, setLoading] = useState(true);
  const [expandedItem, setExpandedItem] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Draft state for the currently expanded proof form
  const [draftExplainItBack, setDraftExplainItBack] = useState('');
  const [draftOralCheck, setDraftOralCheck] = useState('');
  const [draftMiniRebuild, setDraftMiniRebuild] = useState('');

  const loadData = useCallback(async () => {
    if (!learnerId || !siteId) {
      setPortfolioItems([]);
      setBundles(new Map());
      setLoading(false);
      setError(null);
      return;
    }
    setLoading(true);
    setError(null);
    try {
      if (process.env.NEXT_PUBLIC_E2E_TEST_MODE === '1') {
        const { getE2ECollection } = await import('@/src/testing/e2e/fakeWebBackend');
        const items = getE2ECollection('portfolioItems')
          .filter((record) => record.learnerId === learnerId && record.siteId === siteId)
          .map((record) => ({
            id: String(record.id),
            title: typeof record.title === 'string' ? record.title : 'Untitled',
            type: typeof record.type === 'string'
              ? record.type
              : typeof record.mediaType === 'string'
                ? record.mediaType
                : 'artifact',
            createdAt: null,
            proofBundleId: typeof record.proofBundleId === 'string' ? record.proofBundleId : undefined,
            proofOfLearningStatus: record.proofOfLearningStatus as PortfolioItemSummary['proofOfLearningStatus'],
            proofHasExplainItBack: record.proofHasExplainItBack === true,
            proofHasOralCheck: record.proofHasOralCheck === true,
            proofHasMiniRebuild: record.proofHasMiniRebuild === true,
            proofExplainItBackExcerpt: typeof record.proofExplainItBackExcerpt === 'string'
              ? record.proofExplainItBackExcerpt
              : undefined,
            proofOralCheckExcerpt: typeof record.proofOralCheckExcerpt === 'string'
              ? record.proofOralCheckExcerpt
              : undefined,
            proofMiniRebuildExcerpt: typeof record.proofMiniRebuildExcerpt === 'string'
              ? record.proofMiniRebuildExcerpt
              : undefined,
          }));
        setPortfolioItems(items);
        const sitePortfolioItemIds = new Set(items.map((item) => item.id));
        const bundleMap = new Map<string, ProofBundle>();
        getE2ECollection('proofOfLearningBundles').forEach((record) => {
          const portfolioItemId = typeof record.portfolioItemId === 'string'
            ? record.portfolioItemId
            : '';
          if (!sitePortfolioItemIds.has(portfolioItemId) || record.learnerId !== learnerId) return;
          if (typeof record.siteId === 'string' && record.siteId.trim() !== siteId) return;
          bundleMap.set(portfolioItemId, {
            id: String(record.id),
            portfolioItemId,
            capabilityId: typeof record.capabilityId === 'string' ? record.capabilityId : undefined,
            hasExplainItBack: record.hasExplainItBack === true,
            hasOralCheck: record.hasOralCheck === true,
            hasMiniRebuild: record.hasMiniRebuild === true,
            explainItBackExcerpt: typeof record.explainItBackExcerpt === 'string'
              ? record.explainItBackExcerpt
              : undefined,
            oralCheckExcerpt: typeof record.oralCheckExcerpt === 'string'
              ? record.oralCheckExcerpt
              : undefined,
            miniRebuildExcerpt: typeof record.miniRebuildExcerpt === 'string'
              ? record.miniRebuildExcerpt
              : undefined,
            verificationStatus: (record.verificationStatus as ProofBundle['verificationStatus']) || 'missing',
            educatorVerifierId: typeof record.educatorVerifierId === 'string'
              ? record.educatorVerifierId
              : undefined,
            version: typeof record.version === 'number' ? record.version : 1,
          });
        });
        setBundles(bundleMap);
        return;
      }

      // Load portfolio items
      const piQuery = query(
        portfolioItemsCollection,
        where('learnerId', '==', learnerId),
        where('siteId', '==', siteId)
      );
      const piSnap = await getDocs(piQuery);
      const items: PortfolioItemSummary[] = piSnap.docs.map((d) => {
        const data = d.data() as Partial<PortfolioItem> & { type?: string };
        return {
          id: d.id,
          title: data.title || 'Untitled',
          type: data.type || 'artifact',
          createdAt: (data.createdAt as Timestamp | null | undefined) ?? null,
          proofBundleId: data.proofBundleId,
          proofOfLearningStatus: data.proofOfLearningStatus,
          proofHasExplainItBack: data.proofHasExplainItBack === true,
          proofHasOralCheck: data.proofHasOralCheck === true,
          proofHasMiniRebuild: data.proofHasMiniRebuild === true,
          proofExplainItBackExcerpt: data.proofExplainItBackExcerpt,
          proofOralCheckExcerpt: data.proofOralCheckExcerpt,
          proofMiniRebuildExcerpt: data.proofMiniRebuildExcerpt,
        };
      });
      setPortfolioItems(items);
      const sitePortfolioItemIds = new Set(items.map((item) => item.id));

      // Load proof bundles for this learner
      const pbQuery = query(
        proofOfLearningBundlesCollection,
        where('learnerId', '==', learnerId)
      );
      const pbSnap = await getDocs(pbQuery);
      const bundleMap = new Map<string, ProofBundle>();
      pbSnap.docs.forEach((d) => {
        const data = d.data() as ProofOfLearningBundle;
        if (!sitePortfolioItemIds.has(data.portfolioItemId)) {
          return;
        }
        if (typeof data.siteId === 'string' && data.siteId.trim() && data.siteId.trim() !== siteId) {
          return;
        }
        bundleMap.set(data.portfolioItemId, {
          id: d.id,
          portfolioItemId: data.portfolioItemId,
          capabilityId: data.capabilityId,
          hasExplainItBack: data.hasExplainItBack || false,
          hasOralCheck: data.hasOralCheck || false,
          hasMiniRebuild: data.hasMiniRebuild || false,
          explainItBackExcerpt: data.explainItBackExcerpt,
          oralCheckExcerpt: data.oralCheckExcerpt,
          miniRebuildExcerpt: data.miniRebuildExcerpt,
          verificationStatus: data.verificationStatus || 'missing',
          educatorVerifierId: data.educatorVerifierId,
          version: data.version || 1,
        });
      });
      setBundles(bundleMap);
    } catch (err) {
      console.error('Failed to load proof assembly data:', err);
      setError('Failed to load data. Please try again.');
    } finally {
      setLoading(false);
    }
  }, [learnerId, siteId]);

  useEffect(() => {
    void loadData();
  }, [loadData]);

  const handleExpand = (itemId: string) => {
    if (expandedItem === itemId) {
      setExpandedItem(null);
      return;
    }
    setExpandedItem(itemId);
    const existing = bundles.get(itemId) ?? portfolioProofFallback(
      portfolioItems.find((item) => item.id === itemId),
    );
    setDraftExplainItBack(existing?.explainItBackExcerpt || '');
    setDraftOralCheck(existing?.oralCheckExcerpt || '');
    setDraftMiniRebuild(existing?.miniRebuildExcerpt || '');
  };

  const handleSaveProof = async (portfolioItemId: string) => {
    if (!learnerId || !siteId) return;
    setSaving(true);
    try {
      const hasEIB = draftExplainItBack.trim().length > 0;
      const hasOC = draftOralCheck.trim().length > 0;
      const hasMR = draftMiniRebuild.trim().length > 0;
      const verificationStatus = computeVerificationStatus(hasEIB, hasOC, hasMR);
      const proofCheckpointCount = [hasEIB, hasOC, hasMR].filter(Boolean).length;
      const proofMirrorFields = {
        proofOfLearningStatus: verificationStatus,
        proofHasExplainItBack: hasEIB,
        proofHasOralCheck: hasOC,
        proofHasMiniRebuild: hasMR,
        proofCheckpointCount,
        proofExplainItBackExcerpt: draftExplainItBack.trim() || null,
        proofOralCheckExcerpt: draftOralCheck.trim() || null,
        proofMiniRebuildExcerpt: draftMiniRebuild.trim() || null,
        updatedAt: serverTimestamp(),
      };

      const existing = bundles.get(portfolioItemId);
      if (process.env.NEXT_PUBLIC_E2E_TEST_MODE === '1') {
        const { saveE2EProofBundle } = await import('@/src/testing/e2e/fakeWebBackend');
        const result = await saveE2EProofBundle({
          learnerId,
          portfolioItemId,
          siteId,
          proofBundleId: existing?.id,
          hasExplainItBack: hasEIB,
          hasOralCheck: hasOC,
          hasMiniRebuild: hasMR,
          explainItBackExcerpt: draftExplainItBack.trim() || null,
          oralCheckExcerpt: draftOralCheck.trim() || null,
          miniRebuildExcerpt: draftMiniRebuild.trim() || null,
          verificationStatus,
          version: existing ? existing.version + 1 : 1,
        });
        setBundles((prev) => {
          const next = new Map(prev);
          next.set(portfolioItemId, {
            id: result.proofBundleId,
            portfolioItemId,
            hasExplainItBack: hasEIB,
            hasOralCheck: hasOC,
            hasMiniRebuild: hasMR,
            explainItBackExcerpt: draftExplainItBack.trim() || undefined,
            oralCheckExcerpt: draftOralCheck.trim() || undefined,
            miniRebuildExcerpt: draftMiniRebuild.trim() || undefined,
            verificationStatus,
            version: existing ? existing.version + 1 : 1,
          });
          return next;
        });
        setPortfolioItems((prev) => prev.map((item) =>
          item.id === portfolioItemId
            ? { ...item, proofBundleId: result.proofBundleId, proofOfLearningStatus: verificationStatus }
            : item
        ));
        return;
      }

      if (existing) {
        // Update existing bundle
        const docRef = doc(db, 'proofOfLearningBundles', existing.id);
        await updateDoc(docRef, {
          hasExplainItBack: hasEIB,
          hasOralCheck: hasOC,
          hasMiniRebuild: hasMR,
          explainItBackExcerpt: draftExplainItBack.trim() || null,
          oralCheckExcerpt: draftOralCheck.trim() || null,
          miniRebuildExcerpt: draftMiniRebuild.trim() || null,
          verificationStatus,
          siteId,
          version: existing.version + 1,
          updatedAt: serverTimestamp(),
        });
        // Back-link: update portfolio item with proof bundle ID and status
        await updateDoc(doc(db, 'portfolioItems', portfolioItemId), {
          proofBundleId: existing.id,
          ...proofMirrorFields,
        });
        setBundles((prev) => {
          const next = new Map(prev);
          next.set(portfolioItemId, {
            ...existing,
            hasExplainItBack: hasEIB,
            hasOralCheck: hasOC,
            hasMiniRebuild: hasMR,
            explainItBackExcerpt: draftExplainItBack.trim() || undefined,
            oralCheckExcerpt: draftOralCheck.trim() || undefined,
            miniRebuildExcerpt: draftMiniRebuild.trim() || undefined,
            verificationStatus,
            version: existing.version + 1,
          });
          return next;
        });
      } else {
        // Create new bundle
        const docRef = await addDoc(proofOfLearningBundlesCollection, {
          learnerId,
          portfolioItemId,
          siteId,
          hasExplainItBack: hasEIB,
          hasOralCheck: hasOC,
          hasMiniRebuild: hasMR,
          explainItBackExcerpt: draftExplainItBack.trim() || null,
          oralCheckExcerpt: draftOralCheck.trim() || null,
          miniRebuildExcerpt: draftMiniRebuild.trim() || null,
          verificationStatus,
          version: 1,
          createdAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        } as unknown as ProofOfLearningBundle);
        // Back-link: update portfolio item with proof bundle ID and status
        await updateDoc(doc(db, 'portfolioItems', portfolioItemId), {
          proofBundleId: docRef.id,
          ...proofMirrorFields,
        });
        setBundles((prev) => {
          const next = new Map(prev);
          next.set(portfolioItemId, {
            id: docRef.id,
            portfolioItemId,
            hasExplainItBack: hasEIB,
            hasOralCheck: hasOC,
            hasMiniRebuild: hasMR,
            explainItBackExcerpt: draftExplainItBack.trim() || undefined,
            oralCheckExcerpt: draftOralCheck.trim() || undefined,
            miniRebuildExcerpt: draftMiniRebuild.trim() || undefined,
            verificationStatus,
            version: 1,
          });
          return next;
        });
      }
    } catch (err) {
      console.error('Failed to save proof bundle:', err);
      setError('Failed to save proof bundle. Please try again.');
    } finally {
      setSaving(false);
    }
  };

  if (loading) {
    return (
      <div className="p-6 text-center text-gray-500">Loading proof-of-learning data...</div>
    );
  }

  if (!siteId) {
    return (
      <div
        data-testid="learner-proof-assembly-site-required"
        className="rounded-lg border border-amber-200 bg-amber-50 p-4 text-sm text-amber-900"
      >
        Select an active site before assembling proof-of-learning.
      </div>
    );
  }

  const proofStates = portfolioItems
    .map((item) => bundles.get(item.id) ?? portfolioProofFallback(item))
    .filter((bundle): bundle is ProofBundle => bundle !== null);
  const totalItems = portfolioItems.length;
  const verified = proofStates.filter(
    (b) => b.verificationStatus === 'verified'
  ).length;
  const partial = proofStates.filter(
    (b) => b.verificationStatus === 'partial'
  ).length;

  return (
    <div className="space-y-6">
      {error && <div className="rounded-lg border border-red-200 bg-red-50 p-4 text-sm text-red-800">{error}</div>}
      {/* Header */}
      <div className="flex items-center gap-3">
        <ShieldCheckIcon className="h-7 w-7 text-indigo-600" />
        <div>
          <h2 className="text-xl font-bold text-gray-900">Proof of Learning</h2>
          <p className="text-sm text-gray-500">
            Assemble proof for your portfolio items using three verification methods.
          </p>
        </div>
      </div>

      {/* Summary cards */}
      <div className="grid grid-cols-3 gap-4">
        <div className="bg-white border border-gray-200 rounded-lg p-4 text-center">
          <p className="text-2xl font-bold text-gray-900">{totalItems}</p>
          <p className="text-xs text-gray-500">Portfolio Items</p>
        </div>
        <div className="bg-white border border-green-200 rounded-lg p-4 text-center">
          <p className="text-2xl font-bold text-green-700">{verified}</p>
          <p className="text-xs text-green-600">Fully Verified</p>
        </div>
        <div className="bg-white border border-amber-200 rounded-lg p-4 text-center">
          <p className="text-2xl font-bold text-amber-700">{partial}</p>
          <p className="text-xs text-amber-600">Partial Proof</p>
        </div>
      </div>

      {/* Portfolio items with proof assembly */}
      {portfolioItems.length === 0 ? (
        <div className="bg-gray-50 border border-gray-200 rounded-lg p-8 text-center">
          <p className="text-gray-500">No portfolio items yet. Add items to your portfolio first.</p>
        </div>
      ) : (
        <div className="space-y-3">
          {portfolioItems.map((item) => {
            const bundle = bundles.get(item.id) ?? portfolioProofFallback(item);
            const isExpanded = expandedItem === item.id;
            return (
              <div
                key={item.id}
                className="bg-white border border-gray-200 rounded-lg overflow-hidden"
              >
                {/* Item header */}
                <button
                  onClick={() => handleExpand(item.id)}
                  className="w-full flex items-center justify-between p-4 hover:bg-gray-50 transition-colors"
                >
                  <div className="flex items-center gap-3">
                    <FileTextIcon className="h-5 w-5 text-gray-400" />
                    <div className="text-left">
                      <p className="font-medium text-gray-900">{item.title}</p>
                      <p className="text-xs text-gray-500 capitalize">{item.type}</p>
                    </div>
                  </div>
                  <div className="flex items-center gap-3">
                    {statusBadge(bundle?.verificationStatus || 'missing')}
                    {/* Method indicators */}
                    <div className="flex gap-1">
                      <span
                        title="Explain It Back"
                        className={`h-5 w-5 rounded-full flex items-center justify-center text-xs ${
                          bundle?.hasExplainItBack
                            ? 'bg-green-100 text-green-700'
                            : 'bg-gray-100 text-gray-400'
                        }`}
                      >
                        E
                      </span>
                      <span
                        title="Oral Check"
                        className={`h-5 w-5 rounded-full flex items-center justify-center text-xs ${
                          bundle?.hasOralCheck
                            ? 'bg-green-100 text-green-700'
                            : 'bg-gray-100 text-gray-400'
                        }`}
                      >
                        O
                      </span>
                      <span
                        title="Mini Rebuild"
                        className={`h-5 w-5 rounded-full flex items-center justify-center text-xs ${
                          bundle?.hasMiniRebuild
                            ? 'bg-green-100 text-green-700'
                            : 'bg-gray-100 text-gray-400'
                        }`}
                      >
                        M
                      </span>
                    </div>
                    {isExpanded ? (
                      <ChevronUpIcon className="h-4 w-4 text-gray-400" />
                    ) : (
                      <ChevronDownIcon className="h-4 w-4 text-gray-400" />
                    )}
                  </div>
                </button>

                {/* Expanded proof assembly form */}
                {isExpanded && (
                  <div className="border-t border-gray-200 p-4 space-y-4 bg-gray-50">
                    {bundle?.verificationStatus === 'verified' &&
                      bundle?.educatorVerifierId && (
                        <div className="bg-green-50 border border-green-200 rounded-md p-3 text-sm text-green-800">
                          <CheckCircleIcon className="h-4 w-4 inline mr-1" />
                          Verified by educator. You can still update your excerpts.
                        </div>
                      )}

                    {/* Explain It Back */}
                    <div>
                      <label className="flex items-center gap-2 text-sm font-medium text-gray-700 mb-1">
                        <FileTextIcon className="h-4 w-4 text-blue-500" />
                        Explain It Back
                      </label>
                      <p className="text-xs text-gray-500 mb-2">
                        In your own words, explain what you learned and how you did it.
                      </p>
                      <textarea
                        value={draftExplainItBack}
                        onChange={(e) => setDraftExplainItBack(e.target.value)}
                        placeholder="I learned that... My approach was..."
                        rows={3}
                        className="w-full px-3 py-2 border border-gray-300 rounded-md text-sm focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                      />
                    </div>

                    {/* Oral Check */}
                    <div>
                      <label className="flex items-center gap-2 text-sm font-medium text-gray-700 mb-1">
                        <MicIcon className="h-4 w-4 text-purple-500" />
                        Oral Check
                      </label>
                      <p className="text-xs text-gray-500 mb-2">
                        Summarize what you would say if asked to explain this work aloud.
                      </p>
                      <textarea
                        value={draftOralCheck}
                        onChange={(e) => setDraftOralCheck(e.target.value)}
                        placeholder="If asked, I would explain..."
                        rows={3}
                        className="w-full px-3 py-2 border border-gray-300 rounded-md text-sm focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                      />
                    </div>

                    {/* Mini Rebuild */}
                    <div>
                      <label className="flex items-center gap-2 text-sm font-medium text-gray-700 mb-1">
                        <HammerIcon className="h-4 w-4 text-orange-500" />
                        Mini Rebuild
                      </label>
                      <p className="text-xs text-gray-500 mb-2">
                        Describe how you would rebuild a key part of this work from scratch.
                      </p>
                      <textarea
                        value={draftMiniRebuild}
                        onChange={(e) => setDraftMiniRebuild(e.target.value)}
                        placeholder="To rebuild this, I would start by..."
                        rows={3}
                        className="w-full px-3 py-2 border border-gray-300 rounded-md text-sm focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                      />
                    </div>

                    {/* Save button */}
                    <div className="flex justify-end">
                      <button
                        onClick={() => handleSaveProof(item.id)}
                        disabled={saving}
                        className="px-4 py-2 bg-indigo-600 text-white rounded-md text-sm font-medium hover:bg-indigo-700 disabled:opacity-50"
                      >
                        {saving ? 'Saving...' : 'Save Proof Bundle'}
                      </button>
                    </div>
                  </div>
                )}
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
