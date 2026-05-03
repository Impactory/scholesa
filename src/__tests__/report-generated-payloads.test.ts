import {
  buildFamilyShareSummary,
  buildPassportTextLines,
} from '@/src/components/passport/LearnerPassportExport';
import {
  buildGuardianFamilyShareSummary,
  buildGuardianPassportTextLines,
} from '@/src/features/workflows/renderers/GuardianCapabilityViewRenderer';
import {
  assertReportProvenanceContract,
  familySummaryProvenanceSignals,
  passportReportProvenanceSignals,
} from '@/src/lib/reports/shareExport';

const learnerPassport = {
  learnerId: 'learner-1',
  learnerName: 'Avery Stone',
  currentLevel: 3,
  totalXp: 240,
  missionsCompleted: 4,
  attendanceRate: 0.95,
  pillarProgress: { futureSkills: 0.74, leadership: 0.62, impact: 0.51 },
  capabilitySnapshot: {
    futureSkills: 0.74,
    leadership: 0.62,
    impact: 0.51,
    overall: 0.67,
    band: 'developing',
  },
  evidenceSummary: {
    recordCount: 3,
    reviewedCount: 2,
    portfolioLinkedCount: 1,
    verificationPromptCount: 1,
    latestEvidenceAt: '2026-03-20T10:00:00.000Z',
  },
  growthSummary: {
    capabilityCount: 1,
    updatedCapabilityCount: 1,
    averageLevel: 3,
    latestLevel: 3,
    latestGrowthAt: '2026-03-21T10:00:00.000Z',
  },
  growthTimeline: [
    {
      capabilityId: 'cap-1',
      title: 'Evidence-backed reasoning',
      pillar: 'FUTURE_SKILLS',
      level: 3,
      occurredAt: '2026-03-21T10:00:00.000Z',
      reviewingEducatorName: 'Coach Rivera',
      rubricRawScore: 3,
      rubricMaxScore: 4,
      proofOfLearningStatus: 'verified',
      linkedEvidenceRecordIds: ['ev-1'],
      linkedPortfolioItemIds: ['portfolio-1'],
      missionAttemptId: 'attempt-1',
    },
  ],
  processDomainSnapshot: [
    {
      processDomainId: 'process-1',
      title: 'Iteration',
      currentLevel: 3,
      highestLevel: 3,
      evidenceCount: 2,
      updatedAt: '2026-03-21T10:00:00.000Z',
    },
  ],
  processDomainGrowthTimeline: [
    {
      processDomainId: 'process-1',
      title: 'Iteration',
      fromLevel: 2,
      toLevel: 3,
      reviewingEducatorName: 'Coach Rivera',
      linkedEvidenceRecordIds: ['ev-1'],
      missionAttemptId: 'attempt-1',
      rubricApplicationId: 'rubric-app-1',
      rubricRawScore: 3,
      rubricMaxScore: 4,
      evidenceCount: 1,
      createdAt: '2026-03-21T10:00:00.000Z',
    },
  ],
  portfolioSnapshot: {
    artifactCount: 1,
    publishedArtifactCount: 1,
    badgeCount: 0,
    projectCount: 1,
    evidenceLinkedArtifactCount: 1,
    verifiedArtifactCount: 1,
    latestArtifactAt: '2026-03-20T10:00:00.000Z',
  },
  portfolioItemsPreview: [
    {
      id: 'portfolio-1',
      title: 'Prototype Evidence',
      pillar: 'FUTURE_SKILLS',
      type: 'project',
      source: 'mission-review',
      completedAt: '2026-03-20T10:00:00.000Z',
      verificationStatus: 'reviewed',
      evidenceLinked: true,
      evidenceRecordIds: ['ev-1'],
      missionAttemptId: 'attempt-1',
      verificationPrompt: 'Explain why the prototype path matched the evidence.',
      capabilityTitles: ['Evidence-backed reasoning'],
      proofOfLearningStatus: 'verified',
      aiDisclosureStatus: 'learner-ai-not-used',
      aiAssistanceDetails: 'Learner declared no AI support used.',
      proofHasExplainItBack: true,
      proofHasOralCheck: true,
      proofHasMiniRebuild: false,
      proofCheckpointCount: 2,
      reviewingEducatorName: 'Coach Rivera',
      reviewedAt: '2026-03-21T10:00:00.000Z',
      rubricRawScore: 3,
      rubricMaxScore: 4,
    },
  ],
  ideationPassport: {
    missionAttempts: 1,
    completedMissions: 1,
    reflectionsSubmitted: 1,
    voiceInteractions: 0,
    collaborationSignals: 1,
    lastReflectionAt: '2026-03-20T10:00:00.000Z',
    generatedAt: '2026-03-22T10:00:00.000Z',
    summary: 'Avery can explain prototype choices using reviewed evidence.',
    claims: [
      {
        capabilityId: 'cap-1',
        title: 'Evidence-backed reasoning',
        pillar: 'FUTURE_SKILLS',
        latestLevel: 3,
        evidenceCount: 2,
        verifiedArtifactCount: 1,
        evidenceRecordIds: ['ev-1'],
        portfolioItemIds: ['portfolio-1'],
        missionAttemptIds: ['attempt-1'],
        proofOfLearningStatus: 'verified',
        aiDisclosureStatus: 'learner-ai-not-used',
        proofHasExplainItBack: true,
        proofHasOralCheck: true,
        proofHasMiniRebuild: false,
        proofCheckpointCount: 2,
        reviewingEducatorName: 'Coach Rivera',
        reviewedAt: '2026-03-21T10:00:00.000Z',
        rubricRawScore: 3,
        rubricMaxScore: 4,
        progressionDescriptors: ['Explains choices with evidence and tradeoffs.'],
      },
    ],
  },
};

