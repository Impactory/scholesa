import 'package:cloud_firestore/cloud_firestore.dart';
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
import 'package:scholesa_app/modules/educator/educator_mission_review_page.dart';
import 'package:scholesa_app/modules/hq_admin/hq_analytics_page.dart';
import 'package:scholesa_app/modules/missions/mission_service.dart';
import 'package:scholesa_app/modules/missions/missions_page.dart';
import 'package:scholesa_app/services/analytics_service.dart';
import 'package:scholesa_app/services/export_service.dart';
import 'package:scholesa_app/services/firestore_service.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

String? _savedFileName;
String? _savedFileContent;

AppState _buildHqState() {
  final AppState state = AppState();
  state.updateFromMeResponse(<String, dynamic>{
    'userId': 'hq-user-1',
    'email': 'hq@scholesa.dev',
    'displayName': 'HQ Admin',
    'role': 'hq',
    'activeSiteId': 'site-1',
    'siteIds': <String>['site-1', 'site-2'],
    'entitlements': <dynamic>[],
  });
  return state;
}

AppState _buildLearnerState({
  String userId = 'learner-analytics-1',
  String email = 'nia.analytics@example.com',
  String displayName = 'Nia Analytics',
}) {
  final AppState state = AppState();
  state.updateFromMeResponse(<String, dynamic>{
    'userId': userId,
    'email': email,
    'displayName': displayName,
    'role': 'learner',
    'activeSiteId': 'site-1',
    'siteIds': <String>['site-1'],
    'entitlements': <dynamic>[],
  });
  return state;
}

AppState _buildEducatorState() {
  final AppState state = AppState();
  state.updateFromMeResponse(<String, dynamic>{
    'userId': 'educator-1',
    'email': 'educator-1@scholesa.test',
    'displayName': 'Educator One',
    'role': 'educator',
    'activeSiteId': 'site-1',
    'siteIds': <String>['site-1'],
    'entitlements': <dynamic>[],
  });
  return state;
}

Future<void> _seedAnalyticsData(FakeFirebaseFirestore firestore) async {
  await firestore.collection('sites').doc('site-1').set(<String, dynamic>{
    'name': 'North Hub',
    'learnerCount': 40,
    'educatorCount': 4,
    'healthScore': 96,
  });
  await firestore.collection('sites').doc('site-2').set(<String, dynamic>{
    'name': 'South Hub',
    'learnerCount': 24,
    'educatorCount': 3,
    'healthScore': 81,
  });

  await firestore.collection('missions').doc('mission-1').set(<String, dynamic>{
    'siteId': 'site-1',
    'pillar': 'Future Skills',
  });
  await firestore.collection('missions').doc('mission-2').set(<String, dynamic>{
    'siteId': 'site-2',
    'pillar': 'Leadership',
  });

  await firestore.collection('users').doc('learner-1').set(<String, dynamic>{
    'uid': 'learner-1',
    'displayName': 'Luna Learner',
  });
  await firestore.collection('users').doc('learner-2').set(<String, dynamic>{
    'uid': 'learner-2',
    'displayName': 'Kai Builder',
  });

  await firestore
      .collection('missionAttempts')
      .doc('attempt-1')
      .set(<String, dynamic>{
    'siteId': 'site-1',
    'learnerId': 'learner-1',
    'missionId': 'mission-1',
    'status': 'completed',
    'createdAt': Timestamp.fromDate(DateTime(2026, 3, 12, 9)),
  });
  await firestore
      .collection('missionAttempts')
      .doc('attempt-2')
      .set(<String, dynamic>{
    'siteId': 'site-1',
    'learnerId': 'learner-1',
    'missionId': 'mission-1',
    'status': 'completed',
    'createdAt': Timestamp.fromDate(DateTime(2026, 3, 13, 9)),
  });
  await firestore
      .collection('missionAttempts')
      .doc('attempt-3')
      .set(<String, dynamic>{
    'siteId': 'site-2',
    'learnerId': 'learner-2',
    'missionId': 'mission-2',
    'status': 'in_progress',
    'createdAt': Timestamp.fromDate(DateTime(2026, 3, 13, 10)),
  });

  await firestore
      .collection('telemetryEvents')
      .doc('feedback-1')
      .set(<String, dynamic>{
    'eventType': 'bos_mia.usability.feedback',
    'siteId': 'site-1',
    'timestamp':
        Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 1))),
    'metadata': <String, dynamic>{
      'usability_score': 5,
      'usefulness_score': 4,
      'reliability_score': 4,
      'voice_quality_score': 5,
      'rollout_recommendation': 'scale_with_guardrails',
      'top_issues': <String>['Need more drilldowns'],
    },
  });
}

