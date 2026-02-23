import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholesa_app/modules/educator/educator_mission_plans_page.dart';
import 'package:scholesa_app/modules/site/site_sessions_page.dart';

void main() {
  group('CTA reflection regressions', () {
    testWidgets('site sessions create reflects immediately in list',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1600));

      await tester.pumpWidget(
        const MaterialApp(
          home: SiteSessionsPage(),
        ),
      );

      await tester.tap(find.text('New Session'));
      await tester.pumpAndSettle();

      const String title = 'CTA Reflection Session';
      await tester.enterText(
        find.widgetWithText(TextField, 'Session Title'),
        title,
      );

      final Finder createButton =
          find.widgetWithText(ElevatedButton, 'Create Session');
      await tester.ensureVisible(createButton);
      await tester.tap(createButton);
      await tester.pumpAndSettle();

      expect(find.text(title), findsOneWidget);
      expect(find.text('Session created successfully'), findsOneWidget);
    });

    testWidgets('mission plans create reflects immediately in list',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1600));

      await tester.pumpWidget(
        const MaterialApp(
          home: EducatorMissionPlansPage(),
        ),
      );

      await tester.tap(find.text('New Mission'));
      await tester.pumpAndSettle();

      const String missionTitle = 'CTA Reflection Mission';
      await tester.enterText(
        find.widgetWithText(TextField, 'Mission Title'),
        missionTitle,
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Create'));
      await tester.pumpAndSettle();

      expect(find.text(missionTitle), findsOneWidget);
      expect(find.text('Mission created and added to list'), findsOneWidget);
    });
  });
}
