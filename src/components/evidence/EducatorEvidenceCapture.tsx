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
  capabilitiesCollection,
  evidenceRecordsCollection,
  usersCollection,
} from '@/src/firebase/firestore/collections';
import { RoleRouteGuard } from '@/src/components/auth/RoleRouteGuard';
import { Spinner } from '@/src/components/ui/Spinner';
import type { Capability, EvidenceRecord } from '@/src/types/schema';

const PHASE_OPTIONS: { value: EvidenceRecord['phaseKey']; label: string }[] = [
  { value: 'retrieval_warm_up', label: 'Retrieval / Warm-up' },
  { value: 'mini_lesson', label: 'Mini Lesson' },
  { value: 'build_sprint', label: 'Build Sprint' },
  { value: 'checkpoint', label: 'Checkpoint' },
  { value: 'share_out', label: 'Share Out' },
  { value: 'reflection', label: 'Reflection' },
];

interface LearnerOption {
  uid: string;
  displayName: string;
}

interface RecentEvidence {
  id: string;
  learnerName: string;
  description: string;
  capabilityLabel: string | null;
  phaseKey: string | null;
  portfolioCandidate: boolean;
}

export function EducatorEvidenceCapture() {
  const { user, profile, loading: authLoading } = useAuthContext();
  const siteId = profile?.studioId ?? null;

  const [learners, setLearners] = useState<LearnerOption[]>([]);
  const [capabilities, setCapabilities] = useState<Capability[]>([]);
  const [recentEvidence, setRecentEvidence] = useState<RecentEvidence[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);

  // Form state
  const [selectedLearnerId, setSelectedLearnerId] = useState('');
  const [description, setDescription] = useState('');
  const [selectedCapabilityId, setSelectedCapabilityId] = useState('');
  const [freeTextCapability, setFreeTextCapability] = useState('');
  const [phaseKey, setPhaseKey] = useState<EvidenceRecord['phaseKey']>(undefined);
  const [portfolioCandidate, setPortfolioCandidate] = useState(false);

  const learnerNameMap = useMemo(() => {
    const map = new Map<string, string>();
    for (const l of learners) map.set(l.uid, l.displayName);
    return map;
  }, [learners]);

  const selectedCapability = useMemo(
    () => capabilities.find((c) => c.id === selectedCapabilityId) ?? null,
    [capabilities, selectedCapabilityId]
  );

  const loadData = useCallback(async () => {
    if (!siteId) return;
    setLoading(true);
    try {
      const [learnerSnap, capabilitySnap, evidenceSnap] = await Promise.all([
        getDocs(
          query(usersCollection, where('studioId', '==', siteId), where('role', '==', 'learner'), orderBy('displayName'))
        ),
        getDocs(query(capabilitiesCollection, where('siteId', '==', siteId))),
        getDocs(
          query(evidenceRecordsCollection, where('siteId', '==', siteId), orderBy('createdAt', 'desc'), limit(20))
        ),
      ]);

      setLearners(
        learnerSnap.docs.map((d) => ({
          uid: d.data().uid,
          displayName: d.data().displayName,
        }))
      );
      setCapabilities(capabilitySnap.docs.map((d) => ({ ...d.data(), id: d.id })));

      const learnerNames = new Map<string, string>();
      for (const d of learnerSnap.docs) learnerNames.set(d.data().uid, d.data().displayName);

      setRecentEvidence(
        evidenceSnap.docs.map((d) => {
          const data = d.data();
          return {
            id: d.id,
            learnerName: learnerNames.get(data.learnerId) ?? data.learnerId,
            description: data.description,
            capabilityLabel: data.capabilityLabel ?? null,
            phaseKey: data.phaseKey ?? null,
            portfolioCandidate: data.portfolioCandidate,
          };
        })
      );
    } catch (err) {
      console.error('Failed to load evidence capture data', err);
    } finally {
      setLoading(false);
    }
  }, [siteId]);

  useEffect(() => {
    if (!authLoading && siteId) void loadData();
  }, [authLoading, siteId, loadData]);

  const resetForm = () => {
    setDescription('');
    setSelectedCapabilityId('');
    setFreeTextCapability('');
    setPhaseKey(undefined);
    setPortfolioCandidate(false);
    // Keep selectedLearnerId for quick successive logs
  };

  const handleSubmit = async () => {
    if (!user || !siteId || !selectedLearnerId || !description.trim()) return;
    setSaving(true);
    setSuccessMessage(null);

    const capabilityLabel =
      selectedCapability?.title ?? (freeTextCapability.trim() || null);
    const capabilityId = selectedCapability?.id ?? null;

    try {
      await addDoc(evidenceRecordsCollection, {
        learnerId: selectedLearnerId,
        educatorId: user.uid,
        siteId,
        description: description.trim(),
        capabilityId: capabilityId ?? undefined,
        capabilityLabel: capabilityLabel ?? undefined,
        capabilityMapped: !!capabilityId,
        phaseKey,
        portfolioCandidate,
        rubricStatus: 'pending' as const,
        growthStatus: 'pending' as const,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      } as Omit<EvidenceRecord, 'id'>);

      const learnerName = learnerNameMap.get(selectedLearnerId) ?? selectedLearnerId;
      setSuccessMessage(`Logged for ${learnerName}`);
      resetForm();

      // Prepend to recent evidence for instant feedback
      setRecentEvidence((prev) => [
        {
          id: `temp-${Date.now()}`,
          learnerName,
          description: description.trim(),
          capabilityLabel,
          phaseKey: phaseKey ?? null,
          portfolioCandidate,
        },
        ...prev.slice(0, 19),
      ]);
    } catch (err) {
      console.error('Failed to save evidence record', err);
    } finally {
      setSaving(false);
    }
  };

  // Auto-clear success message
  useEffect(() => {
    if (!successMessage) return;
    const timeout = setTimeout(() => setSuccessMessage(null), 3000);
    return () => clearTimeout(timeout);
  }, [successMessage]);

  if (authLoading) {
    return (
      <div className="flex min-h-[240px] items-center justify-center">
        <Spinner />
      </div>
    );
  }

  if (!siteId) {
    return (
      <div className="rounded-xl border border-amber-200 bg-amber-50 p-6 text-sm text-amber-900">
        No site assigned. Evidence capture requires a site context.
      </div>
    );
  }

  const canSubmit = !!selectedLearnerId && description.trim().length > 0 && !saving;

  return (
    <RoleRouteGuard allowedRoles={['educator', 'site', 'hq']}>
      <section className="space-y-4" data-testid="evidence-capture-page">
        <header className="rounded-xl border border-app bg-app-surface-raised p-4">
          <h1 className="text-xl font-bold text-app-foreground">Live Evidence Capture</h1>
          <p className="mt-1 text-sm text-app-muted">
            Log learner observations during sessions. Designed for speed — under 10 seconds per entry.
          </p>
        </header>

        {/* Success banner */}
        {successMessage && (
          <div className="rounded-lg border border-green-200 bg-green-50 px-4 py-2 text-sm font-medium text-green-800" data-testid="evidence-success">
            {successMessage}
          </div>
        )}

        {/* Quick capture form */}
        <div className="rounded-xl border border-app bg-app-surface-raised p-4 space-y-3" data-testid="evidence-form">
          {/* Row 1: Learner + Phase */}
          <div className="grid gap-3 sm:grid-cols-2">
            <label className="space-y-1">
              <span className="text-xs font-medium text-app-muted">Learner *</span>
              <select
                data-testid="evidence-learner"
                value={selectedLearnerId}
                onChange={(e) => setSelectedLearnerId(e.target.value)}
                className="w-full rounded-md border border-app bg-app-canvas px-3 py-2 text-sm text-app-foreground"
              >
                <option value="">Select learner</option>
                {learners.map((l) => (
                  <option key={l.uid} value={l.uid}>
                    {l.displayName}
                  </option>
                ))}
              </select>
            </label>

            <label className="space-y-1">
              <span className="text-xs font-medium text-app-muted">Session Phase</span>
              <select
                data-testid="evidence-phase"
                value={phaseKey ?? ''}
                onChange={(e) =>
                  setPhaseKey((e.target.value || undefined) as EvidenceRecord['phaseKey'])
                }
                className="w-full rounded-md border border-app bg-app-canvas px-3 py-2 text-sm text-app-foreground"
              >
                <option value="">Any phase</option>
                {PHASE_OPTIONS.map((p) => (
                  <option key={p.value} value={p.value}>
                    {p.label}
                  </option>
                ))}
              </select>
            </label>
          </div>

          {/* Row 2: Observation description */}
          <label className="block space-y-1">
            <span className="text-xs font-medium text-app-muted">What did you observe? *</span>
            <textarea
              data-testid="evidence-description"
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              placeholder="e.g., 'Built a working prototype and explained the logic to their partner'"
              className="w-full rounded-md border border-app bg-app-canvas px-3 py-2 text-sm text-app-foreground min-h-20"
            />
          </label>

          {/* Row 3: Capability + Portfolio flag */}
          <div className="grid gap-3 sm:grid-cols-2">
            <label className="space-y-1">
              <span className="text-xs font-medium text-app-muted">Capability</span>
              {capabilities.length > 0 ? (
                <select
                  data-testid="evidence-capability"
                  value={selectedCapabilityId}
                  onChange={(e) => {
                    setSelectedCapabilityId(e.target.value);
                    if (e.target.value) setFreeTextCapability('');
                  }}
                  className="w-full rounded-md border border-app bg-app-canvas px-3 py-2 text-sm text-app-foreground"
                >
                  <option value="">Select or type below</option>
                  {capabilities.map((c) => (
                    <option key={c.id} value={c.id}>
                      {c.title} ({c.pillarCode.replace(/_/g, ' ')})
                    </option>
                  ))}
                </select>
              ) : (
                <input
                  data-testid="evidence-capability-text"
                  type="text"
                  value={freeTextCapability}
                  onChange={(e) => setFreeTextCapability(e.target.value)}
                  placeholder="e.g., Problem Solving"
                  className="w-full rounded-md border border-app bg-app-canvas px-3 py-2 text-sm text-app-foreground"
                />
              )}
            </label>

            <div className="flex items-end pb-1">
              <label className="flex items-center gap-2 rounded-md border border-app bg-app-canvas px-3 py-2">
                <input
                  data-testid="evidence-portfolio"
                  type="checkbox"
                  checked={portfolioCandidate}
                  onChange={(e) => setPortfolioCandidate(e.target.checked)}
                />
                <span className="text-sm text-app-foreground">Portfolio candidate</span>
              </label>
            </div>
          </div>

          {/* Free-text capability fallback when dropdown is present but none selected */}
          {capabilities.length > 0 && !selectedCapabilityId && (
            <label className="block space-y-1">
              <span className="text-xs font-medium text-app-muted">Or type capability label</span>
              <input
                data-testid="evidence-capability-text"
                type="text"
                value={freeTextCapability}
                onChange={(e) => setFreeTextCapability(e.target.value)}
                placeholder="Free-text capability if not in list"
                className="w-full rounded-md border border-app bg-app-canvas px-3 py-2 text-sm text-app-foreground"
              />
            </label>
          )}

          {/* Submit */}
          <button
            type="button"
            data-testid="evidence-submit"
            disabled={!canSubmit}
            onClick={() => void handleSubmit()}
            className="w-full rounded-md bg-primary px-4 py-2.5 text-sm font-semibold text-primary-foreground disabled:opacity-50 sm:w-auto"
          >
            {saving ? 'Saving...' : 'Log Evidence'}
          </button>
        </div>

        {/* Recent evidence log */}
        <div className="rounded-xl border border-app bg-app-surface p-4" data-testid="evidence-recent">
          <h2 className="text-sm font-semibold text-app-foreground mb-3">Recent Observations</h2>
          {loading ? (
            <div className="flex items-center gap-2 text-app-muted py-4">
              <Spinner />
              <span className="text-sm">Loading...</span>
            </div>
          ) : recentEvidence.length === 0 ? (
            <p className="text-sm text-app-muted py-4">No evidence logged yet for this site.</p>
          ) : (
            <ul className="space-y-2">
              {recentEvidence.map((ev) => (
                <li
                  key={ev.id}
                  className="rounded-lg border border-app bg-app-canvas p-3 text-sm"
                >
                  <div className="flex items-start justify-between gap-2">
                    <div>
                      <span className="font-medium text-app-foreground">{ev.learnerName}</span>
                      <span className="mx-1 text-app-muted">—</span>
                      <span className="text-app-foreground">{ev.description}</span>
                    </div>
                    {ev.portfolioCandidate && (
                      <span className="shrink-0 rounded bg-blue-100 px-1.5 py-0.5 text-xs font-medium text-blue-800">
                        Portfolio
                      </span>
                    )}
                  </div>
                  <div className="mt-1 flex flex-wrap gap-2 text-xs text-app-muted">
                    {ev.capabilityLabel && (
                      <span className="rounded bg-app-surface px-1.5 py-0.5">{ev.capabilityLabel}</span>
                    )}
                    {ev.phaseKey && (
                      <span className="rounded bg-app-surface px-1.5 py-0.5">
                        {PHASE_OPTIONS.find((p) => p.value === ev.phaseKey)?.label ?? ev.phaseKey}
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
