import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/modules/educator/educator_mission_plans_page.dart';
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
  required FirestoreService firestoreService,
  required EducatorService educatorService,
  Widget home = const EducatorMissionPlansPage(),
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
      home: home,
    ),
  );
}

Future<void> _seedMission(
  FakeFirebaseFirestore firestore, {
  required String missionId,
  required String title,
  String description = 'Prototype a reusable habitat solution.',
  String status = 'draft',
  String pillar = 'Future Skills',
}) async {
  await firestore.collection('missions').doc(missionId).set(<String, dynamic>{
    'title': title,
    'description': description,
    'pillar': pillar,
    'pillarCode': pillar == 'Leadership & Agency'
        ? 'leadership'
        : pillar == 'Impact & Innovation'
            ? 'impact'
            : 'future_skills',
    'pillarCodes': <String>[
      pillar == 'Leadership & Agency'
          ? 'leadership'
          : pillar == 'Impact & Innovation'
              ? 'impact'
              : 'future_skills',
    ],
    'duration': '4 weeks',
    'targetGrade': '6-8',
    'difficulty': 'beginner',
    'status': status,
    'assignedSessions': 0,
    'completedBy': 0,
    'evidenceDefaults': const <String>[
      'explain_it_back',
      'reflection_note',
    ],
    'lessonSteps': const <String>[
      'Launch challenge',
      'Guided practice',
    ],
    'educatorId': 'educator-1',
    'createdBy': 'educator-1',
    'createdAt': Timestamp.fromDate(DateTime(2026, 3, 19)),
    'updatedAt': Timestamp.fromDate(DateTime(2026, 3, 19)),
  });
  await firestore
      .collection('missions')
      .doc(missionId)
      .collection('steps')
      .doc('step-1')
      .set(<String, dynamic>{
    'title': 'Launch challenge',
    'order': 0,
    'isCompleted': false,
    'createdAt': Timestamp.fromDate(DateTime(2026, 3, 19)),
    'updatedAt': Timestamp.fromDate(DateTime(2026, 3, 19)),
  });
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
      'educator mission plans page keeps stale plans visible after refresh failure',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    final EducatorService educatorService = EducatorService(
      firestoreService: firestoreService,
      educatorId: 'educator-1',
      siteId: 'site-1',
    );
    int loadCount = 0;

    await tester.pumpWidget(
      _buildHarness(
        firestoreService: firestoreService,
        educatorService: educatorService,
        home: EducatorMissionPlansPage(
          missionPlansLoader: (BuildContext context) async {
            loadCount += 1;
            if (loadCount == 1) {
              return <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'mission-1',
                  'title': 'Eco Build Sprint',
                  'description': 'Prototype a reusable habitat solution.',
                  'pillar': 'Future Skills',
                  'difficulty': 'beginner',
                  'status': 'draft',
                  'assignedSessions': 0,
                  'completedBy': 0,
                  'evidenceDefaults': const <String>['explain_it_back'],
                  'lessonSteps': const <String>['Launch challenge'],
                  'educatorId': 'educator-1',
                },
              ];
            }
            throw FirebaseException(
              plugin: 'cloud_firestore',
              code: 'failed-precondition',
              message:
                  'The query requires an index. You can create it here: https://console.firebase.google.com/project/demo/firestore/indexes',
            );
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Eco Build Sprint'), findsWidgets);

    await tester.tap(find.byTooltip('Refresh'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Eco Build Sprint'), findsWidgets);
    expect(
      find.text(
        'Unable to refresh mission plans right now. Showing the last successful data. Mission plans could not load right now. Refresh, or check again after the app reconnects.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('console.firebase.google.com'), findsNothing);
    expect(find.textContaining('failed-precondition'), findsNothing);
    expect(find.text('No missions yet'), findsNothing);
  });

  testWidgets(
      'educator mission plans page shows an explicit load error instead of an empty state',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
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
        home: EducatorMissionPlansPage(
          missionPlansLoader: (BuildContext context) async {
            throw FirebaseException(
              plugin: 'cloud_firestore',
              code: 'failed-precondition',
              message:
                  'The query requires an index. You can create it here: https://console.firebase.google.com/project/demo/firestore/indexes',
            );
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Account menu'), findsOneWidget);
    expect(find.text('Unable to load mission plans'), findsOneWidget);
    expect(
      find.text(
        'Mission plans could not load right now. Refresh, or check again after the app reconnects.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('console.firebase.google.com'), findsNothing);
    expect(find.textContaining('failed-precondition'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('No missions yet'), findsNothing);
  });

  testWidgets('educator mission plans page creates a mission and persists it',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
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

    expect(find.bySemanticsLabel('Account menu'), findsOneWidget);
    expect(find.text('No missions yet'), findsOneWidget);

    await tester.tap(find.text('New Mission'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Eco Build Sprint');
    await tester.enterText(
      find.byType(TextField).at(1),
      'Prototype a reusable habitat solution for the studio garden.',
    );

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.text('Mission created and added to list'), findsOneWidget);
    expect(find.text('Eco Build Sprint'), findsWidgets);

    final missions = await firestore.collection('missions').get();
    expect(missions.docs.length, 1);
    expect(missions.docs.first.data()['title'], 'Eco Build Sprint');
    expect(missions.docs.first.data()['educatorId'], 'educator-1');
  });

  testWidgets('educator mission plans page surfaces failed mission creation',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
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
        home: EducatorMissionPlansPage(
          missionPlanCreator: (
            BuildContext context, {
            required String title,
            required String description,
            required String pillar,
            required String difficulty,
            required List<String> evidenceDefaults,
            required List<String> orderedSteps,
          }) async {
            return false;
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('New Mission'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Eco Build Sprint');
    await tester.enterText(
      find.byType(TextField).at(1),
      'Prototype a reusable habitat solution for the studio garden.',
    );

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.text('Failed to create mission'), findsOneWidget);
    expect(find.text('Eco Build Sprint'), findsOneWidget);

    final missions = await firestore.collection('missions').get();
    expect(missions.docs, isEmpty);
  });

  testWidgets('educator mission plans page updates a mission and persists it',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await _seedMission(
      firestore,
      missionId: 'mission-1',
      title: 'Eco Build Sprint',
    );
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
    await tester.pumpAndSettle();

    await tester.tap(find.text('Eco Build Sprint').first);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Edit'),
      250,
      scrollable: find.byType(Scrollable).last,
    );

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField).at(0),
      'Eco Build Sprint Revised',
    );
    await tester.enterText(
      find.byType(TextField).at(1),
      'Prototype a reusable habitat solution for the studio garden and publish evidence.',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('mission_step_field_1')),
      'Publish evidence reflection',
    );

    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(find.text('Mission updated'), findsOneWidget);
    expect(find.text('Eco Build Sprint Revised'), findsWidgets);

    final mission =
        await firestore.collection('missions').doc('mission-1').get();
    expect(mission.data()?['title'], 'Eco Build Sprint Revised');
    expect(
      mission.data()?['description'],
      'Prototype a reusable habitat solution for the studio garden and publish evidence.',
    );
    expect(
      mission.data()?['lessonSteps'],
      <String>['Launch challenge', 'Publish evidence reflection'],
    );
  });

  testWidgets('educator mission plans page archives a mission and persists it',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await _seedMission(
      firestore,
      missionId: 'mission-1',
      title: 'Eco Build Sprint',
    );
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
    await tester.pumpAndSettle();

    await tester.tap(find.text('Eco Build Sprint').first);
    await tester.pumpAndSettle();

    final Finder archiveAction = find.widgetWithText(ElevatedButton, 'Archive');
    await tester.ensureVisible(archiveAction);
    await tester.tap(archiveAction);
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Archive'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mission archived'), findsOneWidget);

    final mission =
        await firestore.collection('missions').doc('mission-1').get();
    expect(mission.data()?['status'], 'archived');
  });

  testWidgets(
      'educator mission plans page restores the saved pillar filter on reopen',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await _seedMission(
      firestore,
      missionId: 'mission-1',
      title: 'Eco Build Sprint',
      pillar: 'Future Skills',
    );
    await _seedMission(
      firestore,
      missionId: 'mission-2',
      title: 'Leadership Studio',
      pillar: 'Leadership & Agency',
    );
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    final EducatorService educatorService = EducatorService(
      firestoreService: firestoreService,
      educatorId: 'educator-1',
      siteId: 'site-1',
    );

    Widget buildHome() => _buildHarness(
          firestoreService: firestoreService,
          educatorService: educatorService,
          home: EducatorMissionPlansPage(sharedPreferences: prefs),
        );

    await tester.pumpWidget(buildHome());
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Eco Build Sprint'), findsWidgets);
    expect(find.text('Leadership Studio'), findsWidgets);

    await tester.tap(find.byIcon(Icons.filter_list_rounded));
    await tester.pumpAndSettle();
    final Finder filterDialog = find.byType(AlertDialog);
    // Legacy family 'Leadership & Agency' renders through the canonical
    // strand display as 'Communicate & Lead'.
    await tester.tap(
      find.descendant(
        of: filterDialog,
        matching: find.text('Communicate & Lead'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Apply'));
    await tester.pumpAndSettle();

    expect(find.text('Leadership Studio'), findsWidgets);
    expect(find.text('Eco Build Sprint'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    await tester.pumpWidget(buildHome());
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Leadership Studio'), findsWidgets);
    expect(find.text('Eco Build Sprint'), findsNothing);
  });

  testWidgets('educator mission plans page surfaces failed mission archiving',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await _seedMission(
      firestore,
      missionId: 'mission-1',
      title: 'Eco Build Sprint',
    );
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
        home: EducatorMissionPlansPage(
          missionPlanArchiver: (
            BuildContext context, {
            required String missionId,
          }) async {
            return false;
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Eco Build Sprint').first);
    await tester.pumpAndSettle();

    final Finder archiveAction = find.widgetWithText(ElevatedButton, 'Archive');
    await tester.ensureVisible(archiveAction);
    await tester.tap(archiveAction);
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Archive'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Failed to archive mission'), findsOneWidget);

    final mission =
        await firestore.collection('missions').doc('mission-1').get();
    expect(mission.data()?['status'], 'draft');
  });
}
