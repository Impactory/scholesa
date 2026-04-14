import type { TaskType } from '@/src/lib/ai/modelAdapter';
import type { AgeBand, AiPolicyTier, PillarCode, StageId } from '@/src/types/schema';
import {
  getLegacyFamilyDisplayLabel,
  getLegacyFamilyDisplayLabelFromAny,
  getLegacyFamilyStorageLabel,
  normalizeLegacyFamilyCode,
  type CurriculumLegacyFamilyCode,
} from '@/src/lib/curriculum/curriculumDisplay.generated';

export type CurriculumStrandId =
  | 'think'
  | 'make'
  | 'communicate'
  | 'lead'
  | 'navigate_ai'
  | 'build_for_the_world';

export type AnnualCycleId = 'understand' | 'design' | 'test' | 'showcase';
export type LessonMoveId =
  | 'hook'
  | 'micro_skill'
  | 'build_sprint'
  | 'checkpoint'
  | 'share_out'
  | 'reflection';
export type ProofLayerId = 'process' | 'product' | 'thinking' | 'improvement' | 'integrity';
export type PortfolioViewId = 'timeline' | 'capability' | 'best_work_showcase';

export interface CurriculumStrand {
  id: CurriculumStrandId;
  name: string;
  coreQuestion: string;
  graduateOutcome: string;
  typicalEvidence: string[];
}

export interface CurriculumMission {
  title: string;
  essentialQuestion: string;
  strandIds: CurriculumStrandId[];
  signatureOutputs: string[];
}

export interface CurriculumPathway {
  title: string;
  whatStudentsDo: string;
  typicalOutputs: string[];
}

export interface CurriculumStage {
  id: StageId;
  name: string;
  gradeRange: [number, number];
  ageBand: AgeBand;
  learningMode: string;
  priorityCapabilities: string[];
  signatureExperience: string;
  aiPosture: string;
  aiPolicyTier: AiPolicyTier;
  teacherResponsibility: string;
  learnerEvidence: string[];
  signatureThemes?: string[];
  evidenceModes?: string[];
  missions?: CurriculumMission[];
  pathways?: CurriculumPathway[];
}

export interface AnnualCycle {
  id: AnnualCycleId;
  label: string;
  purpose: string;
  learnerMoves: string[];
  portfolioOutputs: string[];
}

export interface LessonMove {
  id: LessonMoveId;
  label: string;
  purpose: string;
  teacherAction: string;
  learnerEvidence: string[];
}

export interface ProofLayer {
  id: ProofLayerId;
  label: string;
  question: string;
  examples: string[];
}

export interface PortfolioView {
  id: PortfolioViewId;
  label: string;
  description: string;
}

export interface ImplementationPhase {
  id: 'pilot_year' | 'core_platform_year' | 'network_scale';
  label: string;
  launches: string[];
  successSignal: string;
}

export interface HumanSupportRole {
  role: 'teacher' | 'family' | 'mentor' | 'administrator';
  primaryContribution: string;
}

export const CURRICULUM_NORTH_STAR =
  'Scholesa is a K-12 future-readiness operating system where learners prove growth in thinking, making, communicating, leading, navigating AI, and building value for the world.';

