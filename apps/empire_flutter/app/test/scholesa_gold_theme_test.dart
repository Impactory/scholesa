import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholesa_app/ui/theme/scholesa_theme.dart';

void main() {
  test('native theme uses the current Gold evidence palette', () {
    final ThemeData light = ScholesaTheme.light;
    final ThemeData dark = ScholesaTheme.dark;

    expect(ScholesaColors.learner, const Color(0xFF0E7490));
    expect(ScholesaColors.educator, const Color(0xFF059669));
    expect(ScholesaColors.parent, const Color(0xFF2563EB));
    expect(ScholesaColors.site, const Color(0xFFD97706));
    expect(ScholesaColors.hq, const Color(0xFFE11D48));
    expect(ScholesaColors.partner, const Color(0xFF4F46E5));

    expect(light.colorScheme.primary, const Color(0xFF0E7490));
    expect(light.colorScheme.secondary, const Color(0xFF059669));
    expect(light.colorScheme.tertiary, const Color(0xFFD97706));
    expect(light.scaffoldBackgroundColor, const Color(0xFFECFEFF));

    expect(dark.colorScheme.primary, const Color(0xFF67E8F9));
    expect(dark.colorScheme.secondary, const Color(0xFF6EE7B7));
    expect(dark.colorScheme.tertiary, const Color(0xFFFCD34D));
    expect(dark.scaffoldBackgroundColor, const Color(0xFF020617));
  });
}
