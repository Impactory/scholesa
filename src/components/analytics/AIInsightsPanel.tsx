'use client';

/**
 * AI Insights Panel for Educator Analytics
 * 
 * Provides AI-generated insights based on:
 * - Learner engagement patterns
 * - At-risk learner identification
 * - Intervention recommendations
 * - Class trends and predictions
 */

import React, { useState, useEffect } from 'react';
import { useInteractionTracking } from '@/src/hooks/useTelemetry';
import { useI18n } from '@/src/lib/i18n/useI18n';
import { 
  SparklesIcon, 
  TrendingUpIcon,
  AlertTriangleIcon,
  LightbulbIcon,
  TargetIcon
} from 'lucide-react';

interface LearnerData {
  learnerId: string;
  learnerName: string;
  engagementScore: number | null;
  autonomyScore: number | null;
  competenceScore: number | null;
  belongingScore: number | null;
  lastActive: Date | null;
  eventCount: number;
}

interface AIInsight {
  id: string;
  type: 'alert' | 'trend' | 'recommendation' | 'prediction';
  priority: 'high' | 'medium' | 'low';
  title: string;
  description: string;
  actionItems?: string[];
  affectedLearners?: string[];
}

interface AIInsightsPanelProps {
  learners: LearnerData[];
  timeRange: 'week' | 'month';
}

