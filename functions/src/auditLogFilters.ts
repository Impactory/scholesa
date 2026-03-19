export interface AuditLogFilters {
  entityId: string;
  entityType: string;
  actions: string[];
}

export interface AuditLogRecord {
  action?: unknown;
  entityId?: unknown;
  entityType?: unknown;
  [key: string]: unknown;
}

function trimString(value: unknown): string {
  return typeof value === 'string' ? value.trim() : '';
}

export function normalizeAuditLogFilters(data: Record<string, unknown> | null | undefined): AuditLogFilters {
  const entityId = trimString(data?.entityId);
  const entityType = trimString(data?.entityType);
  const action = trimString(data?.action);
  const actions = Array.isArray(data?.actions)
    ? data.actions
        .filter((value): value is string => typeof value === 'string' && value.trim().length > 0)
        .map((value) => value.trim())
        .slice(0, 10)
    : [];

  return {
    entityId,
    entityType,
    actions: action ? [action] : actions,
  };
}

export function matchesAuditLogFilters(entry: AuditLogRecord, filters: AuditLogFilters): boolean {
  if (filters.entityId && trimString(entry.entityId) !== filters.entityId) return false;
  if (filters.entityType && trimString(entry.entityType) !== filters.entityType) return false;
  if (filters.actions.length > 0 && !filters.actions.includes(trimString(entry.action))) return false;
  return true;
}