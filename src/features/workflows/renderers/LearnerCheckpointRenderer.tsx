'use client';

/**
 * Learner Checkpoint Renderer
 *
 * Shows the learner their checkpoint history from the `checkpointHistory`
 * collection and lets them submit answers with explain-it-back.
 * Writes to `checkpointHistory` (not portfolioItems) to match the Flutter
 * implementation and the Firestore rules (learner self-write allowed).
 */

import React, { useCallback, useEffect, useState } from 'react';
import {
  addDoc,
  collection,
  getDocs,
  limit,
  orderBy,
  query,
  serverTimestamp,
  where,
} from 'firebase/firestore';
import { firestore } from '@/src/firebase/client-init';
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
  status: 'submitted' | 'passed' | 'failed' | 'pending_review';
  isCorrect: boolean;
  feedback: string | null;
  aiAssistanceUsed: boolean;
  createdAt: string | null;
}

function toIso(val: unknown): string | null {
  if (!val) return null;
  if (typeof val === 'object' && 'toDate' in (val as Record<string, unknown>)) {
    return ((val as { toDate: () => Date }).toDate()).toISOString();
  }
  return null;
}

function statusBadge(status: CheckpointRecord['status'], isCorrect: boolean) {
  if (status === 'passed' || isCorrect)
    return <span className="rounded-full bg-green-100 px-2 py-0.5 text-xs font-medium text-green-800">Passed</span>;
  if (status === 'failed')
    return <span className="rounded-full bg-red-100 px-2 py-0.5 text-xs font-medium text-red-800">Needs review</span>;
  if (status === 'pending_review')
    return <span className="rounded-full bg-amber-100 px-2 py-0.5 text-xs font-medium text-amber-800">Pending review</span>;
  return <span className="rounded-full bg-blue-100 px-2 py-0.5 text-xs font-medium text-blue-800">Submitted</span>;
}

export default function LearnerCheckpointRenderer({ ctx }: CustomRouteRendererProps) {
  const learnerId = ctx.uid;
  const siteId = ctx.profile?.siteIds?.[0] || ctx.profile?.activeSiteId || '';

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
  const [submitting, setSubmitting] = useState(false);
  const [submitError, setSubmitError] = useState<string | null>(null);

  const loadCheckpoints = useCallback(async () => {
    if (!learnerId) return;
    setLoading(true);
    setError(null);
    try {
      const snap = await getDocs(
        query(
          collection(firestore, 'checkpointHistory'),
          where('learnerId', '==', learnerId),
          orderBy('createdAt', 'desc'),
          limit(50)
        )
      );
      setRecords(
        snap.docs.map((d) => {
          const data = d.data();
          return {
            id: d.id,
            missionId: (data.missionId as string) || null,
            missionTitle: (data.missionTitle as string) || null,
            checkpointNumber: typeof data.checkpointNumber === 'number' ? data.checkpointNumber : null,
            answer: (data.answer as string) || null,
            explainItBack: (data.explainItBack as string) || null,
            explainItBackRequired: Boolean(data.explainItBackRequired),
            status: (data.status as CheckpointRecord['status']) || 'submitted',
            isCorrect: Boolean(data.isCorrect),
            feedback: (data.feedback as string) || null,
            aiAssistanceUsed: Boolean(data.aiAssistanceUsed),
            createdAt: toIso(data.createdAt),
          };
        })
      );
    } catch (err) {
      console.error('Failed to load checkpoints:', err);
      setError('Failed to load checkpoints. Please try again.');
    } finally {
      setLoading(false);
    }
  }, [learnerId]);

  useEffect(() => {
    loadCheckpoints();
  }, [loadCheckpoints]);

  const handleSubmit = async () => {
    if (!answer.trim()) {
      setSubmitError('Please write your answer.');
      return;
    }
    if (!learnerId || !siteId) {
      setSubmitError('Unable to submit — not authenticated.');
      return;
    }
    setSubmitting(true);
    setSubmitError(null);
    try {
      await addDoc(collection(firestore, 'checkpointHistory'), {
        learnerId,
        siteId,
        missionId: null,
        checkpointNumber: null,
        answer: answer.trim(),
        explainItBack: explainItBack.trim() || null,
        explainItBackRequired: explainItBack.trim().length > 0,
        status: 'submitted',
        isCorrect: null,
        feedback: null,
        aiAssistanceUsed: aiUsed,
        aiAssistanceDetails: aiUsed ? aiDetails.trim() : null,
        createdAt: serverTimestamp(),
      });
      setAnswer('');
      setExplainItBack('');
      setAiUsed(false);
      setAiDetails('');
      setShowForm(false);
      await loadCheckpoints();
    } catch (err) {
      console.error('Failed to submit checkpoint:', err);
      setSubmitError('Failed to submit. Please try again.');
    } finally {
      setSubmitting(false);
    }
  };

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
              disabled={submitting || !answer.trim()}
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
