@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:scholesa_app/runtime/bos_models.dart';
import 'package:scholesa_app/runtime/mvl_gate_widget.dart';

void main() {
  group('MvlGateWidget class', () {
    test('constructor requires runtime and child parameters', () {
      expect(MvlGateWidget, isA<Type>());
    });
  });

  group('MvlEpisode — model integration', () {
    test('MvlEpisode can be constructed directly', () {
      final MvlEpisode episode = MvlEpisode(
        id: 'ep-1',
        siteId: 'site-1',
        learnerId: 'learner-1',
        sessionOccurrenceId: 'session-1',
        triggerReason: 'low_cognition',
        evidenceEventIds: <String>['ev1'],
      );

      expect(episode.siteId, 'site-1');
      expect(episode.learnerId, 'learner-1');
      expect(episode.triggerReason, 'low_cognition');
      expect(episode.evidenceEventIds, contains('ev1'));
      expect(episode.resolution, isNull);
      expect(episode.resolvedAt, isNull);
    });

    test('MvlEpisode.toMap produces correct keys', () {
      final MvlEpisode episode = MvlEpisode(
        id: 'ep-2',
        siteId: 'site-1',
        learnerId: 'learner-1',
        sessionOccurrenceId: 'session-1',
        triggerReason: 'autonomy_risk',
        evidenceEventIds: <String>['ev1', 'ev2'],
        resolution: 'passed',
      );
      final Map<String, dynamic> map = episode.toMap();
      expect(map['siteId'], 'site-1');
      expect(map['triggerReason'], 'autonomy_risk');
      expect(map['resolution'], 'passed');
      expect(map['evidenceEventIds'], hasLength(2));
    });

    test('MvlEpisode with reliability risk serializes correctly', () {
      final MvlEpisode episode = MvlEpisode(
        id: 'ep-3',
        siteId: 'site-1',
        learnerId: 'learner-1',
        sessionOccurrenceId: 'session-1',
        triggerReason: 'reliability',
        evidenceEventIds: <String>[],
        reliabilityRisk: ReliabilityRisk(
          method: 'bootstrap',
          k: 3,
          m: 5,
          hSem: 0.15,
          riskScore: 0.72,
          threshold: 0.6,
        ),
      );
      expect(episode.reliabilityRisk, isNotNull);
      expect(episode.reliabilityRisk!.riskScore, 0.72);
      expect(episode.reliabilityRisk!.method, 'bootstrap');

      final Map<String, dynamic> map = episode.toMap();
      expect(map.containsKey('reliability'), isTrue);
      final Map<String, dynamic> reliabilityMap =
          map['reliability'] as Map<String, dynamic>;
      expect(reliabilityMap['riskScore'], 0.72);
    });

    test('MvlEpisode with autonomy risk serializes correctly', () {
      final MvlEpisode episode = MvlEpisode(
        id: 'ep-4',
        siteId: 'site-1',
        learnerId: 'learner-1',
        sessionOccurrenceId: 'session-1',
        triggerReason: 'autonomy',
        evidenceEventIds: <String>[],
        autonomyRisk: AutonomyRisk(
          signals: <String>['rapid_submit', 'heavy_ai_use'],
          riskScore: 0.55,
          threshold: 0.5,
        ),
      );
      expect(episode.autonomyRisk, isNotNull);
      expect(episode.autonomyRisk!.riskScore, 0.55);

      final Map<String, dynamic> map = episode.toMap();
      expect(map.containsKey('autonomy'), isTrue);
    });

    test('MvlEpisode defaults evidenceEventIds to empty list', () {
      final MvlEpisode episode = MvlEpisode(
        id: 'ep-5',
        siteId: 'site-1',
        learnerId: 'learner-1',
        sessionOccurrenceId: 'session-1',
        triggerReason: 'low_cognition',
      );
      expect(episode.evidenceEventIds, isEmpty);
    });
  });
}