export const CURRICULUM_STRANDS: readonly CurriculumStrand[] = [
  {
    id: 'think',
    name: 'Think',
    coreQuestion: 'How do I make sense of the world?',
    graduateOutcome: 'Frame questions, reason with evidence, analyze patterns, and make thoughtful decisions under uncertainty.',
    typicalEvidence: ['Research notes', 'Claim-evidence maps', 'Data logs', 'Model critiques'],
  },
  {
    id: 'make',
    name: 'Make',
    coreQuestion: 'How do I build and improve?',
    graduateOutcome: 'Design prototypes, code tools, create media, test ideas, and iterate toward better solutions.',
    typicalEvidence: ['Builds', 'Prototypes', 'Code', 'Demos', 'Design files'],
  },
  {
    id: 'communicate',
    name: 'Communicate',
    coreQuestion: 'How do I help others understand?',
    graduateOutcome: 'Explain complex ideas clearly in speaking, writing, visuals, and presentations.',
    typicalEvidence: ['Decks', 'Pitches', 'Essays', 'Videos', 'Explain-it-back recordings'],
  },
  {
    id: 'lead',
    name: 'Lead',
    coreQuestion: 'How do I work with others and move ideas forward?',
    graduateOutcome: 'Take initiative, collaborate in roles, reflect, manage self, and contribute to teams with integrity.',
    typicalEvidence: ['Team logs', 'Peer feedback', 'Planning documents', 'Reflections'],
  },
  {
    id: 'navigate_ai',
    name: 'Navigate AI',
    coreQuestion: 'How do I use AI wisely?',
    graduateOutcome: 'Recognize AI in context, evaluate outputs, create with AI responsibly, and understand ethical implications.',
    typicalEvidence: ['Prompt logs', 'AI critiques', 'Process notes', 'Revision records'],
  },
  {
    id: 'build_for_the_world',
    name: 'Build for the World',
    coreQuestion: 'How do I create real value?',
    graduateOutcome: 'Apply entrepreneurship, civic thinking, sustainability, and ethics to meaningful community and market problems.',
    typicalEvidence: ['User interviews', 'Venture plans', 'Ethics statements', 'Showcases'],
  },
] as const;

