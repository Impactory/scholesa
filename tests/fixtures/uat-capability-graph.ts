import { getUatMissionByStage, uatMissionDefinitions } from './uat-missions';
import type { LearnerStage } from './uat-seed-data';

export type UatCapabilityDomain =
  | 'Technical fluency'
  | 'Research and analysis'
  | 'Creation and communication'
  | 'Leadership and venture';

export type UatProgressionLevel = 1 | 2 | 3 | 4;

export type UatCapabilityNode = {
  capabilityId: string;
  name: string;
  domain: UatCapabilityDomain;
  description: string;
  stageBand: LearnerStage;
  prerequisites: string[];
  progressionLevel: UatProgressionLevel;
  observableLearnerBehaviors: string[];
  educatorLookFors: string[];
  acceptedEvidenceTypes: string[];
  proofOfWorkRules: string[];
  rubricCriteria: string[];
  badgeMapping: string;
  exampleMissions: string[];
  learnerFacingICanStatement: string;
  learnerAutonomyScore: UatProgressionLevel;
  evidenceMaturityScore: UatProgressionLevel;
};

const stageProgression: Array<{
  stage: LearnerStage;
  level: UatProgressionLevel;
  autonomy: UatProgressionLevel;
  evidenceMaturity: UatProgressionLevel;
}> = [
  { stage: 'Discoverers', level: 1, autonomy: 1, evidenceMaturity: 1 },
  { stage: 'Builders', level: 2, autonomy: 2, evidenceMaturity: 2 },
  { stage: 'Explorers', level: 3, autonomy: 3, evidenceMaturity: 3 },
  { stage: 'Innovators', level: 4, autonomy: 4, evidenceMaturity: 4 },
];

const domainDescriptions: Record<UatCapabilityDomain, string> = {
  'Technical fluency': 'Uses tools, systems, and prototypes to make ideas testable.',
  'Research and analysis': 'Finds, evaluates, compares, and explains information with evidence.',
  'Creation and communication': 'Creates artifacts and communicates what they show.',
  'Leadership and venture': 'Leads ideas from problem insight toward ethical venture action.',
};

const ageAppropriateICan: Record<LearnerStage, string> = {
  Discoverers: 'I can show my idea, tell what it does, and explain one way it helps.',
  Builders: 'I can build a prototype, explain my choices, and improve it with feedback.',
  Explorers: 'I can analyze evidence, compare sources, and explain how my thinking changed.',
  Innovators: 'I can define a real problem, test a solution, evaluate risk, and defend my decisions with evidence.',
};

function evidenceTypesForStage(stage: LearnerStage): string[] {
  return getUatMissionByStage(stage).expectedEvidence;
}

function missionTitlesForDomain(domain: UatCapabilityDomain): string[] {
  return uatMissionDefinitions
    .filter((mission) => mission.capabilityDomains.includes(domain))
    .map((mission) => mission.title);
}

function createCapabilityNode(
  domain: UatCapabilityDomain,
  stage: LearnerStage,
  prerequisites: string[]
): UatCapabilityNode {
  const progression = stageProgression.find((item) => item.stage === stage);

  if (!progression) {
    throw new Error(`Missing progression fixture for ${stage}`);
  }

  const slug = `${domain}-${stage}`.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');

  return {
    capabilityId: `cap-${slug}`,
    name: `${domain} ${stage}`,
    domain,
    description: `${domainDescriptions[domain]} Stage band: ${stage}.`,
    stageBand: stage,
    prerequisites,
    progressionLevel: progression.level,
    observableLearnerBehaviors: [
      `Learner produces stage-${progression.level} evidence for ${domain}.`,
      `Learner explains what the evidence proves using ${stage} language.`,
    ],
    educatorLookFors: [
      `Educator can see whether the Learner connects Evidence to ${domain}.`,
      'Educator can identify the next support move during the Session.',
    ],
    acceptedEvidenceTypes: evidenceTypesForStage(stage),
    proofOfWorkRules: [
      'Evidence must include learner-created artifact, observation, reflection, or explain-it-back provenance.',
      'Evidence must remain linked to tenant, Cohort, Mission, Session, checkpoint, and Capability Review context.',
    ],
    rubricCriteria: [
      'Evidence relevance',
      'Explanation quality',
      'Iteration or reasoning from feedback',
      'Capability transfer appropriate to stage',
    ],
    badgeMapping: `${stage} ${domain} Badge`,
    exampleMissions: missionTitlesForDomain(domain),
    learnerFacingICanStatement: ageAppropriateICan[stage],
    learnerAutonomyScore: progression.autonomy,
    evidenceMaturityScore: progression.evidenceMaturity,
  };
}

export const uatCapabilityDomains: UatCapabilityDomain[] = [
  'Technical fluency',
  'Research and analysis',
  'Creation and communication',
  'Leadership and venture',
];

export const uatCapabilityGraph: UatCapabilityNode[] = uatCapabilityDomains.flatMap((domain) => {
  let previousCapabilityId: string | null = null;

  return stageProgression.map(({ stage }) => {
    const node = createCapabilityNode(domain, stage, previousCapabilityId ? [previousCapabilityId] : []);
    previousCapabilityId = node.capabilityId;

    return node;
  });
});

export function getCapabilitiesByDomain(domain: UatCapabilityDomain): UatCapabilityNode[] {
  return uatCapabilityGraph.filter((capability) => capability.domain === domain);
}

export function getCapabilitiesByStage(stage: LearnerStage): UatCapabilityNode[] {
  return uatCapabilityGraph.filter((capability) => capability.stageBand === stage);
}

export function getCapabilityForMissionDomain(
  domain: UatCapabilityDomain,
  stage: LearnerStage
): UatCapabilityNode {
  const capability = uatCapabilityGraph.find(
    (node) => node.domain === domain && node.stageBand === stage
  );

  if (!capability) {
    throw new Error(`No capability fixture for ${domain} at ${stage}`);
  }

  return capability;
}
