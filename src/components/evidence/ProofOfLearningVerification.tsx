'use client';

import { useCallback, useEffect, useState } from 'react';
import { usePathname } from 'next/navigation';
import {
  getDocs,
  limit,
  orderBy,
  query,
  where,
} from 'firebase/firestore';
import { httpsCallable } from 'firebase/functions';
import { useAuthContext } from '@/src/firebase/auth/AuthProvider';
import {
  portfolioItemsCollection,
} from '@/src/firebase/firestore/collections';
import { functions } from '@/src/firebase/client-init';
import { resolveActiveSiteId } from '@/src/lib/auth/activeSite';
import { useCapabilities } from '@/src/lib/capabilities/useCapabilities';
import { RoleRouteGuard } from '@/src/components/auth/RoleRouteGuard';
import { Spinner } from '@/src/components/ui/Spinner';
import type { PortfolioItem } from '@/src/types/schema';

/* ───── Constants ───── */

const VERIFICATION_CHECKS = [
  { key: 'explainItBack', label: 'Explain-it-back', prompt: 'Can the learner explain the concept in their own words without prompts?' },
  { key: 'oralCheck', label: 'Oral check', prompt: 'Can the learner answer follow-up questions demonstrating understanding?' },
  { key: 'miniRebuild', label: 'Mini rebuild', prompt: 'Can the learner recreate or extend the work independently?' },
] as const;

const STATUS_COLORS: Record<string, string> = {
  pending: 'bg-yellow-100 text-yellow-800',
  reviewed: 'bg-blue-100 text-blue-800',
  verified: 'bg-green-100 text-green-800',
  'needs-resubmission': 'bg-red-100 text-red-800',
};

interface VerifyProofOfLearningResult {
  capabilitiesReadyForRubric?: number;
}

/* ───── Main Component ───── */