export const CURRICULUM_STAGES: Readonly<Record<StageId, CurriculumStage>> = {
  discoverers: {
    id: 'discoverers',
    name: 'Discoverers',
    gradeRange: [1, 3],
    ageBand: 'grades_1_3',
    learningMode: 'Playful, structured, teacher-led',
    priorityCapabilities: ['Curiosity', 'Invention', 'Language', 'Confidence', 'Observation'],
    signatureExperience: 'Story-rich invention studio',
    aiPosture: 'Whole-class demonstration only',
    aiPolicyTier: 'A',
    teacherResponsibility: 'Model safe AI use and compare tool outputs to human ideas.',
    learnerEvidence: ['Teacher notes', 'Oral discussion'],
    signatureThemes: ['Helpful inventions', 'Story worlds', 'Nature and observation', 'Community helpers', 'Simple coding and sequencing', 'Empathy and communication'],
    evidenceModes: ['Drawings', 'Photos', 'Oral recordings', 'Teacher observations', 'Labeled models', 'Simple reflection stems'],
    missions: [
      {
        title: 'My Helpful Invention',
        essentialQuestion: 'What problem can I notice and solve?',
        strandIds: ['think', 'make', 'communicate'],
        signatureOutputs: ['Invention board', 'Model', 'Oral demo'],
      },
      {
        title: 'Story Worlds and Smart Helpers',
        essentialQuestion: 'How can tools help people tell stories or do good work?',
        strandIds: ['make', 'communicate', 'navigate_ai'],
        signatureOutputs: ['Interactive story', 'Storyboard', 'Voice reflection'],
      },
      {
        title: 'Tiny Nature Lab',
        essentialQuestion: 'What patterns can I notice in the living world?',
        strandIds: ['think', 'communicate', 'build_for_the_world'],
        signatureOutputs: ['Observation journal', 'Class graph', 'Photo evidence'],
      },
      {
        title: 'Kind Community Builders',
        essentialQuestion: 'How can we make our classroom or neighborhood better?',
        strandIds: ['lead', 'build_for_the_world', 'communicate'],
        signatureOutputs: ['Class solution', 'Team poster', 'Share-out'],
      },
    ],
  },
  builders: {
    id: 'builders',
    name: 'Builders',
    gradeRange: [4, 6],
    ageBand: 'grades_4_6',
    learningMode: 'Guided projects and team roles',
    priorityCapabilities: ['Foundations', 'Data sense', 'Documentation', 'Teamwork'],
    signatureExperience: 'Design-and-build lab',
    aiPosture: 'Guided assistive use',
    aiPolicyTier: 'B',
    teacherResponsibility: 'Set clear prompts, narrow tasks, and enforce no-copy guardrails.',
    learnerEvidence: ['Prompt capture', 'What the learner kept or changed'],
    signatureThemes: ['Eco-smart systems', 'Community challenges', 'Coding foundations', 'Data storytelling', 'Early product thinking', 'Short-form pitching'],
    evidenceModes: ['Notebooks', 'Screenshots', 'Mini decks', 'Prototype photos', 'Feedback forms', 'Short explain-it-back clips'],
    missions: [
      {
        title: 'Eco-Smart School',
        essentialQuestion: 'How might we improve how our community uses resources?',
        strandIds: ['think', 'make', 'build_for_the_world'],
        signatureOutputs: ['Design workbook', 'System sketch', 'Mini pitch'],
      },
      {
        title: 'Data Detectives',
        essentialQuestion: 'What story does our evidence tell?',
        strandIds: ['think', 'communicate', 'navigate_ai'],
        signatureOutputs: ['Data poster', 'Chart set', 'Reasoning notes'],
      },
      {
        title: 'Code to Help',
        essentialQuestion: 'What tool can we build to make a task easier or clearer?',
        strandIds: ['make', 'think', 'lead'],
        signatureOutputs: ['Simple program', 'Test notes', 'Demo video'],
      },
      {
        title: 'Community Pitch Day',
        essentialQuestion: 'How do we persuade others using evidence and clarity?',
        strandIds: ['communicate', 'lead', 'build_for_the_world'],
        signatureOutputs: ['Pitch deck', 'Audience feedback', 'Reflection'],
      },
    ],
  },
  explorers: {
    id: 'explorers',
    name: 'Explorers',
    gradeRange: [7, 9],
    ageBand: 'grades_7_9',
    learningMode: 'Applied labs and growing autonomy',
    priorityCapabilities: ['Research', 'Critique', 'Bias detection', 'Product thinking'],
    signatureExperience: 'Investigation and media / AI lab',
    aiPosture: 'Logged analytical use',
    aiPolicyTier: 'C',
    teacherResponsibility: 'Teach evaluation, debugging, bias checks, and verification routines.',
    learnerEvidence: ['AI log', 'Critique', 'Evidence cross-check'],
    signatureThemes: ['AI and media literacy', 'Claims versus evidence', 'Model limitations', 'Bias and fairness', 'Debugging', 'Early product strategy', 'Ethical decision-making'],
    evidenceModes: ['Lab books', 'Research notes', 'Evaluation rubrics', 'Code links', 'Checklists', 'Recorded presentations', 'Peer critique'],
    missions: [
      {
        title: 'AI Media Detective Lab',
        essentialQuestion: 'How do we know what to trust?',
        strandIds: ['think', 'navigate_ai', 'communicate'],
        signatureOutputs: ['Evidence dossier', 'Verification checklist', 'Presentation'],
      },
      {
        title: 'Bias and Fairness Challenge',
        essentialQuestion: 'How do systems become unfair, and what can we redesign?',
        strandIds: ['think', 'navigate_ai', 'build_for_the_world'],
        signatureOutputs: ['Bias audit', 'Redesign brief', 'Ethics note'],
      },
      {
        title: 'Build a Useful Tool',
        essentialQuestion: 'What small product could make a real task easier?',
        strandIds: ['make', 'lead', 'communicate'],
        signatureOutputs: ['Prototype', 'User feedback', 'Demo'],
      },
      {
        title: 'Youth Impact Lab',
        essentialQuestion: 'How might we improve something in school or society?',
        strandIds: ['lead', 'build_for_the_world', 'think'],
        signatureOutputs: ['Impact proposal', 'Team artifact', 'Reflection'],
      },
    ],
  },
  innovators: {
    id: 'innovators',
    name: 'Innovators',
    gradeRange: [10, 12],
    ageBand: 'grades_10_12',
    learningMode: 'Mentored, real-world, portfolio-driven',
    priorityCapabilities: ['Leadership', 'Venture design', 'AI/data', 'Ethics', 'Execution'],
    signatureExperience: 'Pathway-based capstone studio',
    aiPosture: 'Advanced assistive use with full audit trail',
    aiPolicyTier: 'D',
    teacherResponsibility: 'Enforce full audit trail, trust controls, and academic integrity.',
    learnerEvidence: ['Audit log', 'Source note', 'Defense of choices'],
    evidenceModes: ['Research memos', 'Decks', 'Prototypes', 'User interviews', 'Code repositories', 'Ethics statements', 'Mentor feedback', 'Final capstone defense'],
    pathways: [
      {
        title: 'Venture and Startup Lab',
        whatStudentsDo: 'Identify needs, test value propositions, build MVPs, and present unit economics and impact cases.',
        typicalOutputs: ['Pitch deck', 'User research', 'MVP demo', 'Venture memo'],
      },
      {
        title: 'AI and Data Lab',
        whatStudentsDo: 'Use automation, analytics, and model reasoning to answer real problems or improve workflows.',
        typicalOutputs: ['Notebook', 'Code or workflow', 'Dashboard', 'Technical brief'],
      },
      {
        title: 'Creative Media and Story Lab',
        whatStudentsDo: 'Use narrative, design, and media systems to influence, educate, and communicate.',
        typicalOutputs: ['Campaign', 'Media package', 'Story prototype', 'Showcase reel'],
      },
      {
        title: 'Robotics and Systems Lab',
        whatStudentsDo: 'Work with sensing, physical computing, systems integration, and engineering iteration.',
        typicalOutputs: ['Build log', 'Prototype', 'Test report', 'Demo'],
      },
      {
        title: 'Trust, Policy, and Ethics Lab',
        whatStudentsDo: 'Analyze governance, safety, privacy, fairness, and public-interest implications of technology.',
        typicalOutputs: ['Policy brief', 'Debate', 'Ethics audit', 'Redesign proposal'],
      },
    ],
  },
} as const;

