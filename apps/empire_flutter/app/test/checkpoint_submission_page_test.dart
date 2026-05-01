import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/modules/learner/checkpoint_submission_page.dart';
import 'package:scholesa_app/services/firestore_service.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

AppState _buildLearnerState() {
  final AppState state = AppState();
  state.updateFromMeResponse(<String, dynamic>{
    'userId': 'learner-1',
    'email': 'learner-1@scholesa.test',
    'displayName': 'Learner One',
    'role': UserRole.learner.name,
    'activeSiteId': 'site-1',
    'siteIds': <String>['site-1'],
    'localeCode': 'en',
    'entitlements': const <Map<String, dynamic>>[],
  });
  return state;
}

Future<void> _seedCheckpointHistory(FakeFirebaseFirestore firestore) async {
  await firestore.collection('checkpointHistory').doc('checkpoint-site-1').set(
    <String, dynamic>{
      'learnerId': 'learner-1',
      'siteId': 'site-1',
      'missionId': 'mission-1',
      'skillId': 'skill-prototype-testing',
      'question': 'What evidence shows your prototype improved?',
      'learnerResponse': '',
      'isCorrect': false,
      'explainItBackRequired': true,
      'createdAt': Timestamp.fromDate(DateTime(2026, 5, 1, 10)),
    },
  );
  await firestore
      .collection('checkpointHistory')
      .doc('checkpoint-other-site')
      .set(
    <String, dynamic>{
      'learnerId': 'learner-1',
      'siteId': 'site-2',
      'missionId': 'mission-other-site',
      'question': 'Other-site checkpoint should stay hidden',
      'learnerResponse': '',
      'isCorrect': false,
      'explainItBackRequired': false,
      'createdAt': Timestamp.fromDate(DateTime(2026, 5, 1, 11)),
    },
  );
}

Future<void> _pumpPage({
  required WidgetTester tester,
  required FakeFirebaseFirestore firestore,
}) async {
  final FirestoreService firestoreService = FirestoreService(
    firestore: firestore,
    auth: _MockFirebaseAuth(),
  );

  await tester.pumpWidget(
    MultiProvider(
      providers: <SingleChildWidget>[
        Provider<FirestoreService>.value(value: firestoreService),
        ChangeNotifierProvider<AppState>.value(value: _buildLearnerState()),
      ],
      child: const MaterialApp(
        home: CheckpointSubmissionPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'checkpoint page captures same-site learner response on classroom mobile width',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await _seedCheckpointHistory(firestore);

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpPage(tester: tester, firestore: firestore);

    expect(find.text('Checkpoints'), findsOneWidget);
    expect(
      find.text('What evidence shows your prototype improved?'),
      findsOneWidget,
    );
    expect(find.text('Other-site checkpoint should stay hidden'), findsNothing);
    expect(
        find.text(
            'You will need to explain what you learned after submitting.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.enterText(
      find.widgetWithText(TextField, 'Type your answer...'),
      'The second filter test ran clearer water for longer.',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
    await tester.pumpAndSettle();

    expect(find.text('Checkpoint submitted!'), findsOneWidget);
    final QuerySnapshot<Map<String, dynamic>> submitted = await firestore
        .collection('checkpointHistory')
        .where('learnerId', isEqualTo: 'learner-1')
        .where('siteId', isEqualTo: 'site-1')
        .where('learnerResponse',
            isEqualTo: 'The second filter test ran clearer water for longer.')
        .get();
    expect(submitted.docs, hasLength(1));
    expect(submitted.docs.single.data()['missionId'], 'mission-1');
    expect(submitted.docs.single.data()['explainItBackRequired'], true);

    final QuerySnapshot<Map<String, dynamic>> hiddenSiteRecords =
        await firestore
            .collection('checkpointHistory')
            .where('siteId', isEqualTo: 'site-2')
            .get();
    expect(hiddenSiteRecords.docs, hasLength(1));
    expect(
      hiddenSiteRecords.docs.single.data()['question'],
      'Other-site checkpoint should stay hidden',
    );
  });
}
