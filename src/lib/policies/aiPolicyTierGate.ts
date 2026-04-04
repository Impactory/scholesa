/**
 * AI Policy Tier Gate (S1-3)
 *
 * Enforces stage-based AI usage policies:
 *   Tier A (Discoverers, grades 1-3): AI blocked for students
 *   Tier B (Builders, grades 4-6):    Brainstorming with justification (hint only)
 *   Tier C (Explorers, grades 7-9):   Analysis with citation (hint + rubric_check + debug)
 *   Tier D (Innovators, grades 10-12): Full access with audit trail (all modes)
 */

import type { AiPolicyTier, StageId } from '@/src/types/schema';
import type { TaskType } from '@/src/lib/ai/modelAdapter';

/** Result of a policy tier enforcement check */
export interface AiPolicyGateResult {
  allowed: boolean;
  tier: AiPolicyTier;
  reason: string;
  allowedModes: TaskType[];
}

/** Map stage IDs to their AI policy tier */
const STAGE_TO_TIER: Record<StageId, AiPolicyTier> = {
  discoverers: 'A',
  builders: 'B',
  explorers: 'C',
  innovators: 'D',
};

/** Allowed AI task types per tier */
const TIER_ALLOWED_MODES: Record<AiPolicyTier, TaskType[]> = {
  A: [],
  B: ['hint'],
  C: ['hint', 'rubric_check', 'debug'],
  D: ['hint', 'rubric_check', 'debug', 'critique'],
};

/** Human-readable tier descriptions */
const TIER_DESCRIPTIONS: Record<AiPolicyTier, string> = {
  A: 'AI help is not available at the Discoverers stage.',
  B: 'At the Builders stage, AI can provide hints. You must justify how the hint helped.',
  C: 'At the Explorers stage, AI can provide hints, rubric checks, and debugging help. Citation required.',
  D: 'At the Innovators stage, all AI modes are available. All interactions are audited.',
};

/**
 * Check whether a specific AI task type is allowed for a learner's stage.
 *
 * @param stageId - The learner's current stage (from UserProfile.stageId)
 * @param taskType - The requested AI interaction mode
 * @returns Gate result with allowed/blocked status, tier, reason, and available modes
 */
export function enforceAiPolicyTier(
  stageId: StageId | undefined,
  taskType: TaskType
): AiPolicyGateResult {
  // If no stage set, default to most permissive (D) to avoid blocking
  if (!stageId) {
    return {
      allowed: true,
      tier: 'D',
      reason: 'No stage assigned — defaulting to full access.',
      allowedModes: TIER_ALLOWED_MODES.D,
    };
  }

  const tier = STAGE_TO_TIER[stageId];
  const allowedModes = TIER_ALLOWED_MODES[tier];
  const allowed = allowedModes.includes(taskType);

  return {
    allowed,
    tier,
    reason: allowed
      ? `Tier ${tier}: ${taskType} permitted.`
      : `Tier ${tier}: ${taskType} not permitted. ${TIER_DESCRIPTIONS[tier]}`,
    allowedModes,
  };
}

/**
 * Get the AI policy tier for a stage.
 */
export function getTierForStage(stageId: StageId | undefined): AiPolicyTier {
  if (!stageId) return 'D';
  return STAGE_TO_TIER[stageId];
}

/**
 * Get human-readable description of what AI modes are available.
 */
export function getTierDescription(tier: AiPolicyTier): string {
  return TIER_DESCRIPTIONS[tier];
}
