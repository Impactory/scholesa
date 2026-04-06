'use client';

/**
 * Learner Showcase & Peer Review Renderer (S3-3)
 *
 * Combines showcase gallery, submission, and structured peer feedback
 * into a single route. Maps to the SDT belonging pillar.
 */

import React, { useCallback, useEffect, useState } from 'react';
import {
  addDoc,
  collection,
  getDocs,
  query,
  where,
  orderBy,
  limit,
  serverTimestamp,
} from 'firebase/firestore';
import { firestore } from '@/src/firebase/client-init';
import type { CustomRouteRendererProps } from '../customRouteRenderers';
import {
  SparklesIcon,
  HeartIcon,
  MessageCircleIcon,
  PlusIcon,
  XIcon,
  ImageIcon,
  SendIcon,
} from 'lucide-react';

interface ShowcaseItem {
  id: string;
  title: string;
  description: string;
  artifactType: string;
  artifactUrl: string;
  learnerId: string;
  learnerName: string;
  microSkillIds: string[];
  recognitionCount: number;
  createdAt: string | null;
}

interface PeerFeedbackEntry {
  id: string;
  showcaseId: string;
  fromLearnerName: string;
  iLike: string;
  iWonder: string;
  nextStep: string;
  createdAt: string | null;
}

function toIso(val: unknown): string | null {
  if (!val) return null;
  if (typeof val === 'object' && 'toDate' in (val as Record<string, unknown>)) {
    return ((val as { toDate: () => Date }).toDate()).toISOString();
  }
  return null;
}

