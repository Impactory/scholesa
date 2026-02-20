'use client';

/**
 * Educator Analytics Dashboard
 * 
 * Shows:
 * - Class engagement overview
 * - SDT profile heatmap (autonomy/competence/belonging per student)
 * - At-risk student alerts
 * - Weekly trends
 */

import React, { useState } from 'react';
import { useAuthContext } from '@/src/firebase/auth/AuthProvider';
import { useLearnerAnalytics } from '@/src/hooks/useRealtimeAnalytics';
import { useInteractionTracking } from '@/src/hooks/useTelemetry';
import { AIInsightsPanel } from './AIInsightsPanel';
import { 
  TrendingUpIcon, 
  TrendingDownIcon, 
  AlertTriangleIcon,
  UsersIcon,
  ActivityIcon,
  AwardIcon,
  HeartIcon,
  BrainIcon,
  DownloadIcon
} from 'lucide-react';

interface LearnerEngagement {
  learnerId: string;
  learnerName: string;
  engagementScore: number; // 0-100
  autonomyScore: number; // 0-100
  competenceScore: number; // 0-100
  belongingScore: number; // 0-100
  lastActive: Date | null;
  eventCount: number;
}

export function AnalyticsDashboard() {
  const { profile } = useAuthContext();
  const [timeRange, setTimeRange] = useState<'week' | 'month'>('week');
  const trackInteraction = useInteractionTracking();
  
  const siteId = profile?.activeSiteId || profile?.siteIds?.[0] || '';
  
  // Use real-time hook for live data updates
  const { learners: realtimeLearners, loading, error } = useLearnerAnalytics({ 
    siteId, 
    timeRange,
    limit: 100 
  });
  
  // Transform real-time data to match LearnerEngagement interface
  const learners: LearnerEngagement[] = realtimeLearners.map(s => ({
    learnerId: s.userId,
    learnerName: s.name,
    engagementScore: s.engagementScore,
    autonomyScore: s.autonomyScore,
    competenceScore: s.competenceScore,
    belongingScore: s.belongingScore,
    lastActive: s.lastActive,
    eventCount: 0 // Can be enhanced later
  }));
  
  if (loading) {
    return (
      <div className="space-y-4 animate-pulse">
        <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
          {[1,2,3,4].map(i => (
            <div key={i} className="h-32 bg-gray-200 rounded-lg" />
          ))}
        </div>
        <div className="h-96 bg-gray-200 rounded-lg" />
      </div>
    );
  }
  
  if (error) {
    return (
      <div className="bg-red-50 border border-red-200 rounded-lg p-8 text-center">
        <AlertTriangleIcon className="h-12 w-12 text-red-500 mx-auto mb-4" />
        <p className="text-red-700">Failed to load analytics. Please try again.</p>
      </div>
    );
  }
  
  const avgEngagement = learners.reduce((sum, s) => sum + s.engagementScore, 0) / learners.length || 0;
  const atRiskCount = learners.filter(s => s.engagementScore < 60).length;
  const highPerformers = learners.filter(s => s.engagementScore >= 80).length;
  
  const handleExportCSV = () => {
    trackInteraction('help_accessed', { cta: 'analytics_export_csv', timeRange, siteId });
    if (learners.length === 0) return;
    
    // Prepare CSV headers
    const headers = ['Learner Name', 'Engagement %', 'Autonomy %', 'Competence %', 'Belonging %', 'Events', 'Last Active'];
    
    // Prepare CSV rows
    const rows = learners.map(s => [
      s.learnerName,
      s.engagementScore.toString(),
      s.autonomyScore.toString(),
      s.competenceScore.toString(),
      s.belongingScore.toString(),
      s.eventCount.toString(),
      s.lastActive ? s.lastActive.toLocaleDateString() : 'Never'
    ]);
    
    // Combine headers and rows
    const csvContent = [
      headers.join(','),
      ...rows.map(row => row.join(','))
    ].join('\n');
    
    // Create download link
    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `scholesa-analytics-${siteId}-${new Date().toISOString().split('T')[0]}.csv`;
    link.click();
    URL.revokeObjectURL(url);
  };
  
  return (
    <div className="space-y-6">
      {/* Time Range Selector + Export */}
      <div className="flex justify-between items-center">
        <div className="inline-flex rounded-md shadow-sm">
          <button
            onClick={() => {
              trackInteraction('feature_discovered', { cta: 'analytics_time_range_week' });
              setTimeRange('week');
            }}
            className={`px-4 py-2 text-sm font-medium rounded-l-md ${
              timeRange === 'week'
                ? 'bg-indigo-600 text-white'
                : 'bg-white text-gray-700 hover:bg-gray-50 border border-gray-300'
            }`}
          >
            This Week
          </button>
          <button
            onClick={() => {
              trackInteraction('feature_discovered', { cta: 'analytics_time_range_month' });
              setTimeRange('month');
            }}
            className={`px-4 py-2 text-sm font-medium rounded-r-md ${
              timeRange === 'month'
                ? 'bg-indigo-600 text-white'
                : 'bg-white text-gray-700 hover:bg-gray-50 border border-gray-300 border-l-0'
            }`}
          >
            This Month
          </button>
        </div>
        
        <button
          onClick={handleExportCSV}
          disabled={learners.length === 0}
          className="inline-flex items-center gap-2 px-4 py-2 text-sm font-medium text-white bg-green-600 rounded-md hover:bg-green-700 disabled:opacity-50 disabled:cursor-not-allowed"
        >
          <DownloadIcon className="h-4 w-4" />
          Export CSV
        </button>
      </div>
      
      {/* Summary Cards */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <SummaryCard
          title="Total Learners"
          value={learners.length}
          icon={UsersIcon}
          color="blue"
        />
        <SummaryCard
          title="Avg Engagement"
          value={`${Math.round(avgEngagement)}%`}
          icon={ActivityIcon}
          color="green"
          trend={avgEngagement > 70 ? 'up' : 'down'}
        />
        <SummaryCard
          title="High Performers"
          value={highPerformers}
          icon={AwardIcon}
          color="purple"
        />
        <SummaryCard
          title="At Risk"
          value={atRiskCount}
          icon={AlertTriangleIcon}
          color="red"
          trend={atRiskCount > 0 ? 'down' : undefined}
        />
      </div>
      
      {/* At-Risk Students Alert */}
      {atRiskCount > 0 && (
        <div className="rounded-lg bg-amber-50 border border-amber-200 p-4">
          <div className="flex items-start">
            <AlertTriangleIcon className="h-5 w-5 text-amber-600 mt-0.5 mr-3" />
            <div>
              <h3 className="text-sm font-medium text-amber-800">
                {atRiskCount} learner{atRiskCount > 1 ? 's' : ''} may need support
              </h3>
              <p className="mt-1 text-sm text-amber-700">
                Students with engagement below 60% haven't been active recently or are showing low participation.
              </p>
            </div>
          </div>
        </div>
      )}
      
      {/* Student SDT Heatmap */}
      <div className="bg-white rounded-lg border border-gray-200 shadow-sm overflow-hidden">
        <div className="px-6 py-4 border-b border-gray-200">
          <h2 className="text-lg font-semibold text-gray-900">Student Motivation Profiles (SDT)</h2>
          <p className="text-sm text-gray-600 mt-1">Self-Determination Theory metrics by student</p>
        </div>
        
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Student
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  <div className="flex items-center gap-1">
                    <BrainIcon className="h-4 w-4" />
                    Autonomy
                  </div>
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  <div className="flex items-center gap-1">
                    <AwardIcon className="h-4 w-4" />
                    Competence
                  </div>
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  <div className="flex items-center gap-1">
                    <HeartIcon className="h-4 w-4" />
                    Belonging
                  </div>
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Engagement
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Last Active
                </th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {learners.map(learner => (
                <tr key={learner.learnerId} className="hover:bg-gray-50">
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="text-sm font-medium text-gray-900">{learner.learnerName}</div>
                    <div className="text-sm text-gray-500">{learner.eventCount} events</div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <ScoreBar score={learner.autonomyScore} color="purple" />
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <ScoreBar score={learner.competenceScore} color="blue" />
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <ScoreBar score={learner.belongingScore} color="pink" />
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <ScoreBar score={learner.engagementScore} color="green" />
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    {formatRelativeTime(learner.lastActive)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
      
      {/* Weekly Trends Chart - TODO: Add trend data generation */}
      {/* <div className="bg-white rounded-lg border border-gray-200 shadow-sm p-6">
        <h3 className="text-lg font-semibold text-gray-900 mb-4">
          {timeRange === 'week' ? 'Weekly' : 'Monthly'} Engagement Trends
        </h3>
        <div className="h-64 flex items-center justify-center text-gray-400 border-2 border-dashed border-gray-200 rounded-lg">
          Trend chart coming soon
        </div>
      </div> */}
      
      {/* AI Insights Panel */}
      <AIInsightsPanel learners={learners} timeRange={timeRange} />
    </div>
  );
}

// ==================== HELPER COMPONENTS ====================

interface SummaryCardProps {
  title: string;
  value: string | number;
  icon: React.ComponentType<{ className?: string }>;
  color: 'blue' | 'green' | 'purple' | 'red';
  trend?: 'up' | 'down';
}

function SummaryCard({ title, value, icon: Icon, color, trend }: SummaryCardProps) {
  const colorClasses = {
    blue: 'bg-blue-100 text-blue-800',
    green: 'bg-green-100 text-green-800',
    purple: 'bg-purple-100 text-purple-800',
    red: 'bg-red-100 text-red-800'
  };
  
  return (
    <div className="bg-white rounded-lg border border-gray-200 shadow-sm p-6">
      <div className="flex items-center justify-between">
        <div>
          <p className="text-sm font-medium text-gray-600">{title}</p>
          <p className="mt-2 text-3xl font-semibold text-gray-900">{value}</p>
        </div>
        <div className={`rounded-full p-3 ${colorClasses[color]}`}>
          <Icon className="h-6 w-6" />
        </div>
      </div>
      {trend && (
        <div className="mt-4 flex items-center text-sm">
          {trend === 'up' ? (
            <TrendingUpIcon className="h-4 w-4 text-green-600 mr-1" />
          ) : (
            <TrendingDownIcon className="h-4 w-4 text-red-600 mr-1" />
          )}
          <span className={trend === 'up' ? 'text-green-600' : 'text-red-600'}>
            vs last {title.includes('Week') ? 'week' : 'month'}
          </span>
        </div>
      )}
    </div>
  );
}

interface ScoreBarProps {
  score: number; // 0-100
  color: 'purple' | 'blue' | 'pink' | 'green';
}

function ScoreBar({ score, color }: ScoreBarProps) {
  const colorClasses = {
    purple: 'bg-purple-600',
    blue: 'bg-blue-600',
    pink: 'bg-pink-600',
    green: 'bg-green-600'
  };
  
  const bgColorClasses = {
    purple: 'bg-purple-100',
    blue: 'bg-blue-100',
    pink: 'bg-pink-100',
    green: 'bg-green-100'
  };
  
  return (
    <div className="flex items-center gap-2">
      <div className={`w-24 h-2 rounded-full ${bgColorClasses[color]}`}>
        <div 
          className={`h-full rounded-full ${colorClasses[color]}`}
          data-score={score}
          aria-label={`Score: ${score}%`}
        >
          <style jsx>{`
            div[data-score="${score}"] {
              width: ${score}%;
            }
          `}</style>
        </div>
      </div>
      <span className="text-sm font-medium text-gray-700">{score}%</span>
    </div>
  );
}

function formatRelativeTime(date: Date | null): string {
  if (!date) return 'Never';
  
  const now = new Date();
  const diffMs = now.getTime() - date.getTime();
  const diffMins = Math.floor(diffMs / 60000);
  const diffHours = Math.floor(diffMs / 3600000);
  const diffDays = Math.floor(diffMs / 86400000);
  
  if (diffMins < 1) return 'Just now';
  if (diffMins < 60) return `${diffMins}m ago`;
  if (diffHours < 24) return `${diffHours}h ago`;
  if (diffDays < 7) return `${diffDays}d ago`;
  
  return date.toLocaleDateString();
}

