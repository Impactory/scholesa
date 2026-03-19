/**
 * SDT Motivation Engine - Complete Implementation
 * 
 * Self-Determination Theory Framework:
 * - **Autonomy**: Choice, agency, self-direction
 * - **Competence**: Mastery, achievement, growth
 * - **Belonging**: Connection, recognition, collaboration
 * 
 * Phases:
 * 1. Choice Architecture (Autonomy)
 * 2. Mastery Pathways (Competence)
 * 3. Social Recognition (Belonging)
 * 4. Reflection & Growth (Metacognition)
 */

import {
  collection,
  doc,
  getDoc,
  getDocs,
  setDoc,
  addDoc,
  updateDoc,
  query,
  where,
  orderBy,
  limit,
  Timestamp,
  increment
} from 'firebase/firestore';
import { db } from '@/src/firebase/client-init';
import type {
  DifficultyLevel,
  AgeBand,
  CrewRole,
  RecognitionType
} from '@/src/types/schema';
import { trackAutonomy, trackCompetence, trackBelonging, trackReflection } from '@/src/lib/telemetry/telemetryService';

// ==================== TYPES ====================

export interface MissionChoice {
  id: string;
  title: string;
  description: string;
  difficulty: DifficultyLevel | null;
  estimatedMinutes: number | null;
  skillIds: string[];
  theme: string | null;
  connectionToInterests: string[]; // Which student interests it matches
  relevanceScore: number; // 0-1 based on student profile
}

export interface LearnerGoal {
  id?: string;
  learnerId: string;
  siteId: string;
  goalType: 'skill_mastery' | 'project_completion' | 'peer_teaching' | 'exploration';
  description: string;
  targetSkillIds?: string[];
  targetDate?: Date;
  progress: number; // 0-100
  status: 'active' | 'completed' | 'abandoned';
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

export interface InterestProfile {
  learnerId: string;
  siteId: string;
  interests: string[]; // e.g., ["robotics", "art", "storytelling"]
  preferredDifficulty: DifficultyLevel;
  preferredWorkStyle: 'independent' | 'paired' | 'crew';
  favoriteThemes: string[];
  avoidances: string[]; // What they don't enjoy
  updatedAt: Timestamp;
}

export interface MasteryProgress {
  learnerId: string;
  siteId: string;
  skillId: string;
  level: 'emerging' | 'developing' | 'proficient' | 'advanced';
  evidenceCount: number;
  lastDemonstrated?: Timestamp;
  checkpointsPassed: number;
  milestonesReached: string[];
  nextMilestone?: string;
}

export interface RecognitionBadge {
  id?: string;
  recipientId: string;
  giverId: string;
  giverName: string;
  siteId: string;
  sessionOccurrenceId: string;
  recognitionType: RecognitionType;
  message: string;
  isPublic: boolean;
  createdAt: Timestamp;
}

export interface ReflectionPrompt {
  id: string;
  prompt: string;
  category: 'effort' | 'enjoyment' | 'learning' | 'peer' | 'goal';
  ageBand: AgeBand;
  isQuick: boolean; // Quick rating vs long-form
}

export interface LearnerReflection {
  id?: string;
  learnerId: string;
  siteId: string;
  sessionId?: string;
  missionId?: string;
  promptId: string;
  response: string | number; // Text or rating
  effortRating?: number; // 1-5
  enjoymentRating?: number; // 1-5
  createdAt: Timestamp;
}

// ==================== PHASE 1: AUTONOMY (CHOICE) ====================

export class AutonomyEngine {
  /**
   * Get personalized mission choices for learner
   */
  static async getMissionChoices(
    learnerId: string,
    siteId: string,
    grade: number,
    sessionOccurrenceId?: string
  ): Promise<MissionChoice[]> {
    // Get learner's interest profile
    const interestProfile = await this.getInterestProfile(learnerId, siteId);
    
    // Get learner's current mastery levels
    const masteryMap = await this.getMasteryMap(learnerId, siteId);
    
    // Fetch available missions for this session/grade
    const availableMissions = await this.getAvailableMissions(siteId, grade, sessionOccurrenceId);
    
    // Score and rank by relevance
    const scoredChoices = availableMissions.map(mission => {
      const relevanceScore = this.calculateRelevance(mission, interestProfile, masteryMap);
      const connectionToInterests = this.matchInterests(mission, interestProfile);
      
      return {
        ...mission,
        connectionToInterests,
        relevanceScore
      };
    });
    
    // Sort by relevance, return top 3-5
    return scoredChoices
      .sort((a, b) => b.relevanceScore - a.relevanceScore)
      .slice(0, grade <= 3 ? 3 : 5);
  }
  
