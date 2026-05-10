import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/modules/educator/proof_verification_page.dart';
import 'package:scholesa_app/services/firestore_service.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _ThrowingFirestoreService extends FirestoreService {
  _ThrowingFirestoreService()
      : super(
          firestore: FakeFirebaseFirestore(),
          auth: _MockFirebaseAuth(),
        );

  @override
  Future<List<Map<String, dynamic>>> queryCollection(
    String collection, {
    List<List<dynamic>>? where,
    String? orderBy,
    bool descending = false,
    int? limit,
  }) async {
    throw FirebaseException(
      plugin: 'cloud_firestore',
      code: 'failed-precondition',
      message:
          'The query requires an index. You can create it here: https://console.firebase.google.com/project/demo/firestore/indexes',
    );
  }
}

class _RevisionRecordingFirestoreService extends FirestoreService {
  _RevisionRecordingFirestoreService({required this.fakeFirestore})
      : super(
          firestore: fakeFirestore,
          auth: _MockFirebaseAuth(),
        );

  final FakeFirebaseFirestore fakeFirestore;
  String? lastRevisionPortfolioItemId;
  String? lastRevisionReason;

  @override
  Future<void> requestProofRevision({
    required String portfolioItemId,
    required String reason,
    Map<String, dynamic> proofChecks = const <String, dynamic>{},
    Map<String, dynamic> excerpts = const <String, dynamic>{},
  }) async {
    lastRevisionPortfolioItemId = portfolioItemId;
    lastRevisionReason = reason;
    final QuerySnapshot<Map<String, dynamic>> snapshot = await fakeFirestore
        .collection('proofOfLearningBundles')
        .where('portfolioItemId', isEqualTo: portfolioItemId)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return;
    await snapshot.docs.first.reference.update(<String, dynamic>{
      'verificationStatus': 'partial',
      'verificationPrompt': reason,
      'updatedAt': Timestamp.fromDate(DateTime(2026, 5, 10, 12)),
    });
  }
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
      home: const ProofVerificationPage(),
    ),
  );
}

Future<void> _seedProofBundles(FakeFirebaseFirestore firestore) async {
  await firestore.collection('proofOfLearningBundles').doc('proof-site-1').set(
    <String, dynamic>{
      'siteId': 'site-1',
      'learnerId': 'learner-1',
      'learnerName': 'Same Site Learner',
      'portfolioItemId': 'portfolio-1',
      'portfolioItemTitle': 'Water Filter Prototype',
      'verificationStatus': 'pending_review',
      'hasExplainItBack': true,
      'hasOralCheck': true,
      'hasMiniRebuild': true,
      'explainItBackExcerpt': 'I changed the filter angle after testing flow.',
      'oralCheckExcerpt':
          'The learner explained the tradeoff in their own words.',
      'miniRebuildExcerpt': 'The learner rebuilt the intake using fewer parts.',
      'createdAt': Timestamp.fromDate(DateTime(2026, 5, 1, 10)),
    },
  );
  await firestore.collection('proofOfLearningBundles').doc('proof-site-2').set(
    <String, dynamic>{
      'siteId': 'site-2',
      'learnerId': 'learner-2',
      'learnerName': 'Other Site Learner',
      'portfolioItemId': 'portfolio-2',
      'portfolioItemTitle': 'Other Site Artifact',
      'verificationStatus': 'pending_review',
      'hasExplainItBack': true,
      'hasOralCheck': true,
      'hasMiniRebuild': true,
      'createdAt': Timestamp.fromDate(DateTime(2026, 5, 1, 11)),
    },
  );
}

void main() {
  testWidgets('proof load failures show friendly setup guidance',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _buildHarness(
        appState: _buildEducatorState(),
        firestoreService: _ThrowingFirestoreService(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Verify Proof of Learning'), findsOneWidget);
    expect(
      find.text(
        'Proof review needs a quick refresh. Try again, or return to Today and reopen Proof of Learning.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('console.firebase.google.com'), findsNothing);
    expect(find.textContaining('failed-precondition'), findsNothing);
  });

  testWidgets(
      'proof verification shows same-site bundles and requests revision through service on mobile width',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await _seedProofBundles(firestore);
    final _RevisionRecordingFirestoreService firestoreService =
        _RevisionRecordingFirestoreService(fakeFirestore: firestore);

    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      _buildHarness(
        appState: _buildEducatorState(),
        firestoreService: firestoreService,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Verify Proof of Learning'), findsOneWidget);
    expect(find.text('Same Site Learner'), findsOneWidget);
    expect(find.text('Water Filter Prototype'), findsOneWidget);
    expect(find.text('Other Site Learner'), findsNothing);
    expect(find.text('Other Site Artifact'), findsNothing);
    expect(find.text('Explain-It-Back'), findsOneWidget);
    expect(find.text('Oral Check'), findsOneWidget);
    expect(find.text('Mini Rebuild'), findsOneWidget);

    await tester.tap(find.text('Request Revision'));
    await tester.pumpAndSettle();

    final DocumentSnapshot<Map<String, dynamic>> sameSiteProof = await firestore
        .collection('proofOfLearningBundles')
        .doc('proof-site-1')
        .get();
    final DocumentSnapshot<Map<String, dynamic>> otherSiteProof =
        await firestore
            .collection('proofOfLearningBundles')
            .doc('proof-site-2')
            .get();

    expect(firestoreService.lastRevisionPortfolioItemId, 'portfolio-1');
    expect(
      firestoreService.lastRevisionReason,
      'Educator requested proof revision.',
    );
    expect(sameSiteProof.data()?['verificationStatus'], 'partial');
    expect(
      sameSiteProof.data()?['verificationPrompt'],
      'Educator requested proof revision.',
    );
    expect(otherSiteProof.data()?['verificationStatus'], 'pending_review');
    expect(find.text('Same Site Learner'), findsOneWidget);
    expect(find.text('All proof bundles have been verified.'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
