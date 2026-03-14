import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/domain/models.dart';
import 'package:scholesa_app/domain/repositories.dart';
import 'package:scholesa_app/modules/educator/educator_integrations_page.dart';
import 'package:scholesa_app/modules/educator/educator_service.dart';
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

Widget _buildHarness({
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

void main() {
  group('Google Classroom integration', () {
    testWidgets('educator integrations page renders sync state and queues a sync job',
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

      final DateTime lastSync = DateTime.now().subtract(const Duration(minutes: 18));

      await tester.pumpWidget(
        _buildHarness(
          appState: appState,
          educatorService: educatorService,
          child: EducatorIntegrationsPage(
            healthLoader: (String siteId) async => <String, dynamic>{
              'connections': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'gc-1',
                  'provider': 'google_classroom',
                  'status': 'active',
                  'siteId': siteId,
                },
              ],
              'syncJobs': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'job-1',
                  'provider': 'google_classroom',
                  'status': 'completed',
                  'updatedAt': lastSync.millisecondsSinceEpoch,
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

      expect(find.text('Google Classroom'), findsOneWidget);
      expect(find.textContaining('Last synced'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sync Now'));
      await tester.pumpAndSettle();

      expect(syncCalls, hasLength(1));
      expect(syncCalls.first['siteId'], 'site-1');
      expect(syncCalls.first['provider'], 'google_classroom');
      expect(find.textContaining('sync queued'), findsOneWidget);
    });

    test('integration repositories persist classroom linkage models', () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      final Timestamp now = Timestamp.now();

      final IntegrationConnectionRepository connections =
          IntegrationConnectionRepository(firestore: firestore);
      final ExternalCourseLinkRepository courseLinks =
          ExternalCourseLinkRepository(firestore: firestore);
      final ExternalUserLinkRepository userLinks =
          ExternalUserLinkRepository(firestore: firestore);
      final ExternalCourseworkLinkRepository courseworkLinks =
          ExternalCourseworkLinkRepository(firestore: firestore);

      await connections.upsert(
        IntegrationConnectionModel(
          id: 'conn-1',
          ownerUserId: 'educator-1',
          provider: 'google_classroom',
          status: 'active',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await courseLinks.upsert(
        ExternalCourseLinkModel(
          id: 'course-link-1',
          provider: 'google_classroom',
          providerCourseId: 'course-123',
          ownerUserId: 'educator-1',
          siteId: 'site-1',
          sessionId: 'session-1',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await userLinks.upsert(
        ExternalUserLinkModel(
          id: 'user-link-1',
          provider: 'google_classroom',
          providerUserId: 'teacher-123',
          scholesaUserId: 'educator-1',
          siteId: 'site-1',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await courseworkLinks.upsert(
        ExternalCourseworkLinkModel(
          id: 'coursework-link-1',
          provider: 'google_classroom',
          providerCourseId: 'course-123',
          providerCourseWorkId: 'coursework-123',
          siteId: 'site-1',
          missionId: 'mission-1',
          publishedBy: 'educator-1',
          publishedAt: now,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final List<IntegrationConnectionModel> loadedConnections =
          await connections.listByOwner('educator-1');
      final List<ExternalCourseLinkModel> loadedCourseLinks =
          await courseLinks.listBySite('site-1');
      final List<ExternalUserLinkModel> loadedUserLinks =
          await userLinks.listBySite('site-1');
      final List<ExternalCourseworkLinkModel> loadedCourseworkLinks =
          await courseworkLinks.listBySite('site-1');

      expect(loadedConnections, hasLength(1));
      expect(loadedConnections.first.provider, 'google_classroom');
      expect(loadedCourseLinks, hasLength(1));
      expect(loadedCourseLinks.first.providerCourseId, 'course-123');
      expect(loadedUserLinks, hasLength(1));
      expect(loadedUserLinks.first.providerUserId, 'teacher-123');
      expect(loadedCourseworkLinks, hasLength(1));
      expect(loadedCourseworkLinks.first.missionId, 'mission-1');
    });
  });
}