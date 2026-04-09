@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:scholesa_app/runtime/bos_models.dart';
import 'package:scholesa_app/runtime/voice_runtime_service.dart';

void main() {
  group('GradeBand enum', () {
    test('all four values exist', () {
      expect(GradeBand.values, hasLength(4));
      expect(GradeBand.values, containsAll(<GradeBand>[
        GradeBand.g1_3,
        GradeBand.g4_6,
        GradeBand.g7_9,
        GradeBand.g10_12,
      ]));
    });

    test('each GradeBand has a non-empty code', () {
      for (final GradeBand band in GradeBand.values) {
        expect(band.code, isNotEmpty, reason: '${band.name} should have a code');
      }
    });

    test('codes match BOS spec format (G prefix + underscored numbers)', () {
      expect(GradeBand.g1_3.code, 'G1_3');
      expect(GradeBand.g4_6.code, 'G4_6');
      expect(GradeBand.g7_9.code, 'G7_9');
      expect(GradeBand.g10_12.code, 'G10_12');
    });
  });

  group('GradeBand.fromString()', () {
    test('parses uppercase BOS codes', () {
      expect(GradeBand.fromString('G1_3'), GradeBand.g1_3);
      expect(GradeBand.fromString('G4_6'), GradeBand.g4_6);
      expect(GradeBand.fromString('G7_9'), GradeBand.g7_9);
      expect(GradeBand.fromString('G10_12'), GradeBand.g10_12);
    });

    test('parses lowercase BOS codes', () {
      expect(GradeBand.fromString('g1_3'), GradeBand.g1_3);
      expect(GradeBand.fromString('g4_6'), GradeBand.g4_6);
      expect(GradeBand.fromString('g7_9'), GradeBand.g7_9);
      expect(GradeBand.fromString('g10_12'), GradeBand.g10_12);
    });

    test('defaults to g4_6 for unknown strings', () {
      expect(GradeBand.fromString('unknown'), GradeBand.g4_6);
      expect(GradeBand.fromString(''), GradeBand.g4_6);
      expect(GradeBand.fromString('K-5'), GradeBand.g4_6);
    });
  });

  group('Voice API grade band format', () {
    test('VoiceCopilotRequest maps all GradeBand values to voice strings', () {
      // The voice backend expects 'K-5', '6-8', '9-12' format.
      // VoiceCopilotRequest._gradeBandForVoice handles the mapping.
      final Map<GradeBand, String> expected = <GradeBand, String>{
        GradeBand.g1_3: 'K-5',
        GradeBand.g4_6: 'K-5',
        GradeBand.g7_9: '6-8',
        GradeBand.g10_12: '9-12',
      };

      for (final MapEntry<GradeBand, String> entry in expected.entries) {
        final VoiceCopilotRequest request = VoiceCopilotRequest(
          message: 'test',
          locale: 'en',
          gradeBand: entry.key,
        );
        expect(
          request.toMap()['gradeBand'],
          entry.value,
          reason: '${entry.key} should map to voice format ${entry.value}',
        );
      }
    });

    test('g1_3 and g4_6 both map to K-5 (elementary band)', () {
      final VoiceCopilotRequest req1 = VoiceCopilotRequest(
        message: 'test',
        locale: 'en',
        gradeBand: GradeBand.g1_3,
      );
      final VoiceCopilotRequest req2 = VoiceCopilotRequest(
        message: 'test',
        locale: 'en',
        gradeBand: GradeBand.g4_6,
      );
      expect(req1.toMap()['gradeBand'], req2.toMap()['gradeBand']);
    });
  });

  group('Cross-layer format consistency', () {
    test('BOS code -> voice format covers all enum values', () {
      // Every GradeBand value must produce a valid voice string.
      const Set<String> validVoiceFormats = <String>{'K-5', '6-8', '9-12'};

      for (final GradeBand band in GradeBand.values) {
        final VoiceCopilotRequest request = VoiceCopilotRequest(
          message: 'test',
          locale: 'en',
          gradeBand: band,
        );
        final String voiceFormat =
            request.toMap()['gradeBand'] as String;
        expect(
          validVoiceFormats.contains(voiceFormat),
          isTrue,
          reason: '${band.name} produced "$voiceFormat" which is not a valid '
              'voice format. Expected one of: $validVoiceFormats',
        );
      }
    });

    test('BOS code round-trips through fromString', () {
      for (final GradeBand band in GradeBand.values) {
        final GradeBand roundTripped = GradeBand.fromString(band.code);
        expect(roundTripped, band,
            reason: '${band.code} should round-trip back to ${band.name}');
      }
    });

    test('BosEvent serializes gradeBand as code string', () {
      for (final GradeBand band in GradeBand.values) {
        final BosEvent event = BosEvent(
          eventType: 'mission_viewed',
          siteId: 'site-001',
          actorId: 'actor-001',
          actorRole: 'learner',
          gradeBand: band,
        );
        final Map<String, dynamic> map = event.toMap();
        expect(map['gradeBand'], band.code,
            reason: 'BosEvent.toMap() should use GradeBand.code for ${band.name}');
      }
    });
  });

  group('VoiceRuntimeService configuration', () {
    test('region default is us-central1', () {
      expect(VoiceRuntimeService.region, 'us-central1');
    });

    test('region is mutable for non-default deployments', () {
      final String original = VoiceRuntimeService.region;
      VoiceRuntimeService.region = 'europe-west1';
      expect(VoiceRuntimeService.region, 'europe-west1');
      // Restore original
      VoiceRuntimeService.region = original;
    });

    test('timeout default is 25 seconds', () {
      expect(VoiceRuntimeService.timeout, const Duration(seconds: 25));
    });

    test('timeout is mutable for custom configurations', () {
      final Duration original = VoiceRuntimeService.timeout;
      VoiceRuntimeService.timeout = const Duration(seconds: 60);
      expect(VoiceRuntimeService.timeout, const Duration(seconds: 60));
      // Restore original
      VoiceRuntimeService.timeout = original;
    });
  });
}
