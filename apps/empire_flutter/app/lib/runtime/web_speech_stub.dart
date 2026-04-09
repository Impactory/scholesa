import 'dart:async';

/// Stub implementation for non-web platforms.
///
/// All methods throw [UnsupportedError] — on native platforms the
/// `speech_to_text` plugin and `flutter_tts` are used instead.

class WebSpeechRecognition {
  void Function(String transcript, bool isFinal)? onResult;
  void Function(String error)? onError;
  void Function()? onEnd;

  static bool get isSupported => false;

  void start({String locale = 'en-US'}) {
    throw UnsupportedError('WebSpeechRecognition is only available on web.');
  }

  void stop() {
    throw UnsupportedError('WebSpeechRecognition is only available on web.');
  }

  void abort() {
    throw UnsupportedError('WebSpeechRecognition is only available on web.');
  }

  bool get isActive => false;
}

class WebSpeechSynthesis {
  static bool get isSupported => false;

  static Future<void> speak(
    String text, {
    String locale = 'en-US',
    double rate = 0.9,
    double pitch = 1.0,
    double volume = 1.0,
  }) {
    throw UnsupportedError('WebSpeechSynthesis is only available on web.');
  }

  static void cancel() {
    throw UnsupportedError('WebSpeechSynthesis is only available on web.');
  }
}

Future<void> unlockWebAudioContext() async {
  // No-op on native platforms.
}
