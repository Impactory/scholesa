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
  avgEngagement: number;
  activeThisWeek: number;
  healthStatus: 'healthy' | 'warning' | 'critical';
  lastActivity: Date;
}

interface PlatformStats {
  totalSites: number;
  totalLearners: number;
  totalEducators: number;
  avgEngagement: number;
  activeSites: number;
}

export function HQAnalyticsDashboard() {
  usePageViewTracking('hq_dashboard');
  
  const [sites, setSites] = useState<SiteMetrics[]>([]);
  const [loading, setLoading] = useState(true);
  const [sortBy, setSortBy] = useState<'name' | 'engagement' | 'learners'>('engagement');
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('desc');
  
  // Real-time platform stats
  const { stats: platformStats, loading: statsLoading } = usePlatformStats();

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
          let activeThisWeek = 0;
          let lastActivityDate = new Date(0);
          
          aggregatesSnapshot.docs.forEach(doc => {
            const data = doc.data();
            const date = data.date?.toDate();
            
            if (date && date >= weekAgo) {
              if (data.engagementScore !== undefined) {
                totalEngagementScore += data.engagementScore;
                engagementCount++;
              }
              if (data.activeUsers !== undefined) {
                activeThisWeek = Math.max(activeThisWeek, data.activeUsers);
              }
            }
            
            if (date && date > lastActivityDate) {
              lastActivityDate = date;
            }
          });
          
          const avgEngagement = engagementCount > 0 
            ? Math.round(totalEngagementScore / engagementCount)
            : 0;
          
          // Determine health status
          let healthStatus: 'healthy' | 'warning' | 'critical' = 'healthy';
          const daysSinceActivity = Math.floor((new Date().getTime() - lastActivityDate.getTime()) / 86400000);
          
          if (avgEngagement < 30 || daysSinceActivity > 7) {
            healthStatus = 'critical';
          } else if (avgEngagement < 50 || daysSinceActivity > 3) {
            healthStatus = 'warning';
          }
          
          if (avgEngagement > 40 && daysSinceActivity <= 7) {
            activeSitesCount++;
          }
          
          siteMetrics.push({
            siteId,
            siteName,
            totalLearners,
            totalEducators,
            avgEngagement,
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
      comparison = a.avgEngagement - b.avgEngagement;
    } else if (sortBy === 'learners') {
      comparison = a.totalLearners - b.totalLearners;
    }
    
    return sortOrder === 'asc' ? comparison : -comparison;
  });
  
  // Export to CSV
  const exportToCSV = () => {
    const headers = ['Site Name', 'Learners', 'Educators', 'Avg Engagement', 'Active This Week', 'Health Status', 'Last Activity'];
    const rows = sites.map(site => [
      site.siteName,
      site.totalLearners.toString(),
      site.totalEducators.toString(),
      `${site.avgEngagement}%`,
      site.activeThisWeek.toString(),
      site.healthStatus,
      site.lastActivity.toLocaleDateString()
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
        <div className="grid grid-cols-1 md:grid-cols-5 gap-4">
          <StatCard
            title="Total Sites"
            value={platformStats.totalSites}
            icon={BuildingIcon}
            color="purple"
          />
          <StatCard
            title="Active Sites"
            value={platformStats.activeSites}
            icon={CheckCircleIcon}
            color="green"
          />
          <StatCard
            title="Total Learners"
            value={platformStats.totalLearners}
            icon={UsersIcon}
            color="blue"
          />
          <StatCard
            title="Total Educators"
            value={platformStats.totalEducators}
            icon={UsersIcon}
            color="cyan"
          />
          <StatCard
            title="Avg Engagement"
            value={`${platformStats.avgEngagement}%`}
            icon={SparklesIcon}
            color="indigo"
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
      </div>
      
      {/* Sites Table */}
      <div className="bg-white rounded-lg border border-gray-200 shadow-sm overflow-hidden">
        <div className="px-6 py-4 border-b border-gray-200 flex items-center justify-between">
          <h2 className="text-lg font-semibold text-gray-900">Site Comparison</h2>
          <div className="flex gap-2">
            <select
              value={sortBy}
              onChange={(e) => setSortBy(e.target.value as 'name' | 'engagement' | 'learners')}
              className="px-3 py-1.5 border border-gray-300 rounded-lg text-sm"
              aria-label="Sort sites by"
            >
              <option value="name">Sort by Name</option>
              <option value="engagement">Sort by Engagement</option>
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
                      <span className="font-medium text-gray-900">{site.avgEngagement}%</span>
                      {site.avgEngagement >= 70 ? (
                        <TrendingUpIcon className="h-4 w-4 text-green-500" />
                      ) : site.avgEngagement < 40 ? (
                        <TrendingDownIcon className="h-4 w-4 text-red-500" />
                      ) : null}
                    </div>
                  </td>
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
}

function StatCard({ title, value, icon: Icon, color }: StatCardProps) {
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
    </div>
  );
}

interface HealthCardProps {
  title: string;
  count: number;
  color: 'green' | 'yellow' | 'red';
}

function HealthCard({ title, count, color }: HealthCardProps) {
  const colorClasses = {
    green: { bg: 'bg-green-50', border: 'border-green-200', text: 'text-green-700', icon: 'text-green-600' },
    yellow: { bg: 'bg-yellow-50', border: 'border-yellow-200', text: 'text-yellow-700', icon: 'text-yellow-600' },
    red: { bg: 'bg-red-50', border: 'border-red-200', text: 'text-red-700', icon: 'text-red-600' }
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
  status: 'healthy' | 'warning' | 'critical';
}

function HealthBadge({ status }: HealthBadgeProps) {
  const config = {
    healthy: { bg: 'bg-green-100', text: 'text-green-800', label: 'Healthy' },
    warning: { bg: 'bg-yellow-100', text: 'text-yellow-800', label: 'Needs Attention' },
    critical: { bg: 'bg-red-100', text: 'text-red-800', label: 'At Risk' }
  };
  
  const { bg, text, label } = config[status];
  
  return (
    <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${bg} ${text}`}>
      {label}
    </span>
  );
}

// ==================== HELPER FUNCTIONS ====================

function formatRelativeTime(date: Date): string {
  const now = new Date();
  const diffMs = now.getTime() - date.getTime();
  const diffDays = Math.floor(diffMs / 86400000);
  
  if (diffDays === 0) return 'Today';
  if (diffDays === 1) return 'Yesterday';
  if (diffDays < 7) return `${diffDays} days ago`;
  if (diffDays < 30) return `${Math.floor(diffDays / 7)} weeks ago`;
  return date.toLocaleDateString();
}
