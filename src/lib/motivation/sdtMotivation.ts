/**
 * SDT Motivation Service
 * 
 * Self-Determination Theory framework for the Scholesa Motivation Engine
 * Autonomy + Competence + Belonging = Intrinsic Motivation
 */

import { getFunctions, httpsCallable } from 'firebase/functions';
import type {
  DifficultyLevel,
  AgeBand,
  CrewRole,
  RecognitionType,
  SprintSession,
  ReflectionEntry,
  WeeklyGoal,
  ShowcaseSubmission,
  SkillEvidence,
  AICoachInteraction,
  MotivationAnalytics
} from '@/src/types/schema';

const functions = getFunctions();

// ===== TYPES =====

export interface MissionOption {
  id: string;
  title: string;
  difficultyLevel: DifficultyLevel;
  theme: string;
  estimatedMinutes: number;
  microSkillIds: string[];
  successCriterion: string;
}

export interface DashboardData {
  todaysMission?: {
    id: string;
    title: string;
    difficultyLevel: DifficultyLevel;
    progress: number;
  };
  streak: {
    current: number;
    best: number;
    attendanceStreak: number;
    effortStreak: number;
  };
  nextCheckpoint?: {
    sprintId: string;
    checkpointNumber: number;
    dueAt: Date;
  };
  quickResumeAvailable: boolean;
  unreadFeedback: number;
  pendingReflections: number;
}

export interface LearningPathProgress {
  unitId: string;
  unitName: string;
  missionsTotal: number;
  missionsCompleted: number;
  microSkillsProven: string[];
  microSkillsInProgress: string[];
  isLocked: boolean;
  nextMission?: {
    id: string;
    title: string;
    difficultyLevel: DifficultyLevel;
  };
}

export interface ProgressInsights {
  skillsProven: number;
  skillsInProgress: number;
  badgesEarned: number;
  suggestedNextMissions: MissionOption[];
  motivationProfile: {
    strongestMotivators: string[];
    engagementLevel: string;
    preferredDifficulty: DifficultyLevel;
  };
}

export interface AICoachRequest {
  mode: 'hint' | 'rubric_check' | 'debug' | 'critique';
  studentQuestion: string;
  context?: {
    missionId?: string;
    sprintId?: string;
    codeSnippet?: string;
  };
}

export interface AICoachResponse {
  response: string;
  requiresExplainBack: boolean;
  suggestedNextSteps?: string[];
  rubricAlignment?: {
    criterion: string;
    currentLevel: string;
    targetLevel: string;
    gap: string;
  }[];
}

// ===== LABELS & CONSTANTS =====

export const DIFFICULTY_LABELS: Record<DifficultyLevel, string> = {
  bronze: 'Bronze Challenge',
  silver: 'Silver Challenge',
  gold: 'Gold Challenge'
};

export const DIFFICULTY_EMOJI: Record<DifficultyLevel, string> = {
  bronze: '🥉',
  silver: '🥈',
  gold: '🥇'
};

export const DIFFICULTY_COLORS: Record<DifficultyLevel, string> = {
  bronze: 'bg-orange-100 text-orange-800 border-orange-300',
  silver: 'bg-gray-100 text-gray-800 border-gray-300',
  gold: 'bg-yellow-100 text-yellow-800 border-yellow-300'
};

export const CREW_ROLE_LABELS: Record<CrewRole, string> = {
  builder: 'Builder',
  tester: 'Tester',
  reporter: 'Reporter'
};

export const CREW_ROLE_EMOJI: Record<CrewRole, string> = {
  builder: '🔨',
  tester: '🔍',
  reporter: '📢'
};

export const RECOGNITION_LABELS: Record<RecognitionType, string> = {
  helper: 'Helper',
  debugger: 'Debugger',
  clear_communicator: 'Clear Communicator',
  courage_to_try: 'Courage to Try'
};

export const RECOGNITION_EMOJI: Record<RecognitionType, string> = {
  helper: '🤝',
  debugger: '🐛',
  clear_communicator: '💬',
  courage_to_try: '🦁'
};

// ===== SDT MOTIVATION SERVICE =====

