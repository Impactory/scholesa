'use client';

import React, { useEffect, useMemo, useState } from 'react';
import { BelongingEngine, CompetenceEngine } from '@/src/lib/motivation/motivationEngine';

interface ClassInsightsProps {
  siteId: string;
  sessionOccurrenceId?: string;
  learnerIds?: string[];
  onSelectLearner?: (learnerId: string) => void;
}

export function ClassInsights(_props: ClassInsightsProps) {
  const { siteId, learnerIds = [], onSelectLearner } = _props;
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [rows, setRows] = useState<Array<{
    learnerId: string;
    skillsProven: number;
    skillsInProgress: number;
    checkpointsPassed: number;
    recognitions: number;
  }>>([]);

  useEffect(() => {
    let isMounted = true;

    const load = async () => {
      if (learnerIds.length === 0) {
        if (isMounted) {
          setRows([]);
          setLoading(false);
        }
        return;
      }

      setLoading(true);
      setError(null);
      try {
        const nextRows = await Promise.all(
          learnerIds.map(async (learnerId) => {
            const [mastery, recognitions] = await Promise.all([
              CompetenceEngine.getMasteryDashboard(learnerId, siteId),
              BelongingEngine.getRecognitionReceived(learnerId, siteId, 5),
            ]);

            return {
              learnerId,
              skillsProven: mastery.skillsProven,
              skillsInProgress: mastery.skillsInProgress,
              checkpointsPassed: mastery.checkpointsPassed,
              recognitions: recognitions.length,
            };
          })
        );

        if (!isMounted) return;
        setRows(nextRows);
      } catch {
        if (!isMounted) return;
        setError('Unable to load class insights right now.');
      } finally {
        if (isMounted) setLoading(false);
      }
    };

    void load();
    return () => {
      isMounted = false;
    };
  }, [siteId, learnerIds]);

  return (
    <div className="rounded-xl border border-gray-200 bg-white p-6">
      <h3 className="mb-4 text-sm font-semibold text-gray-900">Class Insights</h3>

      {loading ? <p className="text-sm text-gray-500">Loading insights…</p> : null}
      {error ? <p className="text-sm text-red-600">{error}</p> : null}

      {!loading && !error && learnerIds.length === 0 ? (
        <p className="text-sm text-gray-500">Select learners to view live insights.</p>
      ) : null}

      {!loading && !error && rows.length > 0 ? (
        <div className="space-y-2">
          {rows.map((row) => (
            <button
              key={row.learnerId}
              type="button"
              className="w-full rounded-lg border border-gray-200 p-3 text-left hover:bg-gray-50"
              onClick={() => onSelectLearner?.(row.learnerId)}
            >
              <p className="text-sm font-medium text-gray-900">Learner {row.learnerId}</p>
              <p className="mt-1 text-xs text-gray-600">
                Proven: {row.skillsProven} · In progress: {row.skillsInProgress} · Checkpoints: {row.checkpointsPassed} · Recognition: {row.recognitions}
              </p>
            </button>
          ))}
        </div>
      ) : null}
    </div>
  );
}

export function ClassInsightsCompact({
  siteId: _siteId,
  onViewFull: _onViewFull,
}: {
  siteId: string;
  onViewFull?: () => void;
}) {
  const summaryText = useMemo(() => `Class insights are available for ${siteId}.`, [siteId]);

  return (
    <div className="rounded-lg border border-gray-200 bg-gray-50 p-4">
      <p className="text-sm text-gray-700">{summaryText}</p>
      {onViewFull ? (
        <button
          type="button"
          className="mt-2 rounded-md border border-gray-300 px-2 py-1 text-xs font-medium text-gray-700"
          onClick={onViewFull}
        >
          View full insights
        </button>
      ) : null}
    </div>
  );
}
