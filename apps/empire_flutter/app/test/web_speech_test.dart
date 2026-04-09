import 'package:flutter_test/flutter_test.dart';
import 'package:scholesa_app/runtime/web_speech.dart';

void main() {
  group('WebSpeechRecognition (stub on non-web)', () {
    test('isSupported returns false on non-web platforms', () {
      expect(WebSpeechRecognition.isSupported, isFalse);
    });

    test('start throws UnsupportedError on non-web', () {
      final recognition = WebSpeechRecognition();
      expect(
        () => recognition.start(locale: 'en-US'),
        throwsUnsupportedError,
      );
    });

    test('stop throws UnsupportedError on non-web', () {
      final recognition = WebSpeechRecognition();
      expect(
        () => recognition.stop(),
        throwsUnsupportedError,
      );
    });

    test('abort throws UnsupportedError on non-web', () {
      final recognition = WebSpeechRecognition();
      expect(
        () => recognition.abort(),
        throwsUnsupportedError,
      );
    });

    test('isActive returns false on non-web', () {
      final recognition = WebSpeechRecognition();
      expect(recognition.isActive, isFalse);
    });

    test('callback properties can be set without error', () {
      final recognition = WebSpeechRecognition();
      recognition.onResult = (transcript, isFinal) {};
      recognition.onError = (error) {};
      recognition.onEnd = () {};
      // Should not throw — callbacks are settable even on stub.
    });
  });

  group('WebSpeechSynthesis (stub on non-web)', () {
    test('isSupported returns false on non-web platforms', () {
      expect(WebSpeechSynthesis.isSupported, isFalse);
    });

    test('speak throws UnsupportedError on non-web', () {
      expect(
        () => WebSpeechSynthesis.speak('Hello', locale: 'en-US'),
        throwsUnsupportedError,
      );
    });

    test('cancel throws UnsupportedError on non-web', () {
      expect(
        () => WebSpeechSynthesis.cancel(),
        throwsUnsupportedError,
      );
    });
  });

  group('unlockWebAudioContext (stub on non-web)', () {
    test('completes without error on non-web', () async {
      // Should be a no-op, not throw.
      await unlockWebAudioContext();
    });
  });
}