export const CURRICULUM_STAGE_ORDER: readonly StageId[] = [
  'discoverers',
  'builders',
  'explorers',
  'innovators',
] as const;

export const CURRICULUM_ANNUAL_RHYTHM: readonly AnnualCycle[] = [
  {
    id: 'understand',
    label: 'Term 1: Understand',
    purpose: 'Build context and curiosity',
    learnerMoves: ['Observe', 'Ask', 'Investigate', 'Notice patterns', 'Gather evidence'],
    portfolioOutputs: ['Research notes', 'Observations', 'Concept maps'],
  },
  {
    id: 'design',
    label: 'Term 2: Design',
    purpose: 'Generate and shape ideas',
    learnerMoves: ['Sketch', 'Plan', 'Prototype', 'Learn tools', 'Try alternatives'],
    portfolioOutputs: ['Design notebooks', 'Early prototypes', 'Process checks'],
  },
  {
    id: 'test',
    label: 'Term 3: Test',
    purpose: 'Use data and feedback to improve',
    learnerMoves: ['Trial', 'Debug', 'Compare', 'Collect responses', 'Revise'],
    portfolioOutputs: ['Change logs', 'User feedback', 'Revised artifacts'],
  },
  {
    id: 'showcase',
    label: 'Term 4: Showcase',
    purpose: 'Defend and communicate learning',
    learnerMoves: ['Present', 'Explain choices', 'Reflect', 'Publish best evidence'],
    portfolioOutputs: ['Showcase piece', 'Reflection', 'Badge evidence'],
  },
] as const;

