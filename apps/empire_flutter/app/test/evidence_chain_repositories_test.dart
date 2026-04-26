import 'dart:io';

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
      expect(RubricApplicationRepository(), isA<RubricApplicationRepository>());
    });

    test('EvidenceRecordRepository is constructible', () {
      expect(EvidenceRecordRepository(), isA<EvidenceRecordRepository>());
    });

    test('ShowcaseSubmissionRepository is constructible', () {
      expect(
          ShowcaseSubmissionRepository(), isA<ShowcaseSubmissionRepository>());
    });
  });

  group('Server-owned interpretation repositories', () {
    final String source =
        File('lib/domain/repositories.dart').readAsStringSync();

    test('capability mastery repository is read-only for Flutter clients', () {
      final String section = _classSection(
        source,
        'class CapabilityMasteryRepository',
        'class CapabilityGrowthEventRepository',
      );

      expect(section, contains('capabilityMastery is server-owned'));
      expect(section, isNot(contains('.set(')));
    });

    test('capability growth event repository is read-only for Flutter clients',
        () {
      final String section = _classSection(
        source,
        'class CapabilityGrowthEventRepository',
        'class MissionRepository',
      );

      expect(section, contains('capabilityGrowthEvents are server-owned'));
      expect(section, isNot(contains('.set(')));
    });

    test('rubric application repository routes writes to callable boundary',
        () {
      final String section = _classSection(
        source,
        'class RubricApplicationRepository',
        'class IntegrationConnectionRepository',
      );

      expect(section, contains('rubricApplications are server-owned'));
      expect(section, contains('applyRubricToEvidence'));
      expect(section, isNot(contains('.set(')));
    });
  });
}

String _classSection(String source, String startToken, String endToken) {
  final int start = source.indexOf(startToken);
  final int end = source.indexOf(endToken, start + startToken.length);
  expect(start, isNonNegative);
  expect(end, isNonNegative);
  return source.substring(start, end);
}
