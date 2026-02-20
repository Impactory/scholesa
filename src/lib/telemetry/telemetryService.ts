/**
 * Universal Telemetry Service
 * 
 * Tracks all user interactions for:
 * - SDT motivation patterns
 * - Feature usage analytics
 * - Performance monitoring
 * - Student engagement insights
 * - Teacher effectiveness metrics
 */

import {
  collection,
  doc,
  addDoc,
  setDoc,
  updateDoc,
  getDoc,
  increment,
  serverTimestamp,
  Timestamp,
  query,
  where,
  getDocs,
  orderBy,
  limit
} from 'firebase/firestore';
import { db } from '@/src/firebase/client-init';
import type { AgeBand, UserRole } from '@/src/types/schema';
import { getAgeBandFromGrade } from '@/src/lib/policies/gradeBandPolicy';

// ==================== EVENT TYPES ====================

export type TelemetryCategory =
  | 'autonomy'       // Choice, agency, self-direction
  | 'competence'     // Skill mastery, achievement
  | 'belonging'      // Social, collaboration
  | 'reflection'     // Metacognition
  | 'ai_interaction' // AI coach usage
  | 'navigation'     // Page views, clicks
  | 'performance'    // Load times, errors
  | 'engagement';    // Time on task, session patterns

export type TelemetryEvent =
  // Autonomy (Choice & Agency)
  | 'mission_browsed'
  | 'mission_selected'
  | 'mission_variant_chosen'
  | 'goal_set'
  | 'interest_profile_updated'
  | 'difficulty_chosen'
  | 'crew_role_chosen'
  // Competence (Skill & Achievement)
  | 'artifact_submitted'
  | 'artifact_revised'
  | 'checkpoint_attempted'
  | 'checkpoint_passed'
  | 'checkpoint_failed'
  | 'skill_evidence_logged'
  | 'skill_proven'
  | 'badge_earned'
  | 'rubric_viewed'
  | 'exemplar_viewed'
  // Belonging (Social & Collaboration)
  | 'showcase_submitted'
  | 'showcase_viewed'
  | 'recognition_given'
  | 'recognition_received'
  | 'peer_feedback_given'
  | 'peer_feedback_received'
  | 'crew_chat_sent'
  | 'crew_joined'
  // Reflection & Metacognition
  | 'reflection_submitted'
  | 'self_assessment_completed'
  | 'effort_rated'
  | 'enjoyment_rated'
  | 'learning_journal_entry'
  // AI Interaction
  | 'ai_hint_requested'
  | 'ai_rubric_check'
  | 'ai_debug_help'
  | 'ai_critique_requested'
  | 'ai_explain_back_submitted'
  | 'ai_feedback_positive'
  | 'ai_feedback_negative'
  // Navigation & Discovery
  | 'page_viewed'
  | 'feature_discovered'
  | 'tutorial_started'
  | 'tutorial_completed'
  | 'help_accessed'
  // Session & Engagement
  | 'session_started'
  | 'session_resumed'
  | 'session_paused'
  | 'session_completed'
  | 'idle_detected'
  | 'focus_regained'
  // Educator Actions
  | 'attendance_marked'
  | 'feedback_given'
  | 'assessment_graded'
  | 'rubric_created'
  | 'session_facilitated'
  // Performance & Errors
  | 'page_load_time'
  | 'api_error'
  | 'client_error'
  | 'slow_query_detected';

// ==================== TELEMETRY PAYLOAD ====================

export interface TelemetryPayload {
  // Required fields
  event: TelemetryEvent;
  category: TelemetryCategory;
  userId: string;
  userRole: UserRole;
  siteId: string;
  
  // Contextual fields (optional)
  grade?: number;
  ageBand?: AgeBand;
  sessionId?: string;
  sessionOccurrenceId?: string;
  missionId?: string;
  artifactId?: string;
  skillId?: string;
  
  // Event-specific metadata
  metadata?: Record<string, unknown>;
  
  // Performance metrics
  duration?: number; // milliseconds
  loadTime?: number; // milliseconds
  
  // Automatic fields (added by service)
  timestamp?: Timestamp;
  deviceType?: string;
  browser?: string;
}

// ==================== TELEMETRY SERVICE ====================

export class TelemetryService {
  /**
   * Track a telemetry event
   */
  static async track(payload: TelemetryPayload): Promise<string> {
    try {
      // Add automatic fields
      const enrichedPayload: TelemetryPayload = {
        ...payload,
        timestamp: Timestamp.now(),
        deviceType: this.getDeviceType(),
        browser: this.getBrowser(),
        ageBand: payload.ageBand || (payload.grade ? getAgeBandFromGrade(payload.grade) : undefined)
      };
      
      // Store in telemetry collection
      const docRef = await addDoc(collection(db, 'telemetryEvents'), enrichedPayload);
      
      // Update aggregates (async, non-blocking)
      this.updateAggregates(enrichedPayload).catch(err => {
        console.warn('Failed to update telemetry aggregates:', err);
      });
      
      return docRef.id;
    } catch (err) {
      console.error('Telemetry tracking failed:', err);
      // Don't throw - telemetry failures shouldn't break app
      return 'error';
    }
  }
  
