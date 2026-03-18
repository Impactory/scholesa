import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/modules/parent/parent_billing_page.dart';
import 'package:scholesa_app/modules/parent/parent_models.dart';
import 'package:scholesa_app/modules/parent/parent_portfolio_page.dart';
import 'package:scholesa_app/modules/parent/parent_schedule_page.dart';
import 'package:scholesa_app/modules/parent/parent_service.dart';
import 'package:scholesa_app/modules/parent/parent_summary_page.dart';
import 'package:scholesa_app/runtime/learning_runtime_provider.dart';
import 'package:scholesa_app/services/firestore_service.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

final ThemeData _workflowTheme = ThemeData(
  useMaterial3: true,
  splashFactory: InkRipple.splashFactory,
);

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

String? _parentScheduleClipboardText;

class _FakeUrlLauncherPlatform extends UrlLauncherPlatform {
  final List<String> launchedUrls = <String>[];
  bool canLaunchResult = true;
  bool launchResult = true;

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => canLaunchResult;

  @override
  Future<void> closeWebView() async {}

  @override
  Future<bool> launch(
    String url, {
    required bool useSafariVC,
    required bool useWebView,
    required bool enableJavaScript,
    required bool enableDomStorage,
    required bool universalLinksOnly,
    required Map<String, String> headers,
    String? webOnlyWindowName,
  }) async {
    launchedUrls.add(url);
    return launchResult;
  }

  @override
  Future<bool> supportsCloseForMode(PreferredLaunchMode mode) async => false;

  @override
  Future<bool> supportsMode(PreferredLaunchMode mode) async => true;
}

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

