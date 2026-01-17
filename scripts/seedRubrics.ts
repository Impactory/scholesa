/**
 * Seed Default Rubrics
 * 
 * Bootstrap your rubric library with age-appropriate defaults.
 * These are YOUR starting intelligence - iterate on them without retraining.
 */

import { RubricManager, type AssessmentRubric } from '../src/lib/ai/rubricManager';

/**
 * Global rubric for K-3 coding missions
 */
export const k3CodingRubric: Omit<AssessmentRubric, 'id' | 'createdAt' | 'version'> = {
  name: 'K-3 Coding Foundations',
  description: 'Age-appropriate assessment for early coding concepts',
  status: 'active',
  siteId: '*', // Global default
  grade: 2,
  pillarId: 'future_skills',
  
  criteria: [
    {
      name: 'Understanding',
      description: 'Shows they get the main idea',
      weight: 0.4,
      levels: [
        {
          name: 'Emerging',
          description: 'Can follow along with help from teacher or friend',
          score: 1,
          commonMistakes: [
            'Confuses blocks (e.g., "repeat" vs "move")',
            'Needs step-by-step guidance for each action'
          ]
        },
        {
          name: 'Proficient',
          description: 'Can explain what their code does in simple words',
          score: 2,
          commonMistakes: []
        },
        {
          name: 'Advanced',
          description: 'Can teach someone else how it works',
          score: 3,
          commonMistakes: []
        }
      ]
    },
    {
      name: 'Problem-Solving',
      description: 'Tries different things when stuck',
      weight: 0.3,
      levels: [
        {
          name: 'Emerging',
          description: 'Asks for help right away when stuck',
          score: 1,
          commonMistakes: [
            'Gives up quickly',
            'Doesn\'t try changing anything before asking for help'
          ]
        },
        {
          name: 'Proficient',
          description: 'Tests a few ideas before asking for help',
          score: 2
        },
        {
          name: 'Advanced',
          description: 'Finds the problem and fixes it on their own',
          score: 3
        }
      ]
    },
    {
      name: 'Communication',
      description: 'Can tell someone about their work',
      weight: 0.3,
      levels: [
        {
          name: 'Emerging',
          description: 'Points to the screen and says "this works"',
          score: 1
        },
        {
          name: 'Proficient',
          description: 'Explains what each part does',
          score: 2
        },
        {
          name: 'Advanced',
          description: 'Explains the whole idea and why they chose it',
          score: 3
        }
      ]
    }
  ],
  
  createdBy: 'system',
  tags: ['coding', 'k-3', 'foundations', 'global']
};

/**
 * Global rubric for grades 4-6 project work
 */
export const grades46ProjectRubric: Omit<AssessmentRubric, 'id' | 'createdAt' | 'version'> = {
  name: 'Grades 4-6 Project Assessment',
  description: 'Holistic rubric for project-based learning',
  status: 'active',
  siteId: '*',
  grade: 5,
  pillarId: 'future_skills',
  
  criteria: [
    {
      name: 'Research & Understanding',
      description: 'Demonstrates solid grasp of concepts and background research',
      weight: 0.25,
      levels: [
        {
          name: 'Emerging',
          description: 'Surface-level understanding; minimal research evident',
          score: 1,
          commonMistakes: [
            'Cites only one source',
            'Confuses key terms or concepts',
            'Doesn\'t connect research to project goal'
          ]
        },
        {
          name: 'Proficient',
          description: 'Clear understanding; research from 2-3 reliable sources',
          score: 2
        },
        {
          name: 'Advanced',
          description: 'Deep understanding; synthesizes multiple perspectives',
          score: 3
        }
      ]
    },
    {
      name: 'Technical Execution',
      description: 'Quality of the artifact/deliverable',
      weight: 0.3,
      levels: [
        {
          name: 'Emerging',
          description: 'Partially complete; some features don\'t work',
          score: 1,
          commonMistakes: [
            'Didn\'t test before submitting',
            'Missing required components',
            'Errors prevent core functionality'
          ]
        },
        {
          name: 'Proficient',
          description: 'Fully functional with all requirements met',
          score: 2
        },
        {
          name: 'Advanced',
          description: 'Exceeds requirements; adds creative enhancements',
          score: 3
        }
      ]
    },
    {
      name: 'Critical Thinking',
      description: 'Analysis, debugging, iteration',
      weight: 0.25,
      levels: [
        {
          name: 'Emerging',
          description: 'Relies heavily on help; doesn\'t debug independently',
          score: 1,
          commonMistakes: [
            'Doesn\'t explain why they made choices',
            'No evidence of iteration or revision',
            'Can\'t identify what went wrong'
          ]
        },
        {
          name: 'Proficient',
          description: 'Debugs systematically; explains reasoning',
          score: 2
        },
        {
          name: 'Advanced',
          description: 'Anticipates problems; documents decision-making',
          score: 3
        }
      ]
    },
    {
      name: 'Communication',
      description: 'Explanation, reflection, presentation',
      weight: 0.2,
      levels: [
        {
          name: 'Emerging',
          description: 'Brief or unclear explanation; incomplete reflection',
          score: 1
        },
        {
          name: 'Proficient',
          description: 'Clear explanation of process and outcomes',
          score: 2
        },
        {
          name: 'Advanced',
          description: 'Compelling narrative; insightful reflection on learning',
          score: 3
        }
      ]
    }
  ],
  
  createdBy: 'system',
  tags: ['project-based', 'grades-4-6', 'holistic', 'global']
};

