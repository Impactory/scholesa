/**
 * Seed the 4 learning stages per Capability-First Specification §7.
 *
 * Usage:
 *   npx ts-node --project tsconfig.json scripts/seedStages.ts
 *
 * Or via Firebase Admin (set GOOGLE_APPLICATION_CREDENTIALS).
 */
import * as admin from 'firebase-admin';

if (!admin.apps.length) {
  admin.initializeApp();
}
const db = admin.firestore();

interface StageSeed {
  id: string;
  name: string;
  gradeRange: [number, number];
  description: string;
  focusAreas: string[];
  aiPolicyTier: 'A' | 'B' | 'C' | 'D';
  uxComplexity: 'simple' | 'guided' | 'autonomous' | 'professional';
  defaultSessionDuration: number;
}

const stages: StageSeed[] = [
  {
    id: 'discoverers',
    name: 'Discoverers',
    gradeRange: [1, 3],
    description:
      'Foundation stage for young learners. Emphasis on curiosity, guided exploration, and building core habits through play-based studio projects.',
    focusAreas: [
      'Curiosity & exploration',
      'Core literacy & numeracy',
      'Creative expression',
      'Collaborative play',
      'Habit formation',
    ],
    aiPolicyTier: 'A',
    uxComplexity: 'simple',
    defaultSessionDuration: 45,
  },
  {
    id: 'builders',
    name: 'Builders',
    gradeRange: [4, 6],
    description:
      'Intermediate stage focused on skill-building and scaffolded problem solving. Learners develop structured thinking and begin self-directed projects.',
    focusAreas: [
      'Structured problem solving',
      'Design thinking basics',
      'Self-regulation skills',
      'Team collaboration',
      'Evidence-based reflection',
    ],
    aiPolicyTier: 'B',
    uxComplexity: 'guided',
    defaultSessionDuration: 60,
  },
  {
    id: 'explorers',
    name: 'Explorers',
    gradeRange: [7, 9],
    description:
      'Advanced stage emphasizing analysis, critique, and independent inquiry. Learners choose tools, evaluate approaches, and build increasingly complex projects.',
    focusAreas: [
      'Critical analysis',
      'Independent research',
      'Ethical reasoning',
      'Technical depth',
      'Cross-domain connections',
    ],
    aiPolicyTier: 'C',
    uxComplexity: 'autonomous',
    defaultSessionDuration: 75,
  },
  {
    id: 'innovators',
    name: 'Innovators',
    gradeRange: [10, 12],
    description:
      'Professional stage for venture-readiness. Learners lead research sprints, build real-world projects, mentor younger students, and prepare portfolios for higher education or industry.',
    focusAreas: [
      'Venture & entrepreneurship',
      'Original research',
      'Mentoring & leadership',
      'Portfolio curation',
      'Professional communication',
    ],
    aiPolicyTier: 'D',
    uxComplexity: 'professional',
    defaultSessionDuration: 90,
  },
];

async function seed() {
  const batch = db.batch();

  for (const stage of stages) {
    const ref = db.collection('stages').doc(stage.id);
    batch.set(ref, {
      name: stage.name,
      gradeRange: stage.gradeRange,
      description: stage.description,
      focusAreas: stage.focusAreas,
      aiPolicyTier: stage.aiPolicyTier,
      uxComplexity: stage.uxComplexity,
      defaultSessionDuration: stage.defaultSessionDuration,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  await batch.commit();
  console.log(`Seeded ${stages.length} stages: ${stages.map((s) => s.id).join(', ')}`);
}

seed()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Seed failed:', err);
    process.exit(1);
  });
