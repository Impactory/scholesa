'use client';

/**
 * Student Home Dashboard
 * 
 * Level 1: Must-have for flow and retention
 * Shows: Today's mission, streak, next checkpoint, quick resume
 */

import React, { useEffect, useState } from 'react';
import { 
  PlayIcon, 
  TrophyIcon, 
  FlameIcon, 
  CheckCircle2Icon,
  ArrowRightIcon,
  BellIcon,
  BookOpenIcon
} from 'lucide-react';
import { sdtMotivation, type DashboardData, DIFFICULTY_EMOJI, DIFFICULTY_LABELS } from '@/src/lib/motivation/sdtMotivation';
import { usePageViewTracking } from '@/src/hooks/useTelemetry';

interface StudentDashboardProps {
  learnerId: string;
  siteId: string;
  onStartMission?: () => void;
  onResumeWork?: () => void;
  onViewFeedback?: () => void;
}

export function StudentDashboard({
  learnerId,
  siteId,
  onStartMission,
  onResumeWork,
  onViewFeedback
}: StudentDashboardProps) {
  const [data, setData] = useState<DashboardData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Track page view
  usePageViewTracking('student_dashboard', { learnerId, siteId });

  useEffect(() => {
    const fetchDashboard = async () => {
      try {
        setLoading(true);
        const dashboardData = await sdtMotivation.getDashboardData(learnerId, siteId);
        setData(dashboardData);
      } catch (err) {
        console.error('Error fetching dashboard:', err);
        setError('Failed to load dashboard');
      } finally {
        setLoading(false);
      }
    };

    fetchDashboard();
  }, [learnerId, siteId]);

  if (loading) {
    return (
      <div className="space-y-4 animate-pulse">
        <div className="h-48 bg-gray-200 rounded-lg"></div>
        <div className="grid grid-cols-3 gap-4">
          <div className="h-24 bg-gray-200 rounded-lg"></div>
          <div className="h-24 bg-gray-200 rounded-lg"></div>
          <div className="h-24 bg-gray-200 rounded-lg"></div>
        </div>
      </div>
    );
  }

  if (error || !data) {
    return (
      <div className="bg-red-50 border border-red-200 rounded-lg p-4">
        <p className="text-red-800">{error || 'No data available'}</p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Hero Card - Today's Mission */}
      <div className="bg-gradient-to-br from-indigo-500 to-purple-600 rounded-lg p-6 text-white shadow-lg">
        {data.todaysMission ? (
          <>
            <div className="flex items-start justify-between mb-4">
              <div>
                <p className="text-indigo-100 text-sm font-medium mb-1">Today's Mission</p>
                <h2 className="text-2xl font-bold mb-2">{data.todaysMission.title}</h2>
                <div className="inline-flex items-center gap-2 bg-white/20 backdrop-blur-sm px-3 py-1 rounded-full text-sm">
                  <span>{DIFFICULTY_EMOJI[data.todaysMission.difficultyLevel]}</span>
                  <span>{DIFFICULTY_LABELS[data.todaysMission.difficultyLevel]}</span>
                </div>
              </div>
              <TrophyIcon className="w-12 h-12 text-yellow-300" />
            </div>

            {/* Progress Bar */}
            {data.todaysMission.progress > 0 && (
              <div className="mb-4">
                <div className="flex justify-between text-sm mb-1">
                  <span>Progress</span>
                  <span>{Math.round(data.todaysMission.progress * 100)}%</span>
                </div>
                <div className="w-full bg-white/20 rounded-full h-2">
                  <div
                    className="bg-white h-2 rounded-full transition-all duration-300"
                    style={{ width: `${Math.min(100, Math.max(0, data.todaysMission.progress * 100))}%` } as React.CSSProperties}
                  ></div>
                </div>
              </div>
            )}

            {/* Action Buttons */}
            <div className="flex gap-3">
              {data.quickResumeAvailable ? (
                <button
                  onClick={onResumeWork}
                  className="flex-1 bg-white text-indigo-600 px-4 py-3 rounded-lg font-medium hover:bg-indigo-50 transition-colors flex items-center justify-center gap-2"
                >
                  <PlayIcon className="w-5 h-5" />
                  Continue Working
                </button>
              ) : (
                <button
                  onClick={onStartMission}
                  className="flex-1 bg-white text-indigo-600 px-4 py-3 rounded-lg font-medium hover:bg-indigo-50 transition-colors flex items-center justify-center gap-2"
                >
                  <PlayIcon className="w-5 h-5" />
                  {data.todaysMission.progress > 0 ? 'Resume Mission' : 'Start Mission'}
                </button>
              )}
            </div>
          </>
        ) : (
          <>
            <div className="text-center py-8">
              <BookOpenIcon className="w-16 h-16 mx-auto mb-4 text-white/80" />
              <h2 className="text-2xl font-bold mb-2">Ready to Learn?</h2>
              <p className="text-indigo-100 mb-4">Pick your next mission and start building!</p>
              <button
                onClick={onStartMission}
                className="bg-white text-indigo-600 px-6 py-3 rounded-lg font-medium hover:bg-indigo-50 transition-colors inline-flex items-center gap-2"
              >
                Choose Mission
                <ArrowRightIcon className="w-5 h-5" />
              </button>
            </div>
          </>
        )}
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        {/* Streak Card */}
        <div className="bg-white rounded-lg border border-gray-200 p-4 shadow-sm">
          <div className="flex items-center gap-3 mb-2">
            <div className="p-2 bg-orange-100 rounded-lg">
              <FlameIcon className="w-6 h-6 text-orange-600" />
            </div>
            <div>
              <p className="text-sm text-gray-600">Current Streak</p>
              <p className="text-2xl font-bold text-gray-900">{data.streak.current} days</p>
            </div>
          </div>
          <div className="flex justify-between text-xs text-gray-500 pt-2 border-t">
            <span>Attendance: {data.streak.attendanceStreak}</span>
            <span>Effort: {data.streak.effortStreak}</span>
          </div>
          {data.streak.best > data.streak.current && (
            <p className="text-xs text-gray-500 mt-1">Best: {data.streak.best} days</p>
          )}
        </div>

        {/* Next Checkpoint */}
        {data.nextCheckpoint && (
          <div className="bg-white rounded-lg border border-gray-200 p-4 shadow-sm">
            <div className="flex items-center gap-3 mb-2">
              <div className="p-2 bg-green-100 rounded-lg">
                <CheckCircle2Icon className="w-6 h-6 text-green-600" />
              </div>
              <div>
                <p className="text-sm text-gray-600">Next Checkpoint</p>
                <p className="text-lg font-bold text-gray-900">Checkpoint {data.nextCheckpoint.checkpointNumber}</p>
              </div>
            </div>
            <p className="text-xs text-gray-500">
              Due: {new Date(data.nextCheckpoint.dueAt).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
            </p>
          </div>
        )}

        {/* Notifications */}
        <div className="bg-white rounded-lg border border-gray-200 p-4 shadow-sm">
          <div className="flex items-center gap-3 mb-2">
            <div className="p-2 bg-blue-100 rounded-lg">
              <BellIcon className="w-6 h-6 text-blue-600" />
            </div>
            <div>
              <p className="text-sm text-gray-600">Notifications</p>
              <div className="flex gap-3 mt-1">
                {data.unreadFeedback > 0 && (
                  <button
                    onClick={onViewFeedback}
                    className="text-xs bg-blue-100 text-blue-700 px-2 py-1 rounded-full hover:bg-blue-200"
                  >
                    {data.unreadFeedback} new feedback
                  </button>
                )}
                {data.pendingReflections > 0 && (
                  <span className="text-xs bg-purple-100 text-purple-700 px-2 py-1 rounded-full">
                    {data.pendingReflections} reflections due
                  </span>
                )}
                {data.unreadFeedback === 0 && data.pendingReflections === 0 && (
                  <p className="text-xs text-gray-500">All caught up! 🎉</p>
                )}
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Motivational Quote/Tip */}
      <div className="bg-gradient-to-r from-pink-50 to-purple-50 border border-purple-200 rounded-lg p-4">
        <p className="text-sm text-purple-900 font-medium">💡 Remember: Mistakes are data! Every attempt teaches you something new.</p>
      </div>
    </div>
  );
}

/**
 * Compact version for mobile/sidebar
 */
export function StudentDashboardCompact({
  learnerId,
  siteId,
  onNavigate
}: {
  learnerId: string;
  siteId: string;
  onNavigate?: (view: string) => void;
}) {
  const [data, setData] = useState<DashboardData | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    sdtMotivation.getDashboardData(learnerId, siteId)
      .then(setData)
      .catch(console.error)
      .finally(() => setLoading(false));
  }, [learnerId, siteId]);

  if (loading) {
    return <div className="animate-pulse bg-gray-200 h-32 rounded-lg"></div>;
  }

  if (!data) return null;

  return (
    <div className="bg-white rounded-lg border border-gray-200 p-4 space-y-3">
      <div className="flex items-center justify-between">
        <h3 className="font-semibold text-gray-900">Today</h3>
        <FlameIcon className="w-5 h-5 text-orange-500" />
      </div>
      
      {data.todaysMission && (
        <div className="text-sm">
          <p className="text-gray-600 mb-1">Current Mission</p>
          <p className="font-medium text-gray-900 truncate">{data.todaysMission.title}</p>
          <div className="w-full bg-gray-200 rounded-full h-1.5 mt-2">
            <div
              className="bg-indigo-600 h-1.5 rounded-full"
              style={{ width: `${Math.min(100, Math.max(0, data.todaysMission.progress * 100))}%` } as React.CSSProperties}
            ></div>
          </div>
        </div>
      )}
      
      <div className="flex gap-2 text-xs">
        <div className="flex-1 bg-gray-50 rounded p-2 text-center">
          <p className="text-gray-600">Streak</p>
          <p className="font-bold text-gray-900">{data.streak.current}</p>
        </div>
        {data.unreadFeedback > 0 && (
          <div className="flex-1 bg-blue-50 rounded p-2 text-center">
            <p className="text-blue-600">Feedback</p>
            <p className="font-bold text-blue-900">{data.unreadFeedback}</p>
          </div>
        )}
      </div>
      
      {data.todaysMission && (
        <button
          onClick={() => onNavigate?.('mission')}
          className="w-full bg-indigo-600 text-white px-3 py-2 rounded-lg text-sm font-medium hover:bg-indigo-700 transition-colors flex items-center justify-center gap-2"
        >
          <PlayIcon className="w-4 h-4" />
          Continue
        </button>
      )}
    </div>
  );
}
