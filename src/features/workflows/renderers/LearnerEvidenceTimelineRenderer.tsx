'use client';

/**
 * Learner Evidence Timeline Renderer
 *
 * Unified view of all learner evidence across:
 * - Portfolio items (artifacts, submitted work)
 * - Reflections (metacognitive entries)
 * - Checkpoints (skill checks with explain-it-back)
 * - Proof bundles (ExplainItBack, OralCheck, MiniRebuild)
 * - Mission attempts (submitted work linked to missions)
 *
 * All rendered in reverse chronological order with linking and status indicators.
 */

import React, { useCallback, useEffect, useState } from 'react';
import {
  collection,
  getDocs,
  limit,
  orderBy,
  query,
  where,
  type DocumentData,
  type QueryDocumentSnapshot,
} from 'firebase/firestore';
import { firestore } from '@/src/firebase/client-init';
import { useCapabilities } from '@/src/lib/capabilities/useCapabilities';
import { Spinner } from '@/src/components/ui/Spinner';
import type { CustomRouteRendererProps } from '../customRouteRenderers';
import {
  FileTextIcon,
  CheckCircleIcon,
  BookOpenIcon,
  CheckSquareIcon,
  ShieldCheckIcon,
} from 'lucide-react';

type EvidenceType = 'artifact' | 'reflection' | 'checkpoint' | 'proof_bundle' | 'mission_attempt';

interface GrowthLink {
  id: string;
  capabilityId: string;
  level: number;
  createdAt: string;
}

interface TimelineItem {
  id: string;
  type: EvidenceType;
  title: string;
  description?: string;
  createdAt: string; // ISO string
  status: 'pending' | 'submitted' | 'reviewing' | 'verified';
  pillarCodes: string[];
  capabilityIds: string[];
  aiDisclosureStatus?: string;
  proofStatus?: 'missing' | 'partial' | 'verified';
  linkedItemIds?: string[]; // ref to portfolio item, etc.
  growthTriggered?: GrowthLink[];
  metadata?: Record<string, unknown>;
}

const LEVEL_WORD_TO_NUMBER: Record<string, number> = {
  emerging: 1,
  developing: 2,
  proficient: 3,
  advanced: 4,
};

function normalizeGrowthLevel(value: unknown): number {
  if (typeof value === 'number') return value;
  if (typeof value === 'string') return LEVEL_WORD_TO_NUMBER[value.toLowerCase()] ?? 0;
  return 0;
}

function toIso(val: unknown): string {
  if (!val) return new Date(0).toISOString();
  if (typeof val === 'object' && 'toDate' in (val as Record<string, unknown>)) {
    return ((val as { toDate: () => Date }).toDate()).toISOString();
  }
  if (typeof val === 'string') return val;
  return new Date(0).toISOString();
}

function getEvidenceIcon(type: EvidenceType) {
  switch (type) {
    case 'artifact':
      return <FileTextIcon className="h-5 w-5" />;
    case 'reflection':
      return <BookOpenIcon className="h-5 w-5" />;
    case 'checkpoint':
      return <CheckSquareIcon className="h-5 w-5" />;
    case 'proof_bundle':
      return <ShieldCheckIcon className="h-5 w-5" />;
    case 'mission_attempt':
      return <CheckCircleIcon className="h-5 w-5" />;
    default:
      return <FileTextIcon className="h-5 w-5" />;
  }
}

function getEvidenceColor(type: EvidenceType): string {
  switch (type) {
    case 'artifact':
      return 'bg-blue-50 border-blue-200 text-blue-700';
    case 'reflection':
      return 'bg-purple-50 border-purple-200 text-purple-700';
    case 'checkpoint':
      return 'bg-green-50 border-green-200 text-green-700';
    case 'proof_bundle':
      return 'bg-amber-50 border-amber-200 text-amber-700';
    case 'mission_attempt':
      return 'bg-indigo-50 border-indigo-200 text-indigo-700';
    default:
      return 'bg-gray-50 border-gray-200 text-gray-700';
  }
}

