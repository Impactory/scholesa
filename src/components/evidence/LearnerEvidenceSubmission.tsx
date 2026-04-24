'use client';

import { useCallback, useEffect, useMemo, useState } from 'react';
import {
  addDoc,
  doc,
  getDocs,
  orderBy,
  query,
  serverTimestamp,
  updateDoc,
  where,
  limit,
} from 'firebase/firestore';
import { useAuthContext } from '@/src/firebase/auth/AuthProvider';
import {
  portfolioItemsCollection,
  learnerReflectionsCollection,
  missionsCollection,
  missionAttemptsCollection,
} from '@/src/firebase/firestore/collections';
import { resolveActiveSiteId } from '@/src/lib/auth/activeSite';
import { useCapabilities } from '@/src/lib/capabilities/useCapabilities';
import { RoleRouteGuard } from '@/src/components/auth/RoleRouteGuard';
import { Spinner } from '@/src/components/ui/Spinner';
import type { PortfolioItem, LearnerReflection, Mission, PillarCode } from '@/src/types/schema';

type SubmitTab = 'artifact' | 'reflection' | 'checkpoint';

interface PortfolioEntry {
  id: string;
  title: string;
  description: string;
  artifacts: string[];
  capabilityTitles: string[];
  aiAssistanceUsed: boolean;
  verificationStatus?: string;
  proofOfLearningStatus?: string;
}

interface RevisionHistoryDisplay {
  round: number;
  educatorFeedback: string;
  previousContent: string;
  requestedAt: Date | null;
  resubmittedContent?: string;
  resubmittedAt?: Date | null;
}

interface RevisionItem {
  id: string;
  missionId: string;
  missionTitle: string;
  content: string;
  revisionFeedback: string;
  revisionRequestedAt: Date | null;
  revisionRound: number;
  revisionHistory: RevisionHistoryDisplay[];
  attachmentUrls: string[];
  aiAssistanceUsed: boolean;
  aiAssistanceDetails?: string;
}

