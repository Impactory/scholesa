import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/modules/partner/partner_payouts_page.dart';
import 'package:scholesa_app/modules/partner/partner_service.dart';
import 'package:scholesa_app/services/firestore_service.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _FailingPartnerService extends PartnerService {
  _FailingPartnerService()
      : super(
          firestoreService: FirestoreService(
            firestore: FakeFirebaseFirestore(),
            auth: _MockFirebaseAuth(),
          ),
          partnerId: 'partner-1',
        );

  bool _loading = false;
  String? _loadError;

  @override
  bool get isLoading => _loading;

  @override
  String? get error => _loadError;

  @override
  Future<void> loadPayouts() async {
    _loading = true;
    _loadError = null;
    notifyListeners();
    _loading = false;
    _loadError = 'Unable to load payouts right now.';
    notifyListeners();
  }
}

Widget _buildHarness(PartnerService partnerService) {
  return MultiProvider(
    providers: <SingleChildWidget>[
      ChangeNotifierProvider<PartnerService>.value(value: partnerService),
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
      home: const PartnerPayoutsPage(),
    ),
  );
}

void main() {
  testWidgets('partner payouts shows a real load error instead of fake zero history',
      (WidgetTester tester) async {
    final _FailingPartnerService service = _FailingPartnerService();

    await tester.pumpWidget(_buildHarness(service));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Payouts are temporarily unavailable'), findsOneWidget);
    expect(find.text('Unable to load payouts right now.'), findsOneWidget);
    expect(find.text('No Payouts Yet'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
  });
}