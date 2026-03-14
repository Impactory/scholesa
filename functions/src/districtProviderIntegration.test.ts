import {
  buildDistrictConnectionDocId,
  districtProviderAuditAction,
  districtProviderDefaultAuthBaseUrl,
  districtProviderDisplayName,
  districtProviderRosterSyncJobType,
  districtProviderSchoolField,
  districtProviderSectionsField,
  normalizeDistrictProvider,
} from './districtProviderIntegration';

describe('district provider integration helpers', () => {
  it('normalizes provider aliases for Clever and ClassLink', () => {
    expect(normalizeDistrictProvider('clever')).toBe('clever');
    expect(normalizeDistrictProvider('ClassLink')).toBe('classlink');
    expect(normalizeDistrictProvider('class_link')).toBe('classlink');
    expect(normalizeDistrictProvider('one-roster')).toBe('classlink');
    expect(normalizeDistrictProvider('google_classroom')).toBeNull();
  });

  it('builds stable provider metadata and naming', () => {
    expect(buildDistrictConnectionDocId('clever', 'site/1')).toBe('clever_site_1');
    expect(buildDistrictConnectionDocId('classlink', 'site/1')).toBe('classlink_site_1');
    expect(districtProviderDisplayName('clever')).toBe('Clever');
    expect(districtProviderDisplayName('classlink')).toBe('ClassLink');
    expect(districtProviderSchoolField('clever')).toBe('cleverSchools');
    expect(districtProviderSchoolField('classlink')).toBe('classlinkSchools');
    expect(districtProviderSectionsField('clever')).toBe('cleverSectionsBySchool');
    expect(districtProviderSectionsField('classlink')).toBe('classlinkSectionsBySchool');
  });

  it('derives auth urls, audit actions, and sync job names', () => {
    expect(districtProviderDefaultAuthBaseUrl('clever')).toContain('clever.com');
    expect(districtProviderDefaultAuthBaseUrl('classlink')).toContain('classlink.com');
    expect(districtProviderAuditAction('clever', 'connect.started')).toBe('clever.connect.started');
    expect(districtProviderAuditAction('classlink', 'disconnect')).toBe('classlink.disconnect');
    expect(districtProviderRosterSyncJobType('clever', 'preview')).toBe('clever_roster_preview');
    expect(districtProviderRosterSyncJobType('classlink', 'apply')).toBe('classlink_roster_apply');
  });
});