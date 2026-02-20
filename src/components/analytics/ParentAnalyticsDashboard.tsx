'use client';

/**
 * Parent Analytics Dashboard
 * 
 * Shows parents their child's/children's:
 * - Overall engagement and progress
 * - SDT scores
 * - Recent activities and achievements
 * - Upcoming goals and deadlines
 * - Educator feedback
 */

import React, { useState, useEffect } from 'react';
import { useAuthContext } from '@/src/firebase/auth/AuthProvider';
import { db } from '@/src/firebase/client-init';
import { collection, query, where, getDocs, orderBy, limit } from 'firebase/firestore';
import {
  UserIcon,
  AwardIcon,
  TargetIcon,
  HeartIcon,
  BookOpenIcon,
  SparklesIcon,
  BellIcon
} from 'lucide-react';
import { usePageViewTracking } from '@/src/hooks/useTelemetry';

interface ChildData {
  childId: string;
  childName: string;
  engagementScore: number;
  autonomyScore: number;
  competenceScore: number;
  belongingScore: number;
  recentActivities: Activity[];
  upcomingGoals: Goal[];
  achievements: Achievement[];
}

interface Activity {
  id: string;
  type: string;
  description: string;
  timestamp: Date;
}

interface Goal {
  id: string;
  description: string;
  targetDate: Date;
  progress: number;
}

interface Achievement {
  id: string;
  title: string;
  type: 'badge' | 'checkpoint' | 'recognition';
  earnedAt: Date;
}