export function AIInsightsPanel({ learners, timeRange }: AIInsightsPanelProps) {
  const [insights, setInsights] = useState<AIInsight[]>([]);
  const [loading, setLoading] = useState(true);
  const { t } = useI18n();

  useEffect(() => {
    generateInsights();
  }, [learners, timeRange, t]);

  const generateInsights = () => {
    setLoading(true);
    const generatedInsights: AIInsight[] = [];
    const learnersWithEngagement = learners.filter((learner) => learner.engagementScore != null);
    const learnersWithAutonomy = learners.filter((learner) => learner.autonomyScore != null);
    const learnersWithCompetence = learners.filter((learner) => learner.competenceScore != null);
    const learnersWithBelonging = learners.filter((learner) => learner.belongingScore != null);

    if (learners.length === 0 || learnersWithEngagement.length === 0) {
      setInsights([]);
      setLoading(false);
      return;
    }

    // 1. Identify at-risk learners (engagement < 30%)
    const atRiskLearners = learnersWithEngagement.filter(s => (s.engagementScore as number) < 30);
    if (atRiskLearners.length > 0) {
      generatedInsights.push({
        id: 'at-risk-alert',
        type: 'alert',
        priority: 'high',
        title: t('aiInsights.atRisk.title', { count: atRiskLearners.length }),
        description: t('aiInsights.atRisk.description'),
        affectedLearners: atRiskLearners.map(s => s.learnerName),
        actionItems: [
          t('aiInsights.atRisk.actions.checkIn'),
          t('aiInsights.atRisk.actions.reviewHistory'),
          t('aiInsights.atRisk.actions.adjustPath'),
        ]
      });
    }

    // 2. Identify learners with low autonomy (< 40%)
    const lowAutonomyLearners = learnersWithAutonomy.filter(s => (s.autonomyScore as number) < 40);
    if (lowAutonomyLearners.length > 0 && lowAutonomyLearners.length < learnersWithAutonomy.length * 0.5) {
      generatedInsights.push({
        id: 'low-autonomy',
        type: 'recommendation',
        priority: 'medium',
        title: t('aiInsights.lowAutonomy.title'),
        description: t('aiInsights.lowAutonomy.description', { count: lowAutonomyLearners.length }),
        affectedLearners: lowAutonomyLearners.map(s => s.learnerName),
        actionItems: [
          t('aiInsights.lowAutonomy.actions.choiceBoards'),
          t('aiInsights.lowAutonomy.actions.goalSetting'),
          t('aiInsights.lowAutonomy.actions.projectOptions'),
        ]
      });
    }

    // 3. Identify learners with low competence (< 40%)
    const lowCompetenceLearners = learnersWithCompetence.filter(s => (s.competenceScore as number) < 40);
    if (lowCompetenceLearners.length > 0 && lowCompetenceLearners.length < learnersWithCompetence.length * 0.5) {
      generatedInsights.push({
        id: 'low-competence',
        type: 'recommendation',
        priority: 'medium',
        title: t('aiInsights.lowCompetence.title'),
        description: t('aiInsights.lowCompetence.description', { count: lowCompetenceLearners.length }),
        affectedLearners: lowCompetenceLearners.map(s => s.learnerName),
        actionItems: [
          t('aiInsights.lowCompetence.actions.scaffoldedPractice'),
          t('aiInsights.lowCompetence.actions.smallWins'),
          t('aiInsights.lowCompetence.actions.peerMentoring'),
        ]
      });
    }

    // 4. Identify learners with low belonging (< 40%)
    const lowBelongingLearners = learnersWithBelonging.filter(s => (s.belongingScore as number) < 40);
    if (lowBelongingLearners.length > 0 && lowBelongingLearners.length < learnersWithBelonging.length * 0.5) {
      generatedInsights.push({
        id: 'low-belonging',
        type: 'recommendation',
        priority: 'medium',
        title: t('aiInsights.lowBelonging.title'),
        description: t('aiInsights.lowBelonging.description', { count: lowBelongingLearners.length }),
        affectedLearners: lowBelongingLearners.map(s => s.learnerName),
        actionItems: [
          t('aiInsights.lowBelonging.actions.peerCollaboration'),
          t('aiInsights.lowBelonging.actions.showcase'),
          t('aiInsights.lowBelonging.actions.recognition'),
        ]
      });
    }

    // 5. Identify thriving learners (engagement > 80%)
    const thrivingLearners = learnersWithEngagement.filter(s => (s.engagementScore as number) > 80);
    if (thrivingLearners.length > 0) {
      generatedInsights.push({
        id: 'thriving-learners',
        type: 'trend',
        priority: 'low',
        title: t('aiInsights.thriving.title', { count: thrivingLearners.length }),
        description: t('aiInsights.thriving.description'),
        affectedLearners: thrivingLearners.map(s => s.learnerName),
        actionItems: [
          t('aiInsights.thriving.actions.advancedChallenges'),
          t('aiInsights.thriving.actions.mentorPeers'),
          t('aiInsights.thriving.actions.showcaseWork'),
        ]
      });
    }

    // 6. Class-wide trend: Overall engagement
    const avgEngagement = learnersWithEngagement.reduce((sum, s) => sum + (s.engagementScore as number), 0) / learnersWithEngagement.length;
    if (avgEngagement < 50) {
      generatedInsights.push({
        id: 'class-engagement-low',
        type: 'alert',
        priority: 'high',
        title: t('aiInsights.classLow.title'),
        description: t('aiInsights.classLow.description', { score: Math.round(avgEngagement) }),
        actionItems: [
          t('aiInsights.classLow.actions.survey'),
          t('aiInsights.classLow.actions.variety'),
          t('aiInsights.classLow.actions.choice'),
        ]
      });
    } else if (avgEngagement > 70) {
      generatedInsights.push({
        id: 'class-engagement-high',
        type: 'trend',
        priority: 'low',
        title: t('aiInsights.classHigh.title'),
        description: t('aiInsights.classHigh.description', { score: Math.round(avgEngagement) }),
        actionItems: [
          t('aiInsights.classHigh.actions.document'),
          t('aiInsights.classHigh.actions.share'),
          t('aiInsights.classHigh.actions.continue'),
        ]
      });
    }

    // 7. Inactive learners (last active > 7 days ago)
    const now = new Date();
    const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
    const inactiveStudents = learners.filter(s => s.lastActive && s.lastActive < sevenDaysAgo);
    if (inactiveStudents.length > 0) {
      generatedInsights.push({
        id: 'inactive-students',
        type: 'alert',
        priority: 'high',
        title: t('aiInsights.inactive.title', { count: inactiveStudents.length }),
        description: t('aiInsights.inactive.description'),
        affectedLearners: inactiveStudents.map(s => s.learnerName),
        actionItems: [
          t('aiInsights.inactive.actions.reengage'),
          t('aiInsights.inactive.actions.contactParents'),
          t('aiInsights.inactive.actions.investigateBarriers'),
        ]
      });
    }

    // 8. SDT Balance recommendation
    if (learnersWithAutonomy.length === 0 || learnersWithCompetence.length === 0 || learnersWithBelonging.length === 0) {
      setInsights(generatedInsights.sort((a, b) => {
        const priorityOrder = { high: 0, medium: 1, low: 2 };
        return priorityOrder[a.priority] - priorityOrder[b.priority];
      }));
      setLoading(false);
      return;
    }

    const avgAutonomy = learnersWithAutonomy.reduce((sum, s) => sum + (s.autonomyScore as number), 0) / learnersWithAutonomy.length;
    const avgCompetence = learnersWithCompetence.reduce((sum, s) => sum + (s.competenceScore as number), 0) / learnersWithCompetence.length;
    const avgBelonging = learnersWithBelonging.reduce((sum, s) => sum + (s.belongingScore as number), 0) / learnersWithBelonging.length;
    
    const maxDimension = Math.max(avgAutonomy, avgCompetence, avgBelonging);
    const minDimension = Math.min(avgAutonomy, avgCompetence, avgBelonging);
    
    if (maxDimension - minDimension > 30) {
      let weakDimensionKey: 'autonomy' | 'competence' | 'belonging' = 'belonging';
      let recommendations: string[] = [];
      
      if (avgAutonomy === minDimension) {
        weakDimensionKey = 'autonomy';
        recommendations = [
          t('aiInsights.sdtImbalance.actions.autonomy.choice'),
          t('aiInsights.sdtImbalance.actions.autonomy.goals'),
          t('aiInsights.sdtImbalance.actions.autonomy.selfPaced'),
        ];
      } else if (avgCompetence === minDimension) {
        weakDimensionKey = 'competence';
        recommendations = [
          t('aiInsights.sdtImbalance.actions.competence.checkpoints'),
          t('aiInsights.sdtImbalance.actions.competence.badges'),
          t('aiInsights.sdtImbalance.actions.competence.challenges'),
        ];
      } else {
        weakDimensionKey = 'belonging';
        recommendations = [
          t('aiInsights.sdtImbalance.actions.belonging.collaboration'),
          t('aiInsights.sdtImbalance.actions.belonging.showcase'),
          t('aiInsights.sdtImbalance.actions.belonging.recognition'),
        ];
      }

      const strongDimensionKey = maxDimension === avgAutonomy
        ? 'autonomy'
        : maxDimension === avgCompetence
          ? 'competence'
          : 'belonging';
      
      generatedInsights.push({
        id: 'sdt-imbalance',
        type: 'recommendation',
        priority: 'medium',
        title: t('aiInsights.sdtImbalance.title', {
          dimension: t(`aiInsights.dimension.${weakDimensionKey}`),
        }),
        description: t('aiInsights.sdtImbalance.description', {
          strong: t(`aiInsights.dimension.${strongDimensionKey}`),
          weak: t(`aiInsights.dimension.${weakDimensionKey}`),
        }),
        actionItems: recommendations
      });
    }

    setInsights(generatedInsights.sort((a, b) => {
      const priorityOrder = { high: 0, medium: 1, low: 2 };
      return priorityOrder[a.priority] - priorityOrder[b.priority];
    }));
    
    setLoading(false);
  };

  if (loading) {
    return (
      <div className="bg-white rounded-lg border border-gray-200 shadow-sm p-6 animate-pulse">
        <div className="h-6 bg-gray-200 rounded w-1/3 mb-4" />
        <div className="space-y-3">
          {[1, 2, 3].map(i => (
            <div key={i} className="h-20 bg-gray-100 rounded" />
          ))}
        </div>
      </div>
    );
  }

  return (
    <div className="bg-white rounded-lg border border-gray-200 shadow-sm overflow-hidden">
      <div className="px-6 py-4 border-b border-gray-200 bg-gradient-to-r from-indigo-50 to-purple-50">
        <div className="flex items-center gap-2">
          <SparklesIcon className="h-5 w-5 text-indigo-600" />
          <h2 className="text-lg font-semibold text-gray-900">{t('aiInsights.panelTitle')}</h2>
          <span className="ml-auto text-xs text-gray-500">
            {t('aiInsights.countLabel', { count: insights.length })}
          </span>
        </div>
      </div>
      
      <div className="p-6 space-y-4">
        {insights.length === 0 ? (
          <div className="text-center py-8">
            <LightbulbIcon className="h-12 w-12 text-gray-300 mx-auto mb-3" />
            <p className="text-gray-500">{t('aiInsights.empty')}</p>
          </div>
        ) : (
          insights.map(insight => (
            <InsightCard key={insight.id} insight={insight} />
          ))
        )}
      </div>
    </div>
  );
}

