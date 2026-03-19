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
      home: const LearnerCredentialsPage(),
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
        'pillarCodes': const <String>['future_skills', 'leadership'],
        'skillIds': const <String>['collaboration', 'python'],
      },
    );

    await tester.pumpWidget(
      _buildHarness(
        appState: _buildLearnerState(),
        firestoreService: firestoreService,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Credentials'), findsOneWidget);
    expect(find.text('Future Skills Sprint'), findsOneWidget);
    expect(find.text('Issued 3/18/2026'), findsOneWidget);
    expect(find.text('Future Skills'), findsOneWidget);
    expect(find.text('Leadership'), findsOneWidget);
    expect(find.text('Skills tagged: 2'), findsOneWidget);
  });

  testWidgets('learner credentials page reports missing storage honestly',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _buildHarness(appState: _buildLearnerState()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Credential storage unavailable right now.'),
        findsOneWidget);
    expect(find.text('No credentials issued yet'), findsNothing);
  });
}
