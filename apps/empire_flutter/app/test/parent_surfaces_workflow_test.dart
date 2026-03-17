import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/modules/parent/parent_billing_page.dart';
import 'package:scholesa_app/modules/parent/parent_portfolio_page.dart';
import 'package:scholesa_app/modules/parent/parent_schedule_page.dart';
import 'package:scholesa_app/modules/parent/parent_service.dart';
import 'package:scholesa_app/modules/parent/parent_summary_page.dart';
import 'package:scholesa_app/runtime/learning_runtime_provider.dart';
import 'package:scholesa_app/services/firestore_service.dart';

final ThemeData _workflowTheme = ThemeData(
  useMaterial3: true,
  splashFactory: InkRipple.splashFactory,
);

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

AppState _buildParentState() {
  final AppState state = AppState();
  state.updateFromMeResponse(<String, dynamic>{
    'userId': 'parent-1',
    'email': 'parent001.demo@scholesa.org',
    'displayName': 'Parent One',
    'role': 'parent',
    'activeSiteId': 'site-1',
    'siteIds': <String>['site-1'],
    'entitlements': <dynamic>[],
  });
  return state;
}

Future<void> _seedParentData(FakeFirebaseFirestore firestore) async {
  final DateTime now = DateTime.now();
  final DateTime anchor = DateTime(now.year, now.month, now.day, 12);
  await firestore.collection('users').doc('parent-1').set(<String, dynamic>{
    'role': 'parent',
    'displayName': 'Parent One',
    'learnerIds': <String>['learner-1'],
  });
  await firestore.collection('guardianLinks').doc('link-1').set(<String, dynamic>{
    'parentId': 'parent-1',
    'learnerId': 'learner-1',
  });
  await firestore.collection('users').doc('learner-1').set(<String, dynamic>{
    'role': 'learner',
    'displayName': 'Ava Learner',
  });
  await firestore.collection('users').doc('learner-2').set(<String, dynamic>{
    'role': 'learner',
    'displayName': 'Unaffiliated Learner',
    'parentIds': <String>['other-parent'],
  });
  await firestore.collection('learnerProgress').doc('learner-1').set(<String, dynamic>{
    'level': 4,
    'totalXp': 1200,
    'missionsCompleted': 5,
    'currentStreak': 7,
    'futureSkillsProgress': 0.8,
    'leadershipProgress': 0.6,
    'impactProgress': 0.4,
  });
  await firestore.collection('activities').doc('activity-1').set(<String, dynamic>{
    'learnerId': 'learner-1',
    'title': 'Build a Robot',
    'description': 'Linked Update',
    'type': 'mission',
    'emoji': '🤖',
    'timestamp': Timestamp.fromDate(anchor.subtract(const Duration(hours: 2))),
  });
  await firestore.collection('activities').doc('activity-2').set(<String, dynamic>{
    'learnerId': 'learner-2',
    'title': 'Hidden Project',
    'description': 'Hidden Update',
    'type': 'mission',
    'emoji': '🕶',
    'timestamp': Timestamp.fromDate(anchor.subtract(const Duration(hours: 1))),
  });
  await firestore.collection('events').doc('event-1').set(<String, dynamic>{
    'learnerId': 'learner-1',
    'title': 'Robotics Studio',
    'description': 'Prototype review',
    'dateTime': Timestamp.fromDate(now.add(const Duration(days: 1, hours: 1))),
    'type': 'future_skills',
    'location': 'Lab 1',
  });
  await firestore.collection('events').doc('event-2').set(<String, dynamic>{
    'learnerId': 'learner-2',
    'title': 'Hidden Session',
    'description': 'Should not appear',
    'dateTime': Timestamp.fromDate(now.add(const Duration(days: 1, hours: 2))),
    'type': 'future_skills',
    'location': 'Hidden Lab',
  });
  await firestore.collection('attendanceRecords').doc('attendance-1').set(<String, dynamic>{
    'learnerId': 'learner-1',
    'status': 'present',
    'recordedAt': Timestamp.fromDate(anchor.subtract(const Duration(days: 1))),
  });
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required FakeFirebaseFirestore firestore,
  required Widget home,
}) async {
  tester.view.physicalSize = const Size(1440, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final FirestoreService firestoreService = FirestoreService(
    firestore: firestore,
    auth: _MockFirebaseAuth(),
  );
  final ParentService parentService = ParentService(
    firestoreService: firestoreService,
    parentId: 'parent-1',
  );

  await tester.pumpWidget(
    MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<AppState>.value(value: _buildParentState()),
        Provider<FirestoreService>.value(value: firestoreService),
        ChangeNotifierProvider<ParentService>.value(value: parentService),
        Provider<LearningRuntimeProvider?>.value(value: null),
      ],
      child: MaterialApp(
        theme: _workflowTheme,
        supportedLocales: const <Locale>[
          Locale('en'),
          Locale('zh', 'CN'),
          Locale('zh', 'TW'),
        ],
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: home,
      ),
    ),
  );

  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

void main() {
  group('Parent surface workflows', () {
    testWidgets('summary page only renders linked learner activity',
        (WidgetTester tester) async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      await _seedParentData(firestore);

      await _pumpPage(
        tester,
        firestore: firestore,
        home: const ParentSummaryPage(),
      );

      expect(find.text('Ava Learner'), findsOneWidget);
      expect(find.text('Build a Robot'), findsOneWidget);
      expect(find.text('Hidden Project'), findsNothing);
    });

    testWidgets('schedule page shows linked session details and reminder flow',
        (WidgetTester tester) async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      await _seedParentData(firestore);

      await _pumpPage(
        tester,
        firestore: firestore,
        home: const ParentSchedulePage(),
      );

      expect(find.text('Hidden Session'), findsNothing);

      await tester.ensureVisible(find.text('Details'));
      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();

      expect(find.text('Next Session Details'), findsOneWidget);
      expect(find.textContaining('Robotics Studio\nLocation: Lab 1'), findsOneWidget);
      expect(find.textContaining('Location: Lab 1'), findsOneWidget);

      await tester.tap(find.text('Set Reminder'));
      await tester.pumpAndSettle();

      expect(find.text('Session reminder set'), findsOneWidget);
    });

    testWidgets('portfolio page opens linked artifact details only',
        (WidgetTester tester) async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      await _seedParentData(firestore);

      await _pumpPage(
        tester,
        firestore: firestore,
        home: const ParentPortfolioPage(),
      );

      expect(find.text('Build a Robot'), findsOneWidget);
      expect(find.text('Hidden Project'), findsNothing);

      await tester.ensureVisible(find.text('Build a Robot').first);
      await tester.tap(find.text('Build a Robot').first);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(OutlinedButton, 'Share'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Download'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Share'));
      await tester.pumpAndSettle();

      expect(find.text('Sharing...'), findsOneWidget);
    });

    testWidgets('billing page shows explicit unavailable state when no billing data exists',
        (WidgetTester tester) async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      await _seedParentData(firestore);

      await _pumpPage(
        tester,
        firestore: firestore,
        home: const ParentBillingPage(),
      );

      expect(find.text('No billing data yet'), findsOneWidget);
  await tester.tap(find.byIcon(Icons.download).first);
  await tester.pumpAndSettle();
  expect(find.text('Billing statements are not available yet'), findsOneWidget);
      await tester.tap(find.text('Plan'));
      await tester.pumpAndSettle();
      expect(find.text('Billing plan unavailable'), findsOneWidget);
      expect(find.text('All paid'), findsNothing);
      expect(find.text('Active'), findsNothing);
    });
  });
}