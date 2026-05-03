import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/modules/educator/educator_learner_supports_page.dart';
import 'package:scholesa_app/modules/educator/educator_service.dart';
import 'package:scholesa_app/modules/site/site_dashboard_page.dart';
import 'package:scholesa_app/services/firestore_service.dart';
import 'package:scholesa_app/ui/theme/scholesa_theme.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

const String _siteId = 'synthetic-site-miloos-gold';
const String _otherSiteId = 'synthetic-site-miloos-other';
const String _educatorId = 'synthetic-miloos-gold-educator';
const String _siteLeadId = 'synthetic-miloos-gold-site-lead';
const String _pendingLearnerId =
    'synthetic-miloos-pending-explain-back-learner';
const String _currentLearnerId = 'synthetic-miloos-support-current-learner';
const String _crossSiteLearnerId = 'synthetic-miloos-cross-site-denial-learner';

late Map<String, dynamic> _canonicalBundle;

Directory _repoRoot() {
  Directory current = Directory.current;
  while (current.parent.path != current.path) {
    if (File('${current.path}/scripts/import_synthetic_data.js').existsSync()) {
      return current;
    }
    current = current.parent;
  }
  throw StateError(
      'Could not find repository root from ${Directory.current.path}.');
}

Map<String, dynamic> _loadCanonicalBundleFromImporter() {
  final Directory root = _repoRoot();
  final ProcessResult result = Process.runSync(
    'node',
    <String>[
      '-e',
      """
const { buildImportBundle } = require('./scripts/import_synthetic_data');
const bundle = buildImportBundle({ mode: 'starter' });
const collections = {};
for (const name of ['users', 'enrollments', 'sessions', 'interactionEvents', 'syntheticMiloOSGoldStates']) {
  collections[name] = Object.fromEntries(bundle.collections.get(name) || []);
}
process.stdout.write(JSON.stringify({ summary: bundle.summary, collections }));
""",
    ],
    workingDirectory: root.path,
  );
  if (result.exitCode != 0) {
    throw StateError(
      'Failed to load canonical MiloOS synthetic bundle: ${result.stderr}',
    );
  }
  return Map<String, dynamic>.from(jsonDecode(result.stdout as String) as Map);
}

Map<String, dynamic> _collection(String name) {
  final Map<String, dynamic> collections =
      Map<String, dynamic>.from(_canonicalBundle['collections'] as Map);
  return Map<String, dynamic>.from(collections[name] as Map);
}

Map<String, dynamic> _doc(String collection, String docId) {
  return Map<String, dynamic>.from(_collection(collection)[docId] as Map);
}

Future<void> _seedCanonicalMiloOSGoldStates(
  FakeFirebaseFirestore firestore,
) async {
  for (final String collectionName in <String>[
    'users',
    'enrollments',
    'sessions',
    'interactionEvents',
    'syntheticMiloOSGoldStates',
  ]) {
    for (final MapEntry<String, dynamic> entry
        in _collection(collectionName).entries) {
      await firestore
          .collection(collectionName)
          .doc(entry.key)
          .set(Map<String, dynamic>.from(entry.value as Map));
    }
  }
}

AppState _appStateFromSyntheticUser(String userId) {
  final Map<String, dynamic> user = _doc('users', userId);
  final AppState state = AppState();
  state.updateFromMeResponse(<String, dynamic>{
    'userId': user['uid'],
    'email': user['email'],
    'displayName': user['displayName'],
    'role': user['role'],
    'activeSiteId': user['activeSiteId'],
    'siteIds': List<dynamic>.from(user['siteIds'] as List),
    'localeCode': 'en',
    'entitlements': <Map<String, dynamic>>[],
  });
  return state;
}

