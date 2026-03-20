export function formatWorkflowRecordUpdatedAt(value: string | null): string {
  if (!value) return 'Unavailable';
  const parsed = Date.parse(value);
  return Number.isNaN(parsed) ? 'Unavailable' : new Date(parsed).toLocaleString();
}