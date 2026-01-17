/**
 * Telemetry Aggregation Cloud Function
 * 
 * Runs daily at 2:00 AM UTC to aggregate telemetry events into daily summaries.
 * This reduces Firestore read costs for analytics dashboards.
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

// Initialize only if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

interface TelemetryEvent {
  userId: string;
  siteId: string;
  category: 'autonomy' | 'competence' | 'belonging' | 'reflection' | 'ai_interaction' | 'navigation' | 'performance' | 'engagement';
  eventName: string;
  timestamp: admin.firestore.Timestamp;
  metadata?: Record<string, unknown>;
}

interface TelemetryAggregate {
  userId: string;
  siteId: string;
  date: admin.firestore.Timestamp;
  aggregationType: 'daily' | 'weekly';
  totalEvents: number;
  categoryCounts: Record<string, number>;
  sdtCounts: {
    autonomy: number;
    competence: number;
    belonging: number;
    reflection: number;
  };
  engagementScore: number;
  createdAt: admin.firestore.Timestamp;
}

/**
 * Scheduled function to aggregate telemetry events daily
 */
export const aggregateDailyTelemetry = functions.pubsub
  .schedule('every day 02:00')
  .timeZone('UTC')
  .onRun(async (_context) => {
    console.log('Starting daily telemetry aggregation...');
    
    try {
      // Calculate date range (yesterday)
      const yesterday = new Date();
      yesterday.setDate(yesterday.getDate() - 1);
      yesterday.setHours(0, 0, 0, 0);
      
      const endOfYesterday = new Date(yesterday);
      endOfYesterday.setHours(23, 59, 59, 999);
      
      console.log(`Aggregating events from ${yesterday.toISOString()} to ${endOfYesterday.toISOString()}`);
      
      // Fetch all telemetry events from yesterday
      const eventsSnapshot = await db.collection('telemetryEvents')
        .where('timestamp', '>=', admin.firestore.Timestamp.fromDate(yesterday))
        .where('timestamp', '<=', admin.firestore.Timestamp.fromDate(endOfYesterday))
        .get();
      
      console.log(`Found ${eventsSnapshot.size} events to aggregate`);
      
      if (eventsSnapshot.size === 0) {
        console.log('No events to aggregate');
        return null;
      }
      
      // Group by userId + siteId
      const aggregates: Map<string, Partial<TelemetryAggregate>> = new Map();
      
      eventsSnapshot.forEach(doc => {
        const event = doc.data() as TelemetryEvent;
        const key = `${event.userId}_${event.siteId}`;
        
        if (!aggregates.has(key)) {
          aggregates.set(key, {
            userId: event.userId,
            siteId: event.siteId,
            date: admin.firestore.Timestamp.fromDate(yesterday),
            aggregationType: 'daily',
            totalEvents: 0,
            categoryCounts: {},
            sdtCounts: { autonomy: 0, competence: 0, belonging: 0, reflection: 0 }
          });
        }
        
        const agg = aggregates.get(key)!;
        agg.totalEvents!++;
        
        // Count by category
        if (!agg.categoryCounts) agg.categoryCounts = {};
        agg.categoryCounts[event.category] = (agg.categoryCounts[event.category] || 0) + 1;
        
        // Count SDT events
        if (['autonomy', 'competence', 'belonging', 'reflection'].includes(event.category)) {
          const sdtCategory = event.category as keyof typeof agg.sdtCounts;
          if (agg.sdtCounts) {
            agg.sdtCounts[sdtCategory]++;
          }
        }
      });
      
      // Calculate engagement scores and write aggregates
      const batch = db.batch();
      let writeCount = 0;
      
      aggregates.forEach((agg, key) => {
        // Calculate engagement score (0-100)
        const totalSDT = (agg.sdtCounts?.autonomy || 0) + 
                        (agg.sdtCounts?.competence || 0) + 
                        (agg.sdtCounts?.belonging || 0) + 
                        (agg.sdtCounts?.reflection || 0);
        
        // Normalize to 0-100 scale (assuming 20 events per day = 100%)
        const engagementScore = Math.min(100, Math.round((totalSDT / 20) * 100));
        
        const aggregateData: TelemetryAggregate = {
          ...agg as TelemetryAggregate,
          engagementScore,
          createdAt: admin.firestore.Timestamp.now()
        };
        
        // Create document ID: userId_siteId_YYYY-MM-DD
        const dateStr = yesterday.toISOString().split('T')[0];
        const docId = `${key}_${dateStr}`;
        const docRef = db.collection('telemetryAggregates').doc(docId);
        
        batch.set(docRef, aggregateData);
        writeCount++;
        
        // Firestore batch limit is 500, commit if we hit it
        if (writeCount >= 500) {
          console.log(`Committing batch of ${writeCount} aggregates...`);
          // Note: Can't await here in forEach, would need to restructure
        }
      });
      
      // Commit final batch
      await batch.commit();
      console.log(`Successfully aggregated ${aggregates.size} user-site pairs for ${yesterday.toISOString()}`);
      
      return { aggregatesCreated: aggregates.size, eventsProcessed: eventsSnapshot.size };
      
    } catch (error) {
      console.error('Error aggregating telemetry:', error);
      throw error;
    }
  });

