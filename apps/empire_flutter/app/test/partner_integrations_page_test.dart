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
import 'package:scholesa_app/modules/partner/partner_integrations_page.dart';
import 'package:scholesa_app/services/firestore_service.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

AppState _buildPartnerState({Locale locale = const Locale('en')}) {
  final AppState state = AppState();
  state.updateFromMeResponse(<String, dynamic>{
    'userId': 'partner-1',
    'email': 'partner-1@scholesa.test',
    'displayName': 'Partner User',
    'role': 'partner',
    'activeSiteId': 'site-1',
    'siteIds': const <String>['site-1'],
    'localeCode': locale.languageCode == 'zh'
        ? 'zh-${locale.countryCode}'
        : 'en',
    'entitlements': const <Map<String, dynamic>>[],
  });
  return state;
}

Widget _buildHarness({
  required AppState appState,
  required FirestoreService firestoreService,
  Locale locale = const Locale('en'),
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
      locale: locale,
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
      home: const PartnerIntegrationsPage(),
    ),
  );
}

void main() {
  testWidgets('partner integrations page renders live connection state',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );

    await firestore.collection('integrationConnections').doc('connection-1').set(
      <String, dynamic>{
        'ownerUserId': 'partner-1',
        'provider': 'github',
        'status': 'error',
        'scopesGranted': const <String>['repo', 'read:user'],
        'lastError': 'Token refresh failed',
        'createdAt': Timestamp.fromDate(DateTime(2026, 3, 15)),
        'updatedAt': Timestamp.fromDate(DateTime(2026, 3, 18)),
      },
    );

    await tester.pumpWidget(
      _buildHarness(
        appState: _buildPartnerState(),
        firestoreService: firestoreService,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Account menu'), findsOneWidget);
    expect(find.text('Partner Integrations'), findsOneWidget);
    expect(find.text('GitHub'), findsOneWidget);
    expect(find.text('Last updated: 3/18/2026'), findsOneWidget);
    expect(find.text('Scopes granted: 2'), findsOneWidget);
    expect(find.text('Last error: Token refresh failed'), findsOneWidget);
  });

  testWidgets('partner integrations page renders honest zh-TW empty state',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );

    await tester.pumpWidget(
      _buildHarness(
        appState: _buildPartnerState(locale: const Locale('zh', 'TW')),
        firestoreService: firestoreService,
        locale: const Locale('zh', 'TW'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Account menu'), findsOneWidget);
    expect(find.text('合作夥伴整合'), findsOneWidget);
    expect(find.text('尚未連接合作夥伴整合'), findsOneWidget);
    expect(
      find.text('當合作夥伴自有連線完成設定後，已連接的整合會顯示在這裡。'),
      findsOneWidget,
    );
  });
}
