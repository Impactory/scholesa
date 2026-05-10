import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// WASM-compatible bridge to the browser Web Speech API.
///
/// Provides [WebSpeechRecognition] for STT and [WebSpeechSynthesis] for TTS
/// using `dart:js_interop` + `package:web` (no legacy `dart:js` or `dart:html`).

// ─── SpeechRecognition JS Interop ───────────────────────

extension type _JsSpeechRecognition._(JSObject _) implements JSObject {
  external set continuous(bool value);
  external set interimResults(bool value);
  external set lang(String value);
  external set maxAlternatives(int value);

  external set onresult(JSFunction? handler);
  external set onerror(JSFunction? handler);
  external set onend(JSFunction? handler);

  external void start();
  external void stop();
  external void abort();
}

extension type _JsSpeechRecognitionEvent._(JSObject _) implements JSObject {
  external _JsSpeechRecognitionResultList get results;
  external int get resultIndex;
}

extension type _JsSpeechRecognitionResultList._(JSObject _)
    implements JSObject {
  external int get length;
  external _JsSpeechRecognitionResult item(int index);
}

extension type _JsSpeechRecognitionResult._(JSObject _) implements JSObject {
  external bool get isFinal;
  external _JsSpeechRecognitionAlternative item(int index);
  external int get length;
}

extension type _JsSpeechRecognitionAlternative._(JSObject _)
    implements JSObject {
  external String get transcript;
  external double get confidence;
}

extension type _JsSpeechRecognitionErrorEvent._(JSObject _)
    implements JSObject {
  external String get error;
  external String get message;
}

// ─── SpeechSynthesis JS Interop ─────────────────────────

extension type _JsSpeechSynthesisUtterance._(JSObject _) implements JSObject {
  external factory _JsSpeechSynthesisUtterance(String text);

  external set lang(String value);
  external set rate(double value);
  external set pitch(double value);
  external set volume(double value);
  external set voice(_JsSpeechSynthesisVoice? value);

  external set onend(JSFunction? handler);
  external set onerror(JSFunction? handler);
}

extension type _JsSpeechSynthesisVoice._(JSObject _) implements JSObject {
  external String get name;
  external String get lang;
  external bool get localService;
}

// ─── Helpers ────────────────────────────────────────────

/// Try to get a SpeechRecognition constructor from globalContext.
_JsSpeechRecognition? _createSpeechRecognition() {
  try {
    final JSAny? ctor =
        globalContext.getProperty('SpeechRecognition'.toJS);
    if (ctor != null && ctor.isA<JSFunction>()) {
      return (ctor as JSFunction).callAsConstructor<_JsSpeechRecognition>();
    }
  } catch (_) {}
  try {
    final JSAny? ctor =
        globalContext.getProperty('webkitSpeechRecognition'.toJS);
    if (ctor != null && ctor.isA<JSFunction>()) {
      return (ctor as JSFunction).callAsConstructor<_JsSpeechRecognition>();
    }
  } catch (_) {}
  return null;
}

bool _hasSpeechRecognition() {
  try {
    final JSAny? ctor =
        globalContext.getProperty('SpeechRecognition'.toJS);
    if (ctor != null && ctor.isA<JSFunction>()) return true;
  } catch (_) {}
  try {
    final JSAny? ctor =
        globalContext.getProperty('webkitSpeechRecognition'.toJS);
    if (ctor != null && ctor.isA<JSFunction>()) return true;
  } catch (_) {}
  return false;
}

// ─── WebSpeechRecognition (Dart API) ────────────────────

/// Browser-native speech recognition via the Web Speech API.
///
/// On Chrome/Edge/Safari this uses `SpeechRecognition`. On older WebKit
/// browsers it falls back to `webkitSpeechRecognition`.
class WebSpeechRecognition {
  _JsSpeechRecognition? _recognition;
  bool _active = false;

  void Function(String transcript, bool isFinal)? onResult;
  void Function(String error)? onError;
  void Function()? onEnd;

  /// Whether the browser supports the SpeechRecognition API.
  static bool get isSupported => _hasSpeechRecognition();

