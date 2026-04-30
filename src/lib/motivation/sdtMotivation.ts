/**
 * SDT Motivation Service
 *
 * Self-Determination Theory framework for the Scholesa Motivation Engine
 * Autonomy + Competence + Belonging = Intrinsic Motivation
 */

import { getFunctions, httpsCallable } from 'firebase/functions';
import type {
  DifficultyLevel,
  CrewRole,
  RecognitionType,
} from '@/src/types/schema';

const functions = getFunctions();

async function loadE2EBackend() {
  return import('@/src/testing/e2e/fakeWebBackend');
}

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

/**
 * AI Help Request — aligned to BOS+MIA contract (HOW_TO §5, A2).
 * Modes: hint (low assist), verify (evidence check), explain (scaffolding), debug (guided).
 * Forbidden: final answers, doing student's work, punitive language.
 */
export interface AICoachRequest {
  mode: 'hint' | 'verify' | 'explain' | 'debug';
  gradeBand?: 'G1_3' | 'G4_6' | 'G7_9' | 'G10_12';
  sessionOccurrenceId?: string;
  missionId?: string;
  checkpointId?: string;
  conceptTags?: string[];
  studentInput?: string;
  attachments?: Array<{ type: 'artifact_ref' | 'evidence_ref'; id: string; version?: string; mvlEpisodeId?: string }>;
}

/**
 * AI Help Response — aligned to BOS+MIA contract.
 * Includes risk assessment, MVL gating, and audit metadata.
 */
export interface AICoachResponse {
  message: string;
  mode: string;
  requiresExplainBack: boolean;
  suggestedNextSteps: string[];
  learnerState: { cognition: number; engagement: number; integrity: number } | null;
  risk: {
    reliability: { riskType: string; method: string; riskScore: number; threshold: number };
    autonomy: { riskType: string; signals: string[]; riskScore: number; threshold: number };
  };
  mvl: { gateActive: boolean; episodeId: string | null; reason: string | null };
  meta: { version: string; gradeBand: string; conceptTags: string[]; aiHelpOpenedEventId: string };
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
    effectiveStrategy?: string,
    aiAssistanceUsed?: boolean,
    aiAssistanceDetails?: string
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
      effectiveStrategy,
      aiAssistanceUsed: aiAssistanceUsed ?? false,
      aiAssistanceDetails: aiAssistanceDetails || undefined,
    });
    return result.data;
  }

  // === AI HELP ===

  /**
  * Request AI help (with guardrails)
   */
  async requestAICoach(
    learnerId: string,
    siteId: string,
    request: AICoachRequest
  ): Promise<AICoachResponse> {
    if (process.env.NEXT_PUBLIC_E2E_TEST_MODE === '1') {
      const { requestE2EAICoach } = await loadE2EBackend();
      return requestE2EAICoach(learnerId, siteId, request);
    }

    // Route to genAiCoach (BOS contract-aligned Cloud Function)
    const callable = httpsCallable<
      AICoachRequest & { learnerId: string; siteId: string },
      AICoachResponse
    >(functions, 'genAiCoach');

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
    if (process.env.NEXT_PUBLIC_E2E_TEST_MODE === '1') {
      const { submitE2EExplainBack } = await loadE2EBackend();
      return submitE2EExplainBack(learnerId, siteId, interactionId, explainBack);
    }

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
