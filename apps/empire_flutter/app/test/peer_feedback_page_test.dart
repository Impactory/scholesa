import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/modules/learner/peer_feedback_page.dart';
import 'package:scholesa_app/services/firestore_service.dart';

class _FakeFirebaseAuth implements FirebaseAuth {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

AppState _buildLearnerState() {
  final AppState state = AppState();
  state.updateFromMeResponse(<String, dynamic>{
    'userId': 'learner-1',
    'email': 'learner@scholesa.test',
    'displayName': 'Learner One',
    'role': 'learner',
    'activeSiteId': 'site-1',
    'siteIds': <String>['site-1'],
    'entitlements': const <dynamic>[],
  });
  return state;
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required FirestoreService firestoreService,
}) async {
  await tester.binding.setSurfaceSize(const Size(1280, 1800));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<AppState>.value(value: _buildLearnerState()),
        Provider<FirestoreService>.value(value: firestoreService),
      ],
      child: MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          splashFactory: NoSplash.splashFactory,
        ),
        locale: const Locale('en'),
        supportedLocales: const <Locale>[
          Locale('en'),
          Locale('zh', 'CN'),
          Locale('zh', 'TW'),
        ],
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const PeerFeedbackPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _seedMissionAttempt(
  FakeFirebaseFirestore firestore, {
  required String id,
  required String siteId,
  required String learnerId,
  required String missionId,
  required DateTime createdAt,
}) async {
  await firestore.collection('missionAttempts').doc(id).set(<String, dynamic>{
    'siteId': siteId,
    'learnerId': learnerId,
    'missionId': missionId,
    'status': 'submitted',
    'reflection': 'Prototype note for $missionId',
    'artifactUrls': const <String>[],
    'pillarCodes': const <String>['futureSkills'],
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(createdAt),
  });
}

void main() {
  testWidgets('learner peer feedback persists same-site structured review only',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    final DateTime anchor = DateTime(2026, 4, 30, 10);

    await _seedMissionAttempt(
      firestore,
      id: 'attempt-peer',
      siteId: 'site-1',
      learnerId: 'learner-2',
      missionId: 'mission-peer',
      createdAt: anchor,
    );
    await _seedMissionAttempt(
      firestore,
      id: 'attempt-self',
      siteId: 'site-1',
      learnerId: 'learner-1',
      missionId: 'mission-self',
      createdAt: anchor.subtract(const Duration(minutes: 1)),
    );
    await _seedMissionAttempt(
      firestore,
      id: 'attempt-other-site',
      siteId: 'other-site',
      learnerId: 'learner-3',
      missionId: 'mission-other-site',
      createdAt: anchor.add(const Duration(minutes: 1)),
    );
    await firestore.collection('peerFeedback').doc('other-site-feedback').set(
      <String, dynamic>{
        'siteId': 'other-site',
        'fromLearnerId': 'learner-1',
        'authorId': 'learner-1',
        'toLearnerId': 'learner-3',
        'missionAttemptId': 'attempt-other-site',
        'rating': 5,
        'strengths': 'Other site strength',
        'suggestions': 'Other site suggestion',
        'createdAt': Timestamp.fromDate(anchor),
      },
    );

    await _pumpPage(
      tester,
      firestoreService: FirestoreService(
        firestore: firestore,
        auth: _FakeFirebaseAuth(),
      ),
    );

    expect(find.text('Mission: mission-peer'), findsOneWidget);
    expect(find.text('By: learner-2'), findsOneWidget);
    expect(find.text('Mission: mission-self'), findsNothing);
    expect(find.text('Mission: mission-other-site'), findsNothing);

    await tester.tap(find.text('Mission: mission-peer'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.star_border).at(3));
    await tester.enterText(
      find.byType(TextField).at(0),
      'Clear prototype reasoning',
    );
    await tester.enterText(
      find.byType(TextField).at(1),
      'Add one more evidence note',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Submit Feedback'));
    await tester.pumpAndSettle();

    final QuerySnapshot<Map<String, dynamic>> feedback = await firestore
        .collection('peerFeedback')
        .where('siteId', isEqualTo: 'site-1')
        .get();
    expect(feedback.docs.length, 1);
    final Map<String, dynamic> data = feedback.docs.single.data();
    expect(data['fromLearnerId'], 'learner-1');
    expect(data['authorId'], 'learner-1');
    expect(data['toLearnerId'], 'learner-2');
    expect(data['targetLearnerId'], 'learner-2');
    expect(data['missionAttemptId'], 'attempt-peer');
    expect(data['rating'], 4);
    expect(data['strengths'], 'Clear prototype reasoning');
    expect(data['iLike'], 'Clear prototype reasoning');
    expect(data['suggestions'], 'Add one more evidence note');
    expect(data['iWonder'], 'Add one more evidence note');
    expect(data['status'], 'submitted');
    expect(data['flagged'], false);
  });
}
