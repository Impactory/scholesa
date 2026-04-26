'use client';

/**
 * Student Personal Analytics Dashboard
 * 
 * Shows learner their own:
 * - Personal SDT scores and growth
 * - Learning journey timeline
 * - Skills progress and badges
 * - Goals and achievements
 * - Peer comparisons (optional, anonymized)
 */

import React, { useState, useEffect } from 'react';
import { useAuthContext } from '@/src/firebase/auth/AuthProvider';
import { db } from '@/src/firebase/client-init';
import { collection, query, where, orderBy, getDocs, Timestamp } from 'firebase/firestore';
import { recognitionBadgesCollection } from '@/src/firebase/firestore/collections';
import { useSDTScores, useChildActivity } from '@/src/hooks/useRealtimeAnalytics';
import {
  AwardIcon,
  TargetIcon,
  SparklesIcon,
  BrainIcon,
  HeartIcon,
  Zap,
  Trophy
} from 'lucide-react';
import { usePageViewTracking } from '@/src/hooks/useTelemetry';
import { useI18n } from '@/src/lib/i18n/useI18n';

interface StudentStats {
  totalEvents: number;
  goalsSet: number;
  goalsAchieved: number;
  checkpointsPassed: number;
  badgesEarned: number;
  recognitionReceived: number;
  currentStreak: number;
  longestStreak: number;
}

interface ActivityData {
  date: string;
  autonomyEvents: number;
  competenceEvents: number;
  belongingEvents: number;
  reflectionEvents: number;
}