  /**
   * Track page view
   */
  static async trackPageView(
    userId: string,
    userRole: UserRole,
    siteId: string,
    pagePath: string,
    pageTitle?: string
  ): Promise<void> {
    await this.track({
      event: 'page_viewed',
      category: 'navigation',
      userId,
      userRole,
      siteId,
      metadata: {
        pagePath,
        pageTitle,
        referrer: typeof document !== 'undefined' ? document.referrer : undefined
      }
    });
  }
  
  /**
   * Track autonomy event (choice, agency)
   */
  static async trackAutonomy(
    event: Extract<TelemetryEvent, 'mission_selected' | 'goal_set' | 'difficulty_chosen' | 'crew_role_chosen' | 'interest_profile_updated'>,
    userId: string,
    siteId: string,
    grade: number,
    metadata?: Record<string, unknown>
  ): Promise<void> {
    await this.track({
      event,
      category: 'autonomy',
      userId,
      userRole: 'learner',
      siteId,
      grade,
      metadata
    });
  }
  
  /**
   * Track competence event (skill mastery)
   */
  static async trackCompetence(
    event: Extract<TelemetryEvent, 'checkpoint_passed' | 'skill_proven' | 'badge_earned' | 'artifact_submitted'>,
    userId: string,
    siteId: string,
    grade: number,
    metadata?: Record<string, unknown>
  ): Promise<void> {
    await this.track({
      event,
      category: 'competence',
      userId,
      userRole: 'learner',
      siteId,
      grade,
      metadata
    });
  }
  
  /**
   * Track belonging event (social, collaboration)
   */
  static async trackBelonging(
    event: Extract<TelemetryEvent, 'recognition_given' | 'peer_feedback_given' | 'showcase_submitted' | 'crew_joined'>,
    userId: string,
    siteId: string,
    grade: number,
    metadata?: Record<string, unknown>
  ): Promise<void> {
    await this.track({
      event,
      category: 'belonging',
      userId,
      userRole: 'learner',
      siteId,
      grade,
      metadata
    });
  }
  
  /**
   * Track reflection event (metacognition)
   */
  static async trackReflection(
    event: Extract<TelemetryEvent, 'reflection_submitted' | 'self_assessment_completed' | 'effort_rated' | 'enjoyment_rated'>,
    userId: string,
    siteId: string,
    grade: number,
    metadata?: Record<string, unknown>
  ): Promise<void> {
    await this.track({
      event,
      category: 'reflection',
      userId,
      userRole: 'learner',
      siteId,
      grade,
      metadata
    });
  }
  
  /**
   * Track AI interaction
   */
  static async trackAI(
    event: Extract<TelemetryEvent, 'ai_hint_requested' | 'ai_rubric_check' | 'ai_debug_help' | 'ai_explain_back_submitted' | 'ai_feedback_positive' | 'ai_feedback_negative'>,
    userId: string,
    siteId: string,
    grade: number,
    metadata?: Record<string, unknown>
  ): Promise<void> {
    await this.track({
      event,
      category: 'ai_interaction',
      userId,
      userRole: 'learner',
      siteId,
      grade,
      metadata
    });
  }
  
  /**
   * Track session activity
   */
  static async trackSession(
    event: Extract<TelemetryEvent, 'session_started' | 'session_resumed' | 'session_paused' | 'session_completed'>,
    userId: string,
    siteId: string,
    grade: number,
    sessionId: string,
    duration?: number
  ): Promise<void> {
    await this.track({
      event,
      category: 'engagement',
      userId,
      userRole: 'learner',
      siteId,
      grade,
      sessionId,
      duration,
      metadata: { sessionId }
    });
  }
  
  /**
   * Track performance metric
   */
  static async trackPerformance(
    event: Extract<TelemetryEvent, 'page_load_time' | 'api_error' | 'client_error' | 'slow_query_detected'>,
    userId: string,
    siteId: string,
    metadata: Record<string, unknown>,
    loadTime?: number
  ): Promise<void> {
    await this.track({
      event,
      category: 'performance',
      userId,
      userRole: 'learner', // Could be any role
      siteId,
      metadata,
      loadTime
    });
  }
  
  // ===== AGGREGATE UPDATES =====
  
