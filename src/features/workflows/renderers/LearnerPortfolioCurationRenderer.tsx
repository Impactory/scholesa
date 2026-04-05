'use client';

import React, { useCallback, useEffect, useState } from 'react';
import {
  addDoc,
  collection,
  deleteDoc,
  doc,
  getDocs,
  limit,
  orderBy,
  query,
  serverTimestamp,
  updateDoc,
  where,
  type DocumentData,
  type QueryDocumentSnapshot,
} from 'firebase/firestore';
import { firestore } from '@/src/firebase/client-init';
import { Spinner } from '@/src/components/ui/Spinner';
import { useInteractionTracking } from '@/src/hooks/useTelemetry';
import type { CustomRouteRendererProps } from '../customRouteRenderers';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

type PillarCode = 'FUTURE_SKILLS' | 'LEADERSHIP_AGENCY' | 'IMPACT_INNOVATION';

type VerificationStatus = 'pending' | 'reviewed' | 'verified';

type AiDisclosure = 'none' | 'assisted_can_explain' | 'assisted_needs_verification';

interface PortfolioItem {
  id: string;
  title: string;
  description: string;
  pillarCode: PillarCode;
  artifactUrl: string;
  aiDisclosure: AiDisclosure;
  verificationStatus: VerificationStatus;
  proofOfLearning: boolean;
  linkedCapabilityIds: string[];
  linkedCapabilityTitles: string[];
  learnerId: string;
  createdAt: string | null;
}

interface CapabilityMastery {
  id: string;
  capabilityId: string;
  capabilityTitle: string;
  pillarCode: PillarCode;
  level: number;
  learnerId: string;
}

interface GrowthEvent {
  id: string;
  capabilityTitle: string;
  pillarCode: PillarCode;
  fromLevel: number;
  toLevel: number;
  createdAt: string | null;
}

const PILLAR_OPTIONS: { value: PillarCode; label: string }[] = [
  { value: 'FUTURE_SKILLS', label: 'Future Skills' },
  { value: 'LEADERSHIP_AGENCY', label: 'Leadership & Agency' },
  { value: 'IMPACT_INNOVATION', label: 'Impact & Innovation' },
];

const AI_DISCLOSURE_OPTIONS: { value: AiDisclosure; label: string }[] = [
  { value: 'none', label: 'No AI assistance used' },
  { value: 'assisted_can_explain', label: 'AI assisted, I can explain my work' },
  { value: 'assisted_needs_verification', label: 'AI assisted, verification needed' },
];

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function toIso(value: unknown): string | null {
  if (
    value &&
    typeof value === 'object' &&
    'toDate' in value &&
    typeof (value as { toDate: () => Date }).toDate === 'function'
  ) {
    return (value as { toDate: () => Date }).toDate().toISOString();
  }
  if (typeof value === 'string') return value;
  if (typeof value === 'number') return new Date(value).toISOString();
  return null;
}

function asString(value: unknown, fallback: string): string {
  return typeof value === 'string' && value.trim().length > 0 ? value.trim() : fallback;
}

function pillarBadgeClass(code: string): string {
  switch (code) {
    case 'FUTURE_SKILLS':
      return 'bg-blue-100 text-blue-800';
    case 'LEADERSHIP_AGENCY':
      return 'bg-purple-100 text-purple-800';
    case 'IMPACT_INNOVATION':
      return 'bg-emerald-100 text-emerald-800';
    default:
      return 'bg-gray-100 text-gray-800';
  }
}

function pillarLabel(code: string): string {
  return PILLAR_OPTIONS.find((p) => p.value === code)?.label ?? code;
}

function verificationBadgeClass(status: VerificationStatus): string {
  switch (status) {
    case 'verified':
      return 'bg-green-100 text-green-800';
    case 'reviewed':
      return 'bg-blue-100 text-blue-800';
    case 'pending':
    default:
      return 'bg-yellow-100 text-yellow-800';
  }
}

function aiDisclosureLabel(disclosure: AiDisclosure): string {
  return AI_DISCLOSURE_OPTIONS.find((o) => o.value === disclosure)?.label ?? disclosure;
}

function levelBarWidth(level: number): string {
  return `${Math.min(Math.max(level, 0), 4) * 25}%`;
}

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

