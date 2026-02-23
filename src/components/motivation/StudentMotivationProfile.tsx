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
import { db } from '@/src/firebase/client-init';
import { collection, query, where, getDocs, orderBy, limit } from 'firebase/firestore';
import { TelemetryService } from '@/src/lib/telemetry/telemetryService';
import { GoalSettingForm } from '@/src/components/goals/GoalSettingForm';
import { 
  BrainIcon, 
  AwardIcon, 
  HeartIcon, 
  TargetIcon,
  SparklesIcon,
  TrendingUpIcon
} from 'lucide-react';
import { usePageViewTracking } from '@/src/hooks/useTelemetry';
import { useI18n } from '@/src/lib/i18n/useI18n';

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

type TranslateFn = (key: string, interpolation?: Record<string, string | number>) => string;

export function StudentMotivationProfile() {
  usePageViewTracking('learner_profile');
  
  const { profile } = useAuthContext();
  const { locale, t } = useI18n();
  const [sdtScores, setSDTScores] = useState<SDTScores | null>(null);
  const [skills, setSkills] = useState<SkillProgress[]>([]);
  const [badges, setBadges] = useState<Badge[]>([]);
  const [goals, setGoals] = useState<Goal[]>([]);
  const [recognitionCount, setRecognitionCount] = useState(0);
  const [loading, setLoading] = useState(true);
  const [showGoalForm, setShowGoalForm] = useState(false);
  
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
        
        // Fetch skills from skillMastery collection
        const skillsQuery = query(
          collection(db, 'skillMastery'),
          where('userId', '==', learnerId),
          where('siteId', '==', siteId),
          orderBy('lastUpdated', 'desc'),
          limit(10)
        );
        const skillsSnapshot = await getDocs(skillsQuery);
        const skillsData: SkillProgress[] = skillsSnapshot.docs.map(doc => {
          const data = doc.data();
          return {
            skillId: doc.id,
            skillName: data.skillName || t('motivation.unnamedSkill'),
            evidenceCount: data.evidenceCount || 0,
            level: data.masteryLevel || 'emerging'
          };
        });
        setSkills(skillsData);
        
        // Fetch badges from badgeAchievements collection
        const badgesQuery = query(
          collection(db, 'badgeAchievements'),
          where('userId', '==', learnerId),
          where('siteId', '==', siteId),
          orderBy('createdAt', 'desc'),
          limit(12)
        );
        const badgesSnapshot = await getDocs(badgesQuery);
        const badgesData: Badge[] = badgesSnapshot.docs.map(doc => {
          const data = doc.data();
          return {
            badgeId: doc.id,
            title: data.badgeName || t('motivation.badgeFallback'),
            description: data.description || '',
            earnedAt: data.createdAt?.toDate() || new Date(),
            iconEmoji: data.iconEmoji || '🏆'
          };
        });
        setBadges(badgesData);
        
        // Fetch goals from learnerGoals collection
        const goalsQuery = query(
          collection(db, 'learnerGoals'),
          where('userId', '==', learnerId),
          where('siteId', '==', siteId),
          where('status', '==', 'active'),
          orderBy('createdAt', 'desc'),
          limit(5)
        );
        const goalsSnapshot = await getDocs(goalsQuery);
        const goalsData: Goal[] = goalsSnapshot.docs.map(doc => {
          const data = doc.data();
          return {
            goalId: doc.id,
            description: data.description || t('motivation.goalFallback'),
            targetDate: data.targetDate?.toDate() || new Date(),
            progress: data.progress || 0
          };
        });
        setGoals(goalsData);
        
        // Fetch recognition count from recognitionBadges collection
        const recognitionQuery = query(
          collection(db, 'recognitionBadges'),
          where('recipientId', '==', learnerId),
          where('siteId', '==', siteId)
        );
        const recognitionSnapshot = await getDocs(recognitionQuery);
        setRecognitionCount(recognitionSnapshot.size);
        
      } catch (err) {
        console.error('Failed to load motivation profile:', err);
      } finally {
        setLoading(false);
      }
    };
    
    fetchProfile();
  }, [learnerId, siteId, t]);
  
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
        <p className="text-gray-500">{t('motivation.noData')}</p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="bg-gradient-to-r from-indigo-500 to-purple-600 rounded-lg p-8 text-white">
        <h1 className="text-3xl font-bold mb-2">{t('motivation.headerTitle')}</h1>
        <p className="text-indigo-100">{t('motivation.headerSubtitle')}</p>
      </div>
      
      {/* SDT Scores */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <SDTCard
          title={t('motivation.sdt.autonomy.title')}
          subtitle={t('motivation.sdt.autonomy.subtitle')}
          score={sdtScores.autonomy}
          icon={BrainIcon}
          color="purple"
        />
        <SDTCard
          title={t('motivation.sdt.competence.title')}
          subtitle={t('motivation.sdt.competence.subtitle')}
          score={sdtScores.competence}
          icon={AwardIcon}
          color="blue"
        />
        <SDTCard
          title={t('motivation.sdt.belonging.title')}
          subtitle={t('motivation.sdt.belonging.subtitle')}
          score={sdtScores.belonging}
          icon={HeartIcon}
          color="pink"
        />
        <SDTCard
          title={t('motivation.sdt.overall.title')}
          subtitle={t('motivation.sdt.overall.subtitle')}
          score={sdtScores.overall}
          icon={SparklesIcon}
          color="green"
        />
      </div>
      
      {/* Skills Mastery */}
      <div className="bg-white rounded-lg border border-gray-200 shadow-sm overflow-hidden">
        <div className="px-6 py-4 border-b border-gray-200">
          <h2 className="text-lg font-semibold text-gray-900">{t('motivation.skills.title')}</h2>
        </div>
        <div className="p-6">
          {skills.length === 0 ? (
            <p className="text-gray-500 text-center py-4">
              {t('motivation.skills.empty')}
            </p>
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              {skills.map(skill => (
                <SkillCard key={skill.skillId} skill={skill} t={t} />
              ))}
            </div>
          )}
        </div>
      </div>
      
      {/* Badges */}
      <div className="bg-white rounded-lg border border-gray-200 shadow-sm overflow-hidden">
        <div className="px-6 py-4 border-b border-gray-200">
          <h2 className="text-lg font-semibold text-gray-900">{t('motivation.badges.title')}</h2>
        </div>
        <div className="p-6">
          {badges.length === 0 ? (
            <p className="text-gray-500 text-center py-4">
              {t('motivation.badges.empty')}
            </p>
          ) : (
            <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
              {badges.map(badge => (
                <BadgeCard key={badge.badgeId} badge={badge} locale={locale} />
              ))}
            </div>
          )}
        </div>
      </div>
      
      {/* Goals */}
      <div className="bg-white rounded-lg border border-gray-200 shadow-sm overflow-hidden">
        <div className="px-6 py-4 border-b border-gray-200 flex items-center justify-between">
          <h2 className="text-lg font-semibold text-gray-900">{t('motivation.goals.title')}</h2>
          <button 
            onClick={() => setShowGoalForm(true)}
            className="px-4 py-2 text-sm bg-indigo-600 text-white rounded-md hover:bg-indigo-700"
          >
            {t('motivation.goals.setNew')}
          </button>
        </div>
        <div className="p-6">
          {goals.length === 0 ? (
            <p className="text-gray-500 text-center py-4">
              {t('motivation.goals.empty')}
            </p>
          ) : (
            <div className="space-y-4">
              {goals.map(goal => (
                <GoalCard key={goal.goalId} goal={goal} locale={locale} t={t} />
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
            <p className="text-gray-600">{t('motivation.recognitionCount')}</p>
          </div>
        </div>
      </div>
      
      {/* Goal Setting Modal */}
      {showGoalForm && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-lg max-w-md w-full">
            <GoalSettingForm 
              onClose={() => setShowGoalForm(false)}
              onGoalSet={(_goalId) => {
                // Refresh goals list
                setShowGoalForm(false);
                // In production, refetch goals from Firestore
              }}
            />
          </div>
        </div>
      )}
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
  t: TranslateFn;
}

function SkillCard({ skill, t }: SkillCardProps) {
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
          {t(`motivation.skillLevel.${skill.level}`)}
        </span>
      </div>
      <div className="flex items-center gap-2 text-sm text-gray-600">
        <TrendingUpIcon className="h-4 w-4" />
        <span>{t('motivation.evidenceCollected', { count: skill.evidenceCount })}</span>
      </div>
    </div>
  );
}

interface BadgeCardProps {
  badge: Badge;
  locale: string;
}

function BadgeCard({ badge, locale }: BadgeCardProps) {
  return (
    <div className="border border-gray-200 rounded-lg p-4 text-center hover:shadow-md transition">
      <div className="text-4xl mb-2">{badge.iconEmoji || '🏆'}</div>
      <h3 className="font-medium text-gray-900 text-sm mb-1">{badge.title}</h3>
      <p className="text-xs text-gray-500">{badge.earnedAt.toLocaleDateString(locale)}</p>
    </div>
  );
}

interface GoalCardProps {
  goal: Goal;
  locale: string;
  t: TranslateFn;
}

function GoalCard({ goal, locale, t }: GoalCardProps) {
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
          <p className="text-xs text-gray-500">
            {t('motivation.goalTargetDate', { date: goal.targetDate.toLocaleDateString(locale) })}
          </p>
        </div>
      </div>
    </div>
  );
}
