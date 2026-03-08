import 'package:flutter/widgets.dart';

typedef InlineTranslations = Map<String, String>;

class InlineLocaleText {
  InlineLocaleText._();

  static String of(
    BuildContext context,
    String input, {
    required InlineTranslations zhCn,
    required InlineTranslations zhTw,
  }) {
    switch (_canonicalLocale(Localizations.localeOf(context))) {
      case 'zh-CN':
        return zhCn[input] ?? zhTw[input] ?? input;
      case 'zh-TW':
        return zhTw[input] ?? zhCn[input] ?? input;
      default:
        return input;
    }
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
    return 'en';
  }
}