  /**
   * Record mission selection (autonomy event)
   */
  static async recordMissionSelection(
    learnerId: string,
    siteId: string,
    grade: number,
    missionId: string,
    chosenDifficulty: DifficultyLevel,
    reason?: string
  ): Promise<void> {
    // Track autonomy telemetry
    await trackAutonomy('mission_selected', learnerId, siteId, grade, {
      missionId,
      difficulty: chosenDifficulty,
      reason
    });
    
    // Update selection history
    const historyRef = doc(db, 'learnerChoiceHistory', learnerId);
    await setDoc(historyRef, {
      learnerId,
      siteId,
      selections: {
        [missionId]: {
          selectedAt: Timestamp.now(),
          difficulty: chosenDifficulty,
          reason
        }
      }
    }, { merge: true });
  }
  
  /**
   * Set learner goal (autonomy signal)
   */
  static async setGoal(goal: Omit<LearnerGoal, 'id' | 'createdAt' | 'updatedAt'>): Promise<string> {
    const docRef = await addDoc(collection(db, 'learnerGoals'), {
      ...goal,
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now()
    });
    
    // Track autonomy
    await trackAutonomy('goal_set', goal.learnerId, goal.siteId, 5, {
      goalType: goal.goalType,
      description: goal.description
    });
    
    return docRef.id;
  }
  
  /**
   * Update interest profile (autonomy signal)
   */
  static async updateInterests(
    learnerId: string,
    siteId: string,
    grade: number,
    updates: Partial<InterestProfile>
  ): Promise<void> {
    const profileRef = doc(db, 'learnerInterestProfiles', learnerId);
    
    await setDoc(profileRef, {
      learnerId,
      siteId,
      ...updates,
      updatedAt: Timestamp.now()
    }, { merge: true });
    
    // Track autonomy
    await trackAutonomy('interest_profile_updated', learnerId, siteId, grade, {
      interests: updates.interests,
      preferredDifficulty: updates.preferredDifficulty
    });
  }
  
  // ===== PRIVATE HELPERS =====
  
  private static async getInterestProfile(learnerId: string, siteId: string): Promise<InterestProfile | null> {
    const profileRef = doc(db, 'learnerInterestProfiles', learnerId);
    const snap = await getDoc(profileRef);
    return snap.exists() ? snap.data() as InterestProfile : null;
  }
  
  private static async getMasteryMap(learnerId: string, siteId: string): Promise<Map<string, MasteryProgress>> {
    const q = query(
      collection(db, 'skillMastery'),
      where('learnerId', '==', learnerId),
      where('siteId', '==', siteId)
    );
    
    const snapshot = await getDocs(q);
    const map = new Map<string, MasteryProgress>();
    
    snapshot.docs.forEach(doc => {
      const data = doc.data() as MasteryProgress;
      map.set(data.skillId, data);
    });
    
    return map;
  }
  
