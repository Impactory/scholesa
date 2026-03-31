'use client';

/**
 * HQ Analytics Dashboard
 * 
 * Platform-wide analytics for HQ users:
 * - Multi-site overview and comparison
 * - Platform-wide engagement metrics
 * - Site health indicators
 * - Educator activity tracking
 * - Export capabilities
 */

import React, { useState, useEffect } from 'react';
import { db } from '@/src/firebase/client-init';
import { collection, query, where, getDocs } from 'firebase/firestore';
import { usePlatformStats } from '@/src/hooks/useRealtimeAnalytics';
import { VoiceReliabilityLegend, VOICE_RELIABILITY_HELPER_TEXT } from './VoiceReliabilityGuidance';
import {
  BuildingIcon,
  UsersIcon,
  SparklesIcon,
  TrendingUpIcon,
  TrendingDownIcon,
  AlertCircleIcon,
  DownloadIcon,
  CheckCircleIcon
} from 'lucide-react';
import { usePageViewTracking } from '@/src/hooks/useTelemetry';

interface SiteMetrics {
  siteId: string;
  siteName: string;
  totalLearners: number;
  totalEducators: number;
  avgEngagement: number | null;
  avgVoiceCaptureSuccess: number | null;
  voiceEscalationsThisWeek: number;
  activeThisWeek: number;
  healthStatus: 'healthy' | 'warning' | 'critical' | 'unavailable';
  lastActivity: Date | null;
}