export function ProofOfLearningVerification() {
  const { user, profile, loading: authLoading } = useAuthContext();
  const siteId = resolveActiveSiteId(profile);
  const { resolveTitle, loading: capLoading } = useCapabilities(siteId);
  const pathname = usePathname();
  const locale = pathname?.split('/').filter(Boolean)[0] ?? 'en';
  const rubricApplyHref = `/${locale}/educator/rubrics/apply`;

  const [items, setItems] = useState<PortfolioItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedItem, setSelectedItem] = useState<PortfolioItem | null>(null);
  const [saving, setSaving] = useState(false);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [filterStatus, setFilterStatus] = useState<'all' | 'pending' | 'reviewed'>('pending');

  /* ───── Load portfolio items needing verification ───── */

  const loadItems = useCallback(async () => {
    setLoadError(null);
    if (!siteId) {
      setItems([]);
      setLoading(false);
      return;
    }

    setLoading(true);
    try {
      // Load items that are pending or reviewed (not yet verified)
      // Site-scoped to prevent cross-site data access
      const constraints = [
        where('siteId', '==', siteId),
        orderBy('createdAt', 'desc'),
        limit(100),
      ];
      const snap = await getDocs(query(portfolioItemsCollection, ...constraints));
      const allItems = snap.docs
        .map((d) => ({ ...d.data(), id: d.id }) as PortfolioItem)
        .filter((item) => {
          const status = item.verificationStatus ?? 'pending';
          return status !== 'verified';
        });
      setItems(allItems);
    } catch (err) {
      console.error('Failed to load verification queue', err);
      setLoadError('Failed to load verification queue. Please try again.');
    } finally {
      setLoading(false);
    }
  }, [siteId]);

  useEffect(() => {
    if (authLoading) return;
    void loadItems();
  }, [authLoading, loadItems]);

  /* ───── Filtered items ───── */

  const filteredItems = items.filter((item) => {
    if (filterStatus === 'all') return true;
    const status = item.verificationStatus ?? 'pending';
    return status === filterStatus;
  });

  /* ───── Auth Guard ───── */

  if (authLoading || capLoading) return <div className="flex justify-center py-12"><Spinner /></div>;
  if (!user || !profile) return <div className="p-6 text-sm text-gray-500">Not authenticated.</div>;
  if (!siteId) {
    return (
      <div
        data-testid="proof-verification-site-required"
        className="rounded-lg border border-amber-200 bg-amber-50 px-4 py-4 text-sm text-amber-900"
      >
        Select an active site before reviewing proof-of-learning evidence.
      </div>
    );
  }

  return (
    <RoleRouteGuard allowedRoles={['hq', 'educator']}>
      <div className="mx-auto max-w-6xl px-4 py-6 sm:px-6">
        <div className="mb-6">
          <h1 className="text-2xl font-bold text-gray-900">Proof-of-Learning Verification</h1>
          <p className="mt-1 text-sm text-gray-500">
            Review learner evidence and verify capability claims through explain-it-back, oral checks, and mini rebuilds.
          </p>
        </div>

        {successMessage && (
          <div className="mb-4 rounded-md bg-green-50 border border-green-200 px-4 py-3 text-sm text-green-800">
            {successMessage}
          </div>
        )}

        {loadError && (
          <div className="mb-4 rounded-md bg-red-50 border border-red-200 px-4 py-3 text-sm text-red-800">
            {loadError}
          </div>
        )}

        {/* Filter toolbar */}
        <div className="mb-4 flex items-center gap-3">
          <select
            aria-label="Filter verification status"
            value={filterStatus}
            onChange={(e) => setFilterStatus(e.target.value as 'all' | 'pending' | 'reviewed')}
            className="rounded-md border border-gray-300 px-3 py-1.5 text-sm"
          >
            <option value="pending">Pending verification</option>
            <option value="reviewed">Reviewed (needs PoL)</option>
            <option value="all">All unverified</option>
          </select>
          <span className="text-xs text-gray-400">{filteredItems.length} items</span>
        </div>

        {loading ? (
          <div className="flex justify-center py-12"><Spinner /></div>
        ) : (
          <div className="grid grid-cols-1 gap-6 lg:grid-cols-3">
            {/* Left: Item list */}
            <div className="lg:col-span-1 space-y-2 max-h-[70vh] overflow-y-auto">
              {filteredItems.length === 0 ? (
                <div className="rounded-lg border-2 border-dashed border-gray-200 py-8 text-center">
                  <p className="text-sm text-gray-500">No items awaiting verification.</p>
                </div>
              ) : (
                filteredItems.map((item) => (
                  <button
                    key={item.id}
                    onClick={() => setSelectedItem(item)}
                    className={`w-full rounded-lg border p-3 text-left transition ${
                      selectedItem?.id === item.id
                        ? 'border-indigo-400 bg-indigo-50 ring-1 ring-indigo-200'
                        : 'border-gray-200 bg-white hover:bg-gray-50'
                    }`}
                  >
                    <div className="flex items-center justify-between gap-2">
                      <h4 className="truncate text-sm font-medium text-gray-900">{item.title}</h4>
                      <span className={`shrink-0 rounded-full px-2 py-0.5 text-xs font-medium ${STATUS_COLORS[item.verificationStatus ?? 'pending']}`}>
                        {item.verificationStatus ?? 'pending'}
                      </span>
                    </div>
                    {item.capabilityIds && item.capabilityIds.length > 0 && (
                      <p className="mt-1 truncate text-xs text-gray-500">
                        {item.capabilityIds.map(resolveTitle).join(', ')}
                      </p>
                    )}
                    <p className="mt-0.5 text-xs text-gray-400">
                      {item.proofOfLearningStatus === 'verified' ? '✓ PoL verified' :
                       item.proofOfLearningStatus === 'partial' ? '◐ Partial PoL' :
                       '○ No PoL yet'}
                    </p>
                  </button>
                ))
              )}
            </div>

            {/* Right: Detail + Verification Panel */}
            <div className="lg:col-span-2">
              {selectedItem ? (
                <VerificationPanel
                  item={selectedItem}
                  resolveTitle={resolveTitle}
                  saving={saving}
                  rubricApplyHref={rubricApplyHref}
                  showRubricCta={profile.role === 'educator'}
                  onVerify={async (verdictData) => {
                    setSaving(true);
                    try {
                      const verifyPoL = httpsCallable(functions, 'verifyProofOfLearning');
                      const result = await verifyPoL({
                        portfolioItemId: selectedItem.id,
                        verificationStatus: verdictData.verificationStatus,
                        proofOfLearningStatus: verdictData.proofOfLearningStatus,
                        proofChecks: {
                          explainItBack: verdictData.proofHasExplainItBack ?? false,
                          oralCheck: verdictData.proofHasOralCheck ?? false,
                          miniRebuild: verdictData.proofHasMiniRebuild ?? false,
                        },
                        excerpts: {
                          explainItBack: verdictData.proofExplainItBackExcerpt,
                          oralCheck: verdictData.proofOralCheckExcerpt,
                          miniRebuild: verdictData.proofMiniRebuildExcerpt,
                        },
                        educatorNotes: verdictData.verificationNotes,
                        resubmissionReason: verdictData.verificationPrompt,
                      });
                      const capabilitiesReadyForRubric =
                        typeof (result.data as VerifyProofOfLearningResult | undefined)
                          ?.capabilitiesReadyForRubric === 'number'
                          ? (result.data as VerifyProofOfLearningResult).capabilitiesReadyForRubric ?? 0
                          : 0;
                      setSuccessMessage(
                        verdictData.verificationStatus === 'verified'
                          ? capabilitiesReadyForRubric > 0
                            ? 'Verified — proof confirmed. Ready for rubric application.'
                            : 'Verified — proof confirmed.'
                          : 'Verification updated.'
                      );
                      setTimeout(() => setSuccessMessage(null), 3000);
                      await loadItems();
                      setSelectedItem(null);
                    } catch (err) {
                      console.error('Failed to update verification', err);
                      alert('Failed to save verification. Please try again.');
                    } finally {
                      setSaving(false);
                    }
                  }}
                />
              ) : (
                <div className="flex items-center justify-center rounded-lg border-2 border-dashed border-gray-200 py-20">
                  <p className="text-sm text-gray-400">Select an item to review</p>
                </div>
              )}
            </div>
          </div>
        )}
      </div>
    </RoleRouteGuard>
  );
}

