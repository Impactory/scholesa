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
import 'package:scholesa_app/modules/missions/mission_service.dart';
import 'package:scholesa_app/modules/missions/missions_page.dart';
import 'package:scholesa_app/services/firestore_service.dart';
import 'package:scholesa_app/ui/theme/scholesa_theme.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

AppState _buildLearnerState() {
  final AppState appState = AppState();
  appState.updateFromMeResponse(<String, dynamic>{
    'userId': 'learner-1',
    'email': 'learner-1@scholesa.test',
    'displayName': 'Learner One',
    'role': 'learner',
    'activeSiteId': 'site-1',
    'siteIds': <String>['site-1'],
    'entitlements': <Map<String, dynamic>>[],
  });
  return appState;
}

Widget _buildHarness({required FirestoreService firestoreService, required MissionService missionService}) {
  return MultiProvider(
    providers: <SingleChildWidget>[
      ChangeNotifierProvider<AppState>.value(value: _buildLearnerState()),
      Provider<FirestoreService>.value(value: firestoreService),
      ChangeNotifierProvider<MissionService>.value(value: missionService),
    ],
    child: MaterialApp(
      theme: ScholesaTheme.light,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const <Locale>[Locale('en'), Locale('zh', 'CN'), Locale('zh', 'TW')],
      home: const MissionsPage(),
    ),
  );
}

Future<void> _seedMissionAndGate(FakeFirebaseFirestore firestore) async {
  await firestore.collection('missionAssignments').doc('assignment-1').set(
    <String, dynamic>{
      'missionId': 'mission-1',
      'learnerId': 'learner-1',
      'siteId': 'site-1',
      'status': 'in_progress',
      'progress': 0.45,
    },
  );
  await firestore.collection('missions').doc('mission-1').set(
    <String, dynamic>{
      'title': 'Mission with verification gate',
      'description': 'Explain your control loop before moving on.',
      'pillarCode': 'future_skills',
      'difficulty': 'beginner',
      'xpReward': 120,
    },
  );
  await firestore.collection('missions').doc('mission-1').collection('steps').doc('step-1').set(
    <String, dynamic>{
      'title': 'Prototype',
      'order': 1,
      'isCompleted': false,
    },
  );
  await firestore.collection('mvlEpisodes').doc('mvl-1').set(
    <String, dynamic>{
      'siteId': 'site-1',
      'learnerId': 'learner-1',
      'sessionOccurrenceId': null,
      'triggerReason': 'high_reliability_risk + high_autonomy_risk',
      'reliability': <String, dynamic>{
        'method': 'sep',
        'K': 1,
        'M': 1,
        'H_sem': 0.72,
        'riskScore': 0.81,
        'threshold': 0.6,
      },
      'autonomy': <String, dynamic>{
        'signals': <String>['verification_gap'],
        'riskScore': 0.72,
        'threshold': 0.5,
      },
      'evidenceEventIds': <String>[],
      'resolution': null,
      'createdAt': Timestamp.fromDate(DateTime(2026, 3, 18)),
    },
  );
}

Future<void> _seedMission(FakeFirebaseFirestore firestore) async {
  await firestore.collection('missionAssignments').doc('assignment-1').set(
    <String, dynamic>{
      'missionId': 'mission-1',
      'learnerId': 'learner-1',
      'siteId': 'site-1',
      'status': 'in_progress',
      'progress': 0.45,
    },
  );
  await firestore.collection('missions').doc('mission-1').set(
    <String, dynamic>{
      'title': 'Mission with AI fallback',
      'description': 'Explain your control loop before moving on.',
      'pillarCode': 'future_skills',
      'difficulty': 'beginner',
      'xpReward': 120,
    },
  );
  await firestore.collection('missions').doc('mission-1').collection('steps').doc('step-1').set(
    <String, dynamic>{
      'title': 'Prototype',
      'order': 1,
      'isCompleted': false,
    },
  );
}

void main() {
  testWidgets('missions page shows empty available-state copy', (WidgetTester tester) async {
    final FirestoreService firestoreService = FirestoreService(
      firestore: FakeFirebaseFirestore(),
      auth: _MockFirebaseAuth(),
    );
    final MissionService missionService = MissionService(
      firestoreService: firestoreService,
      learnerId: 'learner-1',
    );

    await tester.binding.setSurfaceSize(const Size(1280, 1800));
    await tester.pumpWidget(
      _buildHarness(
        firestoreService: firestoreService,
        missionService: missionService,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Account menu'), findsOneWidget);
    expect(find.text('No missions available'), findsOneWidget);
    expect(find.text('Check back soon for new challenges!'), findsOneWidget);
  });

  testWidgets('missions page blocks mission details behind MVL gate',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await _seedMissionAndGate(firestore);
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    final MissionService missionService = MissionService(
      firestoreService: firestoreService,
      learnerId: 'learner-1',
    );

    await tester.pumpWidget(
      _buildHarness(
        firestoreService: firestoreService,
        missionService: missionService,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Account menu'), findsOneWidget);
    await tester.tap(find.text('In Progress'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mission with verification gate').first);
    await tester.pumpAndSettle();

    expect(find.text('Show Your Understanding'), findsOneWidget);
    expect(find.text('Submit Evidence'), findsOneWidget);
  });

  testWidgets('missions AI fallback offers degraded-mode guidance',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await _seedMission(firestore);
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    final MissionService missionService = MissionService(
      firestoreService: firestoreService,
      learnerId: 'learner-1',
    );

    await tester.binding.setSurfaceSize(const Size(1280, 1800));
    await tester.pumpWidget(
      _buildHarness(
        firestoreService: firestoreService,
        missionService: missionService,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    await tester.tap(find.text('In Progress'));
    await tester.pumpAndSettle();
  await tester.tap(find.text('Mission with AI fallback').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Get AI Help'));
    await tester.tap(find.byKey(const Key('mission-ai-toggle')));
    await tester.pumpAndSettle();

    expect(find.text('AI help is temporarily unavailable'), findsOneWidget);
    expect(
      find.text('Keep working on this mission while AI reconnects.'),
      findsOneWidget,
    );
    expect(find.text('Continue this mission'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('mission-ai-continue')));
    await tester.tap(find.byKey(const Key('mission-ai-continue')));
    await tester.pumpAndSettle();

    expect(find.text('AI help is temporarily unavailable'), findsNothing);
    expect(
      find.text('Ask for hints, explanations, or debugging help'),
      findsOneWidget,
    );
  });
}