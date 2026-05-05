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
  writeBatch,
  where,
} from 'firebase/firestore';
import { firestore } from '@/src/firebase/client-init';
import { useAuthContext } from '@/src/firebase/auth/AuthProvider';
import {
  capabilitiesCollection,
  checkpointsCollection,
  missionsCollection,
  rubricTemplatesCollection,
  processDomainsCollection,
} from '@/src/firebase/firestore/collections';
import { resolveActiveSiteId } from '@/src/lib/auth/activeSite';
import { getLegacyPillarFamilyLabel } from '@/src/lib/curriculum/architecture';
import type { Mission } from '@/src/types/schema';
import { invalidateCapabilityCache } from '@/src/lib/capabilities/useCapabilities';
import { RoleRouteGuard } from '@/src/components/auth/RoleRouteGuard';
import { Spinner } from '@/src/components/ui/Spinner';
import type {
  Capability,
  PillarCode,
  RubricTemplate,
  ProgressionDescriptors,
  ProcessDomain,
  CheckpointMapping,
  Checkpoint,
} from '@/src/types/schema';

/* ───── Constants ───── */

const PILLAR_OPTIONS: { value: PillarCode; label: string; color: string }[] = [
  { value: 'FUTURE_SKILLS', label: getLegacyPillarFamilyLabel('FUTURE_SKILLS'), color: 'bg-blue-100 text-blue-800 border-blue-300' },
  { value: 'LEADERSHIP_AGENCY', label: getLegacyPillarFamilyLabel('LEADERSHIP_AGENCY'), color: 'bg-amber-100 text-amber-800 border-amber-300' },
  { value: 'IMPACT_INNOVATION', label: getLegacyPillarFamilyLabel('IMPACT_INNOVATION'), color: 'bg-emerald-100 text-emerald-800 border-emerald-300' },
];

const LEVEL_LABELS = ['Beginning', 'Developing', 'Proficient', 'Advanced'] as const;
const isE2ETestMode = process.env.NEXT_PUBLIC_E2E_TEST_MODE === '1';

function pillarClass(pillarCode: PillarCode): string {
  return PILLAR_OPTIONS.find((p) => p.value === pillarCode)?.color ?? 'bg-gray-100 text-gray-700';
}

function pillarLabel(pillarCode: PillarCode): string {
  return PILLAR_OPTIONS.find((p) => p.value === pillarCode)?.label ?? pillarCode;
}

function sortCheckpointMappings(a: CheckpointMapping, b: CheckpointMapping): number {
  const missionCompare = (a.missionTitle ?? '').localeCompare(b.missionTitle ?? '');
  if (missionCompare !== 0) return missionCompare;

  const numberCompare = (a.checkpointNumber ?? Number.MAX_SAFE_INTEGER) - (b.checkpointNumber ?? Number.MAX_SAFE_INTEGER);
  if (numberCompare !== 0) return numberCompare;

  return a.label.localeCompare(b.label);
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
  status: 'draft' | 'published';
  capabilityIds: string[];
  criteria: { label: string; capabilityId: string; processDomainId: string; maxScore: number }[];
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
  status: 'draft',
  capabilityIds: [],
  criteria: [],
};

/* ───── Main Component ───── */

interface CapabilityFrameworkEditorProps {
  initialTab?: TabKey;
  siteId?: string | null;
}

