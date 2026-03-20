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
  getDocs,
  increment,
  query,
  serverTimestamp,
  setDoc,
  Timestamp,
  where,
} from 'firebase/firestore';
import { db } from '@/src/firebase/client-init';
import { httpsCallable } from 'firebase/functions';
import { functions } from '@/src/firebase/client-init';
import type { AgeBand, UserRole } from '@/src/types/schema';
import { getAgeBandFromGrade } from '@/src/lib/policies/gradeBandPolicy';

// ==================== EVENT TYPES ====================

export type TelemetryCategory =
  | 'autonomy'       // Choice, agency, self-direction
  | 'competence'     // Skill mastery, achievement
  | 'belonging'      // Social, collaboration
  | 'reflection'     // Metacognition
  | 'ai_interaction' // AI help usage
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
  // Voice telemetry
  | 'voice.transcribe'
  | 'voice.message'
  | 'voice.tts'
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
  private static readonly callableAllowedEvents = new Set<string>([
    'auth.login',
    'auth.logout',
    'attendance.recorded',
    'mission.attempt.submitted',
    'message.sent',
    'order.intent',
    'order.paid',
    'cta.clicked',
    'site.switched',
    'cms.page.viewed',
    'insight.viewed',
    'support.applied',
    'support.outcome.logged',
    'educator.feedback.submitted',
    'educator.review.completed',
    'rubric.applied',
    'notification.requested',
    'fdm.state.changed',
    'voice.transcribe',
    'voice.message',
    'voice.tts',
    'mission_viewed',
    'mission_selected',
    'mission_started',
    'mission_completed',
    'checkpoint_started',
    'checkpoint_submitted',
    'checkpoint_graded',
    'artifact_created',
    'artifact_submitted',
    'artifact_reviewed',
    'ai_help_opened',
    'ai_help_used',
    'ai_coach_response',
    'ai_coach_feedback',
    'session_joined',
    'session_left',
    'idle_detected',
    'focus_restored'
  ]);

  private static readonly legacyEventMap: Record<string, string> = {
    page_viewed: 'cms.page.viewed',
    feature_discovered: 'cta.clicked',
    help_accessed: 'cta.clicked',
    mission_browsed: 'mission_viewed',
    mission_selected: 'mission_selected',
    artifact_submitted: 'artifact_submitted',
    checkpoint_passed: 'checkpoint_graded',
    checkpoint_failed: 'checkpoint_submitted',
    reflection_submitted: 'ai_coach_feedback',
    session_started: 'session_joined',
    session_resumed: 'session_joined',
    session_paused: 'idle_detected',
    session_completed: 'session_left',
    focus_regained: 'focus_restored',
    attendance_marked: 'attendance.recorded',
    feedback_given: 'educator.feedback.submitted',
    assessment_graded: 'educator.review.completed',
    rubric_created: 'rubric.applied',
    session_facilitated: 'session_joined',
    ai_hint_requested: 'ai_help_used',
    ai_rubric_check: 'ai_help_used',
    ai_debug_help: 'ai_help_used',
    ai_critique_requested: 'ai_help_used',
    ai_explain_back_submitted: 'ai_coach_feedback',
    ai_feedback_positive: 'ai_coach_feedback',
    ai_feedback_negative: 'ai_coach_feedback',
    page_load_time: 'insight.viewed',
    slow_query_detected: 'insight.viewed',
    api_error: 'fdm.state.changed',
    client_error: 'fdm.state.changed'
  };

  /**
   * Track a telemetry event
   */
  static async track(payload: TelemetryPayload): Promise<string> {
    try {
      // Add automatic fields
      const enrichedPayload = this.removeUndefined({
        ...payload,
        timestamp: Timestamp.now(),
        deviceType: this.getDeviceType(),
        browser: this.getBrowser(),
        ageBand: payload.ageBand || (payload.grade ? getAgeBandFromGrade(payload.grade) : undefined)
      }) as TelemetryPayload;

      const canonicalEvent = this.toCanonicalCallableEvent(enrichedPayload.event);
      const metadata = this.removeUndefined({
        ...enrichedPayload.metadata,
        category: enrichedPayload.category,
        originalEvent: enrichedPayload.event,
        userId: enrichedPayload.userId,
        userRole: enrichedPayload.userRole,
        grade: enrichedPayload.grade,
        ageBand: enrichedPayload.ageBand,
        sessionId: enrichedPayload.sessionId,
        sessionOccurrenceId: enrichedPayload.sessionOccurrenceId,
        missionId: enrichedPayload.missionId,
        artifactId: enrichedPayload.artifactId,
        skillId: enrichedPayload.skillId,
        duration: enrichedPayload.duration,
        loadTime: enrichedPayload.loadTime,
        deviceType: enrichedPayload.deviceType,
        browser: enrichedPayload.browser
      }) as Record<string, unknown>;

      const logTelemetryEvent = httpsCallable(functions, 'logTelemetryEvent');
      await logTelemetryEvent({
        event: canonicalEvent,
        siteId: enrichedPayload.siteId,
        metadata
      });

      return `${canonicalEvent}-${Date.now()}`;
    } catch (err) {
      if (!this.isExpectedTelemetryWriteError(err)) {
        console.error('Telemetry tracking failed:', err);
      }
      // Don't throw - telemetry failures shouldn't break app
      return 'error';
    }
  }

  private static toCanonicalCallableEvent(event: TelemetryEvent): string {
    const mapped = this.legacyEventMap[event] || event;
    if (this.callableAllowedEvents.has(mapped)) {
      return mapped;
    }
    return 'cta.clicked';
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
  ): Promise<number | null> {
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
      if (snapshot.empty) {
        return null;
      }

      const totalEvents = snapshot.size;
      const checkpointsPassed = snapshot.docs.filter(
        doc => doc.data().event === 'checkpoint_passed' || doc.data().event === 'checkpoint_graded'
      ).length;
      const reflections = snapshot.docs.filter(
        doc => doc.data().category === 'reflection' || doc.data().metadata?.category === 'reflection'
      ).length;

      const score = Math.min(100, (
        totalEvents * 0.5 +
        checkpointsPassed * 10 +
        reflections * 5
      ));

      return Math.round(score);
    } catch {
      return null;
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
    autonomy: number | null;
    competence: number | null;
    belonging: number | null;
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
        const category = typeof data.category === 'string'
          ? data.category
          : typeof data.metadata?.category === 'string'
          ? data.metadata.category
          : '';
        if (category in categoryCount) {
          categoryCount[category as keyof typeof categoryCount]++;
        }
      });

      const total = Object.values(categoryCount).reduce((a, b) => a + b, 0);

      if (total === 0) {
        return {
          autonomy: null,
          competence: null,
          belonging: null,
        };
      }

      return {
        autonomy: Math.round((categoryCount.autonomy / total) * 100),
        competence: Math.round((categoryCount.competence / total) * 100),
        belonging: Math.round((categoryCount.belonging / total) * 100)
      };
    } catch {
      return {
        autonomy: null,
        competence: null,
        belonging: null
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

  private static removeUndefined<T>(value: T): T {
    if (Array.isArray(value)) {
      return value
        .filter(item => item !== undefined)
        .map(item => this.removeUndefined(item)) as T;
    }

    if (value && typeof value === 'object') {
      const entries = Object.entries(value as Record<string, unknown>)
        .filter(([, v]) => v !== undefined)
        .map(([k, v]) => [k, this.removeUndefined(v)]);
      return Object.fromEntries(entries) as T;
    }

    return value;
  }

  private static isExpectedTelemetryWriteError(error: unknown): boolean {
    const code = (error as { code?: string } | null)?.code;
    return code === 'permission-denied' || code === 'invalid-argument';
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
