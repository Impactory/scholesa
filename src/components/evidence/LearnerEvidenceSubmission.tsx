'use client';

import { useCallback, useEffect, useMemo, useState } from 'react';
import {
  addDoc,
  getDocs,
  orderBy,
  query,
  serverTimestamp,
  where,
  limit,
} from 'firebase/firestore';
import { useAuthContext } from '@/src/firebase/auth/AuthProvider';
import {
  portfolioItemsCollection,
  learnerReflectionsCollection,
} from '@/src/firebase/firestore/collections';
import { useCapabilities } from '@/src/lib/capabilities/useCapabilities';
import { RoleRouteGuard } from '@/src/components/auth/RoleRouteGuard';
import { Spinner } from '@/src/components/ui/Spinner';
import type { PortfolioItem, LearnerReflection, PillarCode } from '@/src/types/schema';

type SubmitTab = 'artifact' | 'reflection';

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

export function LearnerEvidenceSubmission() {
  const { user, profile, loading: authLoading } = useAuthContext();
  const siteId = profile?.studioId ?? null;
  const learnerId = user?.uid ?? null;

  const { capabilityList: capabilities, resolveTitle, loading: capLoading } = useCapabilities(siteId);
  const [activeTab, setActiveTab] = useState<SubmitTab>('artifact');
  const [portfolio, setPortfolio] = useState<PortfolioEntry[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);

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
    if (!learnerId || !siteId) return;
    setLoading(true);
    try {
      const snap = await getDocs(
        query(
          portfolioItemsCollection,
          where('learnerId', '==', learnerId),
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
    } finally {
      setLoading(false);
    }
  }, [learnerId, siteId, resolveTitle]);

  useEffect(() => {
    if (!authLoading && learnerId && siteId) void loadPortfolio();
  }, [authLoading, learnerId, siteId, loadPortfolio]);

  // Artifact submission
  const handleSubmitArtifact = async () => {
    if (!learnerId || !siteId || !artifactTitle.trim()) return;
    setSaving(true);
    setSuccessMessage(null);
    try {
      const artifacts = artifactUrl.trim() ? [artifactUrl.trim()] : [];
      const pillarCodes = derivedPillarCodes.length > 0 ? derivedPillarCodes : selectedPillarCodes;

      await addDoc(portfolioItemsCollection, {
        learnerId,
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
      } as Omit<PortfolioItem, 'id'>);

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
    } finally {
      setSaving(false);
    }
  };

  // Reflection submission
  const handleSubmitReflection = async () => {
    if (!learnerId || !siteId || !reflectionContent.trim()) return;
    setSaving(true);
    setSuccessMessage(null);
    try {
      await addDoc(learnerReflectionsCollection, {
        learnerId,
        siteId,
        content: reflectionContent.trim(),
        capabilityIds: reflectionCapabilityIds,
        aiAssistanceUsed: reflectionAiUsed,
        aiAssistanceDetails: reflectionAiUsed ? reflectionAiDetails.trim() : undefined,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      } as Omit<LearnerReflection, 'id'>);

      setSuccessMessage('Reflection saved!');
      setReflectionContent('');
      setReflectionCapabilityIds([]);
      setReflectionAiUsed(false);
      setReflectionAiDetails('');
    } catch (err) {
      console.error('Failed to save reflection', err);
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
      <div className="rounded-xl border border-amber-200 bg-amber-50 p-6 text-sm text-amber-900">
        No site assigned. Portfolio requires a site context.
      </div>
    );
  }

  const canSubmitArtifact = artifactTitle.trim().length > 0 && !saving;
  const canSubmitReflection = reflectionContent.trim().length > 0 && !saving;

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
              <legend className="text-xs font-medium text-app-muted">Which capabilities does this show? (optional)</legend>
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
                  No capabilities defined yet. Your teacher will map your work to capabilities during review.
                </p>
              )}
            </fieldset>

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
                <legend className="text-xs font-medium text-app-muted">Which capabilities is this reflection about?</legend>
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