const guardianLearner = {
  learnerId: 'learner-1',
  name: 'Avery Stone',
  currentLevelBand: 'developing',
  attendanceRate: 0.95,
  pillars: [
    {
      pillarCode: 'FUTURE_SKILLS',
      label: 'Think, Make & Navigate AI',
      percent: 74,
      bandLabel: 'Developing',
    },
  ],
  growthTimeline: [
    {
      id: 'growth-1',
      capabilityTitle: 'Evidence-backed reasoning',
      levelAchieved: 'Level 3/4',
      educatorName: 'Coach Rivera',
      date: '2026-03-21T10:00:00.000Z',
      proofStatus: 'verified',
      linkedEvidenceCount: 1,
      linkedPortfolioCount: 1,
      missionAttemptId: 'attempt-1',
      rubricScore: { raw: 3, max: 4 },
    },
  ],
  processDomainSnapshot: [
    {
      processDomainId: 'process-1',
      title: 'Iteration',
      currentLevel: 'Level 3/4',
      highestLevel: 'Level 3/4',
      evidenceCount: 2,
      updatedAt: '2026-03-21T10:00:00.000Z',
    },
  ],
  processDomainGrowthTimeline: [
    {
      id: 'process-growth-1',
      processDomainTitle: 'Iteration',
      fromLevel: 'Level 2/4',
      toLevel: 'Level 3/4',
      educatorName: 'Coach Rivera',
      date: '2026-03-21T10:00:00.000Z',
      linkedEvidenceRecordIds: ['ev-1'],
      missionAttemptId: 'attempt-1',
      rubricApplicationId: 'rubric-app-1',
      rubricScore: { raw: 3, max: 4 },
      evidenceCount: 1,
    },
  ],
  portfolioHighlights: [
    {
      id: 'portfolio-1',
      title: 'Prototype Evidence',
      capabilityTitles: ['Evidence-backed reasoning'],
      source: 'mission-review',
      verificationStatus: 'verified',
      aiDisclosure: 'learner-ai-not-used',
      proofDetails: {
        explainItBack: true,
        oralCheck: true,
        miniRebuild: false,
        educatorVerifierName: 'Coach Rivera',
      },
      reviewedAt: '2026-03-21T10:00:00.000Z',
      evidenceCount: 1,
      proofCheckpointCount: 2,
      missionAttemptId: 'attempt-1',
      verificationPrompt: 'Explain why the prototype path matched the evidence.',
      rubricScore: { raw: 3, max: 4, level: 'Level 3/4' },
    },
  ],
  ideationPassport: {
    missionCount: 1,
    reflectionsCount: 1,
    capabilityClaimsCount: 1,
    summaryText: 'Avery can explain prototype choices using reviewed evidence.',
    claims: [
      {
        capabilityId: 'cap-1',
        capabilityTitle: 'Evidence-backed reasoning',
        pillarCode: 'FUTURE_SKILLS',
        level: 'Level 3/4',
        evidenceCount: 2,
        verifiedArtifactCount: 1,
        portfolioItemCount: 1,
        missionAttemptCount: 1,
        proofStatus: 'verified',
        aiDisclosureStatus: 'learner-ai-not-used',
        reviewerName: 'Coach Rivera',
        reviewedAt: '2026-03-21T10:00:00.000Z',
        rubricScore: { raw: 3, max: 4 },
        proofHasExplainItBack: true,
        proofHasOralCheck: true,
        proofHasMiniRebuild: false,
        proofCheckpointCount: 2,
        progressionDescriptor: 'Explains choices with evidence and tradeoffs.',
      },
    ],
  },
  evidenceSummary: {
    recordCount: 3,
    reviewedCount: 2,
    portfolioLinkedCount: 1,
  },
  miloosSupportSummary: {
    supportOpened: 2,
    supportUsed: 2,
    explainBackSubmitted: 1,
    pendingExplainBack: 1,
    recentSupportAt: '2026-03-22T10:00:00.000Z',
    status: 'pending-explain-back',
    isMasteryEvidence: false,
  },
  growthSummary: {
    capabilityCount: 1,
    updatedCount: 1,
    averageLevel: 3,
  },
  portfolioSnapshot: {
    artifactCount: 1,
    verifiedCount: 1,
    badgeCount: 0,
  },
};

