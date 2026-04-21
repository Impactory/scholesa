'use client';

/**
 * Learner Checkpoint Renderer
 *
 * Shows the learner their checkpoint history from the `checkpointHistory`
 * collection and lets them submit answers with explain-it-back.
 * Each submission now creates a linked portfolio artifact so checkpoint proof
 * moves through the same proof-of-learning and growth contract as other
 * evidence-chain surfaces.
 */

import React, { useCallback, useEffect, useState } from 'react';
import {
  collection,
  doc,
  getDoc,
  getDocs,
  limit,
  orderBy,
  query,
  serverTimestamp,
  writeBatch,
  where,
} from 'firebase/firestore';
import { firestore } from '@/src/firebase/client-init';
import { portfolioItemsCollection } from '@/src/firebase/firestore/collections';
import { resolveActiveSiteId } from '@/src/lib/auth/activeSite';
import { useCapabilities } from '@/src/lib/capabilities/useCapabilities';
import type { PortfolioItem } from '@/src/types/schema';
import type { CustomRouteRendererProps } from '../customRouteRenderers';
import {
  CheckCircleIcon,
  ClockIcon,
  ChevronDownIcon,
  ChevronUpIcon,
  SendIcon,
} from 'lucide-react';

interface CheckpointRecord {
  id: string;
  missionId: string | null;
  missionTitle: string | null;
  checkpointNumber: number | null;
  answer: string | null;
  explainItBack: string | null;
  explainItBackRequired: boolean;
   status: 'submitted' | 'passed' | 'failed' | 'pending_review' | 'reviewed';
   isCorrect: boolean | null;
   feedback: string | null;
   aiAssistanceUsed: boolean;
   portfolioItemId: string | null;
   proofOfLearningStatus: 'missing' | 'partial' | 'verified' | 'not-available' | null;
   createdAt: string | null;
}

function toIso(val: unknown): string | null {
  if (!val) return null;
  if (typeof val === 'object' && 'toDate' in (val as Record<string, unknown>)) {
    return ((val as { toDate: () => Date }).toDate()).toISOString();
  }
  return null;
}

function statusBadge(status: CheckpointRecord['status'], isCorrect: boolean | null) {
  if (status === 'passed' || isCorrect)
    return <span className="rounded-full bg-green-100 px-2 py-0.5 text-xs font-medium text-green-800">Passed</span>;
  if (status === 'reviewed')
    return <span className="rounded-full bg-amber-100 px-2 py-0.5 text-xs font-medium text-amber-800">Reviewed</span>;
  if (status === 'failed')
    return <span className="rounded-full bg-red-100 px-2 py-0.5 text-xs font-medium text-red-800">Needs review</span>;
  if (status === 'pending_review')
    return <span className="rounded-full bg-amber-100 px-2 py-0.5 text-xs font-medium text-amber-800">Pending review</span>;
  return <span className="rounded-full bg-blue-100 px-2 py-0.5 text-xs font-medium text-blue-800">Submitted</span>;
}

