/**
 * Real-time Analytics Hook
 * 
 * Provides live-updating analytics data using Firestore onSnapshot.
 * Automatically unsubscribes on cleanup to prevent memory leaks.
 */

import { useState, useEffect } from 'react';
import { collection, query, where, onSnapshot, orderBy, limit } from 'firebase/firestore';
import { db } from '@/src/firebase/client-init';
import { TelemetryService } from '@/src/lib/telemetry/telemetryService';

interface UseLearnerAnalyticsOptions {
  siteId: string;
  timeRange?: 'week' | 'month';
  limit?: number;
}

interface LearnerData {
  userId: string;
  name: string;
  engagementScore: number;
  autonomyScore: number;
  competenceScore: number;
  belongingScore: number;
  lastActive: Date | null;
}

/**
 * Real-time learner analytics for educators
 */
export function useLearnerAnalytics({ siteId, timeRange = 'week', limit: maxLearners = 50 }: UseLearnerAnalyticsOptions) {
  const [learners, setLearners] = useState<LearnerData[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);

  useEffect(() => {
    if (!siteId) {
      setLoading(false);
      return;
    }

    setLoading(true);
    let unsubscribeUsers: (() => void) | null = null;

    // Subscribe to users in this site
    const usersQuery = query(
      collection(db, 'users'),
      where('role', '==', 'learner'),
      where('siteIds', 'array-contains', siteId),
      limit(maxLearners)
    );

    unsubscribeUsers = onSnapshot(
      usersQuery,
      async (snapshot) => {
        try {
          const learnersData: LearnerData[] = [];

          for (const userDoc of snapshot.docs) {
            const userData = userDoc.data();
            const userId = userDoc.id;

            // Fetch SDT scores
            const sdtScores = await TelemetryService.getSDTProfile(userId, siteId);
            const engagementScore = Math.round((sdtScores.autonomy + sdtScores.competence + sdtScores.belonging) / 3);

            // Get last active time from telemetry
            const eventsQuery = query(
              collection(db, 'telemetryEvents'),
              where('userId', '==', userId),
              where('siteId', '==', siteId),
              orderBy('timestamp', 'desc'),
              limit(1)
            );
            
            const eventsSnapshot = await getDocs(eventsQuery);
            const lastActive = !eventsSnapshot.empty 
              ? eventsSnapshot.docs[0].data().timestamp.toDate()
              : null;

            learnersData.push({
              userId,
              name: userData.displayName || userData.email || 'Learner',
              engagementScore,
              autonomyScore: sdtScores.autonomy,
              competenceScore: sdtScores.competence,
              belongingScore: sdtScores.belonging,
              lastActive
            });
          }

          setLearners(learnersData);
          setLoading(false);
          setError(null);
        } catch (err) {
          console.error('Failed to load learner analytics:', err);
          setError(err as Error);
          setLoading(false);
        }
      },
      (err) => {
        console.error('Learner analytics subscription error:', err);
        setError(err);
        setLoading(false);
      }
    );

    return () => {
      if (unsubscribeUsers) {
        unsubscribeUsers();
      }
    };
  }, [siteId, timeRange, maxLearners]);

  return { learners, loading, error };
}

/**
 * Real-time platform stats for HQ
 */
