import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholesa_app/ui/theme/scholesa_theme.dart';

void main() {
  test('native theme uses the current Gold evidence palette', () {
    final ThemeData light = ScholesaTheme.light;
    final ThemeData dark = ScholesaTheme.dark;

    expect(ScholesaColors.learner, const Color(0xFF0F96C3));
    expect(ScholesaColors.educator, const Color(0xFF1EA569));
    expect(ScholesaColors.parent, const Color(0xFF006969));
    expect(ScholesaColors.site, const Color(0xFFF0C31E));
    expect(ScholesaColors.hq, const Color(0xFFF0695A));
    expect(ScholesaColors.partner, const Color(0xFFF0963C));

    expect(light.colorScheme.primary, const Color(0xFF0F96C3));
    expect(light.colorScheme.secondary, const Color(0xFF1EA569));
    expect(light.colorScheme.tertiary, const Color(0xFFF0963C));
    expect(light.scaffoldBackgroundColor, const Color(0xFFF7FAFC));

    expect(dark.colorScheme.primary, const Color(0xFF0F96C3));
    expect(dark.colorScheme.secondary, const Color(0xFF1EA569));
    expect(dark.colorScheme.tertiary, const Color(0xFFF0C31E));
    expect(dark.scaffoldBackgroundColor, const Color(0xFF061A2A));
  });
}
