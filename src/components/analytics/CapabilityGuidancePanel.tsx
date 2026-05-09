'use client';

import { useEffect, useState } from 'react';
import {
  getDocs,
  query,
  where,
} from 'firebase/firestore';
import {
  capabilityMasteryCollection,
  capabilityGrowthEventsCollection,
} from '@/src/firebase/firestore/collections';
import { Spinner } from '@/src/components/ui/Spinner';
import { useCapabilities } from '@/src/lib/capabilities/useCapabilities';
import {
  LEGACY_PILLAR_ORDER,
  getLegacyPillarFamilyLabel,
  normalizeLegacyPillarCode,
} from '@/src/lib/curriculum/architecture';
import type { CapabilityMastery } from '@/src/types/schema';

/* ───── Interpretation Maps ───── */

const BAND_GUIDANCE: Record<string, { label: string; color: string; parentMessage: string; nextSteps: string }> = {
  strong: {
    label: 'Strong',
    color: 'bg-green-100 text-green-800 border-green-200',
    parentMessage: 'Your child can independently demonstrate and explain this capability. Evidence confirms understanding through multiple observations.',
    nextSteps: 'Celebrate their progress! Encourage them to mentor peers or explore more advanced challenges in this area.',
  },
  developing: {
    label: 'Developing',
    color: 'bg-blue-100 text-blue-800 border-blue-200',
    parentMessage: 'Your child is building toward independent demonstration of this capability. They show understanding but may still need guidance in some situations.',
    nextSteps: 'Ask them to explain what they are working on in their own words. Encourage practice and reflection on what they find challenging.',
  },
  emerging: {
    label: 'Emerging',
    color: 'bg-amber-100 text-amber-800 border-amber-200',
    parentMessage: 'Your child is beginning to explore this capability. Evidence is still being collected, and they are in the early stages of building understanding.',
    nextSteps: 'Be patient and supportive. Ask their teacher what you can do at home to reinforce learning in this area.',
  },
  'no-evidence': {
    label: 'Not yet assessed',
    color: 'bg-gray-100 text-gray-600 border-gray-200',
    parentMessage: 'There is not yet enough evidence to make a trustworthy assessment. This does not mean your child is behind — it means observations have not been recorded yet.',
    nextSteps: 'No action needed. Evidence will be collected through classroom activities, checkpoints, and your child\'s portfolio submissions.',
  },
};

const LEVEL_DESCRIPTIONS: Record<number, string> = {
  0: 'Not yet assessed',
  1: 'Beginning — early exploration',
  2: 'Developing — building understanding',
  3: 'Proficient — can demonstrate independently',
  4: 'Advanced — can teach and extend',
};

const LEVEL_KEYS: Record<number, 'beginning' | 'developing' | 'proficient' | 'advanced'> = {
  1: 'beginning',
  2: 'developing',
  3: 'proficient',
  4: 'advanced',
};

const MASTERY_LEVEL_SCORE: Record<string, number> = {
  emerging: 1,
  developing: 2,
  proficient: 3,
  advanced: 4,
};

/* ───── Component ───── */

interface CapabilityGuidancePanelProps {
  learnerId: string;
  siteId: string;
  learnerName?: string;
}

interface PillarSummary {
  pillarCode: string;
  pillarLabel: string;
  averageLevel: number;
  band: string;
  capabilityCount: number;
  evidenceCount: number;
  latestGrowthDate: Date | null;
}

