import 'package:flutter_test/flutter_test.dart';
import 'package:scholesa_app/domain/models.dart';

void main() {
  group('CheckpointModel', () {
    test('toMap contains all required fields', () {
      const CheckpointModel m = CheckpointModel(
        id: 'cp1',
        missionId: 'mission1',
        learnerId: 'learner1',
        siteId: 'site1',
        question: 'What is 2+2?',
        learnerResponse: '4',
        isCorrect: true,
        explainItBackRequired: true,
        score: 10,
      );

      final Map<String, dynamic> map = m.toMap();
      expect(map['missionId'], 'mission1');
      expect(map['learnerId'], 'learner1');
      expect(map['siteId'], 'site1');
      expect(map['question'], 'What is 2+2?');
      expect(map['learnerResponse'], '4');
      expect(map['isCorrect'], true);
      expect(map['explainItBackRequired'], true);
      expect(map['score'], 10);
      expect(map['createdAt'], isNotNull);
    });

    test('default values are correct', () {
      const CheckpointModel m = CheckpointModel(
        id: 'cp1',
        missionId: 'm1',
        learnerId: 'l1',
        siteId: 's1',
        question: 'q',
        learnerResponse: 'r',
      );
      expect(m.isCorrect, false);
      expect(m.explainItBackRequired, false);
      expect(m.sessionId, isNull);
      expect(m.skillId, isNull);
      expect(m.educatorId, isNull);
      expect(m.score, isNull);
    });
  });

  group('ReflectionEntryModel', () {
    test('toMap contains all required fields', () {
      const ReflectionEntryModel m = ReflectionEntryModel(
        id: 'ref1',
        learnerId: 'learner1',
        siteId: 'site1',
        prompt: 'What did you learn?',
        response: 'I learned fractions.',
        engagementRating: 4,
        confidenceRating: 3,
      );

      final Map<String, dynamic> map = m.toMap();
      expect(map['learnerId'], 'learner1');
      expect(map['prompt'], 'What did you learn?');
      expect(map['response'], 'I learned fractions.');
      expect(map['engagementRating'], 4);
      expect(map['confidenceRating'], 3);
    });

    test('optional fields default to null', () {
      const ReflectionEntryModel m = ReflectionEntryModel(
        id: 'ref1',
        learnerId: 'l1',
        siteId: 's1',
        prompt: 'p',
        response: 'r',
      );
      expect(m.sessionId, isNull);
      expect(m.missionId, isNull);
      expect(m.engagementRating, isNull);
      expect(m.educatorNotes, isNull);
    });
  });

  group('SkillEvidenceModel', () {
    test('toMap contains evidence linkage', () {
      const SkillEvidenceModel m = SkillEvidenceModel(
        id: 'se1',
        learnerId: 'l1',
        skillId: 'skill1',
        capabilityId: 'cap1',
        evidenceType: 'artifact',
        evidenceRefId: 'artifact1',
        siteId: 'site1',
      );

      final Map<String, dynamic> map = m.toMap();
      expect(map['skillId'], 'skill1');
      expect(map['capabilityId'], 'cap1');
      expect(map['evidenceType'], 'artifact');
      expect(map['evidenceRefId'], 'artifact1');
    });
  });

  group('AICoachInteractionModel', () {
    test('toMap preserves explain-it-back guardrails', () {
      const AICoachInteractionModel m = AICoachInteractionModel(
        id: 'ai1',
        learnerId: 'l1',
        siteId: 's1',
        mode: 'verify',
        question: 'Is this correct?',
        response: 'Yes, because...',
        explainItBackRequired: true,
        explainItBackPassed: true,
        toolsUsed: <String>['calculator'],
        durationMs: 5000,
      );

      final Map<String, dynamic> map = m.toMap();
      expect(map['mode'], 'verify');
      expect(map['explainItBackRequired'], true);
      expect(map['explainItBackPassed'], true);
      expect(map['toolsUsed'], <String>['calculator']);
      expect(map['durationMs'], 5000);
    });

    test('default mode and tools', () {
      const AICoachInteractionModel m = AICoachInteractionModel(
        id: 'ai1',
        learnerId: 'l1',
        siteId: 's1',
        mode: 'hint',
        question: 'q',
        response: 'r',
      );
      expect(m.explainItBackRequired, false);
      expect(m.toolsUsed, isEmpty);
    });
  });

  group('PeerFeedbackModel', () {
    test('toMap contains peer review fields', () {
      const PeerFeedbackModel m = PeerFeedbackModel(
        id: 'pf1',
        fromLearnerId: 'from1',
        toLearnerId: 'to1',
        missionAttemptId: 'attempt1',
        rating: 4,
        strengths: 'Great explanation',
        suggestions: 'Add more detail',
        siteId: 'site1',
      );

      final Map<String, dynamic> map = m.toMap();
      expect(map['fromLearnerId'], 'from1');
      expect(map['toLearnerId'], 'to1');
      expect(map['missionAttemptId'], 'attempt1');
      expect(map['rating'], 4);
      expect(map['strengths'], 'Great explanation');
      expect(map['suggestions'], 'Add more detail');
    });
  });

  group('MicroSkillModel', () {
    test('toMap contains rubric levels', () {
      const MicroSkillModel m = MicroSkillModel(
        id: 'ms1',
        capabilityId: 'cap1',
        pillarCode: 'futureSkills',
        name: 'Problem Solving',
        description: 'Ability to solve complex problems',
        rubricLevels: <String, String>{
          'emerging': 'Can identify problems',
          'developing': 'Can propose solutions',
          'proficient': 'Can implement solutions',
          'advanced': 'Can evaluate and optimize solutions',
        },
      );

      final Map<String, dynamic> map = m.toMap();
      expect(map['pillarCode'], 'futureSkills');
      expect(map['rubricLevels'], hasLength(4));
      expect(map['rubricLevels']['emerging'], 'Can identify problems');
    });

    test('default rubricLevels is empty', () {
      const MicroSkillModel m = MicroSkillModel(
        id: 'ms1',
        capabilityId: 'c1',
        pillarCode: 'p1',
        name: 'n',
        description: 'd',
      );
      expect(m.rubricLevels, isEmpty);
    });
  });

  group('MissionVariantModel', () {
    test('toMap contains difficulty info', () {
      const MissionVariantModel m = MissionVariantModel(
        id: 'mv1',
        missionId: 'mission1',
        difficultyLevel: 'challenge',
        description: 'Advanced version',
        adjustedCheckpoints: <String>['cp1', 'cp2', 'cp3'],
        scaffolding: 'Extra hints provided',
      );

      final Map<String, dynamic> map = m.toMap();
      expect(map['difficultyLevel'], 'challenge');
      expect(map['adjustedCheckpoints'], hasLength(3));
      expect(map['scaffolding'], 'Extra hints provided');
    });
  });

  group('ShowcaseSubmissionModel', () {
    test('toMap contains visibility and approval', () {
      const ShowcaseSubmissionModel m = ShowcaseSubmissionModel(
        id: 'sc1',
        learnerId: 'l1',
        portfolioItemId: 'pi1',
        title: 'My Project',
        description: 'A great project',
        visibility: 'public',
        approvalStatus: 'approved',
        approvedBy: 'educator1',
      );

      final Map<String, dynamic> map = m.toMap();
      expect(map['visibility'], 'public');
      expect(map['approvalStatus'], 'approved');
      expect(map['approvedBy'], 'educator1');
    });

    test('defaults to school visibility and pending', () {
      const ShowcaseSubmissionModel m = ShowcaseSubmissionModel(
        id: 'sc1',
        learnerId: 'l1',
        portfolioItemId: 'pi1',
        title: 't',
        description: 'd',
      );
      expect(m.visibility, 'school');
      expect(m.approvalStatus, 'pending');
    });
  });

  group('WeeklyGoalModel', () {
    test('toMap contains goal fields', () {
      const WeeklyGoalModel m = WeeklyGoalModel(
        id: 'wg1',
        learnerId: 'l1',
        siteId: 's1',
        goalText: 'Complete 3 missions this week',
        targetCapabilityId: 'cap1',
        status: 'active',
      );

      final Map<String, dynamic> map = m.toMap();
      expect(map['goalText'], 'Complete 3 missions this week');
      expect(map['targetCapabilityId'], 'cap1');
      expect(map['status'], 'active');
    });

    test('status defaults to active', () {
      const WeeklyGoalModel m = WeeklyGoalModel(
        id: 'wg1',
        learnerId: 'l1',
        siteId: 's1',
        goalText: 'g',
      );
      expect(m.status, 'active');
    });
  });

  group('ProofOfLearningBundleModel', () {
    test('toMap contains all 3 verification methods', () {
      const ProofOfLearningBundleModel m = ProofOfLearningBundleModel(
        id: 'pol1',
        siteId: 'site1',
        learnerId: 'l1',
        portfolioItemId: 'pi1',
        capabilityId: 'cap1',
        hasExplainItBack: true,
        hasOralCheck: true,
        hasMiniRebuild: false,
        explainItBackExcerpt: 'Because gravity pulls objects...',
        oralCheckExcerpt: 'Learner explained orbital mechanics',
        verificationStatus: 'partial',
        version: 2,
      );

      final Map<String, dynamic> map = m.toMap();
      expect(map['hasExplainItBack'], true);
      expect(map['siteId'], 'site1');
      expect(map['hasOralCheck'], true);
      expect(map['hasMiniRebuild'], false);
      expect(map['verificationStatus'], 'partial');
      expect(map['version'], 2);
      expect(map['explainItBackExcerpt'], contains('gravity'));
    });

    test('defaults to missing verification', () {
      const ProofOfLearningBundleModel m = ProofOfLearningBundleModel(
        id: 'pol1',
        siteId: 'site1',
        learnerId: 'l1',
        portfolioItemId: 'pi1',
      );
      expect(m.hasExplainItBack, false);
      expect(m.hasOralCheck, false);
      expect(m.hasMiniRebuild, false);
      expect(m.verificationStatus, 'missing');
      expect(m.version, 1);
    });

    test('verified requires all three methods conceptually', () {
      const ProofOfLearningBundleModel m = ProofOfLearningBundleModel(
        id: 'pol1',
        siteId: 'site1',
        learnerId: 'l1',
        portfolioItemId: 'pi1',
        hasExplainItBack: true,
        hasOralCheck: true,
        hasMiniRebuild: true,
        verificationStatus: 'verified',
      );
      expect(m.hasExplainItBack && m.hasOralCheck && m.hasMiniRebuild, true);
      expect(m.verificationStatus, 'verified');
    });
  });
}
