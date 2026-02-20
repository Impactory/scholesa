import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholesa_app/ui/auth/login_page.dart';
import 'package:scholesa_app/ui/landing/landing_page.dart';

Future<void> _pumpSized(
  WidgetTester tester, {
  required Size size,
  required Widget child,
  Duration settle = const Duration(milliseconds: 2000),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });

  await tester.pumpWidget(
    MaterialApp(
      home: child,
    ),
  );

  await tester.pumpAndSettle(settle);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UI Goldens', () {
    testWidgets('Landing page - mobile', (WidgetTester tester) async {
      await _pumpSized(
        tester,
        size: const Size(390, 844),
        child: const LandingPage(),
      );

      await expectLater(
        find.byType(LandingPage),
        matchesGoldenFile('goldens/landing_mobile.png'),
      );
    });

    testWidgets('Landing page - desktop', (WidgetTester tester) async {
      await _pumpSized(
        tester,
        size: const Size(1280, 800),
        child: const LandingPage(),
      );

      await expectLater(
        find.byType(LandingPage),
        matchesGoldenFile('goldens/landing_desktop.png'),
      );
    });

    testWidgets('Login page - mobile', (WidgetTester tester) async {
      await _pumpSized(
        tester,
        size: const Size(390, 844),
        child: const LoginPage(),
      );

      await expectLater(
        find.byType(LoginPage),
        matchesGoldenFile('goldens/login_mobile.png'),
      );
    });

    testWidgets('Login page - desktop', (WidgetTester tester) async {
      await _pumpSized(
        tester,
        size: const Size(1280, 800),
        child: const LoginPage(),
      );

      await expectLater(
        find.byType(LoginPage),
        matchesGoldenFile('goldens/login_desktop.png'),
      );
    });
  });
}