/**
 * Global rubric for grades 7-9 (identity & agency focus)
 */
export const grades79AgencyRubric: Omit<AssessmentRubric, 'id' | 'createdAt' | 'version'> = {
  name: 'Grades 7-9 Agency & Impact',
  description: 'Assessment focused on agency, voice, and real-world connection',
  status: 'active',
  siteId: '*',
  grade: 8,
  pillarId: 'leadership_agency',
  
  criteria: [
    {
      name: 'Personal Voice & Identity',
      description: 'Project reflects student authentic interests and perspective',
      weight: 0.25,
      levels: [
        {
          name: 'Emerging',
          description: 'Generic approach; minimal personal connection',
          score: 1,
          commonMistakes: [
            'Copies template without personalizing',
            'No clear connection to own interests',
            'Doesn\'t explain why topic matters to them'
          ]
        },
        {
          name: 'Proficient',
          description: 'Clear personal stake; explains why topic matters',
          score: 2
        },
        {
          name: 'Advanced',
          description: 'Deeply personal; connects to identity and future goals',
          score: 3
        }
      ]
    },
    {
      name: 'Real-World Impact',
      description: 'Addresses authentic problem or audience',
      weight: 0.3,
      levels: [
        {
          name: 'Emerging',
          description: 'Hypothetical scenario; no real audience or stakeholder',
          score: 1,
          commonMistakes: [
            'Doesn\'t identify who would benefit',
            'No evidence of user research or feedback',
            'Solution doesn\'t address root cause'
          ]
        },
        {
          name: 'Proficient',
          description: 'Clear beneficiary; solution is feasible',
          score: 2
        },
        {
          name: 'Advanced',
          description: 'Tested with real users; plans for implementation',
          score: 3
        }
      ]
    },
    {
      name: 'Technical Quality',
      description: 'Competence with tools, methods, and execution',
      weight: 0.25,
      levels: [
        {
          name: 'Emerging',
          description: 'Basic functionality; some technical gaps',
          score: 1
        },
        {
          name: 'Proficient',
          description: 'Solid execution; appropriate use of skills learned',
          score: 2
        },
        {
          name: 'Advanced',
          description: 'Sophisticated technique; pushes beyond taught skills',
          score: 3
        }
      ]
    },
    {
      name: 'Metacognition & Reflection',
      description: 'Awareness of own learning process and growth',
      weight: 0.2,
      levels: [
        {
          name: 'Emerging',
          description: 'Surface reflection ("it was hard")',
          score: 1,
          commonMistakes: [
            'Doesn\'t identify specific challenges or breakthroughs',
            'No plan for next steps or improvement',
            'Can\'t articulate what they learned'
          ]
        },
        {
          name: 'Proficient',
          description: 'Identifies specific learning moments and strategies',
          score: 2
        },
        {
          name: 'Advanced',
          description: 'Analyzes own growth patterns; plans future learning',
          score: 3
        }
      ]
    }
  ],
  
  createdBy: 'system',
  tags: ['agency', 'identity', 'grades-7-9', 'impact', 'global']
};

/**
 * Seed all default rubrics into Firestore
 */
export async function seedDefaultRubrics(createdBy: string = 'system'): Promise<string[]> {
  const rubrics = [
    k3CodingRubric,
    grades46ProjectRubric,
    grades79AgencyRubric
  ];
  
  const ids: string[] = [];
  
  for (const rubric of rubrics) {
    try {
      const id = await RubricManager.createRubric({
        ...rubric,
        createdBy
      });
      ids.push(id);
      console.log(`✅ Created rubric: ${rubric.name} (${id})`);
    } catch (err) {
      console.error(`❌ Failed to create rubric: ${rubric.name}`, err);
    }
  }
  
  return ids;
}