export function StudentAnalyticsDashboard() {
  usePageViewTracking('student_analytics');
  
  const { profile } = useAuthContext();
  const { locale, t } = useI18n();
  const [stats, setStats] = useState<StudentStats | null>(null);
  const [activityData, setActivityData] = useState<ActivityData[]>([]);
  const [loading, setLoading] = useState(true);
  const [timeRange, setTimeRange] = useState<'week' | 'month'>('week');
  
  const learnerId = profile?.uid || '';
  const siteId = profile?.activeSiteId || profile?.siteIds?.[0] || '';
  
  // Real-time SDT scores
  const { scores: sdtScores, loading: sdtLoading } = useSDTScores(learnerId, siteId);
  
  // Real-time activity feed
  const { loading: activitiesLoading } = useChildActivity(learnerId, siteId, 20);

  useEffect(() => {
    if (!learnerId || !siteId) return;
    
    const fetchAnalytics = async () => {
      setLoading(true);
      try {
        // Fetch stats from various collections (SDT scores now from real-time hook)
        const daysBack = timeRange === 'week' ? 7 : 30;
        const startDate = new Date();
        startDate.setDate(startDate.getDate() - daysBack);
        
        // Get goals
        const goalsQuery = query(
          collection(db, 'learnerGoals'),
          where('userId', '==', learnerId),
          where('siteId', '==', siteId)
        );
        const goalsSnapshot = await getDocs(goalsQuery);
        const goalsSet = goalsSnapshot.size;
        const goalsAchieved = goalsSnapshot.docs.filter(doc => doc.data().status === 'completed').length;
        
        // Get checkpoints
        const checkpointsQuery = query(
          collection(db, 'checkpointHistory'),
          where('userId', '==', learnerId),
          where('siteId', '==', siteId),
          where('status', '==', 'passed')
        );
        const checkpointsSnapshot = await getDocs(checkpointsQuery);
        const checkpointsPassed = checkpointsSnapshot.size;
        
        // Get badges
        const badgesQuery = query(
          collection(db, 'badgeAchievements'),
          where('userId', '==', learnerId),
          where('siteId', '==', siteId)
        );
        const badgesSnapshot = await getDocs(badgesQuery);
        const badgesEarned = badgesSnapshot.size;
        
        // Get recognition received
        const recognitionQuery = query(
          recognitionBadgesCollection,
          where('recipientId', '==', learnerId),
          where('siteId', '==', siteId)
        );
        const recognitionSnapshot = await getDocs(recognitionQuery);
        const recognitionReceived = recognitionSnapshot.size;
        
        // Get telemetry events for total count and streak
        const eventsQuery = query(
          collection(db, 'telemetryEvents'),
          where('userId', '==', learnerId),
          where('siteId', '==', siteId),
          orderBy('timestamp', 'desc')
        );
        const eventsSnapshot = await getDocs(eventsQuery);
        const totalEvents = eventsSnapshot.size;
        
        // Calculate streak (days with at least 1 event)
        const { currentStreak, longestStreak } = calculateStreaks(eventsSnapshot.docs.map(doc => doc.data().timestamp.toDate()));
        
        setStats({
          totalEvents,
          goalsSet,
          goalsAchieved,
          checkpointsPassed,
          badgesEarned,
          recognitionReceived,
          currentStreak,
          longestStreak
        });
        
        // Fetch activity data for chart
        const activityDataPoints: ActivityData[] = [];
        for (let i = daysBack - 1; i >= 0; i--) {
          const dayDate = new Date();
          dayDate.setDate(dayDate.getDate() - i);
          dayDate.setHours(0, 0, 0, 0);
          
          const dayEnd = new Date(dayDate);
          dayEnd.setHours(23, 59, 59, 999);
          
          const dayEventsQuery = query(
            collection(db, 'telemetryEvents'),
            where('userId', '==', learnerId),
            where('siteId', '==', siteId),
            where('timestamp', '>=', Timestamp.fromDate(dayDate)),
            where('timestamp', '<=', Timestamp.fromDate(dayEnd))
          );
          const dayEventsSnapshot = await getDocs(dayEventsQuery);
          
          const categoryCounts = { autonomy: 0, competence: 0, belonging: 0, reflection: 0 };
          dayEventsSnapshot.docs.forEach(doc => {
            const category = doc.data().category;
            if (category in categoryCounts) {
              categoryCounts[category as keyof typeof categoryCounts]++;
            }
          });
          
          activityDataPoints.push({
            date: dayDate.toLocaleDateString(locale, { month: 'short', day: 'numeric' }),
            autonomyEvents: categoryCounts.autonomy,
            competenceEvents: categoryCounts.competence,
            belongingEvents: categoryCounts.belonging,
            reflectionEvents: categoryCounts.reflection
          });
        }
        
        setActivityData(activityDataPoints);
        
      } catch (err) {
        console.error('Failed to load analytics:', err);
      } finally {
        setLoading(false);
      }
    };
    
    fetchAnalytics();
  }, [learnerId, siteId, timeRange, locale]);
  
  if (loading || sdtLoading || activitiesLoading) {
    return (
      <div className="space-y-6 animate-pulse">
        <div className="h-48 bg-gray-200 rounded-lg" />
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          {[1,2,3].map(i => (
            <div key={i} className="h-32 bg-gray-200 rounded-lg" />
          ))}
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="bg-gradient-to-r from-indigo-500 to-purple-600 rounded-lg p-8 text-white">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-3xl font-bold mb-2">{t('analytics.student.headerTitle')}</h1>
            <p className="text-indigo-100">{t('analytics.student.headerSubtitle')}</p>
          </div>
          <SparklesIcon className="h-16 w-16 text-indigo-200" />
        </div>
      </div>
      
      {/* Time Range Selector */}
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
            {t('analytics.student.thisWeek')}
          </button>
          <button
            onClick={() => setTimeRange('month')}
            className={`px-4 py-2 text-sm font-medium rounded-r-md ${
              timeRange === 'month'
                ? 'bg-indigo-600 text-white'
                : 'bg-white text-gray-700 hover:bg-gray-50 border border-gray-300 border-l-0'
            }`}
          >
            {t('analytics.student.thisMonth')}
          </button>
        </div>
      </div>
      
      {/* SDT Scores */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <SDTScoreCard
          title={t('analytics.student.sdt.autonomy.title')}
          subtitle={t('analytics.student.sdt.autonomy.subtitle')}
          score={sdtScores.autonomy}
          icon={BrainIcon}
          color="purple"
        />
        <SDTScoreCard
          title={t('analytics.student.sdt.competence.title')}
          subtitle={t('analytics.student.sdt.competence.subtitle')}
          score={sdtScores.competence}
          icon={AwardIcon}
          color="blue"
        />
        <SDTScoreCard
          title={t('analytics.student.sdt.belonging.title')}
          subtitle={t('analytics.student.sdt.belonging.subtitle')}
          score={sdtScores.belonging}
          icon={HeartIcon}
          color="pink"
        />
        <SDTScoreCard
          title={t('analytics.student.sdt.overall.title')}
          subtitle={t('analytics.student.sdt.overall.subtitle')}
          score={sdtScores.overall}
          icon={Trophy}
          color="green"
        />
      </div>
      
      {/* Stats Grid */}
      {stats && (
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <StatCard icon={TargetIcon} label={t('analytics.student.stats.goalsSet')} value={stats.goalsSet} color="indigo" />
          <StatCard icon={Trophy} label={t('analytics.student.stats.goalsAchieved')} value={stats.goalsAchieved} color="green" />
          <StatCard icon={AwardIcon} label={t('analytics.student.stats.checkpointsPassed')} value={stats.checkpointsPassed} color="blue" />
          <StatCard icon={SparklesIcon} label={t('analytics.student.stats.badgesEarned')} value={stats.badgesEarned} color="yellow" />
          <StatCard icon={HeartIcon} label={t('analytics.student.stats.recognition')} value={stats.recognitionReceived} color="pink" />
          <StatCard icon={Zap} label={t('analytics.student.stats.currentStreak')} value={t('analytics.student.currentStreakValue', { count: stats.currentStreak })} color="orange" />
        </div>
      )}
      
      {/* Activity Chart */}
      <div className="bg-white rounded-lg border border-gray-200 shadow-sm p-6">
        <h3 className="text-lg font-semibold text-gray-900 mb-4">{t('analytics.student.activityTitle')}</h3>
        {activityData.length > 0 ? (
          <ActivityChart data={activityData} t={t} />
        ) : (
          <div className="h-64 flex items-center justify-center text-gray-400 border-2 border-dashed border-gray-200 rounded-lg">
            {t('analytics.student.activityEmpty')}
          </div>
        )}
      </div>
      
      {/* Motivational Insights */}
      <div className="bg-gradient-to-br from-purple-50 to-pink-50 rounded-lg border border-purple-100 p-6">
        <div className="flex items-start gap-4">
          <div className="rounded-full bg-purple-100 p-3">
            <SparklesIcon className="h-6 w-6 text-purple-600" />
          </div>
          <div>
            <h3 className="font-semibold text-gray-900 mb-2">{t('analytics.student.keepGoingTitle')}</h3>
            <p className="text-gray-700 text-sm">
                {sdtScores.overall == null && 'Motivation evidence unavailable.'}
                {sdtScores.overall != null && sdtScores.overall >= 80 && t('analytics.student.motivation.veryHigh')}
                {sdtScores.overall != null && sdtScores.overall >= 60 && sdtScores.overall < 80 && t('analytics.student.motivation.high')}
                {sdtScores.overall != null && sdtScores.overall >= 40 && sdtScores.overall < 60 && t('analytics.student.motivation.medium')}
                {sdtScores.overall != null && sdtScores.overall < 40 && t('analytics.student.motivation.low')}
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}

// ==================== HELPER FUNCTIONS ====================

function calculateStreaks(dates: Date[]): { currentStreak: number; longestStreak: number } {
  if (dates.length === 0) return { currentStreak: 0, longestStreak: 0 };
  
  // Sort dates
  const sortedDates = dates.sort((a, b) => b.getTime() - a.getTime());
  
  // Group by day (ignoring time)
  const daySet = new Set<string>();
  sortedDates.forEach(date => {
    const dayStr = date.toISOString().split('T')[0];
    daySet.add(dayStr);
  });
  
  const uniqueDays = Array.from(daySet).sort().reverse();
  
  // Calculate current streak
  let currentStreak = 0;
  const today = new Date().toISOString().split('T')[0];
  const yesterday = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString().split('T')[0];
  
  if (uniqueDays[0] === today || uniqueDays[0] === yesterday) {
    currentStreak = 1;
    for (let i = 1; i < uniqueDays.length; i++) {
      const prevDay = new Date(uniqueDays[i - 1]);
      prevDay.setDate(prevDay.getDate() - 1);
      if (uniqueDays[i] === prevDay.toISOString().split('T')[0]) {
        currentStreak++;
      } else {
        break;
      }
    }
  }
  
  // Calculate longest streak
  let longestStreak = 1;
  let tempStreak = 1;
  for (let i = 1; i < uniqueDays.length; i++) {
    const prevDay = new Date(uniqueDays[i - 1]);
    prevDay.setDate(prevDay.getDate() - 1);
    if (uniqueDays[i] === prevDay.toISOString().split('T')[0]) {
      tempStreak++;
      longestStreak = Math.max(longestStreak, tempStreak);
    } else {
      tempStreak = 1;
    }
  }
  
  return { currentStreak, longestStreak };
}

// ==================== HELPER COMPONENTS ====================

interface SDTScoreCardProps {
  title: string;
  subtitle: string;
  score: number | null;
  icon: React.ComponentType<{ className?: string }>;
  color: 'purple' | 'blue' | 'pink' | 'green';
}

function SDTScoreCard({ title, subtitle, score, icon: Icon, color }: SDTScoreCardProps) {
  const colorClasses = {
    purple: 'from-purple-500 to-purple-600',
    blue: 'from-blue-500 to-blue-600',
    pink: 'from-pink-500 to-pink-600',
    green: 'from-green-500 to-green-600'
  };
  
  const circumference = 2 * Math.PI * 40;
  const offset = circumference - ((score ?? 0) / 100) * circumference;
  
  return (
    <div className={`bg-gradient-to-br ${colorClasses[color]} rounded-lg p-6 text-white relative overflow-hidden`}>
      <div className="relative z-10">
        <div className="flex items-center justify-between mb-4">
          <div>
            <h3 className="text-lg font-semibold">{title}</h3>
            <p className="text-white/80 text-sm">{subtitle}</p>
          </div>
          <Icon className="h-8 w-8 text-white/70" />
        </div>
        
        <div className="flex items-center gap-4">
          <svg className="w-20 h-20">
            <circle cx="40" cy="40" r="35" fill="none" stroke="rgba(255,255,255,0.3)" strokeWidth="6" />
            <circle
              cx="40"
              cy="40"
              r="35"
              fill="none"
              stroke="white"
              strokeWidth="6"
              strokeDasharray={circumference}
              strokeDashoffset={offset}
              strokeLinecap="round"
              transform="rotate(-90 40 40)"
            />
            <text x="40" y="45" textAnchor="middle" fill="white" fontSize="18" fontWeight="bold">
              {score ?? 'N/A'}
            </text>
          </svg>
          
          <div className="text-2xl font-bold">{score != null ? `${score}%` : 'Unavailable'}</div>
        </div>
      </div>
    </div>
  );
}

interface StatCardProps {
  icon: React.ComponentType<{ className?: string }>;
  label: string;
  value: number | string;
  color: string;
}

function StatCard({ icon: Icon, label, value, color }: StatCardProps) {
  const colorClasses: Record<string, string> = {
    indigo: 'bg-indigo-100 text-indigo-600',
    green: 'bg-green-100 text-green-600',
    blue: 'bg-blue-100 text-blue-600',
    yellow: 'bg-yellow-100 text-yellow-600',
    pink: 'bg-pink-100 text-pink-600',
    orange: 'bg-orange-100 text-orange-600'
  };
  
  return (
    <div className="bg-white rounded-lg border border-gray-200 shadow-sm p-4">
      <div className={`inline-flex items-center justify-center w-10 h-10 rounded-full ${colorClasses[color]} mb-2`}>
        <Icon className="h-5 w-5" />
      </div>
      <p className="text-2xl font-bold text-gray-900">{value}</p>
      <p className="text-sm text-gray-600">{label}</p>
    </div>
  );
}

interface ActivityChartProps {
  data: ActivityData[];
  t: (key: string, interpolation?: Record<string, string | number>) => string;
}

function ActivityChart({ data, t }: ActivityChartProps) {
  const maxValue = Math.max(...data.flatMap(d => [d.autonomyEvents, d.competenceEvents, d.belongingEvents, d.reflectionEvents]));
  const chartHeight = 200;
  const barWidth = 40;
  const barGap = 8;
  
  return (
    <div className="overflow-x-auto">
      <svg width={data.length * (barWidth + barGap) + 40} height={chartHeight + 40} className="mx-auto">
        {/* Grid lines */}
        {[0, 25, 50, 75, 100].map(pct => (
          <line
            key={pct}
            x1="0"
            y1={chartHeight - (pct / 100) * chartHeight}
            x2={data.length * (barWidth + barGap)}
            y2={chartHeight - (pct / 100) * chartHeight}
            stroke="#e5e7eb"
            strokeWidth="1"
          />
        ))}
        
        {/* Bars */}
        {data.map((point, idx) => {
          const x = idx * (barWidth + barGap);
          const total = point.autonomyEvents + point.competenceEvents + point.belongingEvents + point.reflectionEvents;
          const barHeight = maxValue > 0 ? (total / maxValue) * chartHeight : 0;
          
          return (
            <g key={idx}>
              <rect
                x={x}
                y={chartHeight - barHeight}
                width={barWidth}
                height={barHeight}
                fill="#8b5cf6"
                rx="4"
              />
              <text
                x={x + barWidth / 2}
                y={chartHeight + 20}
                textAnchor="middle"
                fontSize="10"
                fill="#6b7280"
              >
                {point.date}
              </text>
            </g>
          );
        })}
      </svg>
      
      {/* Legend */}
      <div className="flex justify-center gap-4 mt-4 text-xs">
        <div className="flex items-center gap-1">
          <div className="w-3 h-3 rounded-full bg-purple-600" />
          <span>{t('analytics.student.totalActivity')}</span>
        </div>
      </div>
    </div>
  );
}
