import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/modules/learner/proof_assembly_page.dart';
import 'package:scholesa_app/services/firestore_service.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

AppState _buildLearnerState() {
  final AppState state = AppState();
  state.updateFromMeResponse(<String, dynamic>{
    'userId': 'learner-1',
    'email': 'learner@scholesa.test',
    'displayName': 'Learner One',
    'role': 'learner',
    'activeSiteId': 'site-1',
    'siteIds': <String>['site-1'],
    'localeCode': 'en',
    'entitlements': const <Map<String, dynamic>>[],
  });
  return state;
}

Future<void> _seedPortfolioItems(FakeFirebaseFirestore firestore) async {
  await firestore.collection('portfolioItems').doc('portfolio-1').set(
    <String, dynamic>{
      'learnerId': 'learner-1',
      'siteId': 'site-1',
      'title': 'Water filter prototype',
      'description': 'Evidence from the second clearer-water test.',
      'capabilityIds': <String>['capability-evidence-reasoning'],
      'createdAt': Timestamp.fromDate(DateTime(2026, 5, 1, 10)),
      'updatedAt': Timestamp.fromDate(DateTime(2026, 5, 1, 10)),
    },
  );
  await firestore.collection('portfolioItems').doc('portfolio-other-site').set(
    <String, dynamic>{
      'learnerId': 'learner-1',
      'siteId': 'site-2',
      'title': 'Other-site portfolio item should stay hidden',
      'description': 'This belongs to another site.',
      'capabilityIds': <String>['capability-other-site'],
      'createdAt': Timestamp.fromDate(DateTime(2026, 5, 1, 11)),
      'updatedAt': Timestamp.fromDate(DateTime(2026, 5, 1, 11)),
    },
  );
  await firestore
      .collection('proofOfLearningBundles')
      .doc('proof-other-site')
      .set(
    <String, dynamic>{
      'learnerId': 'learner-1',
      'siteId': 'site-2',
      'portfolioItemId': 'portfolio-other-site',
      'capabilityId': 'capability-other-site',
      'hasExplainItBack': true,
      'hasOralCheck': true,
      'hasMiniRebuild': true,
      'explainItBackExcerpt': 'This other-site proof should stay hidden.',
      'verificationStatus': 'pending_review',
      'version': 1,
      'createdAt': Timestamp.fromDate(DateTime(2026, 5, 1, 11)),
      'updatedAt': Timestamp.fromDate(DateTime(2026, 5, 1, 11)),
    },
  );
}

Future<FirestoreService> _pumpPage(
  WidgetTester tester, {
  required FakeFirebaseFirestore firestore,
}) async {
  final FirestoreService service = FirestoreService(
    firestore: firestore,
    auth: _MockFirebaseAuth(),
  );

  await tester.pumpWidget(
    MultiProvider(
      providers: <SingleChildWidget>[
        Provider<FirestoreService>.value(value: service),
        ChangeNotifierProvider<AppState>.value(value: _buildLearnerState()),
      ],
      child: const MaterialApp(home: ProofAssemblyPage()),
    ),
  );
  await tester.pumpAndSettle();
  return service;
}

void main() {
  testWidgets(
      'proof assembly captures same-site proof methods on classroom mobile width',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await _seedPortfolioItems(firestore);

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpPage(tester, firestore: firestore);

    expect(find.text('Proof of Learning'), findsOneWidget);
    expect(find.text('Water filter prototype'), findsOneWidget);
    expect(find.text('Other-site portfolio item should stay hidden'),
        findsNothing);

    await tester.tap(find.text('Water filter prototype'));
    await tester.pumpAndSettle();

    expect(find.text('Explain-It-Back'), findsWidgets);
    expect(find.text('Oral Check'), findsWidgets);
    expect(find.text('Mini Rebuild'), findsWidgets);

    await tester.enterText(
      find.widgetWithText(TextField, 'I learned that...'),
      'The cleaner second test happened because I changed the filter layers.',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'When I explain this out loud, I say...'),
      'I can explain why each material caught different particles.',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'If I were to rebuild this, I would...'),
      'I would rebuild the bottle, layer the charcoal, and test flow rate again.',
    );

    await tester.drag(find.byType(ListView), const Offset(0, -620));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save Proof'));
    await tester.pumpAndSettle();

    final QuerySnapshot<Map<String, dynamic>> bundles = await firestore
        .collection('proofOfLearningBundles')
        .where('learnerId', isEqualTo: 'learner-1')
        .where('portfolioItemId', isEqualTo: 'portfolio-1')
        .get();
    expect(bundles.docs, hasLength(1));

    final Map<String, dynamic> proof = bundles.docs.single.data();
    expect(proof['siteId'], 'site-1');
    expect(proof['capabilityId'], 'capability-evidence-reasoning');
    expect(proof['hasExplainItBack'], true);
    expect(proof['hasOralCheck'], true);
    expect(proof['hasMiniRebuild'], true);
    expect(proof['verificationStatus'], 'pending_review');
    expect(
      proof['explainItBackExcerpt'],
      contains('changed the filter layers'),
    );
    expect(tester.takeException(), isNull);
  });
}
