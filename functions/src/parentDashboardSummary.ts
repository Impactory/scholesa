export function resolveParentCurrentLevel(averageLevel?: number | null): number | null {
  if (typeof averageLevel !== 'number' || !Number.isFinite(averageLevel) || averageLevel <= 0) {
    return null;
  }
  return Math.max(1, Math.round(averageLevel));
}