Widget _educatorHarness({
  required FirestoreService firestoreService,
  required EducatorService educatorService,
}) {
  return MultiProvider(
    providers: <SingleChildWidget>[
      Provider<FirestoreService>.value(value: firestoreService),
      ChangeNotifierProvider<AppState>.value(
        value: _appStateFromSyntheticUser(_educatorId),
      ),
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

Widget _siteHarness({
  required FirestoreService firestoreService,
}) {
  return MultiProvider(
    providers: <SingleChildWidget>[
      Provider<FirestoreService>.value(value: firestoreService),
      ChangeNotifierProvider<AppState>.value(
        value: _appStateFromSyntheticUser(_siteLeadId),
      ),
    ],
    child: MaterialApp(
      theme: ScholesaTheme.light,
      home: const SiteDashboardPage(),
    ),
  );
}

void main() {
  setUpAll(() {
    _canonicalBundle = _loadCanonicalBundleFromImporter();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
    'canonical MiloOS synthetic states feed Flutter educator support provenance',
    (WidgetTester tester) async {
      final Map<String, dynamic> manifest =
          _doc('syntheticMiloOSGoldStates', 'latest');
      expect(manifest['siteId'], _siteId);
      expect(manifest['noMasteryWrites'], isTrue);
      expect(
        Map<String, dynamic>.from(manifest['sourceCounts'] as Map),
        containsPair('miloosGoldLearnerStates', 5),
      );
      expect(
        Map<String, dynamic>.from(manifest['sourceCounts'] as Map),
        containsPair('miloosGoldInteractionEvents', 13),
      );
      final Map<String, dynamic> states =
          Map<String, dynamic>.from(manifest['states'] as Map);
      expect(states['pendingExplainBackLearnerId'], _pendingLearnerId);
      expect(states['supportCurrentLearnerId'], _currentLearnerId);
      expect(_doc('users', _educatorId)['activeSiteId'], _siteId);
      expect(_doc('users', _siteLeadId)['activeSiteId'], _siteId);

      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      await _seedCanonicalMiloOSGoldStates(firestore);
      final FirestoreService firestoreService = FirestoreService(
        firestore: firestore,
        auth: _MockFirebaseAuth(),
      );
      final EducatorService educatorService = EducatorService(
        firestoreService: firestoreService,
        educatorId: _educatorId,
        siteId: _siteId,
      );

      await tester.binding.setSurfaceSize(const Size(390, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _educatorHarness(
          firestoreService: firestoreService,
          educatorService: educatorService,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('MiloOS Support Provenance'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('MiloOS Support Provenance'), findsOneWidget);
      expect(
        find.text(
            'Support events show follow-up debt only. They are not capability mastery.'),
        findsOneWidget,
      );
      expect(
        find.text('Synthetic Miloos Pending Explain Back Learner'),
        findsWidgets,
      );
      expect(
          find.text('Synthetic Miloos Support Current Learner'), findsWidgets);
      expect(
        find.text('Synthetic Miloos Cross Site Denial Learner'),
        findsNothing,
      );
      expect(find.text('Opened: 1'), findsNWidgets(2));
      expect(find.text('Used: 1'), findsNWidgets(2));
      expect(find.text('Explained: 1'), findsOneWidget);
      expect(find.text('Pending: 1'), findsWidgets);
      expect(find.text('Pending: 0'), findsOneWidget);
      expect(find.textContaining('mastery: 100'), findsNothing);

      final QuerySnapshot<Map<String, dynamic>> mastery =
          await firestore.collection('capabilityMastery').get();
      final QuerySnapshot<Map<String, dynamic>> growth =
          await firestore.collection('capabilityGrowthEvents').get();
      expect(mastery.docs, isEmpty);
      expect(growth.docs, isEmpty);
    },
  );

  testWidgets(
    'canonical MiloOS synthetic states feed Flutter site support health',
    (WidgetTester tester) async {
      final Map<String, dynamic> crossSiteUser =
          _doc('users', _crossSiteLearnerId);
      expect(crossSiteUser['siteIds'], <String>[_otherSiteId]);
      expect(
          _doc('interactionEvents', 'synthetic-miloos-cross-site-opened-01')[
              'siteId'],
          _otherSiteId);
      expect(
          _doc('interactionEvents', 'synthetic-miloos-missing-site-opened-01')[
              'siteId'],
          isNull);

      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      await _seedCanonicalMiloOSGoldStates(firestore);
      final FirestoreService firestoreService = FirestoreService(
        firestore: firestore,
        auth: _MockFirebaseAuth(),
      );

      await tester.binding.setSurfaceSize(const Size(390, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_siteHarness(firestoreService: firestoreService));
      await tester.pumpAndSettle();

      expect(find.text('MiloOS Support Health'), findsOneWidget);
      expect(
        find.text(
            'Site-scoped support provenance and explain-back debt. Not capability mastery.'),
        findsOneWidget,
      );
      expect(find.text('Learners with support: 2'), findsOneWidget);
      expect(find.text('Learners pending: 1'), findsOneWidget);
      expect(find.text('Opened: 2'), findsOneWidget);
      expect(find.text('Used: 2'), findsOneWidget);
      expect(find.text('Responses: 2'), findsOneWidget);
      expect(find.text('Explained: 1'), findsOneWidget);
      expect(find.text('Pending explain-backs: 1'), findsOneWidget);
      expect(find.text('Opened: 3'), findsNothing);
      expect(find.text('Opened: 4'), findsNothing);
      expect(find.textContaining('mastery: 100'), findsNothing);
    },
  );
}
