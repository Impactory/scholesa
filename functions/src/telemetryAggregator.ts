/**
 * Telemetry Aggregation Cloud Functions (v2)
 *
 * Runs daily at 2:00 AM UTC to aggregate telemetry events into daily summaries.
 * This reduces Firestore read costs for analytics dashboards.
 */

import { onSchedule } from 'firebase-functions/v2/scheduler';
import { onRequest } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import './gen2Runtime';

// Initialize only if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

interface TelemetryEvent {
  userId: string;
  siteId: string;
  category: 'autonomy' | 'competence' | 'belonging' | 'reflection' | 'ai_interaction' | 'navigation' | 'performance' | 'engagement';
  event?: string;
  eventName: string;
  timestamp: admin.firestore.Timestamp;
  metadata?: Record<string, unknown>;
}

interface VoiceMetricsAggregate {
  voiceAttemptCount: number;
  transcribeSuccessCount: number;
  messageCount: number;
  ttsCount: number;
  blockedCount: number;
  escalatedCount: number;
  transcribeEscalationCount: number;
  captureAttemptCount: number;
  captureSuccessRate: number | null;
}

interface TelemetryAggregate {
  userId: string;
  siteId: string;
  date: admin.firestore.Timestamp;
  aggregationType: 'daily' | 'weekly';
  period: 'daily' | 'weekly';
  totalEvents: number;
  eventCounts: Record<string, number>;
  categoryCounts: Record<string, number>;
  sdtCounts: {
    autonomy: number;
    competence: number;
    belonging: number;
    reflection: number;
  };
  voiceMetrics: VoiceMetricsAggregate;
  engagementScore: number | null;
  createdAt: admin.firestore.Timestamp;
}

function createEmptyVoiceMetrics(): VoiceMetricsAggregate {
  return {
    voiceAttemptCount: 0,
    transcribeSuccessCount: 0,
    messageCount: 0,
    ttsCount: 0,
    blockedCount: 0,
    escalatedCount: 0,
    transcribeEscalationCount: 0,
    captureAttemptCount: 0,
    captureSuccessRate: null,
  };
}

function resolveEventName(event: TelemetryEvent): string | null {
  const candidates = [
    event.event,
    event.eventName,
    event.metadata?.eventType,
    event.metadata?.eventName,
  ];
  for (const candidate of candidates) {
    if (typeof candidate === 'string' && candidate.trim().length > 0) {
      return candidate.trim();
    }
  }
  return null;
}

function updateVoiceMetrics(
  metrics: VoiceMetricsAggregate,
  eventName: string | null,
  metadata: Record<string, unknown> | undefined,
): void {
  if (!eventName || !eventName.startsWith('voice.')) return;

  metrics.voiceAttemptCount += 1;
  if (eventName === 'voice.transcribe') metrics.transcribeSuccessCount += 1;
  if (eventName === 'voice.message') metrics.messageCount += 1;
  if (eventName === 'voice.tts') metrics.ttsCount += 1;
  if (eventName === 'voice.blocked') metrics.blockedCount += 1;
  if (eventName === 'voice.escalated') {
    metrics.escalatedCount += 1;
    const endpoint = typeof metadata?.endpoint === 'string' ? metadata.endpoint.trim() : '';
    if (endpoint === 'voice_transcribe') {
      metrics.transcribeEscalationCount += 1;
    }
  }
}

function finalizeVoiceMetrics(metrics: VoiceMetricsAggregate): VoiceMetricsAggregate {
  const captureAttemptCount = metrics.transcribeSuccessCount + metrics.transcribeEscalationCount;
  return {
    ...metrics,
    captureAttemptCount,
    captureSuccessRate: captureAttemptCount > 0
      ? Math.round((metrics.transcribeSuccessCount / captureAttemptCount) * 1000) / 1000
      : null,
  };
}

/** Helper: run daily aggregation logic */
async function runDailyAggregation(): Promise<{ aggregatesCreated: number; eventsProcessed: number } | null> {
  console.log('Starting daily telemetry aggregation...');

  const yesterday = new Date();
  yesterday.setDate(yesterday.getDate() - 1);
  yesterday.setHours(0, 0, 0, 0);

  const endOfYesterday = new Date(yesterday);
  endOfYesterday.setHours(23, 59, 59, 999);

  console.log(`Aggregating events from ${yesterday.toISOString()} to ${endOfYesterday.toISOString()}`);

  const eventsSnapshot = await db.collection('telemetryEvents')
    .where('timestamp', '>=', admin.firestore.Timestamp.fromDate(yesterday))
    .where('timestamp', '<=', admin.firestore.Timestamp.fromDate(endOfYesterday))
    .get();

  console.log(`Found ${eventsSnapshot.size} events to aggregate`);

  if (eventsSnapshot.size === 0) {
    console.log('No events to aggregate');
    return null;
  }

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
        period: 'daily',
        totalEvents: 0,
        eventCounts: {},
        categoryCounts: {},
        sdtCounts: { autonomy: 0, competence: 0, belonging: 0, reflection: 0 },
        voiceMetrics: createEmptyVoiceMetrics(),
      });
    }

    const agg = aggregates.get(key)!;
    agg.totalEvents!++;

    const eventName = resolveEventName(event);
    if (!agg.eventCounts) agg.eventCounts = {};
    if (eventName) {
      agg.eventCounts[eventName] = (agg.eventCounts[eventName] || 0) + 1;
    }

    if (!agg.categoryCounts) agg.categoryCounts = {};
    agg.categoryCounts[event.category] = (agg.categoryCounts[event.category] || 0) + 1;

    if (!agg.voiceMetrics) agg.voiceMetrics = createEmptyVoiceMetrics();
    updateVoiceMetrics(agg.voiceMetrics, eventName, event.metadata);

    if (['autonomy', 'competence', 'belonging', 'reflection'].includes(event.category)) {
      const sdtCategory = event.category as keyof typeof agg.sdtCounts;
      if (agg.sdtCounts) {
        agg.sdtCounts[sdtCategory]++;
      }
    }
  });

  const batch = db.batch();

  aggregates.forEach((agg, key) => {
    const totalSDT = (agg.sdtCounts?.autonomy || 0) +
                    (agg.sdtCounts?.competence || 0) +
                    (agg.sdtCounts?.belonging || 0) +
                    (agg.sdtCounts?.reflection || 0);

    const engagementScore = totalSDT > 0
      ? Math.min(100, Math.round((totalSDT / 20) * 100))
      : null;

    const aggregateData: TelemetryAggregate = {
      ...agg as TelemetryAggregate,
      voiceMetrics: finalizeVoiceMetrics(agg.voiceMetrics ?? createEmptyVoiceMetrics()),
      engagementScore,
      createdAt: admin.firestore.Timestamp.now(),
    };

    const dateStr = yesterday.toISOString().split('T')[0];
    const docId = `${key}_${dateStr}`;
    const docRef = db.collection('telemetryAggregates').doc(docId);

    batch.set(docRef, aggregateData);
  });

  await batch.commit();
  console.log(`Successfully aggregated ${aggregates.size} user-site pairs for ${yesterday.toISOString()}`);

  return { aggregatesCreated: aggregates.size, eventsProcessed: eventsSnapshot.size };
}

