import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
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
      home: const SiteIncidentsPage(),
    ),
  );
}

void main() {
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

    expect(find.text('Incidents are temporarily unavailable'), findsOneWidget);
    expect(
      find.text('We could not load incidents. Retry to check the current state.'),
      findsOneWidget,
    );
    expect(find.textContaining('No incidents'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
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
}