  /**
   * Update daily/weekly aggregates (for dashboards)
   */
  private static async updateAggregates(payload: TelemetryPayload): Promise<void> {
    const today = new Date().toISOString().split('T')[0]; // YYYY-MM-DD
    
    // Daily aggregate per user
    const dailyAggregateRef = doc(
      db,
      'telemetryAggregates',
      `${payload.userId}_${today}`
    );
    
    await setDoc(dailyAggregateRef, {
      userId: payload.userId,
      siteId: payload.siteId,
      date: today,
      eventCounts: {
        [payload.event]: increment(1)
      },
      categoryCounts: {
        [payload.category]: increment(1)
      },
      totalEvents: increment(1),
      lastUpdated: serverTimestamp()
    }, { merge: true });
    
    // Site-wide aggregate
    const siteAggregateRef = doc(
      db,
      'telemetryAggregates',
      `site_${payload.siteId}_${today}`
    );
    
    await setDoc(siteAggregateRef, {
      siteId: payload.siteId,
      date: today,
      type: 'site_daily',
      eventCounts: {
        [payload.event]: increment(1)
      },
      categoryCounts: {
        [payload.category]: increment(1)
      },
      totalEvents: increment(1),
      lastUpdated: serverTimestamp()
    }, { merge: true });
  }
  
  // ===== ANALYTICS QUERIES =====
  
  /**
   * Get user engagement score (0-100)
   */
  static async getUserEngagementScore(
    userId: string,
    siteId: string,
    days: number = 7
  ): Promise<number> {
    try {
      const startDate = new Date();
      startDate.setDate(startDate.getDate() - days);

      const q = query(
        collection(db, 'telemetryEvents'),
        where('userId', '==', userId),
        where('siteId', '==', siteId),
        where('timestamp', '>=', Timestamp.fromDate(startDate))
      );

      const snapshot = await getDocs(q);

      const totalEvents = snapshot.size;
      const checkpointsPassed = snapshot.docs.filter(
        doc => doc.data().event === 'checkpoint_passed'
      ).length;
      const reflections = snapshot.docs.filter(
        doc => doc.data().category === 'reflection'
      ).length;

      const score = Math.min(100, (
        totalEvents * 0.5 +
        checkpointsPassed * 10 +
        reflections * 5
      ));

      return Math.round(score);
    } catch {
      return 0;
    }
  }
  
  /**
   * Get SDT motivation profile
   */
  static async getSDTProfile(
    userId: string,
    siteId: string,
    days: number = 30
  ): Promise<{
    autonomy: number;
    competence: number;
    belonging: number;
  }> {
    try {
      const startDate = new Date();
      startDate.setDate(startDate.getDate() - days);

      const q = query(
        collection(db, 'telemetryEvents'),
        where('userId', '==', userId),
        where('siteId', '==', siteId),
        where('timestamp', '>=', Timestamp.fromDate(startDate))
      );

      const snapshot = await getDocs(q);

      const categoryCount = {
        autonomy: 0,
        competence: 0,
        belonging: 0
      };

      snapshot.docs.forEach(doc => {
        const data = doc.data();
        if (data.category in categoryCount) {
          categoryCount[data.category as keyof typeof categoryCount]++;
        }
      });

      const total = Object.values(categoryCount).reduce((a, b) => a + b, 0) || 1;

      return {
        autonomy: Math.round((categoryCount.autonomy / total) * 100),
        competence: Math.round((categoryCount.competence / total) * 100),
        belonging: Math.round((categoryCount.belonging / total) * 100)
      };
    } catch {
      return {
        autonomy: 0,
        competence: 0,
        belonging: 0
      };
    }
  }
  
  // ===== UTILITY FUNCTIONS =====
  
  private static getDeviceType(): string {
    if (typeof window === 'undefined') return 'server';
    
    const ua = navigator.userAgent;
    if (/(tablet|ipad|playbook|silk)|(android(?!.*mobi))/i.test(ua)) {
      return 'tablet';
    }
    if (/Mobile|Android|iP(hone|od)|IEMobile|BlackBerry|Kindle|Silk-Accelerated|(hpw|web)OS|Opera M(obi|ini)/.test(ua)) {
      return 'mobile';
    }
    return 'desktop';
  }
  
  private static getBrowser(): string {
    if (typeof window === 'undefined') return 'unknown';
    
    const ua = navigator.userAgent;
    if (ua.includes('Firefox')) return 'Firefox';
    if (ua.includes('Edg')) return 'Edge';
    if (ua.includes('Chrome')) return 'Chrome';
    if (ua.includes('Safari')) return 'Safari';
    return 'Other';
  }
}

// ===== CONVENIENCE EXPORTS =====

export const trackPageView = TelemetryService.trackPageView.bind(TelemetryService);
export const trackAutonomy = TelemetryService.trackAutonomy.bind(TelemetryService);
export const trackCompetence = TelemetryService.trackCompetence.bind(TelemetryService);
export const trackBelonging = TelemetryService.trackBelonging.bind(TelemetryService);
export const trackReflection = TelemetryService.trackReflection.bind(TelemetryService);
export const trackAI = TelemetryService.trackAI.bind(TelemetryService);
export const trackSession = TelemetryService.trackSession.bind(TelemetryService);
export const trackPerformance = TelemetryService.trackPerformance.bind(TelemetryService);
export const getUserEngagementScore = TelemetryService.getUserEngagementScore.bind(TelemetryService);
export const getSDTProfile = TelemetryService.getSDTProfile.bind(TelemetryService);
