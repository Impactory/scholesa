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
import { useI18n } from '@/src/lib/i18n/useI18n';
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
  engagementScore: number | null;
  autonomyScore: number | null;
  competenceScore: number | null;
  belongingScore: number | null;
  lastActive: Date | null;
  eventCount: number;
}

export function AnalyticsDashboard() {
  const { profile } = useAuthContext();
  const { locale, t } = useI18n();
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

  const learnersWithEngagement = learners.filter((learner) => learner.engagementScore != null);
  
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
        <p className="text-red-700">{t('analytics.educator.loadError')}</p>
      </div>
    );
  }
  
  const avgEngagement = learnersWithEngagement.length > 0
    ? learnersWithEngagement.reduce((sum, learner) => sum + (learner.engagementScore as number), 0) / learnersWithEngagement.length
    : null;
  const atRiskCount = learners.filter(s => s.engagementScore != null && s.engagementScore < 60).length;
  const highPerformers = learners.filter(s => s.engagementScore != null && s.engagementScore >= 80).length;
  const periodLabel = timeRange === 'week'
    ? t('analytics.educator.period.week')
    : t('analytics.educator.period.month');
  const trendPoints = buildTrendPoints(learners, timeRange, locale);
  const trendMax = Math.max(100, ...trendPoints.map((point) => point.value));
  
  const handleExportCSV = () => {
    trackInteraction('help_accessed', { cta: 'analytics_export_csv', timeRange, siteId });
    if (learners.length === 0) return;
    
    // Prepare CSV headers
    const headers = [
      t('analytics.educator.csvHeaders.learnerName'),
      t('analytics.educator.csvHeaders.engagement'),
      t('analytics.educator.csvHeaders.autonomy'),
      t('analytics.educator.csvHeaders.competence'),
      t('analytics.educator.csvHeaders.belonging'),
      t('analytics.educator.csvHeaders.events'),
      t('analytics.educator.csvHeaders.lastActive'),
    ];
    
    // Prepare CSV rows
    const rows = learners.map(s => [
      s.learnerName,
      s.engagementScore.toString(),
      s.autonomyScore.toString(),
      s.competenceScore.toString(),
      s.belongingScore.toString(),
      s.eventCount.toString(),
      s.lastActive ? s.lastActive.toLocaleDateString(locale) : t('analytics.educator.never')
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
            {t('analytics.educator.thisWeek')}
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
            {t('analytics.educator.thisMonth')}
          </button>
        </div>
        
        <button
          onClick={handleExportCSV}
          disabled={learners.length === 0}
          className="inline-flex items-center gap-2 px-4 py-2 text-sm font-medium text-white bg-green-600 rounded-md hover:bg-green-700 disabled:opacity-50 disabled:cursor-not-allowed"
        >
          <DownloadIcon className="h-4 w-4" />
          {t('analytics.educator.exportCsv')}
        </button>
      </div>
      
      {/* Summary Cards */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <SummaryCard
          title={t('analytics.educator.summary.totalLearners')}
          value={learners.length}
          icon={UsersIcon}
          color="blue"
          trendLabel={periodLabel}
          t={t}
        />
        <SummaryCard
          title={t('analytics.educator.summary.avgEngagement')}
          value={avgEngagement != null ? `${Math.round(avgEngagement)}%` : 'Unavailable'}
          icon={ActivityIcon}
          color="green"
          trend={avgEngagement == null ? undefined : avgEngagement > 70 ? 'up' : 'down'}
          trendLabel={periodLabel}
          t={t}
        />
        <SummaryCard
          title={t('analytics.educator.summary.highPerformers')}
          value={highPerformers}
          icon={AwardIcon}
          color="purple"
          trendLabel={periodLabel}
          t={t}
        />
        <SummaryCard
          title={t('analytics.educator.summary.atRisk')}
          value={atRiskCount}
          icon={AlertTriangleIcon}
          color="red"
          trend={atRiskCount > 0 ? 'down' : undefined}
          trendLabel={periodLabel}
          t={t}
        />
      </div>
      
      {/* At-Risk Students Alert */}
      {atRiskCount > 0 && (
        <div className="rounded-lg bg-amber-50 border border-amber-200 p-4">
          <div className="flex items-start">
            <AlertTriangleIcon className="h-5 w-5 text-amber-600 mt-0.5 mr-3" />
            <div>
              <h3 className="text-sm font-medium text-amber-800">
                {t('analytics.educator.atRiskTitle', { count: atRiskCount })}
              </h3>
              <p className="mt-1 text-sm text-amber-700">
                {t('analytics.educator.atRiskBody')}
              </p>
            </div>
          </div>
        </div>
      )}
      
      {/* Student SDT Heatmap */}
      <div className="bg-white rounded-lg border border-gray-200 shadow-sm overflow-hidden">
        <div className="px-6 py-4 border-b border-gray-200">
          <h2 className="text-lg font-semibold text-gray-900">{t('analytics.educator.table.title')}</h2>
          <p className="text-sm text-gray-600 mt-1">{t('analytics.educator.table.subtitle')}</p>
        </div>
        
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  {t('analytics.educator.table.student')}
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  <div className="flex items-center gap-1">
                    <BrainIcon className="h-4 w-4" />
                    {t('analytics.educator.table.autonomy')}
                  </div>
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  <div className="flex items-center gap-1">
                    <AwardIcon className="h-4 w-4" />
                    {t('analytics.educator.table.competence')}
                  </div>
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  <div className="flex items-center gap-1">
                    <HeartIcon className="h-4 w-4" />
                    {t('analytics.educator.table.belonging')}
                  </div>
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  {t('analytics.educator.table.engagement')}
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  {t('analytics.educator.table.lastActive')}
                </th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {learners.map(learner => (
                <tr key={learner.learnerId} className="hover:bg-gray-50">
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="text-sm font-medium text-gray-900">{learner.learnerName}</div>
                    <div className="text-sm text-gray-500">{t('analytics.educator.eventsCount', { count: learner.eventCount })}</div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <ScoreBar score={learner.autonomyScore} color="purple" t={t} />
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <ScoreBar score={learner.competenceScore} color="blue" t={t} />
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <ScoreBar score={learner.belongingScore} color="pink" t={t} />
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <ScoreBar score={learner.engagementScore} color="green" t={t} />
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    {formatRelativeTime(learner.lastActive, locale, t)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
      
      {/* Weekly / Monthly Trends Chart */}
      <div className="bg-white rounded-lg border border-gray-200 shadow-sm p-6">
        <h3 className="text-lg font-semibold text-gray-900 mb-4">
          {timeRange === 'week' ? t('analytics.educator.thisWeek') : t('analytics.educator.thisMonth')} {t('analytics.educator.table.engagement')}
        </h3>
        {trendPoints.every((point) => point.value == null) ? (
          <div className="h-40 flex items-center justify-center text-sm text-gray-500 border border-gray-200 rounded-lg">
            Unavailable
          </div>
        ) : (
          <div className="grid grid-cols-7 gap-2 md:gap-3 items-end h-44 rounded-lg border border-gray-200 p-3">
            {trendPoints.map((point) => {
              const heightPercent = point.value != null
                ? Math.max(6, Math.round((point.value / trendMax) * 100))
                : 0;
              return (
                <div key={point.key} className="flex flex-col items-center justify-end gap-2 h-full">
                  <div className="text-[10px] text-gray-500">{point.value != null ? `${Math.round(point.value)}%` : 'N/A'}</div>
                  <div className="w-full max-w-10 h-full flex items-end">
                    <div
                      className="w-full bg-indigo-500 rounded-sm"
                      style={{ height: `${heightPercent}%` }}
                      aria-label={point.value != null ? `${point.label} ${Math.round(point.value)}%` : `${point.label} unavailable`}
                      title={point.value != null ? `${point.label}: ${Math.round(point.value)}%` : `${point.label}: unavailable`}
                    />
                  </div>
                  <div className="text-[10px] text-gray-600 text-center leading-tight">{point.label}</div>
                </div>
              );
            })}
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
  trendLabel: string;
  t: (key: string, interpolation?: Record<string, string | number>) => string;
}

function SummaryCard({ title, value, icon: Icon, color, trend, trendLabel, t }: SummaryCardProps) {
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
            {trend === 'up'
              ? t('analytics.educator.trendUp', { period: trendLabel })
              : t('analytics.educator.trendDown', { period: trendLabel })}
          </span>
        </div>
      )}
    </div>
  );
}

interface ScoreBarProps {
  score: number | null;
  color: 'purple' | 'blue' | 'pink' | 'green';
  t: (key: string, interpolation?: Record<string, string | number>) => string;
}

function ScoreBar({ score, color, t }: ScoreBarProps) {
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
          data-score={score ?? 0}
          aria-label={score != null ? t('analytics.educator.scoreAria', { score }) : 'Score unavailable'}
        >
          <style jsx>{`
            div[data-score="${score ?? 0}"] {
              width: ${score ?? 0}%;
            }
          `}</style>
        </div>
      </div>
      <span className="text-sm font-medium text-gray-700">{score != null ? `${score}%` : 'N/A'}</span>
    </div>
  );
}

function formatRelativeTime(
  date: Date | null,
  locale: string,
  t: (key: string, interpolation?: Record<string, string | number>) => string,
): string {
  if (!date) return t('analytics.educator.never');
  
  const now = new Date();
  const diffMs = now.getTime() - date.getTime();
  const diffMins = Math.floor(diffMs / 60000);
  const diffHours = Math.floor(diffMs / 3600000);
  const diffDays = Math.floor(diffMs / 86400000);
  
  if (diffMins < 1) return t('analytics.educator.relative.justNow');
  if (diffMins < 60) return t('analytics.educator.relative.minutesAgo', { count: diffMins });
  if (diffHours < 24) return t('analytics.educator.relative.hoursAgo', { count: diffHours });
  if (diffDays < 7) return t('analytics.educator.relative.daysAgo', { count: diffDays });
  
  return date.toLocaleDateString(locale);
}

type TrendPoint = {
  key: string;
  label: string;
  value: number | null;
};

function buildTrendPoints(
  learners: LearnerEngagement[],
  timeRange: 'week' | 'month',
  locale: string,
): TrendPoint[] {
  const today = new Date();
  const dayStart = new Date(today.getFullYear(), today.getMonth(), today.getDate());

  const bucketCount = timeRange === 'week' ? 7 : 7;
  const bucketSizeDays = timeRange === 'week' ? 1 : 4;

  const buckets = Array.from({ length: bucketCount }, (_v, idx) => {
    const daysAgo = (bucketCount - 1 - idx) * bucketSizeDays;
    const start = new Date(dayStart);
    start.setDate(dayStart.getDate() - daysAgo);
    const end = new Date(start);
    end.setDate(start.getDate() + bucketSizeDays);

    return {
      key: `${start.toISOString()}_${idx}`,
      start,
      end,
      total: 0,
      count: 0,
    };
  });

  learners.forEach((learner) => {
    if (!learner.lastActive || learner.engagementScore == null) return;
    const activeTime = learner.lastActive.getTime();

    for (const bucket of buckets) {
      if (activeTime >= bucket.start.getTime() && activeTime < bucket.end.getTime()) {
        bucket.total += learner.engagementScore;
        bucket.count += 1;
        break;
      }
    }
  });

  const dayLabelFmt = new Intl.DateTimeFormat(locale, { weekday: 'short' });

  return buckets.map((bucket) => {
    const label = timeRange === 'week'
      ? dayLabelFmt.format(bucket.start)
      : `${bucket.start.getMonth() + 1}/${bucket.start.getDate()}`;

    return {
      key: bucket.key,
      label,
      value: bucket.count > 0 ? bucket.total / bucket.count : null,
    };
  });
}
