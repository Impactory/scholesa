import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/modules/parent/growth_timeline_page.dart';
import 'package:scholesa_app/services/firestore_service.dart';

class _FakeFirebaseAuth implements FirebaseAuth {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ThrowingFirestoreService extends FirestoreService {
  _ThrowingFirestoreService()
      : super(
          firestore: FakeFirebaseFirestore(),
          auth: _FakeFirebaseAuth(),
        );

  @override
  Future<List<Map<String, dynamic>>> queryCollection(
    String collection, {
    List<List<dynamic>>? where,
    String? orderBy,
    bool descending = false,
    int? limit,
  }) async {
    throw FirebaseException(
      plugin: 'cloud_firestore',
      code: 'failed-precondition',
      message:
          'The query requires an index. You can create it here: https://console.firebase.google.com/project/demo/firestore/indexes',
    );
  }
}

AppState _buildParentState() {
  final AppState state = AppState();
  state.updateFromMeResponse(<String, dynamic>{
    'userId': 'parent-1',
    'email': 'parent@scholesa.test',
    'displayName': 'Parent One',
    'role': 'parent',
    'activeSiteId': 'site-1',
    'siteIds': <String>['site-1'],
    'entitlements': const <dynamic>[],
  });
  return state;
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required FirestoreService firestoreService,
}) async {
  await tester.binding.setSurfaceSize(const Size(1280, 1800));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<AppState>.value(value: _buildParentState()),
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
        home: const GrowthTimelinePage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'parent growth timeline load failures show friendly retry guidance',
      (WidgetTester tester) async {
    await _pumpPage(
      tester,
      firestoreService: _ThrowingFirestoreService(),
    );

    expect(find.text('Growth Timeline'), findsOneWidget);
    expect(
      find.text(
        'We could not load this growth timeline right now. Refresh, or check again after the app reconnects.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('console.firebase.google.com'), findsNothing);
    expect(find.textContaining('failed-precondition'), findsNothing);
    expect(find.text('No growth events recorded yet.'), findsNothing);
  });

  testWidgets(
      'parent growth timeline shows only linked learner growth provenance',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    final DateTime anchor = DateTime(2026, 4, 30, 10);

    await firestore.collection('guardianLinks').doc('link-1').set(
      <String, dynamic>{
        'guardianId': 'parent-1',
        'learnerId': 'learner-1',
        'learnerName': 'Ava Learner',
        'siteId': 'site-1',
      },
    );
    await firestore.collection('capabilities').doc('cap-linked').set(
      <String, dynamic>{
        'name': 'Evidence-backed reasoning',
        'siteId': 'site-1',
      },
    );
    await firestore.collection('capabilities').doc('cap-unlinked').set(
      <String, dynamic>{
        'name': 'Unlinked capability',
        'siteId': 'other-site',
      },
    );
    await firestore
        .collection('capabilityGrowthEvents')
        .doc('growth-linked')
        .set(
      <String, dynamic>{
        'learnerId': 'learner-1',
        'siteId': 'site-1',
        'capabilityId': 'cap-linked',
        'fromLevel': 'Level 2',
        'toLevel': 'Level 3',
        'educatorId': 'educator-1',
        'evidenceIds': const <String>['evidence-1'],
        'pillarCode': 'impact',
        'createdAt': Timestamp.fromDate(anchor),
      },
    );
    await firestore
        .collection('capabilityGrowthEvents')
        .doc('growth-unlinked')
        .set(
      <String, dynamic>{
        'learnerId': 'learner-other',
        'siteId': 'other-site',
        'capabilityId': 'cap-unlinked',
        'fromLevel': 'Level 1',
        'toLevel': 'Level 4',
        'educatorId': 'educator-other',
        'evidenceIds': const <String>['evidence-other'],
        'pillarCode': 'futureSkills',
        'createdAt': Timestamp.fromDate(anchor.add(const Duration(hours: 1))),
      },
    );

    await _pumpPage(
      tester,
      firestoreService: FirestoreService(
        firestore: firestore,
        auth: _FakeFirebaseAuth(),
      ),
    );

    expect(find.text('Growth Timeline'), findsOneWidget);
    expect(find.text('Growth Summary'), findsOneWidget);
    expect(find.text('Evidence-backed reasoning'), findsWidgets);
    expect(find.text('Latest: Evidence-backed reasoning reached Level 3'),
        findsOneWidget);
    expect(find.text('Learner: Ava Learner'), findsOneWidget);
    expect(find.text('Assessed by: educator-1'), findsOneWidget);
    expect(find.text('1 evidence item linked'), findsOneWidget);
    expect(find.text('Unlinked capability'), findsNothing);
    expect(find.text('Assessed by: educator-other'), findsNothing);
  });
}
