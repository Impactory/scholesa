const {
  buildBosMiaSyntheticTrainingArtifacts,
  inferredStarterExpectedRow,
} = require('../scripts/lib/bos_mia_synthetic_training');

describe('bos_mia_synthetic_training', () => {
  it('infers starter-pack expectations from rubric labels', () => {
    const inferred = inferredStarterExpectedRow({
      record_id: 'starter-1',
      grade_band: '4-6',
      mastery: 'proficient',
      checkpoint_result: 'pass',
      evidence_use: 'strong',
      integrity_risk: 'low',
      needs_followup: false,
      proof_of_work_present: true,
      confidence_self_rating: 3,
      eligible_for_training: true,
    });

    expect(inferred.recommended_split).toBe('train');
    expect(inferred.expected_action).toBe('auto_pass');
    expect(inferred.bos_mastery_score_expected).toBeGreaterThan(70);
    expect(inferred.mia_review_needed_expected).toBe(false);
  });

  it('builds a calibration profile and evaluation summary from synthetic packs', () => {
    const importedAt = new Date('2026-03-15T12:00:00.000Z');
    const artifacts = buildBosMiaSyntheticTrainingArtifacts({
      importedAt,
      sourcePacks: ['starter', 'full'],
      starterTrainingRows: [
        {
          record_id: 'starter-1',
          grade_band: '4-6',
          mastery: 'proficient',
          checkpoint_result: 'pass',
          evidence_use: 'strong',
          integrity_risk: 'low',
          needs_followup: false,
          proof_of_work_present: true,
          confidence_self_rating: 3,
          eligible_for_training: true,
          ai_used: false,
        },
      ],
      fullExpectedRows: [
        {
          record_id: 'full-1',
          grade_band: 'G4_6',
          recommended_split: 'train',
          bos_mastery_score_expected: 78,
          bos_readiness_score_expected: 74,
          mia_integrity_score_expected: 84,
          mia_review_needed_expected: false,
          expected_action: 'auto_pass',
          confidence_calibration_gap: 6,
          ai_used: false,
        },
        {
          record_id: 'full-2',
          grade_band: 'G7_9',
          recommended_split: 'train',
          bos_mastery_score_expected: 58,
          bos_readiness_score_expected: 52,
          mia_integrity_score_expected: 41,
          mia_review_needed_expected: true,
          expected_action: 'escalate_teacher_review',
          confidence_calibration_gap: 18,
          ai_used: true,
        },
      ],
      longitudinalRows: [
        { expected_mastery_delta_from_prev: 8 },
        { expected_mastery_delta_from_prev: 14 },
      ],
      goldEvalRows: [
        {
          grade_band: 'G4_6',
          bos_mastery_score_expected: 78,
          bos_readiness_score_expected: 74,
          mia_integrity_score_expected: 84,
          mia_review_needed_expected: false,
          expected_action: 'auto_pass',
          confidence_calibration_gap: 6,
          ai_used: false,
        },
        {
          grade_band: 'G7_9',
          bos_mastery_score_expected: 58,
          bos_readiness_score_expected: 52,
          mia_integrity_score_expected: 41,
          mia_review_needed_expected: true,
          expected_action: 'escalate_teacher_review',
          confidence_calibration_gap: 18,
          ai_used: true,
        },
      ],
    });

    expect(artifacts.summary.modelVersion).toBe('synthetic-bos-mia-starter-full-v1');
    expect(artifacts.summary.trainingRunId).toContain('bos-mia-synthetic-2026-03-15T12-00-00-000Z');
    expect(artifacts.summary.calibratedGradeBands).toBeGreaterThanOrEqual(2);
    expect(artifacts.profileDoc.gradeBandProfiles.G4_6.ekfAlpha).toBeGreaterThanOrEqual(0.55);
    expect(artifacts.profileDoc.gradeBandProfiles.G7_9.autonomyRiskThreshold).toBeGreaterThanOrEqual(0.45);
    expect(artifacts.summary.actionAccuracy).toBeGreaterThan(0);
  });
});