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
import { resolveActiveSiteId } from '@/src/lib/auth/activeSite';
import { useCapabilities } from '@/src/lib/capabilities/useCapabilities';
import {
  learnerReflectionsCollection,
  portfolioItemsCollection,
} from '@/src/firebase/firestore/collections';
import type { PortfolioItem as PortfolioItemRecord } from '@/src/types/schema';
import {
  getLegacyPillarFamilyDisplayLabel,
  normalizeLegacyPillarCode,
} from '@/src/lib/curriculum/architecture';
import type { CustomRouteRendererProps } from '../customRouteRenderers';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

type PillarCode = 'FUTURE_SKILLS' | 'LEADERSHIP_AGENCY' | 'IMPACT_INNOVATION' | string;

type VerificationStatus = 'pending' | 'reviewed' | 'verified';

type AiDisclosure = 'none' | 'assisted_can_explain' | 'assisted_needs_verification' | 'unknown';

interface ProofBundleSummary {
  id: string;
  hasExplainItBack: boolean;
  hasOralCheck: boolean;
  hasMiniRebuild: boolean;
  verificationStatus: 'missing' | 'partial' | 'verified';
}

interface PortfolioItem {
  id: string;
  title: string;
  description: string;
  pillarCode: PillarCode;
  artifactUrl: string;
  aiDisclosure: AiDisclosure;
  verificationStatus: VerificationStatus;
  proofOfLearning: boolean;
  proofBundle: ProofBundleSummary | null;
  capabilityIds: string[];
  linkedCapabilityTitles: string[];
  learnerId: string;
  createdAt: string | null;
}

interface CapabilityMastery {
  id: string;
  capabilityId: string;
  pillarCode: PillarCode;
  level: number;
  learnerId: string;
}

interface GrowthEvent {
  id: string;
  capabilityId: string;
  pillarCode: PillarCode;
  level: number;
  createdAt: string | null;
}

const DEFAULT_PILLAR_OPTIONS: { value: PillarCode; label: string }[] = [
  { value: 'FUTURE_SKILLS', label: getLegacyPillarFamilyDisplayLabel('FUTURE_SKILLS') },
  { value: 'LEADERSHIP_AGENCY', label: getLegacyPillarFamilyDisplayLabel('LEADERSHIP_AGENCY') },
  { value: 'IMPACT_INNOVATION', label: getLegacyPillarFamilyDisplayLabel('IMPACT_INNOVATION') },
];