export function ParentAnalyticsDashboard() {
  usePageViewTracking('parent_dashboard');
  
  const { profile } = useAuthContext();
  const [children, setChildren] = useState<ChildData[]>([]);
  const [selectedChild, setSelectedChild] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  
  const siteId = profile?.activeSiteId || profile?.siteIds?.[0] || '';
  const parentId = profile?.uid || '';

  useEffect(() => {
    if (!parentId || !siteId) return;
    
    const fetchChildren = async () => {
      setLoading(true);
      try {
        // Fetch parent's children using parentIds array-contains query
        // Schema: User.parentIds is an array of parent user IDs
        const usersQuery = query(
          collection(db, 'users'),
          where('role', '==', 'learner'),
          where('siteIds', 'array-contains', siteId),
          where('parentIds', 'array-contains', parentId) // Find learners where parentId is in their parentIds array
        );
        const usersSnapshot = await getDocs(usersQuery);
        
        const childrenData: ChildData[] = [];
        
        for (const userDoc of usersSnapshot.docs) {
          const userData = userDoc.data();
          const childId = userDoc.id;
          const childName = userData.displayName || userData.email || 'Learner';
          
          // SDT scores will be fetched in real-time when child is selected
          // For list view, use cached engagement or fetch once
          const engagementScore = 0; // Placeholder, will update when selected
          
          // Initialize SDT scores as 0 for list view
          const autonomyScore = 0;
          const competenceScore = 0;
          const belongingScore = 0;
          
          // Fetch recent activities (now using real-time when selected)
          const eventsQuery = query(
            collection(db, 'telemetryEvents'),
            where('userId', '==', childId),
            where('siteId', '==', siteId),
            orderBy('timestamp', 'desc'),
            limit(10)
          );
          const eventsSnapshot = await getDocs(eventsQuery);
          const recentActivities: Activity[] = eventsSnapshot.docs.map(doc => {
            const data = doc.data();
            return {
              id: doc.id,
              type: data.eventName,
              description: getActivityDescription(data.eventName, data.metadata),
              timestamp: data.timestamp.toDate()
            };
          });
          
          // Fetch upcoming goals
          const goalsQuery = query(
            collection(db, 'learnerGoals'),
            where('userId', '==', childId),
            where('siteId', '==', siteId),
            where('status', '==', 'active'),
            orderBy('targetDate', 'asc'),
            limit(5)
          );
          const goalsSnapshot = await getDocs(goalsQuery);
          const upcomingGoals: Goal[] = goalsSnapshot.docs.map(doc => {
            const data = doc.data();
            return {
              id: doc.id,
              description: data.description,
              targetDate: data.targetDate.toDate(),
              progress: data.progress || 0
            };
          });
          
          // Fetch recent achievements (badges, checkpoints, recognition)
          const achievements: Achievement[] = [];
          
          // Badges
          const badgesQuery = query(
            collection(db, 'badgeAchievements'),
            where('userId', '==', childId),
            where('siteId', '==', siteId),
            orderBy('createdAt', 'desc'),
            limit(5)
          );
          const badgesSnapshot = await getDocs(badgesQuery);
          badgesSnapshot.docs.forEach(doc => {
            const data = doc.data();
            achievements.push({
              id: doc.id,
              title: data.badgeName || 'Badge Earned',
              type: 'badge',
              earnedAt: data.createdAt.toDate()
            });
          });
          
          childrenData.push({
            childId,
            childName,
            engagementScore,
            autonomyScore,
            competenceScore,
            belongingScore,
            recentActivities,
            upcomingGoals,
            achievements
          });
        }
        
        setChildren(childrenData);
        if (childrenData.length > 0 && !selectedChild) {
          setSelectedChild(childrenData[0].childId);
        }
        
      } catch (err) {
        console.error('Failed to load children data:', err);
      } finally {
        setLoading(false);
      }
    };
    
    fetchChildren();
  }, [parentId, siteId, selectedChild]);
  
  if (loading) {
    return (
      <div className="space-y-6 animate-pulse">
        <div className="h-32 bg-gray-200 rounded-lg" />
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          {[1,2,3].map(i => (
            <div key={i} className="h-48 bg-gray-200 rounded-lg" />
          ))}
        </div>
      </div>
    );
  }
  
  const currentChild = children.find(c => c.childId === selectedChild);
  
  if (!currentChild) {
    return (
      <div className="bg-white rounded-lg border border-gray-200 p-12 text-center">
        <UserIcon className="h-16 w-16 text-gray-300 mx-auto mb-4" />
        <p className="text-gray-500">No children found. Please contact your site administrator.</p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="bg-gradient-to-r from-blue-500 to-cyan-600 rounded-lg p-8 text-white">
        <h1 className="text-3xl font-bold mb-2">Parent Dashboard</h1>
        <p className="text-blue-100">Track your child's learning journey and celebrate their growth</p>
      </div>
      
      {/* Child Selector */}
      {children.length > 1 && (
        <div className="flex gap-2">
          {children.map(child => (
            <button
              key={child.childId}
              onClick={() => setSelectedChild(child.childId)}
              className={`px-4 py-2 rounded-lg font-medium transition ${
                selectedChild === child.childId
                  ? 'bg-indigo-600 text-white'
                  : 'bg-white text-gray-700 border border-gray-300 hover:bg-gray-50'
              }`}
            >
              {child.childName}
            </button>
          ))}
        </div>
      )}
      
      {/* SDT Overview */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <ScoreCard
          title="Overall Engagement"
          score={currentChild.engagementScore}
          color="indigo"
          icon={SparklesIcon}
        />
        <ScoreCard
          title="Autonomy"
          score={currentChild.autonomyScore}
          color="purple"
          icon={TargetIcon}
        />
        <ScoreCard
          title="Competence"
          score={currentChild.competenceScore}
          color="blue"
          icon={AwardIcon}
        />
        <ScoreCard
          title="Belonging"
          score={currentChild.belongingScore}
          color="pink"
          icon={HeartIcon}
        />
      </div>
      
      {/* Recent Activities */}
      <div className="bg-white rounded-lg border border-gray-200 shadow-sm overflow-hidden">
        <div className="px-6 py-4 border-b border-gray-200">
          <h2 className="text-lg font-semibold text-gray-900 flex items-center gap-2">
            <BookOpenIcon className="h-5 w-5" />
            Recent Activities
          </h2>
        </div>
        <div className="divide-y divide-gray-100">
          {currentChild.recentActivities.length === 0 ? (
            <div className="px-6 py-8 text-center text-gray-500">
              No recent activities. Encourage your child to start learning!
            </div>
          ) : (
            currentChild.recentActivities.map(activity => (
              <div key={activity.id} className="px-6 py-4 hover:bg-gray-50">
                <div className="flex items-start justify-between">
                  <div className="flex-1">
                    <p className="text-sm font-medium text-gray-900">{activity.description}</p>
                    <p className="text-xs text-gray-500 mt-1">
                      {formatRelativeTime(activity.timestamp)}
                    </p>
                  </div>
                </div>
              </div>
            ))
          )}
        </div>
      </div>
      
      {/* Upcoming Goals */}
      <div className="bg-white rounded-lg border border-gray-200 shadow-sm overflow-hidden">
        <div className="px-6 py-4 border-b border-gray-200">
          <h2 className="text-lg font-semibold text-gray-900 flex items-center gap-2">
            <TargetIcon className="h-5 w-5" />
            Learning Goals
          </h2>
        </div>
        <div className="p-6 space-y-4">
          {currentChild.upcomingGoals.length === 0 ? (
            <p className="text-gray-500 text-center py-4">
              No goals set yet. Help your child set learning goals!
            </p>
          ) : (
            currentChild.upcomingGoals.map(goal => (
              <div key={goal.id} className="border border-gray-200 rounded-lg p-4">
                <div className="flex items-start justify-between mb-2">
                  <p className="font-medium text-gray-900">{goal.description}</p>
                  <span className="text-xs text-gray-500">
                    Due: {goal.targetDate.toLocaleDateString()}
                  </span>
                </div>
                <div className="w-full bg-gray-200 rounded-full h-2 relative">
                  <div
                    className="bg-indigo-600 h-2 rounded-full transition-all absolute top-0 left-0"
                    data-progress={goal.progress}
                  />
                </div>
              </div>
            ))
          )}
        </div>
      </div>
      
      {/* Recent Achievements */}
      <div className="bg-white rounded-lg border border-gray-200 shadow-sm overflow-hidden">
        <div className="px-6 py-4 border-b border-gray-200">
          <h2 className="text-lg font-semibold text-gray-900 flex items-center gap-2">
            <AwardIcon className="h-5 w-5" />
            Recent Achievements
          </h2>
        </div>
        <div className="p-6">
          {currentChild.achievements.length === 0 ? (
            <p className="text-gray-500 text-center py-4">
              No achievements yet. Celebrate your child's first win!
            </p>
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              {currentChild.achievements.map(achievement => (
                <div key={achievement.id} className="flex items-start gap-3 p-4 bg-gradient-to-br from-yellow-50 to-orange-50 rounded-lg border border-yellow-200">
                  <div className="rounded-full bg-yellow-100 p-2">
                    <AwardIcon className="h-5 w-5 text-yellow-600" />
                  </div>
                  <div>
                    <p className="font-medium text-gray-900">{achievement.title}</p>
                    <p className="text-xs text-gray-600 mt-1">
                      {achievement.earnedAt.toLocaleDateString()}
                    </p>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
      
      {/* Engagement Insight */}
      <div className={`rounded-lg border p-6 ${
        currentChild.engagementScore >= 70
          ? 'bg-green-50 border-green-200'
          : currentChild.engagementScore >= 40
          ? 'bg-yellow-50 border-yellow-200'
          : 'bg-red-50 border-red-200'
      }`}>
        <div className="flex items-start gap-3">
          <BellIcon className={`h-6 w-6 ${
            currentChild.engagementScore >= 70
              ? 'text-green-600'
              : currentChild.engagementScore >= 40
              ? 'text-yellow-600'
              : 'text-red-600'
          }`} />
          <div>
            <h3 className="font-semibold text-gray-900 mb-1">
              {currentChild.engagementScore >= 70 && '🎉 Your child is thriving!'}
              {currentChild.engagementScore >= 40 && currentChild.engagementScore < 70 && '👍 Good progress'}
              {currentChild.engagementScore < 40 && '💪 Needs encouragement'}
            </h3>
            <p className="text-sm text-gray-700">
              {currentChild.engagementScore >= 70 && 'They are highly engaged and making excellent progress. Keep celebrating their wins!'}
              {currentChild.engagementScore >= 40 && currentChild.engagementScore < 70 && 'They are on the right track. Consider encouraging them to set new goals.'}
              {currentChild.engagementScore < 40 && 'They may need extra support. Talk to them about their interests and what they enjoy learning.'}
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}

// ==================== HELPER FUNCTIONS ====================

function getActivityDescription(eventName: string, _metadata: Record<string, unknown> | undefined): string {
  const descriptions: Record<string, string> = {
    'goal_set': 'Set a new learning goal',
    'checkpoint_passed': 'Passed a checkpoint',
    'badge_earned': 'Earned a badge',
    'recognition_given': 'Gave peer recognition',
    'recognition_received': 'Received peer recognition',
    'showcase_submitted': 'Submitted work to showcase',
    'reflection_submitted': 'Completed a reflection',
    'mission_selected': 'Started a new mission',
    'skill_mastered': 'Mastered a new skill'
  };
  
  return descriptions[eventName] || eventName.replace(/_/g, ' ');
}

function formatRelativeTime(date: Date): string {
  const now = new Date();
  const diffMs = now.getTime() - date.getTime();
  const diffMins = Math.floor(diffMs / 60000);
  const diffHours = Math.floor(diffMs / 3600000);
  const diffDays = Math.floor(diffMs / 86400000);
  
  if (diffMins < 1) return 'Just now';
  if (diffMins < 60) return `${diffMins} min${diffMins > 1 ? 's' : ''} ago`;
  if (diffHours < 24) return `${diffHours} hour${diffHours > 1 ? 's' : ''} ago`;
  if (diffDays < 7) return `${diffDays} day${diffDays > 1 ? 's' : ''} ago`;
  return date.toLocaleDateString();
}

// ==================== HELPER COMPONENTS ====================

interface ScoreCardProps {
  title: string;
  score: number;
  color: string;
  icon: React.ComponentType<{ className?: string }>;
}

function ScoreCard({ title, score, color, icon: Icon }: ScoreCardProps) {
  const colorClasses: Record<string, { bg: string; text: string; ring: string }> = {
    indigo: { bg: 'bg-indigo-100', text: 'text-indigo-700', ring: 'stroke-indigo-600' },
    purple: { bg: 'bg-purple-100', text: 'text-purple-700', ring: 'stroke-purple-600' },
    blue: { bg: 'bg-blue-100', text: 'text-blue-700', ring: 'stroke-blue-600' },
    pink: { bg: 'bg-pink-100', text: 'text-pink-700', ring: 'stroke-pink-600' }
  };
  
  const colors = colorClasses[color];
  const circumference = 2 * Math.PI * 35;
  const offset = circumference - (score / 100) * circumference;
  
  return (
    <div className="bg-white rounded-lg border border-gray-200 shadow-sm p-6">
      <div className={`inline-flex items-center justify-center w-12 h-12 rounded-full ${colors.bg} mb-3`}>
        <Icon className={`h-6 w-6 ${colors.text}`} />
      </div>
      <h3 className="font-semibold text-gray-900 mb-2">{title}</h3>
      
      <div className="flex items-center gap-3">
        <svg className="w-16 h-16">
          <circle cx="32" cy="32" r="28" fill="none" stroke="#e5e7eb" strokeWidth="5" />
          <circle
            cx="32"
            cy="32"
            r="28"
            fill="none"
            className={colors.ring}
            strokeWidth="5"
            strokeDasharray={circumference}
            strokeDashoffset={offset}
            strokeLinecap="round"
            transform="rotate(-90 32 32)"
          />
        </svg>
        <span className="text-3xl font-bold text-gray-900">{score}%</span>
      </div>
    </div>
  );
}
