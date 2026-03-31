import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/modules/habits/habit_service.dart';
import 'package:scholesa_app/modules/learner/learner_credentials_page.dart';
import 'package:scholesa_app/domain/models.dart';
import 'package:scholesa_app/modules/learner/learner_portfolio_page.dart';
import 'package:scholesa_app/modules/learner/learner_today_page.dart';
import 'package:scholesa_app/modules/messages/message_service.dart';
import 'package:scholesa_app/modules/missions/mission_models.dart';
import 'package:scholesa_app/modules/missions/missions_page.dart';
import 'package:scholesa_app/modules/missions/mission_service.dart';
import 'package:scholesa_app/modules/site/site_incidents_page.dart';
import 'package:scholesa_app/modules/site/site_ops_page.dart';
import 'package:scholesa_app/modules/site/site_sessions_page.dart';
import 'package:scholesa_app/services/firestore_service.dart';
import 'package:scholesa_app/services/notification_service.dart';
import 'package:scholesa_app/services/telemetry_service.dart';
import 'package:scholesa_app/ui/theme/scholesa_theme.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

String? _portfolioClipboardText;

AppState _buildAppState({
  required UserRole role,
  required Locale locale,
}) {
  final AppState appState = AppState();
  appState.updateFromMeResponse(<String, dynamic>{
    'userId': 'test-user-1',
    'email': 'test-user-1@scholesa.test',
    'displayName': 'Test User',
    'role': role.name,
    'activeSiteId': 'site-1',
    'siteIds': <String>['site-1'],
    'localeCode':
        locale.languageCode == 'zh' ? 'zh-${locale.countryCode}' : 'en',
    'entitlements': <Map<String, dynamic>>[],
  });
  return appState;
}

