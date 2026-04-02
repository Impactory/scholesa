import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AI Help runtime honesty wording', () {
    final String bosServiceSource =
        File('lib/runtime/bos_service.dart').readAsStringSync();
    final String bosModelsSource =
        File('lib/runtime/bos_models.dart').readAsStringSync();
    final String voiceRuntimeSource =
        File('lib/runtime/voice_runtime_service.dart').readAsStringSync();
    final String coachWidgetSource =
        File('lib/runtime/ai_coach_widget.dart').readAsStringSync();
    final String overlaySource =
        File('lib/runtime/global_ai_assistant_overlay.dart').readAsStringSync();

    test(
        'keeps runtime exception text aligned to AI Help and voice help wording',
        () {
      expect(bosServiceSource, contains('Malformed AI Help payload.'));
      expect(bosModelsSource, contains('Malformed AI Help response payload.'));
      expect(voiceRuntimeSource, contains('Sign in to use MiloOS by voice.'));
      expect(
        voiceRuntimeSource,
        contains('Sign-in could not be confirmed for MiloOS voice support.'),
      );
      expect(
        voiceRuntimeSource,
        contains('Voice help is unavailable right now ('),
      );
      expect(
        voiceRuntimeSource,
        contains('Audio recording is unavailable for transcription.'),
      );
      expect(
        voiceRuntimeSource,
        contains('Voice transcription is unavailable right now ('),
      );
    });

    test(
      'removes legacy assistant identity wording from runtime prompt and errors',
        () {
      expect(coachWidgetSource,
          contains('You are MiloOS in a live spoken conversation.'));
      expect(
          coachWidgetSource,
          contains(
              'runtimeLoop: Stay in the live spoken support loop and improve support for this specific learner over time.'));
      expect(coachWidgetSource, contains("'aiHelpLoop': true"));
      expect(coachWidgetSource, contains("'ai_help_loop'"));
      expect(
        coachWidgetSource,
        contains('MiloOS request failed, returning safe escalation: \$e'),
      );

      expect(bosServiceSource, isNot(contains('Malformed AI coach payload.')));
      expect(bosModelsSource,
          isNot(contains('Malformed AI coach response payload.')));
      expect(
          voiceRuntimeSource,
          isNot(
              contains('Authentication required for voice runtime request.')));
      expect(
          voiceRuntimeSource,
          isNot(contains(
              'Unable to resolve auth token for voice runtime request.')));
      expect(voiceRuntimeSource, isNot(contains('Voice API error')));
      expect(voiceRuntimeSource, isNot(contains('Voice transcribe error')));
      expect(coachWidgetSource,
          isNot(contains('You are Scholesa AI Coach in a live conversation.')));
      expect(coachWidgetSource,
          isNot(contains('MiloOS closed-loop coaching runtime')));
        expect(coachWidgetSource, isNot(contains("'miloosLoop': true")));
        expect(coachWidgetSource, isNot(contains("'miloos_loop'")));

      expect(
          overlaySource, contains("AppStrings.of(context, 'assistant.title')"));
      expect(overlaySource,
          contains("AppStrings.of(context, 'assistant.tooltip')"));
      expect(overlaySource,
          contains("AppStrings.of(context, 'assistant.hoverHint')"));
        expect(overlaySource, contains("event: 'assistant.open.failed'"));
        expect(overlaySource, contains("'cta': 'global_ai_assistant_open'"));
        expect(overlaySource, contains("'source': 'global_ai_assistant_open'"));
        expect(overlaySource, contains("'cta': 'global_ai_assistant_close'"));
      expect(overlaySource, isNot(contains('AI Coach')));
      expect(overlaySource, isNot(contains('MiloOS')));
      expect(overlaySource, isNot(contains('Voice API')));
        expect(coachWidgetSource,
          isNot(contains('AI request failed, returning safe escalation:')));
    });
  });
}
