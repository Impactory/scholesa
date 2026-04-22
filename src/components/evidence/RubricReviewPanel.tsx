'use client';

import { useCallback, useEffect, useMemo, useState } from 'react';
import { httpsCallable } from 'firebase/functions';
import { doc, getDoc, getDocs, query, where } from 'firebase/firestore';
import { functions } from '@/src/firebase/client-init';
import {
  rubricTemplatesCollection,
  processDomainsCollection,
  portfolioItemsCollection,
} from '@/src/firebase/firestore/collections';
import { useCapabilities } from '@/src/lib/capabilities/useCapabilities';
import type { RubricTemplate, ProcessDomain } from '@/src/types/schema';

interface RubricReviewPanelProps {
  portfolioItemId?: string;
  evidenceRecordIds: string[];
  missionAttemptId?: string;
  learnerId: string;
  learnerName: string;
  siteId: string;
  description: string;
  capabilityId?: string;
  proofVerified?: boolean;
  onComplete: () => void;
  onCancel: () => void;
}

interface ScoreEntry {
  capabilityId: string;
  processDomainId?: string;
  pillarCode: string;
  criterionId: string;
  score: number;
  maxScore: number;
}

const DEFAULT_SCORE_LEVELS = [
  { value: 1, label: 'Beginning', color: 'bg-red-100 text-red-800 border-red-300' },
  { value: 2, label: 'Developing', color: 'bg-amber-100 text-amber-800 border-amber-300' },
  { value: 3, label: 'Proficient', color: 'bg-blue-100 text-blue-800 border-blue-300' },
  { value: 4, label: 'Advanced', color: 'bg-green-100 text-green-800 border-green-300' },
];

const LEVEL_COLORS = [
  'bg-red-100 text-red-800 border-red-300',
  'bg-amber-100 text-amber-800 border-amber-300',
  'bg-blue-100 text-blue-800 border-blue-300',
  'bg-green-100 text-green-800 border-green-300',
  'bg-emerald-100 text-emerald-800 border-emerald-300',
  'bg-teal-100 text-teal-800 border-teal-300',
];

function scoreLevelsForMax(maxScore: number): { value: number; label: string; color: string }[] {
  if (maxScore === 4) return DEFAULT_SCORE_LEVELS;
  return Array.from({ length: maxScore }, (_, i) => ({
    value: i + 1,
    label: `Level ${i + 1}`,
    color: LEVEL_COLORS[Math.min(i, LEVEL_COLORS.length - 1)],
  }));
}