export default function LearnerCheckpointRenderer({ ctx }: CustomRouteRendererProps) {
  const learnerId = ctx.uid;
  const siteId = resolveActiveSiteId(ctx.profile);
  const { capabilityList } = useCapabilities(siteId || null);

  const [records, setRecords] = useState<CheckpointRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [expanded, setExpanded] = useState<string | null>(null);

  // Submit form state
  const [showForm, setShowForm] = useState(false);
  const [answer, setAnswer] = useState('');
  const [explainItBack, setExplainItBack] = useState('');
  const [aiUsed, setAiUsed] = useState(false);
  const [aiDetails, setAiDetails] = useState('');
  const [selectedCapabilityId, setSelectedCapabilityId] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [submitError, setSubmitError] = useState<string | null>(null);

  const loadCheckpoints = useCallback(async () => {
    if (!learnerId || !siteId) {
      setRecords([]);
      setLoading(false);
      setError(null);
      return;
    }
    setLoading(true);
    setError(null);
    try {
      const snap = await getDocs(
        query(
          collection(firestore, 'checkpointHistory'),
          where('learnerId', '==', learnerId),
          where('siteId', '==', siteId),
          orderBy('createdAt', 'desc'),
          limit(50)
        )
      );
      const checkpointRows = await Promise.all(
        snap.docs.map(async (d) => {
          const data = d.data();
          const portfolioItemId =
            typeof data.portfolioItemId === 'string' ? data.portfolioItemId : null;
          let proofOfLearningStatus: CheckpointRecord['proofOfLearningStatus'] = null;

          if (portfolioItemId) {
            try {
              const portfolioSnap = await getDoc(doc(portfolioItemsCollection, portfolioItemId));
              if (portfolioSnap.exists()) {
                const portfolioData = portfolioSnap.data();
                proofOfLearningStatus =
                  typeof portfolioData.proofOfLearningStatus === 'string'
                    ? (portfolioData.proofOfLearningStatus as CheckpointRecord['proofOfLearningStatus'])
                    : null;
              }
            } catch (portfolioErr) {
              console.warn('Failed to load checkpoint proof status:', portfolioErr);
            }
          }

          return {
            id: d.id,
            missionId: (data.missionId as string) || null,
            missionTitle: (data.missionTitle as string) || null,
            checkpointNumber: typeof data.checkpointNumber === 'number' ? data.checkpointNumber : null,
            answer: (data.answer as string) || null,
            explainItBack: (data.explainItBack as string) || null,
            explainItBackRequired: Boolean(data.explainItBackRequired),
            status: (data.status as CheckpointRecord['status']) || 'submitted',
            isCorrect: typeof data.isCorrect === 'boolean' ? data.isCorrect : null,
            feedback: (data.feedback as string) || null,
            aiAssistanceUsed: Boolean(data.aiAssistanceUsed),
            portfolioItemId,
            proofOfLearningStatus,
            createdAt: toIso(data.createdAt),
          };
        })
      );
      setRecords(
        checkpointRows
      );
    } catch (err) {
      console.error('Failed to load checkpoints:', err);
      setError('Failed to load checkpoints. Please try again.');
    } finally {
      setLoading(false);
    }
  }, [learnerId, siteId]);

  useEffect(() => {
    loadCheckpoints();
  }, [loadCheckpoints]);

  const handleSubmit = async () => {
    if (!answer.trim()) {
      setSubmitError('Please write your answer.');
      return;
    }
    if (!selectedCapabilityId) {
      setSubmitError('Select a capability before submitting checkpoint evidence.');
      return;
    }
    if (!learnerId || !siteId) {
      setSubmitError('Unable to submit — not authenticated.');
      return;
    }
    setSubmitting(true);
    setSubmitError(null);
    try {
      const batch = writeBatch(firestore);
      const checkpointRef = doc(collection(firestore, 'checkpointHistory'));
      const portfolioRef = doc(portfolioItemsCollection);
      const explainItBackText = explainItBack.trim();
      const selectedCapability = capabilityList.find((cap) => cap.id === selectedCapabilityId) ?? null;
      const proofOfLearningStatus = explainItBackText ? 'partial' : 'missing';

      batch.set(portfolioRef, {
        learnerId,
        siteId,
        title: selectedCapability
          ? `Checkpoint: ${selectedCapability.title ?? selectedCapability.name}`
          : 'Checkpoint',
        description: answer.trim(),
        pillarCodes: selectedCapability?.pillarCode ? [selectedCapability.pillarCode] : [],
        artifacts: [],
        capabilityIds: selectedCapabilityId ? [selectedCapabilityId] : [],
        capabilityTitles: selectedCapability
          ? [selectedCapability.title ?? selectedCapability.name]
          : [],
        aiAssistanceUsed: aiUsed,
        aiAssistanceDetails: aiUsed ? aiDetails.trim() : undefined,
        aiDisclosureStatus: aiUsed ? 'learner-ai-verified' : 'learner-ai-not-used',
        verificationStatus: 'pending',
        proofOfLearningStatus,
        proofHasExplainItBack: explainItBackText.length > 0,
        proofHasOralCheck: false,
        proofHasMiniRebuild: false,
        proofCheckpointCount: explainItBackText.length > 0 ? 1 : 0,
        proofExplainItBackExcerpt: explainItBackText || undefined,
        source: 'checkpoint_submission',
        createdAt: serverTimestamp(),
      } as unknown as Omit<PortfolioItem, 'id'>);

      batch.set(checkpointRef, {
        learnerId,
        siteId,
        missionId: null,
        capabilityId: selectedCapabilityId || null,
        checkpointNumber: null,
        answer: answer.trim(),
        explainItBack: explainItBackText || null,
        explainItBackRequired: explainItBackText.length > 0,
        status: 'submitted',
        isCorrect: null,
        feedback: null,
        aiAssistanceUsed: aiUsed,
        aiAssistanceDetails: aiUsed ? aiDetails.trim() : null,
        portfolioItemId: portfolioRef.id,
        createdAt: serverTimestamp(),
      });

      await batch.commit();
      setAnswer('');
      setExplainItBack('');
      setAiUsed(false);
      setAiDetails('');
      setSelectedCapabilityId('');
      setShowForm(false);
      await loadCheckpoints();
    } catch (err) {
      console.error('Failed to submit checkpoint:', err);
      setSubmitError('Failed to submit. Please try again.');
    } finally {
      setSubmitting(false);
    }
  };

  if (!siteId) {
    return (
      <div
        data-testid="learner-checkpoints-site-required"
        className="rounded-lg border border-amber-200 bg-amber-50 p-4 text-sm text-amber-900"
      >
        Select an active site before submitting checkpoints or viewing checkpoint evidence.
      </div>
    );
  }

  if (loading) {
    return <div className="p-6 text-center text-gray-500">Loading checkpoints...</div>;
  }

  return (
    <div className="space-y-5">
      {error && (
        <div className="rounded-lg border border-red-200 bg-red-50 p-4 text-sm text-red-800">
          {error}
          <button className="ml-3 underline" onClick={loadCheckpoints}>Retry</button>
        </div>
      )}

      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-xl font-bold text-gray-900">Checkpoints</h2>
          <p className="text-sm text-gray-500">
            Answer checkpoint questions and explain what you learned.
          </p>
        </div>
        <button
          type="button"
          onClick={() => setShowForm(!showForm)}
          className="flex items-center gap-1 rounded-md bg-indigo-600 px-3 py-2 text-sm font-medium text-white hover:bg-indigo-700"
        >
          <SendIcon className="h-4 w-4" />
          Submit checkpoint
        </button>
      </div>

      {/* Submit form */}
      {showForm && (
        <div className="rounded-lg border border-indigo-200 bg-indigo-50 p-4 space-y-3">
          <h3 className="font-medium text-gray-900">Submit a Checkpoint</h3>

          {capabilityList.length > 0 && (
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Capability <span className="text-xs text-gray-400">(what skill is this checkpoint for?)</span>
              </label>
              {capabilityList.length > 0 ? (
                <select
                  value={selectedCapabilityId}
                  onChange={(e) => setSelectedCapabilityId(e.target.value)}
                  className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm focus:border-indigo-500 focus:outline-none"
                >
                  <option value="">Select a capability…</option>
                  {capabilityList.map((cap) => (
                    <option key={cap.id} value={cap.id}>
                      {cap.title ?? cap.name} ({cap.pillarCode.replace(/_/g, ' ')})
                    </option>
                  ))}
                </select>
              ) : (
                <p className="rounded-md border border-amber-200 bg-amber-50 px-3 py-2 text-xs text-amber-900">
                  No capabilities are defined for this site yet. Ask HQ or your educator to map checkpoint evidence before submitting.
                </p>
              )}
            </div>
          )}

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Your answer <span className="text-red-500">*</span>
            </label>
            <textarea
              value={answer}
              onChange={(e) => setAnswer(e.target.value)}
              rows={4}
              placeholder="Write your answer here..."
              className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm focus:border-indigo-500 focus:outline-none"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Explain it back <span className="text-xs text-gray-400">(explain what you learned in your own words)</span>
            </label>
            <textarea
              value={explainItBack}
              onChange={(e) => setExplainItBack(e.target.value)}
              rows={3}
              placeholder="In my own words, what I learned was..."
              className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm focus:border-indigo-500 focus:outline-none"
            />
          </div>

          <label className="flex items-center gap-2 text-sm text-gray-700">
            <input
              type="checkbox"
              checked={aiUsed}
              onChange={(e) => setAiUsed(e.target.checked)}
              className="rounded border-gray-300"
            />
            I used AI assistance for this checkpoint
          </label>

          {aiUsed && (
            <textarea
              value={aiDetails}
              onChange={(e) => setAiDetails(e.target.value)}
              rows={2}
              placeholder="Describe how AI helped you..."
              className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm focus:border-indigo-500 focus:outline-none"
            />
          )}

          {submitError && (
            <p className="text-sm text-red-600">{submitError}</p>
          )}

          <div className="flex gap-2">
            <button
              type="button"
              onClick={handleSubmit}
              disabled={submitting || !answer.trim() || !selectedCapabilityId}
              className="rounded-md bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-700 disabled:opacity-50"
            >
              {submitting ? 'Submitting...' : 'Submit'}
            </button>
            <button
              type="button"
              onClick={() => { setShowForm(false); setSubmitError(null); }}
              className="rounded-md bg-white border border-gray-300 px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50"
            >
              Cancel
            </button>
          </div>
        </div>
      )}

      {/* Checkpoint list */}
      {records.length === 0 ? (
        <div className="rounded-lg border border-gray-200 bg-gray-50 p-8 text-center">
          <CheckCircleIcon className="mx-auto mb-3 h-12 w-12 text-gray-300" />
          <p className="text-gray-500">No checkpoints submitted yet.</p>
          <p className="mt-1 text-sm text-gray-400">
            Submit your first checkpoint when your educator assigns one.
          </p>
        </div>
      ) : (
        <div className="space-y-3">
          {records.map((r) => {
            const isOpen = expanded === r.id;
            return (
              <div key={r.id} className="rounded-lg border border-gray-200 bg-white">
                <button
                  type="button"
                  className="flex w-full items-center justify-between p-4 text-left"
                  onClick={() => setExpanded(isOpen ? null : r.id)}
                >
                  <div className="flex items-center gap-3">
                    {r.status === 'passed' || r.isCorrect ? (
                      <CheckCircleIcon className="h-5 w-5 text-green-500" />
                    ) : (
                      <ClockIcon className="h-5 w-5 text-amber-400" />
                    )}
                    <div className="text-left">
                      <p className="text-sm font-medium text-gray-900">
                        {r.missionTitle
                          ? `${r.missionTitle}${r.checkpointNumber != null ? ` — #${r.checkpointNumber}` : ''}`
                          : r.checkpointNumber != null
                          ? `Checkpoint #${r.checkpointNumber}`
                          : 'Checkpoint'}
                      </p>
                      {r.createdAt && (
                        <p className="text-xs text-gray-400">
                          {new Date(r.createdAt).toLocaleString()}
                        </p>
                      )}
                    </div>
                  </div>
                  <div className="flex items-center gap-2">
                    {statusBadge(r.status, r.isCorrect)}
                    {isOpen ? (
                      <ChevronUpIcon className="h-4 w-4 text-gray-400" />
                    ) : (
                      <ChevronDownIcon className="h-4 w-4 text-gray-400" />
                    )}
                  </div>
                </button>

                {isOpen && (
                  <div className="border-t border-gray-100 px-4 pb-4 pt-3 space-y-3">
                    {r.answer && (
                      <div>
                        <p className="text-xs font-medium text-gray-500 mb-1">Your answer</p>
                        <p className="text-sm text-gray-800 whitespace-pre-wrap">{r.answer}</p>
                      </div>
                    )}
                    {r.explainItBack && (
                      <div>
                        <p className="text-xs font-medium text-indigo-600 mb-1">Explain-it-back</p>
                        <p className="text-sm text-gray-800 whitespace-pre-wrap">{r.explainItBack}</p>
                      </div>
                    )}
                    {r.feedback && (
                      <div className="rounded-md bg-green-50 border border-green-200 p-3">
                        <p className="text-xs font-medium text-green-700 mb-1">Educator feedback</p>
                        <p className="text-sm text-green-900">{r.feedback}</p>
                      </div>
                    )}
                    {r.aiAssistanceUsed && (
                      <p className="text-xs text-amber-600">AI assistance was used for this checkpoint.</p>
                    )}
                    {r.portfolioItemId && (
                      <div
                        className={`rounded-md border px-3 py-2 text-xs ${
                          r.proofOfLearningStatus === 'verified'
                            ? 'border-green-200 bg-green-50 text-green-800'
                            : 'border-amber-200 bg-amber-50 text-amber-900'
                        }`}
                      >
                        {r.proofOfLearningStatus === 'verified'
                          ? 'Proof of learning is verified for this checkpoint artifact.'
                          : 'Next step: complete proof-of-learning so this checkpoint can support capability growth.'}
                      </div>
                    )}
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
