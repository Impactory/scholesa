import { uatSeedData } from './uat-seed-data';

type PrismaModelDelegate = {
  upsert?: (args: { where: { id: string }; update: Record<string, unknown>; create: Record<string, unknown> }) => Promise<unknown>;
};

type PrismaLikeClient = Record<string, PrismaModelDelegate | undefined>;

type SeedRecord = Record<string, unknown> & { id: string };

const users = Object.values(uatSeedData.usersByLoginRole).map((user) => ({
  id: user.id,
  tenantId: user.tenantId,
  organizationId: user.organizationId,
  email: user.email,
  displayName: user.displayName,
  role: user.role,
  grade: user.grade ?? null,
  stage: user.stage ?? null,
  aiPolicy: user.aiPolicy ?? null,
  purpose: user.purpose,
  restriction: user.restriction ?? null,
  access: user.access ?? null,
}));

export const prismaUatSeedData = {
  tenants: [uatSeedData.tenant],
  organizations: [uatSeedData.organization],
  cohorts: uatSeedData.cohorts,
  users,
  cohortMemberships: uatSeedData.cohorts.flatMap((cohort) =>
    cohort.learnerEmails.map((email) => {
      const learner = users.find((user) => user.email === email);

      return {
        id: `${cohort.id}-${learner?.id ?? email}`,
        tenantId: cohort.tenantId,
        organizationId: cohort.organizationId,
        cohortId: cohort.id,
        userId: learner?.id ?? email,
      };
    })
  ),
  familyLinks: [
    {
      id: 'family-link-builder',
      tenantId: uatSeedData.tenant.id,
      organizationId: uatSeedData.organization.id,
      familyUserId: uatSeedData.usersByLoginRole.family.id,
      learnerUserId: uatSeedData.usersByLoginRole.builder.id,
      permission: 'view-selected-progress-home-connections-milestones-portfolio-highlights',
      canEditOfficialEvidence: false,
      canEditCapabilityReviews: false,
    },
  ],
  mentorAssignments: [
    {
      id: 'mentor-assignment-showcase-builder',
      tenantId: uatSeedData.tenant.id,
      organizationId: uatSeedData.organization.id,
      mentorUserId: uatSeedData.usersByLoginRole.mentor.id,
      learnerUserId: uatSeedData.usersByLoginRole.builder.id,
      accessScope: 'assigned-showcase-portfolio-items-only',
    },
  ],
  aiPolicies: Object.values(uatSeedData.usersByLoginRole)
    .filter((user) => user.role === 'learner')
    .map((user) => ({
      id: `ai-policy-${user.id}`,
      tenantId: user.tenantId,
      learnerUserId: user.id,
      policy: user.aiPolicy,
      independentChatAllowed: user.aiPolicy !== 'educator-led-only',
      auditTrailRequired: user.aiPolicy !== 'educator-led-only',
    })),
  capabilities: uatSeedData.capabilities,
  missions: uatSeedData.missions,
  checkpoints: uatSeedData.checkpoints,
  rubrics: uatSeedData.rubrics,
} as const;

const modelMap = {
  tenants: 'tenant',
  organizations: 'organization',
  cohorts: 'cohort',
  users: 'user',
  cohortMemberships: 'cohortMembership',
  familyLinks: 'familyLearnerLink',
  mentorAssignments: 'mentorAssignment',
  aiPolicies: 'learnerAIPolicy',
  capabilities: 'capability',
  missions: 'mission',
  checkpoints: 'missionCheckpoint',
  rubrics: 'rubric',
} as const;

async function upsertRecords(
  prisma: PrismaLikeClient,
  modelName: string,
  records: readonly SeedRecord[]
): Promise<number> {
  const delegate = prisma[modelName];

  if (!delegate?.upsert) {
    return 0;
  }

  for (const record of records) {
    await delegate.upsert({
      where: { id: record.id },
      update: record,
      create: record,
    });
  }

  return records.length;
}

export async function seedPrismaUatData(prisma: PrismaLikeClient): Promise<Record<string, number>> {
  const counts: Record<string, number> = {};

  for (const [fixtureKey, modelName] of Object.entries(modelMap)) {
    const records = prismaUatSeedData[fixtureKey as keyof typeof prismaUatSeedData] as readonly SeedRecord[];
    counts[fixtureKey] = await upsertRecords(prisma, modelName, records);
  }

  return counts;
}
