import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/modules/educator/educator_learners_page.dart';
import 'package:scholesa_app/modules/educator/educator_service.dart';
import 'package:scholesa_app/services/export_service.dart';
import 'package:scholesa_app/services/firestore_service.dart';
import 'package:scholesa_app/ui/theme/scholesa_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

    testWidgets(
      'educator learner detail saves lane override, printable practice export, and persisted follow-up request',
      (WidgetTester tester) async {
    String? savedFileName;
    String? savedFileContent;
    ExportService.instance.debugSaveTextFile = ({
      required String fileName,
      required String content,
      required String mimeType,
    }) async {
      savedFileName = fileName;
      savedFileContent = content;
      return '/tmp/$fileName';
    };
    addTearDown(() => ExportService.instance.debugSaveTextFile = null);
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
    await tester.pumpAndSettle();
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
    await tester.pumpAndSettle();

    expect(savedFileName, 'practice-plan-learner-1-core.txt');
    expect(savedFileContent, isNotNull);
    expect(savedFileContent, contains('Learner: Learner One'));

    await tester.dragUntilVisible(
      find.text('Learner follow-up'),
      find.byType(Scrollable).last,
      const Offset(0, -120),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Learner follow-up'), findsOneWidget);
    expect(
      find.text('Request family or support-team follow-up for this learner.'),
      findsOneWidget,
    );

    await tester.enterText(
      find.byType(TextField).last,
      'Please contact family and learner support team about attendance drop and move to core lane check-in next week.',
    );
    await tester.ensureVisible(find.text('Request follow-up'));
    await tester.tap(find.text('Request follow-up'));
    await tester.pumpAndSettle();

    expect(find.text('Learner follow-up request submitted.'), findsOneWidget);

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
    expect(savedFileContent, contains('Differentiation lane: Core lane'));

    final supportRequests = await firestore.collection('supportRequests').get();
    expect(supportRequests.docs.length, 1);
    expect(supportRequests.docs.first.data()['requestType'], 'learner_follow_up');
    expect(
      supportRequests.docs.first.data()['source'],
      'educator_learner_detail_request_follow_up',
    );
    expect(
      supportRequests.docs.first.data()['metadata']?['learnerId'],
      'learner-1',
    );
    expect(
      supportRequests.docs.first.data()['metadata']?['selectedLane'],
      'core',
    );
    expect(
      supportRequests.docs.first.data()['message'],
      'Please contact family and learner support team about attendance drop and move to core lane check-in next week.',
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
    await tester.pumpAndSettle();

    expect(find.text('Learner unavailable'), findsWidgets);
    expect(find.text('Unknown'), findsNothing);
  });

  testWidgets(
      'educator learner detail copies practice plan when file export is unsupported',
      (WidgetTester tester) async {
    String? copiedText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall methodCall) async {
        if (methodCall.method == 'Clipboard.setData') {
          final Object? args = methodCall.arguments;
          if (args is Map) {
            copiedText = args['text'] as String?;
          }
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    ExportService.instance.debugSaveTextFile = ({
      required String fileName,
      required String content,
      required String mimeType,
    }) async {
      throw UnsupportedError('File export is not supported on this platform.');
    };
    addTearDown(() => ExportService.instance.debugSaveTextFile = null);

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
        child: const EducatorLearnersPage(),
        providers: <SingleChildWidget>[
          Provider<FirestoreService>.value(value: firestoreService),
          ChangeNotifierProvider<AppState>.value(value: _buildEducatorState()),
          ChangeNotifierProvider<EducatorService>.value(value: educatorService),
        ],
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Learner One'));
    await tester.pump(const Duration(milliseconds: 400));

    await tester.dragUntilVisible(
      find.text('Export practice plan'),
      find.byType(Scrollable).last,
      const Offset(0, -120),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.ensureVisible(find.text('Export practice plan'));
    await tester.tap(find.text('Export practice plan'));
    await tester.pumpAndSettle();

    expect(find.text('Practice plan copied for sharing.'), findsOneWidget);
    expect(copiedText, contains('Learner: Learner One'));
    expect(copiedText, contains('Differentiation lane: Scaffolded lane'));

    final practiceExports = await firestore.collection('practiceExports').get();
    expect(practiceExports.docs.length, 1);
  });
}
