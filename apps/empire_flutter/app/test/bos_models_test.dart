import 'package:flutter_test/flutter_test.dart';
import 'package:scholesa_app/runtime/bos_models.dart';

void main() {
  group('XHat', () {
    test('default values are 0.5', () {
      const XHat x = XHat();
      expect(x.cognition, 0.5);
      expect(x.engagement, 0.5);
      expect(x.integrity, 0.5);
    });

    test('toMap / fromMap round-trip', () {
      const XHat original =
          XHat(cognition: 0.8, engagement: 0.3, integrity: 0.9);
      final XHat restored = XHat.fromMap(original.toMap());
      expect(restored.cognition, 0.8);
      expect(restored.engagement, 0.3);
      expect(restored.integrity, 0.9);
    });

    test('toVec returns 3D vector', () {
      const XHat x = XHat(cognition: 0.1, engagement: 0.2, integrity: 0.3);
      expect(x.toVec(), <double>[0.1, 0.2, 0.3]);
    });

    test('tryFromMap rejects incomplete values', () {
      expect(
        XHat.tryFromMap(<String, dynamic>{'cognition': 0.7, 'engagement': 0.4}),
        isNull,
      );
    });
  });

  group('CovarianceSummary', () {
    test('default posture resets to zero confidence', () {
      const CovarianceSummary p = CovarianceSummary();
      expect(p.confidence, 0.0);
      expect(p.trace, 3.0);
      expect(p.diag.length, 3);
      expect(p.diag, const <double>[1.0, 1.0, 1.0]);
    });

    test('toMap / fromMap round-trip', () {
      const CovarianceSummary original = CovarianceSummary(
        diag: <double>[0.1, 0.2, 0.3],
        trace: 0.6,
        confidence: 0.8,
      );
      final CovarianceSummary restored =
          CovarianceSummary.fromMap(original.toMap());
      expect(restored.trace, 0.6);
      expect(restored.confidence, 0.8);
    });

    test('tryFromMap derives confidence from trace without inventing defaults',
        () {
      final CovarianceSummary? restored = CovarianceSummary.tryFromMap(
        <String, dynamic>{
          'diag': <double>[0.1, 0.2, 0.3],
          'trace': 0.6
        },
      );
      expect(restored, isNotNull);
      expect(restored!.confidence, closeTo(0.8, 0.0001));
    });
  });

  group('OrchestrationState', () {
    test('tryFromMap rejects malformed state payloads', () {
      final OrchestrationState? restored = OrchestrationState.tryFromMap(
        <String, dynamic>{
          'siteId': 'site-1',
          'learnerId': 'learner-1',
          'sessionOccurrenceId': 'occ-1',
          'x_hat': <String, dynamic>{
            'cognition': 0.7,
            'engagement': 0.4,
          },
          'P': <String, dynamic>{'trace': 0.5},
        },
      );
      expect(restored, isNull);
    });
  });

  group('GradeBand', () {
    test('fromString parses all bands', () {
      expect(GradeBand.fromString('G1_3'), GradeBand.g1_3);
      expect(GradeBand.fromString('G4_6'), GradeBand.g4_6);
      expect(GradeBand.fromString('G7_9'), GradeBand.g7_9);
      expect(GradeBand.fromString('G10_12'), GradeBand.g10_12);
    });

    test('fromString is case-insensitive', () {
      expect(GradeBand.fromString('g1_3'), GradeBand.g1_3);
    });

    test('unknown defaults to g4_6', () {
      expect(GradeBand.fromString('UNKNOWN'), GradeBand.g4_6);
    });
  });

  group('GradeBandPolicy', () {
    test('M_DAGGER thresholds match spec', () {
      expect(GradeBandPolicy.mDagger[GradeBand.g1_3], 0.55);
      expect(GradeBandPolicy.mDagger[GradeBand.g4_6], 0.60);
      expect(GradeBandPolicy.mDagger[GradeBand.g7_9], 0.65);
      expect(GradeBandPolicy.mDagger[GradeBand.g10_12], 0.70);
    });

    test('autonomyCost is 0 for non-high-assist', () {
      const BosIntervention intervention = BosIntervention(
        type: InterventionType.nudge,
        salience: Salience.low,
      );
      final double cost = GradeBandPolicy.autonomyCost(
        intervention: intervention,
        xHat: const XHat(integrity: 0.3),
        gradeBand: GradeBand.g4_6,
      );
      expect(cost, 0.0);
    });

    test('autonomyCost positive when integrity < m_dagger for high-assist', () {
      const BosIntervention intervention = BosIntervention(
        type: InterventionType.scaffold,
        salience: Salience.high,
      );
      final double cost = GradeBandPolicy.autonomyCost(
        intervention: intervention,
        xHat: const XHat(integrity: 0.3),
        gradeBand: GradeBand.g7_9,
      );
      // m_dagger = 0.65, integrity = 0.3 → gap = 0.35
      expect(cost, closeTo(0.35, 0.001));
    });

    test('autonomyCost is 0 when integrity >= m_dagger', () {
      const BosIntervention intervention = BosIntervention(
        type: InterventionType.scaffold,
        salience: Salience.high,
      );
      final double cost = GradeBandPolicy.autonomyCost(
        intervention: intervention,
        xHat: const XHat(integrity: 0.8),
        gradeBand: GradeBand.g4_6,
      );
      expect(cost, 0.0);
    });
  });

  group('BosIntervention', () {
    test('toMap / fromMap round-trip', () {
      const BosIntervention intervention = BosIntervention(
        type: InterventionType.scaffold,
        salience: Salience.medium,
        mode: AiCoachMode.hint,
        reasonCodes: <String>['low_cognition'],
        policy: PolicyTerms(lambda: 0.5, mDagger: 0.6),
      );
      final BosIntervention restored =
          BosIntervention.fromMap(intervention.toMap());
      expect(restored.type, InterventionType.scaffold);
      expect(restored.salience, Salience.medium);
      expect(restored.mode, AiCoachMode.hint);
      expect(restored.reasonCodes, <String>['low_cognition']);
      expect(restored.policy?.mDagger, 0.6);
    });

    test('drops malformed policy payload instead of inventing defaults', () {
      final BosIntervention restored = BosIntervention.fromMap(
        <String, dynamic>{
          'type': 'scaffold',
          'salience': 'medium',
          'policy': <String, dynamic>{
            'lambda': 0.4,
          },
        },
      );

      expect(restored.policy, isNull);
    });
  });

  group('PolicyTerms', () {
    test('tryFromMap rejects incomplete policy payloads', () {
      expect(
        PolicyTerms.tryFromMap(<String, dynamic>{'lambda': 0.4}),
        isNull,
      );
    });

    test('fromMap throws on incomplete policy payloads', () {
      expect(
        () => PolicyTerms.fromMap(<String, dynamic>{'lambda': 0.4}),
        throwsFormatException,
      );
    });
  });

  group('ReliabilityRisk', () {
    test('default values', () {
      const ReliabilityRisk risk = ReliabilityRisk();
      expect(risk.method, 'sep');
      expect(risk.riskScore, 0.0);
      expect(risk.threshold, 0.5);
    });

    test('tryFromMap rejects missing inferential fields', () {
      expect(
        ReliabilityRisk.tryFromMap(<String, dynamic>{'method': 'sep'}),
        isNull,
      );
      expect(
        AutonomyRisk.tryFromMap(<String, dynamic>{
          'signals': <String>['rapid_submit']
        }),
        isNull,
      );
    });
  });

  group('AiCoachRequest', () {
    test('toMap includes context', () {
      const AiCoachRequest req = AiCoachRequest(
        siteId: 'site1',
        learnerId: 'learner1',
        gradeBand: GradeBand.g4_6,
        mode: AiCoachMode.explain,
        missionId: 'mission1',
        conceptTags: <String>['algebra', 'equations'],
      );
      final Map<String, dynamic> map = req.toMap();
      expect(map['mode'], 'explain');
      expect(map['gradeBand'], 'G4_6');
      expect((map['context'] as Map<String, dynamic>)['conceptTags'],
          <String>['algebra', 'equations']);
    });
  });

  group('BosEvent', () {
    test('toMap includes all required fields', () {
      final BosEvent event = BosEvent(
        eventType: 'mission_started',
        siteId: 'site1',
        actorId: 'user1',
        actorRole: 'learner',
        gradeBand: GradeBand.g4_6,
        missionId: 'mission1',
        payload: const <String, dynamic>{'foo': 'bar'},
      );
      final Map<String, dynamic> map = event.toMap();
      expect(map['eventType'], 'mission_started');
      expect(map['gradeBand'], 'G4_6');
      expect(map['missionId'], 'mission1');
      expect((map['payload'] as Map<String, dynamic>)['foo'], 'bar');
    });

    test('toMap includes research-grade envelope fields', () {
      final BosEvent event = BosEvent(
        eventType: 'checkpoint_submitted',
        siteId: 'site1',
        actorId: 'user1',
        actorRole: 'learner',
        gradeBand: GradeBand.g7_9,
        contextMode: ContextMode.inClass,
        actorIdPseudo: 'pseudo_abc123',
        assignmentId: 'assign1',
        lessonId: 'lesson1',
      );
      final Map<String, dynamic> map = event.toMap();

      // eventId is auto-generated UUID
      expect(map['eventId'], isNotNull);
      expect(map['eventId'], isA<String>());
      expect((map['eventId'] as String).length, greaterThanOrEqualTo(32));

      // schemaVersion
      expect(map['schemaVersion'], '2.0.0');

      // contextMode
      expect(map['contextMode'], 'in_class');

      // pseudonymised actor ID
      expect(map['actorIdPseudo'], 'pseudo_abc123');

      // assignment + lesson linking
      expect(map['assignmentId'], 'assign1');
      expect(map['lessonId'], 'lesson1');
    });

    test('eventId is unique per instance', () {
      final BosEvent e1 = BosEvent(
        eventType: 'test',
        siteId: 's',
        actorId: 'u',
        actorRole: 'learner',
        gradeBand: GradeBand.g4_6,
      );
      final BosEvent e2 = BosEvent(
        eventType: 'test',
        siteId: 's',
        actorId: 'u',
        actorRole: 'learner',
        gradeBand: GradeBand.g4_6,
      );
      expect(e1.eventId, isNot(equals(e2.eventId)));
    });

    test('ContextMode fromString parses all modes', () {
      expect(ContextMode.fromString('in_class'), ContextMode.inClass);
      expect(ContextMode.fromString('homework'), ContextMode.homework);
      expect(ContextMode.fromString('unknown'), ContextMode.unknown);
      expect(ContextMode.fromString('garbage'), ContextMode.unknown);
    });

    test('ClientInfo toMap produces correct structure', () {
      const ClientInfo info = ClientInfo(
        appVersion: '1.0.0-rc.2+2',
        platform: 'ios',
        buildNumber: '2',
      );
      final Map<String, dynamic> map = info.toMap();
      expect(map['appVersion'], '1.0.0-rc.2+2');
      expect(map['platform'], 'ios');
      expect(map['buildNumber'], '2');
    });
  });
}
