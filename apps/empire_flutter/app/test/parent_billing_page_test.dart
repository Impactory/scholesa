import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/modules/parent/parent_billing_page.dart';
import 'package:scholesa_app/modules/parent/parent_models.dart';
import 'package:scholesa_app/modules/parent/parent_service.dart';
import 'package:scholesa_app/services/firestore_service.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _StubParentService extends ParentService {
  _StubParentService({
    required super.firestoreService,
    required super.parentId,
    required this.stubLearnerSummaries,
    required this.stubBillingSummary,
  });

  final List<LearnerSummary> stubLearnerSummaries;
  final BillingSummary? stubBillingSummary;

  @override
  List<LearnerSummary> get learnerSummaries => stubLearnerSummaries;

  @override
  BillingSummary? get billingSummary => stubBillingSummary;

  @override
  bool get isLoading => false;

  @override
  Future<void> loadParentData() async {}
}

AppState _buildParentState() {
  final AppState state = AppState();
  state.updateFromMeResponse(<String, dynamic>{
    'userId': 'parent-1',
    'email': 'parent001.demo@scholesa.org',
    'displayName': 'Parent One',
    'role': 'parent',
    'activeSiteId': 'site-1',
    'siteIds': <String>['site-1'],
    'entitlements': <dynamic>[],
  });
  return state;
}

Widget _buildHarness({required ParentService parentService}) {
  return MultiProvider(
    providers: <SingleChildWidget>[
      ChangeNotifierProvider<AppState>.value(value: _buildParentState()),
      ChangeNotifierProvider<ParentService>.value(value: parentService),
    ],
    child: MaterialApp(
      theme: ThemeData(useMaterial3: true),
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
      home: const ParentBillingPage(),
    ),
  );
}

void main() {
  testWidgets('parent billing page shows explicit unavailable state',
      (WidgetTester tester) async {
    final FirestoreService firestoreService = FirestoreService(
      firestore: FakeFirebaseFirestore(),
      auth: _MockFirebaseAuth(),
    );
    final ParentService parentService = _StubParentService(
      firestoreService: firestoreService,
      parentId: 'parent-1',
      stubLearnerSummaries: <LearnerSummary>[],
      stubBillingSummary: null,
    );

    await tester.binding.setSurfaceSize(const Size(1280, 1800));
    await tester.pumpWidget(_buildHarness(parentService: parentService));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('No billing data yet'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('No billing data yet'), findsOneWidget);
    expect(find.text('Statements are shared by your site or HQ billing team.'), findsOneWidget);
    await tester.tap(find.text('Plan'));
    await tester.pumpAndSettle();
    expect(find.text('Billing plan unavailable'), findsOneWidget);
  });

  testWidgets('parent billing page keeps populated controls read-only',
      (WidgetTester tester) async {
    final FirestoreService firestoreService = FirestoreService(
      firestore: FakeFirebaseFirestore(),
      auth: _MockFirebaseAuth(),
    );
    final ParentService parentService = _StubParentService(
      firestoreService: firestoreService,
      parentId: 'parent-1',
      stubLearnerSummaries: <LearnerSummary>[
        LearnerSummary(
          learnerId: 'learner-1',
          learnerName: 'Ava Learner',
          currentLevel: 4,
          totalXp: 1200,
          missionsCompleted: 5,
          currentStreak: 7,
          attendanceRate: 1.0,
        ),
      ],
      stubBillingSummary: BillingSummary(
        currentBalance: 199.0,
        nextPaymentAmount: 199.0,
        nextPaymentDate: DateTime(2026, 4, 1),
        subscriptionPlan: 'Family Plan',
        recentPayments: <PaymentHistory>[
          PaymentHistory(
            id: 'INV-2026-03',
            amount: 199.0,
            date: DateTime(2026, 3, 1),
            status: 'due',
            description: 'Visa ending 4242',
          ),
        ],
      ),
    );

    await tester.binding.setSurfaceSize(const Size(1280, 1800));
    await tester.pumpWidget(_buildHarness(parentService: parentService));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('INV-2026-03'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('INV-2026-03'), findsOneWidget);
    expect(find.text('Pay Now'), findsNothing);
    expect(find.text('Invoice actions are handled by your site or HQ billing team.'), findsWidgets);
    await tester.tap(find.text('Plan'));
    await tester.pumpAndSettle();
    expect(find.text('Payment method changes are handled by HQ billing support.'), findsOneWidget);
    expect(find.text('Manage Plan'), findsNothing);
  });
}