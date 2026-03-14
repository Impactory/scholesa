import {
  evaluateLearnerReminderWindow,
  enqueueLearnerGoalReminders,
  sendNotification,
} from './notificationPipeline';

describe('notificationPipeline', () => {
  it('sends direct message notification payloads to the notify provider', async () => {
    const fetchImpl = jest.fn(async (_url: string, init: { body: string }) => ({
      ok: true,
      status: 200,
      text: async () => '',
      json: async () => ({ providerMessageId: 'provider-message-123' }),
    }));

    const result = await sendNotification(
      {
        channel: 'push',
        siteId: 'site-1',
        threadId: 'thread-1',
        messageId: 'message-1',
      },
      {
        endpoint: 'https://notify.example.test',
        apiKey: 'secret-key',
        fetchImpl,
      },
    );

    expect(result.providerMessageId).toBe('provider-message-123');
    expect(fetchImpl).toHaveBeenCalledTimes(1);
    const body = JSON.parse(fetchImpl.mock.calls[0][1].body);
    expect(body.threadId).toBe('thread-1');
    expect(body.messageId).toBe('message-1');
    expect(body.siteId).toBe('site-1');
  });

  it('sends typed learner reminder payloads to the notify provider', async () => {
    const fetchImpl = jest.fn(async (_url: string, init: { body: string }) => ({
      ok: true,
      status: 200,
      text: async () => '',
      json: async () => ({ providerMessageId: 'provider-123' }),
    }));

    const result = await sendNotification(
      {
        channel: 'push',
        siteId: 'site-1',
        userId: 'learner-1',
        type: 'learner_goal_reminder',
        data: {
          localDayKey: '2026-03-13',
          weeklyTargetMinutes: 90,
        },
      },
      {
        endpoint: 'https://notify.example.test',
        apiKey: 'secret-key',
        fetchImpl,
      },
    );

    expect(result.providerMessageId).toBe('provider-123');
    expect(fetchImpl).toHaveBeenCalledTimes(1);
    const body = JSON.parse(fetchImpl.mock.calls[0][1].body);
    expect(body.type).toBe('learner_goal_reminder');
    expect(body.userId).toBe('learner-1');
    expect(body.data.localDayKey).toBe('2026-03-13');
  });

  it('evaluates weekday learner reminders in local time', () => {
    const result = evaluateLearnerReminderWindow(
      {
        id: 'site-1_learner-1',
        learnerId: 'learner-1',
        siteId: 'site-1',
        schedule: 'weekdays',
        weeklyTargetMinutes: 90,
        localeCode: 'en',
        timeZone: 'UTC',
        enabled: true,
      },
      new Date('2026-03-13T10:00:00.000Z'),
    );

    expect(result.shouldSend).toBe(true);
    expect(result.localDayKey).toBe('2026-03-13');
    expect(result.isWeekend).toBe(false);
  });

  it('queues learner reminder requests and telemetry from preference records', async () => {
    const writes: Array<Record<string, unknown>> = [];
    const telemetry: Array<Record<string, unknown>> = [];
    const collection = jest.fn((name: string) => {
      if (name === 'learnerReminderPreferences') {
        return {
          where: () => ({
            limit: () => ({
              get: async () => ({
                docs: [
                  {
                    id: 'site-1_learner-1',
                    data: () => ({
                      learnerId: 'learner-1',
                      siteId: 'site-1',
                      schedule: 'daily',
                      weeklyTargetMinutes: 90,
                      localeCode: 'en',
                      timeZone: 'UTC',
                      enabled: true,
                    }),
                  },
                ],
              }),
            }),
          }),
        };
      }
      return {
        where: () => ({
          where: () => ({
            where: () => ({
              limit: () => ({ get: async () => ({ empty: true }) }),
            }),
          }),
        }),
        add: async (doc: Record<string, unknown>) => {
          writes.push(doc);
        },
      };
    });

    const db = { collection } as unknown as FirebaseFirestore.Firestore;
    const result = await enqueueLearnerGoalReminders({
      db,
      reminderPreferencesCollection: 'learnerReminderPreferences',
      notificationRequestsCollection: 'notificationRequests',
      now: new Date('2026-03-13T10:00:00.000Z'),
      persistTelemetryEvent: async (payload) => {
        telemetry.push(payload as Record<string, unknown>);
      },
    });

    expect(result.queued).toBe(1);
    expect(writes).toHaveLength(1);
    expect(writes[0].type).toBe('learner_goal_reminder');
    expect(telemetry).toHaveLength(1);
    expect(telemetry[0].event).toBe('notification.requested');
  });
});