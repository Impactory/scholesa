'use client';

/**
 * Student Motivation Profile
 * 
 * Shows learner's:
 * - SDT scores (autonomy, competence, belonging)
 * - Skills mastered
 * - Badges earned
 * - Recognition received
 * - Learning goals
 * - Reflection timeline
 */

import React, { useState, useEffect } from 'react';
import { useAuthContext } from '@/src/firebase/auth/AuthProvider';
import { TelemetryService } from '@/src/lib/telemetry/telemetryService';
import { 
  BrainIcon, 
  AwardIcon, 
  HeartIcon, 
  TargetIcon,
  SparklesIcon,
  TrendingUpIcon
} from 'lucide-react';
import { usePageViewTracking } from '@/src/hooks/useTelemetry';

interface SDTScores {
  autonomy: number;
  competence: number;
  belonging: number;
  overall: number;
}

interface SkillProgress {
  skillId: string;
  skillName: string;
  evidenceCount: number;
  level: 'emerging' | 'developing' | 'proficient' | 'mastery';
}

interface Badge {
  badgeId: string;
  title: string;
  description: string;
  earnedAt: Date;
  iconEmoji?: string;
}

interface Goal {
  goalId: string;
  description: string;
  targetDate: Date;
  progress: number; // 0-100
}

export function StudentMotivationProfile() {
  usePageViewTracking('learner_profile');
  
  const { profile } = useAuthContext();
  const [sdtScores, setSDTScores] = useState<SDTScores | null>(null);
  const [skills, setSkills] = useState<SkillProgress[]>([]);
  const [badges, setBadges] = useState<Badge[]>([]);
  const [goals, setGoals] = useState<Goal[]>([]);
  const [recognitionCount, setRecognitionCount] = useState(0);
  const [loading, setLoading] = useState(true);
  
  const learnerId = profile?.uid || '';
  const siteId = profile?.activeSiteId || profile?.siteIds?.[0] || '';

  useEffect(() => {
    if (!learnerId || !siteId) return;
    
    const fetchProfile = async () => {
      setLoading(true);
      try {
        // Fetch SDT scores from telemetry
        const rawScores = await TelemetryService.getSDTProfile(learnerId, siteId);
        const overall = Math.round((rawScores.autonomy + rawScores.competence + rawScores.belonging) / 3);
        setSDTScores({ ...rawScores, overall });
        
        // Fetch mastery data from CompetenceEngine
        // For now, use summary stats (detailed skills/badges require additional Firestore queries)
        // TODO: Query skillMastery and recognitionBadges collections directly for detailed lists
        setSkills([]);
        setBadges([]);
        
        // Fetch goals from AutonomyEngine
        // TODO: Implement getGoals() method and query learnerGoals collection
        setGoals([]);
        
        // Fetch recognition count from BelongingEngine
        // TODO: Query recognitionBadges collection
        setRecognitionCount(0);
        
      } catch (err) {
        console.error('Failed to load motivation profile:', err);
      } finally {
        setLoading(false);
      }
    };
    
    fetchProfile();
  }, [learnerId, siteId]);
  
  if (loading) {
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
  
  if (!sdtScores) {
    return (
      <div className="bg-white rounded-lg border border-gray-200 p-8 text-center">
        <p className="text-gray-500">No data available yet. Start learning to see your progress!</p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="bg-gradient-to-r from-indigo-500 to-purple-600 rounded-lg p-8 text-white">
        <h1 className="text-3xl font-bold mb-2">My Learning Journey</h1>
        <p className="text-indigo-100">Track your growth, skills, and achievements</p>
      </div>
      
      {/* SDT Scores */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <SDTCard
          title="Autonomy"
          subtitle="Your Choices"
          score={sdtScores.autonomy}
          icon={BrainIcon}
          color="purple"
        />
        <SDTCard
          title="Competence"
          subtitle="Skills Mastered"
          score={sdtScores.competence}
          icon={AwardIcon}
          color="blue"
        />
        <SDTCard
          title="Belonging"
          subtitle="Community"
          score={sdtScores.belonging}
          icon={HeartIcon}
          color="pink"
        />
        <SDTCard
          title="Overall"
          subtitle="Total Score"
          score={sdtScores.overall}
          icon={SparklesIcon}
          color="green"
        />
      </div>
      
      {/* Skills Mastery */}
      <div className="bg-white rounded-lg border border-gray-200 shadow-sm overflow-hidden">
        <div className="px-6 py-4 border-b border-gray-200">
          <h2 className="text-lg font-semibold text-gray-900">Skills I'm Developing</h2>
        </div>
        <div className="p-6">
          {skills.length === 0 ? (
            <p className="text-gray-500 text-center py-4">
              No skills tracked yet. Complete missions to build your skill profile!
            </p>
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              {skills.map(skill => (
                <SkillCard key={skill.skillId} skill={skill} />
              ))}
            </div>
          )}
        </div>
      </div>
      
      {/* Badges */}
      <div className="bg-white rounded-lg border border-gray-200 shadow-sm overflow-hidden">
        <div className="px-6 py-4 border-b border-gray-200">
          <h2 className="text-lg font-semibold text-gray-900">Badges Earned</h2>
        </div>
        <div className="p-6">
          {badges.length === 0 ? (
            <p className="text-gray-500 text-center py-4">
              No badges earned yet. Keep learning to unlock achievements!
            </p>
          ) : (
            <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
              {badges.map(badge => (
                <BadgeCard key={badge.badgeId} badge={badge} />
              ))}
            </div>
          )}
        </div>
      </div>
      
      {/* Goals */}
      <div className="bg-white rounded-lg border border-gray-200 shadow-sm overflow-hidden">
        <div className="px-6 py-4 border-b border-gray-200 flex items-center justify-between">
          <h2 className="text-lg font-semibold text-gray-900">My Learning Goals</h2>
          <button className="px-4 py-2 text-sm bg-indigo-600 text-white rounded-md hover:bg-indigo-700">
            + Set New Goal
          </button>
        </div>
        <div className="p-6">
          {goals.length === 0 ? (
            <p className="text-gray-500 text-center py-4">
              No goals set yet. Set goals to guide your learning journey!
            </p>
          ) : (
            <div className="space-y-4">
              {goals.map(goal => (
                <GoalCard key={goal.goalId} goal={goal} />
              ))}
            </div>
          )}
        </div>
      </div>
      
      {/* Recognition Stats */}
      <div className="bg-white rounded-lg border border-gray-200 shadow-sm p-6">
        <div className="flex items-center gap-4">
          <div className="rounded-full bg-pink-100 p-4">
            <HeartIcon className="h-8 w-8 text-pink-600" />
          </div>
          <div>
            <p className="text-2xl font-bold text-gray-900">{recognitionCount}</p>
            <p className="text-gray-600">Times recognized by peers</p>
          </div>
        </div>
      </div>
    </div>
  );
}

// ==================== HELPER COMPONENTS ====================

interface SDTCardProps {
  title: string;
  subtitle: string;
  score: number;
  icon: React.ComponentType<{ className?: string }>;
  color: 'purple' | 'blue' | 'pink' | 'green';
}

function SDTCard({ title, subtitle, score, icon: Icon, color }: SDTCardProps) {
  const colorClasses = {
    purple: 'from-purple-500 to-purple-600',
    blue: 'from-blue-500 to-blue-600',
    pink: 'from-pink-500 to-pink-600',
    green: 'from-green-500 to-green-600'
  };
  
  const ringColorClasses = {
    purple: 'stroke-purple-600',
    blue: 'stroke-blue-600',
    pink: 'stroke-pink-600',
    green: 'stroke-green-600'
  };
  
  const circumference = 2 * Math.PI * 45; // r=45
  const offset = circumference - (score / 100) * circumference;
  
  return (
    <div className={`bg-gradient-to-br ${colorClasses[color]} rounded-lg p-6 text-white`}>
      <div className="flex items-center justify-between mb-4">
        <div>
          <h3 className="text-lg font-semibold">{title}</h3>
          <p className="text-white/80 text-sm">{subtitle}</p>
        </div>
        <Icon className="h-8 w-8 opacity-80" />
      </div>
      
      <div className="relative w-28 h-28 mx-auto">
        <svg className="rotate-[-90deg]" width="112" height="112">
          <circle
            cx="56"
            cy="56"
            r="45"
            stroke="currentColor"
            strokeWidth="8"
            fill="none"
            className="opacity-20"
          />
          <circle
            cx="56"
            cy="56"
            r="45"
            stroke="currentColor"
            strokeWidth="8"
            fill="none"
            className={ringColorClasses[color]}
            strokeDasharray={circumference}
            strokeDashoffset={offset}
            strokeLinecap="round"
          />
        </svg>
        <div className="absolute inset-0 flex items-center justify-center">
          <span className="text-3xl font-bold">{score}%</span>
        </div>
      </div>
    </div>
  );
}

interface SkillCardProps {
  skill: SkillProgress;
}

function SkillCard({ skill }: SkillCardProps) {
  const levelColors = {
    emerging: 'bg-gray-100 text-gray-800',
    developing: 'bg-yellow-100 text-yellow-800',
    proficient: 'bg-blue-100 text-blue-800',
    mastery: 'bg-green-100 text-green-800'
  };
  
  return (
    <div className="border border-gray-200 rounded-lg p-4 hover:shadow-md transition">
      <div className="flex items-start justify-between mb-2">
        <h3 className="font-medium text-gray-900">{skill.skillName}</h3>
        <span className={`px-2 py-1 text-xs font-medium rounded-full ${levelColors[skill.level]}`}>
          {skill.level}
        </span>
      </div>
      <div className="flex items-center gap-2 text-sm text-gray-600">
        <TrendingUpIcon className="h-4 w-4" />
        <span>{skill.evidenceCount} evidence collected</span>
      </div>
    </div>
  );
}

interface BadgeCardProps {
  badge: Badge;
}

function BadgeCard({ badge }: BadgeCardProps) {
  return (
    <div className="border border-gray-200 rounded-lg p-4 text-center hover:shadow-md transition">
      <div className="text-4xl mb-2">{badge.iconEmoji || '🏆'}</div>
      <h3 className="font-medium text-gray-900 text-sm mb-1">{badge.title}</h3>
      <p className="text-xs text-gray-500">{badge.earnedAt.toLocaleDateString()}</p>
    </div>
  );
}

interface GoalCardProps {
  goal: Goal;
}

function GoalCard({ goal }: GoalCardProps) {
  return (
    <div className="border border-gray-200 rounded-lg p-4">
      <div className="flex items-start gap-3">
        <TargetIcon className="h-5 w-5 text-indigo-600 mt-0.5 flex-shrink-0" />
        <div className="flex-1">
          <p className="font-medium text-gray-900 mb-2">{goal.description}</p>
          <div className="flex items-center gap-2 mb-1">
            <div className="flex-1 h-2 bg-gray-200 rounded-full">
              <div 
                className="h-full bg-indigo-600 rounded-full transition-all"
                data-progress={goal.progress}
              >
                <style jsx>{`
                  div[data-progress="${goal.progress}"] {
                    width: ${goal.progress}%;
                  }
                `}</style>
              </div>
            </div>
            <span className="text-sm font-medium text-gray-700">{goal.progress}%</span>
          </div>
          <p className="text-xs text-gray-500">Target: {goal.targetDate.toLocaleDateString()}</p>
        </div>
      </div>
    </div>
  );
}