Future<void> _seedMissionReadyForReviewData(
  FakeFirebaseFirestore firestore, {
  required String learnerId,
  required String learnerName,
}) async {
  await firestore.collection('sites').doc('site-1').set(<String, dynamic>{
    'name': 'North Hub',
    'learnerCount': 1,
    'educatorCount': 1,
    'healthScore': 94,
  });
  await firestore.collection('users').doc(learnerId).set(<String, dynamic>{
    'uid': learnerId,
    'displayName': learnerName,
    'role': 'learner',
    'siteIds': <String>['site-1'],
  });
  await firestore.collection('missionAssignments').doc('assignment-1').set(
    <String, dynamic>{
      'missionId': 'mission-1',
      'learnerId': learnerId,
      'siteId': 'site-1',
      'status': 'in_progress',
      'progress': 1.0,
    },
  );
  await firestore.collection('missions').doc('mission-1').set(<String, dynamic>{
    'siteId': 'site-1',
    'title': 'Mission ready for review',
    'description': 'Capture proof of learning before review.',
    'pillarCode': 'future_skills',
    'difficulty': 'beginner',
    'xpReward': 120,
  });
  await firestore
      .collection('missions')
      .doc('mission-1')
      .collection('steps')
      .doc('step-1')
      .set(
    <String, dynamic>{
      'title': 'Prototype',
      'order': 1,
      'isCompleted': true,
      'completedAt': '2026-03-18T10:00:00.000Z',
    },
  );
}

Widget _buildLearnerMissionHarness({
  required FirestoreService firestoreService,
  required MissionService missionService,
  required AppState appState,
}) {
  return MultiProvider(
    providers: <SingleChildWidget>[
      ChangeNotifierProvider<AppState>.value(value: appState),
      Provider<FirestoreService>.value(value: firestoreService),
      ChangeNotifierProvider<MissionService>.value(value: missionService),
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
      supportedLocales: const <Locale>[
        Locale('en'),
        Locale('zh', 'CN'),
        Locale('zh', 'TW'),
      ],
      home: const MissionsPage(),
    ),
  );
}

Widget _buildEducatorReviewHarness({
  required MissionService missionService,
}) {
  return MultiProvider(
    providers: <SingleChildWidget>[
      ChangeNotifierProvider<AppState>.value(value: _buildEducatorState()),
      ChangeNotifierProvider<MissionService>.value(value: missionService),
    ],
    child: MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        splashFactory: NoSplash.splashFactory,
      ),
      home: const EducatorMissionReviewPage(),
    ),
  );
}