  private static async getAvailableMissions(
    siteId: string,
    grade: number,
    sessionOccurrenceId?: string
  ): Promise<MissionChoice[]> {
    try {
      // Determine grade band for filtering
      const gradeBand: AgeBand = grade <= 3 ? 'grades_1_3' : grade <= 6 ? 'grades_4_6' : 'grades_7_9';
      
      // Query missions appropriate for grade band and site
      let missionsQuery = query(
        collection(db, 'missions'),
        where('siteId', '==', siteId),
        where('gradeBands', 'array-contains', gradeBand),
        where('isActive', '==', true),
        orderBy('createdAt', 'desc'),
        limit(20)
      );
      
      const missionsSnap = await getDocs(missionsQuery);
      const missions: MissionChoice[] = [];
      
      missionsSnap.forEach(doc => {
        const data = doc.data();
        const title = typeof data.title === 'string' && data.title.trim().length > 0
          ? data.title.trim()
          : null;
        if (!title) {
          return;
        }
        missions.push({
          id: doc.id,
          title,
          description: typeof data.description === 'string' ? data.description : '',
          difficulty: typeof data.difficulty === 'string' ? data.difficulty as DifficultyLevel : null,
          estimatedMinutes: typeof data.estimatedMinutes === 'number' && Number.isFinite(data.estimatedMinutes)
            ? data.estimatedMinutes
            : null,
          skillIds: Array.isArray(data.targetSkills)
            ? data.targetSkills.filter((skill): skill is string => typeof skill === 'string' && skill.trim().length > 0)
            : [],
          theme: typeof data.theme === 'string' && data.theme.trim().length > 0 ? data.theme.trim() : null,
          connectionToInterests: Array.isArray(data.tags)
            ? data.tags.filter((tag): tag is string => typeof tag === 'string' && tag.trim().length > 0)
            : [],
          relevanceScore: 0.5 // Will be calculated later based on student profile
        });
      });
      
      return missions;
    } catch (err) {
      console.error('Failed to fetch missions:', err);
      return [];
    }
  }
  
  private static calculateRelevance(
    mission: MissionChoice,
    profile: InterestProfile | null,
    mastery: Map<string, MasteryProgress>
  ): number {
    let score = 0.5; // Base score
    
    // Interest match
    if (profile) {
      const interestMatch = mission.skillIds.some(skill =>
        profile.interests.some(interest => skill.includes(interest))
      );
      if (interestMatch) score += 0.3;
      
      // Difficulty preference
      if (mission.difficulty != null && mission.difficulty === profile.preferredDifficulty) score += 0.2;
    }
    
    return Math.min(1, score);
  }
  
  private static matchInterests(mission: MissionChoice, profile: InterestProfile | null): string[] {
    if (!profile) return [];
    
    return profile.interests.filter(interest =>
      mission.skillIds.some(skill => skill.includes(interest)) ||
      (mission.theme != null && mission.theme.toLowerCase().includes(interest.toLowerCase()))
    );
  }
}

// ==================== PHASE 2: COMPETENCE (MASTERY) ====================

export class CompetenceEngine {
  /**
   * Record skill evidence (competence event)
   */
  static async recordSkillEvidence(
    learnerId: string,
    siteId: string,
    grade: number,
    skillId: string,
    artifactId: string,
    quality: 'emerging' | 'proficient' | 'advanced'
  ): Promise<void> {
    // Update mastery progress
    const masteryRef = doc(db, 'skillMastery', `${learnerId}_${skillId}`);
    
    await setDoc(masteryRef, {
      learnerId,
      siteId,
      skillId,
      level: quality,
      evidenceCount: increment(1),
      lastDemonstrated: Timestamp.now()
    }, { merge: true });
    
    // Track competence
    await trackCompetence('skill_proven', learnerId, siteId, grade, {
      skillId,
      artifactId,
      quality
    });
  }
  
  /**
   * Mark checkpoint passed (competence event)
   */
  static async recordCheckpointPassed(
    learnerId: string,
    siteId: string,
    grade: number,
    sessionId: string,
    checkpointNumber: number,
    skillsProven: string[]
  ): Promise<void> {
    // Update checkpoint history
    const historyRef = doc(db, 'checkpointHistory', `${sessionId}_${learnerId}`);
    
    await setDoc(historyRef, {
      learnerId,
      siteId,
      sessionId,
      checkpointsPassed: {
        [checkpointNumber]: {
          passedAt: Timestamp.now(),
          skillsProven
        }
      }
    }, { merge: true });
    
    // Update mastery for each skill
    for (const skillId of skillsProven) {
      const masteryRef = doc(db, 'skillMastery', `${learnerId}_${skillId}`);
      await updateDoc(masteryRef, {
        checkpointsPassed: increment(1),
        lastDemonstrated: Timestamp.now()
      });
    }
    
    // Track competence
    await trackCompetence('checkpoint_passed', learnerId, siteId, grade, {
      sessionId,
      checkpointNumber,
      skillsProven
    });
  }
  
