'use client';

/**
 * Learning Path Map
 * 
 * Level 1: Must-have for flow and retention
 * Shows: Unit → Missions → Micro-skills (locked until evidence)
 * Feels like a journey
 */

import React, { useEffect, useState } from 'react';
import { useInteractionTracking } from '@/src/hooks/useTelemetry';
import {
  LockIcon,
  CheckCircle2Icon,
  CircleIcon,
  TrophyIcon,
  MapIcon,
  ArrowRightIcon
} from 'lucide-react';
import {
  sdtMotivation,
  type LearningPathProgress,
  DIFFICULTY_EMOJI,
  DIFFICULTY_LABELS
} from '@/src/lib/motivation/sdtMotivation';

interface LearningPathMapProps {
  learnerId: string;
  siteId: string;
  courseId?: string;
  onSelectMission?: (missionId: string) => void;
}

export function LearningPathMap({
  learnerId,
  siteId,
  courseId,
  onSelectMission
}: LearningPathMapProps) {
  const [path, setPath] = useState<LearningPathProgress[]>([]);
  const [loading, setLoading] = useState(true);
  const [expandedUnits, setExpandedUnits] = useState<Set<string>>(new Set());
  const trackInteraction = useInteractionTracking();

  useEffect(() => {
    const fetchPath = async () => {
      try {
        setLoading(true);
        const pathData = await sdtMotivation.getLearningPath(learnerId, siteId, courseId);
        setPath(pathData);
        
        // Auto-expand first uncompleted unit
        const firstIncomplete = pathData.find(u => u.missionsCompleted < u.missionsTotal);
        if (firstIncomplete) {
          setExpandedUnits(new Set([firstIncomplete.unitId]));
        }
      } catch (err) {
        console.error('Error fetching learning path:', err);
      } finally {
        setLoading(false);
      }
    };

    fetchPath();
  }, [learnerId, siteId, courseId]);

  const toggleUnit = (unitId: string) => {
    trackInteraction('feature_discovered', { cta: 'learning_path_toggle_unit', unitId });
    setExpandedUnits(prev => {
      const next = new Set(prev);
      if (next.has(unitId)) {
        next.delete(unitId);
      } else {
        next.add(unitId);
      }
      return next;
    });
  };

  if (loading) {
    return (
      <div className="space-y-4 animate-pulse">
        {[1, 2, 3].map(i => (
          <div key={i} className="h-32 bg-gray-200 rounded-lg"></div>
        ))}
      </div>
    );
  }

  if (path.length === 0) {
    return (
      <div className="bg-gray-50 border border-gray-200 rounded-lg p-8 text-center">
        <MapIcon className="w-16 h-16 mx-auto text-gray-400 mb-4" />
        <p className="text-gray-600">No learning path available yet.</p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center gap-3">
        <MapIcon className="w-8 h-8 text-indigo-600" />
        <div>
          <h2 className="text-2xl font-bold text-gray-900">Your Learning Journey</h2>
          <p className="text-gray-600">Track your progress and unlock new challenges</p>
        </div>
      </div>

      {/* Path Units */}
      <div className="space-y-4">
        {path.map((unit, idx) => (
          <UnitCard
            key={unit.unitId}
            unit={unit}
            isExpanded={expandedUnits.has(unit.unitId)}
            onToggle={() => toggleUnit(unit.unitId)}
            onTrackInteraction={trackInteraction}
            onSelectMission={onSelectMission}
            isFirst={idx === 0}
            isLast={idx === path.length - 1}
          />
        ))}
      </div>

      {/* Legend */}
      <div className="bg-gray-50 rounded-lg p-4 border border-gray-200">
        <p className="text-sm font-medium text-gray-700 mb-2">Legend</p>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-3 text-xs">
          <div className="flex items-center gap-2">
            <CheckCircle2Icon className="w-4 h-4 text-green-600" />
            <span className="text-gray-600">Completed</span>
          </div>
          <div className="flex items-center gap-2">
            <CircleIcon className="w-4 h-4 text-blue-600" />
            <span className="text-gray-600">In Progress</span>
          </div>
          <div className="flex items-center gap-2">
            <LockIcon className="w-4 h-4 text-gray-400" />
            <span className="text-gray-600">Locked</span>
          </div>
          <div className="flex items-center gap-2">
            <TrophyIcon className="w-4 h-4 text-yellow-600" />
            <span className="text-gray-600">Skill Proven</span>
          </div>
        </div>
      </div>
    </div>
  );
}

interface UnitCardProps {
  unit: LearningPathProgress;
  isExpanded: boolean;
  onToggle: () => void;
  onTrackInteraction?: (
    eventName: 'page_viewed' | 'feature_discovered' | 'help_accessed',
    metadata?: Record<string, any>
  ) => void;
  onSelectMission?: (missionId: string) => void;
  isFirst: boolean;
  isLast: boolean;
}

function UnitCard({
  unit,
  isExpanded,
  onToggle,
  onTrackInteraction,
  onSelectMission,
  isFirst: _isFirst,
  isLast
}: UnitCardProps) {
  const progress = unit.missionsTotal > 0 ? unit.missionsCompleted / unit.missionsTotal : 0;
  const isComplete = unit.missionsCompleted === unit.missionsTotal;

  return (
    <div className="relative">
      {/* Connection Line */}
      {!isLast && (
        <div className="absolute left-6 top-16 bottom-0 w-0.5 bg-gray-300 -mb-4"></div>
      )}

      {/* Unit Card */}
      <div
        className={`bg-white rounded-lg border-2 shadow-sm transition-all ${
          unit.isLocked
            ? 'border-gray-300 opacity-60'
            : isComplete
            ? 'border-green-300 shadow-green-100'
            : 'border-indigo-300 shadow-indigo-100'
        }`}
      >
        {/* Header - Always Visible */}
        <button
          onClick={onToggle}
          className="w-full p-4 flex items-center gap-4 hover:bg-gray-50 transition-colors rounded-lg"
          disabled={unit.isLocked}
        >
          {/* Status Icon */}
          <div
            className={`w-12 h-12 rounded-full flex items-center justify-center flex-shrink-0 ${
              unit.isLocked
                ? 'bg-gray-100'
                : isComplete
                ? 'bg-green-100'
                : 'bg-indigo-100'
            }`}
          >
            {unit.isLocked ? (
              <LockIcon className="w-6 h-6 text-gray-500" />
            ) : isComplete ? (
              <CheckCircle2Icon className="w-6 h-6 text-green-600" />
            ) : (
              <CircleIcon className="w-6 h-6 text-indigo-600 fill-indigo-600" />
            )}
          </div>

          {/* Unit Info */}
          <div className="flex-1 text-left">
            <h3 className="font-bold text-lg text-gray-900 mb-1">{unit.unitName}</h3>
            <div className="flex items-center gap-4 text-sm text-gray-600">
              <span>
                {unit.missionsCompleted}/{unit.missionsTotal} missions
              </span>
              <span>•</span>
              <span>{unit.microSkillsProven.length} skills proven</span>
            </div>

            {/* Progress Bar */}
            <div className="w-full bg-gray-200 rounded-full h-2 mt-2">
              <div
                className={`h-2 rounded-full transition-all duration-300 ${
                  isComplete ? 'bg-green-600' : 'bg-indigo-600'
                }`}
                style={{ width: `${Math.min(100, Math.max(0, progress * 100))}%` } as React.CSSProperties}
              ></div>
            </div>
          </div>

          {/* Expand Icon */}
          {!unit.isLocked && (
            <ArrowRightIcon
              className={`w-5 h-5 text-gray-400 transition-transform ${
                isExpanded ? 'rotate-90' : ''
              }`}
            />
          )}
        </button>

        {/* Expanded Content */}
        {isExpanded && !unit.isLocked && (
          <div className="px-4 pb-4 space-y-4 border-t border-gray-100">
            {/* Next Mission */}
            {unit.nextMission && (
              <div className="mt-4 bg-indigo-50 rounded-lg p-4 border border-indigo-200">
                <p className="text-sm font-medium text-indigo-900 mb-2">Next Up</p>
                <div className="flex items-center justify-between">
                  <div>
                    <p className="font-semibold text-gray-900">{unit.nextMission.title}</p>
                    <p className="text-sm text-gray-600 flex items-center gap-2 mt-1">
                      <span>{DIFFICULTY_EMOJI[unit.nextMission.difficultyLevel]}</span>
                      <span>{DIFFICULTY_LABELS[unit.nextMission.difficultyLevel]}</span>
                    </p>
                  </div>
                  <button
                    onClick={(e) => {
                      e.stopPropagation();
                      onTrackInteraction?.('feature_discovered', {
                        cta: 'learning_path_start_next_mission',
                        unitId: unit.unitId,
                        missionId: unit.nextMission!.id,
                      });
                      onSelectMission?.(unit.nextMission!.id);
                    }}
                    className="bg-indigo-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-indigo-700 transition-colors"
                  >
                    Start
                  </button>
                </div>
              </div>
            )}

            {/* Micro-Skills */}
            <div>
              <p className="text-sm font-medium text-gray-700 mb-2">Skills in this Unit</p>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-2">
                {unit.microSkillsProven.map(skillId => (
                  <div
                    key={skillId}
                    className="flex items-center gap-2 text-sm bg-green-50 text-green-700 px-3 py-2 rounded-lg"
                  >
                    <TrophyIcon className="w-4 h-4" />
                    <span className="font-medium">Skill {skillId}</span>
                  </div>
                ))}
                {unit.microSkillsInProgress.map(skillId => (
                  <div
                    key={skillId}
                    className="flex items-center gap-2 text-sm bg-blue-50 text-blue-700 px-3 py-2 rounded-lg"
                  >
                    <CircleIcon className="w-4 h-4" />
                    <span>Skill {skillId}</span>
                  </div>
                ))}
              </div>
            </div>
          </div>
        )}

        {/* Locked Message */}
        {unit.isLocked && (
          <div className="px-4 pb-4 pt-2 text-sm text-gray-500 italic">
            Complete previous units to unlock
          </div>
        )}
      </div>
    </div>
  );
}

/**
 * Compact version showing current unit only
 */
export function LearningPathCompact({
  learnerId,
  siteId
}: {
  learnerId: string;
  siteId: string;
}) {
  const [currentUnit, setCurrentUnit] = useState<LearningPathProgress | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    sdtMotivation.getLearningPath(learnerId, siteId)
      .then(path => {
        const current = path.find(u => u.missionsCompleted < u.missionsTotal) || path[path.length - 1];
        setCurrentUnit(current);
      })
      .catch(console.error)
      .finally(() => setLoading(false));
  }, [learnerId, siteId]);

  if (loading || !currentUnit) {
    return <div className="animate-pulse bg-gray-200 h-24 rounded-lg"></div>;
  }

  const progress = currentUnit.missionsTotal > 0 
    ? currentUnit.missionsCompleted / currentUnit.missionsTotal 
    : 0;

  return (
    <div className="bg-white rounded-lg border border-gray-200 p-4">
      <div className="flex items-center gap-2 mb-3">
        <MapIcon className="w-5 h-5 text-indigo-600" />
        <h3 className="font-semibold text-gray-900">Current Unit</h3>
      </div>
      
      <p className="font-medium text-gray-900 mb-2">{currentUnit.unitName}</p>
      
      <div className="w-full bg-gray-200 rounded-full h-2 mb-2">
        <div
          className="bg-indigo-600 h-2 rounded-full transition-all"
          style={{ width: `${Math.min(100, Math.max(0, progress * 100))}%` } as React.CSSProperties}
        ></div>
      </div>
      
      <div className="flex justify-between text-xs text-gray-600">
        <span>{currentUnit.missionsCompleted}/{currentUnit.missionsTotal} missions</span>
        <span>{currentUnit.microSkillsProven.length} skills</span>
      </div>
    </div>
  );
}
