import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/modules/site/site_pickup_auth_page.dart';
import 'package:scholesa_app/modules/site/site_pickup_auth_service.dart';

class _ThrowingPickupAuthorizationService
    extends SitePickupAuthorizationService {
  _ThrowingPickupAuthorizationService()
      : super(firestore: FakeFirebaseFirestore());

  @override
  Future<List<SitePickupAuthorizationLearnerOption>> listLearners(
    String siteId,
  ) async {
    return const <SitePickupAuthorizationLearnerOption>[];
  }

  @override
  Future<List<SitePickupAuthorizationRecord>> listRecords(String siteId) async {
    throw StateError('pickup authorizations unavailable');
  }
}

AppState _buildSiteState() {
  final AppState state = AppState();
  state.updateFromMeResponse(<String, dynamic>{
    'userId': 'site-1-admin',
    'email': 'site-admin@scholesa.test',
    'displayName': 'Site Admin',
    'role': 'site',
    'activeSiteId': 'site-1',
    'siteIds': <String>['site-1'],
    'localeCode': 'en',
    'entitlements': const <Map<String, dynamic>>[],
  });
  return state;
}

Widget _buildHarness({
  required AppState appState,
  required Widget child,
}) {
  return MultiProvider(
    providers: <SingleChildWidget>[
      ChangeNotifierProvider<AppState>.value(value: appState),
    ],
    child: MaterialApp(
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
  );
}

Future<void> _seedPickupData(FakeFirebaseFirestore firestore) async {
  await firestore.collection('learnerProfiles').doc('profile-1').set(
    <String, dynamic>{
      'learnerId': 'learner-1',
      'siteId': 'site-1',
      'preferredName': 'Ava Stone',
    },
  );
  await firestore.collection('learnerProfiles').doc('profile-2').set(
    <String, dynamic>{
      'learnerId': 'learner-2',
      'siteId': 'site-1',
      'preferredName': 'Ben Rivers',
    },
  );
  await firestore.collection('learnerProfiles').doc('profile-3').set(
    <String, dynamic>{
      'learnerId': 'learner-3',
      'siteId': 'site-1',
      'preferredName': 'Cara Quinn',
    },
  );
  await firestore.collection('pickupAuthorizations').doc('pickup-1').set(
    <String, dynamic>{
      'siteId': 'site-1',
      'learnerId': 'learner-1',
      'authorizedPickup': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'pickup-person-1',
          'name': 'Alex Stone',
          'relationship': 'Mother',
          'phone': '555-0100',
          'verificationCode': 'AVA-123',
          'isPrimaryContact': true,
        },
      ],
      'updatedBy': 'site-1-admin',
      'updatedAt': Timestamp.fromDate(DateTime(2026, 3, 18, 9, 15)),
    },
  );
  await firestore.collection('guardianLinks').doc('guardian-link-1').set(
    <String, dynamic>{
      'parentId': 'parent-1',
      'learnerId': 'learner-2',
      'siteId': 'site-1',
      'relationship': 'Aunt',
      'isPrimary': true,
      'updatedAt': Timestamp.fromDate(DateTime(2026, 3, 18, 8, 45)),
    },
  );
  await firestore.collection('parentProfiles').doc('parent-1').set(
    <String, dynamic>{
      'parentId': 'parent-1',
      'siteId': 'site-1',
      'preferredName': 'Bea Rivers',
      'phone': '555-0199',
      'email': 'bea@example.com',
    },
  );
  await firestore.collection('users').doc('parent-1').set(
    <String, dynamic>{
      'displayName': 'Bea Rivers',
      'email': 'bea@example.com',
    },
  );
}

void main() {
  testWidgets(
      'site pickup auth shows explicit and guardian fallback coverage and persists new explicit records',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await _seedPickupData(firestore);

    await tester.binding.setSurfaceSize(const Size(1280, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _buildHarness(
        appState: _buildSiteState(),
        child: SitePickupAuthPage(
          service: SitePickupAuthorizationService(firestore: firestore),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ava Stone'), findsOneWidget);
    expect(find.text('Ben Rivers'), findsOneWidget);
    expect(find.text('Explicit list'), findsWidgets);
    expect(find.text('Guardian fallback'), findsWidgets);
    expect(find.textContaining('AVA-123'), findsOneWidget);

    await tester.tap(find.byTooltip('Add Authorization'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cara Quinn').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Casey Quinn');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Relationship'),
      'Guardian',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Phone'),
      '555-0111',
    );

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Pickup authorizations saved'), findsOneWidget);
    final QuerySnapshot<Map<String, dynamic>> snapshot = await firestore
        .collection('pickupAuthorizations')
        .where('siteId', isEqualTo: 'site-1')
        .where('learnerId', isEqualTo: 'learner-3')
        .get();
    expect(snapshot.docs, hasLength(1));
    final Map<String, dynamic> saved = snapshot.docs.first.data();
    final List<dynamic> authorizedPickup =
        saved['authorizedPickup'] as List<dynamic>;
    expect(authorizedPickup, isNotEmpty);
    expect(authorizedPickup.first['name'], 'Casey Quinn');
    expect(authorizedPickup.first['relationship'], 'Guardian');
    expect(authorizedPickup.first['phone'], '555-0111');
  });

  testWidgets('site pickup auth shows explicit error state when loading fails',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _buildHarness(
        appState: _buildSiteState(),
        child: SitePickupAuthPage(
          service: _ThrowingPickupAuthorizationService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Unable to load pickup authorizations right now'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
  });
}
