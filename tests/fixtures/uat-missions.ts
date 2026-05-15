import type { LearnerAIPolicy, LearnerStage } from './uat-seed-data';

export type UatMissionDefinition = {
  id: string;
  title: string;
  stage: LearnerStage;
  grades: string;
  capabilityDomains: string[];
  aiPolicy: LearnerAIPolicy;
  expectedEvidence: string[];
  checkpointTitles: string[];
};

export const uatMissionDefinitions: UatMissionDefinition[] = [
  {
    id: 'mission-helpful-invention-studio',
    title: 'My Helpful Invention Studio',
    stage: 'Discoverers',
    grades: '1-3',
    capabilityDomains: ['Technical fluency', 'Creation and communication'],
    aiPolicy: 'educator-led-only',
    expectedEvidence: [
      'Drawing or photo of invention idea',
      'Oral explain-it-back',
      'Educator observation',
      'Reflection prompt with age-appropriate support',
    ],
    checkpointTitles: [
      'Name the helpful problem',
      'Share the invention drawing or photo',
      'Explain it back to an Educator',
    ],
  },
  {
    id: 'mission-eco-smart-city-lab',
    title: 'Eco-Smart City Lab',
    stage: 'Builders',
    grades: '4-6',
    capabilityDomains: [
      'Technical fluency',
      'Research and analysis',
      'Creation and communication',
    ],
    aiPolicy: 'guided-assistive-use',
    expectedEvidence: [
      'Design sketch or screenshot',
      'Short written reflection',
      'Build artifact',
      'Explain-it-back response',
      'Optional AI-use summary if MiloOS Coach was used',
    ],
    checkpointTitles: [
      'Research an eco-smart need',
      'Build a city feature prototype',
      'Explain what changed after feedback',
    ],
  },
  {
    id: 'mission-ai-media-detective-lab',
    title: 'AI Media Detective Lab',
    stage: 'Explorers',
    grades: '7-9',
    capabilityDomains: [
      'Research and analysis',
      'Technical fluency',
      'Creation and communication',
    ],
    aiPolicy: 'logged-analytical-use',
    expectedEvidence: [
      'Claim evaluation',
      'Source analysis',
      'Bias detection notes',
      'Reflection',
      'AI prompt log',
      'Summary of what AI suggested and what learner changed',
    ],
    checkpointTitles: [
      'Evaluate the media claim',
      'Compare sources and bias signals',
      'Log AI suggestions and learner decisions',
    ],
  },
  {
    id: 'mission-venture-sprint',
    title: 'Venture Sprint',
    stage: 'Innovators',
    grades: '10-12',
    capabilityDomains: [
      'Leadership and venture',
      'Research and analysis',
      'Creation and communication',
    ],
    aiPolicy: 'advanced-assistive-use-full-audit',
    expectedEvidence: [
      'Venture concept',
      'Problem/customer statement',
      'Prototype or pitch artifact',
      'Risk/ethics statement',
      'Reflection',
      'AI audit trail',
      'Optional showcase submission',
    ],
    checkpointTitles: [
      'Define the venture problem',
      'Create the prototype or pitch artifact',
      'Review risk, ethics, and showcase readiness',
    ],
  },
];

export function getUatMissionByStage(stage: LearnerStage): UatMissionDefinition {
  const mission = uatMissionDefinitions.find((item) => item.stage === stage);

  if (!mission) {
    throw new Error(`No UAT mission configured for stage ${stage}`);
  }

  return mission;
}