// ==================== HELPER COMPONENTS ====================

interface InsightCardProps {
  insight: AIInsight;
}

function InsightCard({ insight }: InsightCardProps) {
  const [expanded, setExpanded] = useState(false);
  const trackInteraction = useInteractionTracking();
  const { t } = useI18n();
  
  const iconMap = {
    alert: AlertTriangleIcon,
    trend: TrendingUpIcon,
    recommendation: LightbulbIcon,
    prediction: TargetIcon
  };
  
  const colorMap = {
    high: 'border-red-200 bg-red-50',
    medium: 'border-yellow-200 bg-yellow-50',
    low: 'border-green-200 bg-green-50'
  };
  
  const iconColorMap = {
    high: 'text-red-600',
    medium: 'text-yellow-600',
    low: 'text-green-600'
  };
  
  const Icon = iconMap[insight.type];
  
  return (
    <div className={`border rounded-lg p-4 ${colorMap[insight.priority]}`}>
      <div className="flex items-start gap-3">
        <Icon className={`h-5 w-5 mt-0.5 ${iconColorMap[insight.priority]}`} />
        <div className="flex-1">
          <div className="flex items-start justify-between">
            <h3 className="font-semibold text-gray-900">{insight.title}</h3>
            <span className={`text-xs font-medium px-2 py-1 rounded ${
              insight.priority === 'high' ? 'bg-red-100 text-red-700' :
              insight.priority === 'medium' ? 'bg-yellow-100 text-yellow-700' :
              'bg-green-100 text-green-700'
            }`}>
              {t(`aiInsights.priority.${insight.priority}`)}
            </span>
          </div>
          
          <p className="text-sm text-gray-700 mt-1">{insight.description}</p>
          
          {(insight.actionItems || insight.affectedLearners) && (
            <button
              onClick={() => {
                trackInteraction('feature_discovered', {
                  cta: expanded ? 'ai_insight_show_less' : 'ai_insight_show_details',
                  insightId: insight.id,
                  insightType: insight.type,
                  priority: insight.priority,
                });
                setExpanded(!expanded);
              }}
              className="text-sm text-indigo-600 hover:text-indigo-700 font-medium mt-2"
            >
              {expanded ? t('aiInsights.showLess') : t('aiInsights.showDetails')}
            </button>
          )}
          
          {expanded && (
            <div className="mt-3 space-y-3">
              {insight.affectedLearners && insight.affectedLearners.length > 0 && (
                <div>
                  <p className="text-xs font-medium text-gray-500 mb-1">{t('aiInsights.affectedLearners')}</p>
                  <div className="flex flex-wrap gap-1">
                    {insight.affectedLearners.map((name, idx) => (
                      <span key={idx} className="text-xs bg-white px-2 py-1 rounded border border-gray-200">
                        {name}
                      </span>
                    ))}
                  </div>
                </div>
              )}
              
              {insight.actionItems && insight.actionItems.length > 0 && (
                <div>
                  <p className="text-xs font-semibold text-gray-700 mb-1">{t('aiInsights.recommendedActions')}</p>
                  <ul className="space-y-1">
                    {insight.actionItems.map((action, idx) => (
                      <li key={idx} className="text-xs text-gray-700 flex items-start gap-2">
                        <span className="text-indigo-600 mt-0.5">•</span>
                        <span>{action}</span>
                      </li>
                    ))}
                  </ul>
                </div>
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
