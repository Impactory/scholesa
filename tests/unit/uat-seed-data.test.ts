import { prismaUatSeedData } from '../fixtures/prisma-seed-data';
import { uatMissionDefinitions } from '../fixtures/uat-missions';
import { getLearnerRoles, getUatUser, uatSeedData } from '../fixtures/uat-seed-data';

describe('Scholesa UAT seed data', () => {
  it('defines the Summer Pilot tenant, organization, cohorts, and role users', () => {
    expect(uatSeedData.tenant.name).toBe('Scholesa Summer Pilot 2026');
    expect(uatSeedData.organization.name).toBe('Scholesa Pilot Academy');
    expect(uatSeedData.cohorts.map((cohort) => cohort.name)).toEqual([
      'Discoverers Grades 1-3',
      'Builders Grades 4-6',
      'Explorers Grades 7-9',
      'Innovators Grades 10-12',
    ]);

    expect(getUatUser('admin')).toMatchObject({ email: 'admin@scholesa.test', role: 'admin' });
    expect(getUatUser('educator')).toMatchObject({ email: 'educator@scholesa.test', role: 'educator' });
    expect(getUatUser('family')).toMatchObject({
      email: 'family@scholesa.test',
      role: 'family',
      linkedLearnerEmail: 'builder@scholesa.test',
    });
    expect(getUatUser('mentor')).toMatchObject({
      email: 'mentor@scholesa.test',
      role: 'mentor',
      access: 'Assigned showcase or portfolio items only.',
    });
  });

  it('preserves stage-specific learner AI policy restrictions', () => {
    expect(getLearnerRoles().map((role) => getUatUser(role).aiPolicy)).toEqual([
      'educator-led-only',
      'guided-assistive-use',
      'logged-analytical-use',
      'advanced-assistive-use-full-audit',
    ]);
    expect(getUatUser('discoverer').restriction).toBe('No independent learner AI chat.');
  });

  it('defines the requested UAT missions with evidence expectations', () => {
    expect(uatMissionDefinitions).toEqual([
      expect.objectContaining({
        title: 'My Helpful Invention Studio',
        stage: 'Discoverers',
        grades: '1-3',
        aiPolicy: 'educator-led-only',
        expectedEvidence: expect.arrayContaining(['Oral explain-it-back']),
      }),
      expect.objectContaining({
        title: 'Eco-Smart City Lab',
        stage: 'Builders',
        grades: '4-6',
        aiPolicy: 'guided-assistive-use',
        expectedEvidence: expect.arrayContaining(['Optional AI-use summary if MiloOS Coach was used']),
      }),
      expect.objectContaining({
        title: 'AI Media Detective Lab',
        stage: 'Explorers',
        grades: '7-9',
        aiPolicy: 'logged-analytical-use',
        expectedEvidence: expect.arrayContaining(['AI prompt log']),
      }),
      expect.objectContaining({
        title: 'Venture Sprint',
        stage: 'Innovators',
        grades: '10-12',
        aiPolicy: 'advanced-assistive-use-full-audit',
        expectedEvidence: expect.arrayContaining(['AI audit trail']),
      }),
    ]);
  });

  it('provides Prisma-shaped seed records without requiring a live Prisma client', () => {
    expect(prismaUatSeedData.tenants).toHaveLength(1);
    expect(prismaUatSeedData.users).toHaveLength(8);
    expect(prismaUatSeedData.familyLinks[0]).toMatchObject({
      canEditOfficialEvidence: false,
      canEditCapabilityReviews: false,
    });
    expect(prismaUatSeedData.aiPolicies).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          learnerUserId: getUatUser('innovator').id,
          policy: 'advanced-assistive-use-full-audit',
          auditTrailRequired: true,
        }),
      ])
    );
  });
});
