/**
 * AI Policy Tier Gate (S1-3)
 *
 * Enforces stage-based AI usage policies:
 *   Tier A (Discoverers, grades 1-3): Whole-class demonstration only
 *   Tier B (Builders, grades 4-6):    Guided assistive use with no-copy guardrails
 *   Tier C (Explorers, grades 7-9):   Logged analytical and critique use
 *   Tier D (Innovators, grades 10-12): Advanced assistive use with full audit trail
 */

import type { AiPolicyTier, StageId } from '@/src/types/schema';
import type { TaskType } from '@/src/lib/ai/modelAdapter';
import {
  getAiAllowedTaskTypesForStage,
  getAiPolicyTierForStage,
} from '@/src/lib/curriculum/architecture';

/** Result of a policy tier enforcement check */
export interface AiPolicyGateResult {
  allowed: boolean;
  tier: AiPolicyTier;
  reason: string;
  allowedModes: TaskType[];
}

/** Allowed AI task types per tier */
const TIER_ALLOWED_MODES: Record<AiPolicyTier, TaskType[]> = {
  A: [...getAiAllowedTaskTypesForStage('discoverers')],
  B: [...getAiAllowedTaskTypesForStage('builders')],
  C: [...getAiAllowedTaskTypesForStage('explorers')],
  D: [...getAiAllowedTaskTypesForStage('innovators')],
};

/** Human-readable tier descriptions */
const TIER_DESCRIPTIONS: Record<AiPolicyTier, string> = {
  A: 'At the Discoverers stage, AI is teacher-led only and does not run as an independent learner tool.',
  B: 'At the Builders stage, AI is guided assistive support with narrow prompts and no-copy guardrails.',
  C: 'At the Explorers stage, AI use must stay logged, analytical, and critique-ready with verification routines.',
  D: 'At the Innovators stage, advanced assistive use is allowed with a full audit trail and integrity defense.',
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

  const tier = getAiPolicyTierForStage(stageId);
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
  return getAiPolicyTierForStage(stageId);
}

/**
 * Get human-readable description of what AI modes are available.
 */
export function getTierDescription(tier: AiPolicyTier): string {
  return TIER_DESCRIPTIONS[tier];
}
