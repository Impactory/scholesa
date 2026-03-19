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
      home: const LearnerPortfolioPage(),
    ),
  );
}

void main() {
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
}
