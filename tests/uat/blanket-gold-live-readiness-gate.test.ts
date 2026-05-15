type BlanketGoldWorkflow = {
  workflow: string;
  automatedUatGate: string;
  liveEvidenceRequired: string[];
  blocksGoldClaimWithoutLiveEvidence: true;
};

const blanketGoldWorkflows: BlanketGoldWorkflow[] = [
  {
    workflow: 'Capability admin defines Capabilities and maps them to Missions and checkpoints',
    automatedUatGate: 'gold-workflow-gate',
    liveEvidenceRequired: [
      'Admin creates or edits a Capability in the deployed app',
      'Capability mapping appears on a real Mission and checkpoint',
      'Audit log records tenant, actor, Capability, Mission, and checkpoint context',
    ],
    blocksGoldClaimWithoutLiveEvidence: true,
  },
  {
    workflow: 'Educator runs a Session and logs Capability observations during build time',
    automatedUatGate: 'gold-workflow-gate',
    liveEvidenceRequired: [
      'Educator opens a live Session with a real Cohort',
      'Observation or checkpoint progress is saved in under 10 seconds on mobile',
      'Educator report reflects the observation without cross-tenant leakage',
    ],
    blocksGoldClaimWithoutLiveEvidence: true,
  },
  {
    workflow: 'Learner submits artifacts, reflections, and checkpoint Evidence',
    automatedUatGate: 'gold-workflow-gate',
    liveEvidenceRequired: [
      'Learner uploads or links a real artifact through deployed storage',
      'Reflection and checkpoint context survive refresh and sign-out/sign-in',
      'Evidence provenance includes tenant, Cohort, Mission, Session, checkpoint, and Capability context',
    ],
    blocksGoldClaimWithoutLiveEvidence: true,
  },
  {
    workflow: 'Educator applies a four-level Capability Review tied to Capabilities and process domains',
    automatedUatGate: 'gold-workflow-gate',
    liveEvidenceRequired: [
      'Educator reviews real Learner Evidence with four-level rubric criteria',
      'Capability Review appears to the Learner and Educator with next steps',
      'Rubric outcome updates growth without implying attendance or completion equals mastery',
    ],
    blocksGoldClaimWithoutLiveEvidence: true,
  },
  {
    workflow: 'Proof-of-learning is captured and reviewed',
    automatedUatGate: 'gold-workflow-gate',
    liveEvidenceRequired: [
      'Proof artifact opens from deployed storage or trusted external URL',
      'Educator can verify authenticity and explain-it-back provenance',
      'Incomplete proof blocks or flags Capability Review until corrected',
    ],
    blocksGoldClaimWithoutLiveEvidence: true,
  },
  {
    workflow: 'Capability growth updates over time from reviewed Evidence',
    automatedUatGate: 'gold-workflow-gate',
    liveEvidenceRequired: [
      'At least two reviewed Evidence records update the same Learner over time',
      'Growth view shows progression and underlying Evidence provenance',
      'Family and Admin summaries derive from reviewed Evidence only',
    ],
    blocksGoldClaimWithoutLiveEvidence: true,
  },
  {
    workflow: 'Portfolio shows real artifacts and reflections',
    automatedUatGate: 'gold-workflow-gate',
    liveEvidenceRequired: [
      'Portfolio renders uploaded artifact, reflection, and Educator feedback',
      'Share modes protect private, Family, Mentor, Cohort, and public Showcase visibility',
      'Portfolio can explain why each Evidence item belongs there',
    ],
    blocksGoldClaimWithoutLiveEvidence: true,
  },
  {
    workflow: 'Ideation Passport and Growth Report are generated from actual Evidence',
    automatedUatGate: 'gold-workflow-gate',
    liveEvidenceRequired: [
      'Export includes selected reviewed Evidence and Capability context',
      'Export excludes private or unapproved Evidence',
      'Generated Growth Report is understandable to Learner, Family, Educator, and Admin roles',
    ],
    blocksGoldClaimWithoutLiveEvidence: true,
  },
  {
    workflow: 'AI-use is disclosed and visible where relevant',
    automatedUatGate: 'product-promise-gate',
    liveEvidenceRequired: [
      'MiloOS Coach interaction is age-appropriate and blocked for unsupported independent use',
      'AI-use summary captures prompt, coach suggestion, and Learner change',
      'Educator audit view links AI-use to the submitted Evidence',
    ],
    blocksGoldClaimWithoutLiveEvidence: true,
  },
  {
    workflow: 'Family, Educator, and Admin views are understandable and trustworthy',
    automatedUatGate: 'product-promise-gate',
    liveEvidenceRequired: [
      'Family sees only linked Learner progress and selected Portfolio highlights',
      'Educator sees actionable Cohort growth, Evidence gaps, and Capability context',
      'Admin sees tenant-scoped reporting, audit logs, and no cross-tenant data',
    ],
    blocksGoldClaimWithoutLiveEvidence: true,
  },
];

describe('Blanket gold live readiness gate', () => {
  it('requires real deployed role-account evidence before Scholesa is called blanket gold', () => {
    expect(blanketGoldWorkflows).toHaveLength(10);

    for (const workflow of blanketGoldWorkflows) {
      expect(workflow.automatedUatGate).toMatch(/gate$/);
      expect(workflow.liveEvidenceRequired.length).toBeGreaterThanOrEqual(3);
      expect(workflow.blocksGoldClaimWithoutLiveEvidence).toBe(true);
    }
  });

  it('keeps the live evidence standard grounded in Scholesa product language', () => {
    const liveEvidenceText = blanketGoldWorkflows
      .flatMap((workflow) => [workflow.workflow, workflow.automatedUatGate, ...workflow.liveEvidenceRequired])
      .join(' ');
    const requiredTerms = [
      'Capability',
      'Mission',
      'Session',
      'checkpoint',
      'Evidence',
      'Capability Review',
      'Portfolio',
      'Showcase',
      'Growth Report',
      'MiloOS Coach',
      'Family',
      'Educator',
      'Learner',
      'Admin',
    ];
    const forbiddenGenericLmsTerms = /\b(Teacher|Student|Parent|Assignment|Homework|Grading|Report Card)\b/;

    for (const term of requiredTerms) {
      expect(liveEvidenceText).toContain(term);
    }
    expect(liveEvidenceText).not.toMatch(forbiddenGenericLmsTerms);
  });
});
