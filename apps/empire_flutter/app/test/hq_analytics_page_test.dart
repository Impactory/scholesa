import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/modules/hq_admin/hq_analytics_page.dart';
import 'package:scholesa_app/services/analytics_service.dart';
import 'package:scholesa_app/services/firestore_service.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

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
    'timestamp': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 1))),
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

void main() {
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
    expect(find.text('BOS/MIA synthetic training'), findsOneWidget);
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
      find.text('HQ BOS-MIA Usability'),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('HQ BOS-MIA Usability'), findsOneWidget);
  });
}