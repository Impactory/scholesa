'use client';

import { useCallback, useEffect, useMemo, useState } from 'react';
import {
  addDoc,
  deleteField,
  doc,
  getDocs,
  orderBy,
  query,
  serverTimestamp,
  updateDoc,
  where,
} from 'firebase/firestore';
import { useAuthContext } from '@/src/firebase/auth/AuthProvider';
import {
  capabilitiesCollection,
  rubricTemplatesCollection,
} from '@/src/firebase/firestore/collections';
import { invalidateCapabilityCache } from '@/src/lib/capabilities/useCapabilities';
import { RoleRouteGuard } from '@/src/components/auth/RoleRouteGuard';
import { Spinner } from '@/src/components/ui/Spinner';
import type { Capability, PillarCode, RubricTemplate, ProgressionDescriptors } from '@/src/types/schema';

/* ───── Constants ───── */

const PILLAR_OPTIONS: { value: PillarCode; label: string; color: string }[] = [
  { value: 'FUTURE_SKILLS', label: 'Future Skills', color: 'bg-blue-100 text-blue-800 border-blue-300' },
  { value: 'LEADERSHIP_AGENCY', label: 'Leadership & Agency', color: 'bg-amber-100 text-amber-800 border-amber-300' },
  { value: 'IMPACT_INNOVATION', label: 'Impact & Innovation', color: 'bg-emerald-100 text-emerald-800 border-emerald-300' },
];

const LEVEL_LABELS = ['Beginning', 'Developing', 'Proficient', 'Advanced'] as const;

function pillarClass(pillarCode: PillarCode): string {
  return PILLAR_OPTIONS.find((p) => p.value === pillarCode)?.color ?? 'bg-gray-100 text-gray-700';
}

function pillarLabel(pillarCode: PillarCode): string {
  return PILLAR_OPTIONS.find((p) => p.value === pillarCode)?.label ?? pillarCode;
}

/* ───── Types ───── */

type TabKey = 'capabilities' | 'rubricTemplates';

interface CapabilityFormData {
  title: string;
  pillarCode: PillarCode;
  descriptor: string;
  sortOrder: number;
  progressionDescriptors: ProgressionDescriptors;
}

interface RubricTemplateFormData {
  title: string;
  capabilityIds: string[];
  criteria: { label: string; capabilityId: string; maxScore: number }[];
}

const EMPTY_CAPABILITY_FORM: CapabilityFormData = {
  title: '',
  pillarCode: 'FUTURE_SKILLS',
  descriptor: '',
  sortOrder: 0,
  progressionDescriptors: { beginning: '', developing: '', proficient: '', advanced: '' },
};

const EMPTY_RUBRIC_FORM: RubricTemplateFormData = {
  title: '',
  capabilityIds: [],
  criteria: [],
};

/* ───── Main Component ───── */

