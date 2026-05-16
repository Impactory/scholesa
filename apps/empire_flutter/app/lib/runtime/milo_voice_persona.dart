import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class MiloVoicePersona {
  MiloVoicePersona._();

  static String languageTagFor(Locale locale) {
    final String languageCode = locale.languageCode.toLowerCase();
    final String countryCode = (locale.countryCode ?? '').toUpperCase();
    if (languageCode == 'zh') {
      return countryCode == 'TW' || countryCode == 'HK' || countryCode == 'MO'
          ? 'zh-TW'
          : 'zh-CN';
    }
    if (languageCode == 'th') {
      return 'th-TH';
    }
    return 'en-US';
  }

  static Future<void> configure(
    FlutterTts tts, {
    required Locale locale,
  }) async {
    final String languageTag = languageTagFor(locale);
    await _trySet(() => tts.setLanguage(languageTag));
    await _trySet(() => tts.setSpeechRate(kIsWeb ? 0.82 : 0.44));
    await _trySet(() => tts.setVolume(1.0));
    await _trySet(() => tts.setPitch(1.08));

    final Map<String, String>? voice = await _friendlyVoiceFor(tts, languageTag);
    if (voice != null) {
      await _trySet(() => tts.setVoice(voice));
    }
  }

  static Future<Map<String, String>?> _friendlyVoiceFor(
    FlutterTts tts,
    String languageTag,
  ) async {
    final Object? voices = await _tryGet(() => tts.getVoices);
    if (voices is! Iterable<dynamic>) {
      return null;
    }

    final String languagePrefix = languageTag.split('-').first.toLowerCase();
    final List<Map<String, String>> candidates = voices
        .whereType<Map<dynamic, dynamic>>()
        .map((Map<dynamic, dynamic> voice) => voice.map(
              (dynamic key, dynamic value) => MapEntry(
                key.toString(),
                value.toString(),
              ),
            ))
        .where((Map<String, String> voice) {
      final String locale =
          (voice['locale'] ?? voice['language'] ?? '').toLowerCase();
      return locale == languageTag.toLowerCase() ||
          locale.startsWith('$languagePrefix-') ||
          locale == languagePrefix;
    }).toList();

    if (candidates.isEmpty) {
      return null;
    }

    const List<String> warmVoiceHints = <String>[
      'female',
      'woman',
      'samantha',
      'karen',
      'victoria',
      'susan',
      'ava',
      'allison',
      'joanna',
      'serena',
      'mei',
      'ting',
      'yaoyao',
      'hanhan',
      'kanya',
      'narisa',
    ];

    for (final Map<String, String> voice in candidates) {
      final String haystack = voice.values.join(' ').toLowerCase();
      if (warmVoiceHints.any(haystack.contains)) {
        return voice;
      }
    }

    return candidates.first;
  }

  static Future<void> _trySet(Future<dynamic> Function() action) async {
    try {
      await action();
    } catch (_) {
      // Voice APIs vary by platform. Falling back is safer than blocking MiloOS.
    }
  }

  static Future<Object?> _tryGet(Future<dynamic> Function() action) async {
    try {
      return await action();
    } catch (_) {
      return null;
    }
  }
}