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

import React, { useState, useEffect } from 'react';
import { useAuthContext } from '@/src/firebase/auth/AuthProvider';
import { TelemetryService } from '@/src/lib/telemetry/telemetryService';
import { 
  TrendingUpIcon, 
  TrendingDownIcon, 
  AlertTriangleIcon,
  UsersIcon,
  ActivityIcon,
  AwardIcon,
  HeartIcon,
  BrainIcon
} from 'lucide-react';

interface StudentEngagement {
  learnerId: string;
  learnerName: string;
  engagementScore: number; // 0-100
  autonomyScore: number; // 0-100
  competenceScore: number; // 0-100
  belongingScore: number; // 0-100
  lastActive: Date;
  eventCount: number;
}

export function AnalyticsDashboard() {
  const { profile } = useAuthContext();
  const [students, setStudents] = useState<StudentEngagement[]>([]);
  const [loading, setLoading] = useState(true);
  const [timeRange, setTimeRange] = useState<'week' | 'month'>('week');
  
  const siteId = profile?.activeSiteId || profile?.siteIds?.[0] || '';

  useEffect(() => {
    if (!siteId) return;
    
    const fetchAnalytics = async () => {
      setLoading(true);
      try {
        // TODO: Replace with actual Firestore query when telemetryAggregates collection has data
        // For now, generate mock data for demonstration
        const mockStudents: StudentEngagement[] = [
          {
            learnerId: 'student1',
            learnerName: 'Alex Johnson',
            engagementScore: 85,
            autonomyScore: 90,
            competenceScore: 80,
            belongingScore: 85,
            lastActive: new Date(),
            eventCount: 45
          },
          {
            learnerId: 'student2',
            learnerName: 'Maria Garcia',
            engagementScore: 72,
            autonomyScore: 75,
            competenceScore: 70,
            belongingScore: 70,
            lastActive: new Date(Date.now() - 86400000), // 1 day ago
            eventCount: 32
          },
          {
            learnerId: 'student3',
            learnerName: 'Jordan Lee',
            engagementScore: 45,
            autonomyScore: 40,
            competenceScore: 50,
            belongingScore: 45,
            lastActive: new Date(Date.now() - 259200000), // 3 days ago
            eventCount: 12
          }
        ];
        
        setStudents(mockStudents);
      } catch (err) {
        console.error('Failed to load analytics:', err);
      } finally {
        setLoading(false);
      }
    };
    
    fetchAnalytics();
  }, [siteId, timeRange]);
  
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
  
  const avgEngagement = students.reduce((sum, s) => sum + s.engagementScore, 0) / students.length || 0;
  const atRiskCount = students.filter(s => s.engagementScore < 60).length;
  const highPerformers = students.filter(s => s.engagementScore >= 80).length;
  
  return (
    <div className="space-y-6">
      {/* Time Range Selector */}
      <div className="flex justify-end">
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
      </div>
      
      {/* Summary Cards */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <SummaryCard
          title="Total Students"
          value={students.length}
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
                {atRiskCount} student{atRiskCount > 1 ? 's' : ''} may need support
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
              {students.map(student => (
                <tr key={student.learnerId} className="hover:bg-gray-50">
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="text-sm font-medium text-gray-900">{student.learnerName}</div>
                    <div className="text-sm text-gray-500">{student.eventCount} events</div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <ScoreBar score={student.autonomyScore} color="purple" />
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <ScoreBar score={student.competenceScore} color="blue" />
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <ScoreBar score={student.belongingScore} color="pink" />
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <ScoreBar score={student.engagementScore} color="green" />
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    {formatRelativeTime(student.lastActive)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
      
      {/* Placeholder for future charts */}
      <div className="bg-white rounded-lg border border-gray-200 shadow-sm p-6">
        <h3 className="text-lg font-semibold text-gray-900 mb-4">Weekly Trends</h3>
        <div className="h-64 flex items-center justify-center text-gray-400 border-2 border-dashed border-gray-200 rounded-lg">
          Coming soon: Line chart showing engagement over time
        </div>
      </div>
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
          style={{ width: `${score}%` }}
        />
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