export function CapabilityFrameworkEditor({ initialTab, siteId }: CapabilityFrameworkEditorProps = {}) {
  const { user, profile, loading: authLoading } = useAuthContext();
  const resolvedSiteId = useMemo(() => siteId || resolveActiveSiteId(profile), [siteId, profile]);

  const [capabilities, setCapabilities] = useState<Capability[]>([]);
  const [checkpoints, setCheckpoints] = useState<Checkpoint[]>([]);
  const [missions, setMissions] = useState<Mission[]>([]);
  const [rubricTemplates, setRubricTemplates] = useState<RubricTemplate[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  const [activeTab, setActiveTab] = useState<TabKey>(initialTab ?? 'capabilities');
  const [editingCapabilityId, setEditingCapabilityId] = useState<string | null>(null);
  const [editingRubricId, setEditingRubricId] = useState<string | null>(null);
  const [showCapabilityForm, setShowCapabilityForm] = useState(false);
  const [showRubricForm, setShowRubricForm] = useState(false);
  const [capabilityForm, setCapabilityForm] = useState<CapabilityFormData>(EMPTY_CAPABILITY_FORM);
  const [rubricForm, setRubricForm] = useState<RubricTemplateFormData>(EMPTY_RUBRIC_FORM);
  const [filterPillar, setFilterPillar] = useState<PillarCode | 'all'>('all');

  /* ───── Data Loading ───── */

  const loadData = useCallback(async () => {
    setErrorMessage(null);
      if (!resolvedSiteId) {
        setCapabilities([]);
        setCheckpoints([]);
        setRubricTemplates([]);
        setMissions([]);
        setLoading(false);
      return;
    }

    setLoading(true);
    try {
      if (isE2ETestMode) {
        const { getE2ECollection } = await import('@/src/testing/e2e/fakeWebBackend');
        setCapabilities(
          getE2ECollection('capabilities')
            .filter((capability) => capability.siteId === resolvedSiteId)
            .map((capability) => ({ ...capability, id: String(capability.id) }) as Capability)
        );
        setCheckpoints(
          getE2ECollection('checkpoints')
            .filter((checkpoint) => checkpoint.siteId === resolvedSiteId && checkpoint.status !== 'archived')
            .map((checkpoint) => ({ ...checkpoint, id: String(checkpoint.id) }) as Checkpoint)
        );
        setRubricTemplates(
          getE2ECollection('rubricTemplates')
            .filter((template) => template.siteId === resolvedSiteId)
            .map((template) => ({ ...template, id: String(template.id) }) as RubricTemplate)
        );
        setMissions(
          getE2ECollection('missions')
            .filter((mission) => !mission.siteId || mission.siteId === resolvedSiteId)
            .map((mission) => ({ ...mission, id: String(mission.id) }) as Mission)
        );
        return;
      }

      const [capSnap, checkpointSnap, rubSnap, missionSnap] = await Promise.all([
        getDocs(query(capabilitiesCollection, where('siteId', '==', resolvedSiteId), orderBy('pillarCode'), orderBy('sortOrder'))),
        getDocs(query(checkpointsCollection, where('siteId', '==', resolvedSiteId))),
        getDocs(query(rubricTemplatesCollection, where('siteId', '==', resolvedSiteId), orderBy('updatedAt', 'desc'))),
        getDocs(query(missionsCollection, where('siteId', '==', resolvedSiteId), orderBy('order'))),
      ]);
      setCapabilities(capSnap.docs.map((d) => ({ ...d.data(), id: d.id }) as Capability));
      setCheckpoints(
        checkpointSnap.docs
          .map((d) => {
            const data = d.data() as Checkpoint;
            return { ...data, id: d.id };
          })
          .filter((checkpoint) => checkpoint.status !== 'archived')
      );
      setRubricTemplates(rubSnap.docs.map((d) => ({ ...d.data(), id: d.id }) as RubricTemplate));
      setMissions(missionSnap.docs.map((d) => ({ ...d.data(), id: d.id }) as Mission));
    } catch (err) {
      console.error('Failed to load capability framework data', err);
      setErrorMessage('Failed to load data. Please try again.');
    } finally {
      setLoading(false);
    }
  }, [resolvedSiteId]);

  useEffect(() => {
    if (authLoading) return;
    void loadData();
  }, [authLoading, loadData]);

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

  const missionMap = useMemo(() => {
    const m = new Map<string, Mission>();
    for (const mission of missions) m.set(mission.id, mission);
    return m;
  }, [missions]);

  /* ───── Flash Messages ───── */

  const flash = useCallback((msg: string) => {
    setSuccessMessage(msg);
    setTimeout(() => setSuccessMessage(null), 3000);
  }, []);

  const flashError = useCallback((msg: string) => {
    setErrorMessage(msg);
    setTimeout(() => setErrorMessage(null), 5000);
  }, []);

  const requireSiteContext = useCallback(
    (actionLabel: string): string | null => {
      if (resolvedSiteId) {
        return resolvedSiteId;
      }

      flashError(`Select an active site before ${actionLabel}.`);
      return null;
    },
    [resolvedSiteId, flashError],
  );

  /* ───── Capability CRUD ───── */

  const openCreateCapability = useCallback(() => {
    setEditingCapabilityId(null);
    setCapabilityForm(EMPTY_CAPABILITY_FORM);
    setShowCapabilityForm(true);
  }, []);

  const openEditCapability = useCallback((cap: Capability) => {
    const checkpointMappings =
      checkpoints
        .filter((checkpoint) => checkpoint.capabilityId === cap.id && checkpoint.status !== 'archived')
        .map((checkpoint) => ({
          checkpointId: checkpoint.id,
          label: checkpoint.title,
          description: checkpoint.description,
          missionId: checkpoint.missionId,
          missionTitle: checkpoint.missionTitle,
          checkpointNumber: checkpoint.checkpointNumber,
        }))
        .sort(sortCheckpointMappings);

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
      checkpointMappings: checkpointMappings.length > 0
        ? checkpointMappings
        : [...(cap.checkpointMappings ?? [])].sort(sortCheckpointMappings),
    });
    setShowCapabilityForm(true);
  }, [checkpoints]);

  const saveCapability = useCallback(async () => {
    const activeSiteId = requireSiteContext('saving capabilities');
    if (!activeSiteId || !user) return;
    const title = capabilityForm.title.trim();
    if (!title) { flashError('Title is required.'); return; }

    let normalizedCheckpointMappings: CheckpointMapping[] = [];
    try {
      normalizedCheckpointMappings = capabilityForm.checkpointMappings
        .flatMap((mapping) => {
          const label = mapping.label.trim();
          const description = mapping.description?.trim() || undefined;
          const checkpointId = mapping.checkpointId?.trim() || undefined;
          const missionId = mapping.missionId?.trim() || undefined;
          const checkpointNumber =
            typeof mapping.checkpointNumber === 'number'
              ? Math.trunc(mapping.checkpointNumber)
              : Number.parseInt(String(mapping.checkpointNumber ?? ''), 10);

          if (!label && !description && !missionId && !checkpointId && !Number.isFinite(checkpointNumber)) {
            return [];
          }
          if (!label) {
            throw new Error('Each checkpoint definition needs a title.');
          }
          if (!missionId) {
            throw new Error(`Select a mission for checkpoint "${label}".`);
          }
          if (!Number.isFinite(checkpointNumber) || checkpointNumber <= 0) {
            throw new Error(`Add a checkpoint number for "${label}".`);
          }

          const mission = missionMap.get(missionId);
          if (!mission) {
            throw new Error(`Mission for checkpoint "${label}" could not be found in the active site.`);
          }

          return [{
            checkpointId,
            label,
            description,
            missionId,
            missionTitle: mission.title,
            checkpointNumber,
          } satisfies CheckpointMapping];
        })
        .sort(sortCheckpointMappings);
    } catch (err) {
      flashError(err instanceof Error ? err.message : 'Checkpoint definitions are incomplete.');
      return;
    }

    setSaving(true);
    try {
      const normalizedTitle = title.toLowerCase().replace(/\s+/g, '_');
      const hasProgression = Object.values(capabilityForm.progressionDescriptors).some((v) => v.trim());
      const descriptor = capabilityForm.descriptor.trim();

      const batch = writeBatch(firestore);
      const capabilityRef = editingCapabilityId
        ? doc(capabilitiesCollection, editingCapabilityId)
        : doc(capabilitiesCollection);
      const capabilityId = capabilityRef.id;
      const existingCheckpointDocs = checkpoints.filter((checkpoint) => checkpoint.capabilityId === capabilityId);
      const existingCheckpointMap = new Map(existingCheckpointDocs.map((checkpoint) => [checkpoint.id, checkpoint]));
      const retainedCheckpointIds = new Set<string>();

      const syncedCheckpointMappings = normalizedCheckpointMappings.map((mapping) => {
        const checkpointRef =
          mapping.checkpointId && existingCheckpointMap.has(mapping.checkpointId)
            ? doc(checkpointsCollection, mapping.checkpointId)
            : doc(checkpointsCollection);

        retainedCheckpointIds.add(checkpointRef.id);

        const existingCheckpoint = existingCheckpointMap.get(checkpointRef.id);
        batch.set(
          checkpointRef,
          {
            siteId: activeSiteId,
            capabilityId,
            capabilityTitle: title,
            pillarCode: capabilityForm.pillarCode,
            missionId: mapping.missionId,
            missionTitle: mapping.missionTitle,
            title: mapping.label,
            description: mapping.description,
            checkpointNumber: mapping.checkpointNumber,
            status: 'active',
            createdAt: existingCheckpoint?.createdAt ?? serverTimestamp(),
            updatedAt: serverTimestamp(),
          } as Omit<Checkpoint, 'id'>,
          { merge: true }
        );

        return {
          checkpointId: checkpointRef.id,
          label: mapping.label,
          description: mapping.description,
          missionId: mapping.missionId,
          missionTitle: mapping.missionTitle,
          checkpointNumber: mapping.checkpointNumber,
        } satisfies CheckpointMapping;
      });

      for (const checkpoint of existingCheckpointDocs) {
        if (retainedCheckpointIds.has(checkpoint.id)) continue;
        batch.set(
          doc(checkpointsCollection, checkpoint.id),
          {
            status: 'archived',
            updatedAt: serverTimestamp(),
          },
          { merge: true }
        );
      }

      const capabilityPayload = {
        title,
        name: title,
        normalizedTitle,
        pillarCode: capabilityForm.pillarCode,
        descriptor: descriptor || deleteField(),
        sortOrder: capabilityForm.sortOrder,
        unitMappings: capabilityForm.unitMappings.length > 0 ? capabilityForm.unitMappings : deleteField(),
        checkpointMappings: syncedCheckpointMappings.length > 0 ? syncedCheckpointMappings : deleteField(),
        progressionDescriptors: hasProgression
          ? capabilityForm.progressionDescriptors
          : deleteField(),
        updatedAt: serverTimestamp(),
      };

      if (editingCapabilityId) {
        batch.update(capabilityRef, capabilityPayload);
      } else {
        batch.set(capabilityRef, {
          title,
          name: title,
          normalizedTitle,
          pillarCode: capabilityForm.pillarCode,
          domain: 'human' as const,
          description: descriptor || title,
          ...(descriptor ? { descriptor } : {}),
          ...(capabilityForm.unitMappings.length > 0 ? { unitMappings: capabilityForm.unitMappings } : {}),
          ...(syncedCheckpointMappings.length > 0 ? { checkpointMappings: syncedCheckpointMappings } : {}),
          ...(hasProgression ? { progressionDescriptors: capabilityForm.progressionDescriptors } : {}),
          sortOrder: capabilityForm.sortOrder,
          siteId: activeSiteId,
          status: 'active' as const,
          createdAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        } as unknown as Omit<Capability, 'id'>);
      }

      await batch.commit();
      flash(editingCapabilityId ? 'Capability updated.' : 'Capability created.');
      invalidateCapabilityCache(activeSiteId);
      setShowCapabilityForm(false);
      await loadData();
    } catch (err) {
      console.error('Failed to save capability', err);
      flashError('Failed to save. Please try again.');
    } finally {
      setSaving(false);
    }
  }, [
    requireSiteContext,
    user,
    capabilityForm,
    editingCapabilityId,
    flash,
    flashError,
    loadData,
    missionMap,
    checkpoints,
  ]);

  const archiveCapability = useCallback(async (cap: Capability) => {
    if (!confirm(`Archive "${cap.title}"? It will no longer appear in new rubric selections.`)) return;
    setSaving(true);
    try {
      const batch = writeBatch(firestore);
      const ref = doc(capabilitiesCollection, cap.id);
      batch.update(ref, { status: 'archived', updatedAt: serverTimestamp() });
      checkpoints
        .filter((checkpoint) => checkpoint.capabilityId === cap.id && checkpoint.status !== 'archived')
        .forEach((checkpoint) => {
          batch.set(
            doc(checkpointsCollection, checkpoint.id),
            { status: 'archived', updatedAt: serverTimestamp() },
            { merge: true }
          );
        });
      await batch.commit();
      if (resolvedSiteId) invalidateCapabilityCache(resolvedSiteId);
      flash('Capability archived.');
      await loadData();
    } catch (err) {
      console.error('Failed to archive capability', err);
      flashError('Failed to archive.');
    } finally {
      setSaving(false);
    }
  }, [checkpoints, resolvedSiteId, flash, flashError, loadData]);

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
      status: tmpl.status === 'published' ? 'published' : 'draft',
      capabilityIds: [...tmpl.capabilityIds],
      criteria: tmpl.criteria.map((c) => ({ label: c.label, capabilityId: c.capabilityId, processDomainId: c.processDomainId || '', maxScore: c.maxScore })),
    });
    setShowRubricForm(true);
  }, []);

  const addCriterion = useCallback(() => {
    setRubricForm((prev) => ({
      ...prev,
      criteria: [...prev.criteria, { label: '', capabilityId: '', processDomainId: '', maxScore: 4 }],
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
    const activeSiteId = requireSiteContext('saving rubric templates');
    if (!activeSiteId || !user) return;
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
      const criteria = rubricForm.criteria.map((c, idx) => {
        const cap = capabilityMap.get(c.capabilityId);
        return {
          id: `criterion-${idx}-${Date.now()}`,
          label: c.label.trim(),
          capabilityId: c.capabilityId,
          pillarCode: cap?.pillarCode,
          maxScore: c.maxScore,
          // Link to process domain if specified
          ...(c.processDomainId ? { processDomainId: c.processDomainId } : {}),
          // Propagate progression descriptors from the linked capability
          ...(cap?.progressionDescriptors &&
            Object.values(cap.progressionDescriptors).some((v) => v.trim())
            ? { descriptors: cap.progressionDescriptors }
            : {}),
        };
      });

        if (isE2ETestMode) {
          const { upsertE2ECollectionRecord } = await import('@/src/testing/e2e/fakeWebBackend');
          const now = new Date().toISOString();
          const rubricId = editingRubricId ?? `e2e-rubric-template-${Date.now()}`;
          upsertE2ECollectionRecord('rubricTemplates', {
            id: rubricId,
            title,
            siteId: activeSiteId,
            capabilityIds,
            criteria,
            status: rubricForm.status,
            createdBy: user.uid,
            createdAt: now,
            updatedAt: now,
          });
          flash(editingRubricId ? `Rubric template ${rubricForm.status === 'published' ? 'published' : 'saved as draft'}.` : 'Rubric template created.');
          setShowRubricForm(false);
          await loadData();
          return;
        }

      if (editingRubricId) {
        const ref = doc(rubricTemplatesCollection, editingRubricId);
        await updateDoc(ref, {
          title,
          status: rubricForm.status,
          capabilityIds,
          criteria,
          updatedAt: serverTimestamp(),
        });
        flash(`Rubric template ${rubricForm.status === 'published' ? 'published' : 'saved as draft'}.`);
      } else {
        await addDoc(rubricTemplatesCollection, {
          title,
          siteId: activeSiteId,
          capabilityIds,
          criteria,
          status: rubricForm.status,
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
  }, [requireSiteContext, user, rubricForm, editingRubricId, capabilityMap, flash, flashError, loadData]);

  /* ───── Process Domain State & CRUD ───── */

  const [processDomains, setProcessDomains] = useState<ProcessDomain[]>([]);
  const [showProcessDomainForm, setShowProcessDomainForm] = useState(false);
  const [editingProcessDomainId, setEditingProcessDomainId] = useState<string | null>(null);
  const [processDomainForm, setProcessDomainForm] = useState<ProcessDomainFormData>(EMPTY_PROCESS_DOMAIN_FORM);

  const loadProcessDomains = useCallback(async () => {
    if (!resolvedSiteId) {
      setProcessDomains([]);
      return;
    }

    try {
      if (isE2ETestMode) {
        const { getE2ECollection } = await import('@/src/testing/e2e/fakeWebBackend');
        setProcessDomains(
          getE2ECollection('processDomains')
            .filter((domain) => domain.siteId === resolvedSiteId && domain.status !== 'archived')
            .map((domain) => ({ ...domain, id: String(domain.id) }) as ProcessDomain)
        );
        return;
      }

      const snap = await getDocs(
        query(processDomainsCollection, where('siteId', '==', resolvedSiteId), orderBy('sortOrder')),
      );
      setProcessDomains(snap.docs.map((d) => ({ ...d.data(), id: d.id }) as ProcessDomain));
    } catch (err) {
      console.error('Failed to load process domains', err);
    }
  }, [resolvedSiteId]);

  useEffect(() => {
    if (authLoading) return;
    void loadProcessDomains();
  }, [authLoading, loadProcessDomains]);

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
    const activeSiteId = requireSiteContext('saving process domains');
    if (!activeSiteId || !user) return;
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
          siteId: activeSiteId,
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
  }, [requireSiteContext, user, processDomainForm, editingProcessDomainId, flash, flashError, loadProcessDomains]);

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

        {!resolvedSiteId ? (
          <div
            data-testid="hq-framework-site-required"
            className="rounded-lg border border-amber-200 bg-amber-50 px-4 py-4 text-sm text-amber-900"
          >
            Select an active site before editing capabilities, rubric templates, or process domains.
          </div>
        ) : (
          <>
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
                processDomains={processDomains}
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
          </>
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
            aria-label="Filter by legacy family"
            value={filterPillar}
            onChange={(e) => setFilterPillar(e.target.value as PillarCode | 'all')}
            className="rounded-md border border-gray-300 px-3 py-1.5 text-sm"
          >
            <option value="all">All Legacy Families</option>
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
            <div
              key={tmpl.id}
              data-testid={`rubric-template-card-${tmpl.id}`}
              className="rounded-lg border border-gray-200 bg-white p-4 shadow-sm"
            >
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
            <label className="block text-sm font-medium text-gray-700">Legacy family *</label>
            <select
              aria-label="Select legacy family"
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
                    checkpointMappings: [
                      ...prev.checkpointMappings,
                      { label: '', description: '', missionId: '', checkpointNumber: 1 },
                    ],
                  }))
                }
                className="rounded bg-gray-100 px-2 py-1 text-xs font-medium text-gray-700 hover:bg-gray-200"
              >
                + Add Checkpoint
              </button>
            </div>
            <p className="text-xs text-gray-400 mb-2">
              Define canonical checkpoints for this capability. Learners and educators will use these authored checkpoint definitions at runtime.
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
                      <div className="grid gap-2 sm:grid-cols-2">
                        <select
                          aria-label="Checkpoint mission"
                          value={cm.missionId ?? ''}
                          onChange={(e) =>
                            setForm((prev) => ({
                              ...prev,
                              checkpointMappings: prev.checkpointMappings.map((c, j) =>
                                j === i ? { ...c, missionId: e.target.value } : c
                              ),
                            }))
                          }
                          className="block w-full rounded-md border border-gray-300 px-2 py-1 text-xs shadow-sm"
                        >
                          <option value="">Select mission…</option>
                          {missions.map((mission) => (
                            <option key={mission.id} value={mission.id}>
                              {mission.title}
                            </option>
                          ))}
                        </select>
                        <input
                          type="number"
                          min={1}
                          value={cm.checkpointNumber ?? ''}
                          onChange={(e) =>
                            setForm((prev) => ({
                              ...prev,
                              checkpointMappings: prev.checkpointMappings.map((c, j) =>
                                j === i
                                  ? {
                                      ...c,
                                      checkpointNumber: e.target.value
                                        ? Number.parseInt(e.target.value, 10)
                                        : undefined,
                                    }
                                  : c
                              ),
                            }))
                          }
                          className="block w-full rounded-md border border-gray-300 px-2 py-1 text-xs shadow-sm"
                          placeholder="Checkpoint number"
                        />
                      </div>
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
                      {cm.checkpointId && (
                        <p className="text-[11px] font-mono text-gray-500">
                          Canonical checkpoint ID: {cm.checkpointId}
                        </p>
                      )}
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
  processDomains,
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
  processDomains: ProcessDomain[];
  isEditing: boolean;
  saving: boolean;
  onSave: () => void;
  onCancel: () => void;
  addCriterion: () => void;
  removeCriterion: (index: number) => void;
  updateCriterion: (index: number, field: string, value: string | number) => void;
}) {
  const activeCapabilities = capabilities.filter((c) => c.status !== 'archived');
  const activeProcessDomains = processDomains.filter((pd) => pd.status !== 'archived');

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

          {/* Status toggle */}
          <div className="flex items-center gap-3">
            <label className="text-sm font-medium text-gray-700">Status:</label>
            <button
              type="button"
              onClick={() => setForm((prev) => ({ ...prev, status: prev.status === 'draft' ? 'published' : 'draft' }))}
              className={`rounded-full px-3 py-1 text-xs font-semibold ${
                form.status === 'published'
                  ? 'bg-green-100 text-green-800'
                  : 'bg-yellow-100 text-yellow-800'
              }`}
            >
              {form.status === 'published' ? 'Published' : 'Draft'}
            </button>
            <span className="text-xs text-gray-400">
              {form.status === 'draft' ? 'Not visible to educators yet' : 'Visible to educators for scoring'}
            </span>
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
                        {activeProcessDomains.length > 0 && (
                          <select
                            aria-label="Process domain (optional)"
                            value={criterion.processDomainId}
                            onChange={(e) => updateCriterion(i, 'processDomainId', e.target.value)}
                            className="block w-full rounded-md border border-gray-300 px-2 py-1 text-xs shadow-sm"
                          >
                            <option value="">Process domain (optional)...</option>
                            {activeProcessDomains.map((pd) => (
                              <option key={pd.id} value={pd.id}>
                                {pd.title}
                              </option>
                            ))}
                          </select>
                        )}
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
