import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholesa_app/runtime/bos_models.dart';
import 'package:scholesa_app/runtime/learning_runtime_provider.dart';

void main() {
  group('LearningRuntimeProvider', () {
    test('hydrates orchestration state and active MVL from Firestore',
        () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      final DateTime now = DateTime.now();

      await firestore
          .collection('orchestrationStates')
          .doc('learner-1_occ-1')
          .set(<String, dynamic>{
        'siteId': 'site-1',
        'learnerId': 'learner-1',
        'sessionOccurrenceId': 'occ-1',
        'x_hat': <String, dynamic>{
          'cognition': 0.62,
          'engagement': 0.57,
          'integrity': 0.81,
        },
        'P': <String, dynamic>{
          'diag': <double>[0.2, 0.19, 0.18],
          'trace': 0.57,
          'confidence': 0.81,
        },
        'model': <String, dynamic>{
          'estimator': 'ema-state-estimator',
          'version': '0.1.0',
          'Q_version': 'v1',
          'R_version': 'v1',
        },
        'fusion': <String, dynamic>{
          'familiesPresent': <String>['interaction', 'voice_understanding'],
          'sensorFusionMet': true,
        },
        'lastUpdatedAt': Timestamp.fromDate(now),
      });

      await firestore
          .collection('mvlEpisodes')
          .doc('mvl-1')
          .set(<String, dynamic>{
        'siteId': 'site-1',
        'learnerId': 'learner-1',
        'sessionOccurrenceId': 'occ-1',
        'triggerReason': 'integrity_threshold',
        'resolution': null,
        'createdAt': Timestamp.fromDate(now),
      });

      final LearningRuntimeProvider provider = LearningRuntimeProvider(
        siteId: 'site-1',
        learnerId: 'learner-1',
        sessionOccurrenceId: 'occ-1',
        gradeBand: GradeBand.g4_6,
        firestore: firestore,
      );
      addTearDown(provider.dispose);

      provider.startListening();
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(provider.state, isNotNull);
      expect(provider.cognition, closeTo(0.62, 0.0001));
      expect(provider.engagement, closeTo(0.57, 0.0001));
      expect(provider.integrity, closeTo(0.81, 0.0001));
      expect(provider.confidence, closeTo(0.81, 0.0001));
      expect(provider.hasMvlGate, isTrue);
      expect(provider.activeMvl, isNotNull);
      expect(provider.activeMvl!.triggerReason, 'integrity_threshold');
      expect(provider.stateStatus, LearningRuntimeStateStatus.ready);
      expect(provider.stateLoadIssue, isNull);
    });

    test('marks malformed orchestration state instead of fabricating values',
        () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();

      await firestore
          .collection('orchestrationStates')
          .doc('learner-1_occ-1')
          .set(<String, dynamic>{
        'siteId': 'site-1',
        'learnerId': 'learner-1',
        'sessionOccurrenceId': 'occ-1',
        'x_hat': <String, dynamic>{
          'cognition': 0.62,
          'engagement': 0.57,
        },
        'P': <String, dynamic>{
          'trace': 0.57,
        },
      });

      final LearningRuntimeProvider provider = LearningRuntimeProvider(
        siteId: 'site-1',
        learnerId: 'learner-1',
        sessionOccurrenceId: 'occ-1',
        gradeBand: GradeBand.g4_6,
        firestore: firestore,
      );
      addTearDown(provider.dispose);

      provider.startListening();
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(provider.state, isNull);
      expect(provider.cognition, isNull);
      expect(provider.confidence, isNull);
      expect(provider.stateStatus, LearningRuntimeStateStatus.malformed);
      expect(provider.stateLoadIssue, 'malformed_orchestration_state');
    });

    test('ignores malformed active MVL documents instead of fabricating ids',
        () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      final DateTime now = DateTime.now();

      await firestore
          .collection('mvlEpisodes')
          .doc('mvl-1')
          .set(<String, dynamic>{
        'siteId': 'site-1',
        'learnerId': 'learner-1',
        'resolution': null,
        'createdAt': Timestamp.fromDate(now),
      });

      final LearningRuntimeProvider provider = LearningRuntimeProvider(
        siteId: 'site-1',
        learnerId: 'learner-1',
        sessionOccurrenceId: 'occ-1',
        gradeBand: GradeBand.g4_6,
        firestore: firestore,
      );
      addTearDown(provider.dispose);

      provider.startListening();
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(provider.hasMvlGate, isFalse);
      expect(provider.activeMvl, isNull);
    });

    test('hydrates learner-level active MVL without session occurrence linkage',
        () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      final DateTime now = DateTime.now();

      await firestore.collection('mvlEpisodes').doc('mvl-1').set(
        <String, dynamic>{
          'siteId': 'site-1',
          'learnerId': 'learner-1',
          'sessionOccurrenceId': null,
          'triggerReason': 'verification_gap',
          'resolution': null,
          'createdAt': Timestamp.fromDate(now),
        },
      );

      final LearningRuntimeProvider provider = LearningRuntimeProvider(
        siteId: 'site-1',
        learnerId: 'learner-1',
        gradeBand: GradeBand.g4_6,
        firestore: firestore,
      );
      addTearDown(provider.dispose);

      provider.startListening();
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(provider.hasMvlGate, isTrue);
      expect(provider.activeMvl, isNotNull);
      expect(provider.activeMvl!.sessionOccurrenceId, isEmpty);
      expect(provider.activeMvl!.triggerReason, 'verification_gap');
    });
  });
}