/* ───── Verification Panel ───── */

function VerificationPanel({
  item,
  resolveTitle,
  saving,
  rubricApplyHref,
  showRubricCta,
  onVerify,
}: {
  item: PortfolioItem;
  resolveTitle: (id: string) => string;
  saving: boolean;
  rubricApplyHref: string;
  showRubricCta: boolean;
  onVerify: (data: Record<string, unknown>) => Promise<void>;
}) {
  const [checks, setChecks] = useState<Record<string, boolean>>({
    explainItBack: false,
    oralCheck: false,
    miniRebuild: false,
  });
  const [excerpts, setExcerpts] = useState<Record<string, string>>({
    explainItBack: '',
    oralCheck: '',
    miniRebuild: '',
  });
  const [educatorNotes, setEducatorNotes] = useState('');
  const [resubmissionReason, setResubmissionReason] = useState('');

  // Reset form when item changes
  useEffect(() => {
    const explainItBackChecked =
      item.proofHasExplainItBack === true
      || (typeof item.proofExplainItBackExcerpt === 'string' && item.proofExplainItBackExcerpt.trim().length > 0);
    const oralCheckChecked =
      item.proofHasOralCheck === true
      || (typeof item.proofOralCheckExcerpt === 'string' && item.proofOralCheckExcerpt.trim().length > 0);
    const miniRebuildChecked =
      item.proofHasMiniRebuild === true
      || (typeof item.proofMiniRebuildExcerpt === 'string' && item.proofMiniRebuildExcerpt.trim().length > 0);
    setChecks({
      explainItBack: explainItBackChecked,
      oralCheck: oralCheckChecked,
      miniRebuild: miniRebuildChecked,
    });
    setExcerpts({
      explainItBack: typeof item.proofExplainItBackExcerpt === 'string' ? item.proofExplainItBackExcerpt : '',
      oralCheck: typeof item.proofOralCheckExcerpt === 'string' ? item.proofOralCheckExcerpt : '',
      miniRebuild: typeof item.proofMiniRebuildExcerpt === 'string' ? item.proofMiniRebuildExcerpt : '',
    });
    setEducatorNotes(typeof item.verificationNotes === 'string' ? item.verificationNotes : '');
    setResubmissionReason(
      item.verificationStatus === 'pending' && typeof item.verificationPrompt === 'string'
        ? item.verificationPrompt
        : ''
    );
  }, [
    item.id,
    item.proofHasExplainItBack,
    item.proofHasOralCheck,
    item.proofHasMiniRebuild,
    item.proofExplainItBackExcerpt,
    item.proofOralCheckExcerpt,
    item.proofMiniRebuildExcerpt,
    item.verificationNotes,
    item.verificationPrompt,
    item.verificationStatus,
  ]);

  const checkedCount = Object.values(checks).filter(Boolean).length;
  const canVerify = checkedCount >= 2; // At least 2 of 3 proof checks

  return (
    <div className="rounded-lg border border-gray-200 bg-white p-6 shadow-sm">
      {/* Header */}
      <div className="mb-4">
        <h3 className="text-lg font-semibold text-gray-900">{item.title}</h3>
        {item.description && <p className="mt-1 text-sm text-gray-600">{item.description}</p>}
      </div>

      {/* Evidence summary */}
      <div className="mb-4 grid grid-cols-2 gap-3 sm:grid-cols-4">
        <div className="rounded border border-gray-100 bg-gray-50 p-2 text-center">
          <span className="block text-lg font-bold text-gray-900">{item.capabilityIds?.length ?? 0}</span>
          <span className="text-xs text-gray-500">Capabilities</span>
        </div>
        <div className="rounded border border-gray-100 bg-gray-50 p-2 text-center">
          <span className="block text-lg font-bold text-gray-900">{item.evidenceRecordIds?.length ?? 0}</span>
          <span className="text-xs text-gray-500">Evidence records</span>
        </div>
        <div className="rounded border border-gray-100 bg-gray-50 p-2 text-center">
          <span className="block text-lg font-bold text-gray-900">{item.artifacts?.length ?? 0}</span>
          <span className="text-xs text-gray-500">Artifacts</span>
        </div>
        <div className="rounded border border-gray-100 bg-gray-50 p-2 text-center">
          <span className={`block text-lg font-bold ${item.aiAssistanceUsed ? 'text-amber-600' : 'text-gray-900'}`}>
            {item.aiAssistanceUsed ? 'Yes' : 'No'}
          </span>
          <span className="text-xs text-gray-500">AI used</span>
        </div>
      </div>

      {/* Capability list */}
      {item.capabilityIds && item.capabilityIds.length > 0 && (
        <div className="mb-4">
          <h4 className="text-xs font-semibold uppercase tracking-wide text-gray-500 mb-1">Mapped Capabilities</h4>
          <div className="flex flex-wrap gap-1">
            {item.capabilityIds.map((capId) => (
              <span key={capId} className="rounded-full bg-indigo-50 border border-indigo-200 px-2 py-0.5 text-xs text-indigo-700">
                {resolveTitle(capId)}
              </span>
            ))}
          </div>
        </div>
      )}

      {/* AI Disclosure detail */}
      {item.aiAssistanceUsed && item.aiAssistanceDetails && (
        <div className="mb-4 rounded border border-amber-200 bg-amber-50 p-3">
          <h4 className="text-xs font-semibold text-amber-800">AI Assistance Disclosed</h4>
          <p className="mt-1 text-xs text-amber-700">{item.aiAssistanceDetails}</p>
        </div>
      )}

      {/* Verification prompt from evidence */}
      {item.verificationPrompt && (
        <div className="mb-4 rounded border border-purple-200 bg-purple-50 p-3">
          <h4 className="text-xs font-semibold text-purple-800">Verification Prompt</h4>
          <p className="mt-1 text-xs text-purple-700">{item.verificationPrompt}</p>
        </div>
      )}

      {showRubricCta && item.capabilityIds && item.capabilityIds.length > 0 && (
        <div
          className="mb-4 rounded border border-blue-200 bg-blue-50 p-3"
          data-testid="proof-verification-rubric-cta"
        >
          <h4 className="text-xs font-semibold text-blue-800">Next step after proof verification</h4>
          <p className="mt-1 text-xs text-blue-700">
            After proof is verified, apply a rubric to interpret this evidence and update capability growth.
          </p>
          <a
            href={rubricApplyHref}
            className="mt-2 inline-flex rounded-md border border-blue-300 bg-white px-3 py-1.5 text-xs font-medium text-blue-700 hover:bg-blue-100"
          >
            Open Rubric Application
          </a>
        </div>
      )}

      <hr className="my-4" />

      {/* Proof-of-Learning Checks */}
      <h4 className="text-sm font-semibold text-gray-700 mb-3">Proof-of-Learning Checks</h4>
      <div className="space-y-3">
        {VERIFICATION_CHECKS.map((check) => (
          <div key={check.key} className="rounded border border-gray-200 p-3">
            <label className="flex items-start gap-3 cursor-pointer">
              <input
                type="checkbox"
                checked={checks[check.key] ?? false}
                onChange={(e) => setChecks((prev) => ({ ...prev, [check.key]: e.target.checked }))}
                className="mt-0.5 h-4 w-4 rounded border-gray-300 text-indigo-600"
              />
              <div className="flex-1">
                <span className="text-sm font-medium text-gray-800">{check.label}</span>
                <p className="text-xs text-gray-500 mt-0.5">{check.prompt}</p>
                {checks[check.key] && (
                  <textarea
                    value={excerpts[check.key] ?? ''}
                    onChange={(e) => setExcerpts((prev) => ({ ...prev, [check.key]: e.target.value }))}
                    placeholder={'What did the learner say/do? (optional brief excerpt)'}
                    rows={2}
                    className="mt-2 block w-full rounded-md border border-gray-300 px-2 py-1.5 text-xs shadow-sm"
                  />
                )}
              </div>
            </label>
          </div>
        ))}
      </div>

      {/* Educator notes */}
      <div className="mt-4">
        <label className="block text-sm font-medium text-gray-700">Educator Notes</label>
        <textarea
          value={educatorNotes}
          onChange={(e) => setEducatorNotes(e.target.value)}
          rows={2}
          className="mt-1 block w-full rounded-md border border-gray-300 px-3 py-2 text-sm shadow-sm"
          placeholder="Overall notes on this verification"
        />
      </div>

      {/* Actions */}
      <div className="mt-6 flex flex-wrap items-center gap-3">
        {/* Verify button */}
        <button
          onClick={() => onVerify({
            verificationStatus: 'verified',
            proofOfLearningStatus: 'verified',
            proofHasExplainItBack: checks.explainItBack,
            proofHasOralCheck: checks.oralCheck,
            proofHasMiniRebuild: checks.miniRebuild,
            ...(excerpts.explainItBack ? { proofExplainItBackExcerpt: excerpts.explainItBack } : {}),
            ...(excerpts.oralCheck ? { proofOralCheckExcerpt: excerpts.oralCheck } : {}),
            ...(excerpts.miniRebuild ? { proofMiniRebuildExcerpt: excerpts.miniRebuild } : {}),
            ...(educatorNotes ? { verificationNotes: educatorNotes } : {}),
            proofCheckpointCount: checkedCount,
          })}
          disabled={saving || !canVerify}
          className="rounded-md bg-green-600 px-4 py-2 text-sm font-medium text-white hover:bg-green-700 disabled:opacity-50"
          title={canVerify ? 'Mark as verified' : 'Complete at least 2 proof checks to verify'}
        >
          {saving ? 'Saving...' : `Verify (${checkedCount}/3 checks)`}
        </button>

        {/* Mark reviewed (without full verification) */}
        <button
          onClick={() => onVerify({
            verificationStatus: 'reviewed',
            proofOfLearningStatus: checkedCount > 0 ? 'partial' : 'not-available',
            proofHasExplainItBack: checks.explainItBack,
            proofHasOralCheck: checks.oralCheck,
            proofHasMiniRebuild: checks.miniRebuild,
            ...(excerpts.explainItBack ? { proofExplainItBackExcerpt: excerpts.explainItBack } : {}),
            ...(excerpts.oralCheck ? { proofOralCheckExcerpt: excerpts.oralCheck } : {}),
            ...(excerpts.miniRebuild ? { proofMiniRebuildExcerpt: excerpts.miniRebuild } : {}),
            ...(educatorNotes ? { verificationNotes: educatorNotes } : {}),
            proofCheckpointCount: checkedCount,
          })}
          disabled={saving}
          className="rounded-md border border-gray-300 px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 disabled:opacity-50"
        >
          Mark Reviewed
        </button>

        {/* Request resubmission */}
        <div className="flex-1" />
        <div className="flex items-center gap-2">
          <input
            type="text"
            value={resubmissionReason}
            onChange={(e) => setResubmissionReason(e.target.value)}
            placeholder="Reason for resubmission"
            className="rounded-md border border-gray-300 px-3 py-1.5 text-sm w-48"
          />
          <button
            onClick={() => {
              if (!resubmissionReason.trim()) return;
              onVerify({
                verificationStatus: 'pending',
                proofOfLearningStatus: checkedCount > 0 ? 'partial' : 'missing',
                proofHasExplainItBack: checks.explainItBack,
                proofHasOralCheck: checks.oralCheck,
                proofHasMiniRebuild: checks.miniRebuild,
                ...(excerpts.explainItBack ? { proofExplainItBackExcerpt: excerpts.explainItBack } : {}),
                ...(excerpts.oralCheck ? { proofOralCheckExcerpt: excerpts.oralCheck } : {}),
                ...(excerpts.miniRebuild ? { proofMiniRebuildExcerpt: excerpts.miniRebuild } : {}),
                ...(educatorNotes ? { verificationNotes: educatorNotes } : {}),
                verificationPrompt: resubmissionReason.trim(),
                verificationPromptSource: 'educator_review',
                proofCheckpointCount: checkedCount,
              });
            }}
            disabled={saving || !resubmissionReason.trim()}
            className="rounded-md border border-red-300 px-3 py-1.5 text-sm font-medium text-red-700 hover:bg-red-50 disabled:opacity-50"
          >
            Request Resubmission
          </button>
        </div>
      </div>
    </div>
  );
}
