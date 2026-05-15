export type UatUserRole = 'admin' | 'educator' | 'learner' | 'family' | 'mentor';

export type UatLoginRole =
  | 'admin'
  | 'educator'
  | 'discoverer'
  | 'builder'
  | 'explorer'
  | 'innovator'
  | 'family'
  | 'mentor';

export type LearnerStage = 'Discoverers' | 'Builders' | 'Explorers' | 'Innovators';

export type LearnerAIPolicy =
  | 'educator-led-only'
  | 'guided-assistive-use'
  | 'logged-analytical-use'
  | 'advanced-assistive-use-full-audit';

export type UatUser = {
  id: string;
  email: string;
  password: string;
  displayName: string;
  role: UatUserRole;
  purpose: string;
  tenantId: string;
  organizationId: string;
  cohortIds: string[];
  grade?: number;
  stage?: LearnerStage;
  aiPolicy?: LearnerAIPolicy;
  linkedLearnerEmail?: string;
  access?: string;
  restriction?: string;
};

export type UatTenant = {
  id: string;
  name: string;
  schoolYear: string;
};

export type UatOrganization = {
  id: string;
  tenantId: string;
  name: string;
};

export type UatCohort = {
  id: string;
  tenantId: string;
  organizationId: string;
  name: string;
  gradeBand: string;
  learnerEmails: string[];
};

export type UatCapability = {
  id: string;
  tenantId: string;
  title: string;
  pillar: 'Future Skills' | 'Leadership' | 'Impact';
  observableBehavior: string;
};

export type UatMission = {
  id: string;
  tenantId: string;
  organizationId: string;
  title: string;
  capabilityIds: string[];
  checkpointIds: string[];
};

export type UatCheckpoint = {
  id: string;
  missionId: string;
  title: string;
  evidencePrompt: string;
  reflectionPrompt: string;
};

export type UatRubric = {
  id: string;
  title: string;
  capabilityId: string;
  levels: Array<{
    score: 1 | 2 | 3 | 4;
    label: string;
    descriptor: string;
  }>;
};

const password = 'Scholesa-UAT-2026!';
const tenantId = 'tenant-summer-pilot-2026';
const organizationId = 'org-scholesa-pilot-academy';

