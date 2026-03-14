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
  group('LTI integrations', () {
    testWidgets(
        'educator integrations page renders LTI provider and queues sync',
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
        _buildHarness(
          appState: appState,
          educatorService: educatorService,
          child: EducatorIntegrationsPage(
            healthLoader: (String siteId) async => <String, dynamic>{
              'connections': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'lti-1',
                  'provider': 'lti_1p3',
                  'status': 'active',
                  'siteId': siteId,
                },
              ],
              'syncJobs': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'job-1',
                  'provider': 'lti_1p3',
                  'type': 'grade_push',
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

      expect(find.text('LTI 1.3 / Grade Passback'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sync Now'));
      await tester.pumpAndSettle();

      expect(syncCalls, hasLength(1));
      expect(syncCalls.first['siteId'], 'site-1');
      expect(syncCalls.first['provider'], 'lti_1p3');
    });

    test(
        'LTI repositories persist platform, resource, and grade passback records',
        () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      final Timestamp now = Timestamp.now();

      final LtiPlatformRegistrationRepository platformRepository =
          LtiPlatformRegistrationRepository(firestore: firestore);
      final LtiResourceLinkRepository resourceRepository =
          LtiResourceLinkRepository(firestore: firestore);
      final LtiGradePassbackJobRepository passbackRepository =
          LtiGradePassbackJobRepository(firestore: firestore);

      await platformRepository.upsert(
        LtiPlatformRegistrationModel(
          id: 'platform-1',
          siteId: 'site-1',
          ownerUserId: 'educator-1',
          issuer: 'https://canvas.example',
          clientId: 'client-1',
          deploymentId: 'deployment-1',
          authLoginUrl: 'https://canvas.example/auth',
          accessTokenUrl: 'https://canvas.example/token',
          jwksUrl: 'https://canvas.example/jwks',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await resourceRepository.upsert(
        LtiResourceLinkModel(
          id: 'resource-1',
          registrationId: 'platform-1',
          siteId: 'site-1',
          resourceLinkId: 'resource-link-1',
          missionId: 'mission-1',
          targetPath: '/en/learner?missionId=mission-1',
          lineItemId: 'line-item-1',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await passbackRepository.upsert(
        LtiGradePassbackJobModel(
          id: 'job-1',
          siteId: 'site-1',
          learnerId: 'learner-1',
          missionAttemptId: 'attempt-1',
          requestedBy: 'educator-1',
          lineItemId: 'line-item-1',
          scoreGiven: 9,
          scoreMaximum: 10,
          idempotencyKey: 'idem-1',
          createdAt: now,
          updatedAt: now,
        ),
      );

      final List<LtiPlatformRegistrationModel> platforms =
          await platformRepository.listBySite('site-1');
      final List<LtiResourceLinkModel> resources =
          await resourceRepository.listBySite('site-1');
      final List<LtiGradePassbackJobModel> jobs =
          await passbackRepository.listBySite('site-1');

      expect(platforms, hasLength(1));
      expect(platforms.first.clientId, 'client-1');
      expect(resources, hasLength(1));
      expect(resources.first.lineItemId, 'line-item-1');
      expect(jobs, hasLength(1));
      expect(jobs.first.scoreGiven, 9);
    });
  });
}
