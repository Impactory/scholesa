import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/dashboards/role_dashboard.dart';
import 'package:scholesa_app/modules/messages/message_service.dart';
import 'package:scholesa_app/router/app_router.dart';
import 'package:scholesa_app/services/firestore_service.dart';

final ThemeData _testTheme = ThemeData(
  useMaterial3: true,
  splashFactory: InkRipple.splashFactory,
);

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

AppState _buildStateForRole(UserRole role) {
  final AppState appState = AppState();
  appState.updateFromMeResponse(<String, dynamic>{
    'userId': 'smoke-${role.name}',
    'email': '${role.name}@scholesa.test',
    'displayName': '${role.displayName} User',
    'role': role.name,
    'activeSiteId': 'site-1',
    'siteIds': <String>['site-1', 'site-2'],
    'entitlements': <dynamic>[],
  });
  return appState;
}

void main() {
  group('Role workflow smoke', () {
    test('every role maps to an enabled default route', () {
      for (final UserRole role in UserRole.values) {
        final String route = roleDefaultWorkflowRoute(role);
        expect(route, isNotEmpty,
            reason: 'route should exist for ${role.name}');
        expect(isRouteEnabled(route), isTrue,
            reason: 'default route should be enabled for ${role.name}');
      }
    });

    test('inventory-aligned routes are enabled', () {
      const List<String> inventoryAlignedRoutes = <String>[
        '/learner/credentials',
        '/learner/settings',
        '/educator/review-queue',
        '/parent/messages',
        '/parent/settings',
        '/parent/child/:learnerId',
        '/parent/consent',
        '/site/scheduling',
        '/site/pickup-auth',
        '/site/consent',
        '/site/audit',
        '/partner/deliverables',
        '/partner/integrations',
        '/hq/cms',
        '/hq/exports',
      ];
      for (final String route in inventoryAlignedRoutes) {
        expect(isRouteEnabled(route), isTrue,
            reason: '$route should be enabled');
      }
    });

    for (final UserRole role in UserRole.values) {
      testWidgets('dashboard renders for ${role.name}',
          (WidgetTester tester) async {
        final AppState appState = _buildStateForRole(role);
        final FirestoreService firestoreService = FirestoreService(
          firestore: FakeFirebaseFirestore(),
          auth: _MockFirebaseAuth(),
        );
        final MessageService messageService = MessageService(
          firestoreService: firestoreService,
          userId: appState.userId ?? 'smoke-${role.name}',
        );

        await tester.binding.setSurfaceSize(const Size(1280, 800));
        addTearDown(() async {
          await tester.binding.setSurfaceSize(null);
        });

        await tester.pumpWidget(
          MultiProvider(
            providers: <SingleChildWidget>[
              Provider<FirestoreService>.value(value: firestoreService),
              ChangeNotifierProvider<AppState>.value(value: appState),
              ChangeNotifierProvider<MessageService>.value(
                  value: messageService),
            ],
            child: MaterialApp(
              theme: _testTheme,
              home: const RoleDashboard(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(RoleDashboard), findsOneWidget);
        expect(find.text('${role.displayName} User'), findsOneWidget);
        if (role == UserRole.partner) {
          expect(find.text('Deliverables'), findsOneWidget);
          expect(find.text('Partner Integrations'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      });
    }
  });
}
