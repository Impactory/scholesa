import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

class _MissionPlansHarness {
  const _MissionPlansHarness({
    required this.firestoreService,
    required this.educatorService,
  });

  final FirestoreService firestoreService;
  final EducatorService educatorService;
}

Future<_MissionPlansHarness> _pumpMissionPlansPage(WidgetTester tester) async {
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

  return _MissionPlansHarness(
    firestoreService: firestoreService,
    educatorService: educatorService,
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

    testWidgets(
        'mission plans persist evidence defaults and authored step order',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1800));

      final _MissionPlansHarness harness = await _pumpMissionPlansPage(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text('New Mission'));
      await tester.pumpAndSettle();

      const String missionTitle = 'Lesson Builder Mission';
      await tester.enterText(
        find.widgetWithText(TextField, 'Mission Title'),
        missionTitle,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Mission Description'),
        'Checks evidence defaults and step ordering.',
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('mission_step_down_0')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Create'));
      await tester.pumpAndSettle();

      final QuerySnapshot<Map<String, dynamic>> missions = await harness
          .firestoreService.firestore
          .collection('missions')
          .where('title', isEqualTo: missionTitle)
          .get();

      expect(missions.docs, hasLength(1));
      final Map<String, dynamic> missionData = missions.docs.single.data();
      expect(
        missionData['evidenceDefaults'],
        containsAll(<String>['explain_it_back', 'reflection_note']),
      );
      expect(
        missionData['lessonSteps'],
        <String>['Guided practice', 'Launch challenge', 'Evidence capture'],
      );

      final QuerySnapshot<Map<String, dynamic>> steps = await missions
          .docs.single.reference
          .collection('steps')
          .orderBy('order')
          .get();
      expect(
        steps.docs
            .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                doc.data()['title'])
            .toList(),
        <String>['Guided practice', 'Launch challenge', 'Evidence capture'],
      );
    });
  });
}
