import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/modules/educator/educator_models.dart';
import 'package:scholesa_app/modules/educator/educator_service.dart';
import 'package:scholesa_app/modules/educator/educator_today_page.dart';
import 'package:scholesa_app/modules/educator/educator_mission_review_page.dart';
import 'package:scholesa_app/modules/missions/mission_service.dart';
import 'package:scholesa_app/services/firestore_service.dart';
import 'package:scholesa_app/ui/theme/scholesa_theme.dart';

final ThemeData _testTheme = ScholesaTheme.light;

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _MockEducatorService extends Mock implements EducatorService {}

AppState _buildAppState() {
  final AppState state = AppState();
  state.updateFromMeResponse(<String, dynamic>{
    'userId': 'educator-1',
    'email': 'educator-1@scholesa.test',
    'displayName': 'Educator One',
    'role': 'educator',
    'activeSiteId': 'site-1',
    'siteIds': <String>['site-1'],
    'entitlements': <Map<String, dynamic>>[],
  });
  return state;
}

void main() {
  testWidgets('educator review queue CTA navigates to the real queue route',
      (WidgetTester tester) async {
    final AppState appState = _buildAppState();
    final _MockEducatorService educatorService = _MockEducatorService();

    final TodayClass todayClass = TodayClass(
      id: 'occ-1',
      sessionId: 'session-1',
      title: 'Mission Studio',
      description: 'Review submissions',
      startTime: DateTime(2026, 3, 17, 9),
      endTime: DateTime(2026, 3, 17, 10),
      location: 'Room A',
      enrolledCount: 12,
      presentCount: 10,
      status: 'in_progress',
      learners: const <EnrolledLearner>[],
    );

    when(() => educatorService.loadTodaySchedule()).thenAnswer((_) async {});
    when(() => educatorService.loadLearners()).thenAnswer((_) async {});
    when(() => educatorService.isLoading).thenReturn(false);
    when(() => educatorService.todayClasses)
        .thenReturn(<TodayClass>[todayClass]);
    when(() => educatorService.currentClass).thenReturn(todayClass);
    when(() => educatorService.learners).thenReturn(const <EducatorLearner>[]);
    when(() => educatorService.dayStats).thenReturn(
      const EducatorDayStats(
        totalClasses: 1,
        completedClasses: 0,
        totalLearners: 12,
        presentLearners: 10,
        missionsToReview: 3,
        unreadMessages: 0,
      ),
    );
    when(() => educatorService.siteId).thenReturn('site-1');

    final GoRouter router = GoRouter(
      initialLocation: '/educator/today',
      routes: <RouteBase>[
        GoRoute(
          path: '/educator/today',
          builder: (BuildContext context, GoRouterState state) =>
              const EducatorTodayPage(),
        ),
        GoRoute(
          path: '/educator/missions/review',
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Center(child: Text('Mission Review Route'))),
        ),
      ],
    );

    await tester.binding.setSurfaceSize(const Size(1280, 1800));
    await tester.pumpWidget(
      MultiProvider(
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<AppState>.value(value: appState),
          ChangeNotifierProvider<EducatorService>.value(value: educatorService),
        ],
        child: MaterialApp.router(
          theme: _testTheme,
          routerConfig: router,
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Review Missions'));
    await tester.pumpAndSettle();

    expect(find.text('Mission Review Queue'), findsOneWidget);

    await tester.tap(find.text('Open Queue'));
    await tester.pumpAndSettle();

    expect(find.text('Mission Review Route'), findsOneWidget);
    expect(find.text('Mission review queue opened'), findsNothing);
  });

  testWidgets(
      'mission review AI draft copy stays honest about local draft state',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    final MissionService missionService = MissionService(
      firestoreService: firestoreService,
      learnerId: 'educator-1',
    );

    await firestore.collection('users').doc('learner-1').set(<String, dynamic>{
      'displayName': 'Avery Chen',
    });
    await firestore
        .collection('missions')
        .doc('mission-1')
        .set(<String, dynamic>{
      'title': 'Robotics Reflection',
      'pillarCode': 'future_skills',
    });
    await firestore
        .collection('missionAttempts')
        .doc('submission-1')
        .set(<String, dynamic>{
      'missionId': 'mission-1',
      'missionTitle': 'Robotics Reflection',
      'learnerId': 'learner-1',
      'siteId': 'site-1',
      'status': 'submitted',
      'submittedAt': Timestamp.fromDate(DateTime(2026, 3, 17, 9, 30)),
      'content': 'I built a loop that reads the sensor twice.',
    });

    await tester.binding.setSurfaceSize(const Size(1280, 1800));
    await tester.pumpWidget(
      MultiProvider(
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<AppState>.value(value: _buildAppState()),
          Provider<FirestoreService>.value(value: firestoreService),
          ChangeNotifierProvider<MissionService>.value(value: missionService),
        ],
        child: MaterialApp(
          theme: _testTheme,
          home: const EducatorMissionReviewPage(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Robotics Reflection'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Robotics Reflection').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Generate AI draft'));
    await tester.pumpAndSettle();

    expect(find.text('AI draft ready to edit'), findsOneWidget);
    expect(find.text('AI draft saved'), findsNothing);
  });

  testWidgets('mission review uses learner unavailable when identity is missing',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    final MissionService missionService = MissionService(
      firestoreService: firestoreService,
      learnerId: 'educator-1',
    );

    await firestore.collection('users').doc('learner-1').set(<String, dynamic>{
      'email': 'learner-1@scholesa.test',
    });
    await firestore.collection('missions').doc('mission-1').set(<String, dynamic>{
      'title': 'Robotics Reflection',
      'pillarCode': 'future_skills',
    });
    await firestore
        .collection('missionAttempts')
        .doc('submission-1')
        .set(<String, dynamic>{
      'missionId': 'mission-1',
      'missionTitle': 'Robotics Reflection',
      'learnerId': 'learner-1',
      'siteId': 'site-1',
      'status': 'submitted',
      'submittedAt': Timestamp.fromDate(DateTime(2026, 3, 17, 9, 30)),
      'content': 'I built a loop that reads the sensor twice.',
    });

    await tester.binding.setSurfaceSize(const Size(1280, 1800));
    await tester.pumpWidget(
      MultiProvider(
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<AppState>.value(value: _buildAppState()),
          Provider<FirestoreService>.value(value: firestoreService),
          ChangeNotifierProvider<MissionService>.value(value: missionService),
        ],
        child: MaterialApp(
          theme: _testTheme,
          home: const EducatorMissionReviewPage(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Learner unavailable'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Learner unavailable'), findsWidgets);
    expect(find.text('Unknown'), findsNothing);

    await tester.tap(find.text('Robotics Reflection').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Generate AI draft'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Learner unavailable showed'), findsWidgets);
    expect(find.textContaining('Unknown showed'), findsNothing);
  });

  testWidgets('mission review uses mission unavailable when mission title is missing',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    final MissionService missionService = MissionService(
      firestoreService: firestoreService,
      learnerId: 'educator-1',
    );

    await firestore.collection('users').doc('learner-1').set(<String, dynamic>{
      'displayName': 'Avery Chen',
    });
    await firestore.collection('missions').doc('mission-1').set(<String, dynamic>{
      'pillarCode': 'future_skills',
    });
    await firestore
        .collection('missionSubmissions')
        .doc('submission-1')
        .set(<String, dynamic>{
      'missionId': 'mission-1',
      'learnerId': 'learner-1',
      'siteId': 'site-1',
      'status': 'pending',
      'submittedAt': Timestamp.fromDate(DateTime(2026, 3, 17, 9, 30)),
      'submissionText': 'I built a loop that reads the sensor twice.',
    });

    await tester.binding.setSurfaceSize(const Size(1280, 1800));
    await tester.pumpWidget(
      MultiProvider(
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<AppState>.value(value: _buildAppState()),
          Provider<FirestoreService>.value(value: firestoreService),
          ChangeNotifierProvider<MissionService>.value(value: missionService),
        ],
        child: MaterialApp(
          theme: _testTheme,
          home: const EducatorMissionReviewPage(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Mission unavailable'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Mission unavailable'), findsWidgets);
    expect(find.text('Unknown Mission'), findsNothing);

    await tester.tap(find.text('Mission unavailable').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Generate AI draft'));
    await tester.pumpAndSettle();

    expect(find.textContaining('growth in Mission unavailable.'), findsWidgets);
    expect(find.textContaining('growth in Unknown Mission.'), findsNothing);
  });
}