class SDTMotivationService {
  // === AUTONOMY MODULE ===
  
  /**
   * Get mission options for learner to choose from (autonomy)
   */
  async getMissionOptions(
    learnerId: string,
    siteId: string,
    sessionOccurrenceId?: string
  ): Promise<MissionOption[]> {
    const callable = httpsCallable<
      { learnerId: string; siteId: string; sessionOccurrenceId?: string },
      { options: MissionOption[] }
    >(functions, 'getMissionOptions');
    
    const result = await callable({ learnerId, siteId, sessionOccurrenceId });
    return result.data.options;
  }
  
  /**
   * Learner selects a mission variant
   */
  async selectMission(
    learnerId: string,
    siteId: string,
    missionVariantId: string,
    reason?: string
  ): Promise<{ sprintSessionId: string }> {
    const callable = httpsCallable<
      { learnerId: string; siteId: string; missionVariantId: string; reason?: string },
      { sprintSessionId: string }
    >(functions, 'selectMission');
    
    const result = await callable({ learnerId, siteId, missionVariantId, reason });
    return result.data;
  }
  
  /**
   * Update learner interest profile
   */
  async updateInterests(
    learnerId: string,
    siteId: string,
    interests: string[]
  ): Promise<void> {
    const callable = httpsCallable(functions, 'updateLearnerInterests');
    await callable({ learnerId, siteId, interests });
  }
  
  /**
   * Set a weekly goal (autonomy)
   */
  async setWeeklyGoal(
    learnerId: string,
    siteId: string,
    cycleId: string,
    goalType: WeeklyGoal['goalType'],
    goalText: string,
    targetCount?: number
  ): Promise<{ goalId: string }> {
    const callable = httpsCallable<any, { goalId: string }>(functions, 'setWeeklyGoal');
    const result = await callable({ learnerId, siteId, cycleId, goalType, goalText, targetCount });
    return result.data;
  }
  
  // === COMPETENCE MODULE ===
  
  /**
   * Submit skill evidence (micro-skill mastery)
   */
  async submitSkillEvidence(
    learnerId: string,
    siteId: string,
    microSkillId: string,
    evidenceType: SkillEvidence['evidenceType'],
    artifactUrl: string,
    description: string,
    locationInWork: string,
    selfScore: SkillEvidence['selfScore']
  ): Promise<{ evidenceId: string }> {
    const callable = httpsCallable<any, { evidenceId: string }>(functions, 'submitSkillEvidence');
    const result = await callable({
      learnerId,
      siteId,
      microSkillId,
      evidenceType,
      artifactUrl,
      description,
      locationInWork,
      selfScore
    });
    return result.data;
  }
  
  /**
   * Get progress insights (visible mastery)
   */
  async getProgressInsights(
    learnerId: string,
    siteId: string
  ): Promise<ProgressInsights> {
    const callable = httpsCallable<
      { learnerId: string; siteId: string },
      ProgressInsights
    >(functions, 'getProgressInsights');
    
    const result = await callable({ learnerId, siteId });
    return result.data;
  }
  
  /**
   * Submit checkpoint (fast feedback)
   */
  async submitCheckpoint(
    sprintSessionId: string,
    learnerId: string,
    siteId: string,
    checkpointNumber: number,
    uploadUrl: string,
    explainItBack: string
  ): Promise<{
    checkpointId: string;
    feedback: string;
    nextStep?: string;
    passed: boolean;
  }> {
    const callable = httpsCallable<any, any>(functions, 'submitCheckpoint');
    const result = await callable({
      sprintSessionId,
      learnerId,
      siteId,
      checkpointNumber,
      uploadUrl,
      explainItBack
    });
    return result.data;
  }
  
  // === BELONGING MODULE ===
  
  /**
   * Submit showcase (team visibility + recognition)
   */
  async submitShowcase(
    learnerId: string,
    siteId: string,
    sprintSessionId: string,
    title: string,
    artifactType: ShowcaseSubmission['artifactType'],
    artifactUrl: string,
    description: string,
    microSkillIds: string[],
    visibleToCrew: boolean,
    visibleToSite: boolean
  ): Promise<{ showcaseId: string }> {
    const callable = httpsCallable<any, { showcaseId: string }>(functions, 'submitShowcase');
    const result = await callable({
      learnerId,
      siteId,
      sprintSessionId,
      title,
      artifactType,
      artifactUrl,
      description,
      microSkillIds,
      visibleToCrew,
      visibleToSite
    });
    return result.data;
  }
  