describe('generated web report payload provenance', () => {
  it('asserts learner passport text and family share payloads carry required provenance', () => {
    assertReportProvenanceContract({
      text: buildPassportTextLines(learnerPassport as any).join('\n'),
      expectedSignals: passportReportProvenanceSignals,
      reportName: 'learner passport generated text',
    });

    assertReportProvenanceContract({
      text: buildFamilyShareSummary(learnerPassport as any),
      expectedSignals: familySummaryProvenanceSignals,
      reportName: 'learner family share generated text',
    });

    expect(buildPassportTextLines(learnerPassport as any).join('\n')).toContain(
      'Provenance:      1 evidence, mission-linked, rubric-linked'
    );
  });

  it('asserts guardian passport text and family share payloads carry required provenance', () => {
    const guardianPassportText = buildGuardianPassportTextLines(guardianLearner as any).join('\n');
    const guardianShareText = buildGuardianFamilyShareSummary(guardianLearner as any);

    assertReportProvenanceContract({
      text: guardianPassportText,
      expectedSignals: passportReportProvenanceSignals,
      reportName: 'guardian passport generated text',
    });

    assertReportProvenanceContract({
      text: guardianShareText,
      expectedSignals: familySummaryProvenanceSignals,
      reportName: 'guardian family share generated text',
    });

    expect(guardianPassportText).toContain('MiloOS Support Provenance');
    expect(guardianPassportText).toContain(
      'These are support and verification signals, not capability mastery.'
    );
    expect(guardianPassportText).toContain(
      'Provenance:      1 evidence, mission-linked, rubric-linked'
    );
    expect(guardianPassportText).toContain('Rubric Score:    3/4');
    expect(guardianShareText).toContain(
      'MiloOS support provenance: 2 opened, 2 used, 1 explain-back(s), 1 pending; not capability mastery.'
    );
    expect(guardianShareText).toContain('rubric-linked');
  });
});
