'use client';

import { useCallback, useEffect, useState } from 'react';
import {
  addDoc,
  collection,
  doc,
  getDocs,
  orderBy,
  query,
  serverTimestamp,
  updateDoc,
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

interface CapabilityRecord {
  id: string;
  title: string;
  pillarCode: PillarCode;
  descriptor: string;
  progressionLevels: ProgressionLevel[];
  siteId: string | null;
  createdAt: string | null;
  updatedAt: string | null;
}

interface ProgressionLevel {
  level: number;
  label: string;
  description: string;
}

interface RubricRecord {
  id: string;
  name: string;
  description: string;
  status: 'draft' | 'active' | 'archived';
  version: number;
  siteId: string;
  capabilityId?: string;
  pillarId?: string;
  criteriaCount: number;
  createdAt: string | null;
}

const PILLAR_OPTIONS: { value: PillarCode; label: string }[] = [
  { value: 'FUTURE_SKILLS', label: 'Future Skills' },
  { value: 'LEADERSHIP_AGENCY', label: 'Leadership & Agency' },
  { value: 'IMPACT_INNOVATION', label: 'Impact & Innovation' },
];

const DEFAULT_PROGRESSION_LEVELS: ProgressionLevel[] = [
  { level: 1, label: 'Emerging', description: '' },
  { level: 2, label: 'Developing', description: '' },
  { level: 3, label: 'Proficient', description: '' },
  { level: 4, label: 'Advanced', description: '' },
];

type ActiveTab = 'capabilities' | 'rubrics';

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

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

export default function HqCapabilityFrameworkRenderer({ ctx }: CustomRouteRendererProps) {
  const trackInteraction = useInteractionTracking();
  const [activeTab, setActiveTab] = useState<ActiveTab>('capabilities');
  const [capabilities, setCapabilities] = useState<CapabilityRecord[]>([]);
  const [rubrics, setRubrics] = useState<RubricRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // ---- Create capability form state ----
  const [showCreateCapability, setShowCreateCapability] = useState(false);
  const [newCapTitle, setNewCapTitle] = useState('');
  const [newCapPillar, setNewCapPillar] = useState<PillarCode>('FUTURE_SKILLS');
  const [newCapDescriptor, setNewCapDescriptor] = useState('');
  const [newCapProgressionLevels, setNewCapProgressionLevels] = useState<ProgressionLevel[]>(
    DEFAULT_PROGRESSION_LEVELS.map((l) => ({ ...l }))
  );
  const [saving, setSaving] = useState(false);

  // ---- Create rubric form state ----
  const [showCreateRubric, setShowCreateRubric] = useState(false);
  const [newRubricName, setNewRubricName] = useState('');
  const [newRubricDescription, setNewRubricDescription] = useState('');
  const [newRubricPillar, setNewRubricPillar] = useState<PillarCode>('FUTURE_SKILLS');

  // ---- Edit capability state ----
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editDescriptor, setEditDescriptor] = useState('');
  const [editProgressionLevels, setEditProgressionLevels] = useState<ProgressionLevel[]>([]);

  // ---- Data loading ----
  const loadData = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const [capSnap, rubricSnap] = await Promise.all([
        getDocs(query(collection(firestore, 'capabilities'), orderBy('title', 'asc'))),
        getDocs(
          query(collection(firestore, 'assessmentRubrics'), orderBy('createdAt', 'desc'))
        ),
      ]);

      setCapabilities(
        capSnap.docs.map((d: QueryDocumentSnapshot<DocumentData>) => {
          const data = d.data();
          const progressionLevels = Array.isArray(data.progressionLevels)
            ? (data.progressionLevels as ProgressionLevel[])
            : [];
          return {
            id: d.id,
            title: asString(data.title, d.id),
            pillarCode: (asString(data.pillarCode, 'FUTURE_SKILLS') as PillarCode),
            descriptor: asString(data.descriptor, ''),
            progressionLevels,
            siteId: typeof data.siteId === 'string' ? data.siteId : null,
            createdAt: toIso(data.createdAt),
            updatedAt: toIso(data.updatedAt),
          };
        })
      );

      setRubrics(
        rubricSnap.docs.map((d: QueryDocumentSnapshot<DocumentData>) => {
          const data = d.data();
          const criteria = Array.isArray(data.criteria) ? data.criteria : [];
          return {
            id: d.id,
            name: asString(data.name, d.id),
            description: asString(data.description, ''),
            status: (['draft', 'active', 'archived'].includes(data.status) ? data.status : 'draft') as
              | 'draft'
              | 'active'
              | 'archived',
            version: typeof data.version === 'number' ? data.version : 1,
            siteId: asString(data.siteId, '*'),
            capabilityId: typeof data.capabilityId === 'string' ? data.capabilityId : undefined,
            pillarId: typeof data.pillarId === 'string' ? data.pillarId : undefined,
            criteriaCount: criteria.length,
            createdAt: toIso(data.createdAt),
          };
        })
      );
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load framework data.');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void loadData();
  }, [loadData]);

  // ---- Capability CRUD ----
  const handleCreateCapability = async () => {
    if (!newCapTitle.trim()) return;
    setSaving(true);
    try {
      await addDoc(collection(firestore, 'capabilities'), {
        title: newCapTitle.trim(),
        normalizedTitle: newCapTitle.trim().toLowerCase(),
        pillarCode: newCapPillar,
        descriptor: newCapDescriptor.trim(),
        progressionLevels: newCapProgressionLevels.filter((l: ProgressionLevel) => l.description.trim().length > 0),
        siteId: null,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      });
      trackInteraction('feature_discovered', { cta: 'capability_created', pillar: newCapPillar });
      setNewCapTitle('');
      setNewCapDescriptor('');
      setNewCapProgressionLevels(DEFAULT_PROGRESSION_LEVELS.map((l) => ({ ...l })));
      setShowCreateCapability(false);
      await loadData();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to create capability.');
    } finally {
      setSaving(false);
    }
  };

  const handleUpdateCapability = async (capId: string) => {
    setSaving(true);
    try {
      await updateDoc(doc(firestore, 'capabilities', capId), {
        descriptor: editDescriptor.trim(),
        progressionLevels: editProgressionLevels.filter((l: ProgressionLevel) => l.description.trim().length > 0),
        updatedAt: serverTimestamp(),
      });
      trackInteraction('feature_discovered', { cta: 'capability_updated', capId });
      setEditingId(null);
      await loadData();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to update capability.');
    } finally {
      setSaving(false);
    }
  };

  // ---- Rubric CRUD ----
  const handleCreateRubric = async () => {
    if (!newRubricName.trim()) return;
    setSaving(true);
    try {
      await addDoc(collection(firestore, 'assessmentRubrics'), {
        name: newRubricName.trim(),
        description: newRubricDescription.trim(),
        version: 1,
        status: 'draft',
        siteId: '*',
        pillarId: newRubricPillar,
        criteria: [
          {
            name: 'Evidence Quality',
            description: 'Quality and depth of evidence provided',
            weight: 0.5,
            levels: [
              { name: 'Emerging', description: '', score: 1 },
              { name: 'Developing', description: '', score: 2 },
              { name: 'Proficient', description: '', score: 3 },
              { name: 'Advanced', description: '', score: 4 },
            ],
          },
          {
            name: 'Capability Demonstration',
            description: 'Demonstration of the target capability',
            weight: 0.5,
            levels: [
              { name: 'Emerging', description: '', score: 1 },
              { name: 'Developing', description: '', score: 2 },
              { name: 'Proficient', description: '', score: 3 },
              { name: 'Advanced', description: '', score: 4 },
            ],
          },
        ],
        tags: [newRubricPillar.toLowerCase()],
        createdBy: ctx.uid,
        createdAt: serverTimestamp(),
      });
      trackInteraction('feature_discovered', { cta: 'rubric_created' });
      setNewRubricName('');
      setNewRubricDescription('');
      setShowCreateRubric(false);
      await loadData();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to create rubric.');
    } finally {
      setSaving(false);
    }
  };

  const handleToggleRubricStatus = async (rubric: RubricRecord) => {
    setSaving(true);
    try {
      const nextStatus = rubric.status === 'active' ? 'draft' : 'active';
      await updateDoc(doc(firestore, 'assessmentRubrics', rubric.id), {
        status: nextStatus,
        updatedAt: serverTimestamp(),
        updatedBy: ctx.uid,
      });
      await loadData();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to update rubric status.');
    } finally {
      setSaving(false);
    }
  };

  const handleArchiveRubric = async (rubricId: string) => {
    setSaving(true);
    try {
      await updateDoc(doc(firestore, 'assessmentRubrics', rubricId), {
        status: 'archived',
        updatedAt: serverTimestamp(),
        updatedBy: ctx.uid,
      });
      await loadData();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to archive rubric.');
    } finally {
      setSaving(false);
    }
  };

  // ---- Progression level helpers ----
  const updateProgressionLevel = (
    levels: ProgressionLevel[],
    setLevels: (l: ProgressionLevel[]) => void,
    index: number,
    field: 'label' | 'description',
    value: string
  ) => {
    const updated = [...levels];
    updated[index] = { ...updated[index], [field]: value };
    setLevels(updated);
  };

  // ---- Pillar label helper ----
  const pillarLabel = (code: string) =>
    PILLAR_OPTIONS.find((p) => p.value === code)?.label ?? code;

  // ---- Pillar badge color ----
  const pillarBadgeClass = (code: string) => {
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
  };

  // ---- Group capabilities by pillar ----
  const capsByPillar = PILLAR_OPTIONS.map((pillar) => ({
    pillar,
    items: capabilities.filter((c: CapabilityRecord) => c.pillarCode === pillar.value),
  }));

  // ---- Render ----
  return (
    <section className="space-y-6" data-testid="hq-capability-framework">
      <header className="rounded-xl border border-app bg-app-surface-raised p-6">
        <h1 className="text-2xl font-bold text-app-foreground">Capability Framework</h1>
        <p className="mt-2 text-sm text-app-muted">
          Define capabilities, progression descriptors, and rubrics that form the foundation of the
          evidence chain. Everything downstream depends on this.
        </p>

        {/* Tab navigation */}
        <div className="mt-4 flex gap-2">
          <button
            type="button"
            onClick={() => setActiveTab('capabilities')}
            className={`rounded-md px-4 py-2 text-sm font-medium ${
              activeTab === 'capabilities'
                ? 'bg-primary text-primary-foreground'
                : 'bg-app-canvas text-app-muted hover:text-app-foreground'
            }`}
          >
            Capabilities ({capabilities.length})
          </button>
          <button
            type="button"
            onClick={() => setActiveTab('rubrics')}
            className={`rounded-md px-4 py-2 text-sm font-medium ${
              activeTab === 'rubrics'
                ? 'bg-primary text-primary-foreground'
                : 'bg-app-canvas text-app-muted hover:text-app-foreground'
            }`}
          >
            Rubrics ({rubrics.length})
          </button>
        </div>
      </header>

      {error && (
        <div className="rounded-xl border border-red-200 bg-red-50 p-4 text-sm text-red-700">
          {error}
        </div>
      )}

      {loading ? (
        <div className="flex min-h-[240px] items-center justify-center rounded-xl border border-app bg-app-surface">
          <div className="flex items-center gap-2 text-app-muted">
            <Spinner />
            <span>Loading framework data...</span>
          </div>
        </div>
      ) : activeTab === 'capabilities' ? (
        /* ============================================================
         * CAPABILITIES TAB
         * ============================================================ */
        <div className="space-y-6">
          {/* Create capability button */}
          <div className="flex gap-3">
            <button
              type="button"
              onClick={() => setShowCreateCapability((prev: boolean) => !prev)}
              className="rounded-md bg-primary px-4 py-2 text-sm font-semibold text-primary-foreground hover:bg-primary/90"
              data-testid="create-capability-toggle"
            >
              {showCreateCapability ? 'Cancel' : 'Define Capability'}
            </button>
            <button
              type="button"
              onClick={() => void loadData()}
              className="rounded-md border border-app px-3 py-2 text-sm text-app-foreground hover:bg-app-canvas"
            >
              Refresh
            </button>
          </div>

          {/* Create capability form */}
          {showCreateCapability && (
            <div
              className="rounded-xl border border-app bg-app-surface p-5 space-y-4"
              data-testid="create-capability-form"
            >
              <h2 className="text-base font-semibold text-app-foreground">Define New Capability</h2>

              <div className="grid gap-4 md:grid-cols-2">
                <label className="space-y-1">
                  <span className="text-xs font-medium text-app-muted">Capability Title *</span>
                  <input
                    type="text"
                    value={newCapTitle}
                    onChange={(e: React.ChangeEvent<HTMLInputElement>) => setNewCapTitle(e.target.value)}
                    placeholder="e.g. Computational Thinking"
                    className="w-full rounded-md border border-app bg-app-canvas px-3 py-2 text-sm text-app-foreground"
                    data-testid="capability-title-input"
                  />
                </label>

                <label className="space-y-1">
                  <span className="text-xs font-medium text-app-muted">Pillar *</span>
                  <select
                    value={newCapPillar}
                    onChange={(e: React.ChangeEvent<HTMLSelectElement>) => setNewCapPillar(e.target.value as PillarCode)}
                    className="w-full rounded-md border border-app bg-app-canvas px-3 py-2 text-sm text-app-foreground"
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
                <span className="text-xs font-medium text-app-muted">Descriptor</span>
                <textarea
                  value={newCapDescriptor}
                  onChange={(e: React.ChangeEvent<HTMLTextAreaElement>) => setNewCapDescriptor(e.target.value)}
                  placeholder="What this capability means and how it is demonstrated..."
                  className="w-full rounded-md border border-app bg-app-canvas px-3 py-2 text-sm text-app-foreground min-h-20"
                />
              </label>

              {/* Progression levels */}
              <div className="space-y-2">
                <span className="text-xs font-medium text-app-muted">Progression Levels</span>
                {newCapProgressionLevels.map((level: ProgressionLevel, i: number) => (
                  <div key={level.level} className="flex gap-2 items-start">
                    <span className="mt-2 w-6 text-center text-xs font-bold text-app-muted">
                      {level.level}
                    </span>
                    <input
                      type="text"
                      value={level.label}
                      onChange={(e: React.ChangeEvent<HTMLInputElement>) =>
                        updateProgressionLevel(
                          newCapProgressionLevels,
                          setNewCapProgressionLevels,
                          i,
                          'label',
                          e.target.value
                        )
                      }
                      placeholder="Level label"
                      className="w-32 rounded-md border border-app bg-app-canvas px-2 py-1.5 text-sm"
                    />
                    <input
                      type="text"
                      value={level.description}
                      onChange={(e: React.ChangeEvent<HTMLInputElement>) =>
                        updateProgressionLevel(
                          newCapProgressionLevels,
                          setNewCapProgressionLevels,
                          i,
                          'description',
                          e.target.value
                        )
                      }
                      placeholder="What this level looks like..."
                      className="flex-1 rounded-md border border-app bg-app-canvas px-2 py-1.5 text-sm"
                    />
                  </div>
                ))}
              </div>

              <button
                type="button"
                disabled={saving || !newCapTitle.trim()}
                onClick={() => void handleCreateCapability()}
                className="rounded-md bg-primary px-4 py-2 text-sm font-semibold text-primary-foreground disabled:opacity-50"
                data-testid="create-capability-submit"
              >
                {saving ? 'Saving...' : 'Create Capability'}
              </button>
            </div>
          )}

          {/* Capabilities grouped by pillar */}
          {capsByPillar.map(({ pillar, items }) => (
            <div key={pillar.value} className="space-y-3">
              <h3 className="text-sm font-semibold text-app-foreground flex items-center gap-2">
                <span className={`rounded-full px-2.5 py-0.5 text-xs font-medium ${pillarBadgeClass(pillar.value)}`}>
                  {pillar.label}
                </span>
                <span className="text-app-muted">({items.length} capabilities)</span>
              </h3>

              {items.length === 0 ? (
                <div className="rounded-lg border border-dashed border-app bg-app-surface p-4 text-center text-sm text-app-muted">
                  No capabilities defined for this pillar yet.
                </div>
              ) : (
                <ul className="grid gap-3">
                  {items.map((cap: CapabilityRecord) => (
                    <li
                      key={cap.id}
                      className="rounded-xl border border-app bg-app-surface-raised p-4"
                      data-testid={`capability-${cap.id}`}
                    >
                      {editingId === cap.id ? (
                        /* Inline edit mode */
                        <div className="space-y-3">
                          <h4 className="text-base font-semibold text-app-foreground">
                            {cap.title}
                          </h4>
                          <label className="block space-y-1">
                            <span className="text-xs font-medium text-app-muted">Descriptor</span>
                            <textarea
                              value={editDescriptor}
                              onChange={(e: React.ChangeEvent<HTMLTextAreaElement>) => setEditDescriptor(e.target.value)}
                              className="w-full rounded-md border border-app bg-app-canvas px-3 py-2 text-sm min-h-16"
                            />
                          </label>
                          <div className="space-y-2">
                            <span className="text-xs font-medium text-app-muted">
                              Progression Levels
                            </span>
                            {editProgressionLevels.map((level: ProgressionLevel, i: number) => (
                              <div key={level.level} className="flex gap-2 items-start">
                                <span className="mt-2 w-6 text-center text-xs font-bold text-app-muted">
                                  {level.level}
                                </span>
                                <input
                                  type="text"
                                  value={level.label}
                                  onChange={(e: React.ChangeEvent<HTMLInputElement>) =>
                                    updateProgressionLevel(
                                      editProgressionLevels,
                                      setEditProgressionLevels,
                                      i,
                                      'label',
                                      e.target.value
                                    )
                                  }
                                  className="w-32 rounded-md border border-app bg-app-canvas px-2 py-1.5 text-sm"
                                />
                                <input
                                  type="text"
                                  value={level.description}
                                  onChange={(e: React.ChangeEvent<HTMLInputElement>) =>
                                    updateProgressionLevel(
                                      editProgressionLevels,
                                      setEditProgressionLevels,
                                      i,
                                      'description',
                                      e.target.value
                                    )
                                  }
                                  placeholder="What this level looks like..."
                                  className="flex-1 rounded-md border border-app bg-app-canvas px-2 py-1.5 text-sm"
                                />
                              </div>
                            ))}
                          </div>
                          <div className="flex gap-2">
                            <button
                              type="button"
                              disabled={saving}
                              onClick={() => void handleUpdateCapability(cap.id)}
                              className="rounded-md bg-primary px-3 py-1.5 text-xs font-semibold text-primary-foreground disabled:opacity-50"
                            >
                              {saving ? 'Saving...' : 'Save'}
                            </button>
                            <button
                              type="button"
                              onClick={() => setEditingId(null)}
                              className="rounded-md border border-app px-3 py-1.5 text-xs text-app-foreground"
                            >
                              Cancel
                            </button>
                          </div>
                        </div>
                      ) : (
                        /* Display mode */
                        <div className="flex flex-wrap items-start justify-between gap-3">
                          <div className="space-y-1 flex-1">
                            <h4 className="text-base font-semibold text-app-foreground">
                              {cap.title}
                            </h4>
                            {cap.descriptor && (
                              <p className="text-sm text-app-muted">{cap.descriptor}</p>
                            )}
                            {cap.progressionLevels.length > 0 && (
                              <div className="mt-2 flex flex-wrap gap-1.5">
                                {cap.progressionLevels.map((level: ProgressionLevel) => (
                                  <span
                                    key={level.level}
                                    className="inline-flex items-center gap-1 rounded-full bg-app-canvas px-2 py-0.5 text-xs text-app-muted"
                                    title={level.description || level.label}
                                  >
                                    <span className="font-semibold">{level.level}</span>
                                    {level.label}
                                  </span>
                                ))}
                              </div>
                            )}
                            {cap.progressionLevels.length === 0 && (
                              <p className="text-xs text-amber-600">
                                No progression levels defined yet.
                              </p>
                            )}
                          </div>
                          <button
                            type="button"
                            onClick={() => {
                              setEditingId(cap.id);
                              setEditDescriptor(cap.descriptor);
                              setEditProgressionLevels(
                                cap.progressionLevels.length > 0
                                  ? cap.progressionLevels.map((l: ProgressionLevel) => ({ ...l }))
                                  : DEFAULT_PROGRESSION_LEVELS.map((l: ProgressionLevel) => ({ ...l }))
                              );
                            }}
                            className="rounded-md border border-app px-3 py-1.5 text-xs font-medium text-app-foreground hover:bg-app-canvas"
                          >
                            Edit
                          </button>
                        </div>
                      )}
                    </li>
                  ))}
                </ul>
              )}
            </div>
          ))}
        </div>
      ) : (
        /* ============================================================
         * RUBRICS TAB
         * ============================================================ */
        <div className="space-y-6">
          <div className="flex gap-3">
            <button
              type="button"
              onClick={() => setShowCreateRubric((prev: boolean) => !prev)}
              className="rounded-md bg-primary px-4 py-2 text-sm font-semibold text-primary-foreground hover:bg-primary/90"
              data-testid="create-rubric-toggle"
            >
              {showCreateRubric ? 'Cancel' : 'Create Rubric'}
            </button>
            <button
              type="button"
              onClick={() => void loadData()}
              className="rounded-md border border-app px-3 py-2 text-sm text-app-foreground hover:bg-app-canvas"
            >
              Refresh
            </button>
          </div>

          {/* Create rubric form */}
          {showCreateRubric && (
            <div className="rounded-xl border border-app bg-app-surface p-5 space-y-4" data-testid="create-rubric-form">
              <h2 className="text-base font-semibold text-app-foreground">Create New Rubric</h2>

              <div className="grid gap-4 md:grid-cols-2">
                <label className="space-y-1">
                  <span className="text-xs font-medium text-app-muted">Rubric Name *</span>
                  <input
                    type="text"
                    value={newRubricName}
                    onChange={(e: React.ChangeEvent<HTMLInputElement>) => setNewRubricName(e.target.value)}
                    placeholder="e.g. K-3 Evidence Quality Rubric"
                    className="w-full rounded-md border border-app bg-app-canvas px-3 py-2 text-sm"
                  />
                </label>

                <label className="space-y-1">
                  <span className="text-xs font-medium text-app-muted">Pillar</span>
                  <select
                    value={newRubricPillar}
                    onChange={(e: React.ChangeEvent<HTMLSelectElement>) => setNewRubricPillar(e.target.value as PillarCode)}
                    className="w-full rounded-md border border-app bg-app-canvas px-3 py-2 text-sm"
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
                  value={newRubricDescription}
                  onChange={(e: React.ChangeEvent<HTMLTextAreaElement>) => setNewRubricDescription(e.target.value)}
                  placeholder="What this rubric evaluates..."
                  className="w-full rounded-md border border-app bg-app-canvas px-3 py-2 text-sm min-h-20"
                />
              </label>

              <p className="text-xs text-app-muted">
                Rubric will be created with default criteria (Evidence Quality + Capability
                Demonstration) and 4 levels (Emerging through Advanced). You can edit criteria after
                creation.
              </p>

              <button
                type="button"
                disabled={saving || !newRubricName.trim()}
                onClick={() => void handleCreateRubric()}
                className="rounded-md bg-primary px-4 py-2 text-sm font-semibold text-primary-foreground disabled:opacity-50"
                data-testid="create-rubric-submit"
              >
                {saving ? 'Saving...' : 'Create Rubric'}
              </button>
            </div>
          )}

          {/* Rubrics list */}
          {rubrics.length === 0 ? (
            <div className="rounded-xl border border-app bg-app-surface p-8 text-center text-app-muted">
              No rubrics defined yet. Create one to start evaluating evidence.
            </div>
          ) : (
            <ul className="grid gap-3">
              {rubrics.map((rubric: RubricRecord) => (
                <li
                  key={rubric.id}
                  className="rounded-xl border border-app bg-app-surface-raised p-4"
                  data-testid={`rubric-${rubric.id}`}
                >
                  <div className="flex flex-wrap items-start justify-between gap-3">
                    <div className="space-y-1">
                      <h4 className="text-base font-semibold text-app-foreground">
                        {rubric.name}
                      </h4>
                      {rubric.description && (
                        <p className="text-sm text-app-muted">{rubric.description}</p>
                      )}
                      <div className="flex flex-wrap gap-2 text-xs text-app-muted">
                        <span
                          className={`rounded-full px-2 py-0.5 font-medium ${
                            rubric.status === 'active'
                              ? 'bg-green-100 text-green-800'
                              : rubric.status === 'archived'
                              ? 'bg-gray-100 text-gray-500'
                              : 'bg-yellow-100 text-yellow-800'
                          }`}
                        >
                          {rubric.status}
                        </span>
                        <span>v{rubric.version}</span>
                        <span>{rubric.criteriaCount} criteria</span>
                        {rubric.pillarId && (
                          <span className={`rounded-full px-2 py-0.5 font-medium ${pillarBadgeClass(rubric.pillarId)}`}>
                            {pillarLabel(rubric.pillarId)}
                          </span>
                        )}
                      </div>
                    </div>
                    <div className="flex gap-2">
                      <button
                        type="button"
                        disabled={saving}
                        onClick={() => void handleToggleRubricStatus(rubric)}
                        className="rounded-md border border-app px-3 py-1.5 text-xs font-medium text-app-foreground disabled:opacity-50"
                      >
                        {rubric.status === 'active' ? 'Deactivate' : 'Activate'}
                      </button>
                      {rubric.status !== 'archived' && (
                        <button
                          type="button"
                          disabled={saving}
                          onClick={() => void handleArchiveRubric(rubric.id)}
                          className="rounded-md border border-red-200 px-3 py-1.5 text-xs font-medium text-red-700 disabled:opacity-50"
                        >
                          Archive
                        </button>
                      )}
                    </div>
                  </div>
                </li>
              ))}
            </ul>
          )}
        </div>
      )}
    </section>
  );
}
