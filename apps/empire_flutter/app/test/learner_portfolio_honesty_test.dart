import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/domain/models.dart';
import 'package:scholesa_app/modules/learner/learner_portfolio_page.dart';
import 'package:scholesa_app/runtime/learning_runtime_provider.dart';
import 'package:scholesa_app/services/firestore_service.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

AppState _buildLearnerState({
  String activeSiteId = 'site-1',
  List<String> siteIds = const <String>['site-1'],
}) {
  final AppState state = AppState();
  state.updateFromMeResponse(<String, dynamic>{
    'userId': 'learner-1',
    'email': 'learner-1@scholesa.test',
    'displayName': 'Test User',
    'role': 'learner',
    'activeSiteId': activeSiteId,
    'siteIds': siteIds,
    'localeCode': 'en',
    'entitlements': const <Map<String, dynamic>>[],
  });
  return state;
}

Widget _buildHarness({
  required AppState appState,
  FirestoreService? firestoreService,
  SharedPreferences? sharedPreferences,
  LearnerPortfolioPage? child,
}) {
  final List<SingleChildWidget> providers = <SingleChildWidget>[
    ChangeNotifierProvider<AppState>.value(value: appState),
    Provider<LearningRuntimeProvider?>.value(value: null),
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
      home: child ?? LearnerPortfolioPage(sharedPreferences: sharedPreferences),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
      'learner portfolio uses site unavailable in the fallback headline when site identity is missing',
      (WidgetTester tester) async {
    final FirestoreService firestoreService = FirestoreService(
      firestore: FakeFirebaseFirestore(),
      auth: _MockFirebaseAuth(),
    );

    await tester.binding.setSurfaceSize(const Size(1280, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildHarness(
        appState:
            _buildLearnerState(activeSiteId: '', siteIds: const <String>[]),
        firestoreService: firestoreService,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Account menu'), findsOneWidget);
    expect(find.text('Future Innovator • Site unavailable'), findsOneWidget);
    expect(find.text('site-1'), findsNothing);
  });

  testWidgets(
      'learner portfolio badges tab renders live credentials instead of a fake empty state',
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
        'title': 'Impact Builder',
        'issuedAt': Timestamp.fromDate(DateTime(2026, 3, 18)),
        'pillarCodes': const <String>['impact'],
        'skillIds': const <String>['prototype'],
      },
    );

    await tester.binding.setSurfaceSize(const Size(1280, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildHarness(
        appState: _buildLearnerState(),
        firestoreService: firestoreService,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Account menu'), findsOneWidget);
    expect(find.text('Impact Builder'), findsOneWidget);
    expect(find.text('Issued 3/18/2026'), findsOneWidget);
    expect(find.text('No badges earned yet'), findsNothing);
  });

  testWidgets(
      'learner portfolio edit reports storage unavailable instead of pretending the profile was saved',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildHarness(
        appState: _buildLearnerState(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit).first);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Portfolio Headline'),
      'Stored headline that should not persist',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Profile storage unavailable right now.'), findsOneWidget);
    expect(find.text('Portfolio profile updated.'), findsNothing);
    expect(find.text('Stored headline that should not persist'), findsNothing);
  });

  testWidgets(
      'learner portfolio AI coach shows an unavailable message and stays expanded on reopen',
      (WidgetTester tester) async {
    final FirestoreService firestoreService = FirestoreService(
      firestore: FakeFirebaseFirestore(),
      auth: _MockFirebaseAuth(),
    );
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    await tester.binding.setSurfaceSize(const Size(1280, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildHarness(
        appState: _buildLearnerState(),
        firestoreService: firestoreService,
        sharedPreferences: prefs,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AI guidance unavailable right now.'), findsNothing);

    await tester.tap(find.byIcon(Icons.expand_more));
    await tester.pumpAndSettle();

    expect(find.text('AI guidance unavailable right now.'), findsOneWidget);
    expect(
      find.text(
        'Your saved badges, skills, and projects are still available while AI reflection reconnects.',
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      _buildHarness(
        appState: _buildLearnerState(),
        firestoreService: firestoreService,
        sharedPreferences: prefs,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AI guidance unavailable right now.'), findsOneWidget);
    expect(find.byIcon(Icons.expand_less), findsOneWidget);
  });

  testWidgets(
      'learner portfolio keeps stale evidence visible after refresh failure',
      (WidgetTester tester) async {
    int loadCount = 0;

    await tester.binding.setSurfaceSize(const Size(1280, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildHarness(
        appState: _buildLearnerState(),
        firestoreService: FirestoreService(
          firestore: FakeFirebaseFirestore(),
          auth: _MockFirebaseAuth(),
        ),
        child: LearnerPortfolioPage(
          portfolioStateLoader: (String learnerId, String siteId) async {
            loadCount += 1;
            if (loadCount == 1) {
              return LearnerPortfolioSnapshot(
                profile: LearnerProfileModel(
                  id: 'profile-1',
                  learnerId: learnerId,
                  siteId: siteId,
                  onboardingCompleted: true,
                  portfolioHeadline: 'Impact builder in progress',
                  portfolioGoal: 'Ship one verified artifact each week',
                  portfolioHighlight: 'Latest highlight: Water prototype',
                  strengths: const <String>['Collaboration'],
                  interests: const <String>['Robotics'],
                  goals: const <String>['Prototype testing'],
                ),
                items: <PortfolioItemModel>[
                  PortfolioItemModel(
                    id: 'portfolio-1',
                    learnerId: learnerId,
                    siteId: siteId,
                    title: 'Water prototype',
                    description: 'Built and documented a first prototype.',
                    pillarCodes: const <String>['impact'],
                    capabilityTitles: const <String>['Systems Thinking'],
                    evidenceRecordIds: const <String>['evidence-1'],
                    createdAt: Timestamp.fromDate(DateTime(2026, 3, 18)),
                    updatedAt: Timestamp.fromDate(DateTime(2026, 3, 19)),
                  ),
                ],
                credentials: <CredentialModel>[
                  CredentialModel(
                    id: 'credential-1',
                    siteId: siteId,
                    learnerId: learnerId,
                    title: 'Impact Builder',
                    issuedAt: Timestamp.fromDate(DateTime(2026, 3, 18)),
                    pillarCodes: const <String>['impact'],
                    skillIds: const <String>['prototype'],
                  ),
                ],
              );
            }
            throw StateError('portfolio refresh unavailable');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Impact Builder'), findsOneWidget);
    expect(find.text('Water prototype'), findsNothing);

    await tester.tap(find.byTooltip('Refresh'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Unable to refresh portfolio right now. Showing the last successful data.',
      ),
      findsOneWidget,
    );
    expect(find.text('Impact Builder'), findsOneWidget);
    expect(find.text('No badges earned yet'), findsNothing);
  });
}