export function LearnerEvidenceSubmission() {
  const { user, profile, loading: authLoading } = useAuthContext();
  const siteId = resolveActiveSiteId(profile);
  const learnerId = user?.uid ?? null;

  const { capabilityList: capabilities, resolveTitle } = useCapabilities(siteId);
  const [activeTab, setActiveTab] = useState<SubmitTab>('artifact');
  const [portfolio, setPortfolio] = useState<PortfolioEntry[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);
  const [submitError, setSubmitError] = useState<string | null>(null);

  // Artifact form state
  const [artifactTitle, setArtifactTitle] = useState('');
  const [artifactDescription, setArtifactDescription] = useState('');
  const [artifactUrl, setArtifactUrl] = useState('');
  const [selectedCapabilityIds, setSelectedCapabilityIds] = useState<string[]>([]);
  const [selectedPillarCodes, setSelectedPillarCodes] = useState<PillarCode[]>([]);
  const [aiUsed, setAiUsed] = useState(false);
  const [aiDetails, setAiDetails] = useState('');

  // Reflection form state
  const [reflectionContent, setReflectionContent] = useState('');
  const [reflectionCapabilityIds, setReflectionCapabilityIds] = useState<string[]>([]);
  const [reflectionAiUsed, setReflectionAiUsed] = useState(false);
  const [reflectionAiDetails, setReflectionAiDetails] = useState('');

  // Checkpoint form state
  const [missions, setMissions] = useState<Mission[]>([]);
  const [checkpointMissionId, setCheckpointMissionId] = useState('');
  const [checkpointContent, setCheckpointContent] = useState('');
  const [checkpointAttachmentUrl, setCheckpointAttachmentUrl] = useState('');
  const [checkpointAiUsed, setCheckpointAiUsed] = useState(false);
  const [checkpointAiDetails, setCheckpointAiDetails] = useState('');

  // Revision resubmission state
  const [revisions, setRevisions] = useState<RevisionItem[]>([]);
  const [revisionEdits, setRevisionEdits] = useState<Record<string, string>>({});
  const [resubmitting, setResubmitting] = useState<string | null>(null);

  // Derive pillar codes from selected capabilities
  const derivedPillarCodes = useMemo(() => {
    const codes = new Set<PillarCode>();
    for (const capId of selectedCapabilityIds) {
      const cap = capabilities.find((c) => c.id === capId);
      if (cap) codes.add(cap.pillarCode);
    }
    return Array.from(codes);
  }, [selectedCapabilityIds, capabilities]);

  // Load learner's own portfolio items
  const loadPortfolio = useCallback(async () => {
    if (!learnerId || !siteId) {
      setPortfolio([]);
      setLoading(false);
      return;
    }

    setLoading(true);
    try {
      const snap = await getDocs(
        query(
          portfolioItemsCollection,
          where('learnerId', '==', learnerId),
          where('siteId', '==', siteId),
          orderBy('createdAt', 'desc'),
          limit(20)
        )
      );
      setPortfolio(
        snap.docs.map((d) => {
          const data = d.data();
          return {
            id: d.id,
            title: data.title,
            description: data.description,
            artifacts: data.artifacts ?? [],
            capabilityTitles: (data.capabilityIds ?? []).map(
              (cid: string) => resolveTitle(cid)
            ),
            aiAssistanceUsed: data.aiAssistanceUsed ?? false,
            verificationStatus: data.verificationStatus,
            proofOfLearningStatus: data.proofOfLearningStatus,
          };
        })
      );
    } catch (err) {
      console.error('Failed to load portfolio', err);
      alert('Failed to load data. Please try again.');
    } finally {
      setLoading(false);
    }
  }, [learnerId, siteId, resolveTitle]);

  // Load missionAttempts with status 'revision' for the current learner
  const loadRevisions = useCallback(async () => {
    if (!learnerId || !siteId) {
      setRevisions([]);
      return;
    }

    try {
      const snap = await getDocs(
        query(
          missionAttemptsCollection,
          where('learnerId', '==', learnerId),
          where('siteId', '==', siteId),
          where('status', '==', 'revision'),
          orderBy('updatedAt', 'desc'),
          limit(20)
        )
      );
      const items: RevisionItem[] = snap.docs.map((d) => {
        const data = d.data() as unknown as Record<string, unknown>;
        const reqAt = data.revisionRequestedAt as { toDate?: () => Date } | undefined;
        const toDate = (v: unknown): Date | null => {
          if (!v) return null;
          const ts = v as { toDate?: () => Date };
          return ts.toDate?.() ?? null;
        };
        const rawHistory = Array.isArray(data.revisionHistory) ? data.revisionHistory : [];
        const history: RevisionHistoryDisplay[] = (rawHistory as Record<string, unknown>[]).map((entry) => ({
          round: typeof entry.round === 'number' ? entry.round : 0,
          educatorFeedback: typeof entry.educatorFeedback === 'string' ? entry.educatorFeedback : '',
          previousContent: typeof entry.previousContent === 'string' ? entry.previousContent : '',
          requestedAt: toDate(entry.requestedAt),
          resubmittedContent: typeof entry.resubmittedContent === 'string' ? entry.resubmittedContent : undefined,
          resubmittedAt: entry.resubmittedAt ? toDate(entry.resubmittedAt) : undefined,
        }));
        return {
          id: d.id,
          missionId: (data.missionId as string) ?? '',
          missionTitle: (data.missionTitle as string) ?? 'Untitled',
          content: (data.content as string) ?? '',
          revisionFeedback: (data.revisionFeedback as string) ?? '',
          revisionRequestedAt: reqAt?.toDate?.() ?? null,
          revisionRound: typeof data.revisionRound === 'number' ? data.revisionRound : 0,
          revisionHistory: history,
          attachmentUrls: (data.attachmentUrls as string[]) ?? [],
          aiAssistanceUsed: Boolean(data.aiAssistanceUsed),
          aiAssistanceDetails: (data.aiAssistanceDetails as string) ?? undefined,
        };
      });
      setRevisions(items);
      // Pre-fill edit buffers with existing content
      const edits: Record<string, string> = {};
      for (const item of items) {
        if (!revisionEdits[item.id]) {
          edits[item.id] = item.content;
        }
      }
      if (Object.keys(edits).length > 0) {
        setRevisionEdits((prev) => ({ ...edits, ...prev }));
      }
    } catch (err) {
      console.error('Failed to load revisions', err);
    }
  }, [learnerId, siteId, revisionEdits]);

  // Resubmit a revised missionAttempt
  const handleResubmit = async (revisionId: string) => {
    const newContent = revisionEdits[revisionId]?.trim();
    if (!newContent || !learnerId || !siteId) return;
    setResubmitting(revisionId);
    setSuccessMessage(null);
    setSubmitError(null);
    try {
      // Read current doc to get the history array so we can stamp the resubmission
      const revItem = revisions.find((r) => r.id === revisionId);
      const updatedHistory = revItem?.revisionHistory
        ? revItem.revisionHistory.map((entry, i, arr) => {
            if (i === arr.length - 1) {
              // Stamp the most recent entry with the resubmission
              return {
                ...entry,
                resubmittedContent: newContent,
                resubmittedAt: serverTimestamp(),
              };
            }
            return entry;
          })
        : [];

      const updatePayload: Record<string, unknown> = {
        status: 'submitted',
        content: newContent,
        revisionFeedback: '',
        updatedAt: serverTimestamp(),
        submittedAt: serverTimestamp(),
      };
      if (updatedHistory.length > 0) {
        updatePayload.revisionHistory = updatedHistory;
      }

      await updateDoc(doc(missionAttemptsCollection, revisionId), updatePayload);

      // Sync linked portfolioItem so portfolio reflects the revised content
      try {
        const linkedSnap = await getDocs(
          query(
            portfolioItemsCollection,
            where('missionAttemptId', '==', revisionId),
            where('siteId', '==', siteId),
            limit(1)
          )
        );
        if (!linkedSnap.empty) {
          const piDoc = linkedSnap.docs[0];
          await updateDoc(doc(portfolioItemsCollection, piDoc.id), {
            description: newContent,
            verificationStatus: 'pending',
            updatedAt: serverTimestamp(),
          } as Partial<PortfolioItem>);
        }
      } catch (err) {
        // Non-critical — portfolio sync failure shouldn't block the resubmission
        console.warn('Failed to sync linked portfolio item:', err);
      }

      setSuccessMessage('Revision resubmitted for review!');
      setRevisionEdits((prev) => {
        const next = { ...prev };
        delete next[revisionId];
        return next;
      });
      await loadRevisions();
      void loadPortfolio();
    } catch (err) {
      console.error('Failed to resubmit revision', err);
      setSubmitError('Failed to resubmit. Please try again.');
    } finally {
      setResubmitting(null);
    }
  };

  useEffect(() => {
    if (!authLoading && learnerId && siteId) {
      void loadPortfolio();
      void loadRevisions();
    }
  }, [authLoading, learnerId, siteId, loadPortfolio, loadRevisions]);

  // Load missions for checkpoint selector
  useEffect(() => {
    if (!siteId) return;
    void (async () => {
      try {
        const snap = await getDocs(query(missionsCollection, where('siteId', '==', siteId), limit(100)));
        setMissions(snap.docs.map((d) => ({ ...d.data(), id: d.id } as Mission)));
      } catch (err) {
        console.error('Failed to load missions', err);
        alert('Failed to load missions. Please try again.');
      }
    })();
  }, [siteId]);

  // Artifact submission
  const handleSubmitArtifact = async () => {
    if (!learnerId || !siteId || !artifactTitle.trim()) return;
    if (selectedCapabilityIds.length === 0) {
      setSubmitError('Select at least one capability before submitting portfolio evidence.');
      return;
    }
    setSaving(true);
    setSuccessMessage(null);
    setSubmitError(null);
    try {
      const artifacts = artifactUrl.trim() ? [artifactUrl.trim()] : [];
      const pillarCodes = derivedPillarCodes.length > 0 ? derivedPillarCodes : selectedPillarCodes;

      await addDoc(portfolioItemsCollection, {
        learnerId,
        siteId,
        title: artifactTitle.trim(),
        description: artifactDescription.trim(),
        pillarCodes,
        artifacts,
        capabilityIds: selectedCapabilityIds,
        capabilityTitles: selectedCapabilityIds.map((cid) => resolveTitle(cid)),
        aiAssistanceUsed: aiUsed,
        aiAssistanceDetails: aiUsed ? aiDetails.trim() : undefined,
        aiDisclosureStatus: aiUsed ? 'learner-ai-verified' : 'learner-ai-not-used',
        verificationStatus: 'pending' as const,
        proofOfLearningStatus: 'not-available' as const,
        source: 'learner_submission',
        createdAt: serverTimestamp(),
      } as unknown as Omit<PortfolioItem, 'id'>);

      setSuccessMessage('Artifact submitted to your portfolio!');
      setArtifactTitle('');
      setArtifactDescription('');
      setArtifactUrl('');
      setSelectedCapabilityIds([]);
      setSelectedPillarCodes([]);
      setAiUsed(false);
      setAiDetails('');

      void loadPortfolio();
    } catch (err) {
      console.error('Failed to submit artifact', err);
      setSubmitError('Failed to submit artifact. Please try again.');
    } finally {
      setSaving(false);
    }
  };

  // Reflection submission
  const handleSubmitReflection = async () => {
    if (!learnerId || !siteId || !reflectionContent.trim()) return;
    if (reflectionCapabilityIds.length === 0) {
      setSubmitError('Select at least one capability before saving a reflection to your evidence portfolio.');
      return;
    }
    setSaving(true);
    setSuccessMessage(null);
    setSubmitError(null);
    try {
      // Create portfolio item first so reflection can reference it
      const reflectionPillarCodes: PillarCode[] = [];
      const reflectionArtifacts: string[] = [];
      const portfolioRef = await addDoc(portfolioItemsCollection, {
        learnerId,
        siteId,
        title: `Reflection: ${reflectionContent.trim().slice(0, 60)}${reflectionContent.trim().length > 60 ? '…' : ''}`,
        description: reflectionContent.trim(),
        pillarCodes: reflectionPillarCodes,
        artifacts: reflectionArtifacts,
        capabilityIds: reflectionCapabilityIds,
        capabilityTitles: reflectionCapabilityIds.map((cid) => resolveTitle(cid)),
        reflectionIds: [] as string[],
        aiAssistanceUsed: reflectionAiUsed,
        aiAssistanceDetails: reflectionAiUsed ? reflectionAiDetails.trim() : undefined,
        aiDisclosureStatus: reflectionAiUsed ? 'learner-ai-verified' : 'learner-ai-not-used',
        verificationStatus: 'pending' as const,
        proofOfLearningStatus: 'not-available' as const,
        source: 'reflection',
        createdAt: serverTimestamp(),
      } as unknown as Omit<PortfolioItem, 'id'>);

      // Create reflection linked to the portfolio item
      const reflectionDoc = await addDoc(learnerReflectionsCollection, {
        learnerId,
        siteId,
        content: reflectionContent.trim(),
        portfolioItemId: portfolioRef.id,
        capabilityIds: reflectionCapabilityIds,
        aiAssistanceUsed: reflectionAiUsed,
        aiAssistanceDetails: reflectionAiUsed ? reflectionAiDetails.trim() : undefined,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      } as unknown as Omit<LearnerReflection, 'id'>);

      await updateDoc(portfolioRef, {
        reflectionIds: [reflectionDoc.id],
        updatedAt: serverTimestamp(),
      });

      setSuccessMessage('Reflection saved!');
      setReflectionContent('');
      setReflectionCapabilityIds([]);
      setReflectionAiUsed(false);
      setReflectionAiDetails('');

      void loadPortfolio();
    } catch (err) {
      console.error('Failed to save reflection', err);
      setSubmitError('Failed to save reflection. Please try again.');
    } finally {
      setSaving(false);
    }
  };

  // Checkpoint evidence submission
  const handleSubmitCheckpoint = async () => {
    if (!learnerId || !siteId || !checkpointMissionId || !checkpointContent.trim()) return;
    setSaving(true);
    setSuccessMessage(null);
    setSubmitError(null);
    try {
      const mission = missions.find((m) => m.id === checkpointMissionId);
      const capIds = mission?.capabilityIds ?? [];
      if (capIds.length === 0) {
        setSubmitError('This checkpoint is not linked to a capability yet. Ask HQ or your educator to map it before submitting evidence.');
        setSaving(false);
        return;
      }
      const pillarCodes = mission?.pillarCodes ?? [];
      const attachmentUrls = checkpointAttachmentUrl.trim()
        ? [checkpointAttachmentUrl.trim()]
        : [];

      // Create mission attempt
      const attemptRef = await addDoc(missionAttemptsCollection, {
        learnerId,
        missionId: checkpointMissionId,
        missionTitle: mission?.title ?? '',
        siteId,
        status: 'submitted' as const,
        content: checkpointContent.trim(),
        attachmentUrls,
        aiAssistanceUsed: checkpointAiUsed,
        aiAssistanceDetails: checkpointAiUsed ? checkpointAiDetails.trim() : undefined,
        aiDisclosureStatus: checkpointAiUsed ? 'learner-ai-verified' : 'learner-ai-not-used',
        submittedAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      });

      // Also add to portfolio for visibility — linked to the mission attempt
      await addDoc(portfolioItemsCollection, {
        learnerId,
        siteId,
        title: `Checkpoint: ${mission?.title ?? 'Unknown'}`,
        description: checkpointContent.trim(),
        pillarCodes,
        artifacts: attachmentUrls,
        capabilityIds: capIds,
        capabilityTitles: capIds.map((cid: string) => resolveTitle(cid)),
        missionAttemptId: attemptRef.id,
        aiAssistanceUsed: checkpointAiUsed,
        aiAssistanceDetails: checkpointAiUsed ? checkpointAiDetails.trim() : undefined,
        aiDisclosureStatus: checkpointAiUsed ? 'learner-ai-verified' : 'learner-ai-not-used',
        verificationStatus: 'pending' as const,
        proofOfLearningStatus: 'not-available' as const,
        source: 'checkpoint_submission',
        createdAt: serverTimestamp(),
      } as unknown as Omit<PortfolioItem, 'id'>);

      setSuccessMessage('Checkpoint evidence submitted!');
      setCheckpointMissionId('');
      setCheckpointContent('');
      setCheckpointAttachmentUrl('');
      setCheckpointAiUsed(false);
      setCheckpointAiDetails('');

      void loadPortfolio();
    } catch (err) {
      console.error('Failed to submit checkpoint evidence', err);
      setSubmitError('Failed to submit checkpoint evidence. Please try again.');
    } finally {
      setSaving(false);
    }
  };

  // Auto-clear success message
  useEffect(() => {
    if (!successMessage) return;
    const timeout = setTimeout(() => setSuccessMessage(null), 4000);
    return () => clearTimeout(timeout);
  }, [successMessage]);

  if (authLoading) {
    return (
      <div className="flex min-h-[240px] items-center justify-center">
        <Spinner />
      </div>
    );
  }

  if (!siteId || !learnerId) {
    return (
      <div
        data-testid="learner-evidence-site-required"
        className="rounded-xl border border-amber-200 bg-amber-50 p-6 text-sm text-amber-900"
      >
        Select an active site before submitting learner evidence or viewing your portfolio.
      </div>
    );
  }

  const selectedCheckpointMission = missions.find((m) => m.id === checkpointMissionId) ?? null;
  const selectedCheckpointMissionHasCapabilities =
    (selectedCheckpointMission?.capabilityIds?.length ?? 0) > 0;

  const canSubmitArtifact =
    artifactTitle.trim().length > 0 && selectedCapabilityIds.length > 0 && !saving;
  const canSubmitReflection =
    reflectionContent.trim().length > 0 && reflectionCapabilityIds.length > 0 && !saving;
  const canSubmitCheckpoint =
    checkpointMissionId.length > 0 &&
    checkpointContent.trim().length > 0 &&
    selectedCheckpointMissionHasCapabilities &&
    !saving;

  const statusBadge = (status?: string) => {
    if (!status || status === 'pending') return <span className="rounded bg-yellow-100 px-1.5 py-0.5 text-xs font-medium text-yellow-800">Pending review</span>;
    if (status === 'reviewed') return <span className="rounded bg-blue-100 px-1.5 py-0.5 text-xs font-medium text-blue-800">Reviewed</span>;
    if (status === 'verified') return <span className="rounded bg-green-100 px-1.5 py-0.5 text-xs font-medium text-green-800">Verified</span>;
    return <span className="rounded bg-gray-100 px-1.5 py-0.5 text-xs font-medium text-gray-700">{status}</span>;
  };

  const polBadge = (status?: string) => {
    if (!status || status === 'not-available') return null;
    if (status === 'verified') return <span className="rounded bg-green-100 px-1.5 py-0.5 text-xs font-medium text-green-800">PoL verified</span>;
    if (status === 'partial') return <span className="rounded bg-amber-100 px-1.5 py-0.5 text-xs font-medium text-amber-800">PoL partial</span>;
    if (status === 'missing') return <span className="rounded bg-red-100 px-1.5 py-0.5 text-xs font-medium text-red-800">PoL needed</span>;
    return null;
  };

  return (
    <RoleRouteGuard allowedRoles={['learner']}>
      <section className="space-y-4" data-testid="learner-evidence-page">
        <header className="rounded-xl border border-app bg-app-surface-raised p-4">
          <h1 className="text-xl font-bold text-app-foreground">My Portfolio & Evidence</h1>
          <p className="mt-1 text-sm text-app-muted">
            Submit artifacts from your work, write reflections, and build your portfolio of capability evidence.
          </p>
        </header>

        {successMessage && (
          <div className="rounded-lg border border-green-200 bg-green-50 px-4 py-2 text-sm font-medium text-green-800" data-testid="submission-success">
            {successMessage}
          </div>
        )}

        {submitError && (
          <div className="rounded-lg border border-red-200 bg-red-50 px-4 py-2 text-sm font-medium text-red-800" data-testid="submission-error">
            {submitError}
          </div>
        )}

        {/* Revisions needing attention */}
        {revisions.length > 0 && (
          <div className="rounded-xl border border-amber-300 bg-amber-50 p-4 space-y-3" data-testid="revision-queue">
            <div className="flex items-center gap-2">
              <span className="rounded bg-amber-200 px-2 py-0.5 text-xs font-bold uppercase tracking-wide text-amber-900">
                {revisions.length} revision{revisions.length !== 1 ? 's' : ''} needed
              </span>
              <span className="text-sm text-amber-800">
                Your educator has asked you to revise and resubmit
              </span>
            </div>

            {revisions.map((rev) => (
              <div
                key={rev.id}
                className="rounded-lg border border-amber-200 bg-white p-4 space-y-3"
                data-testid={`revision-item-${rev.id}`}
              >
                <div className="flex items-start justify-between gap-2">
                  <div>
                    <h3 className="text-sm font-semibold text-app-foreground">{rev.missionTitle}</h3>
                    {rev.revisionRequestedAt && (
                      <span className="text-xs text-app-muted">
                        Requested {rev.revisionRequestedAt.toLocaleDateString()}
                      </span>
                    )}
                  </div>
                  <span className="shrink-0 rounded bg-amber-100 px-1.5 py-0.5 text-xs font-medium text-amber-800">
                    {rev.revisionRound > 1 ? `Round ${rev.revisionRound}` : 'Needs revision'}
                  </span>
                </div>

                {/* Educator feedback */}
                <div className="rounded-md border border-blue-200 bg-blue-50 p-3">
                  <span className="text-xs font-semibold uppercase tracking-wide text-blue-600">
                    Educator feedback
                  </span>
                  <p className="mt-1 text-sm text-blue-900">{rev.revisionFeedback}</p>
                </div>

                {/* Prior revision rounds */}
                {rev.revisionHistory.length > 1 && (
                  <details className="rounded-md border border-gray-200 bg-gray-50">
                    <summary className="cursor-pointer px-3 py-2 text-xs font-medium text-app-muted">
                      Previous rounds ({rev.revisionHistory.length - 1})
                    </summary>
                    <div className="space-y-2 px-3 pb-3">
                      {rev.revisionHistory.slice(0, -1).map((entry) => (
                        <div key={entry.round} className="rounded border border-gray-100 bg-white p-2 space-y-1">
                          <span className="text-xs font-medium text-app-muted">Round {entry.round}</span>
                          <p className="text-xs text-blue-700">Feedback: {entry.educatorFeedback}</p>
                          {entry.resubmittedContent && (
                            <p className="text-xs text-green-700">Your revision: {entry.resubmittedContent}</p>
                          )}
                        </div>
                      ))}
                    </div>
                  </details>
                )}

                {/* Original submission preview */}
                {rev.content && (
                  <div className="rounded-md border border-gray-200 bg-gray-50 p-3">
                    <span className="text-xs font-medium text-app-muted">Your current submission</span>
                    <p className="mt-1 text-sm text-app-foreground line-clamp-3">{rev.content}</p>
                  </div>
                )}

                {/* Revision editor */}
                <label className="block space-y-1">
                  <span className="text-xs font-medium text-app-muted">Your revised response *</span>
                  <textarea
                    data-testid={`revision-editor-${rev.id}`}
                    value={revisionEdits[rev.id] ?? rev.content}
                    onChange={(e) =>
                      setRevisionEdits((prev) => ({ ...prev, [rev.id]: e.target.value }))
                    }
                    className="w-full rounded-md border border-app bg-app-canvas px-3 py-2 text-sm text-app-foreground min-h-28"
                    placeholder="Revise your work based on the feedback above..."
                  />
                </label>

                <button
                  type="button"
                  data-testid={`revision-submit-${rev.id}`}
                  disabled={
                    resubmitting === rev.id ||
                    !(revisionEdits[rev.id]?.trim()) ||
                    revisionEdits[rev.id]?.trim() === rev.content.trim()
                  }
                  onClick={() => void handleResubmit(rev.id)}
                  className="rounded-md bg-amber-600 px-4 py-2 text-sm font-semibold text-white hover:bg-amber-700 disabled:opacity-50"
                >
                  {resubmitting === rev.id ? 'Resubmitting...' : 'Resubmit for Review'}
                </button>
              </div>
            ))}
          </div>
        )}

        {/* Tab selector */}
        <div className="flex gap-1 rounded-lg bg-app-surface p-1" data-testid="submission-tabs">
          <button
            type="button"
            onClick={() => setActiveTab('artifact')}
            className={`flex-1 rounded-md px-3 py-2 text-sm font-medium transition-colors ${
              activeTab === 'artifact'
                ? 'bg-primary text-primary-foreground'
                : 'text-app-muted hover:text-app-foreground'
            }`}
          >
            Submit Artifact
          </button>
          <button
            type="button"
            onClick={() => setActiveTab('reflection')}
            className={`flex-1 rounded-md px-3 py-2 text-sm font-medium transition-colors ${
              activeTab === 'reflection'
                ? 'bg-primary text-primary-foreground'
                : 'text-app-muted hover:text-app-foreground'
            }`}
          >
            Write Reflection
          </button>
          <button
            type="button"
            onClick={() => setActiveTab('checkpoint')}
            className={`flex-1 rounded-md px-3 py-2 text-sm font-medium transition-colors ${
              activeTab === 'checkpoint'
                ? 'bg-primary text-primary-foreground'
                : 'text-app-muted hover:text-app-foreground'
            }`}
          >
            Checkpoint Evidence
          </button>
        </div>

        {/* Artifact submission form */}
        {activeTab === 'artifact' && (
          <div className="rounded-xl border border-app bg-app-surface-raised p-4 space-y-3" data-testid="artifact-form">
            <h2 className="text-sm font-semibold text-app-foreground">New Artifact</h2>

            <label className="block space-y-1">
              <span className="text-xs font-medium text-app-muted">Title *</span>
              <input
                data-testid="artifact-title"
                type="text"
                value={artifactTitle}
                onChange={(e) => setArtifactTitle(e.target.value)}
                placeholder="e.g., 'My Solar System Model' or 'Community Garden Plan'"
                className="w-full rounded-md border border-app bg-app-canvas px-3 py-2 text-sm text-app-foreground"
              />
            </label>

            <label className="block space-y-1">
              <span className="text-xs font-medium text-app-muted">What did you create and what did you learn?</span>
              <textarea
                data-testid="artifact-description"
                value={artifactDescription}
                onChange={(e) => setArtifactDescription(e.target.value)}
                placeholder="Describe your work, what you built, and what you learned..."
                className="w-full rounded-md border border-app bg-app-canvas px-3 py-2 text-sm text-app-foreground min-h-24"
              />
            </label>

            <label className="block space-y-1">
              <span className="text-xs font-medium text-app-muted">Link to your work (optional)</span>
              <input
                data-testid="artifact-url"
                type="url"
                value={artifactUrl}
                onChange={(e) => setArtifactUrl(e.target.value)}
                placeholder="https://docs.google.com/... or https://github.com/..."
                className="w-full rounded-md border border-app bg-app-canvas px-3 py-2 text-sm text-app-foreground"
              />
            </label>

            {/* Capability selection */}
            <fieldset className="space-y-1">
              <legend className="text-xs font-medium text-app-muted">Which capabilities does this show? *</legend>
              {capabilities.length > 0 ? (
                <div className="grid gap-1 max-h-40 overflow-y-auto rounded-md border border-app bg-app-canvas p-2">
                  {capabilities.map((c) => (
                    <label key={c.id} className="flex items-center gap-2 text-sm text-app-foreground">
                      <input
                        type="checkbox"
                        checked={selectedCapabilityIds.includes(c.id)}
                        onChange={(e) => {
                          if (e.target.checked) {
                            setSelectedCapabilityIds((prev) => [...prev, c.id]);
                          } else {
                            setSelectedCapabilityIds((prev) => prev.filter((id) => id !== c.id));
                          }
                        }}
                      />
                      {c.title}
                      <span className="text-xs text-app-muted">({c.pillarCode.replace(/_/g, ' ')})</span>
                    </label>
                  ))}
                </div>
              ) : (
                <p className="text-xs text-app-muted bg-app-canvas rounded-md px-3 py-2 border border-app">
                  No capabilities are defined for this site yet. Ask HQ or your educator to define capabilities before submitting evidence for proof review.
                </p>
              )}
            </fieldset>

            {selectedCapabilityIds.length === 0 && capabilities.length > 0 && (
              <p className="text-xs text-amber-700">
                Select at least one capability so this artifact can contribute to capability growth after proof verification.
              </p>
            )}

            {/* AI disclosure */}
            <div className="rounded-md border border-app bg-app-canvas p-3 space-y-2" data-testid="ai-disclosure">
              <label className="flex items-center gap-2 text-sm text-app-foreground">
                <input
                  type="checkbox"
                  checked={aiUsed}
                  onChange={(e) => setAiUsed(e.target.checked)}
                />
                I used AI tools (MiloOS, ChatGPT, etc.) for part of this work
              </label>
              {aiUsed && (
                <label className="block space-y-1">
                  <span className="text-xs font-medium text-app-muted">
                    How did you use AI? What prompts did you give? What did you change from what AI suggested?
                  </span>
                  <textarea
                    data-testid="ai-details"
                    value={aiDetails}
                    onChange={(e) => setAiDetails(e.target.value)}
                    placeholder="e.g., 'I asked MiloOS for help structuring my essay. It suggested an outline, but I rewrote all the paragraphs in my own words.'"
                    className="w-full rounded-md border border-app bg-app-canvas px-3 py-2 text-sm text-app-foreground min-h-20"
                  />
                </label>
              )}
            </div>

            <button
              type="button"
              data-testid="artifact-submit"
              disabled={!canSubmitArtifact}
              onClick={() => void handleSubmitArtifact()}
              className="w-full rounded-md bg-primary px-4 py-2.5 text-sm font-semibold text-primary-foreground disabled:opacity-50 sm:w-auto"
            >
              {saving ? 'Submitting...' : 'Add to My Portfolio'}
            </button>
          </div>
        )}

        {/* Reflection form */}
        {activeTab === 'reflection' && (
          <div className="rounded-xl border border-app bg-app-surface-raised p-4 space-y-3" data-testid="reflection-form">
            <h2 className="text-sm font-semibold text-app-foreground">New Reflection</h2>
            <p className="text-xs text-app-muted">
              Reflections help you think about what you learned, what was hard, and what you would do differently.
            </p>

            <label className="block space-y-1">
              <span className="text-xs font-medium text-app-muted">Your reflection *</span>
              <textarea
                data-testid="reflection-content"
                value={reflectionContent}
                onChange={(e) => setReflectionContent(e.target.value)}
                placeholder="What did I learn? What was challenging? What would I do differently next time? What am I proud of?"
                className="w-full rounded-md border border-app bg-app-canvas px-3 py-2 text-sm text-app-foreground min-h-32"
              />
            </label>

            {/* Capability link for reflection */}
            {capabilities.length > 0 && (
              <fieldset className="space-y-1">
                <legend className="text-xs font-medium text-app-muted">Which capabilities is this reflection about? *</legend>
                <div className="grid gap-1 max-h-32 overflow-y-auto rounded-md border border-app bg-app-canvas p-2">
                  {capabilities.map((c) => (
                    <label key={c.id} className="flex items-center gap-2 text-sm text-app-foreground">
                      <input
                        type="checkbox"
                        checked={reflectionCapabilityIds.includes(c.id)}
                        onChange={(e) => {
                          if (e.target.checked) {
                            setReflectionCapabilityIds((prev) => [...prev, c.id]);
                          } else {
                            setReflectionCapabilityIds((prev) => prev.filter((id) => id !== c.id));
                          }
                        }}
                      />
                      {c.title}
                    </label>
                  ))}
                </div>
              </fieldset>
            )}

            {capabilities.length === 0 && (
              <p className="text-xs text-app-muted bg-app-canvas rounded-md px-3 py-2 border border-app">
                No capabilities are defined for this site yet. Ask HQ or your educator to define capabilities before saving reflections as evidence.
              </p>
            )}

            {reflectionCapabilityIds.length === 0 && capabilities.length > 0 && (
              <p className="text-xs text-amber-700">
                Link this reflection to at least one capability so it can support trustworthy growth updates.
              </p>
            )}

            {/* AI disclosure for reflection */}
            <div className="rounded-md border border-app bg-app-canvas p-3 space-y-2">
              <label className="flex items-center gap-2 text-sm text-app-foreground">
                <input
                  type="checkbox"
                  checked={reflectionAiUsed}
                  onChange={(e) => setReflectionAiUsed(e.target.checked)}
                />
                I used AI tools to help write this reflection
              </label>
              {reflectionAiUsed && (
                <label className="block space-y-1">
                  <span className="text-xs font-medium text-app-muted">How did AI help?</span>
                  <textarea
                    data-testid="reflection-ai-details"
                    value={reflectionAiDetails}
                    onChange={(e) => setReflectionAiDetails(e.target.value)}
                    placeholder="Describe how you used AI in writing this reflection..."
                    className="w-full rounded-md border border-app bg-app-canvas px-3 py-2 text-sm text-app-foreground min-h-16"
                  />
                </label>
              )}
            </div>

            <button
              type="button"
              data-testid="reflection-submit"
              disabled={!canSubmitReflection}
              onClick={() => void handleSubmitReflection()}
              className="w-full rounded-md bg-primary px-4 py-2.5 text-sm font-semibold text-primary-foreground disabled:opacity-50 sm:w-auto"
            >
              {saving ? 'Saving...' : 'Save Reflection'}
            </button>
          </div>
        )}

        {/* Checkpoint evidence form */}
        {activeTab === 'checkpoint' && (
          <div className="rounded-xl border border-app bg-app-surface-raised p-4 space-y-3" data-testid="checkpoint-form">
            <h2 className="text-sm font-semibold text-app-foreground">Checkpoint Evidence</h2>
            <p className="text-xs text-app-muted">
              Submit evidence for a specific mission or checkpoint. Show what you built, learned, or can explain.
            </p>

            <label className="block space-y-1">
              <span className="text-xs font-medium text-app-muted">Mission / Checkpoint *</span>
              <select
                data-testid="checkpoint-mission-select"
                value={checkpointMissionId}
                onChange={(e) => setCheckpointMissionId(e.target.value)}
                className="w-full rounded-md border border-app bg-app-canvas px-3 py-2 text-sm text-app-foreground"
              >
                <option value="">Select a mission…</option>
                {missions.map((m) => (
                  <option key={m.id} value={m.id}>
                    {m.title}
                  </option>
                ))}
              </select>
            </label>

            {checkpointMissionId && (() => {
              const mission = missions.find((m) => m.id === checkpointMissionId);
              const capIds = mission?.capabilityIds ?? [];
              if (capIds.length === 0) {
                return (
                  <div className="text-xs text-amber-900 rounded-md border border-amber-200 bg-amber-50 px-3 py-2">
                    This checkpoint is not linked to a capability yet. Ask HQ or your educator to map it before submitting evidence.
                  </div>
                );
              }
              return (
                <div className="text-xs text-app-muted rounded-md border border-app bg-app-canvas px-3 py-2">
                  <span className="font-medium">Linked capabilities: </span>
                  {capIds.map((cid) => resolveTitle(cid)).join(', ')}
                </div>
              );
            })()}

            <label className="block space-y-1">
              <span className="text-xs font-medium text-app-muted">What did you do / build / demonstrate? *</span>
              <textarea
                data-testid="checkpoint-content"
                value={checkpointContent}
                onChange={(e) => setCheckpointContent(e.target.value)}
                placeholder="Describe what you created, what you can explain, and what you learned…"
                className="w-full rounded-md border border-app bg-app-canvas px-3 py-2 text-sm text-app-foreground min-h-28"
              />
            </label>

            <label className="block space-y-1">
              <span className="text-xs font-medium text-app-muted">Attachment URL (optional)</span>
              <input
                data-testid="checkpoint-attachment"
                type="url"
                value={checkpointAttachmentUrl}
                onChange={(e) => setCheckpointAttachmentUrl(e.target.value)}
                placeholder="https://drive.google.com/... or link to your work"
                className="w-full rounded-md border border-app bg-app-canvas px-3 py-2 text-sm text-app-foreground"
              />
            </label>

            {/* AI disclosure for checkpoint */}
            <div className="rounded-md border border-app bg-app-canvas p-3 space-y-2">
              <label className="flex items-center gap-2 text-sm text-app-foreground">
                <input
                  type="checkbox"
                  checked={checkpointAiUsed}
                  onChange={(e) => setCheckpointAiUsed(e.target.checked)}
                />
                I used AI tools for part of this checkpoint work
              </label>
              {checkpointAiUsed && (
                <label className="block space-y-1">
                  <span className="text-xs font-medium text-app-muted">How did AI help? What did you change?</span>
                  <textarea
                    data-testid="checkpoint-ai-details"
                    value={checkpointAiDetails}
                    onChange={(e) => setCheckpointAiDetails(e.target.value)}
                    placeholder="Describe how you used AI and what parts are your own work…"
                    className="w-full rounded-md border border-app bg-app-canvas px-3 py-2 text-sm text-app-foreground min-h-16"
                  />
                </label>
              )}
            </div>

            <button
              type="button"
              data-testid="checkpoint-submit"
              disabled={!canSubmitCheckpoint}
              onClick={() => void handleSubmitCheckpoint()}
              className="w-full rounded-md bg-primary px-4 py-2.5 text-sm font-semibold text-primary-foreground disabled:opacity-50 sm:w-auto"
            >
              {saving ? 'Submitting...' : 'Submit Checkpoint Evidence'}
            </button>
          </div>
        )}

        {/* Portfolio items list */}
        <div className="rounded-xl border border-app bg-app-surface p-4" data-testid="portfolio-list">
          <h2 className="text-sm font-semibold text-app-foreground mb-3">My Portfolio</h2>
          {loading ? (
            <div className="flex items-center gap-2 text-app-muted py-4">
              <Spinner />
              <span className="text-sm">Loading portfolio...</span>
            </div>
          ) : portfolio.length === 0 ? (
            <div className="py-6 text-center text-sm text-app-muted">
              <p>No portfolio items yet.</p>
              <p className="mt-1">Submit your first artifact or write a reflection to start building your portfolio!</p>
            </div>
          ) : (
            <ul className="space-y-2">
              {portfolio.map((item) => (
                <li
                  key={item.id}
                  className="rounded-lg border border-app bg-app-canvas p-3 text-sm"
                >
                  <div className="flex items-start justify-between gap-2">
                    <div>
                      <span className="font-medium text-app-foreground">{item.title}</span>
                      {item.description && (
                        <p className="mt-1 text-app-muted line-clamp-2">{item.description}</p>
                      )}
                    </div>
                    <div className="flex flex-col gap-1 shrink-0 items-end">
                      {statusBadge(item.verificationStatus)}
                      {polBadge(item.proofOfLearningStatus)}
                    </div>
                  </div>
                  <div className="mt-2 flex flex-wrap gap-2 text-xs text-app-muted">
                    {item.capabilityTitles.map((title, i) => (
                      <span key={i} className="rounded bg-app-surface px-1.5 py-0.5">
                        {title}
                      </span>
                    ))}
                    {item.artifacts.length > 0 && (
                      <span className="rounded bg-blue-50 text-blue-700 px-1.5 py-0.5">
                        {item.artifacts.length} artifact{item.artifacts.length !== 1 ? 's' : ''}
                      </span>
                    )}
                    {item.aiAssistanceUsed && (
                      <span className="rounded bg-purple-50 text-purple-700 px-1.5 py-0.5">
                        AI assisted
                      </span>
                    )}
                  </div>
                </li>
              ))}
            </ul>
          )}
        </div>
      </section>
    </RoleRouteGuard>
  );
}