export const CURRICULUM_LESSON_MOVES: readonly LessonMove[] = [
  {
    id: 'hook',
    label: 'Hook',
    purpose: 'Activate curiosity and relevance',
    teacherAction: 'Connect to a real problem, image, story, claim, or challenge.',
    learnerEvidence: ['Prediction', 'Observation', 'Quick talk'],
  },
  {
    id: 'micro_skill',
    label: 'Micro-skill',
    purpose: 'Teach one small move clearly',
    teacherAction: 'Model a tool, concept, or strategy with visible steps.',
    learnerEvidence: ['Guided note', 'Worked example', 'Mini response'],
  },
  {
    id: 'build_sprint',
    label: 'Build sprint',
    purpose: 'Create, test, or investigate',
    teacherAction: 'Coach individuals and teams during active work.',
    learnerEvidence: ['Drafts', 'Logs', 'Screenshots', 'Prototypes'],
  },
  {
    id: 'checkpoint',
    label: 'Checkpoint',
    purpose: 'Capture proof during the process',
    teacherAction: 'Pause for evidence and decision-making.',
    learnerEvidence: ['Exit check', 'Rubric note', 'Photo', 'Voice note'],
  },
  {
    id: 'share_out',
    label: 'Share-out',
    purpose: 'Make thinking public',
    teacherAction: 'Facilitate critique and peer explanation.',
    learnerEvidence: ['Presentation', 'Peer feedback', 'Revised idea'],
  },
  {
    id: 'reflection',
    label: 'Reflection',
    purpose: 'Consolidate learning and set next steps',
    teacherAction: 'Prompt metacognition and transfer.',
    learnerEvidence: ['Explain-it-back', 'Reflection note', 'Action plan'],
  },
] as const;

export const CURRICULUM_PROOF_LAYERS: readonly ProofLayer[] = [
  {
    id: 'process',
    label: 'Process proof',
    question: 'Did the learner actually work through the task?',
    examples: ['Sketches', 'Drafts', 'Checkpoints', 'Notes', 'Screenshots'],
  },
  {
    id: 'product',
    label: 'Product proof',
    question: 'What did the learner create or demonstrate?',
    examples: ['Deck', 'Prototype', 'Code', 'Video', 'Report'],
  },
  {
    id: 'thinking',
    label: 'Thinking proof',
    question: 'Can the learner explain decisions in their own words?',
    examples: ['Oral explanation', 'Written reflection', 'Defense questions'],
  },
  {
    id: 'improvement',
    label: 'Improvement proof',
    question: 'Did the learner revise intelligently?',
    examples: ['Change log', 'Before/after comparison', 'Feedback response'],
  },
  {
    id: 'integrity',
    label: 'Integrity proof',
    question: 'How was AI or outside help used?',
    examples: ['Prompt record', 'Source note', 'What changed because of assistance'],
  },
] as const;

export const CURRICULUM_PORTFOLIO_VIEWS: readonly PortfolioView[] = [
  {
    id: 'timeline',
    label: 'Timeline view',
    description: 'Shows growth over time across the full learner journey.',
  },
  {
    id: 'capability',
    label: 'Capability view',
    description: 'Groups evidence by capability strand so growth is visible by area.',
  },
  {
    id: 'best_work_showcase',
    label: 'Best-work showcase view',
    description: 'Curates the strongest artifacts for mentors, opportunities, and public showcase.',
  },
] as const;

export const CURRICULUM_HUMAN_SUPPORT_ROLES: readonly HumanSupportRole[] = [
  {
    role: 'teacher',
    primaryContribution: 'Facilitates missions, coaches thinking, monitors checkpoints, scores growth, and manages safe AI use.',
  },
  {
    role: 'family',
    primaryContribution: 'Reinforces home connection prompts, celebrates portfolio growth, and understands the learner story.',
  },
  {
    role: 'mentor',
    primaryContribution: 'Provides structured outside feedback on selected portfolio pieces, showcases, and capstones.',
  },
  {
    role: 'administrator',
    primaryContribution: 'Ensures quality, coherence, staffing, scheduling, reporting, and policy fidelity across cohorts.',
  },
] as const;

export const CURRICULUM_IMPLEMENTATION_PHASES: readonly ImplementationPhase[] = [
  {
    id: 'pilot_year',
    label: 'Pilot year',
    launches: [
      'Capability graph v1',
      'Flagship missions',
      'Basic evidence capture',
      'Simple portfolio',
      'Teacher scripts and rubrics',
    ],
    successSignal: 'Learners complete missions with visible artifacts and teachers can assess confidently.',
  },
  {
    id: 'core_platform_year',
    label: 'Core platform year',
    launches: [
      'Recommendation engine',
      'AI logs',
      'Voice evidence',
      'Analytics',
      'Differentiated tasking',
      'Stronger reporting',
    ],
    successSignal: 'Teachers save time and schools can monitor growth by cohort and capability.',
  },
  {
    id: 'network_scale',
    label: 'Network scale',
    launches: [
      'Mentor portal',
      'Family portal',
      'Public showcases',
      'Badge automation',
      'Multi-campus reporting',
      'Advanced integrations',
    ],
    successSignal: 'Scholesa expands from pilots to repeatable multi-school adoption.',
  },
] as const;

