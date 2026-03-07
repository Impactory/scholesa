'use client';

import React, { useEffect, useMemo, useState } from 'react';
import { useAuthContext } from '@/src/firebase/auth/AuthProvider';
import { AutonomyEngine, CompetenceEngine, type MissionChoice } from '@/src/lib/motivation/motivationEngine';
import { useInteractionTracking, usePageViewTracking } from '@/src/hooks/useTelemetry';

interface MotivationNudgesProps {
  siteId: string;
  maxNudges?: number;
  showInline?: boolean;
  onNudgeAction?: (nudgeId: string, action: 'accepted' | 'dismissed' | 'snoozed') => void;
}

export function MotivationNudges(_props: MotivationNudgesProps) {
  const { siteId, maxNudges = 3, showInline = false, onNudgeAction } = _props;
  const { user, profile } = useAuthContext();
  const trackInteraction = useInteractionTracking();
  usePageViewTracking('motivation_nudges', { siteId, maxNudges, showInline });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [choices, setChoices] = useState<MissionChoice[]>([]);
  const [milestones, setMilestones] = useState<string[]>([]);

  const inferredGrade = useMemo(() => {
    const rawGrade = (profile as Record<string, unknown> | null)?.grade;
    if (typeof rawGrade === 'number' && Number.isFinite(rawGrade)) return rawGrade;
    return 5;
  }, [profile]);

  useEffect(() => {
    let isMounted = true;

    const load = async () => {
      if (!user?.uid) {
        if (isMounted) {
          setChoices([]);
          setMilestones([]);
          setLoading(false);
        }
        return;
      }

      setLoading(true);
      setError(null);
      try {
        const [missionChoices, dashboard] = await Promise.all([
          AutonomyEngine.getMissionChoices(user.uid, siteId, inferredGrade),
          CompetenceEngine.getMasteryDashboard(user.uid, siteId),
        ]);

        if (!isMounted) return;
        setChoices(missionChoices.slice(0, maxNudges));
        setMilestones(dashboard.nextMilestones.slice(0, Math.max(1, maxNudges - 1)));
      } catch {
        if (!isMounted) return;
        setError('Unable to load nudges right now.');
      } finally {
        if (isMounted) setLoading(false);
      }
    };

    void load();
    return () => {
      isMounted = false;
    };
  }, [user?.uid, siteId, inferredGrade, maxNudges]);

  const nudgeCount = choices.length + milestones.length;

  if (!showInline && nudgeCount === 0 && !loading && !error) {
    return null;
  }

  return (
    <div className="rounded-xl border border-gray-200 bg-white p-6">
      <div className="mb-4 flex items-center justify-between">
        <h3 className="text-sm font-semibold text-gray-900">Motivation Nudges</h3>
        <NudgeIndicator count={nudgeCount} />
      </div>

      {loading ? <p className="text-sm text-gray-500">Loading nudges…</p> : null}
      {error ? <p className="text-sm text-red-600">{error}</p> : null}

      {!loading && !error && nudgeCount === 0 ? (
        <p className="text-sm text-gray-500">No nudges right now — great momentum.</p>
      ) : null}

      <div className="space-y-3">
        {choices.map((choice) => (
          <div key={choice.id} className="rounded-lg border border-gray-200 p-3">
            <p className="text-sm font-medium text-gray-900">Try: {choice.title}</p>
            <p className="mt-1 text-xs text-gray-600">{choice.description}</p>
            <div className="mt-2 flex gap-2">
              <button
                type="button"
                className="rounded-md bg-gray-900 px-2 py-1 text-xs font-medium text-white"
                onClick={() => {
                  trackInteraction('feature_discovered', {
                    cta: 'motivation_nudge_start',
                    nudgeId: choice.id,
                    siteId,
                  });
                  onNudgeAction?.(choice.id, 'accepted');
                }}
              >
                Start
              </button>
              <button
                type="button"
                className="rounded-md border border-gray-300 px-2 py-1 text-xs font-medium text-gray-700"
                onClick={() => {
                  trackInteraction('help_accessed', {
                    cta: 'motivation_nudge_dismiss',
                    nudgeId: choice.id,
                    siteId,
                  });
                  onNudgeAction?.(choice.id, 'dismissed');
                }}
              >
                Dismiss
              </button>
            </div>
          </div>
        ))}

        {milestones.map((milestone, index) => {
          const id = `milestone_${index}`;
          return (
            <div key={id} className="rounded-lg border border-gray-200 p-3">
              <p className="text-sm font-medium text-gray-900">Next Milestone</p>
              <p className="mt-1 text-xs text-gray-600">{milestone}</p>
              <div className="mt-2">
                <button
                  type="button"
                  className="rounded-md border border-gray-300 px-2 py-1 text-xs font-medium text-gray-700"
                  onClick={() => {
                    trackInteraction('help_accessed', {
                      cta: 'motivation_nudge_snooze',
                      nudgeId: id,
                      siteId,
                    });
                    onNudgeAction?.(id, 'snoozed');
                  }}
                >
                  Snooze
                </button>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

export function NudgeIndicator({ count = 0 }: { count?: number }) {
  if (count <= 0) return null;

  return (
    <span className="inline-flex items-center rounded-full border border-gray-300 px-2 py-0.5 text-xs font-medium text-gray-700">
      {count}
    </span>
  );
}
