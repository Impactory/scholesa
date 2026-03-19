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
import 'package:scholesa_app/modules/partner/partner_deliverables_page.dart';
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
      home: const PartnerDeliverablesPage(),
    ),
  );
}

Future<void> _seedContract(
  FakeFirebaseFirestore firestore, {
  String title = 'North Hub Launch',
}) async {
  await firestore.collection('partnerContracts').doc('contract-1').set(
    <String, dynamic>{
      'partnerId': 'partner-1',
      'siteId': 'site-1',
      'title': title,
      'status': 'active',
    },
  );
}

void main() {
  testWidgets(
      'partner deliverables page shows honest contract-level empty states',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    await _seedContract(firestore);

    await tester.pumpWidget(
      _buildHarness(
        appState: _buildPartnerState(),
        firestoreService: firestoreService,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Partner Deliverables'), findsOneWidget);
    expect(find.text('North Hub Launch'), findsOneWidget);
    expect(find.text('No deliverables submitted yet'), findsAtLeastNWidgets(1));
    expect(
      find.text('Deliverables linked to your partner contracts will appear here.'),
      findsOneWidget,
    );
  });

  testWidgets('partner deliverables page submits a deliverable end to end',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    await _seedContract(firestore);

    await tester.pumpWidget(
      _buildHarness(
        appState: _buildPartnerState(),
        firestoreService: firestoreService,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Submit Deliverable'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'Evidence Pack');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'Pilot summary and session assets',
    );
    await tester.enterText(
      find.byType(TextFormField).at(2),
      'https://files.scholesa.test/evidence-pack.pdf',
    );

    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(find.text('Deliverable submitted.'), findsOneWidget);
    expect(find.text('Evidence Pack'), findsOneWidget);

    final QuerySnapshot<Map<String, dynamic>> snapshot = await firestore
        .collection('partnerDeliverables')
        .where('contractId', isEqualTo: 'contract-1')
        .get();
    expect(snapshot.docs, hasLength(1));
    final Map<String, dynamic> saved = snapshot.docs.first.data();
    expect(saved['title'], 'Evidence Pack');
    expect(saved['description'], 'Pilot summary and session assets');
    expect(saved['evidenceUrl'],
        'https://files.scholesa.test/evidence-pack.pdf');
    expect(saved['submittedBy'], 'partner-1');
  });

  testWidgets('partner deliverables page renders zh-CN copy',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    await _seedContract(firestore, title: '');

    await tester.pumpWidget(
      _buildHarness(
        appState: _buildPartnerState(locale: const Locale('zh', 'CN')),
        firestoreService: firestoreService,
        locale: const Locale('zh', 'CN'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('合作伙伴交付项'), findsOneWidget);
    expect(find.text('合同信息不可用'), findsOneWidget);
    expect(find.text('尚未提交交付项'), findsAtLeastNWidgets(1));
  });
}