export const CURRICULUM_AI_ALLOWED_TASKS: Readonly<Record<StageId, readonly TaskType[]>> = {
  discoverers: [],
  builders: ['hint_generation'],
  explorers: ['hint_generation', 'rubric_check', 'debug_assistance', 'critique_feedback'],
  innovators: ['hint_generation', 'rubric_check', 'debug_assistance', 'critique_feedback', 'explain_concept', 'reflection_prompt'],
} as const;

export const LEGACY_PILLAR_ALIGNMENT: Readonly<Record<PillarCode, {
  familyLabel: string;
  strandIds: readonly CurriculumStrandId[];
  note: string;
}>> = {
  FUTURE_SKILLS: {
    familyLabel: getLegacyFamilyDisplayLabel('FUTURE_SKILLS'),
    strandIds: ['think', 'make', 'navigate_ai'],
    note: 'Legacy Future Skills analytics should be interpreted as a rolled-up view across thinking, making, and AI judgment.',
  },
  LEADERSHIP_AGENCY: {
    familyLabel: getLegacyFamilyDisplayLabel('LEADERSHIP_AGENCY'),
    strandIds: ['communicate', 'lead'],
    note: 'Legacy Leadership & Agency analytics should be interpreted as communication and leadership growth together.',
  },
  IMPACT_INNOVATION: {
    familyLabel: getLegacyFamilyDisplayLabel('IMPACT_INNOVATION'),
    strandIds: ['build_for_the_world'],
    note: 'Legacy Impact & Innovation analytics should be interpreted as value creation, ethics, and community impact.',
  },
} as const;

export const LEGACY_PILLAR_ORDER: readonly PillarCode[] = [
  'FUTURE_SKILLS',
  'LEADERSHIP_AGENCY',
  'IMPACT_INNOVATION',
] as const;

export function normalizeLegacyPillarCode(value: unknown): PillarCode | null {
  return normalizeLegacyFamilyCode(value) as PillarCode | null;
}

export function getLegacyPillarFamilyLabel(pillarCode: PillarCode): string {
  return getLegacyFamilyDisplayLabel(pillarCode as CurriculumLegacyFamilyCode);
}

export function getLegacyPillarStorageLabel(pillarCode: PillarCode): string {
  return getLegacyFamilyStorageLabel(pillarCode as CurriculumLegacyFamilyCode);
}

export function getLegacyPillarFamilyDisplayLabel(value: unknown): string {
  return `${getLegacyFamilyDisplayLabelFromAny(value)} family`;
}

export function getLegacyPillarCompatibilityNote(value: unknown): string | null {
  const normalizedCode = normalizeLegacyPillarCode(value);
  return normalizedCode ? LEGACY_PILLAR_ALIGNMENT[normalizedCode].note : null;
}

export function getCurriculumStage(stageId: StageId): CurriculumStage {
  return CURRICULUM_STAGES[stageId];
}

export function getCurriculumStageFromGrade(grade: number): CurriculumStage {
  if (grade >= 1 && grade <= 3) return CURRICULUM_STAGES.discoverers;
  if (grade >= 4 && grade <= 6) return CURRICULUM_STAGES.builders;
  if (grade >= 7 && grade <= 9) return CURRICULUM_STAGES.explorers;
  return CURRICULUM_STAGES.innovators;
}

export function getAgeBandForStage(stageId: StageId): AgeBand {
  return CURRICULUM_STAGES[stageId].ageBand;
}

export function getAiPolicyTierForStage(stageId: StageId): AiPolicyTier {
  return CURRICULUM_STAGES[stageId].aiPolicyTier;
}

export function getAiAllowedTaskTypesForStage(stageId: StageId): readonly TaskType[] {
  return CURRICULUM_AI_ALLOWED_TASKS[stageId];
}