Widget _buildHarness({
  required Locale locale,
  required Widget child,
  required List<SingleChildWidget> providers,
  ThemeData? theme,
}) {
  final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) => child,
      ),
      GoRoute(
        path: '/learner/onboarding',
        builder: (BuildContext context, GoRouterState state) => child,
      ),
    ],
  );

  return MultiProvider(
    providers: providers,
    child: MaterialApp.router(
      routerConfig: router,
      theme: theme ??
          ScholesaTheme.light.copyWith(
            splashFactory: NoSplash.splashFactory,
          ),
      locale: locale,
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
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (
      MethodCall methodCall,
    ) async {
      if (methodCall.method == 'Clipboard.setData') {
        final Map<Object?, Object?>? arguments =
            methodCall.arguments as Map<Object?, Object?>?;
        _portfolioClipboardText = arguments?['text']?.toString();
      }
      return null;
    });
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  setUp(() {
    _portfolioClipboardText = null;
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('Learner and site tri-locale surfaces', () {
    testWidgets('learner today renders zh-CN copy',
        (WidgetTester tester) async {
      final Locale locale = const Locale('zh', 'CN');
      final FirestoreService firestoreService = FirestoreService(
        firestore: FakeFirebaseFirestore(),
        auth: _MockFirebaseAuth(),
      );
      final AppState appState = _buildAppState(
        role: UserRole.learner,
        locale: locale,
      );
      final MissionService missionService = MissionService(
        firestoreService: firestoreService,
        learnerId: 'test-user-1',
      );
      final HabitService habitService = HabitService(
        firestoreService: firestoreService,
        learnerId: 'test-user-1',
      );
      final MessageService messageService = MessageService(
        firestoreService: firestoreService,
        userId: 'test-user-1',
      );

      await tester.binding.setSurfaceSize(const Size(1280, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _buildHarness(
          locale: locale,
          child: const LearnerTodayPage(),
          providers: <SingleChildWidget>[
            ChangeNotifierProvider<AppState>.value(value: appState),
            Provider<FirestoreService>.value(value: firestoreService),
            ChangeNotifierProvider<MissionService>.value(value: missionService),
            ChangeNotifierProvider<HabitService>.value(value: habitService),
            ChangeNotifierProvider<MessageService>.value(value: messageService),
            Provider<dynamic>.value(value: null),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('今天'), findsOneWidget);
      expect(find.text('🌟 继续加油！'), findsOneWidget);
      expect(find.text('今天的习惯'), findsOneWidget);
      expect(find.text('学习者设置'), findsOneWidget);
    });

    testWidgets('learner setup persists profile to Firestore',
        (WidgetTester tester) async {
      final Locale locale = const Locale('en');
      final FakeFirebaseFirestore fakeFirestore = FakeFirebaseFirestore();
      final FirestoreService firestoreService = FirestoreService(
        firestore: fakeFirestore,
        auth: _MockFirebaseAuth(),
      );
      final AppState appState = _buildAppState(
        role: UserRole.learner,
        locale: locale,
      );
      final MissionService missionService = MissionService(
        firestoreService: firestoreService,
        learnerId: 'test-user-1',
      );
      final HabitService habitService = HabitService(
        firestoreService: firestoreService,
        learnerId: 'test-user-1',
      );
      final MessageService messageService = MessageService(
        firestoreService: firestoreService,
        userId: 'test-user-1',
      );
      final List<Map<String, dynamic>> reminderCalls = <Map<String, dynamic>>[];

      await tester.binding.setSurfaceSize(const Size(1280, 1800));
      await NotificationService.runWithCallableInvoker(
        (String callableName, Map<String, dynamic> payload) async {
          reminderCalls.add(<String, dynamic>{
            'callableName': callableName,
            'payload': Map<String, dynamic>.from(payload),
          });
        },
        () async {
          await tester.pumpWidget(
            _buildHarness(
              locale: locale,
              child: const LearnerTodayPage(),
              providers: <SingleChildWidget>[
                ChangeNotifierProvider<AppState>.value(value: appState),
                Provider<FirestoreService>.value(value: firestoreService),
                ChangeNotifierProvider<MissionService>.value(
                    value: missionService),
                ChangeNotifierProvider<HabitService>.value(value: habitService),
                ChangeNotifierProvider<MessageService>.value(
                    value: messageService),
                Provider<dynamic>.value(value: null),
              ],
            ),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.text('Complete setup'));
          await tester.pumpAndSettle();

          await tester.enterText(
              find.byType(TextField).at(0), 'Robotics, coding');
          await tester.enterText(
              find.byType(TextField).at(1), 'Build a better robot');
          await tester.enterText(
              find.byType(TextField).at(2), 'I want to create useful things');
          await tester.tap(find.text('Save').last);
          await tester.pumpAndSettle();
        },
      );

      expect(find.text('Setup saved'), findsOneWidget);

      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await fakeFirestore.collection('learnerProfiles').get();
      expect(snapshot.docs, hasLength(1));
      expect(snapshot.docs.first.data()['learnerId'], 'test-user-1');
      expect(snapshot.docs.first.data()['siteId'], 'site-1');
      expect(snapshot.docs.first.data()['onboardingCompleted'], true);
      expect(snapshot.docs.first.data()['diagnosticConfidenceBand'], isNull);

      expect(reminderCalls, hasLength(1));
      expect(
          reminderCalls.first['callableName'], 'syncLearnerReminderPreference');
      expect(reminderCalls.first['payload']['siteId'], 'site-1');
      expect(reminderCalls.first['payload']['schedule'], 'weekdays');
      expect(reminderCalls.first['payload']['weeklyTargetMinutes'], 90);
      expect(reminderCalls.first['payload']['localeCode'], 'en');
    });

    testWidgets('quick reflection writes learner reflection record',
        (WidgetTester tester) async {
      final Locale locale = const Locale('en');
      final FakeFirebaseFirestore fakeFirestore = FakeFirebaseFirestore();
      final FirestoreService firestoreService = FirestoreService(
        firestore: fakeFirestore,
        auth: _MockFirebaseAuth(),
      );
      final AppState appState = _buildAppState(
        role: UserRole.learner,
        locale: locale,
      );
      final MissionService missionService = MissionService(
        firestoreService: firestoreService,
        learnerId: 'test-user-1',
      );
      final HabitService habitService = HabitService(
        firestoreService: firestoreService,
        learnerId: 'test-user-1',
      );
      final MessageService messageService = MessageService(
        firestoreService: firestoreService,
        userId: 'test-user-1',
      );

      await tester.binding.setSurfaceSize(const Size(1280, 1800));
      await tester.pumpWidget(
        _buildHarness(
          locale: locale,
          child: const LearnerTodayPage(),
          providers: <SingleChildWidget>[
            ChangeNotifierProvider<AppState>.value(value: appState),
            Provider<FirestoreService>.value(value: firestoreService),
            ChangeNotifierProvider<MissionService>.value(value: missionService),
            ChangeNotifierProvider<HabitService>.value(value: habitService),
            ChangeNotifierProvider<MessageService>.value(value: messageService),
            Provider<dynamic>.value(value: null),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Quick reflection'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField).last,
        'The habit streak helped me stay focused.',
      );
      await tester.tap(find.text('Save').last);
      await tester.pumpAndSettle();

      expect(find.text('Reflection saved'), findsOneWidget);

      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await fakeFirestore.collection('learnerReflections').get();
      expect(snapshot.docs, hasLength(1));
      expect(snapshot.docs.first.data()['learnerId'], 'test-user-1');
      expect(snapshot.docs.first.data()['siteId'], 'site-1');
      expect(snapshot.docs.first.data()['reflectionType'], 'post_session');
    });

    testWidgets(
        'motivation loop pre-plan action writes learner reflection record',
        (WidgetTester tester) async {
      final Locale locale = const Locale('en');
      final FakeFirebaseFirestore fakeFirestore = FakeFirebaseFirestore();
      final FirestoreService firestoreService = FirestoreService(
        firestore: fakeFirestore,
        auth: _MockFirebaseAuth(),
      );
      final AppState appState = _buildAppState(
        role: UserRole.learner,
        locale: locale,
      );
      final MissionService missionService = MissionService(
        firestoreService: firestoreService,
        learnerId: 'test-user-1',
      );
      final HabitService habitService = HabitService(
        firestoreService: firestoreService,
        learnerId: 'test-user-1',
      );
      final MessageService messageService = MessageService(
        firestoreService: firestoreService,
        userId: 'test-user-1',
      );

      await fakeFirestore
          .collection('learnerProfiles')
          .doc('site-1_test-user-1')
          .set(
        <String, dynamic>{
          'learnerId': 'test-user-1',
          'siteId': 'site-1',
          'onboardingCompleted': true,
          'weeklyTargetMinutes': 90,
          'reminderSchedule': 'weekdays',
          'valuePrompt': 'I want to build useful things',
        },
      );

      await tester.binding.setSurfaceSize(const Size(1280, 1800));
      await tester.pumpWidget(
        _buildHarness(
          locale: locale,
          child: const LearnerTodayPage(),
          providers: <SingleChildWidget>[
            ChangeNotifierProvider<AppState>.value(value: appState),
            Provider<FirestoreService>.value(value: firestoreService),
            ChangeNotifierProvider<MissionService>.value(value: missionService),
            ChangeNotifierProvider<HabitService>.value(value: habitService),
            ChangeNotifierProvider<MessageService>.value(value: messageService),
            Provider<dynamic>.value(value: null),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Pre-plan reflection'));
      await tester.tap(find.text('Pre-plan reflection'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField).last,
        'I will focus on the first step and ask for help if blocked.',
      );
      await tester.tap(find.text('Save').last);
      await tester.pumpAndSettle();

      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await fakeFirestore.collection('learnerReflections').get();
      expect(snapshot.docs, hasLength(1));
      expect(snapshot.docs.first.data()['reflectionType'], 'pre_plan');
    });

    testWidgets(
        'motivation loop shout-out action writes learner reflection record',
        (WidgetTester tester) async {
      final Locale locale = const Locale('en');
      final FakeFirebaseFirestore fakeFirestore = FakeFirebaseFirestore();
      final FirestoreService firestoreService = FirestoreService(
        firestore: fakeFirestore,
        auth: _MockFirebaseAuth(),
      );
      final AppState appState = _buildAppState(
        role: UserRole.learner,
        locale: locale,
      );
      final MissionService missionService = MissionService(
        firestoreService: firestoreService,
        learnerId: 'test-user-1',
      );
      final HabitService habitService = HabitService(
        firestoreService: firestoreService,
        learnerId: 'test-user-1',
      );
      final MessageService messageService = MessageService(
        firestoreService: firestoreService,
        userId: 'test-user-1',
      );

      await fakeFirestore
          .collection('learnerProfiles')
          .doc('site-1_test-user-1')
          .set(
        <String, dynamic>{
          'learnerId': 'test-user-1',
          'siteId': 'site-1',
          'onboardingCompleted': true,
          'weeklyTargetMinutes': 90,
          'reminderSchedule': 'weekdays',
          'valuePrompt': 'I want to build useful things',
        },
      );

      await tester.binding.setSurfaceSize(const Size(1280, 1800));
      await tester.pumpWidget(
        _buildHarness(
          locale: locale,
          child: const LearnerTodayPage(),
          providers: <SingleChildWidget>[
            ChangeNotifierProvider<AppState>.value(value: appState),
            Provider<FirestoreService>.value(value: firestoreService),
            ChangeNotifierProvider<MissionService>.value(value: missionService),
            ChangeNotifierProvider<HabitService>.value(value: habitService),
            ChangeNotifierProvider<MessageService>.value(value: messageService),
            Provider<dynamic>.value(value: null),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Save shout-out'));
      await tester.tap(find.text('Save shout-out'));
      await tester.pumpAndSettle();

      expect(find.text('Shout-out saved'), findsOneWidget);

      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await fakeFirestore.collection('learnerReflections').get();
      expect(snapshot.docs, hasLength(1));
      expect(snapshot.docs.first.data()['reflectionType'], 'shout_out');
      expect(
        snapshot.docs.first.data()['prompt'],
        'What win are you proud of today?',
      );
    });

    testWidgets('missions study flow controls persist and emit telemetry',
        (WidgetTester tester) async {
      final Locale locale = const Locale('en');
      final FakeFirebaseFirestore fakeFirestore = FakeFirebaseFirestore();
      final FirestoreService firestoreService = FirestoreService(
        firestore: fakeFirestore,
        auth: _MockFirebaseAuth(),
      );
      final AppState appState = _buildAppState(
        role: UserRole.learner,
        locale: locale,
      );
      final MissionService missionService = MissionService(
        firestoreService: firestoreService,
        learnerId: 'test-user-1',
      );
      final List<Map<String, dynamic>> telemetryPayloads =
          <Map<String, dynamic>>[];

      await fakeFirestore
          .collection('missionAssignments')
          .doc('assignment-1')
          .set(
        <String, dynamic>{
          'missionId': 'mission-1',
          'learnerId': 'test-user-1',
          'siteId': 'site-1',
          'status': 'in_progress',
          'progress': 0.5,
        },
      );
      await fakeFirestore
          .collection('missionAssignments')
          .doc('assignment-2')
          .set(
        <String, dynamic>{
          'missionId': 'mission-2',
          'learnerId': 'test-user-1',
          'siteId': 'site-1',
          'status': 'in_progress',
          'progress': 0.2,
        },
      );
      await fakeFirestore.collection('missions').doc('mission-1').set(
        <String, dynamic>{
          'title': 'Mission One',
          'description': 'Description',
          'pillarCode': 'future_skills',
          'difficulty': 'beginner',
          'xpReward': 100,
        },
      );
      await fakeFirestore.collection('missions').doc('mission-2').set(
        <String, dynamic>{
          'title': 'Mission Two',
          'description': 'Description 2',
          'pillarCode': 'future_skills',
          'difficulty': 'intermediate',
          'xpReward': 140,
        },
      );
      await fakeFirestore
          .collection('missions')
          .doc('mission-1')
          .collection('steps')
          .doc('step-1')
          .set(
        <String, dynamic>{
          'title': 'Step One',
          'order': 1,
          'isCompleted': false,
        },
      );

      await tester.binding.setSurfaceSize(const Size(1280, 1800));
      await TelemetryService.runWithDispatcher(
        (Map<String, dynamic> payload) async {
          telemetryPayloads.add(Map<String, dynamic>.from(payload));
        },
        () async {
          await tester.pumpWidget(
            _buildHarness(
              locale: locale,
              child: const MissionsPage(),
              providers: <SingleChildWidget>[
                ChangeNotifierProvider<AppState>.value(value: appState),
                Provider<FirestoreService>.value(value: firestoreService),
                ChangeNotifierProvider<MissionService>.value(
                    value: missionService),
              ],
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 250));
          await tester.pumpAndSettle();

          await tester.tap(find.text('In Progress'));
          await tester.pumpAndSettle();

          await tester.tap(find.text('Mission One').first);
          await tester.pumpAndSettle();

          expect(find.text('Study flow'), findsOneWidget);

          await tester.ensureVisible(find.text('Good').last);
          await tester.tap(find.text('Good').last);
          await tester.pumpAndSettle();

          await tester.ensureVisible(find.text('Snooze 1 day').last);
          await tester.tap(find.text('Snooze 1 day').last);
          await tester.pumpAndSettle();

          await tester.ensureVisible(find.text('Mixed').last);
          await tester.tap(find.text('Scaffolded mix').last);
          await tester.pumpAndSettle();

          expect(find.text('Recommended mix: Mission Two'), findsOneWidget);

          await tester.ensureVisible(find.text('Suspend review queue').last);
          await tester.tap(find.text('Suspend review queue').last);
          await tester.pumpAndSettle();

          await tester.ensureVisible(find.text('Show worked example').last);
          await tester.tap(find.text('Show worked example').last);
          await tester.pumpAndSettle();

          await tester.ensureVisible(find.text('Show next example stage').last);
          await tester.tap(find.text('Show next example stage').last);
          await tester.pumpAndSettle();
        },
      );

      final DocumentSnapshot<Map<String, dynamic>> assignmentDoc =
          await fakeFirestore
              .collection('missionAssignments')
              .doc('assignment-1')
              .get();
      final Map<String, dynamic>? data = assignmentDoc.data();

      expect(data?['fsrsLastRating'], 'good');
      expect(data?['fsrsQueueState'], 'suspended');
      expect(data?['interleavingMode'], 'scaffoldedMixed');
      expect(data?['recommendedInterleavingMissionIds'], contains('mission-2'));
      expect(data?['workedExampleShown'], true);
      expect(data?['workedExampleFadeStage'], 2);
      expect(data?['workedExamplePromptLevel'], 'partialSteps');
      expect(data?.containsKey('nextReviewAt'), isFalse);

      final List<String> emittedEvents = telemetryPayloads
          .map((Map<String, dynamic> payload) => payload['event'] as String?)
          .whereType<String>()
          .toList();
      expect(emittedEvents, contains('fsrs.review.rated'));
      expect(emittedEvents, contains('fsrs.queue.snoozed'));
      expect(emittedEvents, contains('interleaving.mode.changed'));
      expect(emittedEvents, contains('worked_example.shown'));
    });

    testWidgets(
        'missions surface shows keyboard-only alternatives for study flow',
        (WidgetTester tester) async {
      final Locale locale = const Locale('en');
      final FakeFirebaseFirestore fakeFirestore = FakeFirebaseFirestore();
      final FirestoreService firestoreService = FirestoreService(
        firestore: fakeFirestore,
        auth: _MockFirebaseAuth(),
      );
      final AppState appState = _buildAppState(
        role: UserRole.learner,
        locale: locale,
      );
      final MissionService missionService = MissionService(
        firestoreService: firestoreService,
        learnerId: 'test-user-1',
      );

      await fakeFirestore
          .collection('learnerProfiles')
          .doc('site-1_test-user-1')
          .set(
        <String, dynamic>{
          'learnerId': 'test-user-1',
          'siteId': 'site-1',
          'keyboardOnlyEnabled': true,
          'onboardingCompleted': true,
        },
      );
      await fakeFirestore
          .collection('missionAssignments')
          .doc('assignment-1')
          .set(
        <String, dynamic>{
          'missionId': 'mission-1',
          'learnerId': 'test-user-1',
          'siteId': 'site-1',
          'status': 'in_progress',
          'progress': 0.5,
          'interleavingMode': InterleavingMode.focusOnly.name,
        },
      );
      await fakeFirestore.collection('missions').doc('mission-1').set(
        <String, dynamic>{
          'title': 'Robot mission',
          'description': 'Build and test a control loop.',
          'pillarCode': 'future_skills',
          'difficulty': 'beginner',
          'xpReward': 100,
        },
      );
      await fakeFirestore
          .collection('missions')
          .doc('mission-1')
          .collection('steps')
          .doc('step-1')
          .set(
        <String, dynamic>{
          'title': 'Prototype',
          'order': 1,
          'isCompleted': false,
        },
      );

      await tester.binding.setSurfaceSize(const Size(1280, 1800));
      await tester.pumpWidget(
        _buildHarness(
          locale: locale,
          child: const MissionsPage(),
          providers: <SingleChildWidget>[
            ChangeNotifierProvider<AppState>.value(value: appState),
            Provider<FirestoreService>.value(value: firestoreService),
            ChangeNotifierProvider<MissionService>.value(value: missionService),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      await tester.tap(find.text('In Progress'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Robot mission').first);
      await tester.pumpAndSettle();

      expect(find.text('Keyboard-only mission controls'), findsOneWidget);
      expect(find.text('Close mission details'), findsOneWidget);
      expect(find.text('Snooze 1 day'), findsOneWidget);
      expect(find.text('Review in 3 days'), findsOneWidget);
      expect(find.text('Suspend review queue'), findsOneWidget);
    });

    testWidgets('learner today empty cards stay readable in dark theme',
        (WidgetTester tester) async {
      final Locale locale = const Locale('en');
      final FirestoreService firestoreService = FirestoreService(
        firestore: FakeFirebaseFirestore(),
        auth: _MockFirebaseAuth(),
      );
      final AppState appState = _buildAppState(
        role: UserRole.learner,
        locale: locale,
      );
      final HabitService habitService = HabitService(
        firestoreService: firestoreService,
        learnerId: 'test-user-1',
      );
      final MissionService missionService = MissionService(
        firestoreService: firestoreService,
        learnerId: 'test-user-1',
      );
      final MessageService messageService = MessageService(
        firestoreService: firestoreService,
        userId: 'test-user-1',
      );

      await tester.binding.setSurfaceSize(const Size(1280, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _buildHarness(
          locale: locale,
          theme: ScholesaTheme.dark,
          child: const LearnerTodayPage(),
          providers: <SingleChildWidget>[
            ChangeNotifierProvider<AppState>.value(value: appState),
            Provider<FirestoreService>.value(value: firestoreService),
            ChangeNotifierProvider<HabitService>.value(value: habitService),
            ChangeNotifierProvider<MissionService>.value(value: missionService),
            ChangeNotifierProvider<MessageService>.value(value: messageService),
            Provider<dynamic>.value(value: null),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No habits scheduled yet'), findsOneWidget);
      expect(find.text('No active missions yet'), findsOneWidget);
    });

    testWidgets('learner portfolio renders zh-TW copy',
        (WidgetTester tester) async {
      final Locale locale = const Locale('zh', 'TW');
      final FirestoreService firestoreService = FirestoreService(
        firestore: FakeFirebaseFirestore(),
        auth: _MockFirebaseAuth(),
      );
      final AppState appState = _buildAppState(
        role: UserRole.learner,
        locale: locale,
      );

      await tester.binding.setSurfaceSize(const Size(1280, 1800));
      await tester.pumpWidget(
        _buildHarness(
          locale: locale,
          child: const LearnerPortfolioPage(),
          providers: <SingleChildWidget>[
            ChangeNotifierProvider<AppState>.value(value: appState),
            Provider<FirestoreService>.value(value: firestoreService),
            Provider<dynamic>.value(value: null),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('我的作品集'), findsOneWidget);
      expect(find.text('展示你已儲存的作品與憑證'), findsOneWidget);
      expect(find.text('徽章'), findsOneWidget);
    });

    testWidgets('learner credentials renders zh-CN copy',
        (WidgetTester tester) async {
      final Locale locale = const Locale('zh', 'CN');
      final FirestoreService firestoreService = FirestoreService(
        firestore: FakeFirebaseFirestore(),
        auth: _MockFirebaseAuth(),
      );
      final AppState appState = _buildAppState(
        role: UserRole.learner,
        locale: locale,
      );

      await tester.binding.setSurfaceSize(const Size(1280, 1800));
      await tester.pumpWidget(
        _buildHarness(
          locale: locale,
          child: const LearnerCredentialsPage(),
          providers: <SingleChildWidget>[
            ChangeNotifierProvider<AppState>.value(value: appState),
            Provider<FirestoreService>.value(value: firestoreService),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('凭证'), findsOneWidget);
      expect(find.text('还没有已发布的凭证'), findsOneWidget);
      expect(find.text('教育者或站点发布给你的凭证会显示在这里。'), findsOneWidget);
    });

    testWidgets('learner portfolio edit updates the live profile card',
        (WidgetTester tester) async {
      final Locale locale = const Locale('en');
      final FakeFirebaseFirestore fakeFirestore = FakeFirebaseFirestore();
      final FirestoreService firestoreService = FirestoreService(
        firestore: fakeFirestore,
        auth: _MockFirebaseAuth(),
      );
      final AppState appState = _buildAppState(
        role: UserRole.learner,
        locale: locale,
      );

      await tester.binding.setSurfaceSize(const Size(1280, 1800));
      await tester.pumpWidget(
        _buildHarness(
          locale: locale,
          child: const LearnerPortfolioPage(),
          providers: <SingleChildWidget>[
            ChangeNotifierProvider<AppState>.value(value: appState),
            Provider<FirestoreService>.value(value: firestoreService),
            Provider<dynamic>.value(value: null),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.edit).first);
      await tester.pumpAndSettle();

      expect(find.text('Portfolio Headline'), findsOneWidget);
      expect(find.text('Current Goal'), findsOneWidget);
      expect(find.text('Featured Highlight'), findsOneWidget);
      expect(find.text('Emma Johnson'), findsNothing);

      await tester.enterText(
        find.widgetWithText(TextField, 'Portfolio Headline'),
        'Future Skills Builder • site-1',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Current Goal'),
        'Ship one Future Skills prototype this week.',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Featured Highlight'),
        'Latest highlight: Weather Station App',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('Portfolio profile updated.'), findsOneWidget);
      expect(find.text('Future Skills Builder • site-1'), findsOneWidget);
      expect(find.text('Ship one Future Skills prototype this week.'),
          findsOneWidget);
      expect(
          find.text('Latest highlight: Weather Station App'), findsOneWidget);

      final DocumentSnapshot<Map<String, dynamic>> profileDoc =
          await fakeFirestore
              .collection('learnerProfiles')
              .doc('test-user-1')
              .get();
      expect(profileDoc.exists, isTrue);
        expect(
          profileDoc.data()?['portfolioHeadline'], 'Future Skills Builder • site-1');
      expect(
        profileDoc.data()?['portfolioGoal'],
        'Ship one Future Skills prototype this week.',
      );
      expect(
        profileDoc.data()?['portfolioHighlight'],
        'Latest highlight: Weather Station App',
      );
    });

    testWidgets(
        'learner portfolio shows saved project artifacts instead of sample projects',
        (WidgetTester tester) async {
      final Locale locale = const Locale('en');
      final FakeFirebaseFirestore fakeFirestore = FakeFirebaseFirestore();
      await fakeFirestore.collection('portfolioItems').doc('artifact-1').set(
        <String, dynamic>{
          'learnerId': 'test-user-1',
          'siteId': 'site-1',
          'title': 'Solar Oven Prototype',
          'description': 'Built and tested a solar cooker.',
          'pillarCodes': <String>['impact'],
          'createdAt': Timestamp.fromDate(DateTime(2026, 3, 17, 9)),
          'updatedAt': Timestamp.fromDate(DateTime(2026, 3, 17, 10)),
        },
      );
      final FirestoreService firestoreService = FirestoreService(
        firestore: fakeFirestore,
        auth: _MockFirebaseAuth(),
      );
      final AppState appState = _buildAppState(
        role: UserRole.learner,
        locale: locale,
      );

      await tester.binding.setSurfaceSize(const Size(1280, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _buildHarness(
          locale: locale,
          child: LearnerPortfolioPage(
            portfolioStateLoader: (String learnerId, String siteId) async =>
                LearnerPortfolioSnapshot(
              items: <PortfolioItemModel>[
                PortfolioItemModel(
                  id: 'artifact-1',
                  learnerId: learnerId,
                  siteId: siteId,
                  title: 'Solar Oven Prototype',
                  description: 'Built and tested a solar cooker.',
                  pillarCodes: <String>['impact'],
                  createdAt: Timestamp.fromDate(DateTime(2026, 3, 17, 9)),
                  updatedAt: Timestamp.fromDate(DateTime(2026, 3, 17, 10)),
                ),
              ],
            ),
          ),
          providers: <SingleChildWidget>[
            ChangeNotifierProvider<AppState>.value(value: appState),
            Provider<FirestoreService>.value(value: firestoreService),
            Provider<dynamic>.value(value: null),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(Tab, 'Projects'));
      await tester.pumpAndSettle();

      expect(find.text('Solar Oven Prototype'), findsOneWidget);
      expect(find.text('Built and tested a solar cooker.'), findsOneWidget);
      expect(find.text('Weather Station App'), findsNothing);
    });

    testWidgets('learner portfolio share copies a real summary to clipboard',
        (WidgetTester tester) async {
      final Locale locale = const Locale('en');
      final FirestoreService firestoreService = FirestoreService(
        firestore: FakeFirebaseFirestore(),
        auth: _MockFirebaseAuth(),
      );
      final AppState appState = _buildAppState(
        role: UserRole.learner,
        locale: locale,
      );

      await tester.binding.setSurfaceSize(const Size(1280, 1800));
      await tester.pumpWidget(
        _buildHarness(
          locale: locale,
          child: const LearnerPortfolioPage(),
          providers: <SingleChildWidget>[
            ChangeNotifierProvider<AppState>.value(value: appState),
            Provider<FirestoreService>.value(value: firestoreService),
            Provider<dynamic>.value(value: null),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(
          find.text('Portfolio summary copied for sharing.'), findsOneWidget);
      expect(_portfolioClipboardText, isNotNull);
      expect(_portfolioClipboardText, contains('Share Portfolio'));
      expect(_portfolioClipboardText, contains('Test User'));
    });

    testWidgets('site sessions renders zh-CN copy',
        (WidgetTester tester) async {
      final Locale locale = const Locale('zh', 'CN');
      final FirestoreService firestoreService = FirestoreService(
        firestore: FakeFirebaseFirestore(),
        auth: _MockFirebaseAuth(),
      );
      final AppState appState = _buildAppState(
        role: UserRole.site,
        locale: locale,
      );

      await tester.binding.setSurfaceSize(const Size(1280, 1800));
      await tester.pumpWidget(
        _buildHarness(
          locale: locale,
          child: const SiteSessionsPage(),
          providers: <SingleChildWidget>[
            ChangeNotifierProvider<AppState>.value(value: appState),
            Provider<FirestoreService>.value(value: firestoreService),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('课程日程'), findsOneWidget);
      expect(find.text('管理站点课程和教室'), findsOneWidget);
      expect(find.text('新建课程'), findsOneWidget);
    });

    testWidgets('site ops renders zh-TW copy', (WidgetTester tester) async {
      final Locale locale = const Locale('zh', 'TW');
      final FirestoreService firestoreService = FirestoreService(
        firestore: FakeFirebaseFirestore(),
        auth: _MockFirebaseAuth(),
      );
      final AppState appState = _buildAppState(
        role: UserRole.site,
        locale: locale,
      );

      await tester.binding.setSurfaceSize(const Size(1280, 1800));
      await tester.pumpWidget(
        _buildHarness(
          locale: locale,
          child: const SiteOpsPage(),
          providers: <SingleChildWidget>[
            ChangeNotifierProvider<AppState>.value(value: appState),
            Provider<FirestoreService>.value(value: firestoreService),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('今日營運'), findsOneWidget);
      expect(find.text('聯邦執行階段'), findsOneWidget);
      expect(find.text('快捷操作'), findsOneWidget);
      expect(find.text('最近活動'), findsOneWidget);
    });

    testWidgets('site incidents renders zh-CN copy',
        (WidgetTester tester) async {
      final Locale locale = const Locale('zh', 'CN');
      final FakeFirebaseFirestore fakeFirestore = FakeFirebaseFirestore();
      await fakeFirestore.collection('incidents').doc('incident-1').set(
        <String, dynamic>{
          'siteId': 'site-1',
          'title': 'Playground incident',
          'severity': 'minor',
          'status': 'submitted',
          'reportedAt': DateTime(2026, 3, 17, 9).millisecondsSinceEpoch,
        },
      );
      final FirestoreService firestoreService = FirestoreService(
        firestore: fakeFirestore,
        auth: _MockFirebaseAuth(),
      );
      final AppState appState = _buildAppState(
        role: UserRole.site,
        locale: locale,
      );

      await tester.binding.setSurfaceSize(const Size(1280, 1800));
      await tester.pumpWidget(
        _buildHarness(
          locale: locale,
          child: const SiteIncidentsPage(),
          providers: <SingleChildWidget>[
            ChangeNotifierProvider<AppState>.value(value: appState),
            Provider<FirestoreService>.value(value: firestoreService),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('安全与事件'), findsOneWidget);
      expect(find.text('报告事件'), findsOneWidget);
      expect(find.text('Playground incident'), findsOneWidget);
      expect(find.textContaining('学习者信息不可用'), findsOneWidget);
      expect(find.textContaining('报告人信息不可用'), findsOneWidget);
      expect(find.text('未知'), findsNothing);
    });
  });
}
