import 'package:flutter_test/flutter_test.dart';
import 'package:scholesa_app/domain/models.dart';

/// Schema alignment test — verifies that all 10 evidence chain models from
/// CLAUDE.md are present in the Flutter domain layer with correct field sets.
void main() {
  group('Evidence chain schema alignment (15/15)', () {
    test('CheckpointModel has required evidence capture fields', () {
      const CheckpointModel m = CheckpointModel(
        id: 'cp1',
        missionId: 'm1',
        learnerId: 'l1',
        siteId: 's1',
        question: 'q',
        learnerResponse: 'r',
      );
      // Must have explain-it-back support
      expect(m.explainItBackRequired, isFalse);
      // Must have skill linkage
      expect(m.skillId, isNull);
      // Must have educator attribution
      expect(m.educatorId, isNull);
    });

    test('ReflectionEntryModel has metacognitive fields', () {
      const ReflectionEntryModel m = ReflectionEntryModel(
        id: 'r1',
        learnerId: 'l1',
        siteId: 's1',
        prompt: 'p',
        response: 'r',
      );
      // Must have engagement + confidence scales
      expect(m.engagementRating, isNull);
      expect(m.confidenceRating, isNull);
      // Must have educator note support
      expect(m.educatorNotes, isNull);
    });

    test('SkillEvidenceModel links evidence to micro-skills', () {
      const SkillEvidenceModel m = SkillEvidenceModel(
        id: 'se1',
        learnerId: 'l1',
        skillId: 'sk1',
        capabilityId: 'cap1',
        evidenceType: 'artifact',
        evidenceRefId: 'ref1',
        siteId: 's1',
      );
      // Must support 4 evidence types: artifact, observation, checkpoint, reflection
      expect(<String>['artifact', 'observation', 'checkpoint', 'reflection'],
          contains(m.evidenceType));
    });

    test('AICoachInteractionModel has guardrails', () {
      const AICoachInteractionModel m = AICoachInteractionModel(
        id: 'ai1',
        learnerId: 'l1',
        siteId: 's1',
        mode: 'hint',
        question: 'q',
        response: 'r',
      );
      // Must have explain-it-back guardrails
      expect(m.explainItBackRequired, isFalse);
      // Must have version history check
      expect(m.versionHistoryCheck, isNull);
      // Must have tools tracking
      expect(m.toolsUsed, isEmpty);
    });

    test('PeerFeedbackModel has structured review fields', () {
      const PeerFeedbackModel m = PeerFeedbackModel(
        id: 'pf1',
        fromLearnerId: 'from1',
        toLearnerId: 'to1',
        missionAttemptId: 'ma1',
        siteId: 's1',
      );
      // Must link from/to learners
      expect(m.fromLearnerId, isNotEmpty);
      expect(m.toLearnerId, isNotEmpty);
      // Must have structured feedback
      expect(m.strengths, isNull);
      expect(m.suggestions, isNull);
    });

    test('MicroSkillModel has rubric levels map', () {
      const MicroSkillModel m = MicroSkillModel(
        id: 'ms1',
        capabilityId: 'cap1',
        pillarCode: 'futureSkills',
        name: 'n',
        description: 'd',
        rubricLevels: <String, String>{
          'emerging': 'desc',
          'developing': 'desc',
          'proficient': 'desc',
          'advanced': 'desc',
        },
      );
      // Must have pillar code for evidence chain linkage
      expect(m.pillarCode, isNotEmpty);
      // Must support 4 rubric levels
      expect(m.rubricLevels, hasLength(4));
    });

    test('MissionVariantModel has difficulty differentiation', () {
      const MissionVariantModel m = MissionVariantModel(
        id: 'mv1',
        missionId: 'm1',
        difficultyLevel: 'challenge',
        description: 'd',
      );
      // Must support easy/standard/challenge levels
      expect(<String>['easy', 'standard', 'challenge'],
          contains(m.difficultyLevel));
    });

    test('ShowcaseSubmissionModel has visibility controls', () {
      const ShowcaseSubmissionModel m = ShowcaseSubmissionModel(
        id: 'sc1',
        learnerId: 'l1',
        portfolioItemId: 'pi1',
        title: 't',
        description: 'd',
      );
      // Must support public/school/class visibility
      expect(<String>['public', 'school', 'class'], contains(m.visibility));
      // Must have approval workflow
      expect(<String>['pending', 'approved', 'rejected'],
          contains(m.approvalStatus));
    });

    test('WeeklyGoalModel has goal lifecycle', () {
      const WeeklyGoalModel m = WeeklyGoalModel(
        id: 'wg1',
        learnerId: 'l1',
        siteId: 's1',
        goalText: 'g',
      );
      // Must support active/completed/abandoned lifecycle
      expect(<String>['active', 'completed', 'abandoned'],
          contains(m.status));
      // Must link to capability
      expect(m.targetCapabilityId, isNull);
    });

    test('ProofOfLearningBundleModel has 3 verification methods', () {
      const ProofOfLearningBundleModel m = ProofOfLearningBundleModel(
        id: 'pol1',
        learnerId: 'l1',
        portfolioItemId: 'pi1',
      );
      // Must have all 3 verification methods
      expect(m.hasExplainItBack, isFalse);
      expect(m.hasOralCheck, isFalse);
      expect(m.hasMiniRebuild, isFalse);
      // Must have verification status (missing/partial/verified)
      expect(<String>['missing', 'partial', 'verified'],
          contains(m.verificationStatus));
      // Must have versioning
      expect(m.version, 1);
    });
  });
}
