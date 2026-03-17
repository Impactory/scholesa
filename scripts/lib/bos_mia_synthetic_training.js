function toBoolean(value) {
  if (typeof value === 'boolean') return value;
  const normalized = String(value || '').trim().toLowerCase();
  return normalized === 'true' || normalized === '1' || normalized === 'yes';
}

function toNumber(value, fallback = 0) {
  const parsed = Number.parseFloat(String(value ?? ''));
  return Number.isFinite(parsed) ? parsed : fallback;
}

function clamp(value, min, max) {
  return Math.min(max, Math.max(min, value));
}

function round(value, digits = 3) {
  const factor = 10 ** digits;
  return Math.round(value * factor) / factor;
}

function average(values, fallback = 0) {
  if (!Array.isArray(values) || values.length === 0) return fallback;
  return values.reduce((sum, entry) => sum + entry, 0) / values.length;
}

function normalizeGradeBand(raw) {
  switch (String(raw || '').trim()) {
    case '1-3':
    case 'G1_3':
      return 'G1_3';
    case '4-6':
    case 'G4_6':
      return 'G4_6';
    case '7-9':
    case 'G7_9':
      return 'G7_9';
    case '10-12':
    case 'G10_12':
      return 'G10_12';
    default:
      return 'G4_6';
  }
}

function scoreAnchorFromMastery(label) {
  switch (String(label || '').trim().toLowerCase()) {
    case 'advanced':
      return 86;
    case 'proficient':
      return 74;
    case 'developing':
      return 60;
    case 'novice':
    default:
      return 48;
  }
}

function readinessAnchorFromCheckpoint(label) {
  switch (String(label || '').trim().toLowerCase()) {
    case 'pass':
      return 72;
    case 'pass_with_support':
      return 60;
    case 'not_yet':
    default:
      return 48;
  }
}

function integrityAnchorFromRisk(label) {
  switch (String(label || '').trim().toLowerCase()) {
    case 'high':
      return 35;
    case 'medium':
      return 59;
    case 'low':
    default:
      return 83;
  }
}

function inferredStarterExpectedRow(row) {
  const masteryScore = scoreAnchorFromMastery(row.mastery);
  let readinessScore = readinessAnchorFromCheckpoint(row.checkpoint_result);
  if (String(row.evidence_use || '').trim().toLowerCase() === 'strong') {
    readinessScore += 4;
  } else if (String(row.evidence_use || '').trim().toLowerCase() === 'weak') {
    readinessScore -= 4;
  }
  if (toBoolean(row.needs_followup)) {
    readinessScore -= 8;
  }
  const integrityScore = integrityAnchorFromRisk(row.integrity_risk);
  const reviewNeeded =
    toBoolean(row.needs_followup) ||
    String(row.integrity_risk || '').trim().toLowerCase() === 'high' ||
    (!toBoolean(row.proof_of_work_present) &&
      String(row.checkpoint_result || '').trim().toLowerCase() !== 'pass');
  const expectedAction = reviewNeeded
    ? 'escalate_teacher_review'
    : masteryScore < 65 || readinessScore < 60
      ? 'coach_next_step'
      : 'auto_pass';
  const selfRating = toNumber(row.confidence_self_rating, 2.5);
  const expectedConfidence = expectedAction === 'auto_pass' ? 3.2 : 2.2;

  return {
    record_id: row.record_id,
    grade_band: row.grade_band,
    recommended_split: toBoolean(row.eligible_for_training) ? 'train' : 'starter_eval',
    bos_mastery_score_expected: masteryScore,
    bos_readiness_score_expected: clamp(readinessScore, 35, 92),
    mia_integrity_score_expected: integrityScore,
    mia_review_needed_expected: reviewNeeded,
    expected_action: expectedAction,
    confidence_calibration_gap: round((selfRating - expectedConfidence) * 12, 2),
  };
}

