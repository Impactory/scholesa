'use client';

import React, { useEffect, useState, useCallback } from 'react';
import { useAuthContext } from '@/src/firebase/auth/AuthProvider';
import { motivationEngine, MOTIVATION_EMOJI, ENGAGEMENT_COLORS, ENGAGEMENT_LABELS, ClassInsight } from '@/src/lib/motivation/motivationEngine';
import type { MotivationType } from '@/src/types/schema';
import { 
  AlertCircle, 
  ChevronRight, 
  Users, 
  Sparkles,
  Target,
  RefreshCw,
  User,
  TrendingUp,
  Award
} from 'lucide-react';

interface ClassInsightsProps {
  siteId: string;
  sessionOccurrenceId?: string;
  learnerIds?: string[];
  onSelectLearner?: (learnerId: string) => void;
}

export function ClassInsights({
  siteId,
  sessionOccurrenceId,
  learnerIds,
  onSelectLearner,
}: ClassInsightsProps) {
  const { user } = useAuthContext();
  const [insights, setInsights] = useState<ClassInsight[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [selectedView, setSelectedView] = useState<'all' | 'attention' | 'thriving'>('all');

  const fetchInsights = useCallback(async () => {
    if (!user) return;
    
    setLoading(true);
    setError(null);
    
    try {
      const data = await motivationEngine.getClassInsights(siteId, {
        sessionOccurrenceId,
        learnerIds,
      });
      setInsights(data);
    } catch (err: any) {
      console.error('Error fetching class insights:', err);
      setError(err.message || 'Failed to load insights');
    } finally {
      setLoading(false);
    }
  }, [user, siteId, sessionOccurrenceId, learnerIds]);

  useEffect(() => {
    fetchInsights();
  }, [fetchInsights]);

  const filteredInsights = insights.filter(insight => {
    if (selectedView === 'attention') return insight.needsAttention;
    if (selectedView === 'thriving') return insight.currentEngagement === 'thriving';
    return true;
  });

  const attentionCount = insights.filter(i => i.needsAttention).length;
  const thrivingCount = insights.filter(i => i.currentEngagement === 'thriving').length;

  if (loading) {
    return (
      <div className="bg-white rounded-xl border border-gray-200 p-6">
        <div className="animate-pulse space-y-4">
          <div className="h-6 bg-gray-200 rounded w-1/3" />
          <div className="grid grid-cols-3 gap-3">
            {[1, 2, 3].map(i => (
              <div key={i} className="h-20 bg-gray-100 rounded-lg" />
            ))}
          </div>
          <div className="space-y-3">
            {[1, 2, 3].map(i => (
              <div key={i} className="h-16 bg-gray-100 rounded-lg" />
            ))}
          </div>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="bg-red-50 border border-red-200 rounded-xl p-6 text-center">
        <AlertCircle className="w-8 h-8 text-red-500 mx-auto mb-2" />
        <p className="text-red-700">{error}</p>
        <button
          onClick={fetchInsights}
          className="mt-3 px-4 py-2 text-sm bg-red-100 text-red-700 rounded-lg hover:bg-red-200"
        >
          Try Again
        </button>
      </div>
    );
  }

  return (
    <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
      {/* Header */}
      <div className="px-6 py-4 border-b border-gray-100 flex items-center justify-between">
        <div>
          <h3 className="font-semibold text-gray-900 flex items-center gap-2">
            <Sparkles className="w-5 h-5 text-indigo-600" />
            Class Motivation Insights
          </h3>
          <p className="text-sm text-gray-500 mt-0.5">
            {insights.length} learner{insights.length !== 1 ? 's' : ''} analyzed
          </p>
        </div>
        <button
          onClick={fetchInsights}
          className="p-2 text-gray-400 hover:text-gray-600 hover:bg-gray-100 rounded-lg transition-colors"
          title="Refresh insights"
          aria-label="Refresh insights"
        >
          <RefreshCw className="w-5 h-5" />
        </button>
      </div>

      {/* Quick Stats */}
      <div className="px-6 py-4 bg-gray-50 border-b border-gray-100 grid grid-cols-3 gap-4">
        <div 
          className={`p-3 rounded-lg cursor-pointer transition-all ${
            selectedView === 'all' ? 'bg-indigo-100 ring-2 ring-indigo-500' : 'bg-white hover:bg-gray-100'
          }`}
          onClick={() => setSelectedView('all')}
        >
          <div className="flex items-center gap-2">
            <Users className="w-4 h-4 text-indigo-600" />
            <span className="text-sm font-medium text-gray-700">All</span>
          </div>
          <p className="text-2xl font-bold text-gray-900 mt-1">{insights.length}</p>
        </div>

        <div 
          className={`p-3 rounded-lg cursor-pointer transition-all ${
            selectedView === 'attention' ? 'bg-orange-100 ring-2 ring-orange-500' : 'bg-white hover:bg-gray-100'
          }`}
          onClick={() => setSelectedView('attention')}
        >
          <div className="flex items-center gap-2">
            <AlertCircle className="w-4 h-4 text-orange-600" />
            <span className="text-sm font-medium text-gray-700">Need Support</span>
          </div>
          <p className="text-2xl font-bold text-orange-600 mt-1">{attentionCount}</p>
        </div>

        <div 
          className={`p-3 rounded-lg cursor-pointer transition-all ${
            selectedView === 'thriving' ? 'bg-green-100 ring-2 ring-green-500' : 'bg-white hover:bg-gray-100'
          }`}
          onClick={() => setSelectedView('thriving')}
        >
          <div className="flex items-center gap-2">
            <Award className="w-4 h-4 text-green-600" />
            <span className="text-sm font-medium text-gray-700">Thriving</span>
          </div>
          <p className="text-2xl font-bold text-green-600 mt-1">{thrivingCount}</p>
        </div>
      </div>

      {/* Learner List */}
      <div className="divide-y divide-gray-100 max-h-96 overflow-y-auto">
        {filteredInsights.length === 0 ? (
          <div className="px-6 py-8 text-center text-gray-500">
            <Target className="w-8 h-8 mx-auto mb-2 text-gray-300" />
            <p>No learners match this filter</p>
          </div>
        ) : (
          filteredInsights.map((insight) => (
            <LearnerInsightRow
              key={insight.learnerId}
              insight={insight}
              onClick={() => onSelectLearner?.(insight.learnerId)}
            />
          ))
        )}
      </div>
    </div>
  );
}

// Individual learner row in insights
function LearnerInsightRow({
  insight,
  onClick,
}: {
  insight: ClassInsight;
  onClick?: () => void;
}) {
  const engagementColor = ENGAGEMENT_COLORS[insight.currentEngagement];
  const engagementLabel = ENGAGEMENT_LABELS[insight.currentEngagement];

  return (
    <div 
      className={`px-6 py-4 hover:bg-gray-50 transition-colors ${onClick ? 'cursor-pointer' : ''}`}
      onClick={onClick}
    >
      <div className="flex items-center gap-4">
        {/* Avatar placeholder */}
        <div className="w-10 h-10 rounded-full bg-indigo-100 flex items-center justify-center">
          <User className="w-5 h-5 text-indigo-600" />
        </div>

        {/* Main content */}
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2 mb-1">
            <span className="font-medium text-gray-900 truncate">
              Learner {insight.learnerId.slice(-6)}
            </span>
            {insight.needsAttention && (
              <span className="px-2 py-0.5 bg-orange-100 text-orange-700 text-xs font-medium rounded-full">
                Needs attention
              </span>
            )}
          </div>

          {/* Engagement badge */}
          <div className="flex items-center gap-3 text-sm">
            <span className={`px-2 py-0.5 rounded-full ${engagementColor.bg} ${engagementColor.text} text-xs font-medium`}>
              {engagementLabel}
            </span>

            {/* Motivators */}
            {insight.primaryMotivators.length > 0 && (
              <span className="text-gray-500 flex items-center gap-1">
                <TrendingUp className="w-3 h-3" />
                {insight.primaryMotivators.slice(0, 2).map((m) => (
                  <span key={m} title={m}>
                    {MOTIVATION_EMOJI[m as MotivationType]}
                  </span>
                ))}
              </span>
            )}
          </div>
        </div>

        {/* Highlights */}
        {insight.recentHighlights && insight.recentHighlights.length > 0 && (
          <div className="hidden sm:block max-w-48">
            <p className="text-xs text-gray-500 truncate" title={insight.recentHighlights[0]}>
              ✨ {insight.recentHighlights[0]}
            </p>
          </div>
        )}

        {/* Action arrow */}
        {onClick && (
          <ChevronRight className="w-5 h-5 text-gray-400" />
        )}
      </div>

      {/* Suggested strategies */}
      {insight.suggestedStrategies.length > 0 && (
        <div className="mt-3 ml-14">
          <p className="text-xs text-gray-500 mb-1">Try today:</p>
          <div className="flex flex-wrap gap-1">
            {insight.suggestedStrategies.map((s, i) => (
              <span
                key={i}
                className="inline-flex items-center gap-1 px-2 py-0.5 bg-indigo-50 text-indigo-700 text-xs rounded-full"
              >
                {MOTIVATION_EMOJI[s.type as MotivationType]} {s.strategy}
              </span>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}

// Compact version for sidebar/quick view
export function ClassInsightsCompact({
  siteId,
  onViewFull,
}: {
  siteId: string;
  onViewFull?: () => void;
}) {
  const [insights, setInsights] = useState<ClassInsight[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchInsights = async () => {
      try {
        const data = await motivationEngine.getClassInsights(siteId);
        setInsights(data);
      } catch (error) {
        console.error('Error fetching insights:', error);
      } finally {
        setLoading(false);
      }
    };

    fetchInsights();
  }, [siteId]);

  const needsAttention = insights.filter(i => i.needsAttention);

  if (loading) {
    return (
      <div className="animate-pulse p-4 bg-gray-50 rounded-lg">
        <div className="h-4 bg-gray-200 rounded w-3/4 mb-2" />
        <div className="h-3 bg-gray-200 rounded w-1/2" />
      </div>
    );
  }

  if (needsAttention.length === 0) {
    return (
      <div className="p-4 bg-green-50 rounded-lg border border-green-100">
        <div className="flex items-center gap-2">
          <Award className="w-5 h-5 text-green-600" />
          <span className="font-medium text-green-800">All learners engaged!</span>
        </div>
        <p className="text-sm text-green-600 mt-1">
          {insights.filter(i => i.currentEngagement === 'thriving').length} learners thriving today
        </p>
      </div>
    );
  }

  return (
    <div className="p-4 bg-orange-50 rounded-lg border border-orange-100">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <AlertCircle className="w-5 h-5 text-orange-600" />
          <span className="font-medium text-orange-800">
            {needsAttention.length} need support
          </span>
        </div>
        {onViewFull && (
          <button
            onClick={onViewFull}
            className="text-sm text-orange-700 hover:text-orange-900 font-medium"
          >
            View all →
          </button>
        )}
      </div>
      <div className="mt-2 space-y-1">
        {needsAttention.slice(0, 3).map(insight => (
          <div key={insight.learnerId} className="text-sm text-orange-700 flex items-center gap-2">
            <span className="w-1.5 h-1.5 bg-orange-500 rounded-full" />
            <span>Check in with learner {insight.learnerId.slice(-6)}</span>
            {insight.primaryMotivators[0] && (
              <span title={`Try ${insight.primaryMotivators[0]} approach`}>
                {MOTIVATION_EMOJI[insight.primaryMotivators[0] as MotivationType]}
              </span>
            )}
          </div>
        ))}
      </div>
    </div>
  );
}
