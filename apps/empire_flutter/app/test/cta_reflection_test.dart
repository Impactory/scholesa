import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/modules/educator/educator_mission_plans_page.dart';
import 'package:scholesa_app/modules/educator/educator_service.dart';
import 'package:scholesa_app/modules/site/site_sessions_page.dart';
import 'package:scholesa_app/services/firestore_service.dart';

final ThemeData _testTheme = ThemeData(
  useMaterial3: true,
  splashFactory: InkRipple.splashFactory,
);

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

Future<void> _pumpMissionPlansPage(WidgetTester tester) async {
  final FirestoreService firestoreService = FirestoreService(
    firestore: FakeFirebaseFirestore(),
    auth: _MockFirebaseAuth(),
  );
  final EducatorService educatorService = EducatorService(
    firestoreService: firestoreService,
    educatorId: 'educator-test-1',
  );

  await tester.pumpWidget(
    MultiProvider(
      providers: <SingleChildWidget>[
        Provider<FirestoreService>.value(value: firestoreService),
        ChangeNotifierProvider<EducatorService>.value(value: educatorService),
      ],
      child: MaterialApp(
        theme: _testTheme,
        home: const EducatorMissionPlansPage(),
      ),
    ),
  );
}

void main() {
  group('CTA reflection regressions', () {
    testWidgets('site sessions create reflects immediately in list',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1600));

      await tester.pumpWidget(
        MaterialApp(
          theme: _testTheme,
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

      await _pumpMissionPlansPage(tester);
      await tester.pumpAndSettle();

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
