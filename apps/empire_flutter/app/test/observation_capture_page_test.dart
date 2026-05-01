import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/modules/educator/observation_capture_page.dart';
import 'package:scholesa_app/services/firestore_service.dart';

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
    'entitlements': const <Map<String, dynamic>>[],
  });
  return state;
}

Widget _buildHarness({
  required AppState appState,
  required FirestoreService firestoreService,
}) {
  return MultiProvider(
    providers: <SingleChildWidget>[
      ChangeNotifierProvider<AppState>.value(value: appState),
      Provider<FirestoreService>.value(value: firestoreService),
    ],
    child: MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: const ObservationCapturePage(),
    ),
  );
}

Future<void> _seedObservationCaptureData(
  FakeFirebaseFirestore firestore,
) async {
  await firestore.collection('users').doc('learner-site-1').set(
    <String, dynamic>{
      'role': 'learner',
      'displayName': 'Same Site Learner',
      'siteIds': <String>['site-1'],
    },
  );
  await firestore.collection('users').doc('learner-site-2').set(
    <String, dynamic>{
      'role': 'learner',
      'displayName': 'Other Site Learner',
      'siteIds': <String>['site-2'],
    },
  );
  await firestore.collection('evidenceRecords').doc('recent-site-1').set(
    <String, dynamic>{
      'learnerId': 'learner-site-1',
      'learnerName': 'Same Site Learner',
      'siteId': 'site-1',
      'recordedBy': 'educator-1',
      'type': 'observation',
      'observationType': 'engagement',
      'note': 'Same-site recent observation',
      'captureTimeMs': 8000,
      'createdAt': Timestamp.fromDate(DateTime(2026, 5, 1, 9)),
    },
  );
  await firestore.collection('evidenceRecords').doc('recent-site-2').set(
    <String, dynamic>{
      'learnerId': 'learner-site-2',
      'learnerName': 'Other Site Learner',
      'siteId': 'site-2',
      'recordedBy': 'educator-1',
      'type': 'observation',
      'observationType': 'engagement',
      'note': 'Other-site recent observation should stay hidden',
      'captureTimeMs': 7000,
      'createdAt': Timestamp.fromDate(DateTime(2026, 5, 1, 10)),
    },
  );
}

void main() {
  testWidgets(
      'observation capture records same-site classroom evidence on mobile width',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await _seedObservationCaptureData(firestore);
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );

    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      _buildHarness(
        appState: _buildEducatorState(),
        firestoreService: firestoreService,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Quick Observation Capture'), findsOneWidget);
    expect(find.text('Same Site Learner'), findsWidgets);
    expect(find.text('Other Site Learner'), findsNothing);
    expect(find.text('Same-site recent observation'), findsOneWidget);
    expect(
      find.text('Other-site recent observation should stay hidden'),
      findsNothing,
    );

    await tester.tap(find.text('Same Site Learner').first);
    await tester.pump();
    await tester.enterText(
      find.byType(TextField),
      'Learner explained the prototype tradeoff during build time.',
    );
    await tester.tap(find.text('Record'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final QuerySnapshot<Map<String, dynamic>> snapshot = await firestore
        .collection('evidenceRecords')
        .where('note',
            isEqualTo:
                'Learner explained the prototype tradeoff during build time.')
        .get();
    expect(snapshot.docs, hasLength(1));
    final Map<String, dynamic> saved = snapshot.docs.single.data();
    expect(saved['learnerId'], 'learner-site-1');
    expect(saved['learnerName'], 'Same Site Learner');
    expect(saved['educatorId'], 'educator-1');
    expect(saved['recordedBy'], 'educator-1');
    expect(saved['siteId'], 'site-1');
    expect(saved['type'], 'observation');
    expect(saved['rubricStatus'], 'pending');
    expect(saved['growthStatus'], 'pending');
    expect(saved.containsKey('capabilityMastery'), isFalse);
    expect(saved.containsKey('capabilityGrowthEvents'), isFalse);
    expect(tester.takeException(), isNull);
  });
}