function statusBadge(status: string) {
  if (status === 'verified')
    return <span className="rounded-full bg-green-200 px-2 py-0.5 text-xs font-medium text-green-800">Verified</span>;
  if (status === 'reviewing')
    return <span className="rounded-full bg-blue-200 px-2 py-0.5 text-xs font-medium text-blue-800">Under review</span>;
  if (status === 'submitted')
    return <span className="rounded-full bg-amber-200 px-2 py-0.5 text-xs font-medium text-amber-800">Submitted</span>;
  return <span className="rounded-full bg-gray-200 px-2 py-0.5 text-xs font-medium text-gray-800">Pending</span>;
}

function aiDisclosureBadge(status?: string) {
  if (!status || status === 'learner-ai-not-used') return null;
  if (status === 'learner-ai-verified')
    return <span className="rounded-full bg-indigo-100 px-2 py-0.5 text-xs font-medium text-indigo-800">AI used (verified)</span>;
  if (status === 'learner-ai-verification-gap')
    return <span className="rounded-full bg-amber-100 px-2 py-0.5 text-xs font-medium text-amber-800">AI used (needs check)</span>;
  return <span className="rounded-full bg-gray-100 px-2 py-0.5 text-xs font-medium text-gray-800">{status}</span>;
}

export default function LearnerEvidenceTimelineRenderer({ ctx }: CustomRouteRendererProps) {
  const learnerId = ctx.uid;
  const siteId = ctx.profile?.siteIds?.[0] || ctx.profile?.activeSiteId || '';
  const { resolveTitle } = useCapabilities(siteId || null);

  const [items, setItems] = useState<TimelineItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const loadTimeline = useCallback(async () => {
    if (!learnerId || !siteId) return;
    setLoading(true);
    setError(null);
    try {
      const [portfolioSnap, reflectionsSnap, checkpointsSnap, proofSnap, missionsSnap, growthSnap] = await Promise.all([
        getDocs(
          query(
            collection(firestore, 'portfolioItems'),
            where('learnerId', '==', learnerId),
            orderBy('createdAt', 'desc'),
            limit(50)
          )
        ),
        getDocs(
          query(
            collection(firestore, 'learnerReflections'),
            where('learnerId', '==', learnerId),
            orderBy('createdAt', 'desc'),
            limit(50)
          )
        ),
        getDocs(
          query(
            collection(firestore, 'checkpointHistory'),
            where('learnerId', '==', learnerId),
            orderBy('createdAt', 'desc'),
            limit(50)
          )
        ),
        getDocs(
          query(
            collection(firestore, 'proofOfLearningBundles'),
            where('learnerId', '==', learnerId),
            orderBy('updatedAt', 'desc'),
            limit(50)
          )
        ),
        getDocs(
          query(
            collection(firestore, 'missionAttempts'),
            where('learnerId', '==', learnerId),
            orderBy('submittedAt', 'desc'),
            limit(50)
          )
        ),
        getDocs(
          query(
            collection(firestore, 'capabilityGrowthEvents'),
            where('learnerId', '==', learnerId),
            limit(200)
          )
        ),
      ]);

      // Build growth-event back-links: every capabilityGrowthEvent points to one or more
      // triggering sources (missionAttemptId, checkpointId, linkedPortfolioItemIds). We
      // index them here so each timeline item can surface the growth it caused.
      const growthByMission = new Map<string, GrowthLink[]>();
      const growthByCheckpoint = new Map<string, GrowthLink[]>();
      const growthByPortfolio = new Map<string, GrowthLink[]>();
      const pushGrowth = (map: Map<string, GrowthLink[]>, key: string, link: GrowthLink) => {
        if (!key) return;
        const bucket = map.get(key) ?? [];
        bucket.push(link);
        map.set(key, bucket);
      };
      growthSnap.docs.forEach((d) => {
        const data = d.data();
        const capabilityId = typeof data.capabilityId === 'string' ? data.capabilityId : '';
        if (!capabilityId) return;
        const link: GrowthLink = {
          id: d.id,
          capabilityId,
          level: normalizeGrowthLevel(data.level ?? data.toLevel),
          createdAt: toIso(data.createdAt),
        };
        if (typeof data.missionAttemptId === 'string') pushGrowth(growthByMission, data.missionAttemptId, link);
        if (typeof data.checkpointId === 'string') pushGrowth(growthByCheckpoint, data.checkpointId, link);
        if (Array.isArray(data.linkedPortfolioItemIds)) {
          for (const pid of data.linkedPortfolioItemIds) {
            if (typeof pid === 'string') pushGrowth(growthByPortfolio, pid, link);
          }
        }
      });

      // Build proof bundle map for quick lookup
      const proofByItem = new Map<string, QueryDocumentSnapshot<DocumentData>>();
      proofSnap.docs.forEach((d) => {
        const data = d.data();
        if (data.portfolioItemId) {
          proofByItem.set(data.portfolioItemId, d);
        }
      });

      const timelineItems: TimelineItem[] = [];

      // Portfolio items
      portfolioSnap.docs.forEach((d) => {
        const data = d.data();
        const proofDoc = proofByItem.get(d.id);
        const proofData = proofDoc?.data();

        timelineItems.push({
          id: d.id,
          type: (data.source as EvidenceType) || 'artifact',
          title: data.title || 'Untitled artifact',
          description: data.description,
          createdAt: toIso(data.createdAt),
          status: ((data.verificationStatus as string) || 'pending') as 'pending' | 'submitted' | 'reviewing' | 'verified',
          pillarCodes: data.pillarCodes || [],
          capabilityIds: data.capabilityIds || [],
          aiDisclosureStatus: data.aiDisclosureStatus,
          proofStatus: proofData?.verificationStatus || 'missing',
          linkedItemIds: proofData ? [proofData.id] : [],
          growthTriggered: growthByPortfolio.get(d.id),
          metadata: {
            artifacts: data.artifacts,
            source: data.source,
          },
        });
      });

      // Reflections
      reflectionsSnap.docs.forEach((d) => {
        const data = d.data();
        const proudOfText = data.proudOf || 'Reflection';
        timelineItems.push({
          id: d.id,
          type: 'reflection',
          title: `Reflection: ${proudOfText.slice(0, 50)}${proudOfText.length > 50 ? '…' : ''}`,
          description: `Proud of: ${data.proudOf}\nNext: ${data.nextIWill}`,
          createdAt: toIso(data.createdAt),
          status: 'submitted' as const,
          pillarCodes: [],
          capabilityIds: data.capabilityIds || [],
          aiDisclosureStatus: data.aiAssistanceUsed ? 'learner-ai-verified' : 'learner-ai-not-used',
          metadata: {
            effortLevel: data.effortLevel,
            enjoymentLevel: data.enjoymentLevel,
            strategy: data.effectiveStrategy,
          },
        });
      });

      // Checkpoints
      checkpointsSnap.docs.forEach((d) => {
        const data = d.data();
        timelineItems.push({
          id: d.id,
          type: 'checkpoint',
          title: data.missionTitle ? `Checkpoint: ${data.missionTitle}` : 'Checkpoint',
          description: data.answer,
          createdAt: toIso(data.createdAt),
          status: (data.isCorrect ? 'verified' : (data.status as string) || 'submitted') as 'pending' | 'submitted' | 'reviewing' | 'verified',
          pillarCodes: [],
          capabilityIds: data.capabilityId ? [data.capabilityId] : [],
          aiDisclosureStatus: data.aiAssistanceUsed ? 'learner-ai-verified' : 'learner-ai-not-used',
          growthTriggered: growthByCheckpoint.get(d.id),
          metadata: {
            answer: data.answer,
            explainItBack: data.explainItBack,
            isCorrect: data.isCorrect,
            feedback: data.feedback,
          },
        });
      });

      // Mission attempts
      missionsSnap.docs.forEach((d) => {
        const data = d.data();
        timelineItems.push({
          id: d.id,
          type: 'mission_attempt',
          title: data.missionTitle || 'Mission attempt',
          description: data.content,
          createdAt: toIso(data.submittedAt || data.startedAt || data.createdAt),
          status: ((data.reviewStatus as string) || (data.status as string) || 'submitted') as 'pending' | 'submitted' | 'reviewing' | 'verified',
          pillarCodes: [],
          capabilityIds: data.capabilityIds || [],
          growthTriggered: growthByMission.get(d.id),
          metadata: {
            missionId: data.missionId,
            status: data.status,
            reviewStatus: data.reviewStatus,
          },
        });
      });

      // Sort by date descending (newest first)
      timelineItems.sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());

      setItems(timelineItems);
    } catch (err) {
      console.error('Failed to load evidence timeline:', err);
      setError('Failed to load evidence. Please try again.');
    } finally {
      setLoading(false);
    }
  }, [learnerId, siteId]);

  useEffect(() => {
    void loadTimeline();
  }, [loadTimeline]);

  if (loading) {
    return (
      <div className="flex min-h-[240px] items-center justify-center">
        <div className="flex items-center gap-2 text-app-muted">
          <Spinner />
          <span>Loading evidence timeline...</span>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="rounded-lg border border-red-200 bg-red-50 p-4 text-sm text-red-800">
        {error}
        <button onClick={() => void loadTimeline()} className="ml-3 underline">
          Retry
        </button>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <header className="rounded-xl border border-app bg-app-surface-raised p-4">
        <h1 className="text-2xl font-bold text-app-foreground">My Evidence Timeline</h1>
        <p className="mt-1 text-sm text-app-muted">
          All your learning evidence in one place — artifacts, reflections, checkpoints, and proof of learning.
        </p>
      </header>

      {items.length === 0 ? (
        <div className="rounded-lg border border-dashed border-app bg-app-surface p-8 text-center text-sm text-app-muted">
          <p>No evidence submitted yet.</p>
          <p className="mt-1 text-xs">Submit artifacts, write reflections, or complete checkpoints to build your evidence timeline.</p>
        </div>
      ) : (
        <div className="space-y-3">
          {/* Timeline */}
          <div className="relative space-y-4 pl-8">
            {/* Vertical line */}
            <div className="absolute left-3 top-2 bottom-0 w-0.5 bg-app-surface" />

            {items.map((item) => (
              <div key={item.id} className="relative">
                {/* Timeline dot */}
                <div className="absolute -left-6 top-2 h-6 w-6 rounded-full border-2 border-app bg-white flex items-center justify-center text-app-foreground">
                  {getEvidenceIcon(item.type)}
                </div>

                {/* Card */}
                <div
                  className={`rounded-lg border ${getEvidenceColor(item.type)} p-4 space-y-2`}
                  data-testid={`evidence-item-${item.id}`}
                >
                  {/* Header */}
                  <div className="flex items-start justify-between gap-2">
                    <div className="flex-1 min-w-0">
                      <h3 className="font-medium text-app-foreground truncate">{item.title}</h3>
                      {item.description && (
                        <p className="mt-1 text-sm text-app-muted line-clamp-2">{item.description}</p>
                      )}
                    </div>
                    <div className="flex flex-col gap-1 shrink-0 items-end text-xs">
                      {statusBadge(item.status)}
                      {aiDisclosureBadge(item.aiDisclosureStatus)}
                      {item.proofStatus && item.proofStatus !== 'missing' && (
                        <span className={`rounded-full px-2 py-0.5 font-medium ${
                          item.proofStatus === 'verified'
                            ? 'bg-green-200 text-green-800'
                            : 'bg-amber-200 text-amber-800'
                        }`}>
                          PoL {item.proofStatus}
                        </span>
                      )}
                    </div>
                  </div>

                  {/* Metadata */}
                  <div className="pt-2 border-t border-current border-opacity-10 text-xs text-app-muted flex flex-wrap gap-2">
                    <span>{new Date(item.createdAt).toLocaleDateString()}</span>
                    {item.capabilityIds.length > 0 && (
                      <span>Capabilities: {item.capabilityIds.map((cid) => resolveTitle(cid)).join(', ')}</span>
                    )}
                    {item.pillarCodes.length > 0 && (
                      <span>Pillars: {item.pillarCodes.join(', ')}</span>
                    )}
                  </div>

                  {item.growthTriggered && item.growthTriggered.length > 0 && (
                    <div
                      className="mt-2 rounded-md border border-emerald-200 bg-emerald-50 p-2 text-xs text-emerald-800"
                      data-testid={`growth-triggered-${item.id}`}
                    >
                      <div className="font-semibold">Triggered capability growth</div>
                      <ul className="mt-1 space-y-0.5">
                        {item.growthTriggered.map((g) => (
                          <li key={g.id}>
                            {resolveTitle(g.capabilityId)}
                            {g.level > 0 ? ` — now Level ${g.level}/4` : ''}
                          </li>
                        ))}
                      </ul>
                    </div>
                  )}
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
