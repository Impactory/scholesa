import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/modules/checkin/checkin_models.dart';
import 'package:scholesa_app/modules/checkin/checkin_page.dart';
import 'package:scholesa_app/modules/checkin/checkin_service.dart';
import 'package:scholesa_app/services/firestore_service.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _FailingLatePickupCheckinService extends CheckinService {
  _FailingLatePickupCheckinService({
    required super.firestoreService,
    required super.siteId,
  });

  @override
  Future<bool> markLate({
    required String learnerId,
    required String learnerName,
    String? notes,
  }) async {
    return false;
  }
}

CheckinDaySnapshot _buildCheckinSnapshot() {
  return CheckinDaySnapshot(
    learnerSummaries: const <LearnerDaySummary>[
      LearnerDaySummary(
        learnerId: 'learner-1',
        learnerName: 'Ava Learner',
        currentStatus: CheckStatus.checkedIn,
      ),
    ],
    todayRecords: <CheckRecord>[
      CheckRecord(
        id: 'record-1',
        visitorId: 'visitor-1',
        visitorName: 'Parent One',
        learnerId: 'learner-1',
        learnerName: 'Ava Learner',
        siteId: 'site-1',
        timestamp: DateTime(2026, 3, 17, 8, 30),
        status: CheckStatus.checkedIn,
      ),
    ],
  );
}

