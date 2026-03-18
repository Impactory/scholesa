import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/modules/educator/educator_learners_page.dart';
import 'package:scholesa_app/modules/educator/educator_service.dart';
import 'package:scholesa_app/services/firestore_service.dart';
import 'package:scholesa_app/ui/theme/scholesa_theme.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

AppState _buildEducatorState() {
  final AppState state = AppState();
  state.updateFromMeResponse(<String, dynamic>{
    'userId': 'educator-1',
    'email': 'educator-1@scholesa.test',
    'displayName': 'Educator One',
    'role': 'educator',
    'activeSiteId': 'site-1',
    'siteIds': <String>['site-1'],
    'localeCode': 'en',
    'entitlements': <Map<String, dynamic>>[],
  });
  return state;
}

Widget _buildHarness({
  required Widget child,
  required List<SingleChildWidget> providers,
}) {
  return MultiProvider(
    providers: providers,
    child: MaterialApp(
      theme: ScholesaTheme.light,
      locale: const Locale('en'),
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const <Locale>[
        Locale('en'),
        Locale('zh', 'CN'),
        Locale('zh', 'TW'),
      ],
      home: child,
    ),
  );
}

Future<void> _seedLearner(FakeFirebaseFirestore firestore) async {
  await firestore.collection('users').doc('learner-1').set(<String, dynamic>{
    'displayName': 'Learner One',
    'email': 'learner-1@scholesa.test',
    'siteId': 'site-1',
    'attendanceRate': 68,
    'missionsCompleted': 3,
    'futureSkillsProgress': 0.32,
    'leadershipProgress': 0.48,
    'impactProgress': 0.41,
    'enrolledSessionIds': <String>['session-1'],
  });
  await firestore
      .collection('enrollments')
      .doc('enrollment-1')
      .set(<String, dynamic>{
    'siteId': 'site-1',
    'learnerId': 'learner-1',
    'educatorId': 'educator-1',
    'sessionId': 'session-1',
  });
}

Future<void> _seedLearnerWithoutDisplayName(
  FakeFirebaseFirestore firestore,
) async {
  await firestore.collection('users').doc('learner-1').set(<String, dynamic>{
    'email': 'learner-1@scholesa.test',
    'siteId': 'site-1',
    'attendanceRate': 68,
    'missionsCompleted': 3,
    'futureSkillsProgress': 0.32,
    'leadershipProgress': 0.48,
    'impactProgress': 0.41,
    'enrolledSessionIds': <String>['session-1'],
  });
  await firestore
      .collection('enrollments')
      .doc('enrollment-1')
      .set(<String, dynamic>{
    'siteId': 'site-1',
    'learnerId': 'learner-1',
    'educatorId': 'educator-1',
    'sessionId': 'session-1',
  });
}

void main() {
  testWidgets(
      'educator learner detail saves lane override and printable practice export',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await _seedLearner(firestore);
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    final EducatorService educatorService = EducatorService(
      firestoreService: firestoreService,
      educatorId: 'educator-1',
      siteId: 'site-1',
    );
    final AppState appState = _buildEducatorState();

    await tester.pumpWidget(
      _buildHarness(
        child: const EducatorLearnersPage(),
        providers: <SingleChildWidget>[
          Provider<FirestoreService>.value(value: firestoreService),
          ChangeNotifierProvider<AppState>.value(value: appState),
          ChangeNotifierProvider<EducatorService>.value(value: educatorService),
        ],
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Learner One'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Differentiation lane'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('Core lane'),
      find.byType(Scrollable).last,
      const Offset(0, -120),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Core lane'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(
      find.byType(TextField).last,
      'Learner is ready for on-level practice this week.',
    );
    await tester.ensureVisible(find.text('Save lane override'));
    await tester.tap(find.text('Save lane override'));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.ensureVisible(find.text('Export practice plan'));
    await tester.tap(find.text('Export practice plan'));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.dragUntilVisible(
      find.text(
        'Direct learner messaging and full learner profiles are not available from this sheet yet.',
      ),
      find.byType(Scrollable).last,
      const Offset(0, -120),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      find.text(
        'Direct learner messaging and full learner profiles are not available from this sheet yet.',
      ),
      findsOneWidget,
    );
    expect(find.text('Message'), findsNothing);
    expect(find.text('Full Profile'), findsNothing);

    final planDoc = await firestore
        .collection('learnerDifferentiationPlans')
        .doc('learner-1_site-1')
        .get();
    expect(planDoc.exists, isTrue);
    expect(planDoc.data()?['recommendedLane'], 'scaffolded');
    expect(planDoc.data()?['selectedLane'], 'core');
    expect(planDoc.data()?['teacherOverride'], isTrue);

    final practiceExports = await firestore.collection('practiceExports').get();
    expect(practiceExports.docs.length, 1);
    expect(practiceExports.docs.first.data()['lane'], 'core');
    expect(
      practiceExports.docs.first.data()['content'] as String,
      contains('Learner: Learner One'),
    );
  });

  testWidgets('educator learners page shows honest learner unavailable label',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await _seedLearnerWithoutDisplayName(firestore);
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    final EducatorService educatorService = EducatorService(
      firestoreService: firestoreService,
      educatorId: 'educator-1',
      siteId: 'site-1',
    );

    await tester.pumpWidget(
      _buildHarness(
        child: const EducatorLearnersPage(),
        providers: <SingleChildWidget>[
          Provider<FirestoreService>.value(value: firestoreService),
          ChangeNotifierProvider<AppState>.value(value: _buildEducatorState()),
          ChangeNotifierProvider<EducatorService>.value(value: educatorService),
        ],
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Learner unavailable'), findsWidgets);
    expect(find.text('Unknown'), findsNothing);
  });
}
