import {
  CURRICULUM_ANNUAL_RHYTHM,
  CURRICULUM_LESSON_MOVES,
  CURRICULUM_PORTFOLIO_VIEWS,
  CURRICULUM_PROOF_LAYERS,
  CURRICULUM_HUMAN_SUPPORT_ROLES,
  CURRICULUM_IMPLEMENTATION_PHASES,
  CURRICULUM_STAGE_ORDER,
  CURRICULUM_STAGES,
  CURRICULUM_STRANDS,
  LEGACY_PILLAR_ALIGNMENT,
  getCurriculumStageFromGrade,
} from '@/src/lib/curriculum/architecture';
import { enforceAiPolicyTier, getTierForStage } from '@/src/lib/policies/aiPolicyTierGate';
import { getAICoachModesForGrade } from '@/src/lib/policies/gradeBandPolicy';

describe('curriculum architecture contract', () => {
  it('encodes the four-stage K-12 learner journey', () => {
    expect(CURRICULUM_STAGE_ORDER).toEqual([
      'discoverers',
      'builders',
      'explorers',
      'innovators',
    ]);

    expect(getCurriculumStageFromGrade(1).name).toBe('Discoverers');
    expect(getCurriculumStageFromGrade(4).name).toBe('Builders');
    expect(getCurriculumStageFromGrade(7).name).toBe('Explorers');
    expect(getCurriculumStageFromGrade(10).name).toBe('Innovators');
    expect(CURRICULUM_STAGES.innovators.pathways).toHaveLength(5);
  });

  it('encodes the six durable capability strands from the master curriculum', () => {
    expect(CURRICULUM_STRANDS.map((strand) => strand.name)).toEqual([
      'Think',
      'Make',
      'Communicate',
      'Lead',
      'Navigate AI',
      'Build for the World',
    ]);
  });

  it('keeps annual rhythm, lesson moves, proof layers, and portfolio views aligned', () => {
    expect(CURRICULUM_ANNUAL_RHYTHM.map((cycle) => cycle.id)).toEqual([
      'understand',
      'design',
      'test',
      'showcase',
    ]);
    expect(CURRICULUM_LESSON_MOVES.map((move) => move.id)).toEqual([
      'hook',
      'micro_skill',
      'build_sprint',
      'checkpoint',
      'share_out',
      'reflection',
    ]);
    expect(CURRICULUM_PROOF_LAYERS.map((layer) => layer.id)).toEqual([
      'process',
      'product',
      'thinking',
      'improvement',
      'integrity',
    ]);
    expect(CURRICULUM_PORTFOLIO_VIEWS.map((view) => view.id)).toEqual([
      'timeline',
      'capability',
      'best_work_showcase',
    ]);
    expect(CURRICULUM_HUMAN_SUPPORT_ROLES.map((entry) => entry.role)).toEqual([
      'teacher',
      'family',
      'mentor',
      'administrator',
    ]);
    expect(CURRICULUM_IMPLEMENTATION_PHASES.map((phase) => phase.id)).toEqual([
      'pilot_year',
      'core_platform_year',
      'network_scale',
    ]);
  });

  it('keeps AI policy tiers and grade-band coach modes aligned to the stage model', () => {
    expect(getTierForStage('discoverers')).toBe('A');
    expect(getTierForStage('builders')).toBe('B');
    expect(getTierForStage('explorers')).toBe('C');
    expect(getTierForStage('innovators')).toBe('D');

    expect(enforceAiPolicyTier('discoverers', 'hint_generation').allowed).toBe(false);
    expect(enforceAiPolicyTier('builders', 'hint_generation').allowed).toBe(true);
    expect(enforceAiPolicyTier('builders', 'debug_assistance').allowed).toBe(false);
    expect(enforceAiPolicyTier('explorers', 'critique_feedback').allowed).toBe(true);
    expect(enforceAiPolicyTier('innovators', 'reflection_prompt').allowed).toBe(true);

    expect(getAICoachModesForGrade(1)).toEqual([]);
    expect(getAICoachModesForGrade(4)).toEqual(['hint']);
    expect(getAICoachModesForGrade(7)).toEqual([
      'hint',
      'rubric_check',
      'debug',
      'critique',
    ]);
    expect(getAICoachModesForGrade(10)).toEqual([
      'hint',
      'rubric_check',
      'debug',
      'critique',
    ]);
  });

  it('documents how legacy pillar analytics map onto the six-strand model', () => {
    expect(LEGACY_PILLAR_ALIGNMENT.FUTURE_SKILLS.familyLabel).toBe(
      'Think, Make & Navigate AI',
    );
    expect(LEGACY_PILLAR_ALIGNMENT.FUTURE_SKILLS.strandIds).toEqual([
      'think',
      'make',
      'navigate_ai',
    ]);
    expect(LEGACY_PILLAR_ALIGNMENT.LEADERSHIP_AGENCY.strandIds).toEqual([
      'communicate',
      'lead',
    ]);
    expect(LEGACY_PILLAR_ALIGNMENT.IMPACT_INNOVATION.strandIds).toEqual([
      'build_for_the_world',
    ]);
  });
});