export function CapabilityGuidancePanel({ learnerId, siteId, learnerName }: CapabilityGuidancePanelProps) {
  const { capabilityList: capabilities, loading: capLoading } = useCapabilities(siteId);
  const [mastery, setMastery] = useState<CapabilityMastery[]>([]);
  const [loading, setLoading] = useState(true);
  const [growthCount, setGrowthCount] = useState(0);

  useEffect(() => {
    if (!learnerId || !siteId) return;
    let cancelled = false;

    async function load() {
      setLoading(true);
      try {
        const [masterySnap, growthSnap] = await Promise.all([
          getDocs(query(capabilityMasteryCollection, where('learnerId', '==', learnerId))),
          getDocs(query(capabilityGrowthEventsCollection, where('learnerId', '==', learnerId))),
        ]);
        if (cancelled) return;
        setMastery(masterySnap.docs.map((d) => ({ ...d.data(), id: d.id }) as CapabilityMastery));
        setGrowthCount(growthSnap.size);
      } catch (err) {
        console.error('Failed to load capability data', err);
      } finally {
        if (!cancelled) setLoading(false);
      }
    }

    void load();
    return () => { cancelled = true; };
  }, [learnerId, siteId]);

  if (loading || capLoading) {
    return (
      <div className="rounded-lg border border-gray-200 bg-white p-6 shadow-sm">
        <div className="flex items-center gap-2 text-gray-400">
          <Spinner />
          <span className="text-sm">Loading capability guidance...</span>
        </div>
      </div>
    );
  }

  // Group mastery by pillar
  const pillarMap = new Map<string, { levels: number[]; evidenceCounts: number[]; latestDates: Date[] }>();
  for (const m of mastery) {
    const pillar = normalizeLegacyPillarCode(m.pillarCode);
    if (!pillar) continue;
    const entry = pillarMap.get(pillar) ?? { levels: [], evidenceCounts: [], latestDates: [] };
    entry.levels.push(MASTERY_LEVEL_SCORE[m.latestLevel] ?? 0);
    entry.evidenceCounts.push(m.evidenceIds?.length ?? 0);
    if (m.updatedAt && typeof m.updatedAt.toDate === 'function') {
      entry.latestDates.push(m.updatedAt.toDate());
    }
    pillarMap.set(pillar, entry);
  }

  // Build pillar summaries
  const pillars: PillarSummary[] = LEGACY_PILLAR_ORDER.map((code) => {
    const data = pillarMap.get(code);
    if (!data || data.levels.length === 0) {
      return {
        pillarCode: code,
        pillarLabel: getLegacyPillarFamilyLabel(code),
        averageLevel: 0,
        band: 'no-evidence',
        capabilityCount: 0,
        evidenceCount: 0,
        latestGrowthDate: null,
      };
    }
    const avg = data.levels.reduce((a, b) => a + b, 0) / data.levels.length;
    const totalEvidence = data.evidenceCounts.reduce((a, b) => a + b, 0);
    const latestDate = data.latestDates.length > 0
      ? new Date(Math.max(...data.latestDates.map((d) => d.getTime())))
      : null;

    const normalized = avg / 4; // 0-1
    const band = normalized >= 0.75 ? 'strong' : normalized >= 0.45 ? 'developing' : 'emerging';

    return {
      pillarCode: code,
      pillarLabel: getLegacyPillarFamilyLabel(code),
      averageLevel: Math.round(avg * 10) / 10,
      band,
      capabilityCount: data.levels.length,
      evidenceCount: totalEvidence,
      latestGrowthDate: latestDate,
    };
  });

  const overallBand = mastery.length === 0
    ? 'no-evidence'
    : pillars.every((p) => p.band === 'strong')
      ? 'strong'
      : pillars.some((p) => p.band === 'emerging' || p.band === 'no-evidence')
        ? 'emerging'
        : 'developing';

  const guidance = BAND_GUIDANCE[overallBand] ?? BAND_GUIDANCE['no-evidence'];
  const displayName = learnerName ?? 'your child';

  return (
    <div className="rounded-lg border border-gray-200 bg-white shadow-sm overflow-hidden" data-testid="capability-guidance-panel">
      {/* Header with overall band */}
      <div className={`px-6 py-4 border-b ${guidance.color}`}>
        <h2 className="text-lg font-semibold">
          Capability Growth — {guidance.label}
        </h2>
        <p className="mt-1 text-sm opacity-90">
          {guidance.parentMessage.replace('Your child', displayName.charAt(0).toUpperCase() + displayName.slice(1))}
        </p>
      </div>

      {/* Legacy family breakdown */}
      <div className="p-6 space-y-4">
        <p className="text-xs text-gray-500">
          Legacy family breakdown for the live six-strand curriculum.
        </p>
        {pillars.map((pillar) => {
          const pg = BAND_GUIDANCE[pillar.band] ?? BAND_GUIDANCE['no-evidence'];
          return (
            <div key={pillar.pillarCode} className="rounded-lg border border-gray-100 p-4">
              <div className="flex items-center justify-between mb-2">
                <h3 className="text-sm font-semibold text-gray-900">{pillar.pillarLabel}</h3>
                <span className={`rounded-full border px-2.5 py-0.5 text-xs font-medium ${pg.color}`}>
                  {pg.label}
                </span>
              </div>

              {/* Progress bar */}
              <progress
                aria-label={`${pillar.pillarLabel} capability level`}
                className={`mb-2 h-2 w-full rounded-full bg-gray-100 ${
                  pillar.band === 'strong' ? 'accent-green-500' :
                  pillar.band === 'developing' ? 'accent-blue-500' :
                  pillar.band === 'emerging' ? 'accent-amber-400' : 'accent-gray-300'
                }`}
                value={pillar.averageLevel}
                max={4}
              />

              <div className="flex items-center gap-4 text-xs text-gray-500">
                <span>Level {pillar.averageLevel}/4 — {LEVEL_DESCRIPTIONS[Math.round(pillar.averageLevel)] ?? 'In progress'}</span>
                {pillar.evidenceCount > 0 && <span>{pillar.evidenceCount} evidence items</span>}
                {pillar.capabilityCount > 0 && <span>{pillar.capabilityCount} capabilities tracked</span>}
              </div>

              <p className="mt-2 text-xs text-gray-600">{pg.nextSteps}</p>

              {/* Per-capability progression descriptors */}
              {mastery
                .filter((m) => normalizeLegacyPillarCode(m.pillarCode) === pillar.pillarCode)
                .map((m) => {
                  const cap = capabilities.find((c) => c.id === m.capabilityId);
                  if (!cap) return null;
                  const level = MASTERY_LEVEL_SCORE[m.latestLevel] ?? 0;
                  const levelKey = LEVEL_KEYS[Math.min(4, Math.max(1, Math.round(level))) as 1 | 2 | 3 | 4];
                  const descriptor = cap.progressionDescriptors?.[levelKey];
                  return (
                    <div key={m.id ?? m.capabilityId} className="mt-2 rounded border border-gray-50 bg-gray-50 px-3 py-2">
                      <div className="flex items-center justify-between">
                        <span className="text-xs font-medium text-gray-800">{cap.title}</span>
                        <span className="text-xs text-gray-500">Level {level}/4</span>
                      </div>
                      {descriptor ? (
                        <p className="mt-0.5 text-xs text-gray-600 italic">&ldquo;{descriptor}&rdquo;</p>
                      ) : null}
                    </div>
                  );
                })}
            </div>
          );
        })}

        {/* Overall evidence summary */}
        <div className="rounded-lg bg-gray-50 border border-gray-100 p-4 text-sm text-gray-600">
          <p className="font-medium text-gray-800 mb-1">How this assessment works</p>
          <p>
            Capability bands are based on <strong>{mastery.length}</strong> capability assessments
            backed by <strong>{growthCount}</strong> growth observations from your child&apos;s educators.
            These are not test scores — they reflect what {displayName} can demonstrate, explain,
            and build over time. If data is limited, the assessment may be incomplete.
          </p>
        </div>

        {/* Next steps */}
        <div className="rounded-lg border border-indigo-100 bg-indigo-50 p-4 text-sm text-indigo-800">
          <p className="font-medium mb-1">What you can do</p>
          <p>{guidance.nextSteps}</p>
        </div>
      </div>
    </div>
  );
}
