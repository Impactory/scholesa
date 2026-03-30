import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/domain/repositories.dart';
import 'package:scholesa_app/modules/educator/educator_integrations_page.dart';
import 'package:scholesa_app/modules/educator/educator_service.dart';
import 'package:scholesa_app/modules/site/site_identity_page.dart';
import 'package:scholesa_app/modules/site/site_integrations_health_page.dart';
import 'package:scholesa_app/services/firestore_service.dart';
import 'package:scholesa_app/ui/theme/scholesa_theme.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

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

AppState _buildSiteState() {
  final AppState state = AppState();
  state.updateFromMeResponse(<String, dynamic>{
    'userId': 'site-admin-1',
    'email': 'site-admin-1@scholesa.test',
    'displayName': 'Site Admin One',
    'role': 'site',
    'activeSiteId': 'site-1',
    'siteIds': <String>['site-1'],
    'localeCode': 'en',
    'entitlements': <Map<String, dynamic>>[],
  });
  return state;
}

Widget _buildEducatorHarness({
  required AppState appState,
  required EducatorService educatorService,
  required Widget child,
}) {
  return MultiProvider(
    providers: <SingleChildWidget>[
      ChangeNotifierProvider<AppState>.value(value: appState),
      ChangeNotifierProvider<EducatorService>.value(value: educatorService),
    ],
    child: MaterialApp(
      theme: ScholesaTheme.light,
      home: child,
    ),
  );
}

Widget _buildSiteHarness({
  required AppState appState,
  required Widget child,
}) {
  return MultiProvider(
    providers: <SingleChildWidget>[
      ChangeNotifierProvider<AppState>.value(value: appState),
    ],
    child: MaterialApp(
      theme: ScholesaTheme.light,
      home: child,
    ),
  );
}