export default function LearnerShowcasePeerReviewRenderer({ ctx }: CustomRouteRendererProps) {
  const learnerId = ctx.uid;
  const siteId = ctx.profile?.siteIds?.[0] || '';

  const [items, setItems] = useState<ShowcaseItem[]>([]);
  const [feedbacks, setFeedbacks] = useState<Map<string, PeerFeedbackEntry[]>>(new Map());
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [showSubmitForm, setShowSubmitForm] = useState(false);
  const [feedbackTarget, setFeedbackTarget] = useState<string | null>(null);

  // Submit form state
  const [newTitle, setNewTitle] = useState('');
  const [newDescription, setNewDescription] = useState('');
  const [newArtifactUrl, setNewArtifactUrl] = useState('');
  const [submitting, setSubmitting] = useState(false);

  // Peer feedback form state
  const [fbILike, setFbILike] = useState('');
  const [fbIWonder, setFbIWonder] = useState('');
  const [fbNextStep, setFbNextStep] = useState('');
  const [sendingFeedback, setSendingFeedback] = useState(false);

  const loadData = useCallback(async () => {
    if (!siteId) return;
    setLoading(true);
    try {
      // Load showcase submissions for this site
      const showcaseSnap = await getDocs(
        query(
          collection(firestore, 'showcaseSubmissions'),
          where('siteId', '==', siteId),
          where('visibleToSite', '==', true),
          orderBy('createdAt', 'desc'),
          limit(50)
        )
      );

      const showcaseItems: ShowcaseItem[] = showcaseSnap.docs.map((d) => {
        const data = d.data();
        return {
          id: d.id,
          title: (data.title as string) || 'Untitled',
          description: (data.description as string) || '',
          artifactType: (data.artifactType as string) || 'document',
          artifactUrl: (data.artifactUrl as string) || '',
          learnerId: (data.learnerId as string) || '',
          learnerName: (data.learnerName as string) || 'Anonymous',
          microSkillIds: Array.isArray(data.microSkillIds) ? data.microSkillIds : [],
          recognitionCount: Array.isArray(data.recognitions) ? data.recognitions.length : 0,
          createdAt: toIso(data.createdAt),
        };
      });
      setItems(showcaseItems);

      // Load peer feedback for displayed items
      if (showcaseItems.length > 0) {
        const itemIds = showcaseItems.map((i) => i.id).slice(0, 10);
        const fbSnap = await getDocs(
          query(
            collection(firestore, 'peerFeedback'),
            where('targetId', 'in', itemIds),
            orderBy('createdAt', 'desc')
          )
        );
        const fbMap = new Map<string, PeerFeedbackEntry[]>();
        fbSnap.docs.forEach((d) => {
          const data = d.data();
          const targetId = data.targetId as string;
          const entry: PeerFeedbackEntry = {
            id: d.id,
            showcaseId: targetId,
            fromLearnerName: (data.fromLearnerName as string) || 'Peer',
            iLike: (data.iLike as string) || '',
            iWonder: (data.iWonder as string) || '',
            nextStep: (data.nextStep as string) || '',
            createdAt: toIso(data.createdAt),
          };
          const existing = fbMap.get(targetId) || [];
          existing.push(entry);
          fbMap.set(targetId, existing);
        });
        setFeedbacks(fbMap);
      }
    } catch (err) {
      console.error('Failed to load showcase data:', err);
      setError('Failed to load data. Please try again.');
    } finally {
      setLoading(false);
    }
  }, [siteId]);

  useEffect(() => {
    loadData();
  }, [loadData]);

  const handleSubmitShowcase = async () => {
    if (!newTitle.trim() || !learnerId || !siteId) return;
    setSubmitting(true);
    try {
      await addDoc(collection(firestore, 'showcaseSubmissions'), {
        learnerId,
        siteId,
        title: newTitle.trim(),
        description: newDescription.trim(),
        artifactType: 'document',
        artifactUrl: newArtifactUrl.trim(),
        learnerName: ctx.profile?.displayName || 'Learner',
        microSkillIds: [],
        recognitions: [],
        visibleToCrew: true,
        visibleToSite: true,
        createdAt: serverTimestamp(),
      });
      setNewTitle('');
      setNewDescription('');
      setNewArtifactUrl('');
      setShowSubmitForm(false);
      await loadData();
    } catch (err) {
      console.error('Failed to submit showcase:', err);
      alert('Failed to submit showcase. Please try again.');
    } finally {
      setSubmitting(false);
    }
  };

  const handleSendFeedback = async (targetId: string) => {
    if (!fbILike.trim() && !fbIWonder.trim() && !fbNextStep.trim()) return;
    setSendingFeedback(true);
    try {
      await addDoc(collection(firestore, 'peerFeedback'), {
        targetId,
        targetType: 'showcase',
        fromLearnerId: learnerId,
        fromLearnerName: ctx.profile?.displayName || 'Peer',
        siteId,
        iLike: fbILike.trim(),
        iWonder: fbIWonder.trim(),
        nextStep: fbNextStep.trim(),
        flagged: false,
        createdAt: serverTimestamp(),
      });
      setFbILike('');
      setFbIWonder('');
      setFbNextStep('');
      setFeedbackTarget(null);
      await loadData();
    } catch (err) {
      console.error('Failed to send feedback:', err);
      alert('Failed to send feedback. Please try again.');
    } finally {
      setSendingFeedback(false);
    }
  };

  if (loading) {
    return <div className="p-6 text-center text-gray-500">Loading showcase...</div>;
  }

  return (
    <div className="space-y-6">
      {error && <div className="rounded-lg border border-red-200 bg-red-50 p-4 text-sm text-red-800">{error}</div>}
      {/* Header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <SparklesIcon className="h-7 w-7 text-purple-600" />
          <div>
            <h2 className="text-xl font-bold text-gray-900">Showcase Gallery</h2>
            <p className="text-sm text-gray-500">
              Share your work and give structured feedback to peers.
            </p>
          </div>
        </div>
        <button
          onClick={() => setShowSubmitForm(!showSubmitForm)}
          className="flex items-center gap-1 px-3 py-2 bg-purple-600 text-white rounded-md text-sm font-medium hover:bg-purple-700"
        >
          <PlusIcon className="h-4 w-4" /> Submit Work
        </button>
      </div>

      {/* Submit form */}
      {showSubmitForm && (
        <div className="bg-white border border-purple-200 rounded-lg p-4 space-y-3">
          <div className="flex justify-between items-center">
            <h3 className="font-medium text-gray-900">Submit to Showcase</h3>
            <button onClick={() => setShowSubmitForm(false)} className="text-gray-400 hover:text-gray-600">
              <XIcon className="h-4 w-4" />
            </button>
          </div>
          <input
            type="text"
            value={newTitle}
            onChange={(e) => setNewTitle(e.target.value)}
            placeholder="Title of your work"
            className="w-full px-3 py-2 border border-gray-300 rounded-md text-sm"
          />
          <textarea
            value={newDescription}
            onChange={(e) => setNewDescription(e.target.value)}
            placeholder="Describe what you made and what you learned..."
            rows={3}
            className="w-full px-3 py-2 border border-gray-300 rounded-md text-sm"
          />
          <input
            type="url"
            value={newArtifactUrl}
            onChange={(e) => setNewArtifactUrl(e.target.value)}
            placeholder="Artifact URL (optional)"
            className="w-full px-3 py-2 border border-gray-300 rounded-md text-sm"
          />
          <button
            onClick={handleSubmitShowcase}
            disabled={!newTitle.trim() || submitting}
            className="px-4 py-2 bg-purple-600 text-white rounded-md text-sm font-medium hover:bg-purple-700 disabled:opacity-50"
          >
            {submitting ? 'Submitting...' : 'Share with Site'}
          </button>
        </div>
      )}

      {/* Gallery */}
      {items.length === 0 ? (
        <div className="bg-gray-50 border border-gray-200 rounded-lg p-8 text-center">
          <ImageIcon className="h-12 w-12 text-gray-300 mx-auto mb-3" />
          <p className="text-gray-500">No showcase submissions yet. Be the first to share!</p>
        </div>
      ) : (
        <div className="grid gap-4 sm:grid-cols-2">
          {items.map((item) => {
            const itemFeedbacks = feedbacks.get(item.id) || [];
            const isOwn = item.learnerId === learnerId;
            const showingFeedback = feedbackTarget === item.id;

            return (
              <div
                key={item.id}
                className="bg-white border border-gray-200 rounded-lg overflow-hidden"
              >
                <div className="p-4">
                  <div className="flex justify-between items-start mb-2">
                    <div>
                      <h3 className="font-medium text-gray-900">{item.title}</h3>
                      <p className="text-xs text-gray-500">
                        by {item.learnerName}
                        {item.createdAt && (
                          <> &middot; {new Date(item.createdAt).toLocaleDateString()}</>
                        )}
                      </p>
                    </div>
                    {item.recognitionCount > 0 && (
                      <span className="flex items-center gap-1 text-xs text-pink-600">
                        <HeartIcon className="h-3 w-3" /> {item.recognitionCount}
                      </span>
                    )}
                  </div>

                  {item.description && (
                    <p className="text-sm text-gray-700 mb-3 line-clamp-3">
                      {item.description}
                    </p>
                  )}

                  {item.artifactUrl && (
                    <a
                      href={item.artifactUrl}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="text-xs text-purple-600 underline"
                    >
                      View Artifact
                    </a>
                  )}

                  {/* Peer feedback section */}
                  {itemFeedbacks.length > 0 && (
                    <div className="mt-3 space-y-2">
                      <p className="text-xs font-medium text-gray-500 flex items-center gap-1">
                        <MessageCircleIcon className="h-3 w-3" /> Feedback ({itemFeedbacks.length})
                      </p>
                      {itemFeedbacks.slice(0, 2).map((fb) => (
                        <div
                          key={fb.id}
                          className="bg-gray-50 rounded-md p-2 text-xs space-y-1"
                        >
                          <p className="font-medium text-gray-700">{fb.fromLearnerName}</p>
                          {fb.iLike && (
                            <p className="text-green-700">
                              <span className="font-medium">I like:</span> {fb.iLike}
                            </p>
                          )}
                          {fb.iWonder && (
                            <p className="text-blue-700">
                              <span className="font-medium">I wonder:</span> {fb.iWonder}
                            </p>
                          )}
                          {fb.nextStep && (
                            <p className="text-amber-700">
                              <span className="font-medium">Next step:</span> {fb.nextStep}
                            </p>
                          )}
                        </div>
                      ))}
                    </div>
                  )}

                  {/* Give feedback button (not on own work) */}
                  {!isOwn && (
                    <div className="mt-3">
                      {showingFeedback ? (
                        <div className="space-y-2 border-t border-gray-100 pt-3">
                          <input
                            type="text"
                            value={fbILike}
                            onChange={(e) => setFbILike(e.target.value)}
                            placeholder="I like..."
                            className="w-full px-2 py-1 border border-gray-300 rounded text-xs"
                          />
                          <input
                            type="text"
                            value={fbIWonder}
                            onChange={(e) => setFbIWonder(e.target.value)}
                            placeholder="I wonder..."
                            className="w-full px-2 py-1 border border-gray-300 rounded text-xs"
                          />
                          <input
                            type="text"
                            value={fbNextStep}
                            onChange={(e) => setFbNextStep(e.target.value)}
                            placeholder="A good next step would be..."
                            className="w-full px-2 py-1 border border-gray-300 rounded text-xs"
                          />
                          <div className="flex gap-2">
                            <button
                              onClick={() => handleSendFeedback(item.id)}
                              disabled={sendingFeedback}
                              className="flex items-center gap-1 px-2 py-1 bg-blue-600 text-white rounded text-xs hover:bg-blue-700 disabled:opacity-50"
                            >
                              <SendIcon className="h-3 w-3" />
                              {sendingFeedback ? 'Sending...' : 'Send'}
                            </button>
                            <button
                              onClick={() => setFeedbackTarget(null)}
                              className="px-2 py-1 bg-gray-100 text-gray-600 rounded text-xs hover:bg-gray-200"
                            >
                              Cancel
                            </button>
                          </div>
                        </div>
                      ) : (
                        <button
                          onClick={() => setFeedbackTarget(item.id)}
                          className="flex items-center gap-1 text-xs text-blue-600 hover:text-blue-800"
                        >
                          <MessageCircleIcon className="h-3 w-3" /> Give Feedback
                        </button>
                      )}
                    </div>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