function joinExpectedWithCore(expectedRows, coreRows) {
  const coreByRecordId = new Map();
  coreRows.forEach((row) => {
    if (row && row.record_id) {
      coreByRecordId.set(row.record_id, row);
    }
  });

  return expectedRows.map((row) => {
    const core = coreByRecordId.get(row.record_id) || {};
    return {
      ...core,
      ...row,
      grade_band: row.grade_band || core.grade_band,
      ai_used: row.ai_used !== undefined ? row.ai_used : core.ai_used,
    };
  });
}

function candidateIntegrityThresholds(rows) {
  const thresholds = new Set([0.55, 0.6, 0.65, 0.7, 0.75, 0.8]);
  rows.forEach((row) => {
    const score = clamp(toNumber(row.mia_integrity_score_expected, 0) / 100, 0, 1);
    thresholds.add(round(score, 2));
  });
  return Array.from(thresholds).sort((left, right) => left - right);
}

function bestIntegrityThreshold(rows) {
  const reviewRows = rows.filter((row) => row.mia_review_needed_expected === true);
  const nonReviewRows = rows.filter((row) => row.mia_review_needed_expected !== true);
  if (rows.length === 0 || reviewRows.length === 0 || nonReviewRows.length === 0) {
    return 0.65;
  }

  let bestThreshold = 0.65;
  let bestBalancedAccuracy = -1;
  let bestAccuracy = -1;

  candidateIntegrityThresholds(rows).forEach((threshold) => {
    let truePositive = 0;
    let trueNegative = 0;
    let falsePositive = 0;
    let falseNegative = 0;

    rows.forEach((row) => {
      const score = clamp(toNumber(row.mia_integrity_score_expected, 0) / 100, 0, 1);
      const predictedReview = score < threshold;
      const expectedReview = row.mia_review_needed_expected === true;
      if (predictedReview && expectedReview) truePositive += 1;
      else if (!predictedReview && !expectedReview) trueNegative += 1;
      else if (predictedReview) falsePositive += 1;
      else falseNegative += 1;
    });

    const sensitivity = truePositive / Math.max(1, truePositive + falseNegative);
    const specificity = trueNegative / Math.max(1, trueNegative + falsePositive);
    const balancedAccuracy = (sensitivity + specificity) / 2;
    const accuracy = (truePositive + trueNegative) / Math.max(1, rows.length);

    if (
      balancedAccuracy > bestBalancedAccuracy ||
      (balancedAccuracy === bestBalancedAccuracy && accuracy > bestAccuracy)
    ) {
      bestThreshold = threshold;
      bestBalancedAccuracy = balancedAccuracy;
      bestAccuracy = accuracy;
    }
  });

  return round(bestThreshold, 3);
}

function deriveEkfAlpha(longitudinalRows) {
  if (!Array.isArray(longitudinalRows) || longitudinalRows.length === 0) {
    return 0.7;
  }
  const deltas = longitudinalRows
    .map((row) => Math.abs(toNumber(row.expected_mastery_delta_from_prev, 0)))
    .filter((value) => Number.isFinite(value));
  if (deltas.length === 0) return 0.7;
  const avgAbsDelta = average(deltas, 0);
  return round(clamp(0.85 - (avgAbsDelta / 100), 0.55, 0.85), 3);
}

function deriveReliabilityThreshold(rows) {
  const gaps = rows
    .map((row) => Math.abs(toNumber(row.confidence_calibration_gap, 0)))
    .filter((value) => Number.isFinite(value));
  const meanAbsGap = average(gaps, 18);
  return round(clamp(0.5 + Math.min(0.18, meanAbsGap / 200), 0.45, 0.75), 3);
}

function deriveAutonomyThreshold(rows) {
  const aiRows = rows.filter((row) => toBoolean(row.ai_used));
  const escalationRate = aiRows.length === 0
    ? 0.2
    : aiRows.filter((row) => row.expected_action === 'escalate_teacher_review').length / aiRows.length;
  return round(clamp(0.45 + (escalationRate * 0.2), 0.45, 0.7), 3);
}