export function HQAnalyticsDashboard() {
  usePageViewTracking('hq_dashboard');
  
  const [sites, setSites] = useState<SiteMetrics[]>([]);
  const [loading, setLoading] = useState(true);
  const [sortBy, setSortBy] = useState<'name' | 'engagement' | 'voice' | 'learners'>('engagement');
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('desc');
  
  // Real-time platform stats
  const { stats: platformStats, loading: platformStatsLoading } = usePlatformStats();

  useEffect(() => {
    const fetchPlatformData = async () => {
      setLoading(true);
      try {
        // Fetch all sites (platform stats now from real-time hook)
        const sitesQuery = query(collection(db, 'sites'));
        const sitesSnapshot = await getDocs(sitesQuery);
        
        const siteMetrics: SiteMetrics[] = [];
        
        for (const siteDoc of sitesSnapshot.docs) {
          const siteData = siteDoc.data();
          const siteId = siteDoc.id;
          const siteName = siteData.name || 'Unnamed Site';
          
          // Count learners
          const learnersQuery = query(
            collection(db, 'users'),
            where('role', '==', 'learner'),
            where('siteIds', 'array-contains', siteId)
          );
          const learnersSnapshot = await getDocs(learnersQuery);
          const totalLearners = learnersSnapshot.size;
          
          // Count educators
          const educatorsQuery = query(
            collection(db, 'users'),
            where('role', '==', 'educator'),
            where('siteIds', 'array-contains', siteId)
          );
          const educatorsSnapshot = await getDocs(educatorsQuery);
          const totalEducators = educatorsSnapshot.size;
          
          // Calculate engagement from telemetry aggregates (last 7 days)
          const weekAgo = new Date();
          weekAgo.setDate(weekAgo.getDate() - 7);
          
          const aggregatesQuery = query(
            collection(db, 'telemetryAggregates'),
            where('siteId', '==', siteId),
            where('period', '==', 'daily')
          );
          const aggregatesSnapshot = await getDocs(aggregatesQuery);
          
          let totalEngagementScore = 0;
          let engagementCount = 0;
          let totalVoiceCaptureSuccess = 0;
          let voiceCaptureCount = 0;
          let voiceEscalationsThisWeek = 0;
          let activeThisWeek = 0;
          let lastActivityDate: Date | null = null;
          
          aggregatesSnapshot.docs.forEach(doc => {
            const data = doc.data();
            const date = data.date?.toDate();
            
            if (date && date >= weekAgo) {
              if (typeof data.engagementScore === 'number' && Number.isFinite(data.engagementScore)) {
                totalEngagementScore += data.engagementScore;
                engagementCount++;
              }
              const voiceMetrics = data.voiceMetrics && typeof data.voiceMetrics === 'object'
                ? data.voiceMetrics as Record<string, unknown>
                : null;
              if (typeof voiceMetrics?.captureSuccessRate === 'number' && Number.isFinite(voiceMetrics.captureSuccessRate)) {
                totalVoiceCaptureSuccess += voiceMetrics.captureSuccessRate;
                voiceCaptureCount++;
              }
              if (typeof voiceMetrics?.escalatedCount === 'number' && Number.isFinite(voiceMetrics.escalatedCount)) {
                voiceEscalationsThisWeek += voiceMetrics.escalatedCount;
              }
              if (typeof data.activeUsers === 'number' && Number.isFinite(data.activeUsers)) {
                activeThisWeek = Math.max(activeThisWeek, data.activeUsers);
              }
            }
            
            if (date && (!lastActivityDate || date > lastActivityDate)) {
              lastActivityDate = date;
            }
          });
          
          const avgEngagement = engagementCount > 0 
            ? Math.round(totalEngagementScore / engagementCount)
            : null;
          const avgVoiceCaptureSuccess = voiceCaptureCount > 0
            ? Math.round((totalVoiceCaptureSuccess / voiceCaptureCount) * 100)
            : null;
          
          // Determine health status
          let healthStatus: 'healthy' | 'warning' | 'critical' | 'unavailable' = 'unavailable';
          const capturedLastActivityDate = lastActivityDate;
          const daysSinceActivity = capturedLastActivityDate
            ? Math.floor((new Date().getTime() - capturedLastActivityDate.getTime()) / 86400000)
            : null;
          const voiceCaptureCritical = avgVoiceCaptureSuccess !== null && avgVoiceCaptureSuccess < 50;
          const voiceCaptureWarning = avgVoiceCaptureSuccess !== null && avgVoiceCaptureSuccess < 80;
          
          if (
            avgEngagement !== null &&
            daysSinceActivity !== null &&
            (avgEngagement < 30 || daysSinceActivity > 7 || voiceCaptureCritical)
          ) {
            healthStatus = 'critical';
          } else if (
            avgEngagement !== null &&
            daysSinceActivity !== null &&
            (avgEngagement < 50 || daysSinceActivity > 3 || voiceCaptureWarning)
          ) {
            healthStatus = 'warning';
          } else if ((avgEngagement !== null || avgVoiceCaptureSuccess !== null) && daysSinceActivity !== null) {
            healthStatus = 'healthy';
          }
          
          siteMetrics.push({
            siteId,
            siteName,
            totalLearners,
            totalEducators,
            avgEngagement,
            avgVoiceCaptureSuccess,
            voiceEscalationsThisWeek,
            activeThisWeek,
            healthStatus,
            lastActivity: lastActivityDate
          });
        }
        
        setSites(siteMetrics);
        // Platform stats now come from real-time hook
        
      } catch (err) {
        console.error('Failed to load platform data:', err);
      } finally {
        setLoading(false);
      }
    };
    
    fetchPlatformData();
  }, []);
  
  // Sort sites
  const sortedSites = [...sites].sort((a, b) => {
    let comparison = 0;
    
    if (sortBy === 'name') {
      comparison = a.siteName.localeCompare(b.siteName);
    } else if (sortBy === 'engagement') {
      const left = a.avgEngagement ?? Number.NEGATIVE_INFINITY;
      const right = b.avgEngagement ?? Number.NEGATIVE_INFINITY;
      comparison = left - right;
    } else if (sortBy === 'voice') {
      const left = a.avgVoiceCaptureSuccess ?? Number.NEGATIVE_INFINITY;
      const right = b.avgVoiceCaptureSuccess ?? Number.NEGATIVE_INFINITY;
      comparison = left - right;
    } else if (sortBy === 'learners') {
      comparison = a.totalLearners - b.totalLearners;
    }
    
    return sortOrder === 'asc' ? comparison : -comparison;
  });

  const sitesWithVoiceEvidence = sites.filter((site) => site.avgVoiceCaptureSuccess != null);
  const avgVoiceCapture = sitesWithVoiceEvidence.length > 0
    ? Math.round(
      sitesWithVoiceEvidence.reduce((sum, site) => sum + (site.avgVoiceCaptureSuccess as number), 0) /
      sitesWithVoiceEvidence.length,
    )
    : null;
  const lowVoiceCaptureSites = sites.filter(
    (site) => site.avgVoiceCaptureSuccess != null && site.avgVoiceCaptureSuccess < 80,
  ).length;
  const criticalVoiceCaptureSites = sites.filter(
    (site) => site.avgVoiceCaptureSuccess != null && site.avgVoiceCaptureSuccess < 50,
  ).length;
  const totalVoiceEscalations = sites.reduce((sum, site) => sum + site.voiceEscalationsThisWeek, 0);
  
  // Export to CSV
  const exportToCSV = () => {
    const headers = ['Site Name', 'Learners', 'Educators', 'Avg Engagement', 'Voice Capture Success', 'Voice Escalations', 'Active This Week', 'Health Status', 'Last Activity'];
    const rows = sites.map(site => [
      site.siteName,
      site.totalLearners.toString(),
      site.totalEducators.toString(),
      site.avgEngagement != null ? `${site.avgEngagement}%` : 'Unavailable',
      site.avgVoiceCaptureSuccess != null ? `${site.avgVoiceCaptureSuccess}%` : 'Unavailable',
      site.voiceEscalationsThisWeek.toString(),
      site.activeThisWeek.toString(),
      site.healthStatus,
      site.lastActivity ? site.lastActivity.toLocaleDateString() : 'Unavailable'
    ]);
    
    const csv = [headers, ...rows]
      .map(row => row.map(cell => `"${cell}"`).join(','))
      .join('\n');
    
    const blob = new Blob([csv], { type: 'text/csv' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `platform-analytics-${new Date().toISOString().split('T')[0]}.csv`;
    link.click();
    URL.revokeObjectURL(url);
  };
  
  if (loading) {
    return (
      <div className="space-y-6 animate-pulse">
        <div className="h-32 bg-gray-200 rounded-lg" />
        <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
          {[1,2,3,4].map(i => (
            <div key={i} className="h-32 bg-gray-200 rounded-lg" />
          ))}
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="bg-gradient-to-r from-purple-600 to-indigo-700 rounded-lg p-8 text-white">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-3xl font-bold mb-2">Platform Analytics</h1>
            <p className="text-purple-100">Organization-wide insights and performance metrics</p>
          </div>
          <button
            onClick={exportToCSV}
            className="flex items-center gap-2 bg-white text-purple-700 px-4 py-2 rounded-lg hover:bg-purple-50 transition font-medium"
          >
            <DownloadIcon className="h-4 w-4" />
            Export CSV
          </button>
        </div>
      </div>
      
      {/* Platform Stats */}
      {platformStats && (
        <div className="grid grid-cols-1 md:grid-cols-6 gap-4">
          <StatCard
            title="Total Sites"
            value={platformStatsLoading || platformStats.totalSites == null ? 'Unavailable' : platformStats.totalSites}
            icon={BuildingIcon}
            color="purple"
          />
          <StatCard
            title="Active Sites"
            value={platformStatsLoading || platformStats.activeSites == null ? 'Unavailable' : platformStats.activeSites}
            icon={CheckCircleIcon}
            color="green"
          />
          <StatCard
            title="Total Learners"
            value={platformStatsLoading || platformStats.totalLearners == null ? 'Unavailable' : platformStats.totalLearners}
            icon={UsersIcon}
            color="blue"
          />
          <StatCard
            title="Total Educators"
            value={platformStatsLoading || platformStats.totalEducators == null ? 'Unavailable' : platformStats.totalEducators}
            icon={UsersIcon}
            color="cyan"
          />
          <StatCard
            title="Avg Engagement"
            value={platformStatsLoading || platformStats.avgEngagement == null ? 'Unavailable' : `${platformStats.avgEngagement}%`}
            icon={SparklesIcon}
            color="indigo"
          />
          <StatCard
            title="Voice Capture"
            value={platformStatsLoading || platformStats.avgVoiceCaptureSuccess == null ? 'Unavailable' : `${platformStats.avgVoiceCaptureSuccess}%`}
            icon={SparklesIcon}
            color="purple"
            helperText={VOICE_RELIABILITY_HELPER_TEXT.platformUnavailable}
          />
        </div>
      )}
      
      {/* Site Health Overview */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <HealthCard
          title="Healthy Sites"
          count={sites.filter(s => s.healthStatus === 'healthy').length}
          color="green"
        />
        <HealthCard
          title="Sites Needing Attention"
          count={sites.filter(s => s.healthStatus === 'warning').length}
          color="yellow"
        />
        <HealthCard
          title="Sites at Risk"
          count={sites.filter(s => s.healthStatus === 'critical').length}
          color="red"
        />
        <HealthCard
          title="Evidence Unavailable"
          count={sites.filter(s => s.healthStatus === 'unavailable').length}
          color="gray"
        />
      </div>

      <div className="bg-white rounded-lg border border-gray-200 shadow-sm p-6">
        <div className="flex flex-wrap items-start justify-between gap-4">
          <div>
            <h2 className="text-lg font-semibold text-gray-900">Voice Reliability</h2>
            <p className="text-sm text-gray-600">
              Capture reliability across the last 7 days. Low values mean the app had fewer clear voice inputs to work from.
            </p>
            <p className="mt-2 text-xs text-gray-500">
              {VOICE_RELIABILITY_HELPER_TEXT.platformTrustBoundary}
            </p>
          </div>
          <div className="rounded-lg bg-amber-50 px-3 py-2 text-sm text-amber-800">
            {criticalVoiceCaptureSites > 0
              ? `${criticalVoiceCaptureSites} site${criticalVoiceCaptureSites === 1 ? '' : 's'} are below 50% capture success.`
              : 'No sites are currently below 50% capture success.'}
          </div>
        </div>
        <div className="mt-4 grid grid-cols-1 md:grid-cols-4 gap-4">
          <StatCard
            title="Avg Voice Capture"
            value={avgVoiceCapture == null ? 'Unavailable' : `${avgVoiceCapture}%`}
            icon={SparklesIcon}
            color="purple"
            helperText={VOICE_RELIABILITY_HELPER_TEXT.platformMetricNote}
          />
          <StatCard
            title="Sites With Voice Data"
            value={sitesWithVoiceEvidence.length}
            icon={CheckCircleIcon}
            color="green"
          />
          <StatCard
            title="Sites Below 80%"
            value={lowVoiceCaptureSites}
            icon={AlertCircleIcon}
            color="yellow"
          />
          <StatCard
            title="Weekly Escalations"
            value={totalVoiceEscalations}
            icon={AlertCircleIcon}
            color="red"
          />
        </div>
        <VoiceReliabilityLegend />
      </div>
      
      {/* Sites Table */}
      <div className="bg-white rounded-lg border border-gray-200 shadow-sm overflow-hidden">
        <div className="px-6 py-4 border-b border-gray-200 flex items-center justify-between">
          <h2 className="text-lg font-semibold text-gray-900">Site Comparison</h2>
          <div className="flex gap-2">
            <select
              value={sortBy}
              onChange={(e) => setSortBy(e.target.value as 'name' | 'engagement' | 'voice' | 'learners')}
              className="px-3 py-1.5 border border-gray-300 rounded-lg text-sm"
              aria-label="Sort sites by"
            >
              <option value="name">Sort by Name</option>
              <option value="engagement">Sort by Engagement</option>
              <option value="voice">Sort by Voice Capture</option>
              <option value="learners">Sort by Learners</option>
            </select>
            <button
              onClick={() => setSortOrder(sortOrder === 'asc' ? 'desc' : 'asc')}
              className="px-3 py-1.5 border border-gray-300 rounded-lg text-sm hover:bg-gray-50"
            >
              {sortOrder === 'asc' ? '↑' : '↓'}
            </button>
          </div>
        </div>
        
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead className="bg-gray-50 border-b border-gray-200">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Site</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Learners</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Educators</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Avg Engagement</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Voice Capture</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Escalations</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Active This Week</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Health</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Last Activity</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {sortedSites.map(site => (
                <tr key={site.siteId} className="hover:bg-gray-50">
                  <td className="px-6 py-4">
                    <div className="font-medium text-gray-900">{site.siteName}</div>
                    <div className="text-xs text-gray-500">{site.siteId}</div>
                  </td>
                  <td className="px-6 py-4 text-gray-700">{site.totalLearners}</td>
                  <td className="px-6 py-4 text-gray-700">{site.totalEducators}</td>
                  <td className="px-6 py-4">
                    <div className="flex items-center gap-2">
                      <span className="font-medium text-gray-900">{site.avgEngagement != null ? `${site.avgEngagement}%` : 'Unavailable'}</span>
                      {site.avgEngagement != null && site.avgEngagement >= 70 ? (
                        <TrendingUpIcon className="h-4 w-4 text-green-500" />
                      ) : site.avgEngagement != null && site.avgEngagement < 40 ? (
                        <TrendingDownIcon className="h-4 w-4 text-red-500" />
                      ) : null}
                    </div>
                  </td>
                  <td className="px-6 py-4 text-gray-700">
                    {site.avgVoiceCaptureSuccess != null ? `${site.avgVoiceCaptureSuccess}%` : 'Unavailable'}
                  </td>
                  <td className="px-6 py-4 text-gray-700">{site.voiceEscalationsThisWeek}</td>
                  <td className="px-6 py-4 text-gray-700">{site.activeThisWeek}</td>
                  <td className="px-6 py-4">
                    <HealthBadge status={site.healthStatus} />
                  </td>
                  <td className="px-6 py-4 text-sm text-gray-600">
                    {formatRelativeTime(site.lastActivity)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}

// ==================== HELPER COMPONENTS ====================

interface StatCardProps {
  title: string;
  value: string | number;
  icon: React.ComponentType<{ className?: string }>;
  color: string;
  helperText?: string;
}

function StatCard({ title, value, icon: Icon, color, helperText }: StatCardProps) {
  const colorClasses: Record<string, { bg: string; text: string }> = {
    purple: { bg: 'bg-purple-100', text: 'text-purple-700' },
    green: { bg: 'bg-green-100', text: 'text-green-700' },
    blue: { bg: 'bg-blue-100', text: 'text-blue-700' },
    cyan: { bg: 'bg-cyan-100', text: 'text-cyan-700' },
    indigo: { bg: 'bg-indigo-100', text: 'text-indigo-700' }
  };
  
  const colors = colorClasses[color];
  
  return (
    <div className="bg-white rounded-lg border border-gray-200 shadow-sm p-6">
      <div className={`inline-flex items-center justify-center w-12 h-12 rounded-full ${colors.bg} mb-3`}>
        <Icon className={`h-6 w-6 ${colors.text}`} />
      </div>
      <p className="text-sm font-medium text-gray-600 mb-1">{title}</p>
      <p className="text-3xl font-bold text-gray-900">{value}</p>
      {helperText ? <p className="mt-2 max-w-xs text-xs text-gray-500">{helperText}</p> : null}
    </div>
  );
}

interface HealthCardProps {
  title: string;
  count: number;
  color: 'green' | 'yellow' | 'red' | 'gray';
}

function HealthCard({ title, count, color }: HealthCardProps) {
  const colorClasses = {
    green: { bg: 'bg-green-50', border: 'border-green-200', text: 'text-green-700', icon: 'text-green-600' },
    yellow: { bg: 'bg-yellow-50', border: 'border-yellow-200', text: 'text-yellow-700', icon: 'text-yellow-600' },
    red: { bg: 'bg-red-50', border: 'border-red-200', text: 'text-red-700', icon: 'text-red-600' },
    gray: { bg: 'bg-gray-50', border: 'border-gray-200', text: 'text-gray-700', icon: 'text-gray-600' },
  };
  
  const colors = colorClasses[color];
  const Icon = color === 'green' ? CheckCircleIcon : AlertCircleIcon;
  
  return (
    <div className={`${colors.bg} border ${colors.border} rounded-lg p-6`}>
      <div className="flex items-center gap-3">
        <Icon className={`h-8 w-8 ${colors.icon}`} />
        <div>
          <p className={`text-sm font-medium ${colors.text}`}>{title}</p>
          <p className="text-3xl font-bold text-gray-900">{count}</p>
        </div>
      </div>
    </div>
  );
}

interface HealthBadgeProps {
  status: 'healthy' | 'warning' | 'critical' | 'unavailable';
}

function HealthBadge({ status }: HealthBadgeProps) {
  const config = {
    healthy: { bg: 'bg-green-100', text: 'text-green-800', label: 'Healthy' },
    warning: { bg: 'bg-yellow-100', text: 'text-yellow-800', label: 'Needs Attention' },
    critical: { bg: 'bg-red-100', text: 'text-red-800', label: 'At Risk' },
    unavailable: { bg: 'bg-gray-100', text: 'text-gray-800', label: 'Evidence Unavailable' },
  };
  
  const { bg, text, label } = config[status];
  
  return (
    <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${bg} ${text}`}>
      {label}
    </span>
  );
}

// ==================== HELPER FUNCTIONS ====================

function formatRelativeTime(date: Date | null): string {
  if (!date) return 'Unavailable';
  const now = new Date();
  const diffMs = now.getTime() - date.getTime();
  const diffDays = Math.floor(diffMs / 86400000);
  
  if (diffDays === 0) return 'Today';
  if (diffDays === 1) return 'Yesterday';
  if (diffDays < 7) return `${diffDays} days ago`;
  if (diffDays < 30) return `${Math.floor(diffDays / 7)} weeks ago`;
  return date.toLocaleDateString();
}
