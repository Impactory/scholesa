import { matchesAuditLogFilters, normalizeAuditLogFilters } from './auditLogFilters';

describe('auditLogFilters', () => {
  it('prefers a singular action over the actions array and trims filter values', () => {
    expect(normalizeAuditLogFilters({
      entityId: ' entity-1 ',
      entityType: ' auditLogs ',
      action: ' telemetry_aggregate.backfilled ',
      actions: ['ignored.action'],
    })).toEqual({
      entityId: 'entity-1',
      entityType: 'auditLogs',
      actions: ['telemetry_aggregate.backfilled'],
    });
  });

  it('caps actions arrays and removes empty entries', () => {
    const filters = normalizeAuditLogFilters({
      actions: [
        'one', ' ', 'two', 'three', 'four', 'five',
        'six', 'seven', 'eight', 'nine', 'ten', 'eleven',
      ],
    });

    expect(filters.actions).toEqual(['one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten']);
  });

  it('matches records only when all requested filters align', () => {
    const filters = normalizeAuditLogFilters({
      entityId: 'bulk_backfill',
      entityType: 'telemetryAggregates',
      actions: ['telemetry_aggregate.backfilled', 'kpi_pack.voice_reliability_backfilled'],
    });

    expect(matchesAuditLogFilters({
      entityId: 'bulk_backfill',
      entityType: 'telemetryAggregates',
      action: 'telemetry_aggregate.backfilled',
    }, filters)).toBe(true);

    expect(matchesAuditLogFilters({
      entityId: 'bulk_backfill',
      entityType: 'telemetryAggregates',
      action: 'other.audit.event',
    }, filters)).toBe(false);

    expect(matchesAuditLogFilters({
      entityId: 'wrong',
      entityType: 'telemetryAggregates',
      action: 'telemetry_aggregate.backfilled',
    }, filters)).toBe(false);
  });
});