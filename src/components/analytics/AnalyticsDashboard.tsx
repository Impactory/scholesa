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
            onClick={() => setTimeRange('week')}
            className={`px-4 py-2 text-sm font-medium rounded-l-md ${
              timeRange === 'week'
                ? 'bg-indigo-600 text-white'
                : 'bg-white text-gray-700 hover:bg-gray-50 border border-gray-300'
            }`}
          >
            This Week
          </button>
          <button
            onClick={() => setTimeRange('month')}
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
      
      {/* Weekly Trends Chart */}
      <div className="bg-white rounded-lg border border-gray-200 shadow-sm p-6">
        <h3 className="text-lg font-semibold text-gray-900 mb-4">
          {timeRange === 'week' ? 'Weekly' : 'Monthly'} Engagement Trends
        </h3>
        {weeklyData.length > 0 ? (
          <WeeklyTrendsChart data={weeklyData} />
        ) : (
          <div className="h-64 flex items-center justify-center text-gray-400 border-2 border-dashed border-gray-200 rounded-lg">
            No trend data available yet. Data will appear after learners complete activities.
          </div>
        )}
      </div>
      
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

function formatRelativeTime(date: Date): string {
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

// ==================== WEEKLY TRENDS CHART ====================

interface WeeklyTrendsChartProps {
  data: WeeklyDataPoint[];
}

function WeeklyTrendsChart({ data }: WeeklyTrendsChartProps) {
  if (data.length === 0) return null;
  
  const maxValue = Math.max(
    ...data.map(d => Math.max(d.avgEngagement, d.avgAutonomy, d.avgCompetence, d.avgBelonging))
  );
  const chartHeight = 256; // 64 * 4 = h-64
  const chartWidth = data.length * 60; // 60px per data point
  
  // Calculate Y-axis scale
  const yScale = (value: number) => {
    return chartHeight - (value / 100) * chartHeight;
  };
  
  // Generate SVG path for a line
  const generatePath = (dataKey: keyof WeeklyDataPoint) => {
    return data.map((point, index) => {
      const x = index * 60 + 30; // Center of each segment
      const y = yScale(point[dataKey] as number);
      return `${index === 0 ? 'M' : 'L'} ${x} ${y}`;
    }).join(' ');
  };
  
  return (
    <div className="space-y-4">
      {/* Legend */}
      <div className="flex flex-wrap gap-4 text-sm">
        <div className="flex items-center gap-2">
          <div className="w-4 h-4 rounded-full bg-green-500" />
          <span>Overall Engagement</span>
        </div>
        <div className="flex items-center gap-2">
          <div className="w-4 h-4 rounded-full bg-purple-500" />
          <span>Autonomy</span>
        </div>
        <div className="flex items-center gap-2">
          <div className="w-4 h-4 rounded-full bg-blue-500" />
          <span>Competence</span>
        </div>
        <div className="flex items-center gap-2">
          <div className="w-4 h-4 rounded-full bg-pink-500" />
          <span>Belonging</span>
        </div>
      </div>
      
      {/* Chart */}
      <div className="overflow-x-auto">
        <svg width={Math.max(chartWidth, 800)} height={chartHeight + 40} className="border border-gray-200 rounded-lg bg-gray-50">
          {/* Grid lines */}
          {[0, 25, 50, 75, 100].map(value => (
            <g key={value}>
              <line
                x1={0}
                y1={yScale(value)}
                x2={chartWidth}
                y2={yScale(value)}
                stroke="#e5e7eb"
                strokeWidth={1}
                strokeDasharray="4 4"
              />
              <text
                x={5}
                y={yScale(value) - 5}
                fontSize={12}
                fill="#6b7280"
              >
                {value}%
              </text>
            </g>
          ))}
          
          {/* Overall Engagement Line */}
          <path
            d={generatePath('avgEngagement')}
            fill="none"
            stroke="#10b981"
            strokeWidth={2}
            strokeLinecap="round"
            strokeLinejoin="round"
          />
          
          {/* Autonomy Line */}
          <path
            d={generatePath('avgAutonomy')}
            fill="none"
            stroke="#8b5cf6"
            strokeWidth={2}
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeDasharray="5 5"
          />
          
          {/* Competence Line */}
          <path
            d={generatePath('avgCompetence')}
            fill="none"
            stroke="#3b82f6"
            strokeWidth={2}
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeDasharray="5 5"
          />
          
          {/* Belonging Line */}
          <path
            d={generatePath('avgBelonging')}
            fill="none"
            stroke="#ec4899"
            strokeWidth={2}
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeDasharray="5 5"
          />
          
          {/* Data points */}
          {data.map((point, index) => {
            const x = index * 60 + 30;
            return (
              <g key={index}>
                <circle cx={x} cy={yScale(point.avgEngagement)} r={4} fill="#10b981" />
                <circle cx={x} cy={yScale(point.avgAutonomy)} r={3} fill="#8b5cf6" />
                <circle cx={x} cy={yScale(point.avgCompetence)} r={3} fill="#3b82f6" />
                <circle cx={x} cy={yScale(point.avgBelonging)} r={3} fill="#ec4899" />
              </g>
            );
          })}
          
          {/* X-axis labels */}
          {data.map((point, index) => {
            const x = index * 60 + 30;
            return (
              <text
                key={index}
                x={x}
                y={chartHeight + 20}
                fontSize={10}
                fill="#6b7280"
                textAnchor="middle"
              >
                {point.date}
              </text>
            );
          })}
        </svg>
      </div>
    </div>
  );
}

