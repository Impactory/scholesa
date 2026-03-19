import { asFiniteNumber, asTrimmedString } from './sharedStringNumber';

export const ANALYTICS_REPAIR_AUDIT_ACTIONS = [
  'telemetry_aggregate.backfilled',
  'kpi_pack.voice_reliability_backfilled',
] as const;

export interface AnalyticsRepairRunRecord {
  id: string;
  title: string;
  subtitle: string;
  status: string;
  updatedAt: string;
  siteId: string | null;
  actorRole: string;
  metadata: Record<string, string>;
}

interface AnalyticsRepairAuditEntry {
  id: string;
  action?: unknown;
  actorRole?: unknown;
  createdAt?: unknown;
  siteId?: unknown;
  details?: unknown;
}

function toIsoDate(value: unknown): string {
  if (value && typeof value === 'object' && 'toDate' in value && typeof (value as { toDate: () => Date }).toDate === 'function') {
    return (value as { toDate: () => Date }).toDate().toISOString();
  }
  if (typeof value === 'number') return new Date(value).toISOString();
  if (typeof value === 'string') {
    const parsed = Date.parse(value);
    if (!Number.isNaN(parsed)) return new Date(parsed).toISOString();
  }
  return new Date().toISOString();
}

function joinAvailableParts(parts: Array<string | null | undefined>): string {
  return parts.filter((part): part is string => typeof part === 'string' && part.trim().length > 0).join(' • ');
}

function metadataWithAvailableValues(values: Record<string, string | null | undefined>): Record<string, string> {
  return Object.fromEntries(
    Object.entries(values).filter((entry): entry is [string, string] => typeof entry[1] === 'string' && entry[1].trim().length > 0),
  );
}

function asAvailabilityLabel(value: unknown): string | null {
  const numeric = asFiniteNumber(value);
  return numeric != null ? String(numeric) : null;
}

function buildAnalyticsRepairMetadata(entry: AnalyticsRepairAuditEntry): Record<string, string> {
  const details = entry.details && typeof entry.details === 'object' && !Array.isArray(entry.details)
    ? entry.details as Record<string, unknown>
    : null;
  const startDate = typeof details?.startDate === 'string' && details.startDate.trim().length > 0
    ? details.startDate
    : null;
  const endDate = typeof details?.endDate === 'string' && details.endDate.trim().length > 0
    ? details.endDate
    : null;

  return metadataWithAvailableValues({
    siteId: asTrimmedString(entry.siteId) || null,
    processed: asAvailabilityLabel(details?.processed),
    updated: asAvailabilityLabel(details?.updated),
    skipped: asAvailabilityLabel(details?.skipped),
    aggregationType: typeof details?.aggregationType === 'string' ? details.aggregationType : null,
    period: typeof details?.period === 'string' ? details.period : null,
    force: typeof details?.force === 'boolean' ? String(details.force) : null,
    backfillWindow: joinAvailableParts([startDate, endDate]) || null,
  });
}

function analyticsRepairRunStatus(metadata: Record<string, string>): string {
  const updated = asFiniteNumber(metadata.updated);
  if (updated === 0) {
    return 'no-op';
  }
  return 'completed';
}

export function buildAnalyticsRepairRunRecord(entry: AnalyticsRepairAuditEntry): AnalyticsRepairRunRecord | null {
  const action = asTrimmedString(entry.action);
  if (!ANALYTICS_REPAIR_AUDIT_ACTIONS.includes(action as typeof ANALYTICS_REPAIR_AUDIT_ACTIONS[number])) {
    return null;
  }

  const metadata = buildAnalyticsRepairMetadata(entry);
  return {
    id: entry.id,
    title: action === 'telemetry_aggregate.backfilled'
      ? 'Telemetry aggregate backfill'
      : 'KPI voice backfill',
    subtitle: joinAvailableParts([
      metadata.updated ? `${metadata.updated} updated` : null,
      metadata.processed ? `${metadata.processed} processed` : null,
      metadata.backfillWindow,
    ]) || 'Backfill run recorded',
    status: analyticsRepairRunStatus(metadata),
    updatedAt: toIsoDate(entry.createdAt),
    siteId: asTrimmedString(entry.siteId) || null,
    actorRole: asTrimmedString(entry.actorRole) || 'unknown',
    metadata,
  };
}