  /**
   * Award badge (competence milestone)
   */
  static async awardBadge(
    learnerId: string,
    siteId: string,
    grade: number,
    badgeId: string,
    reason: string
  ): Promise<void> {
    const badgeRef = doc(db, 'learnerBadges', `${learnerId}_${badgeId}`);
    
    await setDoc(badgeRef, {
      learnerId,
      siteId,
      badgeId,
      reason,
      awardedAt: Timestamp.now()
    });
    
    // Track competence
    await trackCompetence('badge_earned', learnerId, siteId, grade, {
      badgeId,
      reason
    });
  }
  
  /**
   * Get mastery dashboard for learner
   */
  static async getMasteryDashboard(
    learnerId: string,
    siteId: string
  ): Promise<{
    skillsProven: number;
    skillsInProgress: number;
    badgesEarned: number;
    checkpointsPassed: number;
    nextMilestones: string[];
  }> {
    // Query mastery progress
    const masteryQuery = query(
      collection(db, 'skillMastery'),
      where('learnerId', '==', learnerId),
      where('siteId', '==', siteId)
    );
    
    const masterySnap = await getDocs(masteryQuery);
    
    let skillsProven = 0;
    let skillsInProgress = 0;
    let totalCheckpoints = 0;
    
    masterySnap.docs.forEach(doc => {
      const data = doc.data() as MasteryProgress;
      if (data.level === 'proficient' || data.level === 'advanced') {
        skillsProven++;
      } else {
        skillsInProgress++;
      }
      totalCheckpoints += data.checkpointsPassed || 0;
    });
    
    // Query badges
    const badgesQuery = query(
      collection(db, 'learnerBadges'),
      where('learnerId', '==', learnerId),
      where('siteId', '==', siteId)
    );
    
    const badgesSnap = await getDocs(badgesQuery);
    
    // Calculate next milestones from active missions
    const nextMilestones: string[] = [];
    
    // Query active missions for this learner
    const activeMissionsQuery = query(
      collection(db, 'missionEnrollments'),
      where('learnerId', '==', learnerId),
      where('siteId', '==', siteId),
      where('status', '==', 'active'),
      limit(5)
    );
    
    const activeMissionsSnap = await getDocs(activeMissionsQuery);
    
    for (const enrollmentDoc of activeMissionsSnap.docs) {
      const enrollment = enrollmentDoc.data();
      const missionId = enrollment.missionId;
      
      // Get mission details
      const missionDoc = await getDoc(doc(db, 'missions', missionId));
      if (!missionDoc.exists()) continue;
      
      const missionData = missionDoc.data();
      const checkpoints = missionData.checkpoints || [];
      
      // Find next uncompleted checkpoint
      const completedCheckpoints = enrollment.completedCheckpoints || [];
      const nextCheckpoint = checkpoints.find(
        (cp: { id: string }) => !completedCheckpoints.includes(cp.id)
      );
      
      if (nextCheckpoint) {
        nextMilestones.push(
          `${missionData.title}: ${nextCheckpoint.title || nextCheckpoint.description || 'Next checkpoint'}`
        );
      }
    }
    
    return {
      skillsProven,
      skillsInProgress,
      badgesEarned: badgesSnap.size,
      checkpointsPassed: totalCheckpoints,
      nextMilestones
    };
  }
}

// ==================== PHASE 3: BELONGING (SOCIAL) ====================

export class BelongingEngine {
  /**
   * Give recognition to peer (belonging event)
   */
  static async giveRecognition(
    recognition: Omit<RecognitionBadge, 'id' | 'createdAt'>,
    giverGrade: number
  ): Promise<string> {
    const docRef = await addDoc(collection(db, 'recognitionBadges'), {
      ...recognition,
      createdAt: Timestamp.now()
    });
    
    // Track belonging (giver)
    await trackBelonging('recognition_given', recognition.giverId, recognition.siteId, giverGrade, {
      recipientId: recognition.recipientId,
      recognitionType: recognition.recognitionType,
      message: recognition.message
    });
    
    return docRef.id;
  }
  