export function CapabilityFrameworkEditor() {
  const { user, profile, loading: authLoading } = useAuthContext();
  const siteId = profile?.studioId ?? null;

  const [capabilities, setCapabilities] = useState<Capability[]>([]);
  const [rubricTemplates, setRubricTemplates] = useState<RubricTemplate[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  const [activeTab, setActiveTab] = useState<TabKey>('capabilities');
  const [editingCapabilityId, setEditingCapabilityId] = useState<string | null>(null);
  const [editingRubricId, setEditingRubricId] = useState<string | null>(null);
  const [showCapabilityForm, setShowCapabilityForm] = useState(false);
  const [showRubricForm, setShowRubricForm] = useState(false);
  const [capabilityForm, setCapabilityForm] = useState<CapabilityFormData>(EMPTY_CAPABILITY_FORM);
  const [rubricForm, setRubricForm] = useState<RubricTemplateFormData>(EMPTY_RUBRIC_FORM);
  const [filterPillar, setFilterPillar] = useState<PillarCode | 'all'>('all');

  /* ───── Data Loading ───── */

  const loadData = useCallback(async () => {
    if (!siteId) return;
    setLoading(true);
    setErrorMessage(null);
    try {
      const [capSnap, rubSnap] = await Promise.all([
        getDocs(query(capabilitiesCollection, where('siteId', '==', siteId), orderBy('pillarCode'), orderBy('sortOrder'))),
        getDocs(query(rubricTemplatesCollection, where('siteId', '==', siteId), orderBy('updatedAt', 'desc'))),
      ]);
      setCapabilities(capSnap.docs.map((d) => ({ ...d.data(), id: d.id }) as Capability));
      setRubricTemplates(rubSnap.docs.map((d) => ({ ...d.data(), id: d.id }) as RubricTemplate));
    } catch (err) {
      console.error('Failed to load capability framework data', err);
      setErrorMessage('Failed to load data. Please try again.');
    } finally {
      setLoading(false);
    }
  }, [siteId]);

  useEffect(() => {
    if (siteId) loadData();
  }, [siteId, loadData]);

  /* ───── Filtered data ───── */

  const filteredCapabilities = useMemo(() => {
    if (filterPillar === 'all') return capabilities;
    return capabilities.filter((c) => c.pillarCode === filterPillar);
  }, [capabilities, filterPillar]);

  const capsByPillar = useMemo(() => {
    const grouped: Record<string, Capability[]> = {};
    for (const cap of filteredCapabilities) {
      const key = cap.pillarCode;
      if (!grouped[key]) grouped[key] = [];
      grouped[key].push(cap);
    }
    return grouped;
  }, [filteredCapabilities]);

  const capabilityMap = useMemo(() => {
    const m = new Map<string, Capability>();
    for (const c of capabilities) m.set(c.id, c);
    return m;
  }, [capabilities]);

  /* ───── Flash Messages ───── */

  const flash = useCallback((msg: string) => {
    setSuccessMessage(msg);
    setTimeout(() => setSuccessMessage(null), 3000);
  }, []);

  const flashError = useCallback((msg: string) => {
    setErrorMessage(msg);
    setTimeout(() => setErrorMessage(null), 5000);
  }, []);

  /* ───── Capability CRUD ───── */

  const openCreateCapability = useCallback(() => {
    setEditingCapabilityId(null);
    setCapabilityForm(EMPTY_CAPABILITY_FORM);
    setShowCapabilityForm(true);
  }, []);

  const openEditCapability = useCallback((cap: Capability) => {
    setEditingCapabilityId(cap.id);
    setCapabilityForm({
      title: cap.title,
      pillarCode: cap.pillarCode,
      descriptor: cap.descriptor ?? '',
      sortOrder: cap.sortOrder ?? 0,
      progressionDescriptors: cap.progressionDescriptors ?? {
        beginning: '', developing: '', proficient: '', advanced: '',
      },
    });
    setShowCapabilityForm(true);
  }, []);

  const saveCapability = useCallback(async () => {
    if (!siteId || !user) return;
    const title = capabilityForm.title.trim();
    if (!title) { flashError('Title is required.'); return; }

    setSaving(true);
    try {
      const normalizedTitle = title.toLowerCase().replace(/\s+/g, '_');
      const hasProgression = Object.values(capabilityForm.progressionDescriptors).some((v) => v.trim());

      if (editingCapabilityId) {
        const ref = doc(capabilitiesCollection, editingCapabilityId);
        await updateDoc(ref, {
          title,
          normalizedTitle,
          pillarCode: capabilityForm.pillarCode,
          descriptor: capabilityForm.descriptor.trim() || null,
          sortOrder: capabilityForm.sortOrder,
          ...(hasProgression
            ? { progressionDescriptors: capabilityForm.progressionDescriptors }
            : { progressionDescriptors: deleteField() }),
          updatedAt: serverTimestamp(),
        });
        flash('Capability updated.');
      } else {
        await addDoc(capabilitiesCollection, {
          title,
          normalizedTitle,
          pillarCode: capabilityForm.pillarCode,
          siteId,
          descriptor: capabilityForm.descriptor.trim() || null,
          sortOrder: capabilityForm.sortOrder,
          ...(hasProgression ? { progressionDescriptors: capabilityForm.progressionDescriptors } : {}),
          status: 'active',
          createdAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        });
        flash('Capability created.');
      }
      if (siteId) invalidateCapabilityCache(siteId);
      setShowCapabilityForm(false);
      await loadData();
    } catch (err) {
      console.error('Failed to save capability', err);
      flashError('Failed to save. Please try again.');
    } finally {
      setSaving(false);
    }
  }, [siteId, user, capabilityForm, editingCapabilityId, flash, flashError, loadData]);

  const archiveCapability = useCallback(async (cap: Capability) => {
    if (!confirm(`Archive "${cap.title}"? It will no longer appear in new rubric selections.`)) return;
    setSaving(true);
    try {
      const ref = doc(capabilitiesCollection, cap.id);
      await updateDoc(ref, { status: 'archived', updatedAt: serverTimestamp() });
      if (siteId) invalidateCapabilityCache(siteId);
      flash('Capability archived.');
      await loadData();
    } catch (err) {
      console.error('Failed to archive capability', err);
      flashError('Failed to archive.');
    } finally {
      setSaving(false);
    }
  }, [siteId, flash, flashError, loadData]);

  /* ───── Rubric Template CRUD ───── */

  const openCreateRubric = useCallback(() => {
    setEditingRubricId(null);
    setRubricForm(EMPTY_RUBRIC_FORM);
    setShowRubricForm(true);
  }, []);

  const openEditRubric = useCallback((tmpl: RubricTemplate) => {
    setEditingRubricId(tmpl.id);
    setRubricForm({
      title: tmpl.title,
      capabilityIds: [...tmpl.capabilityIds],
      criteria: tmpl.criteria.map((c) => ({ label: c.label, capabilityId: c.capabilityId, maxScore: c.maxScore })),
    });
    setShowRubricForm(true);
  }, []);

  const addCriterion = useCallback(() => {
    setRubricForm((prev) => ({
      ...prev,
      criteria: [...prev.criteria, { label: '', capabilityId: '', maxScore: 4 }],
    }));
  }, []);

  const removeCriterion = useCallback((index: number) => {
    setRubricForm((prev) => ({
      ...prev,
      criteria: prev.criteria.filter((_, i) => i !== index),
    }));
  }, []);

  const updateCriterion = useCallback((index: number, field: string, value: string | number) => {
    setRubricForm((prev) => ({
      ...prev,
      criteria: prev.criteria.map((c, i) => (i === index ? { ...c, [field]: value } : c)),
    }));
  }, []);

  const saveRubricTemplate = useCallback(async () => {
    if (!siteId || !user) return;
    const title = rubricForm.title.trim();
    if (!title) { flashError('Title is required.'); return; }
    if (rubricForm.criteria.length === 0) { flashError('At least one criterion is required.'); return; }
    for (const c of rubricForm.criteria) {
      if (!c.label.trim() || !c.capabilityId) {
        flashError('Each criterion needs a label and mapped capability.');
        return;
      }
    }

    setSaving(true);
    try {
      const capabilityIds = [...new Set(rubricForm.criteria.map((c) => c.capabilityId))];
      const criteria = rubricForm.criteria.map((c) => ({
        label: c.label.trim(),
        capabilityId: c.capabilityId,
        pillarCode: capabilityMap.get(c.capabilityId)?.pillarCode,
        maxScore: c.maxScore,
      }));

      if (editingRubricId) {
        const ref = doc(rubricTemplatesCollection, editingRubricId);
        await updateDoc(ref, {
          title,
          capabilityIds,
          criteria,
          updatedAt: serverTimestamp(),
        });
        flash('Rubric template updated.');
      } else {
        await addDoc(rubricTemplatesCollection, {
          title,
          siteId,
          capabilityIds,
          criteria,
          status: 'published',
          createdBy: user.uid,
          createdAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        });
        flash('Rubric template created.');
      }
      setShowRubricForm(false);
      await loadData();
    } catch (err) {
      console.error('Failed to save rubric template', err);
      flashError('Failed to save. Please try again.');
    } finally {
      setSaving(false);
    }
  }, [siteId, user, rubricForm, editingRubricId, capabilityMap, flash, flashError, loadData]);

  /* ───── Auth Guard ───── */

  if (authLoading) return <div className="flex justify-center py-12"><Spinner /></div>;
  if (!user || !profile) return <div className="p-6 text-sm text-gray-500">Not authenticated.</div>;

  return (
    <RoleRouteGuard allowedRoles={['hq']}>
      <div className="mx-auto max-w-6xl px-4 py-6 sm:px-6">
        {/* ───── Header ───── */}
        <div className="mb-6">
          <h1 className="text-2xl font-bold text-gray-900">Capability Framework</h1>
          <p className="mt-1 text-sm text-gray-500">
            Define capabilities, progression descriptors, and rubric templates.
            These form the foundation of the evidence chain.
          </p>
        </div>

        {/* ───── Flash Messages ───── */}
        {successMessage && (
          <div className="mb-4 rounded-md bg-green-50 border border-green-200 px-4 py-3 text-sm text-green-800">
            {successMessage}
          </div>
        )}
        {errorMessage && (
          <div className="mb-4 rounded-md bg-red-50 border border-red-200 px-4 py-3 text-sm text-red-800">
            {errorMessage}
          </div>
        )}

        {/* ───── Tabs ───── */}
        <div className="mb-6 border-b border-gray-200">
          <nav className="-mb-px flex gap-6">
            <button
              onClick={() => setActiveTab('capabilities')}
              className={`pb-3 text-sm font-medium border-b-2 ${
                activeTab === 'capabilities'
                  ? 'border-indigo-600 text-indigo-600'
                  : 'border-transparent text-gray-500 hover:text-gray-700'
              }`}
            >
              Capabilities ({capabilities.length})
            </button>
            <button
              onClick={() => setActiveTab('rubricTemplates')}
              className={`pb-3 text-sm font-medium border-b-2 ${
                activeTab === 'rubricTemplates'
                  ? 'border-indigo-600 text-indigo-600'
                  : 'border-transparent text-gray-500 hover:text-gray-700'
              }`}
            >
              Rubric Templates ({rubricTemplates.length})
            </button>
          </nav>
        </div>

        {loading ? (
          <div className="flex justify-center py-12"><Spinner /></div>
        ) : activeTab === 'capabilities' ? (
          <CapabilitiesTab
            capsByPillar={capsByPillar}
            filterPillar={filterPillar}
            setFilterPillar={setFilterPillar}
            onCreateCapability={openCreateCapability}
            onEditCapability={openEditCapability}
            onArchiveCapability={archiveCapability}
            saving={saving}
            totalCount={capabilities.length}
          />
        ) : (
          <RubricTemplatesTab
            rubricTemplates={rubricTemplates}
            capabilityMap={capabilityMap}
            onCreateRubric={openCreateRubric}
            onEditRubric={openEditRubric}
          />
        )}

        {/* ───── Capability Form Modal ───── */}
        {showCapabilityForm && (
          <CapabilityFormModal
            form={capabilityForm}
            setForm={setCapabilityForm}
            isEditing={!!editingCapabilityId}
            saving={saving}
            onSave={saveCapability}
            onCancel={() => setShowCapabilityForm(false)}
          />
        )}

        {/* ───── Rubric Template Form Modal ───── */}
        {showRubricForm && (
          <RubricTemplateFormModal
            form={rubricForm}
            setForm={setRubricForm}
            capabilities={capabilities}
            isEditing={!!editingRubricId}
            saving={saving}
            onSave={saveRubricTemplate}
            onCancel={() => setShowRubricForm(false)}
            addCriterion={addCriterion}
            removeCriterion={removeCriterion}
            updateCriterion={updateCriterion}
          />
        )}
      </div>
    </RoleRouteGuard>
  );
}

/* ───── Capabilities Tab ───── */

function CapabilitiesTab({
  capsByPillar,
  filterPillar,
  setFilterPillar,
  onCreateCapability,
  onEditCapability,
  onArchiveCapability,
  saving,
  totalCount,
}: {
  capsByPillar: Record<string, Capability[]>;
  filterPillar: PillarCode | 'all';
  setFilterPillar: (p: PillarCode | 'all') => void;
  onCreateCapability: () => void;
  onEditCapability: (cap: Capability) => void;
  onArchiveCapability: (cap: Capability) => void;
  saving: boolean;
  totalCount: number;
}) {
  return (
    <div>
      {/* ───── Toolbar ───── */}
      <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-center gap-2">
          <select
            value={filterPillar}
            onChange={(e) => setFilterPillar(e.target.value as PillarCode | 'all')}
            className="rounded-md border border-gray-300 px-3 py-1.5 text-sm"
          >
            <option value="all">All Pillars</option>
            {PILLAR_OPTIONS.map((p) => (
              <option key={p.value} value={p.value}>{p.label}</option>
            ))}
          </select>
          <span className="text-xs text-gray-400">{totalCount} total</span>
        </div>
        <button
          onClick={onCreateCapability}
          className="rounded-md bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-700 disabled:opacity-50"
          disabled={saving}
        >
          + Add Capability
        </button>
      </div>

      {/* ───── Grouped List ───── */}
      {Object.keys(capsByPillar).length === 0 ? (
        <div className="rounded-lg border-2 border-dashed border-gray-200 py-12 text-center">
          <p className="text-sm text-gray-500">No capabilities defined yet.</p>
          <p className="mt-1 text-xs text-gray-400">
            Create your first capability to build the evidence chain foundation.
          </p>
        </div>
      ) : (
        <div className="space-y-6">
          {PILLAR_OPTIONS.filter((p) => capsByPillar[p.value]).map((pillar) => (
            <div key={pillar.value}>
              <h3 className="mb-2 text-sm font-semibold text-gray-700">{pillar.label}</h3>
              <div className="space-y-2">
                {capsByPillar[pillar.value].map((cap) => (
                  <CapabilityCard
                    key={cap.id}
                    capability={cap}
                    onEdit={() => onEditCapability(cap)}
                    onArchive={() => onArchiveCapability(cap)}
                    saving={saving}
                  />
                ))}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

/* ───── Capability Card ───── */

function CapabilityCard({
  capability,
  onEdit,
  onArchive,
  saving,
}: {
  capability: Capability;
  onEdit: () => void;
  onArchive: () => void;
  saving: boolean;
}) {
  const [expanded, setExpanded] = useState(false);
  const pd = capability.progressionDescriptors;
  const hasProgression = pd && Object.values(pd).some((v) => v?.trim());

  return (
    <div className="rounded-lg border border-gray-200 bg-white p-4 shadow-sm">
      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0 flex-1">
          <div className="flex items-center gap-2">
            <span className={`inline-flex items-center rounded-full border px-2 py-0.5 text-xs font-medium ${pillarClass(capability.pillarCode)}`}>
              {pillarLabel(capability.pillarCode)}
            </span>
            <h4 className="truncate text-sm font-medium text-gray-900">{capability.title}</h4>
            {capability.status === 'archived' && (
              <span className="rounded bg-gray-100 px-1.5 py-0.5 text-xs text-gray-500">Archived</span>
            )}
          </div>
          {capability.descriptor && (
            <p className="mt-1 text-xs text-gray-500">{capability.descriptor}</p>
          )}
          {hasProgression && (
            <button
              onClick={() => setExpanded(!expanded)}
              className="mt-1 text-xs text-indigo-600 hover:underline"
            >
              {expanded ? 'Hide' : 'Show'} progression descriptors
            </button>
          )}
          {expanded && hasProgression && pd && (
            <div className="mt-2 grid grid-cols-2 gap-2 sm:grid-cols-4">
              {LEVEL_LABELS.map((label, i) => {
                const key = label.toLowerCase() as keyof ProgressionDescriptors;
                const desc = pd[key];
                return (
                  <div key={label} className="rounded border border-gray-100 bg-gray-50 p-2">
                    <span className="block text-xs font-semibold text-gray-600">
                      L{i + 1} — {label}
                    </span>
                    <span className="mt-0.5 block text-xs text-gray-500">
                      {desc || '(not defined)'}
                    </span>
                  </div>
                );
              })}
            </div>
          )}
        </div>
        <div className="flex shrink-0 gap-1">
          <button
            onClick={onEdit}
            disabled={saving}
            className="rounded px-2 py-1 text-xs text-indigo-600 hover:bg-indigo-50 disabled:opacity-50"
          >
            Edit
          </button>
          {capability.status !== 'archived' && (
            <button
              onClick={onArchive}
              disabled={saving}
              className="rounded px-2 py-1 text-xs text-red-600 hover:bg-red-50 disabled:opacity-50"
            >
              Archive
            </button>
          )}
        </div>
      </div>
    </div>
  );
}

/* ───── Rubric Templates Tab ───── */

function RubricTemplatesTab({
  rubricTemplates,
  capabilityMap,
  onCreateRubric,
  onEditRubric,
}: {
  rubricTemplates: RubricTemplate[];
  capabilityMap: Map<string, Capability>;
  onCreateRubric: () => void;
  onEditRubric: (tmpl: RubricTemplate) => void;
}) {
  return (
    <div>
      <div className="mb-4 flex items-center justify-between">
        <p className="text-xs text-gray-400">{rubricTemplates.length} templates</p>
        <button
          onClick={onCreateRubric}
          className="rounded-md bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-700"
        >
          + Add Rubric Template
        </button>
      </div>

      {rubricTemplates.length === 0 ? (
        <div className="rounded-lg border-2 border-dashed border-gray-200 py-12 text-center">
          <p className="text-sm text-gray-500">No rubric templates yet.</p>
          <p className="mt-1 text-xs text-gray-400">
            Create rubric templates that educators can use when scoring learner evidence.
          </p>
        </div>
      ) : (
        <div className="space-y-3">
          {rubricTemplates.map((tmpl) => (
            <div key={tmpl.id} className="rounded-lg border border-gray-200 bg-white p-4 shadow-sm">
              <div className="flex items-start justify-between gap-3">
                <div className="min-w-0 flex-1">
                  <h4 className="text-sm font-medium text-gray-900">{tmpl.title}</h4>
                  <div className="mt-1 flex flex-wrap gap-1">
                    {tmpl.capabilityIds.map((capId) => {
                      const cap = capabilityMap.get(capId);
                      return (
                        <span
                          key={capId}
                          className={`inline-flex rounded-full border px-2 py-0.5 text-xs ${
                            cap ? pillarClass(cap.pillarCode) : 'bg-gray-100 text-gray-500'
                          }`}
                        >
                          {cap?.title ?? capId}
                        </span>
                      );
                    })}
                  </div>
                  <p className="mt-1 text-xs text-gray-400">
                    {tmpl.criteria.length} criteria · Max score:{' '}
                    {tmpl.criteria.reduce((sum, c) => sum + c.maxScore, 0)}
                  </p>
                </div>
                <button
                  onClick={() => onEditRubric(tmpl)}
                  className="rounded px-2 py-1 text-xs text-indigo-600 hover:bg-indigo-50"
                >
                  Edit
                </button>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

/* ───── Capability Form Modal ───── */

function CapabilityFormModal({
  form,
  setForm,
  isEditing,
  saving,
  onSave,
  onCancel,
}: {
  form: CapabilityFormData;
  setForm: (fn: (prev: CapabilityFormData) => CapabilityFormData) => void;
  isEditing: boolean;
  saving: boolean;
  onSave: () => void;
  onCancel: () => void;
}) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
      <div className="w-full max-w-xl rounded-lg bg-white p-6 shadow-xl max-h-[90vh] overflow-y-auto">
        <h2 className="text-lg font-semibold text-gray-900">
          {isEditing ? 'Edit Capability' : 'Create Capability'}
        </h2>

        <div className="mt-4 space-y-4">
          {/* Title */}
          <div>
            <label className="block text-sm font-medium text-gray-700">Title *</label>
            <input
              type="text"
              value={form.title}
              onChange={(e) => setForm((prev) => ({ ...prev, title: e.target.value }))}
              className="mt-1 block w-full rounded-md border border-gray-300 px-3 py-2 text-sm shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
              placeholder="e.g., Computational Thinking"
            />
          </div>

          {/* Pillar */}
          <div>
            <label className="block text-sm font-medium text-gray-700">Pillar *</label>
            <select
              value={form.pillarCode}
              onChange={(e) => setForm((prev) => ({ ...prev, pillarCode: e.target.value as PillarCode }))}
              className="mt-1 block w-full rounded-md border border-gray-300 px-3 py-2 text-sm shadow-sm"
            >
              {PILLAR_OPTIONS.map((p) => (
                <option key={p.value} value={p.value}>{p.label}</option>
              ))}
            </select>
          </div>

          {/* Descriptor */}
          <div>
            <label className="block text-sm font-medium text-gray-700">Descriptor</label>
            <textarea
              value={form.descriptor}
              onChange={(e) => setForm((prev) => ({ ...prev, descriptor: e.target.value }))}
              rows={2}
              className="mt-1 block w-full rounded-md border border-gray-300 px-3 py-2 text-sm shadow-sm"
              placeholder="Brief description of what this capability measures"
            />
          </div>

          {/* Sort Order */}
          <div>
            <label className="block text-sm font-medium text-gray-700">Sort Order</label>
            <input
              type="number"
              value={form.sortOrder}
              onChange={(e) => setForm((prev) => ({ ...prev, sortOrder: parseInt(e.target.value) || 0 }))}
              className="mt-1 block w-24 rounded-md border border-gray-300 px-3 py-2 text-sm shadow-sm"
            />
          </div>

          {/* Progression Descriptors */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Progression Descriptors
            </label>
            <p className="text-xs text-gray-400 mb-2">
              Define what each level looks like for this capability.
            </p>
            <div className="space-y-2">
              {LEVEL_LABELS.map((label) => {
                const key = label.toLowerCase() as keyof ProgressionDescriptors;
                return (
                  <div key={label} className="flex items-start gap-2">
                    <span className="mt-2 w-24 shrink-0 text-xs font-medium text-gray-600">
                      {label}
                    </span>
                    <textarea
                      value={form.progressionDescriptors[key]}
                      onChange={(e) =>
                        setForm((prev) => ({
                          ...prev,
                          progressionDescriptors: {
                            ...prev.progressionDescriptors,
                            [key]: e.target.value,
                          },
                        }))
                      }
                      rows={1}
                      className="block w-full rounded-md border border-gray-300 px-3 py-1.5 text-xs shadow-sm"
                      placeholder={`What does "${label}" look like for this capability?`}
                    />
                  </div>
                );
              })}
            </div>
          </div>
        </div>

        <div className="mt-6 flex justify-end gap-3">
          <button
            onClick={onCancel}
            className="rounded-md border border-gray-300 px-4 py-2 text-sm text-gray-700 hover:bg-gray-50"
          >
            Cancel
          </button>
          <button
            onClick={onSave}
            disabled={saving}
            className="rounded-md bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-700 disabled:opacity-50"
          >
            {saving ? 'Saving...' : isEditing ? 'Update' : 'Create'}
          </button>
        </div>
      </div>
    </div>
  );
}

/* ───── Rubric Template Form Modal ───── */

function RubricTemplateFormModal({
  form,
  setForm,
  capabilities,
  isEditing,
  saving,
  onSave,
  onCancel,
  addCriterion,
  removeCriterion,
  updateCriterion,
}: {
  form: RubricTemplateFormData;
  setForm: (fn: (prev: RubricTemplateFormData) => RubricTemplateFormData) => void;
  capabilities: Capability[];
  isEditing: boolean;
  saving: boolean;
  onSave: () => void;
  onCancel: () => void;
  addCriterion: () => void;
  removeCriterion: (index: number) => void;
  updateCriterion: (index: number, field: string, value: string | number) => void;
}) {
  const activeCapabilities = capabilities.filter((c) => c.status !== 'archived');

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
      <div className="w-full max-w-2xl rounded-lg bg-white p-6 shadow-xl max-h-[90vh] overflow-y-auto">
        <h2 className="text-lg font-semibold text-gray-900">
          {isEditing ? 'Edit Rubric Template' : 'Create Rubric Template'}
        </h2>

        <div className="mt-4 space-y-4">
          {/* Title */}
          <div>
            <label className="block text-sm font-medium text-gray-700">Template Title *</label>
            <input
              type="text"
              value={form.title}
              onChange={(e) => setForm((prev) => ({ ...prev, title: e.target.value }))}
              className="mt-1 block w-full rounded-md border border-gray-300 px-3 py-2 text-sm shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
              placeholder="e.g., Design Thinking Project Rubric"
            />
          </div>

          {/* Criteria */}
          <div>
            <div className="flex items-center justify-between mb-2">
              <label className="block text-sm font-medium text-gray-700">
                Criteria ({form.criteria.length})
              </label>
              <button
                onClick={addCriterion}
                className="rounded bg-gray-100 px-3 py-1 text-xs font-medium text-gray-700 hover:bg-gray-200"
              >
                + Add Criterion
              </button>
            </div>

            {form.criteria.length === 0 ? (
              <p className="text-xs text-gray-400 py-4 text-center border border-dashed rounded-md">
                Add criteria to define what this rubric scores. Each criterion maps to one capability.
              </p>
            ) : (
              <div className="space-y-3">
                {form.criteria.map((criterion, i) => (
                  <div key={i} className="rounded border border-gray-200 bg-gray-50 p-3">
                    <div className="flex items-start gap-2">
                      <div className="flex-1 space-y-2">
                        <input
                          type="text"
                          value={criterion.label}
                          onChange={(e) => updateCriterion(i, 'label', e.target.value)}
                          className="block w-full rounded-md border border-gray-300 px-3 py-1.5 text-sm shadow-sm"
                          placeholder="Criterion label (e.g., Problem decomposition)"
                        />
                        <div className="flex gap-2">
                          <select
                            value={criterion.capabilityId}
                            onChange={(e) => updateCriterion(i, 'capabilityId', e.target.value)}
                            className="block flex-1 rounded-md border border-gray-300 px-2 py-1 text-xs shadow-sm"
                          >
                            <option value="">Map to capability...</option>
                            {activeCapabilities.map((cap) => (
                              <option key={cap.id} value={cap.id}>
                                {cap.title} ({pillarLabel(cap.pillarCode)})
                              </option>
                            ))}
                          </select>
                          <div className="flex items-center gap-1">
                            <label className="text-xs text-gray-500">Max:</label>
                            <input
                              type="number"
                              min={1}
                              max={10}
                              value={criterion.maxScore}
                              onChange={(e) => updateCriterion(i, 'maxScore', parseInt(e.target.value) || 4)}
                              className="w-14 rounded-md border border-gray-300 px-2 py-1 text-xs shadow-sm"
                            />
                          </div>
                        </div>
                      </div>
                      <button
                        onClick={() => removeCriterion(i)}
                        className="mt-1 rounded p-1 text-gray-400 hover:bg-red-50 hover:text-red-500"
                        title="Remove criterion"
                      >
                        ✕
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>

        <div className="mt-6 flex justify-end gap-3">
          <button
            onClick={onCancel}
            className="rounded-md border border-gray-300 px-4 py-2 text-sm text-gray-700 hover:bg-gray-50"
          >
            Cancel
          </button>
          <button
            onClick={onSave}
            disabled={saving}
            className="rounded-md bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-700 disabled:opacity-50"
          >
            {saving ? 'Saving...' : isEditing ? 'Update' : 'Create'}
          </button>
        </div>
      </div>
    </div>
  );
}