const AI_DISCLOSURE_OPTIONS: { value: AiDisclosure; label: string }[] = [
  { value: 'none', label: 'No AI assistance used' },
  { value: 'assisted_can_explain', label: 'AI assisted, I can explain my work' },
  { value: 'assisted_needs_verification', label: 'AI assisted, verification needed' },
  { value: 'unknown', label: 'AI status not assessed' },
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
  return getLegacyPillarFamilyDisplayLabel(code);
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

function aiDisclosureFromRecord(record: Record<string, unknown>): AiDisclosure {
  const aiDisclosureStatus =
    typeof record.aiDisclosureStatus === 'string' ? record.aiDisclosureStatus.trim() : '';
  switch (aiDisclosureStatus) {
    case 'learner-ai-not-used':
      return 'none';
    case 'learner-ai-verified':
      return 'assisted_can_explain';
    case 'learner-ai-verification-gap':
    case 'educator-feedback-ai':
      return 'assisted_needs_verification';
    case 'no-learner-ai-signal':
    case 'not-available':
      return 'unknown';
    default:
      if (typeof record.aiAssistanceUsed === 'boolean') {
        return record.aiAssistanceUsed ? 'assisted_needs_verification' : 'none';
      }
      return (['none', 'assisted_can_explain', 'assisted_needs_verification', 'unknown'].includes(
        asString(record.aiDisclosure, ''),
      )
        ? record.aiDisclosure
        : 'unknown') as AiDisclosure;
  }
}

function aiFieldsFromDisclosure(disclosure: AiDisclosure): {
  aiAssistanceUsed?: boolean;
  aiDisclosureStatus: NonNullable<PortfolioItemRecord['aiDisclosureStatus']>;
} {
  switch (disclosure) {
    case 'none':
      return {
        aiAssistanceUsed: false,
        aiDisclosureStatus: 'learner-ai-not-used',
      };
    case 'assisted_can_explain':
      return {
        aiAssistanceUsed: true,
        aiDisclosureStatus: 'learner-ai-verified',
      };
    case 'assisted_needs_verification':
      return {
        aiAssistanceUsed: true,
        aiDisclosureStatus: 'learner-ai-verification-gap',
      };
    case 'unknown':
    default:
      return {
        aiDisclosureStatus: 'no-learner-ai-signal',
      };
  }
}

function clampMasteryLevel(level: number): number {
  return Math.min(Math.max(level, 0), 4);
}

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

export default function LearnerPortfolioCurationRenderer({ ctx }: CustomRouteRendererProps) {
  const trackInteraction = useInteractionTracking();
  const siteId = resolveActiveSiteId(ctx.profile);
  const { capabilityList, resolveTitle } = useCapabilities(siteId);

  // Derive pillar options from live capabilities, falling back to defaults
  const pillarOptions = React.useMemo(() => {
    if (capabilityList.length === 0) return DEFAULT_PILLAR_OPTIONS;
    const seen = new Set<string>();
    const dynamic: { value: PillarCode; label: string }[] = [];
    for (const c of capabilityList) {
      if (c.pillarCode && !seen.has(c.pillarCode)) {
        seen.add(c.pillarCode);
        const label = getLegacyPillarFamilyDisplayLabel(c.pillarCode);
        dynamic.push({ value: c.pillarCode as PillarCode, label });
      }
    }
    return dynamic.length > 0 ? dynamic : DEFAULT_PILLAR_OPTIONS;
  }, [capabilityList]);

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
  const [newAiDetails, setNewAiDetails] = useState('');
  const [newReflection, setNewReflection] = useState('');
  const [newCapabilityId, setNewCapabilityId] = useState('');
  const [saving, setSaving] = useState(false);

  const capabilitiesForSelectedPillar = capabilityList.filter(
    (capability) =>
      normalizeLegacyPillarCode(capability.pillarCode ?? '') === normalizeLegacyPillarCode(newPillar),
  );
  const aiDisclosureNeedsDetails =
    newAiDisclosure === 'assisted_can_explain'
    || newAiDisclosure === 'assisted_needs_verification';

  // ---- Data loading ----
  const loadData = useCallback(async () => {
    if (!siteId) {
      setPortfolioItems([]);
      setMasteries([]);
      setGrowthEvents([]);
      setLoading(false);
      setError(null);
      return;
    }
    setLoading(true);
    setError(null);
    try {
      const [itemsSnap, masterySnap, growthSnap, proofSnap] = await Promise.all([
        getDocs(
          query(
            collection(firestore, 'portfolioItems'),
            where('learnerId', '==', ctx.uid),
            where('siteId', '==', siteId),
            orderBy('createdAt', 'desc')
          )
        ),
        getDocs(
          query(
            collection(firestore, 'capabilityMastery'),
            where('learnerId', '==', ctx.uid),
            where('siteId', '==', siteId)
          )
        ),
        getDocs(
          query(
            collection(firestore, 'capabilityGrowthEvents'),
            where('learnerId', '==', ctx.uid),
            where('siteId', '==', siteId),
            limit(20)
          )
        ),
        getDocs(
          query(
            collection(firestore, 'proofOfLearningBundles'),
            where('learnerId', '==', ctx.uid),
            where('siteId', '==', siteId)
          )
        ),
      ]);

      // Build proof bundle lookup by portfolioItemId
        const proofByItem = new Map<string, ProofBundleSummary>();
      proofSnap.docs.forEach((d: QueryDocumentSnapshot<DocumentData>) => {
        const data = d.data();
        const piId = data.portfolioItemId as string;
        if (piId) {
          proofByItem.set(piId, {
            id: d.id,
            hasExplainItBack: data.hasExplainItBack === true,
            hasOralCheck: data.hasOralCheck === true,
            hasMiniRebuild: data.hasMiniRebuild === true,
            verificationStatus: (['missing', 'partial', 'verified'].includes(data.verificationStatus)
              ? data.verificationStatus
              : 'missing') as 'missing' | 'partial' | 'verified',
          });
        }
      });

      setPortfolioItems(
        itemsSnap.docs.map((d: QueryDocumentSnapshot<DocumentData>) => {
          const data = d.data();
          const pillarCodes = Array.isArray(data.pillarCodes)
            ? data.pillarCodes.filter((value: unknown): value is PillarCode => typeof value === 'string')
            : [];
          const artifacts = Array.isArray(data.artifacts)
            ? data.artifacts.filter((value: unknown): value is string => typeof value === 'string')
            : [];
          const proofOfLearningStatus = asString(data.proofOfLearningStatus, '');
          const capabilityIds = Array.isArray(data.capabilityIds)
            ? data.capabilityIds.filter((value: unknown): value is string => typeof value === 'string')
            : Array.isArray(data.linkedCapabilityIds)
              ? data.linkedCapabilityIds.filter((value: unknown): value is string => typeof value === 'string')
              : [];
          const capabilityTitles = Array.isArray(data.capabilityTitles)
            ? data.capabilityTitles.filter((value: unknown): value is string => typeof value === 'string')
            : Array.isArray(data.linkedCapabilityTitles)
              ? data.linkedCapabilityTitles.filter((value: unknown): value is string => typeof value === 'string')
              : capabilityIds.map((capabilityId) => resolveTitle(capabilityId));
          return {
            id: d.id,
            title: asString(data.title, 'Untitled'),
            description: asString(data.description, ''),
            pillarCode: (pillarCodes[0] || asString(data.pillarCode, '') || 'FUTURE_SKILLS') as PillarCode,
            artifactUrl: artifacts[0] || asString(data.artifactUrl, ''),
            aiDisclosure: aiDisclosureFromRecord(data),
            verificationStatus: (['pending', 'reviewed', 'verified'].includes(
              data.verificationStatus
            )
              ? data.verificationStatus
              : 'pending') as VerificationStatus,
            proofOfLearning:
              proofOfLearningStatus.length > 0
                ? proofOfLearningStatus !== 'missing' && proofOfLearningStatus !== 'not-available'
                : data.proofOfLearning === true,
            proofBundle: proofByItem.get(d.id) || null,
            capabilityIds,
            linkedCapabilityTitles: capabilityTitles,
            learnerId: asString(data.learnerId, ctx.uid),
            createdAt: toIso(data.createdAt),
          };
        })
      );

      setMasteries(
        masterySnap.docs.map((d: QueryDocumentSnapshot<DocumentData>) => {
          const data = d.data();
          const latest =
            typeof data.latestLevel === 'number'
              ? data.latestLevel
              : typeof data.level === 'number'
                ? data.level
                : 0;
          return {
            id: d.id,
            capabilityId: asString(data.capabilityId, ''),
            pillarCode: (asString(data.pillarCode, '') || 'FUTURE_SKILLS') as PillarCode,
            level: latest,
            learnerId: asString(data.learnerId, ctx.uid),
          };
        })
      );

      setGrowthEvents(
        growthSnap.docs.map((d: QueryDocumentSnapshot<DocumentData>) => {
          const data = d.data();
          const level =
            typeof data.level === 'number'
              ? data.level
              : typeof data.toLevel === 'number'
                ? data.toLevel
                : 0;
          return {
            id: d.id,
            capabilityId: asString(data.capabilityId, ''),
            pillarCode: (asString(data.pillarCode, '') || 'FUTURE_SKILLS') as PillarCode,
            level,
            createdAt: toIso(data.createdAt),
          };
        })
      );
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load portfolio data.');
    } finally {
      setLoading(false);
    }
  }, [ctx.uid, resolveTitle, siteId]);

  useEffect(() => {
    void loadData();
  }, [loadData]);

  // ---- Actions ----

  const handleAddItem = async () => {
    if (!siteId) {
      setError('Select an active site before adding portfolio evidence.');
      return;
    }
    if (!newTitle.trim()) {
      setError('Add a title before saving this portfolio item.');
      return;
    }
    if (!newCapabilityId) {
      setError('Link this portfolio item to a capability before saving it.');
      return;
    }

    const selectedCapability = capabilityList.find((capability) => capability.id === newCapabilityId);
    if (!selectedCapability) {
      setError('Choose a valid capability before saving this portfolio item.');
      return;
    }

    setSaving(true);
    setError(null);
    try {
      const pillarCodes = [
        (selectedCapability.pillarCode ?? newPillar) as PortfolioItemRecord['pillarCodes'][number],
      ];
      const artifacts = newArtifactUrl.trim() ? [newArtifactUrl.trim()] : [];
      const aiFields = aiFieldsFromDisclosure(newAiDisclosure);
      const aiDetails =
        typeof aiFields.aiAssistanceUsed === 'boolean'
        && aiFields.aiAssistanceUsed
        && newAiDetails.trim()
          ? newAiDetails.trim()
          : undefined;
      const portfolioAiPayload =
        typeof aiFields.aiAssistanceUsed === 'boolean'
          ? { aiAssistanceUsed: aiFields.aiAssistanceUsed }
          : {};
      const portfolioDoc = await addDoc(portfolioItemsCollection, {
        learnerId: ctx.uid,
        siteId,
        title: newTitle.trim(),
        description: newDescription.trim(),
        pillarCodes,
        artifacts,
        verificationStatus: 'pending',
        proofOfLearningStatus: 'not-available',
        capabilityIds: [selectedCapability.id],
        capabilityTitles: [resolveTitle(selectedCapability.id)],
        reflectionIds: [] as string[],
        source: 'learner_submission',
        aiDisclosureStatus: aiFields.aiDisclosureStatus,
        aiAssistanceDetails: aiDetails,
        createdAt: serverTimestamp(),
        ...portfolioAiPayload,
      } as unknown as Omit<PortfolioItemRecord, 'id'>);

      // S1-6: Create linked reflection if provided
      if (newReflection.trim()) {
        const reflectionPayload: Record<string, unknown> = {
          learnerId: ctx.uid,
          siteId,
          content: newReflection.trim(),
          portfolioItemId: portfolioDoc.id,
          capabilityIds: [selectedCapability.id],
          pillarCodes,
          proudOf: newReflection.trim(),
          nextIWill: '',
          createdAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        };
        if (typeof aiFields.aiAssistanceUsed === 'boolean') {
          reflectionPayload.aiAssistanceUsed = aiFields.aiAssistanceUsed;
        }
        if (aiDetails) {
          reflectionPayload.aiAssistanceDetails = aiDetails;
        }
        const reflectionDoc = await addDoc(
          learnerReflectionsCollection,
          reflectionPayload as DocumentData,
        );
        // Back-link the reflection to the portfolio item
        await updateDoc(portfolioDoc, {
          reflectionIds: [reflectionDoc.id],
          updatedAt: serverTimestamp(),
        });
      }

      trackInteraction('feature_discovered', {
        cta: 'portfolio_item_added',
        pillar: selectedCapability.pillarCode ?? newPillar,
        capabilityId: selectedCapability.id,
        aiDisclosure: newAiDisclosure,
        hasReflection: newReflection.trim().length > 0,
      });
      setNewTitle('');
      setNewDescription('');
      setNewPillar((selectedCapability.pillarCode as PillarCode | undefined) ?? 'FUTURE_SKILLS');
      setNewArtifactUrl('');
      setNewAiDisclosure('none');
      setNewAiDetails('');
      setNewReflection('');
      setNewCapabilityId('');
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
        showcase: true,
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
  const masteryByPillar = pillarOptions.map((pillar) => ({
    pillar,
    items: masteries.filter(
      (m: CapabilityMastery) =>
        normalizeLegacyPillarCode(m.pillarCode) === normalizeLegacyPillarCode(pillar.value),
    ),
  }));

  if (!siteId) {
    return (
      <section className="space-y-6" data-testid="learner-portfolio-curation">
        <header className="rounded-xl border border-app bg-app-surface-raised p-6">
          <h1 className="text-2xl font-bold text-app-foreground">My Portfolio</h1>
          <p className="mt-1 text-sm text-app-muted">
            Curate evidence of your learning journey, track capability growth, and showcase your best
            work.
          </p>
        </header>
        <div
          className="rounded-xl border border-amber-200 bg-amber-50 p-4 text-sm text-amber-900"
          data-testid="learner-portfolio-site-required"
        >
          Select an active site before curating portfolio evidence.
        </div>
      </section>
    );
  }

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
            <p className="text-sm text-app-muted">
              Legacy family roll-up of the live six-strand curriculum.
            </p>

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
                              {resolveTitle(m.capabilityId)}
                            </span>
                            <div className="flex-1">
                              <progress
                                aria-label={`${resolveTitle(m.capabilityId)} capability level`}
                                className="h-2 w-full rounded-full bg-app-canvas accent-primary"
                                value={clampMasteryLevel(m.level)}
                                max={4}
                              />
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
                      <span className="text-app-foreground font-medium">{resolveTitle(ev.capabilityId)}</span>
                      <span>Now at Level {ev.level}/4</span>
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
                    <span className="text-xs font-medium text-app-muted">Legacy family *</span>
                    <select
                      value={newPillar}
                      onChange={(e: React.ChangeEvent<HTMLSelectElement>) => {
                        const pillar = e.target.value as PillarCode;
                        setNewPillar(pillar);
                        const capabilityStillMatches = capabilityList.some(
                          (capability) =>
                            capability.id === newCapabilityId &&
                            normalizeLegacyPillarCode(capability.pillarCode ?? '') ===
                              normalizeLegacyPillarCode(pillar),
                        );
                        if (!capabilityStillMatches) {
                          setNewCapabilityId('');
                        }
                      }}
                      className="w-full rounded-md border border-app bg-app-canvas px-3 py-2 text-sm text-app-foreground"
                      data-testid="portfolio-item-pillar-select"
                    >
                      {pillarOptions.map((p) => (
                        <option key={p.value} value={p.value}>
                          {p.label}
                        </option>
                      ))}
                    </select>
                  </label>

                  <label className="space-y-1">
                    <span className="text-xs font-medium text-app-muted">Capability *</span>
                    <select
                      value={newCapabilityId}
                      onChange={(e: React.ChangeEvent<HTMLSelectElement>) => {
                        const capabilityId = e.target.value;
                        setNewCapabilityId(capabilityId);
                        const selectedCapability = capabilityList.find((capability) => capability.id === capabilityId);
                        if (selectedCapability?.pillarCode) {
                          setNewPillar(selectedCapability.pillarCode as PillarCode);
                        }
                      }}
                      className="w-full rounded-md border border-app bg-app-canvas px-3 py-2 text-sm text-app-foreground"
                      data-testid="portfolio-item-capability-select"
                    >
                      <option value="">Select the capability this evidence demonstrates</option>
                      {capabilitiesForSelectedPillar.map((capability) => (
                        <option key={capability.id} value={capability.id}>
                          {capability.title ?? capability.name}
                        </option>
                      ))}
                    </select>
                  </label>
                </div>

                {capabilitiesForSelectedPillar.length === 0 && (
                  <div
                    className="rounded-md border border-amber-200 bg-amber-50 px-3 py-2 text-sm text-amber-900"
                    data-testid="portfolio-item-capability-required"
                  >
                    No capabilities are configured for this legacy family yet. Choose a different family
                    or ask your school to publish capabilities before adding this evidence.
                  </div>
                )}

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

                {aiDisclosureNeedsDetails && (
                  <label className="block space-y-1">
                    <span className="text-xs font-medium text-app-muted">AI details</span>
                    <textarea
                      value={newAiDetails}
                      onChange={(e: React.ChangeEvent<HTMLTextAreaElement>) => setNewAiDetails(e.target.value)}
                      placeholder="What did AI help with, and what did you change or explain yourself?"
                      className="w-full rounded-md border border-app bg-app-canvas px-3 py-2 text-sm text-app-foreground min-h-16"
                      data-testid="portfolio-item-ai-details-input"
                    />
                  </label>
                )}

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
                  disabled={saving || !newTitle.trim() || !newCapabilityId}
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
                              : item.aiDisclosure === 'unknown'
                                ? 'bg-yellow-100 text-yellow-800'
                                : 'bg-amber-100 text-amber-800'
                        }`}
                        data-testid={`ai-disclosure-status-${item.id}`}
                      >
                        {aiDisclosureLabel(item.aiDisclosure)}
                      </span>

                      {/* S3-1: Proof bundle detail indicators */}
                      {item.proofBundle ? (
                        <span
                          className={`rounded-full px-2 py-0.5 font-medium ${
                            item.proofBundle.verificationStatus === 'verified'
                              ? 'bg-green-100 text-green-800'
                              : item.proofBundle.verificationStatus === 'partial'
                                ? 'bg-amber-100 text-amber-800'
                                : 'bg-gray-100 text-gray-500'
                          }`}
                        >
                          Proof: {item.proofBundle.verificationStatus}
                        </span>
                      ) : item.proofOfLearning ? (
                        <span className="rounded-full bg-green-100 px-2 py-0.5 font-medium text-green-800">
                          Proof of Learning
                        </span>
                      ) : (
                        <span className="rounded-full bg-gray-100 px-2 py-0.5 font-medium text-gray-500">
                          No proof
                        </span>
                      )}
                    </div>

                    {/* S3-1: Proof method checklist */}
                    {item.proofBundle && (
                      <div className="flex gap-3 text-xs">
                        <span className={item.proofBundle.hasExplainItBack ? 'text-green-700' : 'text-gray-400'}>
                          {item.proofBundle.hasExplainItBack ? '✓' : '○'} Explain It Back
                        </span>
                        <span className={item.proofBundle.hasOralCheck ? 'text-green-700' : 'text-gray-400'}>
                          {item.proofBundle.hasOralCheck ? '✓' : '○'} Oral Check
                        </span>
                        <span className={item.proofBundle.hasMiniRebuild ? 'text-green-700' : 'text-gray-400'}>
                          {item.proofBundle.hasMiniRebuild ? '✓' : '○'} Mini Rebuild
                        </span>
                      </div>
                    )}

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