Future<void> _seedParentData(FakeFirebaseFirestore firestore) async {
  final DateTime now = DateTime.now();
  final DateTime anchor = DateTime(now.year, now.month, now.day, 12);
  await firestore.collection('users').doc('parent-1').set(<String, dynamic>{
    'role': 'parent',
    'displayName': 'Parent One',
    'learnerIds': <String>['learner-1'],
  });
  await firestore
      .collection('guardianLinks')
      .doc('link-1')
      .set(<String, dynamic>{
    'parentId': 'parent-1',
    'learnerId': 'learner-1',
  });
  await firestore.collection('users').doc('learner-1').set(<String, dynamic>{
    'role': 'learner',
    'displayName': 'Ava Learner',
  });
  await firestore.collection('users').doc('learner-2').set(<String, dynamic>{
    'role': 'learner',
    'displayName': 'Unaffiliated Learner',
    'parentIds': <String>['other-parent'],
  });
  await firestore
      .collection('learnerProgress')
      .doc('learner-1')
      .set(<String, dynamic>{
    'level': 4,
    'totalXp': 1200,
    'missionsCompleted': 5,
    'currentStreak': 7,
    'futureSkillsProgress': 0.8,
    'leadershipProgress': 0.6,
    'impactProgress': 0.4,
  });
  await firestore
      .collection('activities')
      .doc('activity-1')
      .set(<String, dynamic>{
    'learnerId': 'learner-1',
    'title': 'Build a Robot',
    'description': 'Linked Update',
    'type': 'mission',
    'emoji': '🤖',
    'timestamp': Timestamp.fromDate(anchor.subtract(const Duration(hours: 2))),
  });
  await firestore
      .collection('activities')
      .doc('activity-2')
      .set(<String, dynamic>{
    'learnerId': 'learner-2',
    'title': 'Hidden Project',
    'description': 'Hidden Update',
    'type': 'mission',
    'emoji': '🕶',
    'timestamp': Timestamp.fromDate(anchor.subtract(const Duration(hours: 1))),
  });
  await firestore.collection('events').doc('event-1').set(<String, dynamic>{
    'learnerId': 'learner-1',
    'title': 'Robotics Studio',
    'description': 'Prototype review',
    'dateTime': Timestamp.fromDate(now.add(const Duration(days: 1, hours: 1))),
    'type': 'future_skills',
    'location': 'Lab 1',
  });
  await firestore.collection('events').doc('event-2').set(<String, dynamic>{
    'learnerId': 'learner-2',
    'title': 'Hidden Session',
    'description': 'Should not appear',
    'dateTime': Timestamp.fromDate(now.add(const Duration(days: 1, hours: 2))),
    'type': 'future_skills',
    'location': 'Hidden Lab',
  });
  await firestore
      .collection('attendanceRecords')
      .doc('attendance-1')
      .set(<String, dynamic>{
    'learnerId': 'learner-1',
    'status': 'present',
    'recordedAt': Timestamp.fromDate(anchor.subtract(const Duration(days: 1))),
  });
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required FakeFirebaseFirestore firestore,
  required Widget home,
  ParentService? parentService,
}) async {
  tester.view.physicalSize = const Size(1440, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final FirestoreService firestoreService = FirestoreService(
    firestore: firestore,
    auth: _MockFirebaseAuth(),
  );
  final ParentService resolvedParentService = parentService ??
      ParentService(
        firestoreService: firestoreService,
        parentId: 'parent-1',
      );

  await tester.pumpWidget(
    MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<AppState>.value(value: _buildParentState()),
        Provider<FirestoreService>.value(value: firestoreService),
        ChangeNotifierProvider<ParentService>.value(
            value: resolvedParentService),
        Provider<LearningRuntimeProvider?>.value(value: null),
      ],
      child: MaterialApp(
        theme: _workflowTheme,
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
        home: home,
      ),
    ),
  );

  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (
      MethodCall methodCall,
    ) async {
      if (methodCall.method == 'Clipboard.setData') {
        final Map<Object?, Object?>? arguments =
            methodCall.arguments as Map<Object?, Object?>?;
        _parentScheduleClipboardText = arguments?['text']?.toString();
      }
      return null;
    });
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  setUp(() {
    _parentScheduleClipboardText = null;
  });

  group('Parent surface workflows', () {
    testWidgets('summary page only renders linked learner activity',
        (WidgetTester tester) async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      await _seedParentData(firestore);

      await _pumpPage(
        tester,
        firestore: firestore,
        home: const ParentSummaryPage(),
      );

      expect(find.text('Ava Learner'), findsOneWidget);
      expect(find.text('Build a Robot'), findsOneWidget);
      expect(find.text('Hidden Project'), findsNothing);
    });

    testWidgets('schedule page shows linked session details and reminder flow',
        (WidgetTester tester) async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      await _seedParentData(firestore);

      await _pumpPage(
        tester,
        firestore: firestore,
        home: const ParentSchedulePage(),
      );

      expect(find.text('Hidden Session'), findsNothing);

      await tester.ensureVisible(find.text('Details'));
      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();

      expect(find.text('Next Session Details'), findsOneWidget);
      expect(find.textContaining('Robotics Studio\nLocation: Lab 1'),
          findsOneWidget);
      expect(find.textContaining('Location: Lab 1'), findsOneWidget);

      expect(find.widgetWithText(TextButton, 'Set Reminder'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Set Reminder'));
      await tester.pumpAndSettle();

      expect(find.text('Session reminder copied for sharing.'), findsOneWidget);
      expect(_parentScheduleClipboardText, isNotNull);
      expect(_parentScheduleClipboardText, contains('Session Reminder'));
      expect(_parentScheduleClipboardText, contains('Robotics Studio'));
    });

    testWidgets('portfolio page shows explicit unavailable share state',
        (WidgetTester tester) async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      final _FakeUrlLauncherPlatform launcherPlatform =
          _FakeUrlLauncherPlatform();
      final UrlLauncherPlatform previousLauncherPlatform =
          UrlLauncherPlatform.instance;
      await _seedParentData(firestore);

      UrlLauncherPlatform.instance = launcherPlatform;
      try {
        await _pumpPage(
          tester,
          firestore: firestore,
          home: const ParentPortfolioPage(),
        );

        expect(find.text('Build a Robot'), findsOneWidget);
        expect(find.text('Hidden Project'), findsNothing);

        await tester.ensureVisible(find.text('Build a Robot').first);
        await tester.tap(find.text('Build a Robot').first);
        await tester.pumpAndSettle();

        expect(find.widgetWithText(OutlinedButton, 'Share'), findsOneWidget);
        expect(find.widgetWithText(ElevatedButton, 'Download'), findsOneWidget);

        await tester.tap(find.widgetWithText(OutlinedButton, 'Share'));
        await tester.pumpAndSettle();

        expect(
          launcherPlatform.launchedUrls,
          contains(
            predicate<String>(
              (String value) =>
                  value.startsWith('mailto:support@scholesa.com?') &&
                  value.contains('portfolio+share+request'),
            ),
          ),
        );
        expect(
          find.text('Portfolio sharing is not available in the app yet'),
          findsNothing,
        );
      } finally {
        UrlLauncherPlatform.instance = previousLauncherPlatform;
      }
    });

    testWidgets('portfolio page launches support email for download state',
        (WidgetTester tester) async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      final _FakeUrlLauncherPlatform launcherPlatform =
          _FakeUrlLauncherPlatform();
      final UrlLauncherPlatform previousLauncherPlatform =
          UrlLauncherPlatform.instance;
      await _seedParentData(firestore);

      UrlLauncherPlatform.instance = launcherPlatform;
      try {
        await _pumpPage(
          tester,
          firestore: firestore,
          home: const ParentPortfolioPage(),
        );

        await tester.ensureVisible(find.text('Build a Robot').first);
        await tester.tap(find.text('Build a Robot').first);
        await tester.pumpAndSettle();

        expect(find.widgetWithText(ElevatedButton, 'Download'), findsOneWidget);

        await tester.tap(find.widgetWithText(ElevatedButton, 'Download'));
        await tester.pumpAndSettle();

        expect(
          launcherPlatform.launchedUrls,
          contains(
            predicate<String>(
              (String value) =>
                  value.startsWith('mailto:support@scholesa.com?') &&
                  value.contains('portfolio+download+request'),
            ),
          ),
        );
        expect(
          find.text('Portfolio downloads are not available in the app yet'),
          findsNothing,
        );
      } finally {
        UrlLauncherPlatform.instance = previousLauncherPlatform;
      }
    });

    testWidgets(
        'billing page shows explicit unavailable state when no billing data exists',
        (WidgetTester tester) async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      await _seedParentData(firestore);

      await _pumpPage(
        tester,
        firestore: firestore,
        home: const ParentBillingPage(),
      );

      expect(find.text('No billing data yet'), findsOneWidget);
      expect(find.byIcon(Icons.download), findsNothing);
      expect(
        find.text('Statements are shared by your site or HQ billing team.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Plan'));
      await tester.pumpAndSettle();
      expect(find.text('Billing plan unavailable'), findsOneWidget);
      expect(find.text('All paid'), findsNothing);
      expect(find.text('Active'), findsNothing);
    });

    testWidgets(
        'billing page keeps populated invoices and plan controls read-only',
        (WidgetTester tester) async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      await _seedParentData(firestore);

      final FirestoreService firestoreService = FirestoreService(
        firestore: firestore,
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
            PaymentHistory(
              id: 'INV-2026-02',
              amount: 149.0,
              date: DateTime(2026, 2, 1),
              status: 'paid',
              description: 'Visa ending 4242',
            ),
          ],
        ),
      );

      await _pumpPage(
        tester,
        firestore: firestore,
        parentService: parentService,
        home: const ParentBillingPage(),
      );

      expect(find.text('INV-2026-03'), findsOneWidget);
      expect(find.text('NEXT-DUE'), findsOneWidget);
      expect(find.text('Pay Now'), findsNothing);
      expect(find.text('View'), findsNothing);
      expect(
        find.text(
            'Invoice actions are handled by your site or HQ billing team.'),
        findsNWidgets(2),
      );

      await tester.tap(find.text('Plan'));
      await tester.pumpAndSettle();

      expect(find.text('FAMILY PLAN'), findsOneWidget);
      expect(
        find.text('Payment method changes are handled by HQ billing support.'),
        findsOneWidget,
      );
      expect(
        find.text('Plan changes are handled by HQ billing support.'),
        findsOneWidget,
      );
      expect(find.text('Manage Plan'), findsNothing);
    });
  });
}
