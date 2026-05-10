import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:scholesa_app/runtime/bos_models.dart';
import 'package:scholesa_app/runtime/voice_runtime_service.dart';

void main() {
  group('VoiceRuntimeService', () {
    group('transcribeAudioBase64', () {
      test('throws when not authenticated', () async {
        // Without Firebase initialization, _requiredIdToken will throw.
        expect(
          () => VoiceRuntimeService.instance.transcribeAudioBase64(
            audioBytes: Uint8List.fromList(utf8.encode('test-audio')),
            mimeType: 'audio/webm;codecs=opus',
            locale: 'en-US',
          ),
          throwsException,
        );
      });
    });

    group('TranscribeVoiceResponse', () {
      test('constructs with required fields', () {
        const response = TranscribeVoiceResponse(
          transcript: 'Hello world',
          confidence: 0.95,
        );
        expect(response.transcript, 'Hello world');
        expect(response.confidence, 0.95);
        expect(response.traceId, isNull);
        expect(response.latencyMs, isNull);
        expect(response.modelVersion, isNull);
        expect(response.locale, isNull);
      });

      test('constructs with all fields', () {
        const response = TranscribeVoiceResponse(
          transcript: 'Test transcript',
          confidence: 0.87,
          traceId: 'trace-123',
          latencyMs: 450,
          modelVersion: 'whisper-v3',
          locale: 'en-US',
        );
        expect(response.transcript, 'Test transcript');
        expect(response.confidence, 0.87);
        expect(response.traceId, 'trace-123');
        expect(response.latencyMs, 450);
        expect(response.modelVersion, 'whisper-v3');
        expect(response.locale, 'en-US');
      });

      test('handles null confidence', () {
        const response = TranscribeVoiceResponse(
          transcript: 'No confidence',
          confidence: null,
        );
        expect(response.confidence, isNull);
      });
    });

    group('VoiceCopilotRequest', () {
      test('serializes to map correctly', () {
        const request = VoiceCopilotRequest(
          message: 'Help me understand',
          locale: 'en-US',
          gradeBand: GradeBand.g4_6,
        );
        final map = request.toMap();
        expect(map['message'], 'Help me understand');
        expect(map['locale'], 'en-US');
        expect(map['gradeBand'], 'K-5');
        expect(map['inputModality'], 'voice');
        expect(map['voice']['enabled'], true);
        expect(map['voice']['output'], true);
      });

      test('serializes typed learner modality alongside voice output settings',
          () {
        const request = VoiceCopilotRequest(
          message: 'How can I improve my portfolio evidence?',
          locale: 'en-US',
          gradeBand: GradeBand.g7_9,
          inputModality: 'typed',
          context: <String, dynamic>{
            'source': 'manual',
            'inputModality': 'typed',
          },
          voiceEnabled: true,
          voiceOutput: true,
        );

        final Map<String, dynamic> map = request.toMap();
        expect(map['inputModality'], 'typed');
        expect(map['context']['source'], 'manual');
        expect(map['context']['inputModality'], 'typed');
        expect(map['voice']['enabled'], true);
        expect(map['voice']['output'], true);
      });

      test('serializes grade bands correctly', () {
        for (final entry in <GradeBand, String>{
          GradeBand.g1_3: 'K-5',
          GradeBand.g4_6: 'K-5',
          GradeBand.g7_9: '6-8',
          GradeBand.g10_12: '9-12',
        }.entries) {
          final request = VoiceCopilotRequest(
            message: 'test',
            locale: 'en',
            gradeBand: entry.key,
          );
          expect(request.toMap()['gradeBand'], entry.value,
              reason: '${entry.key} should map to ${entry.value}');
        }
      });
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
      VoiceRuntimeService.region = original;
    });

    test('timeout default is 25 seconds', () {
      expect(VoiceRuntimeService.timeout, const Duration(seconds: 25));
    });

    test('timeout is mutable for custom configurations', () {
      final Duration original = VoiceRuntimeService.timeout;
      VoiceRuntimeService.timeout = const Duration(seconds: 60);
      expect(VoiceRuntimeService.timeout, const Duration(seconds: 60));
      VoiceRuntimeService.timeout = original;
    });
  });

  group('ExplainBackResult', () {
    test('constructs with approved = true', () {
      const result = ExplainBackResult(
        approved: true,
        feedback: 'Great explanation!',
      );
      expect(result.approved, isTrue);
      expect(result.feedback, 'Great explanation!');
    });

    test('constructs with approved = false', () {
      const result = ExplainBackResult(
        approved: false,
        feedback: 'Please try explaining in your own words.',
      );
      expect(result.approved, isFalse);
      expect(result.feedback, 'Please try explaining in your own words.');
    });
  });
}
