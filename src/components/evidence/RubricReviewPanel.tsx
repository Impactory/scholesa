'use client';

import { useCallback, useEffect, useMemo, useState } from 'react';
import { httpsCallable } from 'firebase/functions';
import { getDocs, query, where } from 'firebase/firestore';
import { functions } from '@/src/firebase/client-init';
import { rubricTemplatesCollection } from '@/src/firebase/firestore/collections';
import { useCapabilities } from '@/src/lib/capabilities/useCapabilities';
import { Spinner } from '@/src/components/ui/Spinner';
import type { RubricTemplate } from '@/src/types/schema';

interface RubricReviewPanelProps {
  evidenceRecordIds: string[];
  learnerId: string;
  learnerName: string;
  siteId: string;
  description: string;
  capabilityId?: string;
  onComplete: () => void;
  onCancel: () => void;
}

interface ScoreEntry {
  capabilityId: string;
  pillarCode: string;
  criterionId: string;
  score: number;
  maxScore: number;
}

const SCORE_LEVELS = [
  { value: 1, label: 'Beginning', color: 'bg-red-100 text-red-800 border-red-300' },
  { value: 2, label: 'Developing', color: 'bg-amber-100 text-amber-800 border-amber-300' },
  { value: 3, label: 'Proficient', color: 'bg-blue-100 text-blue-800 border-blue-300' },
  { value: 4, label: 'Advanced', color: 'bg-green-100 text-green-800 border-green-300' },
];

export function RubricReviewPanel({
  evidenceRecordIds,
  learnerId,
  learnerName,
  siteId,
  description,
  capabilityId: preselectedCapabilityId,
  onComplete,
  onCancel,
}: RubricReviewPanelProps) {
  const { capabilityList, resolveTitle } = useCapabilities(siteId);
  const [templates, setTemplates] = useState<RubricTemplate[]>([]);
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
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Load published rubric templates for the site
  useEffect(() => {
    if (!siteId) return;
    void (async () => {
      try {
        const snap = await getDocs(
          query(rubricTemplatesCollection, where('status', '==', 'published'))
        );
        setTemplates(snap.docs.map((d) => ({ ...d.data(), id: d.id })));
      } catch {
        // Templates are optional — fall back to ad-hoc scoring
      }
    })();
  }, [siteId]);

  // When a template is selected, populate scores from its criteria
  const applyTemplate = useCallback((templateId: string) => {
    const tpl = templates.find((t) => t.id === templateId);
    if (!tpl) return;
    setSelectedTemplateId(templateId);
    setScores(
      tpl.criteria.map((c) => ({
        capabilityId: c.capabilityId,
        pillarCode: c.pillarCode ?? capabilityList.find((cap) => cap.id === c.capabilityId)?.pillarCode ?? '',
        criterionId: c.label,
        score: 0,
        maxScore: c.maxScore || 4,
      }))
    );
  }, [templates, capabilityList]);

  // Find templates that match the current capability selection
  const matchingTemplates = useMemo(() => {
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

  const canSubmit = useMemo(
    () => scores.length > 0 && scores.every((s) => s.score > 0),
    [scores]
  );

  const handleSubmit = useCallback(async () => {
    if (!canSubmit) return;
    setSaving(true);
    setError(null);

    try {
      const applyRubric = httpsCallable(functions, 'applyRubricToEvidence');
      await applyRubric({
        evidenceRecordIds,
        learnerId,
        siteId,
        rubricId: selectedTemplateId ?? undefined,
        scores: scores.map((s) => ({
          criterionId: s.criterionId,
          capabilityId: s.capabilityId,
          pillarCode: s.pillarCode,
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
  }, [canSubmit, evidenceRecordIds, learnerId, siteId, scores, onComplete]);

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
            {SCORE_LEVELS.map((level) => (
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

      {capabilityList.length === 0 && (
        <p className="text-xs text-amber-700 bg-amber-50 rounded-md px-3 py-2 border border-amber-200">
          No capabilities defined for this site. Define capabilities in HQ before reviewing evidence.
        </p>
      )}

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
          disabled={!canSubmit || saving}
          className="rounded-md bg-primary px-4 py-2 text-sm font-semibold text-primary-foreground disabled:opacity-50"
        >
          {saving ? 'Applying...' : `Apply Rubric (${scores.length} capabilities)`}
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
