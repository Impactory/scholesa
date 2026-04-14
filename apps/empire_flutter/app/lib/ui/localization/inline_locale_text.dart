import 'package:flutter/widgets.dart';
import '../../domain/curriculum/curriculum_display.g.dart';

typedef InlineTranslations = Map<String, String>;

class InlineLocaleText {
  InlineLocaleText._();

  static String of(
    BuildContext context,
    String input, {
    required InlineTranslations zhCn,
    required InlineTranslations zhTw,
    InlineTranslations es = const <String, String>{},
    InlineTranslations th = const <String, String>{},
  }) {
    final String locale = _canonicalLocale(Localizations.localeOf(context));
    final String translated;
    switch (locale) {
      case 'zh-CN':
        translated = zhCn[input] ?? zhTw[input] ?? input;
        break;
      case 'zh-TW':
        translated = zhTw[input] ?? zhCn[input] ?? input;
        break;
      case 'es':
        translated = es[input] ?? input;
        break;
      case 'th':
        translated = th[input] ?? input;
        break;
      default:
        translated = input;
        break;
    }
    return CurriculumDisplay.localizeDisplayText(
      input,
      locale,
      fallback: translated,
    );
  }

  static String canonicalLocale(Locale locale) => _canonicalLocale(locale);

  static String _canonicalLocale(Locale locale) {
    final String languageCode = locale.languageCode.toLowerCase();
    final String countryCode = (locale.countryCode ?? '').toUpperCase();
    if (languageCode == 'zh') {
      if (countryCode == 'TW' || countryCode == 'HK' || countryCode == 'MO') {
        return 'zh-TW';
      }
      return 'zh-CN';
    }
    if (languageCode == 'es') return 'es';
    if (languageCode == 'th') return 'th';
    return 'en';
  }
}