export default function LearnerPortfolioCurationRenderer({ ctx }: CustomRouteRendererProps) {
  const trackInteraction = useInteractionTracking();

  const [portfolioItems, setPortfolioItems] = useState<PortfolioItem[]>([]);
  const [masteries, setMasteries] = useState<CapabilityMastery[]>([]);
  const [growthEvents, setGrowthEvents] = useState<GrowthEvent[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // ---- Add item form state ----
  const [showAddForm, setShowAddForm] = useState(false);
  const [newTitle, setNewTitle] = useState('');
  const [newDescription, setNewDescription] = useState('');
  const [newPillar, setNewPillar] = useState<PillarCode>('FUTURE_SKILLS');
  const [newArtifactUrl, setNewArtifactUrl] = useState('');
  const [newAiDisclosure, setNewAiDisclosure] = useState<AiDisclosure>('none');
  const [newReflection, setNewReflection] = useState('');
  const [saving, setSaving] = useState(false);

  // ---- Data loading ----
  const loadData = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const [itemsSnap, masterySnap, growthSnap] = await Promise.all([
        getDocs(
          query(
            collection(firestore, 'portfolioItems'),
            where('learnerId', '==', ctx.uid),
            orderBy('createdAt', 'desc')
          )
        ),
        getDocs(
          query(
            collection(firestore, 'capabilityMastery'),
            where('learnerId', '==', ctx.uid)
          )
        ),
        getDocs(
          query(
            collection(firestore, 'capabilityGrowthEvents'),
            where('learnerId', '==', ctx.uid),
            limit(20)
          )
        ),
      ]);

      setPortfolioItems(
        itemsSnap.docs.map((d: QueryDocumentSnapshot<DocumentData>) => {
          const data = d.data();
          return {
            id: d.id,
            title: asString(data.title, 'Untitled'),
            description: asString(data.description, ''),
            pillarCode: (['FUTURE_SKILLS', 'LEADERSHIP_AGENCY', 'IMPACT_INNOVATION'].includes(
              data.pillarCode
            )
              ? data.pillarCode
              : 'FUTURE_SKILLS') as PillarCode,
            artifactUrl: asString(data.artifactUrl, ''),
            aiDisclosure: (['none', 'assisted_can_explain', 'assisted_needs_verification'].includes(
              data.aiDisclosure
            )
              ? data.aiDisclosure
              : 'none') as AiDisclosure,
            verificationStatus: (['pending', 'reviewed', 'verified'].includes(
              data.verificationStatus
            )
              ? data.verificationStatus
              : 'pending') as VerificationStatus,
            proofOfLearning: data.proofOfLearning === true,
            linkedCapabilityIds: Array.isArray(data.linkedCapabilityIds)
              ? data.linkedCapabilityIds
              : [],
            linkedCapabilityTitles: Array.isArray(data.linkedCapabilityTitles)
              ? data.linkedCapabilityTitles
              : [],
            learnerId: asString(data.learnerId, ctx.uid),
            createdAt: toIso(data.createdAt),
          };
        })
      );

      setMasteries(
        masterySnap.docs.map((d: QueryDocumentSnapshot<DocumentData>) => {
          const data = d.data();
          return {
            id: d.id,
            capabilityId: asString(data.capabilityId, ''),
            capabilityTitle: asString(data.capabilityTitle, 'Unknown'),
            pillarCode: (['FUTURE_SKILLS', 'LEADERSHIP_AGENCY', 'IMPACT_INNOVATION'].includes(
              data.pillarCode
            )
              ? data.pillarCode
              : 'FUTURE_SKILLS') as PillarCode,
            level: typeof data.level === 'number' ? data.level : 0,
            learnerId: asString(data.learnerId, ctx.uid),
          };
        })
      );

      setGrowthEvents(
        growthSnap.docs.map((d: QueryDocumentSnapshot<DocumentData>) => {
          const data = d.data();
          return {
            id: d.id,
            capabilityTitle: asString(data.capabilityTitle, 'Unknown'),
            pillarCode: (['FUTURE_SKILLS', 'LEADERSHIP_AGENCY', 'IMPACT_INNOVATION'].includes(
              data.pillarCode
            )
              ? data.pillarCode
              : 'FUTURE_SKILLS') as PillarCode,
            fromLevel: typeof data.fromLevel === 'number' ? data.fromLevel : 0,
            toLevel: typeof data.toLevel === 'number' ? data.toLevel : 0,
            createdAt: toIso(data.createdAt),
          };
        })
      );
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load portfolio data.');
    } finally {
      setLoading(false);
    }
  }, [ctx.uid]);

  useEffect(() => {
    void loadData();
  }, [loadData]);

  // ---- Actions ----

  const handleAddItem = async () => {
    if (!newTitle.trim()) return;
    setSaving(true);
    try {
      const portfolioDoc = await addDoc(collection(firestore, 'portfolioItems'), {
        title: newTitle.trim(),
        description: newDescription.trim(),
        pillarCode: newPillar,
        artifactUrl: newArtifactUrl.trim(),
        aiDisclosure: newAiDisclosure,
        verificationStatus: 'pending',
        proofOfLearning: false,
        linkedCapabilityIds: [],
        linkedCapabilityTitles: [],
        reflectionIds: [] as string[],
        learnerId: ctx.uid,
        createdAt: serverTimestamp(),
      });

      // S1-6: Create linked reflection if provided
      if (newReflection.trim()) {
        const reflectionDoc = await addDoc(collection(firestore, 'learnerReflections'), {
          learnerId: ctx.uid,
          siteId: ctx.profile?.siteIds?.[0] ?? '',
          portfolioItemId: portfolioDoc.id,
          proudOf: newReflection.trim(),
          nextIWill: '',
          createdAt: serverTimestamp(),
        });
        // Back-link the reflection to the portfolio item
        await updateDoc(portfolioDoc, {
          reflectionIds: [reflectionDoc.id],
        });
      }

      trackInteraction('feature_discovered', {
        cta: 'portfolio_item_added',
        pillar: newPillar,
        aiDisclosure: newAiDisclosure,
        hasReflection: newReflection.trim().length > 0,
      });
      setNewTitle('');
      setNewDescription('');
      setNewArtifactUrl('');
      setNewAiDisclosure('none');
      setNewReflection('');
      setShowAddForm(false);
      await loadData();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to add portfolio item.');
    } finally {
      setSaving(false);
    }
  };

  const handleMarkAsShowcase = async (itemId: string) => {
    setSaving(true);
    try {
      await updateDoc(doc(firestore, 'portfolioItems', itemId), {
        verificationStatus: 'verified',
        updatedAt: serverTimestamp(),
      });
      trackInteraction('feature_discovered', { cta: 'portfolio_item_showcased', itemId });
      await loadData();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to mark as showcase.');
    } finally {
      setSaving(false);
    }
  };

  const handleDeleteItem = async (itemId: string) => {
    setSaving(true);
    try {
      await deleteDoc(doc(firestore, 'portfolioItems', itemId));
      trackInteraction('feature_discovered', { cta: 'portfolio_item_deleted', itemId });
      await loadData();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to delete portfolio item.');
    } finally {
      setSaving(false);
    }
  };

  // ---- Group mastery by pillar ----
  const masteryByPillar = PILLAR_OPTIONS.map((pillar) => ({
    pillar,
    items: masteries.filter((m: CapabilityMastery) => m.pillarCode === pillar.value),
  }));

  // ---- Render ----
  return (
    <section className="space-y-6" data-testid="learner-portfolio-curation">
      {/* Growth Summary */}
      <header className="rounded-xl border border-app bg-app-surface-raised p-6">
        <h1 className="text-2xl font-bold text-app-foreground">My Portfolio</h1>
        <p className="mt-1 text-sm text-app-muted">
          Curate evidence of your learning journey, track capability growth, and showcase your best
          work.
        </p>
      </header>

      {error && (
        <div
          className="rounded-xl border border-red-200 bg-red-50 p-4 text-sm text-red-700"
          data-testid="portfolio-error"
        >
          {error}
        </div>
      )}

      {loading ? (
        <div
          className="flex min-h-[240px] items-center justify-center rounded-xl border border-app bg-app-surface"
          data-testid="portfolio-loading"
        >
          <div className="flex items-center gap-2 text-app-muted">
            <Spinner />
            <span>Loading portfolio...</span>
          </div>
        </div>
      ) : (
        <>
          {/* ============================================================
           * GROWTH SUMMARY
           * ============================================================ */}
          <div
            className="rounded-xl border border-app bg-app-surface p-5 space-y-4"
            data-testid="growth-summary"
          >
            <h2 className="text-lg font-semibold text-app-foreground">Growth Summary</h2>

            {masteries.length === 0 ? (
              <p className="text-sm text-app-muted" data-testid="growth-summary-empty">
                No capability mastery data yet. Complete missions to start building your growth
                profile.
              </p>
            ) : (
              <div className="space-y-5">
                {masteryByPillar.map(({ pillar, items }) =>
                  items.length === 0 ? null : (
                    <div key={pillar.value} className="space-y-2">
                      <h3 className="flex items-center gap-2 text-sm font-semibold text-app-foreground">
                        <span
                          className={`rounded-full px-2.5 py-0.5 text-xs font-medium ${pillarBadgeClass(pillar.value)}`}
                        >
                          {pillar.label}
                        </span>
                      </h3>
                      <ul className="space-y-2">
                        {items.map((m: CapabilityMastery) => (
                          <li
                            key={m.id}
                            className="flex items-center gap-3"
                            data-testid={`mastery-${m.id}`}
                          >
                            <span className="w-40 truncate text-sm text-app-foreground">
                              {m.capabilityTitle}
                            </span>
                            <div className="flex-1">
                              <div className="h-2 rounded-full bg-app-canvas">
                                <div
                                  className="h-2 rounded-full bg-primary transition-all"
                                  style={{ width: levelBarWidth(m.level) }}
                                />
                              </div>
                            </div>
                            <span className="w-8 text-right text-xs font-semibold text-app-muted">
                              {m.level}/4
                            </span>
                          </li>
                        ))}
                      </ul>
                    </div>
                  )
                )}
              </div>
            )}

            {/* Recent growth events */}
            {growthEvents.length > 0 && (
              <div className="mt-4 space-y-2" data-testid="growth-events">
                <h3 className="text-sm font-semibold text-app-foreground">Recent Growth</h3>
                <ul className="space-y-1">
                  {growthEvents.slice(0, 5).map((ev: GrowthEvent) => (
                    <li
                      key={ev.id}
                      className="flex items-center gap-2 text-xs text-app-muted"
                      data-testid={`growth-event-${ev.id}`}
                    >
                      <span className={`rounded-full px-2 py-0.5 font-medium ${pillarBadgeClass(ev.pillarCode)}`}>
                        {pillarLabel(ev.pillarCode)}
                      </span>
                      <span className="text-app-foreground font-medium">{ev.capabilityTitle}</span>
                      <span>
                        Level {ev.fromLevel} &rarr; {ev.toLevel}
                      </span>
                    </li>
                  ))}
                </ul>
              </div>
            )}
          </div>

          {/* ============================================================
           * PORTFOLIO ITEMS
           * ============================================================ */}
          <div className="space-y-4" data-testid="portfolio-items-section">
            <div className="flex items-center justify-between">
              <h2 className="text-lg font-semibold text-app-foreground">
                Portfolio Items ({portfolioItems.length})
              </h2>
              <div className="flex gap-2">
                <button
                  type="button"
                  onClick={() => setShowAddForm((prev: boolean) => !prev)}
                  className="rounded-md bg-primary px-4 py-2 text-sm font-semibold text-primary-foreground hover:bg-primary/90"
                  data-testid="add-portfolio-item-toggle"
                >
                  {showAddForm ? 'Cancel' : 'Add Item'}
                </button>
                <button
                  type="button"
                  onClick={() => void loadData()}
                  className="rounded-md border border-app px-3 py-2 text-sm text-app-foreground hover:bg-app-canvas"
                >
                  Refresh
                </button>
              </div>
            </div>

            {/* Add portfolio item form */}
            {showAddForm && (
              <div
                className="rounded-xl border border-app bg-app-surface p-5 space-y-4"
                data-testid="add-portfolio-item-form"
              >
                <h3 className="text-base font-semibold text-app-foreground">
                  Add Portfolio Item
                </h3>

                <div className="grid gap-4 md:grid-cols-2">
                  <label className="space-y-1">
                    <span className="text-xs font-medium text-app-muted">Title *</span>
                    <input
                      type="text"
                      value={newTitle}
                      onChange={(e: React.ChangeEvent<HTMLInputElement>) => setNewTitle(e.target.value)}
                      placeholder="e.g. My robotics project"
                      className="w-full rounded-md border border-app bg-app-canvas px-3 py-2 text-sm text-app-foreground"
                      data-testid="portfolio-item-title-input"
                    />
                  </label>

                  <label className="space-y-1">
                    <span className="text-xs font-medium text-app-muted">Pillar *</span>
                    <select
                      value={newPillar}
                      onChange={(e: React.ChangeEvent<HTMLSelectElement>) => setNewPillar(e.target.value as PillarCode)}
                      className="w-full rounded-md border border-app bg-app-canvas px-3 py-2 text-sm text-app-foreground"
                      data-testid="portfolio-item-pillar-select"
                    >
                      {PILLAR_OPTIONS.map((p) => (
                        <option key={p.value} value={p.value}>
                          {p.label}
                        </option>
                      ))}
                    </select>
                  </label>
                </div>

                <label className="block space-y-1">
                  <span className="text-xs font-medium text-app-muted">Description</span>
                  <textarea
                    value={newDescription}
                    onChange={(e: React.ChangeEvent<HTMLTextAreaElement>) => setNewDescription(e.target.value)}
                    placeholder="Describe what you learned and how you demonstrated this capability..."
                    className="w-full rounded-md border border-app bg-app-canvas px-3 py-2 text-sm text-app-foreground min-h-20"
                    data-testid="portfolio-item-description-input"
                  />
                </label>

                <label className="block space-y-1">
                  <span className="text-xs font-medium text-app-muted">Artifact URL</span>
                  <input
                    type="url"
                    value={newArtifactUrl}
                    onChange={(e: React.ChangeEvent<HTMLInputElement>) => setNewArtifactUrl(e.target.value)}
                    placeholder="https://..."
                    className="w-full rounded-md border border-app bg-app-canvas px-3 py-2 text-sm text-app-foreground"
                    data-testid="portfolio-item-artifact-url-input"
                  />
                </label>

                {/* AI Disclosure */}
                <fieldset className="space-y-2" data-testid="ai-disclosure-fieldset">
                  <legend className="text-xs font-medium text-app-muted">AI Disclosure *</legend>
                  {AI_DISCLOSURE_OPTIONS.map((option) => (
                    <label
                      key={option.value}
                      className="flex items-center gap-2 cursor-pointer"
                    >
                      <input
                        type="radio"
                        name="aiDisclosure"
                        value={option.value}
                        checked={newAiDisclosure === option.value}
                        onChange={() => setNewAiDisclosure(option.value)}
                        className="accent-primary"
                        data-testid={`ai-disclosure-${option.value}`}
                      />
                      <span className="text-sm text-app-foreground">{option.label}</span>
                    </label>
                  ))}
                </fieldset>

                {/* Reflection linkage (S1-6) */}
                <label className="block space-y-1">
                  <span className="text-xs font-medium text-app-muted">
                    Reflection (optional)
                  </span>
                  <textarea
                    value={newReflection}
                    onChange={(e: React.ChangeEvent<HTMLTextAreaElement>) =>
                      setNewReflection(e.target.value)
                    }
                    placeholder="What are you proud of? What did you learn from this work?"
                    className="w-full rounded-md border border-app bg-app-canvas px-3 py-2 text-sm text-app-foreground min-h-16"
                    data-testid="add-portfolio-reflection"
                  />
                </label>

                <button
                  type="button"
                  disabled={saving || !newTitle.trim()}
                  onClick={() => void handleAddItem()}
                  className="rounded-md bg-primary px-4 py-2 text-sm font-semibold text-primary-foreground disabled:opacity-50"
                  data-testid="add-portfolio-item-submit"
                >
                  {saving ? 'Saving...' : 'Add to Portfolio'}
                </button>
              </div>
            )}

            {/* Items list */}
            {portfolioItems.length === 0 ? (
              <div
                className="rounded-xl border border-dashed border-app bg-app-surface p-8 text-center text-sm text-app-muted"
                data-testid="portfolio-items-empty"
              >
                Your portfolio is empty. Add your first piece of evidence to get started.
              </div>
            ) : (
              <ul className="grid gap-3" data-testid="portfolio-items-list">
                {portfolioItems.map((item: PortfolioItem) => (
                  <li
                    key={item.id}
                    className="rounded-xl border border-app bg-app-surface-raised p-4 space-y-3"
                    data-testid={`portfolio-item-${item.id}`}
                  >
                    <div className="flex flex-wrap items-start justify-between gap-3">
                      <div className="space-y-1 flex-1">
                        <h4 className="text-base font-semibold text-app-foreground">
                          {item.title}
                        </h4>
                        {item.description && (
                          <p className="text-sm text-app-muted">{item.description}</p>
                        )}
                      </div>

                      <div className="flex gap-2">
                        {item.verificationStatus !== 'verified' && (
                          <button
                            type="button"
                            disabled={saving}
                            onClick={() => void handleMarkAsShowcase(item.id)}
                            className="rounded-md bg-primary px-3 py-1.5 text-xs font-semibold text-primary-foreground disabled:opacity-50"
                            data-testid={`showcase-${item.id}`}
                          >
                            Mark as Showcase
                          </button>
                        )}
                        <button
                          type="button"
                          disabled={saving}
                          onClick={() => void handleDeleteItem(item.id)}
                          className="rounded-md border border-red-200 px-3 py-1.5 text-xs font-medium text-red-700 disabled:opacity-50"
                          data-testid={`delete-${item.id}`}
                        >
                          Delete
                        </button>
                      </div>
                    </div>

                    {/* Badges row */}
                    <div className="flex flex-wrap gap-2 text-xs">
                      <span
                        className={`rounded-full px-2 py-0.5 font-medium ${pillarBadgeClass(item.pillarCode)}`}
                      >
                        {pillarLabel(item.pillarCode)}
                      </span>

                      <span
                        className={`rounded-full px-2 py-0.5 font-medium ${verificationBadgeClass(item.verificationStatus)}`}
                        data-testid={`verification-status-${item.id}`}
                      >
                        {item.verificationStatus}
                      </span>

                      <span
                        className={`rounded-full px-2 py-0.5 font-medium ${
                          item.aiDisclosure === 'none'
                            ? 'bg-gray-100 text-gray-700'
                            : item.aiDisclosure === 'assisted_can_explain'
                              ? 'bg-indigo-100 text-indigo-800'
                              : 'bg-amber-100 text-amber-800'
                        }`}
                        data-testid={`ai-disclosure-status-${item.id}`}
                      >
                        {aiDisclosureLabel(item.aiDisclosure)}
                      </span>

                      {item.proofOfLearning && (
                        <span className="rounded-full bg-green-100 px-2 py-0.5 font-medium text-green-800">
                          Proof of Learning
                        </span>
                      )}

                      {!item.proofOfLearning && (
                        <span className="rounded-full bg-gray-100 px-2 py-0.5 font-medium text-gray-500">
                          No proof of learning
                        </span>
                      )}
                    </div>

                    {/* Linked capabilities */}
                    {item.linkedCapabilityTitles.length > 0 && (
                      <div className="flex flex-wrap gap-1.5" data-testid={`linked-capabilities-${item.id}`}>
                        <span className="text-xs text-app-muted">Capabilities:</span>
                        {item.linkedCapabilityTitles.map((title: string, i: number) => (
                          <span
                            key={i}
                            className="rounded-full bg-app-canvas px-2 py-0.5 text-xs text-app-foreground"
                          >
                            {title}
                          </span>
                        ))}
                      </div>
                    )}

                    {/* Artifact link */}
                    {item.artifactUrl && (
                      <a
                        href={item.artifactUrl}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="inline-block text-xs font-medium text-primary underline"
                        data-testid={`artifact-link-${item.id}`}
                      >
                        View Artifact
                      </a>
                    )}
                  </li>
                ))}
              </ul>
            )}
          </div>
        </>
      )}
    </section>
  );
}
