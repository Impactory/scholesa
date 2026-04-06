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
  missionsCollection,
  rubricTemplatesCollection,
  processDomainsCollection,
} from '@/src/firebase/firestore/collections';
import type { Mission } from '@/src/types/schema';
import { invalidateCapabilityCache } from '@/src/lib/capabilities/useCapabilities';
import { RoleRouteGuard } from '@/src/components/auth/RoleRouteGuard';
import { Spinner } from '@/src/components/ui/Spinner';
import type { Capability, PillarCode, RubricTemplate, ProgressionDescriptors, ProcessDomain, CheckpointMapping } from '@/src/types/schema';

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

type TabKey = 'capabilities' | 'rubricTemplates' | 'processDomains';

interface CapabilityFormData {
  title: string;
  pillarCode: PillarCode;
  descriptor: string;
  sortOrder: number;
  progressionDescriptors: ProgressionDescriptors;
  unitMappings: string[];
  checkpointMappings: CheckpointMapping[];
}

interface ProcessDomainFormData {
  title: string;
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
  unitMappings: [],
  checkpointMappings: [],
};

const EMPTY_PROCESS_DOMAIN_FORM: ProcessDomainFormData = {
  title: '',
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
  const [missions, setMissions] = useState<Mission[]>([]);
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
      const [capSnap, rubSnap, missionSnap] = await Promise.all([
        getDocs(query(capabilitiesCollection, where('siteId', '==', siteId), orderBy('pillarCode'), orderBy('sortOrder'))),
        getDocs(query(rubricTemplatesCollection, where('siteId', '==', siteId), orderBy('updatedAt', 'desc'))),
        getDocs(query(missionsCollection, orderBy('order'))),
      ]);
      setCapabilities(capSnap.docs.map((d) => ({ ...d.data(), id: d.id }) as Capability));
      setRubricTemplates(rubSnap.docs.map((d) => ({ ...d.data(), id: d.id }) as RubricTemplate));
      setMissions(missionSnap.docs.map((d) => ({ ...d.data(), id: d.id }) as Mission));
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
      title: cap.title ?? cap.name,
      pillarCode: cap.pillarCode,
      descriptor: cap.descriptor ?? '',
      sortOrder: cap.sortOrder ?? 0,
      progressionDescriptors: cap.progressionDescriptors ?? {
        beginning: '', developing: '', proficient: '', advanced: '',
      },
      unitMappings: cap.unitMappings ?? [],
      checkpointMappings: cap.checkpointMappings ?? [],
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
          descriptor: capabilityForm.descriptor.trim() || undefined,
          sortOrder: capabilityForm.sortOrder,
          unitMappings: capabilityForm.unitMappings.length > 0 ? capabilityForm.unitMappings : deleteField(),
          checkpointMappings: capabilityForm.checkpointMappings.length > 0
            ? capabilityForm.checkpointMappings.filter((cm) => cm.label.trim())
            : deleteField(),
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
          descriptor: capabilityForm.descriptor.trim() || undefined,
          sortOrder: capabilityForm.sortOrder,
          ...(capabilityForm.unitMappings.length > 0 ? { unitMappings: capabilityForm.unitMappings } : {}),
          ...(capabilityForm.checkpointMappings.filter((cm) => cm.label.trim()).length > 0
            ? { checkpointMappings: capabilityForm.checkpointMappings.filter((cm) => cm.label.trim()) }
            : {}),
          ...(hasProgression ? { progressionDescriptors: capabilityForm.progressionDescriptors } : {}),
          status: 'active' as const,
          createdAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        } as unknown as Omit<Capability, 'id'>);
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
      const capabilityIds = Array.from(new Set(rubricForm.criteria.map((c) => c.capabilityId)));
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
          status: 'published' as const,
          createdBy: user.uid,
          createdAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        } as unknown as Omit<RubricTemplate, 'id'>);
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

  /* ───── Process Domain State & CRUD ───── */

  const [processDomains, setProcessDomains] = useState<ProcessDomain[]>([]);
  const [showProcessDomainForm, setShowProcessDomainForm] = useState(false);
  const [editingProcessDomainId, setEditingProcessDomainId] = useState<string | null>(null);
  const [processDomainForm, setProcessDomainForm] = useState<ProcessDomainFormData>(EMPTY_PROCESS_DOMAIN_FORM);

  const loadProcessDomains = useCallback(async () => {
    if (!siteId) return;
    try {
      const snap = await getDocs(
        query(processDomainsCollection, where('siteId', '==', siteId), orderBy('sortOrder')),
      );
      setProcessDomains(snap.docs.map((d) => ({ ...d.data(), id: d.id }) as ProcessDomain));
    } catch (err) {
      console.error('Failed to load process domains', err);
    }
  }, [siteId]);

  useEffect(() => {
    if (siteId) loadProcessDomains();
  }, [siteId, loadProcessDomains]);

  const openCreateProcessDomain = useCallback(() => {
    setEditingProcessDomainId(null);
    setProcessDomainForm(EMPTY_PROCESS_DOMAIN_FORM);
    setShowProcessDomainForm(true);
  }, []);

  const openEditProcessDomain = useCallback((pd: ProcessDomain) => {
    setEditingProcessDomainId(pd.id);
    setProcessDomainForm({
      title: pd.title,
      descriptor: pd.descriptor ?? '',
      sortOrder: pd.sortOrder ?? 0,
      progressionDescriptors: pd.progressionDescriptors ?? {
        beginning: '', developing: '', proficient: '', advanced: '',
      },
    });
    setShowProcessDomainForm(true);
  }, []);

  const saveProcessDomain = useCallback(async () => {
    if (!siteId || !user) return;
    const title = processDomainForm.title.trim();
    if (!title) { flashError('Title is required.'); return; }

    setSaving(true);
    try {
      const hasProgression = Object.values(processDomainForm.progressionDescriptors).some((v) => v.trim());

      if (editingProcessDomainId) {
        const ref = doc(processDomainsCollection, editingProcessDomainId);
        await updateDoc(ref, {
          title,
          descriptor: processDomainForm.descriptor.trim() || undefined,
          sortOrder: processDomainForm.sortOrder,
          ...(hasProgression
            ? { progressionDescriptors: processDomainForm.progressionDescriptors }
            : { progressionDescriptors: deleteField() }),
          updatedAt: serverTimestamp(),
        });
        flash('Process domain updated.');
      } else {
        await addDoc(processDomainsCollection, {
          title,
          siteId,
          descriptor: processDomainForm.descriptor.trim() || undefined,
          sortOrder: processDomainForm.sortOrder,
          ...(hasProgression ? { progressionDescriptors: processDomainForm.progressionDescriptors } : {}),
          status: 'active' as const,
          createdAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        } as Omit<ProcessDomain, 'id'>);
        flash('Process domain created.');
      }
      setShowProcessDomainForm(false);
      await loadProcessDomains();
    } catch (err) {
      console.error('Failed to save process domain', err);
      flashError('Failed to save. Please try again.');
    } finally {
      setSaving(false);
    }
  }, [siteId, user, processDomainForm, editingProcessDomainId, flash, flashError, loadProcessDomains]);

  const archiveProcessDomain = useCallback(async (pd: ProcessDomain) => {
    if (!confirm(`Archive "${pd.title}"?`)) return;
    setSaving(true);
    try {
      const ref = doc(processDomainsCollection, pd.id);
      await updateDoc(ref, { status: 'archived', updatedAt: serverTimestamp() });
      flash('Process domain archived.');
      await loadProcessDomains();
    } catch (err) {
      console.error('Failed to archive process domain', err);
      flashError('Failed to archive.');
    } finally {
      setSaving(false);
    }
  }, [flash, flashError, loadProcessDomains]);

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
            <button
              onClick={() => setActiveTab('processDomains')}
              className={`pb-3 text-sm font-medium border-b-2 ${
                activeTab === 'processDomains'
                  ? 'border-indigo-600 text-indigo-600'
                  : 'border-transparent text-gray-500 hover:text-gray-700'
              }`}
            >
              Process Domains ({processDomains.length})
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
        ) : activeTab === 'rubricTemplates' ? (
          <RubricTemplatesTab
            rubricTemplates={rubricTemplates}
            capabilityMap={capabilityMap}
            onCreateRubric={openCreateRubric}
            onEditRubric={openEditRubric}
          />
        ) : (
          <ProcessDomainsTab
            processDomains={processDomains}
            onCreateProcessDomain={openCreateProcessDomain}
            onEditProcessDomain={openEditProcessDomain}
            onArchiveProcessDomain={archiveProcessDomain}
            saving={saving}
          />
        )}

        {/* ───── Capability Form Modal ───── */}
        {showCapabilityForm && (
          <CapabilityFormModal
            form={capabilityForm}
            setForm={setCapabilityForm}
            missions={missions}
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

        {/* ───── Process Domain Form Modal ───── */}
        {showProcessDomainForm && (
          <ProcessDomainFormModal
            form={processDomainForm}
            setForm={setProcessDomainForm}
            isEditing={!!editingProcessDomainId}
            saving={saving}
            onSave={saveProcessDomain}
            onCancel={() => setShowProcessDomainForm(false)}
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
            aria-label="Filter by pillar"
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
  missions,
  isEditing,
  saving,
  onSave,
  onCancel,
}: {
  form: CapabilityFormData;
  setForm: (fn: (prev: CapabilityFormData) => CapabilityFormData) => void;
  missions: Mission[];
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
              aria-label="Select pillar"
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
              aria-label="Sort order"
              type="number"
              value={form.sortOrder}
              onChange={(e) => setForm((prev) => ({ ...prev, sortOrder: parseInt(e.target.value) || 0 }))}
              className="mt-1 block w-24 rounded-md border border-gray-300 px-3 py-2 text-sm shadow-sm"
            />
          </div>

          {/* Unit / Mission Mappings */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Mapped Units / Missions
            </label>
            <p className="text-xs text-gray-400 mb-2">
              Select which missions or checkpoints this capability is assessed in.
            </p>
            {missions.length > 0 ? (
              <div className="max-h-40 overflow-y-auto rounded-md border border-gray-300 p-2 space-y-1">
                {missions.map((m) => (
                  <label key={m.id} className="flex items-center gap-2 text-sm text-gray-700 py-0.5">
                    <input
                      type="checkbox"
                      checked={form.unitMappings.includes(m.id)}
                      onChange={(e) => {
                        setForm((prev) => ({
                          ...prev,
                          unitMappings: e.target.checked
                            ? [...prev.unitMappings, m.id]
                            : prev.unitMappings.filter((id) => id !== m.id),
                        }));
                      }}
                    />
                    <span>{m.title}</span>
                  </label>
                ))}
              </div>
            ) : (
              <p className="text-xs text-gray-400 italic">No missions defined yet.</p>
            )}
            {form.unitMappings.length > 0 && (
              <p className="mt-1 text-xs text-gray-500">
                {form.unitMappings.length} mission{form.unitMappings.length !== 1 ? 's' : ''} mapped
              </p>
            )}
          </div>

          {/* Checkpoint Mappings */}
          <div>
            <div className="flex items-center justify-between mb-1">
              <label className="block text-sm font-medium text-gray-700">
                Checkpoint Mappings
              </label>
              <button
                type="button"
                onClick={() =>
                  setForm((prev) => ({
                    ...prev,
                    checkpointMappings: [...prev.checkpointMappings, { label: '', description: '' }],
                  }))
                }
                className="rounded bg-gray-100 px-2 py-1 text-xs font-medium text-gray-700 hover:bg-gray-200"
              >
                + Add Checkpoint
              </button>
            </div>
            <p className="text-xs text-gray-400 mb-2">
              Define named checkpoints (assessment points) for this capability.
            </p>
            {form.checkpointMappings.length === 0 ? (
              <p className="text-xs text-gray-400 italic">No checkpoints defined.</p>
            ) : (
              <div className="space-y-2">
                {form.checkpointMappings.map((cm, i) => (
                  <div key={i} className="flex items-start gap-2 rounded border border-gray-200 bg-gray-50 p-2">
                    <div className="flex-1 space-y-1">
                      <input
                        type="text"
                        value={cm.label}
                        onChange={(e) =>
                          setForm((prev) => ({
                            ...prev,
                            checkpointMappings: prev.checkpointMappings.map((c, j) =>
                              j === i ? { ...c, label: e.target.value } : c
                            ),
                          }))
                        }
                        className="block w-full rounded-md border border-gray-300 px-2 py-1 text-xs shadow-sm"
                        placeholder="Checkpoint label (e.g., Mid-sprint check)"
                      />
                      <input
                        type="text"
                        value={cm.description ?? ''}
                        onChange={(e) =>
                          setForm((prev) => ({
                            ...prev,
                            checkpointMappings: prev.checkpointMappings.map((c, j) =>
                              j === i ? { ...c, description: e.target.value } : c
                            ),
                          }))
                        }
                        className="block w-full rounded-md border border-gray-300 px-2 py-1 text-xs shadow-sm"
                        placeholder="Description (optional)"
                      />
                    </div>
                    <button
                      type="button"
                      onClick={() =>
                        setForm((prev) => ({
                          ...prev,
                          checkpointMappings: prev.checkpointMappings.filter((_, j) => j !== i),
                        }))
                      }
                      className="mt-1 rounded p-1 text-gray-400 hover:bg-red-50 hover:text-red-500"
                      title="Remove checkpoint"
                    >
                      ✕
                    </button>
                  </div>
                ))}
              </div>
            )}
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
                            aria-label="Map to capability"
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
                              aria-label="Max score"
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

/* ───── Process Domains Tab ───── */

function ProcessDomainsTab({
  processDomains,
  onCreateProcessDomain,
  onEditProcessDomain,
  onArchiveProcessDomain,
  saving,
}: {
  processDomains: ProcessDomain[];
  onCreateProcessDomain: () => void;
  onEditProcessDomain: (pd: ProcessDomain) => void;
  onArchiveProcessDomain: (pd: ProcessDomain) => void;
  saving: boolean;
}) {
  return (
    <div>
      <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
        <div>
          <p className="text-xs text-gray-400">{processDomains.length} process domains</p>
          <p className="text-xs text-gray-500 mt-0.5">
            Cross-cutting skills (e.g., collaboration, critical thinking) assessed alongside capabilities in rubrics.
          </p>
        </div>
        <button
          onClick={onCreateProcessDomain}
          disabled={saving}
          className="rounded-md bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-700 disabled:opacity-50"
        >
          + Add Process Domain
        </button>
      </div>

      {processDomains.length === 0 ? (
        <div className="rounded-lg border-2 border-dashed border-gray-200 py-12 text-center">
          <p className="text-sm text-gray-500">No process domains defined yet.</p>
          <p className="mt-1 text-xs text-gray-400">
            Process domains capture cross-cutting skills assessed alongside capabilities.
          </p>
        </div>
      ) : (
        <div className="space-y-2">
          {processDomains.map((pd) => {
            const hasProgression = pd.progressionDescriptors &&
              Object.values(pd.progressionDescriptors as unknown as Record<string, string>).some((v) => v.trim());
            return (
              <div key={pd.id} className="rounded-lg border border-gray-200 bg-white p-4 shadow-sm">
                <div className="flex items-start justify-between gap-3">
                  <div className="min-w-0 flex-1">
                    <h4 className="text-sm font-medium text-gray-900">{pd.title}</h4>
                    {pd.descriptor && (
                      <p className="mt-1 text-xs text-gray-500">{pd.descriptor}</p>
                    )}
                    {hasProgression && (
                      <p className="mt-1 text-xs text-gray-400">Has progression descriptors</p>
                    )}
                    {pd.status === 'archived' && (
                      <span className="mt-1 inline-block rounded bg-gray-100 px-1.5 py-0.5 text-xs text-gray-500">Archived</span>
                    )}
                  </div>
                  <div className="flex shrink-0 gap-1">
                    <button
                      onClick={() => onEditProcessDomain(pd)}
                      disabled={saving}
                      className="rounded px-2 py-1 text-xs text-indigo-600 hover:bg-indigo-50 disabled:opacity-50"
                    >
                      Edit
                    </button>
                    {pd.status !== 'archived' && (
                      <button
                        onClick={() => onArchiveProcessDomain(pd)}
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
          })}
        </div>
      )}
    </div>
  );
}

/* ───── Process Domain Form Modal ───── */

function ProcessDomainFormModal({
  form,
  setForm,
  isEditing,
  saving,
  onSave,
  onCancel,
}: {
  form: ProcessDomainFormData;
  setForm: (fn: (prev: ProcessDomainFormData) => ProcessDomainFormData) => void;
  isEditing: boolean;
  saving: boolean;
  onSave: () => void;
  onCancel: () => void;
}) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
      <div className="w-full max-w-xl rounded-lg bg-white p-6 shadow-xl max-h-[90vh] overflow-y-auto">
        <h2 className="text-lg font-semibold text-gray-900">
          {isEditing ? 'Edit Process Domain' : 'Create Process Domain'}
        </h2>

        <div className="mt-4 space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700">Title *</label>
            <input
              type="text"
              value={form.title}
              onChange={(e) => setForm((prev) => ({ ...prev, title: e.target.value }))}
              className="mt-1 block w-full rounded-md border border-gray-300 px-3 py-2 text-sm shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
              placeholder="e.g., Collaboration, Critical Thinking"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700">Descriptor</label>
            <textarea
              value={form.descriptor}
              onChange={(e) => setForm((prev) => ({ ...prev, descriptor: e.target.value }))}
              rows={2}
              className="mt-1 block w-full rounded-md border border-gray-300 px-3 py-2 text-sm shadow-sm"
              placeholder="Brief description of this process domain"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700">Sort Order</label>
            <input
              aria-label="Sort order"
              type="number"
              value={form.sortOrder}
              onChange={(e) => setForm((prev) => ({ ...prev, sortOrder: parseInt(e.target.value) || 0 }))}
              className="mt-1 block w-24 rounded-md border border-gray-300 px-3 py-2 text-sm shadow-sm"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Progression Descriptors
            </label>
            <div className="space-y-2">
              {LEVEL_LABELS.map((label) => {
                const key = label.toLowerCase() as keyof ProgressionDescriptors;
                return (
                  <div key={label} className="flex items-start gap-2">
                    <span className="mt-2 w-24 shrink-0 text-xs font-medium text-gray-600">{label}</span>
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
                      placeholder={`What does "${label}" look like for this domain?`}
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