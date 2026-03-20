import { ANALYTICS_REPAIR_AUDIT_ACTIONS, buildAnalyticsRepairRunRecord } from './analyticsRepairRuns';

describe('analyticsRepairRuns', () => {
  it('only accepts the known analytics repair audit actions', () => {
    expect(ANALYTICS_REPAIR_AUDIT_ACTIONS).toEqual([
      'telemetry_aggregate.backfilled',
      'kpi_pack.voice_reliability_backfilled',
    ]);

    expect(buildAnalyticsRepairRunRecord({
      id: 'audit-unknown',
      action: 'other.audit.event',
      createdAt: '2026-03-19T12:00:00.000Z',
    })).toBeNull();
  });

  it('maps telemetry aggregate backfills into completed repair runs', () => {
    expect(buildAnalyticsRepairRunRecord({
      id: 'audit-1',
      action: 'telemetry_aggregate.backfilled',
      actorRole: 'hq',
      siteId: 'site-1',
      createdAt: '2026-03-19T10:00:00.000Z',
      details: {
        processed: 12,
        updated: 10,
        skipped: 2,
        aggregationType: 'daily',
        startDate: '2026-03-01T00:00:00.000Z',
        endDate: '2026-03-07T00:00:00.000Z',
      },
    })).toEqual(expect.objectContaining({
      id: 'audit-1',
      title: 'Telemetry aggregate backfill',
      status: 'completed',
      subtitle: '10 updated • 12 processed • 2026-03-01T00:00:00.000Z • 2026-03-07T00:00:00.000Z',
      metadata: expect.objectContaining({
        processed: '12',
        updated: '10',
        skipped: '2',
        aggregationType: 'daily',
      }),
    }));
  });

  it('maps zero-update KPI voice backfills into no-op repair runs', () => {
    expect(buildAnalyticsRepairRunRecord({
      id: 'audit-2',
      action: 'kpi_pack.voice_reliability_backfilled',
      actorRole: 'hq',
      siteId: 'site-2',
      createdAt: '2026-03-19T11:00:00.000Z',
      details: {
        processed: 4,
        updated: 0,
        period: 'quarter',
        force: true,
      },
    })).toEqual(expect.objectContaining({
      id: 'audit-2',
      title: 'KPI voice backfill',
      status: 'no-op',
      subtitle: '0 updated • 4 processed',
      metadata: expect.objectContaining({
        processed: '4',
        updated: '0',
        period: 'quarter',
        force: 'true',
      }),
    }));
  });

  it('preserves missing actorRole as absent instead of inventing unknown', () => {
    const result = buildAnalyticsRepairRunRecord({
      id: 'audit-3',
      action: 'telemetry_aggregate.backfilled',
      createdAt: '2026-03-19T12:00:00.000Z',
      details: {
        processed: 1,
        updated: 1,
      },
    });

    expect(result).toEqual(expect.objectContaining({
      id: 'audit-3',
      title: 'Telemetry aggregate backfill',
      status: 'completed',
    }));
    expect(result).not.toHaveProperty('actorRole');
  });

  it('preserves missing createdAt as absent instead of inventing a fresh timestamp', () => {
    const result = buildAnalyticsRepairRunRecord({
      id: 'audit-4',
      action: 'telemetry_aggregate.backfilled',
      details: {
        processed: 2,
        updated: 1,
      },
    });

    expect(result).toEqual(expect.objectContaining({
      id: 'audit-4',
      title: 'Telemetry aggregate backfill',
      updatedAt: null,
    }));
  });
});