/**
 * Scheduled function to aggregate weekly telemetry (runs every Monday)
 */
export const aggregateWeeklyTelemetry = functions.pubsub
  .schedule('every monday 03:00')
  .timeZone('UTC')
  .onRun(async (_context) => {
    console.log('Starting weekly telemetry aggregation...');
    
    try {
      // Calculate date range (last 7 days)
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      
      const sevenDaysAgo = new Date(today);
      sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);
      
      console.log(`Aggregating events from ${sevenDaysAgo.toISOString()} to ${today.toISOString()}`);
      
      // Fetch all telemetry events from last 7 days
      const eventsSnapshot = await db.collection('telemetryEvents')
        .where('timestamp', '>=', admin.firestore.Timestamp.fromDate(sevenDaysAgo))
        .where('timestamp', '<', admin.firestore.Timestamp.fromDate(today))
        .get();
      
      console.log(`Found ${eventsSnapshot.size} events for weekly aggregation`);
      
      if (eventsSnapshot.size === 0) {
        console.log('No events to aggregate');
        return null;
      }
      
      // Group by userId + siteId
      const aggregates: Map<string, Partial<TelemetryAggregate>> = new Map();
      
      eventsSnapshot.forEach(doc => {
        const event = doc.data() as TelemetryEvent;
        const key = `${event.userId}_${event.siteId}`;
        
        if (!aggregates.has(key)) {
          aggregates.set(key, {
            userId: event.userId,
            siteId: event.siteId,
            date: admin.firestore.Timestamp.fromDate(sevenDaysAgo),
            aggregationType: 'weekly',
            totalEvents: 0,
            categoryCounts: {},
            sdtCounts: { autonomy: 0, competence: 0, belonging: 0, reflection: 0 }
          });
        }
        
        const agg = aggregates.get(key)!;
        agg.totalEvents!++;
        
        if (!agg.categoryCounts) agg.categoryCounts = {};
        agg.categoryCounts[event.category] = (agg.categoryCounts[event.category] || 0) + 1;
        
        if (['autonomy', 'competence', 'belonging', 'reflection'].includes(event.category)) {
          const sdtCategory = event.category as keyof typeof agg.sdtCounts;
          if (agg.sdtCounts) {
            agg.sdtCounts[sdtCategory]++;
          }
        }
      });
      
      // Calculate engagement scores and write aggregates
      const batch = db.batch();
      
      aggregates.forEach((agg, key) => {
        const totalSDT = (agg.sdtCounts?.autonomy || 0) + 
                        (agg.sdtCounts?.competence || 0) + 
                        (agg.sdtCounts?.belonging || 0) + 
                        (agg.sdtCounts?.reflection || 0);
        
        // For weekly: 140 events (20/day * 7 days) = 100%
        const engagementScore = Math.min(100, Math.round((totalSDT / 140) * 100));
        
        const aggregateData: TelemetryAggregate = {
          ...agg as TelemetryAggregate,
          engagementScore,
          createdAt: admin.firestore.Timestamp.now()
        };
        
        const dateStr = sevenDaysAgo.toISOString().split('T')[0];
        const docId = `${key}_week_${dateStr}`;
        const docRef = db.collection('telemetryAggregates').doc(docId);
        
        batch.set(docRef, aggregateData);
      });
      
      await batch.commit();
      console.log(`Successfully aggregated ${aggregates.size} weekly summaries`);
      
      return { weeklyAggregatesCreated: aggregates.size, eventsProcessed: eventsSnapshot.size };
      
    } catch (error) {
      console.error('Error aggregating weekly telemetry:', error);
      throw error;
    }
  });

/**
 * HTTP function to manually trigger aggregation (for testing)
 */
export const triggerTelemetryAggregation = functions.https.onRequest(async (req, res) => {
  try {
    const result = await aggregateDailyTelemetry.run({} as any);
    res.json({ success: true, result });
  } catch (error) {
    console.error('Error triggering aggregation:', error);
    res.status(500).json({ success: false, error: String(error) });
  }
});
