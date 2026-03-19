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
import 'package:scholesa_app/modules/habits/habit_service.dart';
import 'package:scholesa_app/modules/habits/habits_page.dart';
import 'package:scholesa_app/services/firestore_service.dart';

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

Widget _buildHarness({required FirestoreService firestoreService, required HabitService habitService}) {
  return MultiProvider(
    providers: <SingleChildWidget>[
      ChangeNotifierProvider<AppState>.value(value: _buildLearnerState()),
      Provider<FirestoreService>.value(value: firestoreService),
      ChangeNotifierProvider<HabitService>.value(value: habitService),
    ],
    child: MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        splashFactory: NoSplash.splashFactory,
      ),
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const <Locale>[Locale('en'), Locale('zh', 'CN'), Locale('zh', 'TW')],
      home: const HabitsPage(),
    ),
  );
}

Future<void> _seedHabit(FakeFirebaseFirestore firestore) async {
  await firestore.collection('habits').doc('habit-1').set(<String, dynamic>{
    'learnerId': 'learner-1',
    'title': 'Read for 10 minutes',
    'description': 'Daily reading time',
    'emoji': '📚',
    'category': 'learning',
    'frequency': 'daily',
    'preferredTime': 'evening',
    'targetMinutes': 10,
    'createdAt': Timestamp.fromDate(DateTime(2026, 3, 1)),
    'currentStreak': 2,
    'longestStreak': 2,
    'totalCompletions': 2,
    'isActive': true,
    'lastCompletedAt': Timestamp.fromDate(DateTime(2026, 3, 16, 9)),
    'buildingPhaseStartDate': Timestamp.fromDate(DateTime(2026, 3, 1)),
  });
}

void main() {
  testWidgets('habits page shows empty-state coaching copy', (WidgetTester tester) async {
    final FirestoreService firestoreService = FirestoreService(
      firestore: FakeFirebaseFirestore(),
      auth: _MockFirebaseAuth(),
    );
    final HabitService habitService = HabitService(
      firestoreService: firestoreService,
      learnerId: 'learner-1',
    );

    await tester.binding.setSurfaceSize(const Size(1280, 1800));
    await tester.pumpWidget(
      _buildHarness(
        firestoreService: firestoreService,
        habitService: habitService,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    expect(find.text('Start building your habits!'), findsOneWidget);
    expect(find.text('Tap + to create your first habit'), findsOneWidget);
  });

  testWidgets('habits page completes a habit and persists a log',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await _seedHabit(firestore);
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    final HabitService habitService = HabitService(
      firestoreService: firestoreService,
      learnerId: 'learner-1',
    );

    await tester.binding.setSurfaceSize(const Size(1280, 1800));
    await tester.pumpWidget(
      _buildHarness(
        firestoreService: firestoreService,
        habitService: habitService,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    expect(find.text('Read for 10 minutes'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.play_arrow_rounded).first);
    await tester.pumpAndSettle();

    expect(find.textContaining('completed!'), findsOneWidget);
    final QuerySnapshot<Map<String, dynamic>> logs = await firestore.collection('habitLogs').get();
    expect(logs.docs.length, 1);
    expect(logs.docs.first.data()['habitId'], 'habit-1');
  });

  testWidgets('habits AI fallback offers degraded-mode guidance',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await _seedHabit(firestore);
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    final HabitService habitService = HabitService(
      firestoreService: firestoreService,
      learnerId: 'learner-1',
    );

    await tester.binding.setSurfaceSize(const Size(1280, 1800));
    await tester.pumpWidget(
      _buildHarness(
        firestoreService: firestoreService,
        habitService: habitService,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Read for 10 minutes'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Reflect with AI'));
    await tester.tap(find.byIcon(Icons.expand_more).last);
    await tester.pumpAndSettle();

    expect(find.text('AI Coach is temporarily unavailable'), findsOneWidget);
    expect(
      find.text('Keep your streak moving while AI reconnects.'),
      findsOneWidget,
    );
    expect(find.text('Continue this habit'), findsOneWidget);

    await tester.tap(find.text('Continue this habit'));
    await tester.pumpAndSettle();

    expect(find.text('AI Coach is temporarily unavailable'), findsNothing);
    expect(find.text('Get coaching on your progress'), findsOneWidget);
  });
}