void main() {
  group('District provider integrations', () {
    testWidgets(
        'educator integrations page renders Clever and ClassLink and queues sync by provider',
        (WidgetTester tester) async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      final FirestoreService firestoreService = FirestoreService(
        firestore: firestore,
        auth: _MockFirebaseAuth(),
      );
      final EducatorService educatorService = EducatorService(
        firestoreService: firestoreService,
        educatorId: 'educator-1',
        siteId: 'site-1',
      );
      final AppState appState = _buildEducatorState();
      final List<Map<String, String>> syncCalls = <Map<String, String>>[];

      await tester.pumpWidget(
        _buildEducatorHarness(
          appState: appState,
          educatorService: educatorService,
          child: EducatorIntegrationsPage(
            healthLoader: (String siteId) async => <String, dynamic>{
              'connections': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'clever-1',
                  'provider': 'clever',
                  'status': 'active',
                  'siteId': siteId,
                },
                <String, dynamic>{
                  'id': 'classlink-1',
                  'provider': 'classlink',
                  'status': 'active',
                  'siteId': siteId,
                },
              ],
              'syncJobs': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'job-1',
                  'provider': 'clever',
                  'type': 'clever_roster_preview',
                  'status': 'completed',
                  'updatedAt': DateTime.now().millisecondsSinceEpoch,
                },
                <String, dynamic>{
                  'id': 'job-2',
                  'provider': 'classlink',
                  'type': 'classlink_roster_preview',
                  'status': 'completed',
                  'updatedAt': DateTime.now().millisecondsSinceEpoch,
                },
              ],
            },
            syncJobTrigger: (String siteId, String provider) async {
              syncCalls.add(<String, String>{
                'siteId': siteId,
                'provider': provider,
              });
            },
            connectionStatusUpdater: (_, __) async {},
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Clever'), findsOneWidget);
      expect(find.text('ClassLink'), findsOneWidget);
      expect(find.textContaining('Last synced'), findsNWidgets(2));

      await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sync Now'));
      await tester.pumpAndSettle();

      expect(syncCalls, hasLength(1));
      expect(syncCalls.first['siteId'], 'site-1');
      expect(syncCalls.first['provider'], 'classlink');
    });

    testWidgets(
        'site integrations health page renders Clever and ClassLink connections',
        (WidgetTester tester) async {
      final AppState appState = _buildSiteState();

      await tester.pumpWidget(
        _buildSiteHarness(
          appState: appState,
          child: SiteIntegrationsHealthPage(
            healthLoader: (String siteId) async => <String, dynamic>{
              'connections': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'clever-conn',
                  'provider': 'clever',
                  'status': 'active',
                  'siteId': siteId,
                },
                <String, dynamic>{
                  'id': 'classlink-conn',
                  'provider': 'classlink',
                  'status': 'revoked',
                  'siteId': siteId,
                },
              ],
              'syncJobs': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'job-1',
                  'provider': 'clever',
                  'status': 'completed',
                  'createdAt': DateTime.now().millisecondsSinceEpoch,
                },
                <String, dynamic>{
                  'id': 'job-2',
                  'provider': 'classlink',
                  'status': 'failed',
                  'createdAt': DateTime.now().millisecondsSinceEpoch,
                },
              ],
            },
            rosterImportRepository:
                RosterImportRepository(firestore: FakeFirebaseFirestore()),
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Clever'), findsOneWidget);
      expect(find.text('ClassLink'), findsOneWidget);
      expect(find.text('Healthy'), findsWidgets);
      expect(find.text('Disconnected'), findsOneWidget);
    });

    testWidgets(
        'site identity page routes approve and ignore through provider-aware resolver inputs',
        (WidgetTester tester) async {
      final AppState appState = _buildSiteState();
      final List<Map<String, String?>> resolverCalls = <Map<String, String?>>[];
      // Loader is stateful: excludes already-resolved identities so the page
      // correctly removes them from the queue after each action.
      final List<Map<String, dynamic>> allIdentities = <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'identity-1',
          'provider': 'clever',
          'providerUserId': 'clever-learner-1',
          'scholesaUserId': 'learner-1',
          'scholesaUserName': 'Clever Learner',
          'confidence': 0.93,
          'status': 'unmatched',
        },
        <String, dynamic>{
          'id': 'identity-2',
          'provider': 'classlink',
          'providerUserId': 'classlink-learner-2',
          'scholesaUserId': 'learner-2',
          'scholesaUserName': 'ClassLink Learner',
          'confidence': 0.84,
          'status': 'unmatched',
        },
      ];

      await tester.pumpWidget(
        _buildSiteHarness(
          appState: appState,
          child: SiteIdentityPage(
            identityLoader: (_) async {
              final Set<String> resolved =
                  resolverCalls.map((Map<String, String?> c) => c['id']!).toSet();
              return allIdentities
                  .where((Map<String, dynamic> i) =>
                      !resolved.contains(i['id'] as String))
                  .toList();
            },
            identityResolver: (
              String id,
              String rawProvider,
              String decision,
              String? suggestedUserId,
            ) async {
              resolverCalls.add(<String, String?>{
                'id': id,
                'provider': rawProvider,
                'decision': decision,
                'suggestedUserId': suggestedUserId,
              });
            },
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Clever'), findsOneWidget);
      expect(find.text('ClassLink'), findsOneWidget);
      expect(find.text('Approve Match'), findsNWidgets(2));

      await tester.tap(find.text('Approve Match').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ignore').first);
      await tester.pumpAndSettle();

      expect(resolverCalls, hasLength(2));
      expect(resolverCalls.first['id'], 'identity-1');
      expect(resolverCalls.first['provider'], 'clever');
      expect(resolverCalls.first['decision'], 'link');
      expect(resolverCalls.first['suggestedUserId'], 'learner-1');
      expect(resolverCalls.last['id'], 'identity-2');
      expect(resolverCalls.last['provider'], 'classlink');
      expect(resolverCalls.last['decision'], 'ignore');
      expect(resolverCalls.last['suggestedUserId'], 'learner-2');
    });

    testWidgets(
        'site identity page shows unavailable confidence instead of inventing midpoint values',
        (WidgetTester tester) async {
      final AppState appState = _buildSiteState();

      await tester.pumpWidget(
        _buildSiteHarness(
          appState: appState,
          child: SiteIdentityPage(
            identityLoader: (_) async => <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'identity-missing-confidence',
                'provider': 'google_classroom',
                'providerUserId': 'external-learner-1',
                'scholesaUserId': 'learner-1',
                'scholesaUserName': 'Learner One',
                'status': 'unmatched',
              },
            ],
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Match confidence unavailable'), findsOneWidget);
      expect(find.text('Match confidence: 50%'), findsNothing);
    });

    testWidgets(
        'site identity page shows unavailable account labels instead of unknown identities',
        (WidgetTester tester) async {
      final AppState appState = _buildSiteState();

      await tester.pumpWidget(
        _buildSiteHarness(
          appState: appState,
          child: SiteIdentityPage(
            identityLoader: (_) async => <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'identity-missing-accounts',
                'provider': 'google_classroom',
                'scholesaUserId': 'learner-1',
                'status': 'unmatched',
              },
            ],
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Local account unavailable'), findsOneWidget);
      expect(find.text('External account unavailable'), findsOneWidget);
      expect(find.text('Unknown local account'), findsNothing);
      expect(find.text('Unknown external account'), findsNothing);
    });
  });
}
