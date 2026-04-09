import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:scholesa_app/runtime/bos_service.dart';

void main() {
  final String source = File('lib/runtime/bos_service.dart').readAsStringSync();

  group('BosService singleton', () {
    test('instance returns the same object on multiple accesses', () {
      final BosService a = BosService.instance;
      final BosService b = BosService.instance;
      expect(identical(a, b), isTrue);
    });
  });

  group('BosService API surface — expected methods', () {
    test('ingestEvent', () {
      expect(source, contains('Future<void> ingestEvent(BosEvent event)'));
    });

    test('getIntervention', () {
      expect(source, contains('Future<BosIntervention?> getIntervention('));
    });

    test('scoreMvl', () {
      expect(source, contains('Future<String> scoreMvl('));
    });

    test('submitMvlEvidence', () {
      expect(source, contains('Future<void> submitMvlEvidence('));
    });

    test('teacherOverrideMvl', () {
      expect(source, contains('Future<void> teacherOverrideMvl('));
    });

    test('getClassInsights', () {
      expect(source, contains('Future<Map<String, dynamic>> getClassInsights('));
    });

    test('getLearnerLoopInsights', () {
      expect(
        source,
        contains('Future<Map<String, dynamic>> getLearnerLoopInsights('),
      );
    });

    test('requestContestability', () {
      expect(source, contains('Future<void> requestContestability('));
    });

    test('resolveContestability', () {
      expect(source, contains('Future<void> resolveContestability('));
    });

    test('submitExplainBack', () {
      expect(source, contains('Future<ExplainBackResult> submitExplainBack('));
    });
  });

  group('BosService — removed methods should NOT be present', () {
    test('callAiCoach is removed', () {
      expect(source, isNot(contains('callAiCoach')));
    });

    test('getOrchestrationState is removed', () {
      expect(source, isNot(contains('getOrchestrationState')));
    });
  });

  group('BosService — Firebase callable names', () {
    test('bosIngestEvent', () {
      expect(source, contains("'bosIngestEvent'"));
    });

    test('bosGetIntervention', () {
      expect(source, contains("'bosGetIntervention'"));
    });

    test('bosScoreMvl', () {
      expect(source, contains("'bosScoreMvl'"));
    });

    test('bosSubmitMvlEvidence', () {
      expect(source, contains("'bosSubmitMvlEvidence'"));
    });

    test('bosTeacherOverrideMvl', () {
      expect(source, contains("'bosTeacherOverrideMvl'"));
    });

    test('bosGetClassInsights', () {
      expect(source, contains("'bosGetClassInsights'"));
    });

    test('bosGetLearnerLoopInsights', () {
      expect(source, contains("'bosGetLearnerLoopInsights'"));
    });

    test('bosContestability', () {
      expect(source, contains("'bosContestability'"));
    });

    test('submitExplainBack', () {
      expect(source, contains("'submitExplainBack'"));
    });
  });

  group('BosService — internal helpers', () {
    test('_asStringDynamicMap helper is present', () {
      expect(source, contains('_asStringDynamicMap'));
    });
  });
}