Future<void> _pumpCheckinPage(
  WidgetTester tester, {
  required FakeFirebaseFirestore firestore,
  Locale locale = const Locale('en'),
  CheckinService? checkinService,
}) async {
  final FirestoreService firestoreService = FirestoreService(
    firestore: firestore,
    auth: _MockFirebaseAuth(),
  );
  final CheckinService resolvedCheckinService =
      checkinService ??
      CheckinService(
        firestoreService: firestoreService,
        siteId: 'site-1',
      );

  await tester.pumpWidget(
    MultiProvider(
      providers: <SingleChildWidget>[
        Provider<FirestoreService>.value(value: firestoreService),
        ChangeNotifierProvider<CheckinService>.value(
          value: resolvedCheckinService,
        ),
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
        home: const CheckinPage(),
      ),
    ),
  );

  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'quick pickup resolves a configured pickup code into the real checkout flow',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    final DateTime now = DateTime.now();
    await firestore.collection('users').doc('learner-1').set(<String, dynamic>{
      'role': 'learner',
      'displayName': 'Ava Learner',
      'siteIds': <String>['site-1'],
    });
    await firestore.collection('checkins').doc('checkin-1').set(
      <String, dynamic>{
        'siteId': 'site-1',
        'learnerId': 'learner-1',
        'learnerName': 'Ava Learner',
        'type': 'checkin',
        'timestamp': Timestamp.fromDate(now.subtract(const Duration(minutes: 5))),
        'recordedBy': 'pickup-1',
        'recorderName': 'Parent One',
      },
    );
    await firestore.collection('pickupAuthorizations').doc('auth-1').set(
      <String, dynamic>{
        'siteId': 'site-1',
        'learnerId': 'learner-1',
        'authorizedPickup': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'pickup-1',
            'name': 'Parent One',
            'relationship': 'Parent',
            'phone': '+1 555 123 4567',
            'verificationCode': 'AVA123',
            'isPrimaryContact': true,
          },
        ],
      },
    );

    await _pumpCheckinPage(tester, firestore: firestore);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Account menu'), findsOneWidget);
    expect(find.text('Quick Pickup'), findsWidgets);
    final Finder dialog = find.byType(AlertDialog);
    await tester.enterText(
      find.descendant(of: dialog, matching: find.byType(TextField)),
      'AVA123',
    );
    await tester.tap(find.descendant(of: dialog, matching: find.text('Find pickup')));
    await tester.pumpAndSettle();

    expect(find.text('Check Out'), findsWidgets);
    expect(find.text('Ava Learner'), findsWidgets);
    expect(find.text('Parent One'), findsWidgets);
    final Finder confirmButton =
        find.widgetWithText(ElevatedButton, 'Confirm Check Out');
    expect(confirmButton, findsOneWidget);

    await tester.ensureVisible(confirmButton);
    await tester.tap(confirmButton);
    await tester.pumpAndSettle();

    final QuerySnapshot<Map<String, dynamic>> records =
        await firestore.collection('checkins').get();
    expect(records.docs.length, 2);
    final Iterable<Map<String, dynamic>> checkoutRecords = records.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) => doc.data())
        .where((Map<String, dynamic> data) => data['type'] == 'checkout');
    expect(checkoutRecords, hasLength(1));
    expect(checkoutRecords.first['learnerId'], 'learner-1');
    expect(checkoutRecords.first['recordedBy'], 'pickup-1');
  });

  testWidgets('checkin page labels missing learner names as unavailable',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await firestore.collection('users').doc('learner-1').set(<String, dynamic>{
      'role': 'learner',
      'siteIds': <String>['site-1'],
    });

    await _pumpCheckinPage(
      tester,
      firestore: firestore,
      locale: const Locale('zh', 'CN'),
    );

    expect(find.textContaining('学习者信息不可用'), findsWidgets);
    expect(find.text('Learner unavailable'), findsNothing);
    expect(find.text('Unknown'), findsNothing);
  });

  testWidgets('late pickup flagging shows an error when the write fails',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    final DateTime now = DateTime.now();
    await firestore.collection('users').doc('learner-1').set(<String, dynamic>{
      'role': 'learner',
      'displayName': 'Ava Learner',
      'siteIds': <String>['site-1'],
    });
    await firestore.collection('checkins').doc('checkin-1').set(
      <String, dynamic>{
        'siteId': 'site-1',
        'learnerId': 'learner-1',
        'learnerName': 'Ava Learner',
        'type': 'checkin',
        'timestamp': Timestamp.fromDate(now.subtract(const Duration(minutes: 5))),
      },
    );

    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    final CheckinService checkinService = _FailingLatePickupCheckinService(
      firestoreService: firestoreService,
      siteId: 'site-1',
    );

    await _pumpCheckinPage(
      tester,
      firestore: firestore,
      checkinService: checkinService,
    );

    await tester.tap(find.byTooltip('Flag late pickup'));
    await tester.pumpAndSettle();

    expect(find.text('Unable to flag late pickup right now.'), findsOneWidget);
    final QuerySnapshot<Map<String, dynamic>> records =
        await firestore.collection('checkins').get();
    expect(records.docs.length, 1);
  });

  testWidgets('checkin page shows load failure instead of fake empty learners',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    final CheckinService checkinService = CheckinService(
      firestoreService: firestoreService,
      siteId: 'site-1',
      daySnapshotLoader: () async {
        throw Exception('network down');
      },
    );

    await _pumpCheckinPage(
      tester,
      firestore: firestore,
      checkinService: checkinService,
    );

    expect(
      find.text(
        'We could not load check-in data right now. Retry to check the current state.',
      ),
      findsOneWidget,
    );
    expect(find.text('No learners found'), findsNothing);
  });

  testWidgets('checkin page keeps stale learner data visible after refresh failure',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    int loadCount = 0;
    final CheckinService checkinService = CheckinService(
      firestoreService: firestoreService,
      siteId: 'site-1',
      daySnapshotLoader: () async {
        loadCount += 1;
        if (loadCount == 1) {
          return _buildCheckinSnapshot();
        }
        throw Exception('network down');
      },
    );

    await _pumpCheckinPage(
      tester,
      firestore: firestore,
      checkinService: checkinService,
    );

    expect(find.text('Ava Learner'), findsOneWidget);

    await tester.tap(find.byTooltip('Refresh'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Unable to refresh check-in data right now. Showing the last successful data. Failed to load check-in data: Exception: network down',
      ),
      findsOneWidget,
    );
    expect(find.text('Ava Learner'), findsOneWidget);
    expect(find.text('No learners found'), findsNothing);
  });

  test('checkin service loads guardian-link pickups when pickup auth docs are absent',
      () async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    final DateTime now = DateTime.now();
    await firestore.collection('users').doc('learner-1').set(<String, dynamic>{
      'role': 'learner',
      'displayName': 'Ava Learner',
      'siteIds': <String>['site-1'],
    });
    await firestore.collection('users').doc('parent-1').set(<String, dynamic>{
      'role': 'parent',
      'displayName': 'Parent One',
      'email': 'parent1@example.com',
      'siteIds': <String>['site-1'],
    });
    await firestore.collection('parentProfiles').doc('parent-1').set(
      <String, dynamic>{
        'siteId': 'site-1',
        'userId': 'parent-1',
        'displayName': 'Parent One',
        'phone': '+1 555 000 1212',
        'email': 'parent1@example.com',
      },
    );
    await firestore.collection('guardianLinks').doc('link-1').set(
      <String, dynamic>{
        'siteId': 'site-1',
        'parentId': 'parent-1',
        'learnerId': 'learner-1',
        'relationship': 'Parent',
        'isPrimary': true,
        'createdAt': Timestamp.fromDate(now),
        'createdBy': 'site-admin-1',
      },
    );
    await firestore.collection('checkins').doc('checkin-1').set(
      <String, dynamic>{
        'siteId': 'site-1',
        'learnerId': 'learner-1',
        'learnerName': 'Ava Learner',
        'type': 'checkin',
        'timestamp': Timestamp.fromDate(now.subtract(const Duration(minutes: 10))),
      },
    );

    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    final CheckinService service = CheckinService(
      firestoreService: firestoreService,
      siteId: 'site-1',
    );

    await service.loadTodayData();

    expect(service.learnerSummaries, hasLength(1));
    final pickup = service.learnerSummaries.first.authorizedPickups.single;
    expect(pickup.name, 'Parent One');
    expect(pickup.phone, '+1 555 000 1212');
    expect(pickup.email, 'parent1@example.com');
    expect(service.findPickupMatches('1212').single.pickup.id, 'link-1');
  });
}
