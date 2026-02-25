/**
 * React Hooks for Telemetry Integration
 * 
 * Provides easy-to-use hooks for tracking user interactions throughout the app.
 * Auto-tracks page views, sessions, and common interactions.
 */

import { useEffect, useRef } from 'react';
import { useAuthContext } from '@/src/firebase/auth/AuthProvider';
import { TelemetryService, type TelemetryCategory, type TelemetryEvent } from '@/src/lib/telemetry/telemetryService';
import type { UserRole } from '@/src/types/schema';

const LEGACY_EVENT_TO_CANONICAL: Record<string, string> = {
  page_viewed: 'cms.page.viewed',
  feature_discovered: 'cta.clicked',
  help_accessed: 'cta.clicked',
  session_started: 'session_joined',
  session_resumed: 'session_joined',
  session_paused: 'idle_detected',
  session_completed: 'session_left',
  focus_regained: 'focus_restored',
  attendance_marked: 'attendance.recorded',
  feedback_given: 'educator.feedback.submitted',
  assessment_graded: 'educator.review.completed',
  rubric_created: 'rubric.applied',
  ai_hint_requested: 'ai_help_used',
  ai_rubric_check: 'ai_help_used',
  ai_debug_help: 'ai_help_used',
  ai_critique_requested: 'ai_help_used'
};

function canonicalEventForLegacy(eventType: string): string {
  return LEGACY_EVENT_TO_CANONICAL[eventType] || 'cta.clicked';
}

function trackMappedTelemetry(params: {
  eventType: TelemetryEvent;
  category: TelemetryCategory;
  userId: string;
  userRole: UserRole;
  siteId: string;
  metadata?: Record<string, unknown>;
}) {
  const { eventType, category, userId, userRole, siteId, metadata } = params;
  return TelemetryService.track({
    event: eventType,
    category,
    userId,
    userRole,
    siteId,
    metadata: {
      ...metadata,
      legacyEvent: eventType,
      canonicalEvent: canonicalEventForLegacy(eventType)
    }
  });
}

/**
 * Auto-track page views when component mounts
 * 
 * @example
 * function Dashboard() {
 *   usePageViewTracking('learner_dashboard');
 *   return <div>Dashboard content</div>;
 * }
 */
export function usePageViewTracking(pageName: string, metadata?: Record<string, any>) {
  const { user, profile } = useAuthContext();
  const trackedRef = useRef(false);
  
  useEffect(() => {
    if (!user || !profile || trackedRef.current) return;
    
    const siteId = profile.activeSiteId || profile.siteIds?.[0] || '';
    
    trackMappedTelemetry({
      eventType: 'page_viewed',
      category: 'navigation',
      userId: user.uid,
      userRole: profile.role as UserRole,
      siteId,
      metadata: {
        page: pageName,
        ...metadata
      }
    }).catch(err => console.warn('Telemetry failed:', err));
    
    trackedRef.current = true;
  }, [user, profile, pageName, metadata]);
}

/**
 * Track session start/end automatically
 * 
 * @example
 * function SessionPage({ sessionId }: { sessionId: string }) {
 *   useSessionTracking(sessionId);
 *   return <div>Session content</div>;
 * }
 */
export function useSessionTracking(sessionId: string) {
  const { user, profile } = useAuthContext();
  const startedRef = useRef(false);
  
  useEffect(() => {
    if (!user || !profile || !sessionId || startedRef.current) return;
    
    const siteId = profile.activeSiteId || profile.siteIds?.[0] || '';
    
    // Track session start
    trackMappedTelemetry({
      eventType: 'session_started',
      category: 'engagement',
      userId: user.uid,
      userRole: profile.role as UserRole,
      siteId,
      metadata: { sessionId }
    }).catch(err => console.warn('Telemetry failed:', err));
    
    startedRef.current = true;
    
    // Track session end on unmount
    return () => {
      trackMappedTelemetry({
        eventType: 'session_completed',
        category: 'engagement',
        userId: user.uid,
        userRole: profile.role as UserRole,
        siteId,
        metadata: { sessionId }
      }).catch(err => console.warn('Telemetry failed:', err));
    };
  }, [user, profile, sessionId]);
}

/**
 * Track interaction events (clicks, submissions, etc.)
 * 
 * @example
 * function MissionCard({ missionId }: { missionId: string }) {
 *   const trackClick = useInteractionTracking();
 *   
 *   return (
 *     <button onClick={() => trackClick('feature_discovered', { missionId })}>
 *       View Mission
 *     </button>
 *   );
 * }
 */
export function useInteractionTracking() {
  const { user, profile } = useAuthContext();
  
  return (eventType: 'page_viewed' | 'feature_discovered' | 'help_accessed', metadata?: Record<string, any>) => {
    if (!user || !profile) return;
    
    const siteId = profile.activeSiteId || profile.siteIds?.[0] || '';
    
    trackMappedTelemetry({
      eventType: eventType,
      category: 'navigation',
      userId: user.uid,
      userRole: profile.role as UserRole,
      siteId,
      metadata
    }).catch(err => console.warn('Telemetry failed:', err));
  };
}

/**
 * Track autonomy events (choice, goal setting, etc.)
 * 
 * @example
 * function MissionBrowser() {
 *   const trackAutonomy = useAutonomyTracking();
 *   
 *   const handleMissionSelect = (missionId: string) => {
 *     trackAutonomy('mission_selected', { missionId, difficulty: 'medium' });
 *   };
 *   
 *   return <div>...</div>;
 * }
 */
