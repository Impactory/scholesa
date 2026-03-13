import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/modules/learner/learner_onboarding_gate.dart';
import 'package:scholesa_app/services/firestore_service.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

AppState _buildLearnerState() {
  final AppState appState = AppState();
  appState.updateFromMeResponse(<String, dynamic>{
    'userId': 'learner-1',
    'email': 'learner-1@scholesa.test',
    'displayName': 'Learner One',
    'role': 'learner',
    'activeSiteId': 'site-1',
    'siteIds': <String>['site-1'],
    'entitlements': <Map<String, dynamic>>[],
  });
  return appState;
}

Widget _buildRouterHarness({
  required GoRouter router,
  required FirestoreService firestoreService,
  required AppState appState,
}) {
  return MultiProvider(
    providers: <SingleChildWidget>[
      ChangeNotifierProvider<AppState>.value(value: appState),
      Provider<FirestoreService>.value(value: firestoreService),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  group('Learner onboarding gate', () {
    testWidgets('redirects incomplete learner to onboarding route',
        (WidgetTester tester) async {
      final FirestoreService firestoreService = FirestoreService(
        firestore: FakeFirebaseFirestore(),
        auth: _MockFirebaseAuth(),
      );
      final AppState appState = _buildLearnerState();
      final GoRouter router = GoRouter(
        initialLocation: '/learner/missions',
        routes: <RouteBase>[
          GoRoute(
            path: '/learner/missions',
            builder: (BuildContext context, GoRouterState state) =>
                const LearnerOnboardingGate(
              child: Scaffold(body: Text('Missions route')),
            ),
          ),
          GoRoute(
            path: '/learner/onboarding',
            builder: (BuildContext context, GoRouterState state) =>
                const LearnerOnboardingGate(
              allowIncompleteSetup: true,
              child: Scaffold(body: Text('Onboarding route')),
            ),
          ),
        ],
      );

      await tester.pumpWidget(_buildRouterHarness(
        router: router,
        firestoreService: firestoreService,
        appState: appState,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Onboarding route'), findsOneWidget);
      expect(find.text('Missions route'), findsNothing);
    });

    testWidgets('allows completed learner to stay on workflow route',
        (WidgetTester tester) async {
      final FakeFirebaseFirestore fakeFirestore = FakeFirebaseFirestore();
      await fakeFirestore.collection('learnerProfiles').doc('site-1_learner-1').set(
        <String, dynamic>{
          'learnerId': 'learner-1',
          'siteId': 'site-1',
          'onboardingCompleted': true,
        },
      );
      final FirestoreService firestoreService = FirestoreService(
        firestore: fakeFirestore,
        auth: _MockFirebaseAuth(),
      );
      final AppState appState = _buildLearnerState();
      final GoRouter router = GoRouter(
        initialLocation: '/learner/missions',
        routes: <RouteBase>[
          GoRoute(
            path: '/learner/missions',
            builder: (BuildContext context, GoRouterState state) =>
                const LearnerOnboardingGate(
              child: Scaffold(body: Text('Missions route')),
            ),
          ),
          GoRoute(
            path: '/learner/onboarding',
            builder: (BuildContext context, GoRouterState state) =>
                const LearnerOnboardingGate(
              allowIncompleteSetup: true,
              child: Scaffold(body: Text('Onboarding route')),
            ),
          ),
        ],
      );

      await tester.pumpWidget(_buildRouterHarness(
        router: router,
        firestoreService: firestoreService,
        appState: appState,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Missions route'), findsOneWidget);
      expect(find.text('Onboarding route'), findsNothing);
    });
  });
}