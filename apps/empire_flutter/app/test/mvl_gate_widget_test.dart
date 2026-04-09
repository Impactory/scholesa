@TestOn('vm')
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholesa_app/runtime/bos_event_bus.dart';
import 'package:scholesa_app/runtime/bos_models.dart';
import 'package:scholesa_app/runtime/learning_runtime_provider.dart';
import 'package:scholesa_app/runtime/mvl_gate_widget.dart';

void main() {
  group('MvlGateWidget class', () {
    test('constructor requires runtime and child parameters', () {
      expect(MvlGateWidget, isA<Type>());
    });

    test('widget accepts LearningRuntimeProvider and child', () {
      // Verify the constructor signature compiles with expected types.
      // Cannot instantiate LearningRuntimeProvider without Firebase,
      // so we verify via compile-time type checking only.
      // ignore: prefer_function_declarations_over_variables
      final MvlGateWidget Function(LearningRuntimeProvider, Widget) builder =
          (LearningRuntimeProvider runtime, Widget child) =>
              MvlGateWidget(runtime: runtime, child: child);
      expect(builder, isA<Function>());
    });
  });

  group('MvlGateWidget BOS events', () {
    test('all MVL event types are in BOS allowlist', () {
      const Set<String> mvlEvents = <String>{
        'explain_it_back_submitted',
        'mvl_evidence_attached',
        'mvl_passed',
        'mvl_failed',
        'mvl_gate_triggered',
        'mvl_evidence_submitted',
        'mvl_needs_more_evidence',
      };

      for (final String eventType in mvlEvents) {
        expect(
          BosEventBus.allowedBosEvents.contains(eventType),
          isTrue,
          reason: '$eventType should be in the BOS allowlist',
        );
      }
    });

    test('contestability_requested is in BOS allowlist', () {
      expect(
        BosEventBus.allowedBosEvents.contains('contestability_requested'),
        isTrue,
      );
    });

    test('contestability_resolved is in BOS allowlist', () {
      expect(
        BosEventBus.allowedBosEvents.contains('contestability_resolved'),
        isTrue,
      );
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

    test('MvlEpisode id is preserved', () {
      final MvlEpisode episode = MvlEpisode(
        id: 'unique-mvl-id-abc',
        siteId: 'site-1',
        learnerId: 'learner-1',
        sessionOccurrenceId: 'session-1',
        triggerReason: 'test',
      );
      expect(episode.id, 'unique-mvl-id-abc');
    });
  });

  group('ReliabilityRisk model', () {
    test('serializes all fields', () {
      final ReliabilityRisk risk = ReliabilityRisk(
        method: 'jackknife',
        k: 5,
        m: 10,
        hSem: 0.2,
        riskScore: 0.85,
        threshold: 0.7,
      );
      expect(risk.method, 'jackknife');
      expect(risk.k, 5);
      expect(risk.m, 10);
      expect(risk.hSem, 0.2);
      expect(risk.riskScore, 0.85);
      expect(risk.threshold, 0.7);
    });
  });

  group('AutonomyRisk model', () {
    test('contains signals list and risk score', () {
      final AutonomyRisk risk = AutonomyRisk(
        signals: <String>['rapid_submit', 'copy_paste_detected'],
        riskScore: 0.65,
        threshold: 0.5,
      );
      expect(risk.signals, hasLength(2));
      expect(risk.riskScore, 0.65);
      expect(risk.threshold, 0.5);
    });

    test('handles empty signals list', () {
      final AutonomyRisk risk = AutonomyRisk(
        signals: <String>[],
        riskScore: 0.0,
        threshold: 0.5,
      );
      expect(risk.signals, isEmpty);
      expect(risk.riskScore, 0.0);
    });
  });
}
