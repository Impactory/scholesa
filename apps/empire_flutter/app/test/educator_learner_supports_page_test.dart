import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/modules/educator/educator_learner_supports_page.dart';
import 'package:scholesa_app/modules/educator/educator_service.dart';
import 'package:scholesa_app/services/firestore_service.dart';
import 'package:scholesa_app/ui/theme/scholesa_theme.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _FailingSupportPlanFirestoreService extends FirestoreService {
  _FailingSupportPlanFirestoreService({
    required super.firestore,
    required super.auth,
  });

  @override
  Future<String> createDocument(
    String collection,
    Map<String, dynamic> data,
  ) async {
    if (collection == 'learnerSupportPlans') {
      throw StateError('support plan write failed');
    }
    return super.createDocument(collection, data);
  }

  @override
  Future<void> updateDocument(
    String collection,
    String docId,
    Map<String, dynamic> data,
  ) async {
    if (collection == 'learnerSupportPlans') {
      throw StateError('support plan write failed');
    }
    return super.updateDocument(collection, docId, data);
  }
}

AppState _buildEducatorState() {
  final AppState state = AppState();
  state.updateFromMeResponse(<String, dynamic>{
    'userId': 'educator-1',
    'email': 'educator-1@scholesa.test',
    'displayName': 'Educator One',
    'role': 'educator',
    'activeSiteId': 'site-1',
    'siteIds': <String>['site-1'],
    'localeCode': 'en',
    'entitlements': <Map<String, dynamic>>[],
  });
  return state;
}

Widget _buildHarness({
  required FirestoreService firestoreService,
  required EducatorService educatorService,
}) {
  return MultiProvider(
    providers: <SingleChildWidget>[
      Provider<FirestoreService>.value(value: firestoreService),
      ChangeNotifierProvider<AppState>.value(value: _buildEducatorState()),
      ChangeNotifierProvider<EducatorService>.value(value: educatorService),
    ],
    child: MaterialApp(
      theme: ScholesaTheme.light,
      locale: const Locale('en'),
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
      home: const EducatorLearnerSupportsPage(),
    ),
  );
}

Future<void> _seedLearner(FakeFirebaseFirestore firestore) async {
  await firestore.collection('users').doc('learner-1').set(<String, dynamic>{
    'displayName': 'Learner One',
    'email': 'learner-1@scholesa.test',
    'siteId': 'site-1',
    'attendanceRate': 58,
    'missionsCompleted': 3,
    'futureSkillsProgress': 0.32,
    'leadershipProgress': 0.48,
    'impactProgress': 0.41,
    'enrolledSessionIds': <String>['session-1'],
  });
  await firestore.collection('enrollments').doc('enrollment-1').set(<String, dynamic>{
    'siteId': 'site-1',
    'learnerId': 'learner-1',
    'educatorId': 'educator-1',
    'sessionId': 'session-1',
  });
}

void main() {
  testWidgets('educator learner supports page renders support plan from live learner data',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await _seedLearner(firestore);
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    final EducatorService educatorService = EducatorService(
      firestoreService: firestoreService,
      educatorId: 'educator-1',
      siteId: 'site-1',
    );

    await tester.pumpWidget(
      _buildHarness(
        firestoreService: firestoreService,
        educatorService: educatorService,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.bySemanticsLabel('Account menu'), findsOneWidget);
    expect(find.text('Active Support Plans'), findsOneWidget);
    expect(find.text('Learner One'), findsOneWidget);
    expect(find.text('High'), findsOneWidget);
    expect(find.text('Academic'), findsOneWidget);
    expect(find.text('Check-in support'), findsOneWidget);
    expect(find.text('Peer buddy'), findsOneWidget);
    expect(find.text('No support plans yet'), findsNothing);
  });

  testWidgets('educator learner supports page persists edited support plans',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await _seedLearner(firestore);
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    final EducatorService educatorService = EducatorService(
      firestoreService: firestoreService,
      educatorId: 'educator-1',
      siteId: 'site-1',
    );

    await tester.binding.setSurfaceSize(const Size(1280, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _buildHarness(
        firestoreService: firestoreService,
        educatorService: educatorService,
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Learner One').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Edit Plan'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Behavioral').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Medium').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField).at(0),
      'Visual checklist, Flexible seating',
    );
    await tester.enterText(
      find.byType(TextField).at(1),
      'Updated support plan with visual cues.',
    );

    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();

    expect(find.text('Support plan updated.'), findsOneWidget);
    expect(find.text('Log Support Outcome'), findsOneWidget);

    await tester.tap(find.text('Helped'));
    await tester.pumpAndSettle();

    final List<Map<String, dynamic>> plans = (await firestore
            .collection('learnerSupportPlans')
            .get())
        .docs
        .map((doc) => doc.data())
        .toList();

    expect(plans, hasLength(1));
    expect(plans.single['siteId'], 'site-1');
    expect(plans.single['learnerId'], 'learner-1');
    expect(plans.single['supportType'], 'Behavioral');
    expect(
      plans.single['accommodations'],
      <String>['Visual checklist', 'Flexible seating'],
    );
    expect(plans.single['priority'], 'medium');
    expect(plans.single['notes'], 'Updated support plan with visual cues.');

    expect(find.text('Behavioral'), findsOneWidget);
    expect(find.text('Visual checklist'), findsOneWidget);
    expect(find.text('Flexible seating'), findsOneWidget);
  });

  testWidgets('educator learner supports page fails closed when support plan save fails',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await _seedLearner(firestore);
    final FirestoreService firestoreService = _FailingSupportPlanFirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    final EducatorService educatorService = EducatorService(
      firestoreService: firestoreService,
      educatorId: 'educator-1',
      siteId: 'site-1',
    );

    await tester.binding.setSurfaceSize(const Size(1280, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _buildHarness(
        firestoreService: firestoreService,
        educatorService: educatorService,
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Learner One').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Edit Plan'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();

    expect(find.text('Unable to update support plan right now.'), findsOneWidget);
    expect(find.text('Log Support Outcome'), findsNothing);
    expect(find.text('Edit Support Plan'), findsOneWidget);
  });
}