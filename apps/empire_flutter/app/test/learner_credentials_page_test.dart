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
import 'package:scholesa_app/domain/models.dart';
import 'package:scholesa_app/modules/learner/learner_credentials_page.dart';
import 'package:scholesa_app/services/firestore_service.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

AppState _buildLearnerState() {
  final AppState state = AppState();
  state.updateFromMeResponse(<String, dynamic>{
    'userId': 'learner-1',
    'email': 'learner-1@scholesa.test',
    'displayName': 'Test Learner',
    'role': 'learner',
    'activeSiteId': 'site-1',
    'siteIds': const <String>['site-1'],
    'localeCode': 'en',
    'entitlements': const <Map<String, dynamic>>[],
  });
  return state;
}

Widget _buildHarness({
  required AppState appState,
  FirestoreService? firestoreService,
  LearnerCredentialsPage? child,
}) {
  final List<SingleChildWidget> providers = <SingleChildWidget>[
    ChangeNotifierProvider<AppState>.value(value: appState),
  ];
  if (firestoreService != null) {
    providers.add(Provider<FirestoreService>.value(value: firestoreService));
  }

  return MultiProvider(
    providers: providers,
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
      home: child ?? const LearnerCredentialsPage(),
    ),
  );
}

void main() {
  testWidgets('learner credentials page renders live credentials',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );

    await firestore.collection('credentials').doc('credential-1').set(
      <String, dynamic>{
        'siteId': 'site-1',
        'learnerId': 'learner-1',
        'title': 'Future Skills Sprint',
        'issuedAt': Timestamp.fromDate(DateTime(2026, 3, 18)),
        'issuerId': 'educator-1',
        'status': 'issued',
        'pillarCodes': const <String>['future_skills', 'leadership'],
        'skillIds': const <String>['collaboration', 'python'],
        'evidenceIds': const <String>['evidence-1', 'evidence-2'],
        'portfolioItemIds': const <String>['portfolio-1'],
        'proofBundleIds': const <String>['proof-1'],
        'growthEventIds': const <String>['growth-1'],
        'rubricApplicationId': 'rubric-application-1',
      },
    );

    await firestore.collection('credentials').doc('credential-other-site').set(
      <String, dynamic>{
        'siteId': 'site-2',
        'learnerId': 'learner-1',
        'title': 'Other Site Credential',
        'issuedAt': Timestamp.fromDate(DateTime(2026, 3, 19)),
        'issuerId': 'educator-2',
        'status': 'issued',
        'evidenceIds': const <String>['evidence-other-site'],
      },
    );

    await tester.pumpWidget(
      _buildHarness(
        appState: _buildLearnerState(),
        firestoreService: firestoreService,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Account menu'), findsOneWidget);
    expect(find.text('Credentials'), findsOneWidget);
    expect(find.text('Future Skills Sprint'), findsOneWidget);
    expect(find.text('Issued 3/18/2026'), findsOneWidget);
    // Legacy pillar codes now render through the canonical strand display:
    // 'future_skills' -> 'Think, Make & Navigate AI'
    // 'leadership'    -> 'Communicate & Lead'
    expect(find.text('Think, Make & Navigate AI'), findsOneWidget);
    expect(find.text('Communicate & Lead'), findsOneWidget);
    expect(find.text('Skills tagged: 2'), findsOneWidget);
    expect(find.text('Credential site: site-1'), findsOneWidget);
    expect(find.text('Issued by: educator-1'), findsOneWidget);
    expect(find.text('Evidence provenance'), findsOneWidget);
    expect(find.text('Source evidence: 2'), findsOneWidget);
    expect(find.text('Portfolio artifacts: 1'), findsOneWidget);
    expect(find.text('Proof bundles: 1'), findsOneWidget);
    expect(find.text('Growth events: 1'), findsOneWidget);
    expect(find.text('Rubric review: rubric-application-1'), findsOneWidget);
    expect(find.text('Other Site Credential'), findsNothing);
  });

  testWidgets('learner credentials page reports missing storage honestly',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _buildHarness(appState: _buildLearnerState()),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Account menu'), findsOneWidget);
    expect(
        find.text('Credential storage unavailable right now.'), findsOneWidget);
    expect(find.text('No credentials issued yet'), findsNothing);
  });

  testWidgets(
      'learner credentials page keeps stale credentials visible after refresh failure',
      (WidgetTester tester) async {
    int loadCount = 0;

    await tester.pumpWidget(
      _buildHarness(
        appState: _buildLearnerState(),
        firestoreService: FirestoreService(
          firestore: FakeFirebaseFirestore(),
          auth: _MockFirebaseAuth(),
        ),
        child: LearnerCredentialsPage(
          credentialsLoader: (String learnerId, String? siteId) async {
            loadCount += 1;
            if (loadCount == 1) {
              return <CredentialModel>[
                CredentialModel(
                  id: 'credential-1',
                  siteId: siteId ?? 'site-1',
                  learnerId: learnerId,
                  title: 'Future Skills Sprint',
                  issuedAt: Timestamp.fromDate(DateTime(2026, 3, 18)),
                  issuerId: 'educator-1',
                  pillarCodes: const <String>['future_skills'],
                  skillIds: const <String>['collaboration'],
                  evidenceIds: const <String>['evidence-1'],
                  portfolioItemIds: const <String>['portfolio-1'],
                  proofBundleIds: const <String>['proof-1'],
                  growthEventIds: const <String>['growth-1'],
                  rubricApplicationId: 'rubric-application-1',
                ),
              ];
            }
            throw StateError('credentials refresh unavailable');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Future Skills Sprint'), findsOneWidget);
    expect(find.text('No credentials issued yet'), findsNothing);

    await tester.tap(find.byTooltip('Refresh'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Unable to refresh credentials right now. Showing the last successful data.',
      ),
      findsOneWidget,
    );
    expect(find.text('Future Skills Sprint'), findsOneWidget);
    expect(find.text('No credentials issued yet'), findsNothing);
  });
}
