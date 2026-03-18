import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/modules/educator/educator_service.dart';
import 'package:scholesa_app/modules/educator/educator_today_page.dart';
import 'package:scholesa_app/modules/habits/habit_service.dart';
import 'package:scholesa_app/modules/learner/learner_today_page.dart';
import 'package:scholesa_app/modules/messages/message_service.dart';
import 'package:scholesa_app/modules/missions/mission_service.dart';
import 'package:scholesa_app/services/firestore_service.dart';

final ThemeData _testTheme = ThemeData(
  useMaterial3: true,
  splashFactory: InkRipple.splashFactory,
);

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

AppState _buildAppState({
  required String userId,
  required String displayName,
  required UserRole role,
  required String siteId,
}) {
  final AppState appState = AppState();
  appState.updateFromMeResponse(<String, dynamic>{
    'userId': userId,
    'email': '$userId@scholesa.test',
    'displayName': displayName,
    'role': role.name,
    'activeSiteId': siteId,
    'siteIds': <String>[siteId],
    'entitlements': <Map<String, dynamic>>[],
  });
  return appState;
}

void main() {
  group('MiloOS role analytics regressions', () {
    testWidgets('learner today renders MiloOS learning loop card',
        (WidgetTester tester) async {
      final FirestoreService firestoreService = FirestoreService(
        firestore: FakeFirebaseFirestore(),
        auth: _MockFirebaseAuth(),
      );
      final AppState appState = _buildAppState(
        userId: 'learner-test-1',
        displayName: 'Luna Learner',
        role: UserRole.learner,
        siteId: 'site-test-1',
      );
      final MissionService missionService = MissionService(
        firestoreService: firestoreService,
        learnerId: 'learner-test-1',
      );
      final HabitService habitService = HabitService(
        firestoreService: firestoreService,
        learnerId: 'learner-test-1',
      );
      final MessageService messageService = MessageService(
        firestoreService: firestoreService,
        userId: 'learner-test-1',
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: <SingleChildWidget>[
            ChangeNotifierProvider<AppState>.value(value: appState),
            Provider<FirestoreService>.value(value: firestoreService),
            ChangeNotifierProvider<MissionService>.value(value: missionService),
            ChangeNotifierProvider<HabitService>.value(value: habitService),
            ChangeNotifierProvider<MessageService>.value(value: messageService),
          ],
          child: MaterialApp(
            theme: _testTheme,
            home: const LearnerTodayPage(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.scrollUntilVisible(
        find.text('MiloOS Learning Loop'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('MiloOS Learning Loop'), findsOneWidget);
      expect(find.textContaining('Latest individual improvement signal'),
          findsOneWidget);
    });

    testWidgets('educator today renders MiloOS learner loop card',
        (WidgetTester tester) async {
      final FakeFirebaseFirestore fakeFirestore = FakeFirebaseFirestore();
      await fakeFirestore.collection('users').doc('educator-test-1').set(
        <String, dynamic>{
          'displayName': 'Edu One',
          'learnerIds': <String>['learner-test-2'],
        },
      );
      await fakeFirestore.collection('users').doc('learner-test-2').set(
        <String, dynamic>{
          'displayName': 'Nia Learner',
          'email': 'nia@scholesa.test',
        },
      );

      final FirestoreService firestoreService = FirestoreService(
        firestore: fakeFirestore,
        auth: _MockFirebaseAuth(),
      );
      final AppState appState = _buildAppState(
        userId: 'educator-test-1',
        displayName: 'Edu One',
        role: UserRole.educator,
        siteId: 'site-test-1',
      );
      final EducatorService educatorService = EducatorService(
        firestoreService: firestoreService,
        educatorId: 'educator-test-1',
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: <SingleChildWidget>[
            ChangeNotifierProvider<AppState>.value(value: appState),
            Provider<FirestoreService>.value(value: firestoreService),
            ChangeNotifierProvider<EducatorService>.value(
              value: educatorService,
            ),
          ],
          child: MaterialApp(
            theme: _testTheme,
            home: const EducatorTodayPage(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.scrollUntilVisible(
        find.text('MiloOS Class Insights'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('MiloOS Class Insights'), findsOneWidget);
      expect(
        find.textContaining('FDM state estimate, BAE watchlist'),
        findsOneWidget,
      );
    });
  });
}