function expectedActionFromProfile(row, profile) {
  const masteryScore = toNumber(row.bos_mastery_score_expected, 0);
  const readinessScore = toNumber(row.bos_readiness_score_expected, 0);
  const integrityScore = toNumber(row.mia_integrity_score_expected, 0) / 100;
  if (integrityScore < profile.integrityFloor) {
    return 'escalate_teacher_review';
  }
  if (
    masteryScore < profile.targetRegion.cognitionTarget * 100 ||
    readinessScore < profile.targetRegion.engagementTarget * 100
  ) {
    return 'coach_next_step';
  }
  return 'auto_pass';
}

function evaluateActionMetrics(rows, profile) {
  if (!Array.isArray(rows) || rows.length === 0) {
    return {
      cases: 0,
      actionAccuracy: 0,
      reviewPrecision: 0,
      reviewRecall: 0,
    };
  }

  let exactActionMatches = 0;
  let truePositive = 0;
  let falsePositive = 0;
  let falseNegative = 0;

  rows.forEach((row) => {
    const predictedAction = expectedActionFromProfile(row, profile);
    const expectedAction = String(row.expected_action || '').trim();
    const predictedReview = predictedAction === 'escalate_teacher_review';
    const expectedReview = expectedAction === 'escalate_teacher_review' || row.mia_review_needed_expected === true;

    if (predictedAction === expectedAction) {
      exactActionMatches += 1;
    }
    if (predictedReview && expectedReview) truePositive += 1;
    else if (predictedReview) falsePositive += 1;
    else if (expectedReview) falseNegative += 1;
  });

  return {
    cases: rows.length,
    actionAccuracy: round(exactActionMatches / Math.max(1, rows.length), 4),
    reviewPrecision: round(truePositive / Math.max(1, truePositive + falsePositive), 4),
    reviewRecall: round(truePositive / Math.max(1, truePositive + falseNegative), 4),
  };
}

function computeGradeBandProfile(rows, longitudinalRows, goldEvalRows) {
  const healthyRows = rows.filter((row) =>
    row.mia_review_needed_expected !== true &&
    String(row.expected_action || '').trim() !== 'escalate_teacher_review',
  );
  const targetRows = healthyRows.length > 0 ? healthyRows : rows;
  const integrityFloor = bestIntegrityThreshold(rows);
  const profile = {
    targetRegion: {
      cognitionTarget: round(clamp(average(targetRows.map((row) => toNumber(row.bos_mastery_score_expected, 60)), 60) / 100, 0.45, 0.9), 3),
      engagementTarget: round(clamp(average(targetRows.map((row) => toNumber(row.bos_readiness_score_expected, 60)), 60) / 100, 0.45, 0.9), 3),
      integrityFloor: round(clamp(integrityFloor, 0.45, 0.9), 3),
    },
    integrityFloor: round(clamp(integrityFloor, 0.45, 0.9), 3),
    ekfAlpha: deriveEkfAlpha(longitudinalRows),
    autonomyRiskThreshold: deriveAutonomyThreshold(rows),
    reliabilityRiskThreshold: deriveReliabilityThreshold(rows),
    reviewNeededRate: round(rows.filter((row) => row.mia_review_needed_expected === true).length / Math.max(1, rows.length), 4),
    averageConfidenceGap: round(average(rows.map((row) => Math.abs(toNumber(row.confidence_calibration_gap, 0))), 0), 2),
    averageMasteryScore: round(average(rows.map((row) => toNumber(row.bos_mastery_score_expected, 60)), 60), 2),
    averageReadinessScore: round(average(rows.map((row) => toNumber(row.bos_readiness_score_expected, 60)), 60), 2),
    averageIntegrityScore: round(average(rows.map((row) => toNumber(row.mia_integrity_score_expected, 75)), 75), 2),
    trainRows: rows.length,
    healthyRows: healthyRows.length,
    longitudinalRows: longitudinalRows.length,
  };

  return {
    ...profile,
    goldEvaluation: evaluateActionMetrics(goldEvalRows, profile),
  };
}

function groupByGradeBand(rows) {
  const groups = new Map();
  rows.forEach((row) => {
    const gradeBand = normalizeGradeBand(row.grade_band);
    if (!groups.has(gradeBand)) {
      groups.set(gradeBand, []);
    }
    groups.get(gradeBand).push(row);
  });
  return groups;
}

