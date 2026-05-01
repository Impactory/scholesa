import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/modules/hq_admin/capability_framework_page.dart';
import 'package:scholesa_app/modules/hq_admin/rubric_builder_page.dart';
import 'package:scholesa_app/services/firestore_service.dart';

class _FakeFirebaseAuth implements FirebaseAuth {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

AppState _buildHqState() {
  final AppState state = AppState();
  state.updateFromMeResponse(<String, dynamic>{
    'userId': 'hq-user-1',
    'email': 'hq@scholesa.test',
    'displayName': 'HQ One',
    'role': 'hq',
    'activeSiteId': 'site-1',
    'siteIds': <String>['site-1'],
    'entitlements': const <dynamic>[],
  });
  return state;
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required Widget child,
  required FirestoreService firestoreService,
}) async {
  await tester.binding.setSurfaceSize(const Size(1280, 1800));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<AppState>.value(value: _buildHqState()),
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
        home: child,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('mobile HQ creates site-scoped capability framework records',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await firestore.collection('capabilities').doc('other-capability').set(
      <String, dynamic>{
        'siteId': 'other-site',
        'name': 'Other Site Capability',
        'title': 'Other Site Capability',
        'pillarCode': 'futureSkills',
        'createdAt': Timestamp.fromDate(DateTime(2026, 4, 29)),
        'updatedAt': Timestamp.fromDate(DateTime(2026, 4, 29)),
      },
    );

    await _pumpPage(
      tester,
      child: const CapabilityFrameworkPage(),
      firestoreService: FirestoreService(
        firestore: firestore,
        auth: _FakeFirebaseAuth(),
      ),
    );

    expect(find.text('Other Site Capability'), findsNothing);
    await tester.tap(find.text('Add First Capability'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Name'),
      'Evidence Modeling',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Description'),
      'Models claims with traceable evidence.',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    final QuerySnapshot<Map<String, dynamic>> capabilities = await firestore
        .collection('capabilities')
        .where('siteId', isEqualTo: 'site-1')
        .get();
    expect(capabilities.docs.length, 1);
    final Map<String, dynamic> data = capabilities.docs.single.data();
    expect(data['name'], 'Evidence Modeling');
    expect(data['title'], 'Evidence Modeling');
    expect(data['description'], 'Models claims with traceable evidence.');
    expect(data['descriptor'], 'Models claims with traceable evidence.');
    expect(data['createdBy'], 'hq-user-1');
    expect(data['status'], 'active');
  });

  testWidgets('mobile HQ creates canonical site-scoped rubric templates',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await firestore.collection('rubricTemplates').doc('other-rubric').set(
      <String, dynamic>{
        'siteId': 'other-site',
        'title': 'Other Site Rubric',
        'name': 'Other Site Rubric',
        'status': 'draft',
        'capabilityIds': const <String>[],
        'criteria': const <Map<String, dynamic>>[],
        'createdAt': Timestamp.fromDate(DateTime(2026, 4, 29)),
        'updatedAt': Timestamp.fromDate(DateTime(2026, 4, 29)),
      },
    );

    await _pumpPage(
      tester,
      child: const RubricBuilderPage(),
      firestoreService: FirestoreService(
        firestore: firestore,
        auth: _FakeFirebaseAuth(),
      ),
    );

    expect(find.text('Other Site Rubric'), findsNothing);
    await tester.tap(find.text('Create First Rubric'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Rubric Name'),
      'Evidence Defense Rubric',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Description'),
      'Scores how learners defend evidence-backed decisions.',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    final QuerySnapshot<Map<String, dynamic>> templates = await firestore
        .collection('rubricTemplates')
        .where('siteId', isEqualTo: 'site-1')
        .get();
    expect(templates.docs.length, 1);
    final Map<String, dynamic> data = templates.docs.single.data();
    expect(data['title'], 'Evidence Defense Rubric');
    expect(data['name'], 'Evidence Defense Rubric');
    expect(data['description'],
        'Scores how learners defend evidence-backed decisions.');
    expect(data['createdBy'], 'hq-user-1');
    expect(data['status'], 'draft');
    expect(data['capabilityIds'], isEmpty);
    expect(data['criteria'], isA<List<dynamic>>());
    expect((data['criteria'] as List<dynamic>).length, 4);
  });
}
