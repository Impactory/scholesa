export interface NotificationPayload {
  channel: string;
  siteId?: string;
  threadId?: string;
  messageId?: string;
  userId?: string;
  type?: string;
  data?: Record<string, unknown>;
}

export interface NotificationResponse {
  delivered: boolean;
  providerMessageId: string;
}

export interface LearnerReminderPreference {
  id: string;
  learnerId: string;
  siteId: string;
  schedule: string;
  weeklyTargetMinutes: number;
  localeCode?: string;
  timeZone?: string;
  valuePrompt?: string;
  enabled: boolean;
}

export interface TelemetryWriter {
  (payload: {
    event: string;
    userId: string;
    role?: 'learner' | 'educator' | 'parent' | 'site' | 'partner' | 'hq' | 'system';
    siteId?: string;
    metadata?: Record<string, unknown>;
  }): Promise<unknown>;
}

interface FetchResponseLike {
  ok: boolean;
  status: number;
  text(): Promise<string>;
  json(): Promise<{ providerMessageId?: string }>;
}

type FetchLike = (
  url: string,
  init: {
    method: string;
    headers: Record<string, string>;
    body: string;
  },
) => Promise<FetchResponseLike>;

export async function sendNotification(
  payload: NotificationPayload,
  deps: {
    endpoint: string;
    apiKey: string;
    fetchImpl: FetchLike;
  },
): Promise<NotificationResponse> {
  if (!deps.endpoint || !deps.apiKey) {
    throw new Error('Notification provider not configured');
  }
  if (!payload.threadId && !payload.type) {
    throw new Error('Notification payload requires threadId/messageId or type');
  }

  const response = await deps.fetchImpl(deps.endpoint, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${deps.apiKey}`,
    },
    body: JSON.stringify({
      channel: payload.channel,
      threadId: payload.threadId,
      messageId: payload.messageId,
      siteId: payload.siteId,
      userId: payload.userId,
      type: payload.type,
      data: payload.data,
    }),
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`Notify failed: ${response.status} ${text}`);
  }

  const data = await response.json();
  return {
    delivered: true,
    providerMessageId:
        data.providerMessageId ?? `prov-${payload.messageId ?? payload.type ?? 'notification'}`,
  };
}

export function evaluateLearnerReminderWindow(
  preference: LearnerReminderPreference,
  now: Date,
): { shouldSend: boolean; localDayKey: string; isWeekend: boolean } {
  const timeZone = preference.timeZone && preference.timeZone !== 'auto'
      ? preference.timeZone
      : 'UTC';
  const localWeekday = new Intl.DateTimeFormat('en-US', {
    weekday: 'short',
    timeZone,
  }).format(now);
  const localDayKey = new Intl.DateTimeFormat('en-CA', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(now);
  const isWeekend = localWeekday == 'Sat' || localWeekday == 'Sun';
  const shouldSend = preference.schedule == 'daily' ||
      (preference.schedule == 'weekdays' && !isWeekend) ||
      (preference.schedule == 'weekends' && isWeekend);
  return { shouldSend, localDayKey, isWeekend };
}

export async function enqueueLearnerGoalReminders(options: {
  db: FirebaseFirestore.Firestore;
  reminderPreferencesCollection: string;
  notificationRequestsCollection: string;
  now?: Date;
  limit?: number;
  persistTelemetryEvent: TelemetryWriter;
}): Promise<{ queued: number }> {
  const {
    db,
    reminderPreferencesCollection,
    notificationRequestsCollection,
    persistTelemetryEvent,
  } = options;
  const now = options.now ?? new Date();
  const limit = options.limit ?? 100;
  const prefsSnap = await db
    .collection(reminderPreferencesCollection)
    .where('enabled', '==', true)
    .limit(limit)
    .get();

  let queued = 0;
  for (const doc of prefsSnap.docs) {
    const data = doc.data();
    const preference: LearnerReminderPreference = {
      id: doc.id,
      learnerId: typeof data.learnerId === 'string' ? data.learnerId : '',
      siteId: typeof data.siteId === 'string' ? data.siteId : '',
      schedule: typeof data.schedule === 'string' ? data.schedule : 'off',
      weeklyTargetMinutes:
          typeof data.weeklyTargetMinutes === 'number' ? data.weeklyTargetMinutes : 0,
      localeCode: typeof data.localeCode === 'string' ? data.localeCode : 'en',
      timeZone: typeof data.timeZone === 'string' ? data.timeZone : 'UTC',
      valuePrompt: typeof data.valuePrompt === 'string' ? data.valuePrompt : '',
      enabled: data.enabled === true,
    };
    if (!preference.enabled || !preference.learnerId || !preference.siteId) {
      continue;
    }

    const windowResult = evaluateLearnerReminderWindow(preference, now);
    if (!windowResult.shouldSend) {
      continue;
    }

    const existing = await db
      .collection(notificationRequestsCollection)
      .where('userId', '==', preference.learnerId)
      .where('type', '==', 'learner_goal_reminder')
      .where('data.localDayKey', '==', windowResult.localDayKey)
      .limit(1)
      .get();
    if (!existing.empty) {
      continue;
    }

    await db.collection(notificationRequestsCollection).add({
      userId: preference.learnerId,
      siteId: preference.siteId,
      type: 'learner_goal_reminder',
      channel: 'push',
      status: 'pending',
      requestedBy: preference.learnerId,
      role: 'learner',
      rateKey: `${preference.learnerId}:learner_goal_reminder:${windowResult.localDayKey}`,
      data: {
        schedule: preference.schedule,
        weeklyTargetMinutes: preference.weeklyTargetMinutes,
        valuePrompt: preference.valuePrompt,
        localeCode: preference.localeCode,
        localDayKey: windowResult.localDayKey,
        preferenceId: preference.id,
      },
      createdAt: now,
    });

    await persistTelemetryEvent({
      event: 'notification.requested',
      userId: preference.learnerId,
      role: 'learner',
      siteId: preference.siteId,
      metadata: {
        channel: 'push',
        type: 'learner_goal_reminder',
        schedule: preference.schedule,
        localDayKey: windowResult.localDayKey,
        preferenceId: preference.id,
      },
    });
    queued += 1;
  }

  return { queued };
}