export function useAutonomyTracking() {
  const { user, profile } = useAuthContext();
  
  return (eventType: 'mission_selected' | 'goal_set' | 'difficulty_chosen' | 'interest_profile_updated', metadata?: Record<string, any>) => {
    if (!user || !profile) return;
    
    const siteId = profile.activeSiteId || profile.siteIds?.[0] || '';
    
    trackMappedTelemetry({
      eventType: eventType,
      category: 'autonomy',
      userId: user.uid,
      userRole: profile.role as UserRole,
      siteId,
      metadata
    }).catch(err => console.warn('Telemetry failed:', err));
  };
}

/**
 * Track competence events (skill proofs, checkpoints, etc.)
 * 
 * @example
 * function CheckpointSubmission() {
 *   const trackCompetence = useCompetenceTracking();
 *   
 *   const handleSubmit = async () => {
 *     await submitCheckpoint();
 *     trackCompetence('checkpoint_passed', { checkpointNumber: 3 });
 *   };
 *   
 *   return <button onClick={handleSubmit}>Submit</button>;
 * }
 */
export function useCompetenceTracking() {
  const { user, profile } = useAuthContext();
  
  return (eventType: 'artifact_submitted' | 'checkpoint_passed' | 'skill_proven' | 'badge_earned', metadata?: Record<string, any>) => {
    if (!user || !profile) return;
    
    const siteId = profile.activeSiteId || profile.siteIds?.[0] || '';
    
    trackMappedTelemetry({
      eventType: eventType,
      category: 'competence',
      userId: user.uid,
      userRole: profile.role as UserRole,
      siteId,
      metadata
    }).catch(err => console.warn('Telemetry failed:', err));
  };
}

/**
 * Track belonging events (recognition, showcase, etc.)
 * 
 * @example
 * function RecognitionButton({ recipientId }: { recipientId: string }) {
 *   const trackBelonging = useBelongingTracking();
 *   
 *   const handleGiveRecognition = () => {
 *     trackBelonging('recognition_given', { recipientId, type: 'helpful' });
 *   };
 *   
 *   return <button onClick={handleGiveRecognition}>Give Props</button>;
 * }
 */
export function useBelongingTracking() {
  const { user, profile } = useAuthContext();
  
  return (eventType: 'showcase_submitted' | 'recognition_given' | 'peer_feedback_given' | 'crew_joined', metadata?: Record<string, any>) => {
    if (!user || !profile) return;
    
    const siteId = profile.activeSiteId || profile.siteIds?.[0] || '';
    
    trackMappedTelemetry({
      eventType: eventType,
      category: 'belonging',
      userId: user.uid,
      userRole: profile.role as UserRole,
      siteId,
      metadata
    }).catch(err => console.warn('Telemetry failed:', err));
  };
}

/**
 * Track reflection events (metacognition)
 * 
 * @example
 * function ReflectionPrompt() {
 *   const trackReflection = useReflectionTracking();
 *   
 *   const handleSubmit = (response: string) => {
 *     trackReflection('reflection_submitted', { responseLength: response.length });
 *   };
 *   
 *   return <textarea onChange={...} />;
 * }
 */
export function useReflectionTracking() {
  const { user, profile } = useAuthContext();
  
  return (eventType: 'reflection_submitted' | 'effort_rated' | 'enjoyment_rated', metadata?: Record<string, any>) => {
    if (!user || !profile) return;
    
    const siteId = profile.activeSiteId || profile.siteIds?.[0] || '';
    
    trackMappedTelemetry({
      eventType: eventType,
      category: 'reflection',
      userId: user.uid,
      userRole: profile.role as UserRole,
      siteId,
      metadata
    }).catch(err => console.warn('Telemetry failed:', err));
  };
}

/**
 * Track AI interactions
 * 
 * @example
 * function AICoach() {
 *   const trackAI = useAITracking();
 *   
 *   const handleQuery = (query: string) => {
 *     trackAI('ai_hint_requested', { query });
 *   };
 *   
 *   return <input onSubmit={...} />;
 * }
 */
export function useAITracking() {
  const { user, profile } = useAuthContext();
  
  return (eventType: 'ai_hint_requested' | 'ai_rubric_check' | 'ai_debug_help' | 'ai_critique_requested', metadata?: Record<string, any>) => {
    if (!user || !profile) return;
    
    const siteId = profile.activeSiteId || profile.siteIds?.[0] || '';
    
    trackMappedTelemetry({
      eventType: eventType,
      category: 'ai_interaction',
      userId: user.uid,
      userRole: profile.role as UserRole,
      siteId,
      metadata
    }).catch(err => console.warn('Telemetry failed:', err));
  };
}

/**
 * Track performance metrics (load times, errors, etc.)
 * 
 * @example
 * function DataLoader() {
 *   const trackPerformance = usePerformanceTracking();
 *   
 *   useEffect(() => {
 *     const start = Date.now();
 *     fetchData().then(() => {
 *       trackPerformance('page_load_time', { duration: Date.now() - start });
 *     });
 *   }, []);
 *   
 *   return <div>...</div>;
 * }
 */
export function usePerformanceTracking() {
  const { user, profile } = useAuthContext();
  
  return (eventType: 'page_load_time' | 'api_error' | 'client_error', metadata?: Record<string, any>) => {
    if (!user || !profile) return;
    
    const siteId = profile.activeSiteId || profile.siteIds?.[0] || '';
    
    trackMappedTelemetry({
      eventType: eventType,
      category: 'performance',
      userId: user.uid,
      userRole: profile.role as UserRole,
      siteId,
      metadata
    }).catch(err => console.warn('Telemetry failed:', err));
  };
}
