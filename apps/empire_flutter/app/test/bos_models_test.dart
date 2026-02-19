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
      const XHat original = XHat(cognition: 0.8, engagement: 0.3, integrity: 0.9);
      final XHat restored = XHat.fromMap(original.toMap());
      expect(restored.cognition, 0.8);
      expect(restored.engagement, 0.3);
      expect(restored.integrity, 0.9);
    });

    test('toVec returns 3D vector', () {
      const XHat x = XHat(cognition: 0.1, engagement: 0.2, integrity: 0.3);
      expect(x.toVec(), <double>[0.1, 0.2, 0.3]);
    });
  });

  group('CovarianceSummary', () {
    test('default confidence is 0.25', () {
      const CovarianceSummary p = CovarianceSummary();
      expect(p.confidence, 0.25);
      expect(p.trace, 0.75);
      expect(p.diag.length, 3);
    });

    test('toMap / fromMap round-trip', () {
      const CovarianceSummary original = CovarianceSummary(
        diag: <double>[0.1, 0.2, 0.3],
        trace: 0.6,
        confidence: 0.8,
      );
      final CovarianceSummary restored = CovarianceSummary.fromMap(original.toMap());
      expect(restored.trace, 0.6);
      expect(restored.confidence, 0.8);
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
      final BosIntervention restored = BosIntervention.fromMap(intervention.toMap());
      expect(restored.type, InterventionType.scaffold);
      expect(restored.salience, Salience.medium);
      expect(restored.mode, AiCoachMode.hint);
      expect(restored.reasonCodes, <String>['low_cognition']);
      expect(restored.policy?.mDagger, 0.6);
    });
  });

  group('ReliabilityRisk', () {
    test('default values', () {
      const ReliabilityRisk risk = ReliabilityRisk();
      expect(risk.method, 'sep');
      expect(risk.riskScore, 0.0);
      expect(risk.threshold, 0.5);
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
      expect((map['context'] as Map<String, dynamic>)['conceptTags'], <String>['algebra', 'equations']);
    });
  });

  group('BosEvent', () {
    test('toMap includes all required fields', () {
      const BosEvent event = BosEvent(
        eventType: 'mission_started',
        siteId: 'site1',
        actorId: 'user1',
        actorRole: 'learner',
        gradeBand: GradeBand.g4_6,
        missionId: 'mission1',
        payload: <String, dynamic>{'foo': 'bar'},
      );
      final Map<String, dynamic> map = event.toMap();
      expect(map['eventType'], 'mission_started');
      expect(map['gradeBand'], 'G4_6');
      expect(map['missionId'], 'mission1');
      expect((map['payload'] as Map<String, dynamic>)['foo'], 'bar');
    });
  });
}
