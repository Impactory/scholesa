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
import 'package:scholesa_app/runtime/runtime.dart';
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
  required FirestoreService firestoreService,
  required EducatorService educatorService,
  BosLearnerLoopInsightsLoader? learnerLoopInsightsLoader,
}) {
  return MultiProvider(
    providers: <SingleChildWidget>[
      Provider<FirestoreService>.value(value: firestoreService),
      ChangeNotifierProvider<AppState>.value(value: _buildEducatorState()),
      ChangeNotifierProvider<EducatorService>.value(value: educatorService),
    ],
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
      home: EducatorLearnersPage(
        learnerLoopInsightsLoader: learnerLoopInsightsLoader,
      ),
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
  await firestore.collection('enrollments').doc('enrollment-1').set(<String, dynamic>{
    'siteId': 'site-1',
    'learnerId': 'learner-1',
    'educatorId': 'educator-1',
    'sessionId': 'session-1',
  });
}

Future<void> _seedLearnerWithoutDisplayName(FakeFirebaseFirestore firestore) async {
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
  await firestore.collection('enrollments').doc('enrollment-1').set(<String, dynamic>{
    'siteId': 'site-1',
    'learnerId': 'learner-1',
    'educatorId': 'educator-1',
    'sessionId': 'session-1',
  });
}

void main() {
  testWidgets('educator learners page persists learner follow-up requests',
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

    await tester.pumpWidget(
      _buildHarness(
        firestoreService: firestoreService,
        educatorService: educatorService,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Learner One'));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('Learner follow-up'),
      find.byType(Scrollable).last,
      const Offset(0, -120),
    );
    await tester.enterText(
      find.byType(TextField).last,
      'Family follow-up needed for attendance dip and lane check-in.',
    );
    await tester.tap(find.text('Request follow-up'));
    await tester.pumpAndSettle();

    expect(find.text('Learner follow-up request submitted.'), findsWidgets);
    final supportRequests = await firestore.collection('supportRequests').get();
    expect(supportRequests.docs.length, 1);
    expect(supportRequests.docs.first.data()['requestType'], 'learner_follow_up');
  });

  testWidgets('educator learners page shows learner unavailable label',
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
        firestoreService: firestoreService,
        educatorService: educatorService,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Learner unavailable'), findsWidgets);
    expect(find.text('Unknown'), findsNothing);
  });

  testWidgets('educator learners page discloses synthetic MiloOS preview',
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

    await tester.pumpWidget(
      _buildHarness(
        firestoreService: firestoreService,
        educatorService: educatorService,
        learnerLoopInsightsLoader: ({
          required String siteId,
          required String learnerId,
          required int lookbackDays,
        }) async => <String, dynamic>{
          'synthetic': true,
          'state': <String, dynamic>{
            'cognition': 0.73,
            'engagement': 0.64,
            'integrity': 0.9,
          },
          'trend': <String, dynamic>{
            'improvementScore': 0.06,
            'cognitionDelta': 0.02,
            'engagementDelta': 0.01,
            'integrityDelta': 0.01,
          },
          'mvl': <String, dynamic>{
            'active': 1,
            'passed': 0,
            'failed': 0,
          },
          'activeGoals': <String>['Prototype feedback loop'],
          'stateAvailability': <String, dynamic>{
            'hasCurrentState': true,
            'hasTrendBaseline': true,
          },
        },
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Synthetic MiloOS preview only. Do not treat this as classroom evidence or learner growth.',
      ),
      findsOneWidget,
    );
  });
}