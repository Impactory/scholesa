import { resolveActiveSiteId } from './activeSite';

describe('resolveActiveSiteId', () => {
  it('prefers activeSiteId when available', () => {
    expect(
      resolveActiveSiteId({
        activeSiteId: 'active-site',
        siteIds: ['fallback-site'],
        studioId: 'legacy-site',
      }),
    ).toBe('active-site');
  });

  it('falls back to the first siteIds entry before legacy studioId', () => {
    expect(
      resolveActiveSiteId({
        activeSiteId: '',
        siteIds: ['first-site', 'second-site'],
        studioId: 'legacy-site',
      }),
    ).toBe('first-site');
  });

  it('falls back to legacy studioId when newer site fields are missing', () => {
    expect(
      resolveActiveSiteId({
        siteIds: [],
        studioId: 'legacy-site',
      }),
    ).toBe('legacy-site');
  });

  it('returns null when no usable site context exists', () => {
    expect(
      resolveActiveSiteId({
        activeSiteId: '   ',
        siteIds: ['   '],
        studioId: '',
      }),
    ).toBeNull();
  });
});
