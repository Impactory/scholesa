import 'package:flutter_test/flutter_test.dart';
import 'package:scholesa_app/domain/repositories.dart';

/// Tests that evidence chain repository classes exist and can be instantiated.
/// Actual Firestore integration is tested via emulator (test:integration:rules).
void main() {
  group('Evidence chain repositories exist', () {
    test('CheckpointRepository is constructible', () {
      expect(CheckpointRepository(), isA<CheckpointRepository>());
    });

    test('SkillEvidenceRepository is constructible', () {
      expect(SkillEvidenceRepository(), isA<SkillEvidenceRepository>());
    });

    test('AICoachInteractionRepository is constructible', () {
      expect(
          AICoachInteractionRepository(), isA<AICoachInteractionRepository>());
    });

    test('PeerFeedbackRepository is constructible', () {
      expect(PeerFeedbackRepository(), isA<PeerFeedbackRepository>());
    });

    test('ProofOfLearningBundleRepository is constructible', () {
      expect(ProofOfLearningBundleRepository(),
          isA<ProofOfLearningBundleRepository>());
    });

    test('RubricApplicationRepository is constructible', () {
      expect(
          RubricApplicationRepository(), isA<RubricApplicationRepository>());
    });

    test('EvidenceRecordRepository is constructible', () {
      expect(EvidenceRecordRepository(), isA<EvidenceRecordRepository>());
    });

    test('ShowcaseSubmissionRepository is constructible', () {
      expect(ShowcaseSubmissionRepository(),
          isA<ShowcaseSubmissionRepository>());
    });
  });
}