  /**
   * Give recognition to peer
   */
  async giveRecognition(
    fromLearnerId: string,
    toLearnerId: string,
    siteId: string,
    showcaseId: string,
    recognitionType: RecognitionType,
    comment?: string
  ): Promise<void> {
    const callable = httpsCallable(functions, 'giveRecognition');
    await callable({
      fromLearnerId,
      toLearnerId,
      siteId,
      showcaseId,
      recognitionType,
      comment
    });
  }
  
  /**
   * Submit peer feedback (I like, I wonder, Next step)
   */
  async submitPeerFeedback(
    fromLearnerId: string,
    toLearnerId: string,
    siteId: string,
    showcaseId: string,
    iLike: string,
    iWonder: string,
    nextStep: string
  ): Promise<{ feedbackId: string }> {
    const callable = httpsCallable<any, { feedbackId: string }>(functions, 'submitPeerFeedback');
    const result = await callable({
      fromLearnerId,
      toLearnerId,
      siteId,
      showcaseId,
      iLike,
      iWonder,
      nextStep
    });
    return result.data;
  }
  
  // === REFLECTION (IDENTITY) ===
  
  /**
   * Submit reflection ("I'm proud of... Next I will...")
   */
  async submitReflection(
    learnerId: string,
    siteId: string,
    proudOf: string,
    nextIWill: string,
    sprintSessionId?: string,
    missionId?: string,
    effortLevel?: 1 | 2 | 3 | 4 | 5,
    enjoymentLevel?: 1 | 2 | 3 | 4 | 5,
    effectiveStrategy?: string
  ): Promise<{ reflectionId: string }> {
    const callable = httpsCallable<any, { reflectionId: string }>(functions, 'submitReflection');
    const result = await callable({
      learnerId,
      siteId,
      proudOf,
      nextIWill,
      sprintSessionId,
      missionId,
      effortLevel,
      enjoymentLevel,
      effectiveStrategy
    });
    return result.data;
  }
  
  // === AI COACH ===
  
  /**
   * Request AI coach help (with guardrails)
   */
  async requestAICoach(
    learnerId: string,
    siteId: string,
    request: AICoachRequest
  ): Promise<AICoachResponse> {
    const callable = httpsCallable<
      AICoachRequest & { learnerId: string; siteId: string },
      AICoachResponse
    >(functions, 'requestAICoach');
    
    const result = await callable({ ...request, learnerId, siteId });
    return result.data;
  }
  
  /**
   * Submit explain-it-back response
   */
  async submitExplainBack(
    learnerId: string,
    siteId: string,
    interactionId: string,
    explainBack: string
  ): Promise<{ approved: boolean; feedback?: string }> {
    const callable = httpsCallable<any, any>(functions, 'submitExplainBack');
    const result = await callable({ learnerId, siteId, interactionId, explainBack });
    return result.data;
  }
  
  // === DASHBOARD DATA ===
  
  /**
   * Get learner dashboard data
   */
  async getDashboardData(
    learnerId: string,
    siteId: string
  ): Promise<DashboardData> {
    const callable = httpsCallable<
      { learnerId: string; siteId: string },
      DashboardData
    >(functions, 'getLearnerDashboard');
    
    const result = await callable({ learnerId, siteId });
    return result.data;
  }
  
  /**
   * Get learning path progress
   */
  async getLearningPath(
    learnerId: string,
    siteId: string,
    courseId?: string
  ): Promise<LearningPathProgress[]> {
    const callable = httpsCallable<any, { path: LearningPathProgress[] }>(functions, 'getLearningPath');
    const result = await callable({ learnerId, siteId, courseId });
    return result.data.path;
  }
}

// Singleton instance
export const sdtMotivation = new SDTMotivationService();

// Re-export service class
export { SDTMotivationService };