  /**
   * Submit to showcase (belonging event)
   */
  static async submitToShowcase(
    learnerId: string,
    siteId: string,
    grade: number,
    artifactId: string,
    caption: string
  ): Promise<void> {
    const showcaseRef = doc(db, 'showcaseSubmissions', artifactId);
    
    await setDoc(showcaseRef, {
      learnerId,
      siteId,
      artifactId,
      caption,
      submittedAt: Timestamp.now(),
      likes: 0,
      comments: []
    });
    
    // Track belonging
    await trackBelonging('showcase_submitted', learnerId, siteId, grade, {
      artifactId,
      caption
    });
  }
  
  /**
   * Give peer feedback (belonging event)
   */
  static async givePeerFeedback(
    giverId: string,
    recipientId: string,
    siteId: string,
    grade: number,
    artifactId: string,
    feedback: string,
    stars: number
  ): Promise<void> {
    await addDoc(collection(db, 'peerFeedback'), {
      giverId,
      recipientId,
      siteId,
      artifactId,
      feedback,
      stars,
      createdAt: Timestamp.now()
    });
    
    // Track belonging (giver)
    await trackBelonging('peer_feedback_given', giverId, siteId, grade, {
      recipientId,
      artifactId,
      stars
    });
  }
  
  /**
   * Get recognition received by learner
   */
  static async getRecognitionReceived(
    learnerId: string,
    siteId: string,
    limitCount: number = 10
  ): Promise<RecognitionBadge[]> {
    const q = query(
      collection(db, 'recognitionBadges'),
      where('recipientId', '==', learnerId),
      where('siteId', '==', siteId),
      orderBy('createdAt', 'desc'),
      limit(limitCount)
    );
    
    const snapshot = await getDocs(q);
    return snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    } as RecognitionBadge));
  }
}

// ==================== PHASE 4: REFLECTION (METACOGNITION) ====================

export class ReflectionEngine {
  /**
   * Get reflection prompts for age band
   */
  static getPromptsForAgeBand(ageBand: AgeBand): ReflectionPrompt[] {
    const prompts: Record<AgeBand, ReflectionPrompt[]> = {
      grades_1_3: [
        { id: 'k3_effort', prompt: 'How hard did you try today?', category: 'effort', ageBand: 'grades_1_3', isQuick: true },
        { id: 'k3_fun', prompt: 'Did you have fun learning?', category: 'enjoyment', ageBand: 'grades_1_3', isQuick: true },
        { id: 'k3_proud', prompt: 'What are you proud of?', category: 'learning', ageBand: 'grades_1_3', isQuick: false }
      ],
      grades_4_6: [
        { id: '46_effort', prompt: 'What strategies did you use when you got stuck?', category: 'effort', ageBand: 'grades_4_6', isQuick: false },
        { id: '46_learning', prompt: 'What did you learn today that surprised you?', category: 'learning', ageBand: 'grades_4_6', isQuick: false },
        { id: '46_peer', prompt: 'How did your crew help you?', category: 'peer', ageBand: 'grades_4_6', isQuick: false }
      ],
      grades_7_9: [
        { id: '79_growth', prompt: 'How did this challenge help you grow?', category: 'learning', ageBand: 'grades_7_9', isQuick: false },
        { id: '79_identity', prompt: 'How does this connect to your goals?', category: 'goal', ageBand: 'grades_7_9', isQuick: false },
        { id: '79_metacog', prompt: 'What would you do differently next time?', category: 'effort', ageBand: 'grades_7_9', isQuick: false }
      ],
      grades_10_12: [
        { id: '1012_impact', prompt: 'How could this skill impact your future?', category: 'goal', ageBand: 'grades_10_12', isQuick: false },
        { id: '1012_transfer', prompt: 'Where else could you apply this thinking?', category: 'learning', ageBand: 'grades_10_12', isQuick: false },
        { id: '1012_critique', prompt: 'Critique your own process - what worked, what did not?', category: 'effort', ageBand: 'grades_10_12', isQuick: false }
      ]
    };
    
    return prompts[ageBand] || prompts.grades_4_6;
  }
  
