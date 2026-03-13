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

Widget _buildHarness({
  required AppState appState,
  required FirestoreService firestoreService,
  required MissionService missionService,
}) {
  return MultiProvider(
    providers: <SingleChildWidget>[
      ChangeNotifierProvider<AppState>.value(value: appState),
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
      supportedLocales: const <Locale>[
        Locale('en'),
        Locale('zh', 'CN'),
        Locale('zh', 'TW'),
      ],
      home: const MissionsPage(),
    ),
  );
}

Future<void> _seedMission(FakeFirebaseFirestore firestore) async {
  await firestore.collection('missionAssignments').doc('assignment-1').set(
    <String, dynamic>{
      'missionId': 'mission-1',
      'learnerId': 'learner-1',
      'siteId': 'site-1',
      'status': 'in_progress',
      'progress': 1.0,
    },
  );
  await firestore.collection('missions').doc('mission-1').set(
    <String, dynamic>{
      'title': 'Proof bundle mission',
      'description': 'Demonstrate understanding before review.',
      'pillarCode': 'future_skills',
      'difficulty': 'beginner',
      'xpReward': 100,
    },
  );
  await firestore
      .collection('missions')
      .doc('mission-1')
      .collection('steps')
      .doc('step-1')
      .set(
    <String, dynamic>{
      'title': 'Build the first prototype',
      'order': 1,
      'isCompleted': true,
    },
  );
}

void main() {
  testWidgets('learner mission sheet persists proof bundle and attaches it on submission',
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
        appState: _buildLearnerState(),
        firestoreService: firestoreService,
        missionService: missionService,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    await tester.tap(find.text('In Progress'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Proof bundle mission').first);
    await tester.pumpAndSettle();

    expect(find.text('Proof of Learning'), findsOneWidget);

    final Finder textFields = find.byType(TextField);
    await tester.enterText(textFields.at(0), 'I can explain the build loop in my own words.');
    await tester.enterText(textFields.at(1), 'I said the steps out loud and corrected one gap.');
    await tester.enterText(textFields.at(2), 'I would rebuild the sensor flow, test inputs, then refactor outputs.');
    await tester.enterText(textFields.at(3), 'Checkpoint after fixing the motor timing.');
    await tester.enterText(textFields.at(4), 'Attached a note about the final timing tweak.');

    await tester.ensureVisible(find.widgetWithText(OutlinedButton, 'Save Checkpoint'));
    await tester.tap(find.widgetWithText(OutlinedButton, 'Save Checkpoint'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Save Proof Bundle'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.widgetWithText(ElevatedButton, 'Submit for Review'),
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Submit for Review'));
    await tester.pumpAndSettle();

    final DocumentSnapshot<Map<String, dynamic>> proofBundleDoc = await firestore
        .collection('proofOfLearningBundles')
        .doc('learner-1_mission-1')
        .get();
    expect(proofBundleDoc.exists, isTrue);
    expect(proofBundleDoc.data()?['explainItBack'], contains('build loop'));
    expect((proofBundleDoc.data()?['versionHistory'] as List<dynamic>).length, 1);

    final QuerySnapshot<Map<String, dynamic>> submissions =
        await firestore.collection('missionSubmissions').get();
    expect(submissions.docs, hasLength(1));
    expect(submissions.docs.first.data()['proofBundleId'], 'learner-1_mission-1');
    expect(
      submissions.docs.first.data()['proofBundleSummary']['checkpointCount'],
      1,
    );
    expect(
      submissions.docs.first.data()['proofBundleSummary']['isReady'],
      isTrue,
    );
  });
}