export function usePlatformStats() {
  const [stats, setStats] = useState({
    totalSites: 0,
    totalLearners: 0,
    totalEducators: 0,
    avgEngagement: 0,
    activeSites: 0
  });
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // Subscribe to sites collection
    const unsubscribeSites = onSnapshot(
      collection(db, 'sites'),
      async (snapshot) => {
        const totalSites = snapshot.size;
        let totalLearners = 0;
        let totalEducators = 0;
        let totalEngagement = 0;
        let activeSites = 0;

        for (const siteDoc of snapshot.docs) {
          const siteId = siteDoc.id;

          // Count learners
          const learnersSnapshot = await getDocs(
            query(
              collection(db, 'users'),
              where('role', '==', 'learner'),
              where('siteIds', 'array-contains', siteId)
            )
          );
          totalLearners += learnersSnapshot.size;

          // Count educators
          const educatorsSnapshot = await getDocs(
            query(
              collection(db, 'users'),
              where('role', '==', 'educator'),
              where('siteIds', 'array-contains', siteId)
            )
          );
          totalEducators += educatorsSnapshot.size;

          // Get site engagement from aggregates
          const weekAgo = new Date();
          weekAgo.setDate(weekAgo.getDate() - 7);

          const aggregatesSnapshot = await getDocs(
            query(
              collection(db, 'telemetryAggregates'),
              where('siteId', '==', siteId),
              where('period', '==', 'daily')
            )
          );

          let siteEngagement = 0;
          let count = 0;

          aggregatesSnapshot.docs.forEach(doc => {
            const data = doc.data();
            const date = data.date?.toDate();
            if (date && date >= weekAgo && data.engagementScore !== undefined) {
              siteEngagement += data.engagementScore;
              count++;
            }
          });

          const avgSiteEngagement = count > 0 ? siteEngagement / count : 0;
          totalEngagement += avgSiteEngagement;

          if (avgSiteEngagement > 40) {
            activeSites++;
          }
        }

        setStats({
          totalSites,
          totalLearners,
          totalEducators,
          avgEngagement: totalSites > 0 ? Math.round(totalEngagement / totalSites) : 0,
          activeSites
        });
        setLoading(false);
      },
      (err) => {
        console.error('Platform stats subscription error:', err);
        setLoading(false);
      }
    );

    return () => unsubscribeSites();
  }, []);

  return { stats, loading };
}

/**
 * Real-time activity feed for parent dashboard
 */
export function useChildActivity(childId: string, siteId: string, limitCount: number = 10) {
  const [activities, setActivities] = useState<Array<{
    id: string;
    type: string;
    description: string;
    timestamp: Date;
  }>>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!childId || !siteId) {
      setLoading(false);
      return;
    }

    const unsubscribe = onSnapshot(
      query(
        collection(db, 'telemetryEvents'),
        where('userId', '==', childId),
        where('siteId', '==', siteId),
        orderBy('timestamp', 'desc'),
        limit(limitCount)
      ),
      (snapshot) => {
        const activitiesData = snapshot.docs.map(doc => {
          const data = doc.data();
          return {
            id: doc.id,
            type: data.eventName,
            description: getActivityDescription(data.eventName, data.metadata),
            timestamp: data.timestamp.toDate()
          };
        });
        
        setActivities(activitiesData);
        setLoading(false);
      },
      (err) => {
        console.error('Activity feed subscription error:', err);
        setLoading(false);
      }
    );

    return () => unsubscribe();
  }, [childId, siteId, limitCount]);

  return { activities, loading };
}

/**
 * Real-time SDT scores for a single user
 */
export function useSDTScores(userId: string, siteId: string) {
  const [scores, setScores] = useState({
    autonomy: 0,
    competence: 0,
    belonging: 0,
    overall: 0
  });
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!userId || !siteId) {
      setLoading(false);
      return;
    }

    // Subscribe to telemetry events to trigger recalculation
    const unsubscribe = onSnapshot(
      query(
        collection(db, 'telemetryEvents'),
        where('userId', '==', userId),
        where('siteId', '==', siteId),
        orderBy('timestamp', 'desc'),
        limit(1)
      ),
      async () => {
        try {
          const sdtScores = await TelemetryService.getSDTProfile(userId, siteId);
          const overall = Math.round((sdtScores.autonomy + sdtScores.competence + sdtScores.belonging) / 3);
          setScores({ ...sdtScores, overall });
          setLoading(false);
        } catch (err) {
          console.error('Failed to load SDT scores:', err);
          setLoading(false);
        }
      },
      (err) => {
        console.error('SDT scores subscription error:', err);
        setLoading(false);
      }
    );

    return () => unsubscribe();
  }, [userId, siteId]);

  return { scores, loading };
}

// Helper function
function getActivityDescription(eventName: string, _metadata: Record<string, unknown> | undefined): string {
  const descriptions: Record<string, string> = {
    'goal_set': 'Set a new learning goal',
    'checkpoint_passed': 'Passed a checkpoint',
    'badge_earned': 'Earned a badge',
    'recognition_given': 'Gave peer recognition',
    'recognition_received': 'Received peer recognition',
    'showcase_submitted': 'Submitted work to showcase',
    'reflection_submitted': 'Completed a reflection',
    'mission_selected': 'Started a new mission',
    'skill_mastered': 'Mastered a new skill'
  };
  
  return descriptions[eventName] || eventName.replace(/_/g, ' ');
}

// Re-export getDocs for backwards compatibility
import { getDocs } from 'firebase/firestore';
export { getDocs };