export const uatSeedData = {
  tenant: {
    id: tenantId,
    name: 'Scholesa Summer Pilot 2026',
    schoolYear: '2026',
  } satisfies UatTenant,
  organization: {
    id: organizationId,
    tenantId,
    name: 'Scholesa Pilot Academy',
  } satisfies UatOrganization,
  cohorts: [
    {
      id: 'cohort-discoverers-1-3',
      tenantId,
      organizationId,
      name: 'Discoverers Grades 1-3',
      gradeBand: '1-3',
      learnerEmails: ['discoverer@scholesa.test'],
    },
    {
      id: 'cohort-builders-4-6',
      tenantId,
      organizationId,
      name: 'Builders Grades 4-6',
      gradeBand: '4-6',
      learnerEmails: ['builder@scholesa.test'],
    },
    {
      id: 'cohort-explorers-7-9',
      tenantId,
      organizationId,
      name: 'Explorers Grades 7-9',
      gradeBand: '7-9',
      learnerEmails: ['explorer@scholesa.test'],
    },
    {
      id: 'cohort-innovators-10-12',
      tenantId,
      organizationId,
      name: 'Innovators Grades 10-12',
      gradeBand: '10-12',
      learnerEmails: ['innovator@scholesa.test'],
    },
  ] satisfies UatCohort[],
  usersByLoginRole: {
    admin: {
      id: 'user-admin-summer-pilot',
      email: 'admin@scholesa.test',
      password,
      displayName: 'Scholesa Pilot Admin',
      role: 'admin',
      purpose:
        'Manages tenant, organization, users, cohorts, policies, reporting, and platform operations.',
      tenantId,
      organizationId,
      cohortIds: [],
    },
    educator: {
      id: 'user-educator-summer-pilot',
      email: 'educator@scholesa.test',
      password,
      displayName: 'Scholesa Pilot Educator',
      role: 'educator',
      purpose:
        'Facilitates learning, assigns missions, monitors checkpoints, reviews evidence, performs capability reviews, provides feedback, and supports learner growth.',
      tenantId,
      organizationId,
      cohortIds: [
        'cohort-discoverers-1-3',
        'cohort-builders-4-6',
        'cohort-explorers-7-9',
        'cohort-innovators-10-12',
      ],
    },
    discoverer: {
      id: 'user-learner-discoverer',
      email: 'discoverer@scholesa.test',
      password,
      displayName: 'Drew Discoverer',
      role: 'learner',
      purpose: 'Young learner participating in educator-led capability missions.',
      tenantId,
      organizationId,
      cohortIds: ['cohort-discoverers-1-3'],
      grade: 2,
      stage: 'Discoverers',
      aiPolicy: 'educator-led-only',
      restriction: 'No independent learner AI chat.',
    },
    builder: {
      id: 'user-learner-builder',
      email: 'builder@scholesa.test',
      password,
      displayName: 'Bailey Builder',
      role: 'learner',
      purpose: 'Learner building artifacts and guided reflections for capability evidence.',
      tenantId,
      organizationId,
      cohortIds: ['cohort-builders-4-6'],
      grade: 5,
      stage: 'Builders',
      aiPolicy: 'guided-assistive-use',
    },
    explorer: {
      id: 'user-learner-explorer',
      email: 'explorer@scholesa.test',
      password,
      displayName: 'Emery Explorer',
      role: 'learner',
      purpose: 'Learner using logged analytical support for missions and reflections.',
      tenantId,
      organizationId,
      cohortIds: ['cohort-explorers-7-9'],
      grade: 8,
      stage: 'Explorers',
      aiPolicy: 'logged-analytical-use',
    },
    innovator: {
      id: 'user-learner-innovator',
      email: 'innovator@scholesa.test',
      password,
      displayName: 'Indigo Innovator',
      role: 'learner',
      purpose: 'Older learner using advanced assistive AI with a full audit trail.',
      tenantId,
      organizationId,
      cohortIds: ['cohort-innovators-10-12'],
      grade: 11,
      stage: 'Innovators',
      aiPolicy: 'advanced-assistive-use-full-audit',
    },
    family: {
      id: 'user-family-builder',
      email: 'family@scholesa.test',
      password,
      displayName: 'Bailey Family',
      role: 'family',
      purpose:
        'Views selected learner progress, home connections, milestones, and portfolio highlights.',
      tenantId,
      organizationId,
      cohortIds: [],
      linkedLearnerEmail: 'builder@scholesa.test',
      restriction: 'Cannot edit official learning evidence or capability reviews.',
    },
    mentor: {
      id: 'user-mentor-showcase',
      email: 'mentor@scholesa.test',
      password,
      displayName: 'Scholesa Showcase Mentor',
      role: 'mentor',
      purpose: 'Approved external expert, advisor, community partner, or showcase reviewer.',
      tenantId,
      organizationId,
      cohortIds: [],
      access: 'Assigned showcase or portfolio items only.',
    },
  } satisfies Record<UatLoginRole, UatUser>,
  capabilities: [
    {
      id: 'capability-prototype-iteration',
      tenantId,
      title: 'Prototype Iteration',
      pillar: 'Future Skills',
      observableBehavior:
        'Learner tests an artifact, explains what changed, and improves the design from evidence.',
    },
    {
      id: 'capability-reflective-explanation',
      tenantId,
      title: 'Reflective Explanation',
      pillar: 'Leadership',
      observableBehavior:
        'Learner explains decisions, tradeoffs, and next steps in age-appropriate language.',
    },
  ] satisfies UatCapability[],
  checkpoints: [
    {
      id: 'checkpoint-prototype-photo',
      missionId: 'mission-community-invention',
      title: 'Prototype evidence upload',
      evidencePrompt: 'Upload a prototype artifact and describe what it proves.',
      reflectionPrompt: 'What changed after feedback, and what will you try next?',
    },
  ] satisfies UatCheckpoint[],
  missions: [
    {
      id: 'mission-community-invention',
      tenantId,
      organizationId,
      title: 'Community Invention Studio',
      capabilityIds: ['capability-prototype-iteration', 'capability-reflective-explanation'],
      checkpointIds: ['checkpoint-prototype-photo'],
    },
  ] satisfies UatMission[],
  rubrics: [
    {
      id: 'rubric-prototype-evidence-review',
      title: 'Prototype Evidence Review',
      capabilityId: 'capability-prototype-iteration',
      levels: [
        { score: 1, label: 'Not yet visible', descriptor: 'Evidence is missing or unrelated.' },
        { score: 2, label: 'Emerging', descriptor: 'Evidence shows an attempt with limited explanation.' },
        { score: 3, label: 'Capable', descriptor: 'Evidence shows a tested improvement and clear explanation.' },
        { score: 4, label: 'Transferable', descriptor: 'Evidence shows iteration, reasoning, and transfer to a new context.' },
      ],
    },
  ] satisfies UatRubric[],
} as const;

export function getUatUser(role: UatLoginRole): UatUser {
  return uatSeedData.usersByLoginRole[role];
}

export function getLearnerRoles(): UatLoginRole[] {
  return ['discoverer', 'builder', 'explorer', 'innovator'];
}
