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
import 'package:scholesa_app/modules/hq_admin/hq_sites_page.dart';
import 'package:scholesa_app/services/firestore_service.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

Widget _buildHarness(
  FirestoreService firestoreService, {
  Future<List<Map<String, dynamic>>> Function()? loadSitesOverride,
  AppState? appState,
}) {
  return MultiProvider(
    providers: <SingleChildWidget>[
      Provider<FirestoreService>.value(value: firestoreService),
      if (appState != null)
        ChangeNotifierProvider<AppState>.value(
          value: appState,
        ),
    ],
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
      home: HqSitesPage(loadSitesOverride: loadSitesOverride),
    ),
  );
}

Future<void> _seedSites(FakeFirebaseFirestore firestore) async {
  await firestore.collection('sites').doc('site-active').set(<String, dynamic>{
    'name': 'Alpha Studio',
    'location': 'Singapore',
    'status': 'active',
    'learnerCount': 42,
    'educatorCount': 5,
    'healthScore': 96,
  });
  await firestore
      .collection('sites')
      .doc('site-onboarding')
      .set(<String, dynamic>{
    'name': 'Beta Studio',
    'location': 'Hong Kong',
    'status': 'onboarding',
    'learnerIds': <String>['l1', 'l2'],
    'educatorIds': <String>['e1'],
  });
  await firestore.collection('sites').doc('site-pending').set(<String, dynamic>{
    'name': 'Gamma Studio',
    'location': 'Taipei',
    'status': 'pending',
    'learnerCount': 0,
    'educatorCount': 0,
    'healthScore': 0,
  });
}

void main() {
  testWidgets('HQ sites page loads stats and filters onboarding sites',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await _seedSites(firestore);
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );

    await tester.pumpWidget(_buildHarness(firestoreService));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Account menu'), findsOneWidget);
    expect(find.text('Sites Management'), findsOneWidget);
    expect(find.text('Alpha Studio'), findsOneWidget);
    expect(find.text('Beta Studio'), findsOneWidget);
    expect(find.text('3'), findsWidgets);

    await tester.tap(find.text('Onboarding'));
    await tester.pumpAndSettle();

    expect(find.text('Beta Studio'), findsOneWidget);
    expect(find.text('Alpha Studio'), findsNothing);
    expect(find.text('Gamma Studio'), findsNothing);
  });

  testWidgets('HQ sites page search narrows site results',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await _seedSites(firestore);
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );

    await tester.pumpWidget(_buildHarness(firestoreService));
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Taipei');
    await tester.pumpAndSettle();

    expect(find.text('Gamma Studio'), findsOneWidget);
    expect(find.text('Alpha Studio'), findsNothing);
    expect(find.text('Beta Studio'), findsNothing);
  });

  testWidgets('HQ sites page creates a pending site through the create sheet',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await _seedSites(firestore);
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );

    await tester.pumpWidget(_buildHarness(firestoreService));
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add Site'));
    await tester.pumpAndSettle();

    expect(find.text('Add New Site'), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextField, 'Site Name'), 'Delta Studio');
    await tester.enterText(find.widgetWithText(TextField, 'Location'), 'Seoul');

    await tester.tap(find.text('Create Site'));
    await tester.pumpAndSettle();

    expect(find.text('Site created successfully'), findsOneWidget);

    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await firestore.collection('sites').get();
    final Iterable<Map<String, dynamic>> created = snapshot.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) => doc.data())
        .where((Map<String, dynamic> data) => data['name'] == 'Delta Studio');
    expect(created.length, 1);
    expect(created.single['status'], 'pending');
    expect(created.single['location'], 'Seoul');
  });

  testWidgets(
      'HQ sites page shows an explicit unavailable state instead of a fake empty list',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );

    await tester.pumpWidget(
      _buildHarness(
        firestoreService,
        loadSitesOverride: () async {
          throw StateError('sites backend unavailable');
        },
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Account menu'), findsOneWidget);
    expect(find.text('Sites are temporarily unavailable'), findsOneWidget);
    expect(
      find.text(
          'We could not load sites right now. Retry to check the current state.'),
      findsOneWidget,
    );
    expect(find.text('No sites found'), findsNothing);
  });

  testWidgets('HQ sites page keeps stale data visible when a refresh fails',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    int loadCalls = 0;

    await tester.pumpWidget(
      _buildHarness(
        firestoreService,
        loadSitesOverride: () async {
          loadCalls += 1;
          if (loadCalls == 1) {
            return <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'site-active',
                'name': 'Alpha Studio',
                'location': 'Singapore',
                'status': 'active',
                'learnerCount': 42,
                'educatorCount': 5,
                'healthScore': 96,
              },
            ];
          }
          throw StateError('sites refresh unavailable');
        },
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Alpha Studio'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.refresh).first);
    await tester.pumpAndSettle();

    expect(find.text('Alpha Studio'), findsOneWidget);
    expect(
      find.text(
          'Unable to refresh sites right now. Showing the last successful data.'),
      findsOneWidget,
    );
    expect(find.text('No sites found'), findsNothing);
  });

  testWidgets('HQ sites page selecting a site updates active site context',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await _seedSites(firestore);
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    final AppState appState = AppState()
      ..updateFromMeResponse(<String, dynamic>{
        'userId': 'hq123',
        'email': 'hq@example.com',
        'displayName': 'HQ User',
        'role': 'hq',
        'activeSiteId': null,
        'siteIds': <String>[],
        'entitlements': <dynamic>[],
      });

    await tester.pumpWidget(
      _buildHarness(firestoreService, appState: appState),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Alpha Studio'));
    await tester.pumpAndSettle();

    expect(appState.activeSiteId, equals('site-active'));
    expect(appState.siteIds, contains('site-active'));
  });
}
