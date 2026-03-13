import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/modules/educator/educator_models.dart';
import 'package:scholesa_app/modules/educator/educator_service.dart';
import 'package:scholesa_app/modules/educator/educator_today_page.dart';
import 'package:scholesa_app/services/firestore_service.dart';
import 'package:scholesa_app/ui/theme/scholesa_theme.dart';

final ThemeData _testTheme = ScholesaTheme.light;

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _MockEducatorService extends Mock implements EducatorService {}

AppState _buildAppState() {
  final AppState appState = AppState();
  appState.updateFromMeResponse(<String, dynamic>{
    'userId': 'educator-1',
    'email': 'educator-1@scholesa.test',
    'displayName': 'Educator One',
    'role': 'educator',
    'activeSiteId': 'site-1',
    'siteIds': <String>['site-1'],
    'entitlements': <Map<String, dynamic>>[],
  });
  return appState;
}

void main() {
  testWidgets(
      'educator today live session mode persists state and session events',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    final AppState appState = _buildAppState();
    final _MockEducatorService educatorService = _MockEducatorService();

    final TodayClass currentClass = TodayClass(
      id: 'occ-1',
      sessionId: 'session-1',
      title: 'Robotics Studio',
      description: 'Build and test a sensor loop.',
      startTime: DateTime(2026, 3, 13, 10),
      endTime: DateTime(2026, 3, 13, 11),
      location: 'Lab 2',
      enrolledCount: 12,
      presentCount: 10,
      status: 'in_progress',
      learners: const <EnrolledLearner>[
        EnrolledLearner(id: 'learner-1', name: 'Avery Chen'),
        EnrolledLearner(id: 'learner-2', name: 'Jordan Lee'),
      ],
    );

    final List<EducatorLearner> learners = <EducatorLearner>[
      const EducatorLearner(
        id: 'learner-1',
        name: 'Avery Chen',
        email: 'avery@scholesa.test',
        attendanceRate: 91,
        missionsCompleted: 5,
        pillarProgress: <String, double>{
          'future_skills': 0.52,
          'leadership': 0.46,
          'impact': 0.48,
        },
        enrolledSessionIds: <String>['session-1'],
      ),
      const EducatorLearner(
        id: 'learner-2',
        name: 'Jordan Lee',
        email: 'jordan@scholesa.test',
        attendanceRate: 88,
        missionsCompleted: 6,
        pillarProgress: <String, double>{
          'future_skills': 0.61,
          'leadership': 0.53,
          'impact': 0.55,
        },
        enrolledSessionIds: <String>['session-1'],
      ),
    ];

    when(() => educatorService.loadTodaySchedule())
        .thenAnswer((_) async {});
    when(() => educatorService.loadLearners()).thenAnswer((_) async {});
    when(() => educatorService.isLoading).thenReturn(false);
    when(() => educatorService.todayClasses).thenReturn(<TodayClass>[currentClass]);
    when(() => educatorService.currentClass).thenReturn(currentClass);
    when(() => educatorService.learners).thenReturn(learners);
    when(() => educatorService.dayStats).thenReturn(
      const EducatorDayStats(
        totalClasses: 1,
        completedClasses: 0,
        totalLearners: 12,
        presentLearners: 10,
        missionsToReview: 2,
        unreadMessages: 1,
      ),
    );
    when(() => educatorService.siteId).thenReturn('site-1');

    await tester.binding.setSurfaceSize(const Size(1280, 1800));
    await tester.pumpWidget(
      MultiProvider(
        providers: <SingleChildWidget>[
          Provider<FirestoreService>.value(value: firestoreService),
          ChangeNotifierProvider<AppState>.value(value: appState),
          ChangeNotifierProvider<EducatorService>.value(value: educatorService),
        ],
        child: MaterialApp(
          theme: _testTheme,
          home: EducatorTodayPage(
            classInsightsLoader: ({
              required String sessionOccurrenceId,
              required String siteId,
            }) async => <String, dynamic>{
              'sessionOccurrenceId': sessionOccurrenceId,
              'siteId': siteId,
              'learners': <Map<String, dynamic>>[
                <String, dynamic>{
                  'learnerId': 'learner-1',
                  'misconceptionTags': <String>['loops'],
                  'x_hat': <String, double>{
                    'cognition': 0.31,
                    'engagement': 0.58,
                    'integrity': 0.74,
                  },
                },
                <String, dynamic>{
                  'learnerId': 'learner-2',
                  'misconceptionTags': <String>['sensor calibration'],
                  'x_hat': <String, double>{
                    'cognition': 0.62,
                    'engagement': 0.66,
                    'integrity': 0.81,
                  },
                },
              ],
            },
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Live Session Mode'));
    await tester.pumpAndSettle();

    expect(find.text('Misconception Alerts'), findsOneWidget);
    expect(find.textContaining('Avery Chen: loops'), findsOneWidget);

    await tester.tap(find.text('Accelerate'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Queue Cold-Call'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Launch Quick Poll'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.dragUntilVisible(
      find.text('Send Exit Ticket'),
      find.byType(Scrollable).last,
      const Offset(0, -200),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Send Exit Ticket'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.ensureVisible(find.text('Save Live Mode'));
    await tester.tap(find.text('Save Live Mode'));
    await tester.pump(const Duration(milliseconds: 300));

    final modeDoc = await firestore
        .collection('liveSessionModes')
        .doc('occ-1_site-1')
        .get();
    expect(modeDoc.exists, isTrue);
    expect(modeDoc.data()?['pacingMode'], 'accelerate');
    expect(modeDoc.data()?['sessionOccurrenceId'], 'occ-1');
    expect(modeDoc.data()?['coldCallLearnerId'], 'learner-1');
    expect(modeDoc.data()?['pollPrompt'], 'How confident are you with this step?');
    expect(
      modeDoc.data()?['misconceptionAlerts'] as List<dynamic>,
      contains('Avery Chen: loops'),
    );

    final events = await firestore.collection('liveSessionEvents').get();
    expect(events.docs.length, 3);
    final List<String> eventTypes = events.docs
      .map((doc) => doc.data()['eventType'] as String? ?? '')
      .toList(growable: false);
    expect(eventTypes, contains('cold_call'));
    expect(eventTypes, contains('poll'));
    expect(eventTypes, contains('exit_ticket'));
  });
}