/**
 * Scheduled function to aggregate telemetry events daily (v2)
 */
export const aggregateDailyTelemetry = onSchedule(
  { schedule: 'every day 02:00', timeZone: 'UTC' },
  async () => {
    await runDailyAggregation();
  },
);

/**
 * Scheduled function to aggregate weekly telemetry (runs every Monday, v2)
 */
export const aggregateWeeklyTelemetry = onSchedule(
  { schedule: 'every monday 03:00', timeZone: 'UTC' },
  async () => {
    console.log('Starting weekly telemetry aggregation...');

    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const sevenDaysAgo = new Date(today);
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);

    console.log(`Aggregating events from ${sevenDaysAgo.toISOString()} to ${today.toISOString()}`);

    const eventsSnapshot = await db.collection('telemetryEvents')
      .where('timestamp', '>=', admin.firestore.Timestamp.fromDate(sevenDaysAgo))
      .where('timestamp', '<', admin.firestore.Timestamp.fromDate(today))
      .get();

    console.log(`Found ${eventsSnapshot.size} events for weekly aggregation`);

    if (eventsSnapshot.size === 0) {
      console.log('No events to aggregate');
      return;
    }

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
          period: 'weekly',
          totalEvents: 0,
          eventCounts: {},
          categoryCounts: {},
          sdtCounts: { autonomy: 0, competence: 0, belonging: 0, reflection: 0 },
          voiceMetrics: createEmptyVoiceMetrics(),
        });
      }

      const agg = aggregates.get(key)!;
      agg.totalEvents!++;

      const eventName = resolveEventName(event);
      if (!agg.eventCounts) agg.eventCounts = {};
      if (eventName) {
        agg.eventCounts[eventName] = (agg.eventCounts[eventName] || 0) + 1;
      }

      if (!agg.categoryCounts) agg.categoryCounts = {};
      agg.categoryCounts[event.category] = (agg.categoryCounts[event.category] || 0) + 1;

      if (!agg.voiceMetrics) agg.voiceMetrics = createEmptyVoiceMetrics();
      updateVoiceMetrics(agg.voiceMetrics, eventName, event.metadata);

      if (['autonomy', 'competence', 'belonging', 'reflection'].includes(event.category)) {
        const sdtCategory = event.category as keyof typeof agg.sdtCounts;
        if (agg.sdtCounts) {
          agg.sdtCounts[sdtCategory]++;
        }
      }
    });

    const batch = db.batch();

    aggregates.forEach((agg, key) => {
      const totalSDT = (agg.sdtCounts?.autonomy || 0) +
                      (agg.sdtCounts?.competence || 0) +
                      (agg.sdtCounts?.belonging || 0) +
                      (agg.sdtCounts?.reflection || 0);

      const engagementScore = totalSDT > 0
        ? Math.min(100, Math.round((totalSDT / 140) * 100))
        : null;

      const aggregateData: TelemetryAggregate = {
        ...agg as TelemetryAggregate,
        voiceMetrics: finalizeVoiceMetrics(agg.voiceMetrics ?? createEmptyVoiceMetrics()),
        engagementScore,
        createdAt: admin.firestore.Timestamp.now(),
      };

      const dateStr = sevenDaysAgo.toISOString().split('T')[0];
      const docId = `${key}_week_${dateStr}`;
      const docRef = db.collection('telemetryAggregates').doc(docId);

      batch.set(docRef, aggregateData);
    });

    await batch.commit();
    console.log(`Successfully aggregated ${aggregates.size} weekly summaries`);
  },
);

/**
 * HTTP function to manually trigger daily aggregation (for testing, v2)
 */
export const triggerTelemetryAggregation = onRequest(async (_req, res) => {
  try {
    const result = await runDailyAggregation();
    res.json({ success: true, result });
  } catch (error) {
    console.error('Error triggering aggregation:', error);
    res.status(500).json({ success: false, error: String(error) });
  }
});