function buildBosMiaSyntheticTrainingArtifacts(input) {
  const importedAt = input.importedAt || new Date();
  const starterExpectedRows = (input.starterTrainingRows || []).map(inferredStarterExpectedRow);
  const fullExpectedRows = joinExpectedWithCore(input.fullExpectedRows || [], input.coreRows || []);
  const combinedTrainingRows = [...starterExpectedRows, ...fullExpectedRows]
    .filter((row) => String(row.recommended_split || '').trim().toLowerCase() === 'train');

  const goldEvalRows = input.goldEvalRows || [];
  const longitudinalRows = input.longitudinalRows || [];
  const byGradeBand = groupByGradeBand(combinedTrainingRows);
  const longitudinalByGradeBand = groupByGradeBand(longitudinalRows);
  const goldByGradeBand = groupByGradeBand(goldEvalRows);
  const gradeBandProfiles = {};

  Array.from(byGradeBand.keys()).sort().forEach((gradeBand) => {
    gradeBandProfiles[gradeBand] = {
      gradeBand,
      ...computeGradeBandProfile(
        byGradeBand.get(gradeBand) || [],
        longitudinalByGradeBand.get(gradeBand) || [],
        goldByGradeBand.get(gradeBand) || [],
      ),
    };
  });

  const overallProfile = {
    integrityFloor: bestIntegrityThreshold(combinedTrainingRows),
    ekfAlpha: deriveEkfAlpha(longitudinalRows),
    autonomyRiskThreshold: deriveAutonomyThreshold(combinedTrainingRows),
    reliabilityRiskThreshold: deriveReliabilityThreshold(combinedTrainingRows),
  };
  const overallEvaluation = evaluateActionMetrics(goldEvalRows, {
    targetRegion: {
      cognitionTarget: round(average(Object.values(gradeBandProfiles).map((profile) => profile.targetRegion.cognitionTarget), 0.66), 3),
      engagementTarget: round(average(Object.values(gradeBandProfiles).map((profile) => profile.targetRegion.engagementTarget), 0.64), 3),
      integrityFloor: overallProfile.integrityFloor,
    },
    integrityFloor: overallProfile.integrityFloor,
  });

  const modelVersion = `synthetic-bos-mia-${(input.sourcePacks || ['starter']).join('-')}-v1`;
  const trainingRunId = `bos-mia-synthetic-${importedAt.toISOString().replace(/[:.]/g, '-')}`;
  const profileDoc = {
    id: 'latest',
    scope: 'synthetic',
    sitePrefix: 'synthetic-site-',
    synthetic: true,
    modelVersion,
    trainingRunId,
    trainedAt: importedAt,
    sourcePacks: input.sourcePacks || [],
    gradeBandProfiles,
    overallProfile,
    evaluation: overallEvaluation,
    sourceCounts: {
      trainingRows: combinedTrainingRows.length,
      goldEvalCases: goldEvalRows.length,
      longitudinalRows: longitudinalRows.length,
    },
  };

  return {
    trainingRunId,
    profileDoc,
    trainingRunDoc: {
      id: trainingRunId,
      synthetic: true,
      sourcePacks: input.sourcePacks || [],
      trainedAt: importedAt,
      modelVersion,
      gradeBandProfiles,
      overallProfile,
      evaluation: overallEvaluation,
      sourceCounts: profileDoc.sourceCounts,
    },
    summary: {
      modelVersion,
      trainingRunId,
      trainedAt: importedAt,
      calibratedGradeBands: Object.keys(gradeBandProfiles).length,
      trainingRows: combinedTrainingRows.length,
      goldEvalCases: goldEvalRows.length,
      actionAccuracy: overallEvaluation.actionAccuracy,
      reviewPrecision: overallEvaluation.reviewPrecision,
      reviewRecall: overallEvaluation.reviewRecall,
    },
  };
}

module.exports = {
  buildBosMiaSyntheticTrainingArtifacts,
  expectedActionFromProfile,
  inferredStarterExpectedRow,
  normalizeGradeBand,
};