  /// Start streaming recognition in the given [locale] (e.g. 'en-US').
  void start({String locale = 'en-US'}) {
    if (_active) return;

    final _JsSpeechRecognition? recognition = _createSpeechRecognition();
    if (recognition == null) {
      onError?.call('not_supported');
      return;
    }

    recognition
      ..continuous = true
      ..interimResults = true
      ..lang = locale
      ..maxAlternatives = 1;

    recognition.onresult = ((JSObject event) {
      final _JsSpeechRecognitionEvent e =
          event as _JsSpeechRecognitionEvent;
      final StringBuffer transcript = StringBuffer();
      bool isFinal = false;
      for (int i = 0; i < e.results.length; i++) {
        final _JsSpeechRecognitionResult result = e.results.item(i);
        if (result.length > 0) {
          transcript.write(result.item(0).transcript);
          if (result.isFinal) isFinal = true;
        }
      }
      onResult?.call(transcript.toString(), isFinal);
    }).toJS;

    recognition.onerror = ((JSObject event) {
      final _JsSpeechRecognitionErrorEvent e =
          event as _JsSpeechRecognitionErrorEvent;
      onError?.call(e.error);
    }).toJS;

    recognition.onend = (() {
      _active = false;
      _recognition = null;
      onEnd?.call();
    }).toJS;

    _recognition = recognition;
    _active = true;
    recognition.start();
  }

  /// Stop recognition (waits for final result).
  void stop() {
    _recognition?.stop();
    _active = false;
  }

  /// Abort recognition immediately (no final result).
  void abort() {
    _recognition?.abort();
    _active = false;
    _recognition = null;
  }

  bool get isActive => _active;
}

// ─── WebSpeechSynthesis (Dart API) ──────────────────────

/// Browser-native text-to-speech via `window.speechSynthesis`.
class WebSpeechSynthesis {
  static bool get isSupported {
    try {
      final JSAny? synth =
          globalContext.getProperty('speechSynthesis'.toJS);
      return synth != null && synth.isA<JSObject>();
    } catch (_) {
      return false;
    }
  }

  /// Speak [text] in the given [locale]. Returns a [Future] that completes
  /// when the utterance finishes or errors.
  static Future<void> speak(
    String text, {
    String locale = 'en-US',
    double rate = 0.86,
    double pitch = 1.04,
    double volume = 1.0,
  }) {
    final Completer<void> completer = Completer<void>();

    final _JsSpeechSynthesisUtterance utterance =
        _JsSpeechSynthesisUtterance(text);
    utterance
      ..lang = locale
      ..rate = rate
      ..pitch = pitch
      ..volume = volume;

    // Try to pick a voice matching the locale.
    try {
      final List<web.SpeechSynthesisVoice> voices =
          web.window.speechSynthesis.getVoices().toDart;
      final String langPrefix =
          locale.contains('-') ? locale.split('-').first : locale;
      web.SpeechSynthesisVoice? fallbackVoice;
      for (final web.SpeechSynthesisVoice voice in voices) {
        final String voiceName = voice.name.toLowerCase();
        final bool preferredHumanVoice =
            voiceName.contains('natural') ||
                voiceName.contains('enhanced') ||
                voiceName.contains('premium') ||
                voiceName.contains('samantha') ||
                voiceName.contains('alex') ||
                voiceName.contains('daniel') ||
                voiceName.contains('google');
        if (voice.lang.startsWith(langPrefix) && preferredHumanVoice) {
          utterance.voice = voice as _JsSpeechSynthesisVoice;
          break;
        }
        if (fallbackVoice == null && voice.lang.startsWith(langPrefix)) {
          fallbackVoice = voice;
        }
      }
      if (fallbackVoice != null) {
        utterance.voice ??= fallbackVoice as _JsSpeechSynthesisVoice;
      }
    } catch (_) {
      // Voice selection is best-effort.
    }

    utterance.onend = (() {
      if (!completer.isCompleted) completer.complete();
    }).toJS;

    utterance.onerror = (() {
      if (!completer.isCompleted) {
        completer.completeError(Exception('Web TTS utterance failed'));
      }
    }).toJS;

    web.window.speechSynthesis.speak(utterance as web.SpeechSynthesisUtterance);
    return completer.future;
  }

  /// Cancel all pending utterances.
  static void cancel() {
    try {
      web.window.speechSynthesis.cancel();
    } catch (_) {
      // Best-effort.
    }
  }
}

/// Unlock the Web Audio context. Must be called from a user gesture handler.
Future<void> unlockWebAudioContext() async {
  try {
    final web.AudioContext ctx = web.AudioContext();
    await ctx.resume().toDart;
    ctx.close();
  } catch (_) {
    // Audio context unlock is best-effort.
  }
}