  /**
   * Submit reflection (metacognition event)
   */
  static async submitReflection(
    reflection: Omit<LearnerReflection, 'id' | 'createdAt'>,
    grade: number
  ): Promise<string> {
    const docRef = await addDoc(collection(db, 'learnerReflections'), {
      ...reflection,
      createdAt: Timestamp.now()
    });
    
    // Track reflection
    await trackReflection('reflection_submitted', reflection.learnerId, reflection.siteId, grade, {
      promptId: reflection.promptId,
      responseLength: typeof reflection.response === 'string' ? reflection.response.length : 0
    });
    
    return docRef.id;
  }
  
  /**
   * Rate effort (quick reflection)
   */
  static async rateEffort(
    learnerId: string,
    siteId: string,
    grade: number,
    sessionId: string,
    rating: number
  ): Promise<void> {
    const reflectionRef = doc(db, 'sessionReflections', `${sessionId}_${learnerId}`);
    
    await setDoc(reflectionRef, {
      learnerId,
      siteId,
      sessionId,
      effortRating: rating,
      updatedAt: Timestamp.now()
    }, { merge: true });
    
    // Track reflection
    await trackReflection('effort_rated', learnerId, siteId, grade, {
      sessionId,
      rating
    });
  }
  
  /**
   * Rate enjoyment (quick reflection)
   */
  static async rateEnjoyment(
    learnerId: string,
    siteId: string,
    grade: number,
    sessionId: string,
    rating: number
  ): Promise<void> {
    const reflectionRef = doc(db, 'sessionReflections', `${sessionId}_${learnerId}`);
    
    await setDoc(reflectionRef, {
      learnerId,
      siteId,
      sessionId,
      enjoymentRating: rating,
      updatedAt: Timestamp.now()
    }, { merge: true });
    
    // Track reflection
    await trackReflection('enjoyment_rated', learnerId, siteId, grade, {
      sessionId,
      rating
    });
  }
  
  /**
   * Get reflection history
   */
  static async getReflectionHistory(
    learnerId: string,
    siteId: string,
    limitCount: number = 10
  ): Promise<LearnerReflection[]> {
    const q = query(
      collection(db, 'learnerReflections'),
      where('learnerId', '==', learnerId),
      where('siteId', '==', siteId),
      orderBy('createdAt', 'desc'),
      limit(limitCount)
    );
    
    const snapshot = await getDocs(q);
    return snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    } as LearnerReflection));
  }
}

// ===== CONVENIENCE EXPORTS =====

export const getMissionChoices = AutonomyEngine.getMissionChoices.bind(AutonomyEngine);
export const recordMissionSelection = AutonomyEngine.recordMissionSelection.bind(AutonomyEngine);
export const setLearnerGoal = AutonomyEngine.setGoal.bind(AutonomyEngine);
export const updateLearnerInterests = AutonomyEngine.updateInterests.bind(AutonomyEngine);

export const recordSkillEvidence = CompetenceEngine.recordSkillEvidence.bind(CompetenceEngine);
export const recordCheckpointPassed = CompetenceEngine.recordCheckpointPassed.bind(CompetenceEngine);
export const awardBadge = CompetenceEngine.awardBadge.bind(CompetenceEngine);
export const getMasteryDashboard = CompetenceEngine.getMasteryDashboard.bind(CompetenceEngine);

export const giveRecognition = BelongingEngine.giveRecognition.bind(BelongingEngine);
export const submitToShowcase = BelongingEngine.submitToShowcase.bind(BelongingEngine);
export const givePeerFeedback = BelongingEngine.givePeerFeedback.bind(BelongingEngine);
export const getRecognitionReceived = BelongingEngine.getRecognitionReceived.bind(BelongingEngine);

export const getReflectionPrompts = ReflectionEngine.getPromptsForAgeBand.bind(ReflectionEngine);
export const submitReflection = ReflectionEngine.submitReflection.bind(ReflectionEngine);
export const rateEffort = ReflectionEngine.rateEffort.bind(ReflectionEngine);
export const rateEnjoyment = ReflectionEngine.rateEnjoyment.bind(ReflectionEngine);
export const getReflectionHistory = ReflectionEngine.getReflectionHistory.bind(ReflectionEngine);