export function RubricReviewPanel({
  portfolioItemId,
  evidenceRecordIds,
  missionAttemptId,
  learnerId,
  learnerName,
  siteId,
  description,
  capabilityId: preselectedCapabilityId,
  proofVerified = false,
  onComplete,
  onCancel,
}: RubricReviewPanelProps) {
  const { capabilityList, resolveTitle } = useCapabilities(siteId);
  const [templates, setTemplates] = useState<RubricTemplate[]>([]);
  const [processDomains, setProcessDomains] = useState<ProcessDomain[]>([]);
  const [selectedTemplateId, setSelectedTemplateId] = useState<string | null>(null);
  const [scores, setScores] = useState<ScoreEntry[]>(() =>
    preselectedCapabilityId
      ? [{
          capabilityId: preselectedCapabilityId,
          pillarCode: capabilityList.find((c) => c.id === preselectedCapabilityId)?.pillarCode ?? '',
          criterionId: 'observation',
          score: 0,
          maxScore: 4,
        }]
      : []
  );
  const [domainScores, setDomainScores] = useState<ScoreEntry[]>([]);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [resolvedProofVerified, setResolvedProofVerified] = useState(proofVerified);
  const [loadingProofState, setLoadingProofState] = useState(!proofVerified);

  // Load published rubric templates for the site
  useEffect(() => {
    if (!siteId) return;
    void (async () => {
      try {
        const snap = await getDocs(
          query(rubricTemplatesCollection, where('siteId', '==', siteId), where('status', '==', 'published'))
        );
        setTemplates(snap.docs.map((d) => ({ ...d.data(), id: d.id })));
      } catch (err) {
        console.warn('RubricReviewPanel: failed to load rubric templates:', err);
      }
    })();
  }, [siteId]);

  // Load active process domains for the site
  useEffect(() => {
    if (!siteId) return;
    void (async () => {
      try {
        const snap = await getDocs(
          query(processDomainsCollection, where('siteId', '==', siteId), where('status', '==', 'active'))
        );
        setProcessDomains(snap.docs.map((d) => ({ ...d.data(), id: d.id }) as ProcessDomain));
      } catch (err) {
        console.warn('RubricReviewPanel: failed to load process domains:', err);
      }
    })();
  }, [siteId]);

  useEffect(() => {
    if (proofVerified) {
      setResolvedProofVerified(true);
      setLoadingProofState(false);
      return;
    }
    if (!siteId) {
      setResolvedProofVerified(false);
      setLoadingProofState(false);
      return;
    }

    let cancelled = false;

    void (async () => {
      setLoadingProofState(true);
      try {
        const portfolioSnaps: Array<Promise<unknown>> = [];
        const directPortfolioSnap = portfolioItemId
          ? getDoc(doc(portfolioItemsCollection, portfolioItemId))
          : null;
        if (missionAttemptId) {
          portfolioSnaps.push(
            getDocs(
              query(
                portfolioItemsCollection,
                where('siteId', '==', siteId),
                where('missionAttemptId', '==', missionAttemptId)
              )
            )
          );
        }
        for (const evidenceRecordId of evidenceRecordIds) {
          portfolioSnaps.push(
            getDocs(
              query(
                portfolioItemsCollection,
                where('siteId', '==', siteId),
                where('evidenceRecordIds', 'array-contains', evidenceRecordId)
              )
            )
          );
        }

        const directResult = directPortfolioSnap ? await directPortfolioSnap : null;
        const results = await Promise.all(portfolioSnaps);
        const directProofVerified =
          directResult?.exists() === true && directResult.data().proofOfLearningStatus === 'verified';
        const relatedProofVerified = results.some((snap) =>
          (snap as { docs: Array<{ data: () => Record<string, unknown> }> }).docs.some(
            (docSnap) => docSnap.data().proofOfLearningStatus === 'verified'
          )
        );
        const hasVerifiedProof = directProofVerified || relatedProofVerified;

        if (!cancelled) {
          setResolvedProofVerified(hasVerifiedProof);
        }
      } catch (err) {
        console.warn('RubricReviewPanel: failed to resolve proof-of-learning status:', err);
        if (!cancelled) {
          setResolvedProofVerified(false);
        }
      } finally {
        if (!cancelled) {
          setLoadingProofState(false);
        }
      }
    })();

    return () => {
      cancelled = true;
    };
  }, [proofVerified, siteId, missionAttemptId, evidenceRecordIds, portfolioItemId]);

  const effectiveProofVerified = proofVerified || resolvedProofVerified;

  // When a template is selected, populate scores from its criteria
  const applyTemplate = useCallback((templateId: string) => {
    const tpl = templates.find((t) => t.id === templateId);
    if (!tpl) return;
    setSelectedTemplateId(templateId);
    const capScores: ScoreEntry[] = [];
    const domScores: ScoreEntry[] = [];
    for (const c of tpl.criteria) {
      const entry: ScoreEntry = {
        capabilityId: c.capabilityId,
        processDomainId: c.processDomainId,
        pillarCode: c.pillarCode ?? capabilityList.find((cap) => cap.id === c.capabilityId)?.pillarCode ?? '',
        criterionId: c.label,
        score: 0,
        maxScore: c.maxScore || 4,
      };
      if (c.processDomainId) {
        domScores.push(entry);
      } else {
        capScores.push(entry);
      }
    }
    setScores(capScores);
    setDomainScores(domScores);
  }, [templates, capabilityList]);

  // Find templates that match the current capability selection
  const _matchingTemplates = useMemo(() => {
    const capIds = new Set(scores.map((s) => s.capabilityId));
    return templates.filter((t) =>
      t.capabilityIds.some((cid) => capIds.has(cid)) || t.capabilityIds.length === 0
    );
  }, [templates, scores]);

  // Get descriptors for a score entry from the selected template
  const getDescriptor = useCallback((capabilityId: string, level: number): string | undefined => {
    if (!selectedTemplateId) return undefined;
    const tpl = templates.find((t) => t.id === selectedTemplateId);
    if (!tpl) return undefined;
    const criterion = tpl.criteria.find((c) => c.capabilityId === capabilityId);
    if (!criterion?.descriptors) return undefined;
    const levelMap: Record<number, keyof NonNullable<typeof criterion.descriptors>> = {
      1: 'beginning', 2: 'developing', 3: 'proficient', 4: 'advanced',
    };
    return criterion.descriptors[levelMap[level]];
  }, [selectedTemplateId, templates]);

  const addCapabilityScore = useCallback((capId: string) => {
    const cap = capabilityList.find((c) => c.id === capId);
    if (!cap) return;
    if (scores.some((s) => s.capabilityId === capId)) return;
    setScores((prev) => [
      ...prev,
      {
        capabilityId: capId,
        pillarCode: cap.pillarCode,
        criterionId: `criterion-${capId}`,
        score: 0,
        maxScore: 4,
      },
    ]);
  }, [capabilityList, scores]);

  const updateScore = useCallback((capabilityId: string, level: number) => {
    setScores((prev) =>
      prev.map((s) =>
        s.capabilityId === capabilityId ? { ...s, score: level } : s
      )
    );
  }, []);

  const removeScore = useCallback((capabilityId: string) => {
    setScores((prev) => prev.filter((s) => s.capabilityId !== capabilityId));
  }, []);

  const addProcessDomainScore = useCallback((domainId: string) => {
    if (domainScores.some((s) => s.processDomainId === domainId)) return;
    const domain = processDomains.find((d) => d.id === domainId);
    if (!domain) return;
    setDomainScores((prev) => [
      ...prev,
      {
        capabilityId: '',
        processDomainId: domainId,
        pillarCode: '',
        criterionId: `process-domain-${domainId}`,
        score: 0,
        maxScore: 4,
      },
    ]);
  }, [processDomains, domainScores]);

  const updateDomainScore = useCallback((domainId: string, level: number) => {
    setDomainScores((prev) =>
      prev.map((s) =>
        s.processDomainId === domainId ? { ...s, score: level } : s
      )
    );
  }, []);

  const removeDomainScore = useCallback((domainId: string) => {
    setDomainScores((prev) => prev.filter((s) => s.processDomainId !== domainId));
  }, []);

  const getProcessDomainDescriptor = useCallback((domainId: string, level: number): string | undefined => {
    const domain = processDomains.find((d) => d.id === domainId);
    if (!domain?.progressionDescriptors) return undefined;
    const levelMap: Record<number, keyof NonNullable<typeof domain.progressionDescriptors>> = {
      1: 'beginning', 2: 'developing', 3: 'proficient', 4: 'advanced',
    };
    return domain.progressionDescriptors[levelMap[level]];
  }, [processDomains]);

  const resolveDomainTitle = useCallback((domainId: string): string => {
    return processDomains.find((d) => d.id === domainId)?.title ?? domainId;
  }, [processDomains]);

  const canSubmit = useMemo(
    () => {
      const allScores = [...scores, ...domainScores];
      return allScores.length > 0 && allScores.every((s) => s.score > 0);
    },
    [scores, domainScores]
  );

  const handleSubmit = useCallback(async () => {
    if (!effectiveProofVerified) {
      setError('Verify proof-of-learning before applying a rubric that updates capability growth.');
      return;
    }
    if (!canSubmit) return;
    setSaving(true);
    setError(null);

    try {
      const applyRubric = httpsCallable(functions, 'applyRubricToEvidence');
      const allScores = [...scores, ...domainScores];
      await applyRubric({
        portfolioItemId: portfolioItemId ?? undefined,
        evidenceRecordIds,
        missionAttemptId: missionAttemptId ?? undefined,
        learnerId,
        siteId,
        rubricId: selectedTemplateId ?? undefined,
        scores: allScores.map((s) => ({
          criterionId: s.criterionId,
          capabilityId: s.capabilityId || undefined,
          processDomainId: s.processDomainId || undefined,
          pillarCode: s.pillarCode || undefined,
          score: s.score,
          maxScore: s.maxScore,
        })),
      });
      onComplete();
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : 'Failed to apply rubric';
      setError(message);
    } finally {
      setSaving(false);
    }
  }, [effectiveProofVerified, canSubmit, portfolioItemId, evidenceRecordIds, missionAttemptId, learnerId, siteId, scores, domainScores, selectedTemplateId, onComplete]);

  const unusedCapabilities = useMemo(
    () => capabilityList.filter((c) => !scores.some((s) => s.capabilityId === c.id)),
    [capabilityList, scores]
  );

  return (
    <div className="rounded-xl border border-app bg-app-surface-raised p-4 space-y-4">
      <div className="flex items-start justify-between">
        <div>
          <h3 className="text-sm font-semibold text-app-foreground">
            Rubric Review — {learnerName}
          </h3>
          <p className="mt-1 text-xs text-app-muted line-clamp-2">{description}</p>
        </div>
        <button
          type="button"
          onClick={onCancel}
          className="text-xs text-app-muted hover:text-app-foreground"
        >
          Cancel
        </button>
      </div>

      {/* Rubric template selector */}
      {templates.length > 0 && (
        <div className="rounded-lg border border-blue-200 bg-blue-50 p-3 space-y-2">
          <label className="text-xs font-semibold text-blue-800">Use rubric template</label>
          <select
            aria-label="Select rubric template"
            value={selectedTemplateId ?? ''}
            onChange={(e) => {
              if (e.target.value) {
                applyTemplate(e.target.value);
              } else {
                setSelectedTemplateId(null);
              }
            }}
            className="w-full rounded-md border border-blue-200 bg-white px-3 py-2 text-sm text-app-foreground"
          >
            <option value="">Ad-hoc scoring (no template)</option>
            {templates.map((t) => (
              <option key={t.id} value={t.id}>
                {t.title} ({t.criteria.length} criteria)
              </option>
            ))}
          </select>
        </div>
      )}

      {/* Capability score cards */}
      {scores.map((s) => (
        <div key={s.capabilityId} className="rounded-lg border border-app bg-app-canvas p-3 space-y-2">
          <div className="flex items-center justify-between">
            <span className="text-sm font-medium text-app-foreground">
              {resolveTitle(s.capabilityId)}
            </span>
            <button
              type="button"
              onClick={() => removeScore(s.capabilityId)}
              className="text-xs text-red-500 hover:text-red-700"
            >
              Remove
            </button>
          </div>
          <div className="flex gap-2">
            {scoreLevelsForMax(s.maxScore).map((level) => (
              <button
                key={level.value}
                type="button"
                onClick={() => updateScore(s.capabilityId, level.value)}
                className={`flex-1 rounded-md border px-2 py-1.5 text-xs font-medium transition-all ${
                  s.score === level.value
                    ? level.color + ' ring-2 ring-offset-1 ring-primary/40'
                    : 'border-app bg-app-surface text-app-muted hover:bg-app-canvas'
                }`}
              >
                {level.label}
              </button>
            ))}
          </div>
          {s.score > 0 && getDescriptor(s.capabilityId, s.score) && (
            <p className="text-xs text-app-muted italic pl-1">
              {getDescriptor(s.capabilityId, s.score)}
            </p>
          )}
        </div>
      ))}

      {/* Add capability */}
      {unusedCapabilities.length > 0 && (
        <div className="flex items-center gap-2">
          <select
            aria-label="Add capability to assess"
            onChange={(e) => {
              if (e.target.value) {
                addCapabilityScore(e.target.value);
                e.target.value = '';
              }
            }}
            className="flex-1 rounded-md border border-app bg-app-canvas px-3 py-2 text-sm text-app-foreground"
            defaultValue=""
          >
            <option value="">+ Add capability to assess</option>
            {unusedCapabilities.map((c) => (
              <option key={c.id} value={c.id}>
                {c.title} ({c.pillarCode.replace(/_/g, ' ')})
              </option>
            ))}
          </select>
        </div>
      )}

      {/* Process domain score cards */}
      {domainScores.length > 0 && (
        <div className="space-y-2">
          <h4 className="text-xs font-semibold text-app-muted uppercase tracking-wide">Process Domains</h4>
          {domainScores.map((s) => (
            <div key={s.processDomainId} className="rounded-lg border border-purple-200 bg-purple-50/50 p-3 space-y-2">
              <div className="flex items-center justify-between">
                <span className="text-sm font-medium text-purple-900">
                  {resolveDomainTitle(s.processDomainId!)}
                </span>
                <button
                  type="button"
                  onClick={() => removeDomainScore(s.processDomainId!)}
                  className="text-xs text-red-500 hover:text-red-700"
                >
                  Remove
                </button>
              </div>
              <div className="flex gap-2">
                {scoreLevelsForMax(s.maxScore).map((level) => (
                  <button
                    key={level.value}
                    type="button"
                    onClick={() => updateDomainScore(s.processDomainId!, level.value)}
                    className={`flex-1 rounded-md border px-2 py-1.5 text-xs font-medium transition-all ${
                      s.score === level.value
                        ? level.color + ' ring-2 ring-offset-1 ring-purple-400/40'
                        : 'border-app bg-app-surface text-app-muted hover:bg-app-canvas'
                    }`}
                  >
                    {level.label}
                  </button>
                ))}
              </div>
              {s.score > 0 && getProcessDomainDescriptor(s.processDomainId!, s.score) && (
                <p className="text-xs text-purple-700 italic pl-1">
                  {getProcessDomainDescriptor(s.processDomainId!, s.score)}
                </p>
              )}
            </div>
          ))}
        </div>
      )}

      {/* Add process domain */}
      {processDomains.length > 0 && (
        <div className="flex items-center gap-2">
          <select
            aria-label="Add process domain to assess"
            onChange={(e) => {
              if (e.target.value) {
                addProcessDomainScore(e.target.value);
                e.target.value = '';
              }
            }}
            className="flex-1 rounded-md border border-purple-200 bg-purple-50/30 px-3 py-2 text-sm text-app-foreground"
            defaultValue=""
          >
            <option value="">+ Add process domain to assess</option>
            {processDomains
              .filter((d) => !domainScores.some((s) => s.processDomainId === d.id))
              .map((d) => (
                <option key={d.id} value={d.id}>
                  {d.title}
                </option>
              ))}
          </select>
        </div>
      )}

      {capabilityList.length === 0 && (
        <p className="text-xs text-amber-700 bg-amber-50 rounded-md px-3 py-2 border border-amber-200">
          No capabilities defined for this site. Define capabilities in HQ before reviewing evidence.
        </p>
      )}

      <p
        className={`rounded-md border px-3 py-2 text-xs ${
          loadingProofState
            ? 'border-blue-200 bg-blue-50 text-blue-800'
            : effectiveProofVerified
            ? 'border-green-200 bg-green-50 text-green-800'
            : 'border-amber-200 bg-amber-50 text-amber-900'
        }`}
        data-testid="rubric-review-proof-gate"
      >
        {loadingProofState
          ? 'Checking proof-of-learning status before allowing capability growth updates.'
          : effectiveProofVerified
          ? 'Proof of learning is verified. This rubric review can update capability growth.'
          : 'Verify proof-of-learning before applying a rubric that updates capability growth.'}
      </p>

      {error && (
        <p className="text-xs text-red-600 bg-red-50 rounded-md px-3 py-2 border border-red-200">
          {error}
        </p>
      )}

      {/* Submit */}
      <div className="flex gap-2">
        <button
          type="button"
          onClick={() => void handleSubmit()}
          disabled={!canSubmit || saving || loadingProofState || !effectiveProofVerified}
          className="rounded-md bg-primary px-4 py-2 text-sm font-semibold text-primary-foreground disabled:opacity-50"
        >
          {saving ? 'Applying...' : `Apply Rubric (${scores.length + domainScores.length} scores)`}
        </button>
        <button
          type="button"
          onClick={onCancel}
          className="rounded-md border border-app px-4 py-2 text-sm text-app-muted hover:bg-app-canvas"
        >
          Cancel
        </button>
      </div>
    </div>
  );
}
