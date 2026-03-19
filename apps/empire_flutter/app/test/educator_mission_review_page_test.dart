import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/modules/educator/educator_mission_review_page.dart';
import 'package:scholesa_app/modules/missions/mission_service.dart';
import 'package:scholesa_app/services/firestore_service.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _StubMissionService extends MissionService {
  _StubMissionService({
    this.failFirstLoad = false,
    this.submitShouldSucceed = true,
    List<MissionSubmission> submissions = const <MissionSubmission>[],
  })  : _submissions = List<MissionSubmission>.from(submissions),
        super(
          firestoreService: FirestoreService(
            firestore: FakeFirebaseFirestore(),
            auth: _MockFirebaseAuth(),
          ),
          learnerId: 'educator-1',
        );

  final bool failFirstLoad;
  final bool submitShouldSucceed;

  final List<String?> requestedSiteIds = <String?>[];
  int loadCallCount = 0;
  int submitCallCount = 0;

  bool _loading = false;
  String? _errorState;
  List<MissionSubmission> _submissions;
  int _reviewedTodayState = 0;

  @override
  bool get isLoading => _loading;

  @override
  String? get error => _errorState;

  @override
  List<MissionSubmission> get pendingReviews => _submissions;

  @override
  int get reviewedToday => _reviewedTodayState;

  @override
  Future<void> loadPendingReviews({String? educatorId, String? siteId}) async {
    loadCallCount += 1;
    requestedSiteIds.add(siteId);
    _loading = false;
    if (failFirstLoad && loadCallCount == 1) {
      _errorState = 'Unable to load mission review queue right now.';
      _submissions = <MissionSubmission>[];
      _reviewedTodayState = 0;
    } else {
      _errorState = null;
      _reviewedTodayState = 1;
    }
    notifyListeners();
  }

  @override
  Future<bool> submitReview({
    required String submissionId,
    required int rating,
    required String feedback,
    required String reviewerId,
    String status = 'reviewed',
    String? aiFeedbackDraft,
    String? rubricId,
    String? rubricTitle,
    List<Map<String, dynamic>> rubricScores = const <Map<String, dynamic>>[],
  }) async {
    submitCallCount += 1;
    if (!submitShouldSucceed) {
      _errorState = 'Failed to submit review: backend unavailable';
      notifyListeners();
      return false;
    }
    _submissions =
        _submissions.where((MissionSubmission item) => item.id != submissionId).toList();
    _reviewedTodayState += 1;
    _errorState = null;
    notifyListeners();
    return true;
  }
}

AppState _buildAppState() {
  final AppState state = AppState();
  state.updateFromMeResponse(<String, dynamic>{
    'userId': 'educator-1',
    'email': 'educator-1@scholesa.test',
    'displayName': 'Educator One',
    'role': 'educator',
    'activeSiteId': 'site-1',
    'siteIds': <String>['site-1'],
    'entitlements': const <dynamic>[],
  });
  return state;
}

MissionSubmission _submission() {
  return MissionSubmission(
    id: 'submission-1',
    missionId: 'mission-1',
    missionTitle: 'Robotics Reflection',
    learnerId: 'learner-1',
    learnerName: 'Avery Chen',
    pillar: 'future_skills',
    submittedAt: DateTime(2026, 3, 18, 9, 30),
    status: 'pending',
    submissionText: 'I tested the robot with two sensor loops.',
  );
}

Widget _buildHarness(MissionService missionService) {
  return MultiProvider(
    providers: <SingleChildWidget>[
      ChangeNotifierProvider<AppState>.value(value: _buildAppState()),
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

void main() {
  testWidgets(
      'educator mission review page shows explicit load error and retries with active site scope',
      (WidgetTester tester) async {
    final _StubMissionService missionService = _StubMissionService(
      failFirstLoad: true,
      submissions: <MissionSubmission>[_submission()],
    );

    await tester.pumpWidget(_buildHarness(missionService));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.text('Unable to load mission review queue right now.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('All caught up!'), findsNothing);
    expect(missionService.requestedSiteIds, <String?>['site-1']);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(missionService.requestedSiteIds, <String?>['site-1', 'site-1']);
    expect(find.text('Robotics Reflection'), findsOneWidget);
    expect(
      find.text('Unable to load mission review queue right now.'),
      findsNothing,
    );
  });

  testWidgets(
      'educator mission review page surfaces failed approval instead of silent no-op',
      (WidgetTester tester) async {
    final _StubMissionService missionService = _StubMissionService(
      submissions: <MissionSubmission>[_submission()],
      submitShouldSucceed: false,
    );

    await tester.pumpWidget(_buildHarness(missionService));
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Robotics Reflection'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Approve'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(missionService.submitCallCount, 1);
    expect(find.text('Unable to submit review right now.'), findsOneWidget);
    expect(find.text('Mission approved!'), findsNothing);
    expect(find.text('Request Revision'), findsOneWidget);
  });
}
