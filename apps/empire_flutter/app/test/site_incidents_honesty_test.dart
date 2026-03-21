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
import 'package:scholesa_app/modules/site/site_incidents_page.dart';
import 'package:scholesa_app/services/firestore_service.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

AppState _buildSiteState() {
  final AppState appState = AppState();
  appState.updateFromMeResponse(<String, dynamic>{
    'userId': 'site-1-admin',
    'email': 'site-admin@scholesa.test',
    'displayName': 'Site Admin',
    'role': 'site',
    'activeSiteId': 'site-1',
    'siteIds': <String>['site-1'],
    'localeCode': 'en',
    'entitlements': const <Map<String, dynamic>>[],
  });
  return appState;
}

Widget _buildHarness({
  required AppState appState,
  required FirestoreService firestoreService,
  SharedPreferences? sharedPreferences,
  SiteIncidentsPage? child,
}) {
  return MultiProvider(
    providers: <SingleChildWidget>[
      ChangeNotifierProvider<AppState>.value(value: appState),
      Provider<FirestoreService>.value(value: firestoreService),
    ],
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
      home: child ?? SiteIncidentsPage(sharedPreferences: sharedPreferences),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('site incidents shows a real load error instead of a fake empty state',
      (WidgetTester tester) async {
    final FirestoreService firestoreService = FirestoreService(
      firestore: FakeFirebaseFirestore(),
      auth: _MockFirebaseAuth(),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<AppState>.value(value: _buildSiteState()),
          Provider<FirestoreService>.value(value: firestoreService),
        ],
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
          home: SiteIncidentsPage(
            incidentsLoader: (String _) async {
              throw StateError('incidents backend unavailable');
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Account menu'), findsOneWidget);
    expect(find.text('Incidents are temporarily unavailable'), findsOneWidget);
    expect(
      find.text('We could not load incidents. Retry to check the current state.'),
      findsOneWidget,
    );
    expect(find.textContaining('No incidents'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.byTooltip('Refresh'), findsOneWidget);
  });

  testWidgets(
      'site incidents use honest unavailable identities in list and details',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await firestore.collection('incidents').doc('incident-1').set(
      <String, dynamic>{
        'siteId': 'site-1',
        'title': 'Playground incident',
        'severity': 'minor',
        'status': 'submitted',
        'learnerName': 'Unknown',
        'reportedAt': DateTime(2026, 3, 17, 9).millisecondsSinceEpoch,
      },
    );

    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );

    await tester.binding.setSurfaceSize(const Size(1280, 1800));
    await tester.pumpWidget(
      _buildHarness(
        appState: _buildSiteState(),
        firestoreService: firestoreService,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Account menu'), findsOneWidget);
    expect(find.text('Playground incident'), findsOneWidget);
    expect(find.text('Learner unavailable'), findsOneWidget);
    expect(find.textContaining('Reported by Reporter unavailable'),
        findsOneWidget);
    expect(find.text('Unknown'), findsNothing);

    await tester.tap(find.text('Playground incident'));
    await tester.pumpAndSettle();

    expect(find.text('Reporter unavailable'), findsWidgets);
    expect(find.text('Learner unavailable'), findsWidgets);
    expect(find.text('Unknown'), findsNothing);
  });

      testWidgets('site incidents keep stale evidence visible after refresh failure',
          (WidgetTester tester) async {
        final FirestoreService firestoreService = FirestoreService(
          firestore: FakeFirebaseFirestore(),
          auth: _MockFirebaseAuth(),
        );
        int loadCount = 0;

        await tester.pumpWidget(
          _buildHarness(
            appState: _buildSiteState(),
            firestoreService: firestoreService,
            child: SiteIncidentsPage(
              incidentsLoader: (String _) async {
                loadCount += 1;
                if (loadCount == 1) {
                  return <Map<String, dynamic>>[
                    <String, dynamic>{
                      'id': 'incident-1',
                      'title': 'Playground incident',
                      'severity': 'minor',
                      'status': 'submitted',
                      'learnerName': 'Learner One',
                      'reportedByName': 'Staff One',
                      'reportedAt': DateTime(2026, 3, 17, 9).millisecondsSinceEpoch,
                    },
                  ];
                }
                throw StateError('incidents refresh unavailable');
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Playground incident'), findsOneWidget);
        expect(find.textContaining('No incidents'), findsNothing);

        await tester.tap(find.byTooltip('Refresh'));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Unable to refresh incidents right now. Showing the last successful data.',
          ),
          findsOneWidget,
        );
        expect(find.text('Playground incident'), findsOneWidget);
        expect(find.textContaining('No incidents'), findsNothing);
      });

  testWidgets('site incidents restores the selected status tab on reopen',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      _buildHarness(
        appState: _buildSiteState(),
        firestoreService: firestoreService,
        sharedPreferences: prefs,
        child: SiteIncidentsPage(
          sharedPreferences: prefs,
          incidentsLoader: (String _) async => <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'incident-open',
              'title': 'Open Playground Incident',
              'severity': 'minor',
              'status': 'submitted',
              'learnerName': 'Learner One',
              'reportedByName': 'Staff One',
              'reportedAt': DateTime(2026, 3, 17, 9).millisecondsSinceEpoch,
            },
            <String, dynamic>{
              'id': 'incident-reviewed',
              'title': 'Reviewed Lab Incident',
              'severity': 'major',
              'status': 'reviewed',
              'learnerName': 'Learner Two',
              'reportedByName': 'Staff Two',
              'reportedAt': DateTime(2026, 3, 17, 10).millisecondsSinceEpoch,
            },
            <String, dynamic>{
              'id': 'incident-closed',
              'title': 'Closed Arrival Incident',
              'severity': 'critical',
              'status': 'closed',
              'learnerName': 'Learner Three',
              'reportedByName': 'Staff Three',
              'reportedAt': DateTime(2026, 3, 17, 11).millisecondsSinceEpoch,
            },
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Open Playground Incident'), findsOneWidget);
    expect(find.text('Reviewed Lab Incident'), findsNothing);
    expect(find.text('Closed Arrival Incident'), findsNothing);

    await tester.tap(find.text('Reviewed'));
    await tester.pumpAndSettle();

    expect(find.text('Open Playground Incident'), findsNothing);
    expect(find.text('Reviewed Lab Incident'), findsOneWidget);
    expect(find.text('Closed Arrival Incident'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      _buildHarness(
        appState: _buildSiteState(),
        firestoreService: firestoreService,
        sharedPreferences: prefs,
        child: SiteIncidentsPage(
          sharedPreferences: prefs,
          incidentsLoader: (String _) async => <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'incident-open',
              'title': 'Open Playground Incident',
              'severity': 'minor',
              'status': 'submitted',
              'learnerName': 'Learner One',
              'reportedByName': 'Staff One',
              'reportedAt': DateTime(2026, 3, 17, 9).millisecondsSinceEpoch,
            },
            <String, dynamic>{
              'id': 'incident-reviewed',
              'title': 'Reviewed Lab Incident',
              'severity': 'major',
              'status': 'reviewed',
              'learnerName': 'Learner Two',
              'reportedByName': 'Staff Two',
              'reportedAt': DateTime(2026, 3, 17, 10).millisecondsSinceEpoch,
            },
            <String, dynamic>{
              'id': 'incident-closed',
              'title': 'Closed Arrival Incident',
              'severity': 'critical',
              'status': 'closed',
              'learnerName': 'Learner Three',
              'reportedByName': 'Staff Three',
              'reportedAt': DateTime(2026, 3, 17, 11).millisecondsSinceEpoch,
            },
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Reviewed Lab Incident'), findsOneWidget);
    expect(find.text('Open Playground Incident'), findsNothing);
    expect(find.text('Closed Arrival Incident'), findsNothing);
  });
}
