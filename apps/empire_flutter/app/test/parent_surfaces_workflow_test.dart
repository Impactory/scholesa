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
import 'package:scholesa_app/modules/parent/parent_billing_page.dart';
import 'package:scholesa_app/modules/parent/parent_models.dart';
import 'package:scholesa_app/modules/parent/parent_portfolio_page.dart';
import 'package:scholesa_app/modules/parent/parent_schedule_page.dart';
import 'package:scholesa_app/modules/parent/parent_service.dart';
import 'package:scholesa_app/modules/parent/parent_summary_page.dart';
import 'package:scholesa_app/runtime/learning_runtime_provider.dart';
import 'package:scholesa_app/services/export_service.dart';
import 'package:scholesa_app/services/firestore_service.dart';

final ThemeData _workflowTheme = ThemeData(
  useMaterial3: true,
  splashFactory: InkRipple.splashFactory,
);

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

String? _savedFileName;
String? _savedFileContent;

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

  setUp(() {
    _savedFileName = null;
    _savedFileContent = null;
    ExportService.instance.debugSaveTextFile = null;
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

      expect(
          find.widgetWithText(TextButton, 'Request Reminder'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Request Reminder'));
      await tester.pumpAndSettle();

      expect(find.text('Session reminder request submitted.'), findsOneWidget);

      final List<Map<String, dynamic>> supportRequests = (await firestore
              .collection('supportRequests')
              .get())
          .docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) => doc.data())
          .toList();
      expect(
        supportRequests.any(
          (Map<String, dynamic> request) =>
              request['requestType'] == 'session_reminder' &&
              request['source'] == 'parent_schedule_request_session_reminder' &&
              request['metadata']?['sessionTitle'] == 'Robotics Studio',
        ),
        isTrue,
      );
    });

    testWidgets('portfolio page persists portfolio share requests in app',
        (WidgetTester tester) async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      await _seedParentData(firestore);

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

      expect(
          find.widgetWithText(OutlinedButton, 'Request Share'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Download Summary'),
          findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Request Share'));
      await tester.pumpAndSettle();

      expect(find.text('Portfolio share request submitted.'), findsOneWidget);

      final List<Map<String, dynamic>> supportRequests = (await firestore
              .collection('supportRequests')
              .get())
          .docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) => doc.data())
          .toList();
      expect(
        supportRequests.any(
          (Map<String, dynamic> request) =>
              request['requestType'] == 'portfolio_share' &&
              request['source'] == 'parent_portfolio_request_share' &&
              request['metadata']?['itemTitle'] == 'Build a Robot',
        ),
        isTrue,
      );
    });

    testWidgets('portfolio page downloads a real summary file',
        (WidgetTester tester) async {
      ExportService.instance.debugSaveTextFile = ({
        required String fileName,
        required String content,
        required String mimeType,
      }) async {
        _savedFileName = fileName;
        _savedFileContent = content;
        return '/tmp/$fileName';
      };
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      await _seedParentData(firestore);

      await _pumpPage(
        tester,
        firestore: firestore,
        home: const ParentPortfolioPage(),
      );

      await tester.ensureVisible(find.text('Build a Robot').first);
      await tester.tap(find.text('Build a Robot').first);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ElevatedButton, 'Download Summary'),
          findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Download Summary'));
      await tester.pumpAndSettle();

      expect(find.text('Portfolio summary downloaded.'), findsOneWidget);
      expect(_savedFileName, 'portfolio-summary-learner-1-activity-1.txt');
      expect(_savedFileContent,
          contains('Portfolio Item ID: learner-1-activity-1'));
      expect(_savedFileContent, contains('Title: Build a Robot'));
      expect(_savedFileContent, contains('Description: Linked Update'));
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
