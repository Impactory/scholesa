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
  engagementScore: number;
  autonomyScore: number;
  competenceScore: number;
  belongingScore: number;
  lastActive: Date;
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

  useEffect(() => {
    generateInsights();
  }, [learners, timeRange]);

  const generateInsights = () => {
    setLoading(true);
    const generatedInsights: AIInsight[] = [];

    // 1. Identify at-risk learners (engagement < 30%)
    const atRiskLearners = learners.filter(s => s.engagementScore < 30);
    if (atRiskLearners.length > 0) {
      generatedInsights.push({
        id: 'at-risk-alert',
        type: 'alert',
        priority: 'high',
        title: `${atRiskLearners.length} Learner${atRiskLearners.length > 1 ? 's' : ''} At Risk`,
        description: 'These learners show low engagement (< 30%) and may need immediate attention.',
        affectedLearners: atRiskLearners.map(s => s.learnerName),
        actionItems: [
          'Schedule one-on-one check-ins',
          'Review their mission history for blockers',
          'Adjust learning path to match interests'
        ]
      });
    }

    // 2. Identify learners with low autonomy (< 40%)
    const lowAutonomyLearners = learners.filter(s => s.autonomyScore < 40);
    if (lowAutonomyLearners.length > 0 && lowAutonomyLearners.length < learners.length * 0.5) {
      generatedInsights.push({
        id: 'low-autonomy',
        type: 'recommendation',
        priority: 'medium',
        title: 'Learners Need More Choice',
        description: `${lowAutonomyLearners.length} learners show low autonomy scores. They may benefit from more self-directed learning.`,
        affectedLearners: lowAutonomyLearners.map(s => s.learnerName),
        actionItems: [
          'Offer mission choice boards',
          'Encourage goal-setting activities',
          'Provide interest-based project options'
        ]
      });
    }

    // 3. Identify learners with low competence (< 40%)
    const lowCompetenceLearners = learners.filter(s => s.competenceScore < 40);
    if (lowCompetenceLearners.length > 0 && lowCompetenceLearners.length < learners.length * 0.5) {
      generatedInsights.push({
        id: 'low-competence',
        type: 'recommendation',
        priority: 'medium',
        title: 'Skill Mastery Support Needed',
        description: `${lowCompetenceLearners.length} learners need more skill-building opportunities.`,
        affectedLearners: lowCompetenceLearners.map(s => s.learnerName),
        actionItems: [
          'Provide scaffolded practice activities',
          'Celebrate small wins with badges',
          'Offer peer mentoring opportunities'
        ]
      });
    }

    // 4. Identify learners with low belonging (< 40%)
    const lowBelongingLearners = learners.filter(s => s.belongingScore < 40);
    if (lowBelongingLearners.length > 0 && lowBelongingLearners.length < learners.length * 0.5) {
      generatedInsights.push({
        id: 'low-belonging',
        type: 'recommendation',
        priority: 'medium',
        title: 'Community Connection Needed',
        description: `${lowBelongingLearners.length} learners show low belonging scores. They may feel isolated.`,
        affectedLearners: lowBelongingLearners.map(s => s.learnerName),
        actionItems: [
          'Facilitate peer collaboration activities',
          'Encourage showcase submissions',
          'Create recognition opportunities'
        ]
      });
    }

    // 5. Identify thriving learners (engagement > 80%)
    const thrivingLearners = learners.filter(s => s.engagementScore > 80);
    if (thrivingLearners.length > 0) {
      generatedInsights.push({
        id: 'thriving-learners',
        type: 'trend',
        priority: 'low',
        title: `${thrivingLearners.length} Learner${thrivingLearners.length > 1 ? 's' : ''} Thriving`,
        description: 'These learners show exceptional engagement across all SDT dimensions.',
        affectedLearners: thrivingLearners.map(s => s.learnerName),
        actionItems: [
          'Offer advanced challenges',
          'Invite them to mentor struggling peers',
          'Showcase their work as examples'
        ]
      });
    }

    // 6. Class-wide trend: Overall engagement
    const avgEngagement = learners.reduce((sum, s) => sum + s.engagementScore, 0) / learners.length || 0;
    if (avgEngagement < 50) {
      generatedInsights.push({
        id: 'class-engagement-low',
        type: 'alert',
        priority: 'high',
        title: 'Class Engagement Below Target',
        description: `Average class engagement is ${Math.round(avgEngagement)}%. Consider adjusting curriculum or pacing.`,
        actionItems: [
          'Survey learners about interests and challenges',
          'Introduce more variety in mission types',
          'Increase opportunities for student choice'
        ]
      });
    } else if (avgEngagement > 70) {
      generatedInsights.push({
        id: 'class-engagement-high',
        type: 'trend',
        priority: 'low',
        title: 'Strong Class Engagement',
        description: `Class is highly engaged (${Math.round(avgEngagement)}%). Keep up the great work!`,
        actionItems: [
          'Document successful strategies',
          'Share best practices with other educators',
          'Continue current approach'
        ]
      });
    }

    // 7. Inactive students (last active > 7 days ago)
    const now = new Date();
    const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
    const inactiveStudents = students.filter(s => s.lastActive < sevenDaysAgo);
    if (inactiveStudents.length > 0) {
      generatedInsights.push({
        id: 'inactive-students',
        type: 'alert',
        priority: 'high',
        title: `${inactiveStudents.length} Inactive Student${inactiveStudents.length > 1 ? 's' : ''}`,
        description: 'These students have not logged in for over a week.',
        affectedStudents: inactiveStudents.map(s => s.learnerName),
        actionItems: [
          'Send re-engagement email or message',
          'Contact parents/guardians',
          'Investigate potential barriers to access'
        ]
      });
    }

    // 8. SDT Balance recommendation
    const avgAutonomy = students.reduce((sum, s) => sum + s.autonomyScore, 0) / students.length || 0;
    const avgCompetence = students.reduce((sum, s) => sum + s.competenceScore, 0) / students.length || 0;
    const avgBelonging = students.reduce((sum, s) => sum + s.belongingScore, 0) / students.length || 0;
    
    const maxDimension = Math.max(avgAutonomy, avgCompetence, avgBelonging);
    const minDimension = Math.min(avgAutonomy, avgCompetence, avgBelonging);
    
    if (maxDimension - minDimension > 30) {
      let weakDimension = '';
      let recommendations: string[] = [];
      
      if (avgAutonomy === minDimension) {
        weakDimension = 'Autonomy';
        recommendations = [
          'Increase student choice in missions',
          'Allow learners to set personal goals',
          'Offer self-paced learning paths'
        ];
      } else if (avgCompetence === minDimension) {
        weakDimension = 'Competence';
        recommendations = [
          'Provide more skill-building checkpoints',
          'Celebrate mastery with badges',
          'Offer progressive challenges'
        ];
      } else {
        weakDimension = 'Belonging';
        recommendations = [
          'Increase peer collaboration opportunities',
          'Encourage showcase submissions',
          'Facilitate peer recognition activities'
        ];
      }
      
      generatedInsights.push({
        id: 'sdt-imbalance',
        type: 'recommendation',
        priority: 'medium',
        title: `${weakDimension} Dimension Needs Attention`,
        description: `Class shows strong ${maxDimension === avgAutonomy ? 'autonomy' : maxDimension === avgCompetence ? 'competence' : 'belonging'} but weaker ${weakDimension.toLowerCase()}.`,
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
          <h2 className="text-lg font-semibold text-gray-900">AI Insights</h2>
          <span className="ml-auto text-xs text-gray-500">
            {insights.length} insight{insights.length !== 1 ? 's' : ''}
          </span>
        </div>
      </div>
      
      <div className="p-6 space-y-4">
        {insights.length === 0 ? (
          <div className="text-center py-8">
            <LightbulbIcon className="h-12 w-12 text-gray-300 mx-auto mb-3" />
            <p className="text-gray-500">No insights available yet. Check back after students engage more with the platform.</p>
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
              {insight.priority}
            </span>
          </div>
          
          <p className="text-sm text-gray-700 mt-1">{insight.description}</p>
          
          {(insight.actionItems || insight.affectedLearners) && (
            <button
              onClick={() => setExpanded(!expanded)}
              className="text-sm text-indigo-600 hover:text-indigo-700 font-medium mt-2"
            >
              {expanded ? 'Show less' : 'Show details'}
            </button>
          )}
          
          {expanded && (
            <div className="mt-3 space-y-3">
              {insight.affectedLearners && insight.affectedLearners.length > 0 && (
                <div>
                  <p className="text-xs font-medium text-gray-500 mb-1">Affected Learners:</p>
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
                  <p className="text-xs font-semibold text-gray-700 mb-1">Recommended Actions:</p>
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
