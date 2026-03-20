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
import 'package:scholesa_app/router/role_gate.dart';
import 'package:scholesa_app/services/firestore_service.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

AppState _buildAppState() {
  final AppState state = AppState();
  state.updateFromMeResponse(<String, dynamic>{
    'userId': 'parent-user-1',
    'email': 'parent-user-1@scholesa.test',
    'displayName': 'Parent User',
    'role': 'parent',
    'activeSiteId': 'site-1',
    'siteIds': <String>['site-1'],
    'localeCode': 'en',
    'entitlements': <dynamic>[],
  });
  return state;
}

Widget _buildHarness({required List<SingleChildWidget> providers}) {
  return MultiProvider(
    providers: providers,
    child: MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        splashFactory: NoSplash.splashFactory,
      ),
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
      home: const Scaffold(
        body: Center(
          child: EntitlementGate(
            feature: 'family_billing_plus',
            child: SizedBox.shrink(),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('entitlement gate persists access review requests',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore fakeFirestore = FakeFirebaseFirestore();
    final FirestoreService firestoreService = FirestoreService(
      firestore: fakeFirestore,
      auth: _MockFirebaseAuth(),
    );

    await tester.pumpWidget(
      _buildHarness(
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<AppState>.value(value: _buildAppState()),
          Provider<FirestoreService>.value(value: firestoreService),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Request Access Review'), findsOneWidget);
    await tester.tap(find.text('Request Access Review'));
    await tester.pumpAndSettle();

    expect(find.text('Access review request submitted.'), findsOneWidget);

    final QuerySnapshot<Map<String, dynamic>> supportRequests =
        await fakeFirestore.collection('supportRequests').get();
    expect(supportRequests.docs, hasLength(1));
    expect(
      supportRequests.docs.single.data()['requestType'],
      'feature_access_review',
    );
    expect(
      supportRequests.docs.single.data()['source'],
      'entitlement_gate_request_access_review',
    );
    expect(
      (supportRequests.docs.single.data()['metadata'] as Map<String, dynamic>)[
        'feature'
      ],
      'family_billing_plus',
    );
  });

  testWidgets('entitlement gate fails closed when support requests are unavailable',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _buildHarness(
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<AppState>.value(value: _buildAppState()),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Request Access Review'));
    await tester.pumpAndSettle();

    expect(find.text('Support requests are unavailable right now.'), findsOneWidget);
  });
}