Future<void> _submitMissionForReviewViaPage(
  WidgetTester tester, {
  required FirestoreService firestoreService,
  required MissionService missionService,
  required AppState appState,
}) async {
  await tester.pumpWidget(
    _buildLearnerMissionHarness(
      firestoreService: firestoreService,
      missionService: missionService,
      appState: appState,
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
  await tester.pumpAndSettle();

  await tester.tap(find.text('In Progress'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Mission ready for review').first);
  await tester.pumpAndSettle();

  await tester.scrollUntilVisible(
    find.text('No AI support used for this mission'),
    200,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.tap(find.text('No AI support used for this mission'));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.widgetWithText(TextField, 'Explain-it-back summary'),
    'I explained how the prototype responded to the evidence.',
  );
  await tester.enterText(
    find.widgetWithText(TextField, 'Oral check reflection'),
    'I described why this version was more stable.',
  );
  await tester.enterText(
    find.widgetWithText(TextField, 'Mini-rebuild plan'),
    'I would rebuild the sensing step first and retest.',
  );
  await tester.enterText(
    find.widgetWithText(TextField, 'Version checkpoint summary'),
    'Completed the working prototype before review.',
  );

  await tester.scrollUntilVisible(
    find.text('Save Checkpoint'),
    200,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.tap(find.text('Save Checkpoint'));
  await tester.pump();
  await tester.pumpAndSettle();

  await tester.scrollUntilVisible(
    find.text('Submit for Review'),
    200,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.tap(find.text('Submit for Review'));
  await tester.pump();
  await tester.pumpAndSettle();
}

Future<void> _approveMissionViaReviewPage(
  WidgetTester tester, {
  required MissionService missionService,
}) async {
  await tester.pumpWidget(
    _buildEducatorReviewHarness(missionService: missionService),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pumpAndSettle();

  await tester.tap(find.text('Mission ready for review').first);
  await tester.pumpAndSettle();

  await tester.enterText(
    find.byType(TextField).last,
    'Your explanation matched the evidence and review requirements.',
  );
  await tester.scrollUntilVisible(
    find.text('Approve'),
    250,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.tap(find.text('Approve'));
  await tester.pump();
  await tester.pumpAndSettle();
}

Widget _buildAnalyticsHarness({
  required FirestoreService firestoreService,
  required Widget child,
}) {
  return MultiProvider(
    providers: <SingleChildWidget>[
      Provider<FirestoreService>.value(value: firestoreService),
      ChangeNotifierProvider<AppState>.value(value: _buildHqState()),
    ],
    child: MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        splashFactory: NoSplash.splashFactory,
      ),
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _savedFileName = null;
    _savedFileContent = null;
    ExportService.instance.debugSaveTextFile = null;
  });

  testWidgets('hq analytics page consumes KPI metrics and supplemental data',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await _seedAnalyticsData(firestore);
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: <SingleChildWidget>[
          Provider<FirestoreService>.value(value: firestoreService),
          ChangeNotifierProvider<AppState>.value(value: _buildHqState()),
        ],
        child: MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            splashFactory: NoSplash.splashFactory,
          ),
          home: HqAnalyticsPage(
            metricsLoader: ({String? siteId, String period = 'month'}) async {
              return const TelemetryDashboardMetrics(
                weeklyAccountabilityAdherenceRate: 91.0,
                educatorReviewTurnaroundHoursAvg: 18.5,
                educatorReviewWithinSlaRate: 87.0,
                educatorReviewSlaHours: 48,
                interventionHelpedRate: 72.0,
                interventionTotal: 11,
                attendanceTrend: <AttendanceTrendPoint>[
                  AttendanceTrendPoint(
                    date: '2026-03-10',
                    records: 20,
                    events: 2,
                    presentRate: 88,
                  ),
                  AttendanceTrendPoint(
                    date: '2026-03-11',
                    records: 22,
                    events: 2,
                    presentRate: 91,
                  ),
                ],
              );
            },
            kpiPacksLoader: ({String? siteId, int limit = 24}) async =>
                <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'pack-1',
                'title': 'North Hub Pack',
                'siteId': 'site-1',
                'period': 'month',
                'recommendation': 'scale',
                'fidelityScore': 92.0,
                'portfolioQualityGrade': 'A',
                'updatedAt': DateTime(2026, 3, 14).toIso8601String(),
              },
            ],
            syntheticImportLoader: () async => <String, dynamic>{
              'summaryLabel': 'Starter + full synthetic packs',
              'mode': 'all',
              'sourcePacks': <String>['starter', 'full'],
              'importedAt': DateTime(2026, 3, 15, 12).toIso8601String(),
              'sourceCounts': <String, dynamic>{
                'starterBootstrapRows': 2400,
                'starterChallengeRows': 240,
                'fullCoreEvidenceRows': 14400,
                'fullSuiteRows': 46672,
              },
              'nativeCounts': <String, dynamic>{
                'users': 2900,
                'interactionEvents': 93610,
                'portfolioItems': 13165,
                'syntheticDatasetImports': 2,
                'missionAttempts': 16800,
              },
              'bosMiaTraining': <String, dynamic>{
                'modelVersion': 'synthetic-bos-mia-starter-full-v1',
                'trainingRunId': 'bos-mia-synthetic-2026-03-15T12-00-00-000Z',
                'trainedAt': DateTime(2026, 3, 15, 12).toIso8601String(),
                'calibratedGradeBands': 4,
                'trainingRows': 17040,
                'goldEvalCases': 1280,
                'actionAccuracy': 0.914,
                'reviewPrecision': 0.882,
                'reviewRecall': 0.901,
              },
            },
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Account menu'), findsOneWidget);
    expect(find.text('Platform Analytics'), findsOneWidget);
    expect(find.text('Telemetry KPIs'), findsOneWidget);
    expect(find.text('91.0%'), findsOneWidget);
    expect(find.text('KPI Packs'), findsOneWidget);
    expect(find.text('North Hub Pack'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Synthetic Data'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Synthetic Data'), findsOneWidget);
    expect(find.text('Starter + full synthetic packs'), findsOneWidget);
    expect(find.text('17040'), findsOneWidget);
    expect(find.text('Synthetic AI help training'), findsOneWidget);
    expect(
      find.textContaining('synthetic-bos-mia-starter-full-v1'),
      findsOneWidget,
    );
    expect(find.text('91.4%'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Site Comparison'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Site Comparison'), findsOneWidget);
    expect(find.text('North Hub'), findsWidgets);
    expect(find.text('Top Performers'), findsOneWidget);
    expect(find.text('Luna Learner'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('HQ AI help feedback'),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('HQ AI help feedback'), findsOneWidget);
  });

  testWidgets(
      'hq analytics top performers reflect reviewed learner work from the live learner and educator workflow',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await _seedMissionReadyForReviewData(
      firestore,
      learnerId: 'learner-analytics-1',
      learnerName: 'Nia Analytics',
    );
    await firestore.collection('users').doc('learner-unfinished-1').set(
      <String, dynamic>{
        'uid': 'learner-unfinished-1',
        'displayName': 'Uma Unfinished',
        'role': 'learner',
        'siteIds': <String>['site-1'],
      },
    );
    await firestore.collection('missionAttempts').doc('unfinished-attempt-1').set(
      <String, dynamic>{
        'siteId': 'site-1',
        'learnerId': 'learner-unfinished-1',
        'missionId': 'mission-1',
        'status': 'submitted',
        'submittedAt': Timestamp.fromDate(DateTime(2026, 3, 18, 11)),
        'createdAt': Timestamp.fromDate(DateTime(2026, 3, 18, 11)),
      },
    );
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );

    await _submitMissionForReviewViaPage(
      tester,
      firestoreService: firestoreService,
      missionService: MissionService(
        firestoreService: firestoreService,
        learnerId: 'learner-analytics-1',
      ),
      appState: _buildLearnerState(),
    );

    await _approveMissionViaReviewPage(
      tester,
      missionService: MissionService(
        firestoreService: firestoreService,
        learnerId: 'educator-1',
      ),
    );

    final QuerySnapshot<Map<String, dynamic>> attempts = await firestore
        .collection('missionAttempts')
        .where('learnerId', isEqualTo: 'learner-analytics-1')
        .get();
    expect(attempts.docs, hasLength(1));
    expect(attempts.docs.single.data()['status'], 'reviewed');

    await tester.pumpWidget(
      _buildAnalyticsHarness(
        firestoreService: firestoreService,
        child: HqAnalyticsPage(
          metricsLoader: ({String? siteId, String period = 'month'}) async {
            return const TelemetryDashboardMetrics(
              weeklyAccountabilityAdherenceRate: 91.0,
              educatorReviewTurnaroundHoursAvg: 18.5,
              educatorReviewWithinSlaRate: 87.0,
              educatorReviewSlaHours: 48,
              interventionHelpedRate: 72.0,
              interventionTotal: 11,
              attendanceTrend: <AttendanceTrendPoint>[],
            );
          },
          kpiPacksLoader: ({String? siteId, int limit = 24}) async =>
              <Map<String, dynamic>>[],
          syntheticImportLoader: () async => null,
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Top Performers'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Top Performers'), findsOneWidget);
    expect(find.text('Nia Analytics'), findsOneWidget);
    expect(find.text('North Hub'), findsWidgets);
    expect(find.text('1 reviewed'), findsOneWidget);
    expect(find.text('Uma Unfinished'), findsNothing);
    expect(find.text('No top performers available'), findsNothing);
  });

  testWidgets(
      'hq analytics page does not fabricate zero attendance when rates are missing',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: <SingleChildWidget>[
          Provider<FirestoreService>.value(value: firestoreService),
          ChangeNotifierProvider<AppState>.value(value: _buildHqState()),
        ],
        child: MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            splashFactory: NoSplash.splashFactory,
          ),
          home: HqAnalyticsPage(
            metricsLoader: ({String? siteId, String period = 'month'}) async {
              return const TelemetryDashboardMetrics(
                weeklyAccountabilityAdherenceRate: 91.0,
                educatorReviewTurnaroundHoursAvg: 18.5,
                educatorReviewWithinSlaRate: 87.0,
                educatorReviewSlaHours: 48,
                interventionHelpedRate: 72.0,
                interventionTotal: 11,
                attendanceTrend: <AttendanceTrendPoint>[
                  AttendanceTrendPoint(
                    date: '2026-03-10',
                    records: 20,
                    events: 2,
                  ),
                ],
              );
            },
            kpiPacksLoader: ({String? siteId, int limit = 24}) async =>
                const <Map<String, dynamic>>[],
            syntheticImportLoader: () async => null,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Attendance Trend'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Attendance rate unavailable for this period'),
        findsOneWidget);
    expect(find.text('Latest attendance: 0.0%'), findsNothing);
  });

  testWidgets('hq analytics export downloads the live dashboard snapshot',
      (WidgetTester tester) async {
    ExportService.instance.debugSaveTextFile = ({
      required String fileName,
      required String content,
      required String mimeType,
    }) async {
      _savedFileName = fileName;
      _savedFileContent = content;
      return '/tmp/$fileName';
    };
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: <SingleChildWidget>[
          Provider<FirestoreService>.value(value: firestoreService),
          ChangeNotifierProvider<AppState>.value(value: _buildHqState()),
        ],
        child: MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            splashFactory: NoSplash.splashFactory,
          ),
          home: HqAnalyticsPage(
            metricsLoader: ({String? siteId, String period = 'month'}) async {
              return const TelemetryDashboardMetrics(
                weeklyAccountabilityAdherenceRate: 91.0,
                educatorReviewTurnaroundHoursAvg: 18.5,
                educatorReviewWithinSlaRate: 87.0,
                educatorReviewSlaHours: 48,
                interventionHelpedRate: 72.0,
                interventionTotal: 11,
                attendanceTrend: <AttendanceTrendPoint>[],
              );
            },
            supplementalLoader: ({String selectedSite = 'all'}) async =>
                const HqAnalyticsSupplementalSnapshot(
                  topPerformers: <Map<String, dynamic>>[
                    <String, dynamic>{
                      'rank': 1,
                      'name': 'Nia Analytics',
                      'site': 'North Hub',
                      'reviewedEvidenceCount': 2,
                      'capabilityUpdates': 1,
                      'reviewedDays': 1,
                      'latestCapabilityTitle': 'Evidence-backed reasoning',
                      'latestCapabilityLevel': 3,
                    },
                  ],
                ),
            kpiPacksLoader: ({String? siteId, int limit = 24}) async =>
                <Map<String, dynamic>>[],
            syntheticImportLoader: () async => null,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.download));
    await tester.pumpAndSettle();

    expect(find.text('Export HQ Analytics'), findsNothing);
    expect(find.text('HQ analytics export downloaded.'), findsOneWidget);
    expect(_savedFileName, contains('hq-analytics'));
    expect(_savedFileContent, isNotNull);
    expect(_savedFileContent, contains('Export HQ Analytics'));
    expect(
      _savedFileContent,
      contains('Weekly accountability adherence: 91.0%'),
    );
    expect(_savedFileContent, contains('reviewedEvidence=2'));
    expect(_savedFileContent, contains('capabilityUpdates=1'));
    expect(
      _savedFileContent,
      contains('latestCapability=Evidence-backed reasoning | level=3/4'),
    );
    expect(_savedFileContent, isNot(contains('missions=2')));
  });

  testWidgets('hq analytics export copies content when file export is unsupported',
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

    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    ExportService.instance.debugSaveTextFile = ({
      required String fileName,
      required String content,
      required String mimeType,
    }) async {
      throw UnsupportedError('File export is not supported on this platform.');
    };

    await tester.pumpWidget(
      MultiProvider(
        providers: <SingleChildWidget>[
          Provider<FirestoreService>.value(value: firestoreService),
          ChangeNotifierProvider<AppState>.value(value: _buildHqState()),
        ],
        child: MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            splashFactory: NoSplash.splashFactory,
          ),
          home: HqAnalyticsPage(
            metricsLoader: ({String? siteId, String period = 'month'}) async {
              return const TelemetryDashboardMetrics(
                weeklyAccountabilityAdherenceRate: 91.0,
                educatorReviewTurnaroundHoursAvg: 18.5,
                educatorReviewWithinSlaRate: 87.0,
                educatorReviewSlaHours: 48,
                interventionHelpedRate: 72.0,
                interventionTotal: 11,
                attendanceTrend: <AttendanceTrendPoint>[],
              );
            },
            kpiPacksLoader: ({String? siteId, int limit = 24}) async =>
                <Map<String, dynamic>>[],
            syntheticImportLoader: () async => null,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.download));
    await tester.pumpAndSettle();

    expect(find.text('HQ analytics export copied to clipboard.'), findsOneWidget);
    expect(copiedText, contains('Export HQ Analytics'));
    expect(copiedText, contains('Weekly accountability adherence: 91.0%'));
  });

  testWidgets('hq analytics shows explicit unavailable state when telemetry metrics fail to load',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );

    await tester.pumpWidget(
      _buildAnalyticsHarness(
        firestoreService: firestoreService,
        child: HqAnalyticsPage(
          metricsLoader: ({String? siteId, String period = 'month'}) async {
            throw Exception('metrics down');
          },
          supplementalLoader: ({String selectedSite = 'all'}) async =>
              const HqAnalyticsSupplementalSnapshot(),
          kpiPacksLoader: ({String? siteId, int limit = 24}) async =>
              const <Map<String, dynamic>>[],
          syntheticImportLoader: () async => null,
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Telemetry metrics are temporarily unavailable'), findsOneWidget);
    expect(
      find.text('We could not load telemetry metrics right now. Retry to check the current state.'),
      findsOneWidget,
    );
    expect(find.text('Waiting for first app telemetry sync.'), findsNothing);
  });

  testWidgets('hq analytics keeps stale telemetry metrics visible after refresh failure',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    int metricsCalls = 0;

    await tester.pumpWidget(
      _buildAnalyticsHarness(
        firestoreService: firestoreService,
        child: HqAnalyticsPage(
          metricsLoader: ({String? siteId, String period = 'month'}) async {
            metricsCalls += 1;
            if (metricsCalls > 1) {
              throw Exception('metrics refresh failed');
            }
            return const TelemetryDashboardMetrics(
              weeklyAccountabilityAdherenceRate: 91.0,
              educatorReviewTurnaroundHoursAvg: 18.5,
              educatorReviewWithinSlaRate: 87.0,
              educatorReviewSlaHours: 48,
              interventionHelpedRate: 72.0,
              interventionTotal: 11,
              attendanceTrend: <AttendanceTrendPoint>[
                AttendanceTrendPoint(
                  date: '2026-03-10',
                  records: 20,
                  events: 2,
                  presentRate: 88,
                ),
              ],
            );
          },
          supplementalLoader: ({String selectedSite = 'all'}) async =>
              const HqAnalyticsSupplementalSnapshot(),
          kpiPacksLoader: ({String? siteId, int limit = 24}) async =>
              const <Map<String, dynamic>>[],
          syntheticImportLoader: () async => null,
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('91.0%'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.refresh_rounded).first);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.text('Unable to refresh telemetry metrics right now. Showing the last successful data.'),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.text('Attendance Trend'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Showing last successful attendance trend'), findsOneWidget);
    expect(find.text('Attendance data unavailable'), findsNothing);
  });

  testWidgets('hq analytics shows explicit unavailable state when supplemental analytics fail to load',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );

    await tester.pumpWidget(
      _buildAnalyticsHarness(
        firestoreService: firestoreService,
        child: HqAnalyticsPage(
          metricsLoader: ({String? siteId, String period = 'month'}) async {
            return const TelemetryDashboardMetrics(
              weeklyAccountabilityAdherenceRate: 91.0,
              educatorReviewTurnaroundHoursAvg: 18.5,
              educatorReviewWithinSlaRate: 87.0,
              educatorReviewSlaHours: 48,
              interventionHelpedRate: 72.0,
              interventionTotal: 11,
              attendanceTrend: <AttendanceTrendPoint>[],
            );
          },
          supplementalLoader: ({String selectedSite = 'all'}) async {
            throw Exception('supplemental down');
          },
          kpiPacksLoader: ({String? siteId, int limit = 24}) async =>
              const <Map<String, dynamic>>[],
          syntheticImportLoader: () async => null,
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Supplemental analytics are temporarily unavailable'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Supplemental analytics are temporarily unavailable'), findsOneWidget);
    expect(
      find.text('We could not load supplemental analytics right now. Retry to check the current state.'),
      findsWidgets,
    );
    expect(find.text('No pillar data available'), findsNothing);
    expect(find.text('No comparison data available'), findsNothing);
    expect(find.text('No top performers available'), findsNothing);
  });

  testWidgets('hq analytics keeps stale supplemental analytics visible after refresh failure',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1800));
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    int supplementalCalls = 0;

    await tester.pumpWidget(
      _buildAnalyticsHarness(
        firestoreService: firestoreService,
        child: HqAnalyticsPage(
          metricsLoader: ({String? siteId, String period = 'month'}) async {
            return const TelemetryDashboardMetrics(
              weeklyAccountabilityAdherenceRate: 91.0,
              educatorReviewTurnaroundHoursAvg: 18.5,
              educatorReviewWithinSlaRate: 87.0,
              educatorReviewSlaHours: 48,
              interventionHelpedRate: 72.0,
              interventionTotal: 11,
              attendanceTrend: <AttendanceTrendPoint>[],
            );
          },
          supplementalLoader: ({String selectedSite = 'all'}) async {
            supplementalCalls += 1;
            if (supplementalCalls > 1) {
              throw Exception('supplemental refresh failed');
            }
            return const HqAnalyticsSupplementalSnapshot(
              pillarAnalytics: <Map<String, dynamic>>[
                <String, dynamic>{
                  'pillar': 'Future Skills',
                  'progress': 0.75,
                  'learners': 14,
                  'missions': 6,
                },
              ],
              siteComparison: <Map<String, dynamic>>[
                <String, dynamic>{
                  'siteId': 'site-1',
                  'name': 'North Hub',
                  'learners': 40,
                  'attendance': 96,
                  'engagement': 84,
                },
              ],
              topPerformers: <Map<String, dynamic>>[
                <String, dynamic>{
                  'rank': 1,
                  'name': 'Luna Learner',
                  'site': 'North Hub',
                  'reviewedEvidenceCount': 12,
                  'capabilityUpdates': 5,
                  'reviewedDays': 4,
                  'latestCapabilityTitle': 'Evidence-backed reasoning',
                  'latestCapabilityLevel': 4,
                },
              ],
              bosMiaFeedback: <String, dynamic>{
                'submissionCount': 3,
                'avgUsability': 4.2,
                'avgUsefulness': 4.3,
                'avgReliability': 4.1,
                'avgVoiceQuality': 4.4,
                'topRecommendation': 'scale_with_guardrails',
                'topIssue': 'telemetry_gaps',
              },
            );
          },
          kpiPacksLoader: ({String? siteId, int limit = 24}) async =>
              const <Map<String, dynamic>>[],
          syntheticImportLoader: () async => null,
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Top Performers'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Luna Learner'), findsOneWidget);

    await tester.drag(find.byType(Scrollable).first, const Offset(0, 1200));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -1600));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byIcon(Icons.refresh_rounded).first);
    await tester.tap(find.byIcon(Icons.refresh_rounded).first, warnIfMissed: false);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        'Unable to refresh supplemental analytics right now.',
      ),
      findsWidgets,
    );

    await tester.scrollUntilVisible(
      find.text('Top Performers'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Luna Learner'), findsOneWidget);
    expect(find.text('North Hub'), findsWidgets);
  });

  testWidgets('hq analytics shows explicit unavailable state when KPI packs fail to load',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );

    await tester.pumpWidget(
      _buildAnalyticsHarness(
        firestoreService: firestoreService,
        child: HqAnalyticsPage(
          metricsLoader: ({String? siteId, String period = 'month'}) async {
            return const TelemetryDashboardMetrics(
              weeklyAccountabilityAdherenceRate: 91.0,
              educatorReviewTurnaroundHoursAvg: 18.5,
              educatorReviewWithinSlaRate: 87.0,
              educatorReviewSlaHours: 48,
              interventionHelpedRate: 72.0,
              interventionTotal: 11,
              attendanceTrend: <AttendanceTrendPoint>[],
            );
          },
          supplementalLoader: ({String selectedSite = 'all'}) async =>
              const HqAnalyticsSupplementalSnapshot(),
          kpiPacksLoader: ({String? siteId, int limit = 24}) async {
            throw Exception('kpi down');
          },
          syntheticImportLoader: () async => null,
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('KPI packs are temporarily unavailable'), findsOneWidget);
    expect(find.text('No KPI packs yet'), findsNothing);
  });

  testWidgets('hq analytics shows explicit unavailable state when synthetic import metadata fails to load',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );

    await tester.pumpWidget(
      _buildAnalyticsHarness(
        firestoreService: firestoreService,
        child: HqAnalyticsPage(
          metricsLoader: ({String? siteId, String period = 'month'}) async {
            return const TelemetryDashboardMetrics(
              weeklyAccountabilityAdherenceRate: 91.0,
              educatorReviewTurnaroundHoursAvg: 18.5,
              educatorReviewWithinSlaRate: 87.0,
              educatorReviewSlaHours: 48,
              interventionHelpedRate: 72.0,
              interventionTotal: 11,
              attendanceTrend: <AttendanceTrendPoint>[],
            );
          },
          supplementalLoader: ({String selectedSite = 'all'}) async =>
              const HqAnalyticsSupplementalSnapshot(),
          kpiPacksLoader: ({String? siteId, int limit = 24}) async =>
              const <Map<String, dynamic>>[],
          syntheticImportLoader: () async {
            throw Exception('synthetic down');
          },
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Synthetic import metadata is temporarily unavailable'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Synthetic import metadata is temporarily unavailable'), findsOneWidget);
    expect(find.text('No synthetic import metadata yet'), findsNothing);
  });
}
