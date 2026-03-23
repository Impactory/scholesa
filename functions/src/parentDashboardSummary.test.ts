import { resolveParentCurrentLevel } from './parentDashboardSummary';

describe('parent dashboard current level honesty', () => {
  it('returns a rounded evidence-backed level when reviewed capability average exists', () => {
    expect(resolveParentCurrentLevel(2.34)).toBe(2);
    expect(resolveParentCurrentLevel(2.67)).toBe(3);
  });

  it('does not invent a level when no reviewed capability average exists', () => {
    expect(resolveParentCurrentLevel(null)).toBeNull();
    expect(resolveParentCurrentLevel(undefined)).toBeNull();
    expect(resolveParentCurrentLevel(0)).toBeNull();
    expect(resolveParentCurrentLevel(-1)).toBeNull();
  });
});