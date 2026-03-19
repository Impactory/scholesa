import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/modules/messages/message_service.dart';
import 'package:scholesa_app/modules/messages/messages_page.dart';
import 'package:scholesa_app/modules/messages/notifications_page.dart';
import 'package:scholesa_app/router/role_gate.dart';
import 'package:scholesa_app/services/firestore_service.dart';
import 'package:scholesa_app/ui/theme/scholesa_theme.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

Widget _buildHarness({
  required MessageService messageService,
  required Widget home,
}) {
  return MultiProvider(
    providers: <SingleChildWidget>[
      ChangeNotifierProvider<MessageService>.value(value: messageService),
    ],
    child: MaterialApp(
      theme: ScholesaTheme.light,
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
      home: home,
    ),
  );
}

Widget _buildRouterHarness({
  required MessageService messageService,
  required AppState appState,
  required GoRouter router,
}) {
  return MultiProvider(
    providers: <SingleChildWidget>[
      ChangeNotifierProvider<AppState>.value(value: appState),
      ChangeNotifierProvider<MessageService>.value(value: messageService),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      theme: ScholesaTheme.light,
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
    ),
  );
}

AppState _buildParentState() {
  final AppState state = AppState();
  state.updateFromMeResponse(<String, dynamic>{
    'userId': 'parent-1',
    'email': 'parent-1@scholesa.test',
    'displayName': 'Parent One',
    'role': UserRole.parent.name,
    'activeSiteId': 'site-1',
    'siteIds': <String>['site-1'],
    'localeCode': 'en',
    'entitlements': const <Map<String, dynamic>>[],
  });
  return state;
}

Future<void> _seedMessages(FakeFirebaseFirestore firestore) async {
  final Timestamp now = Timestamp.fromDate(DateTime(2026, 3, 18, 10));
  await firestore.collection('messages').doc('note-1').set(<String, dynamic>{
    'title': 'Mission reminder',
    'body': 'Bring your prototype notes to class.',
    'type': 'reminder',
    'priority': 'high',
    'senderId': 'educator-1',
    'senderName': 'Educator One',
    'recipientId': 'user-1',
    'createdAt': now,
    'isRead': false,
    'actionUrl': '[',
  });
  await firestore.collection('messages').doc('direct-1').set(<String, dynamic>{
    'title': 'Direct message',
    'body': 'Can you send the attendance note?',
    'type': 'direct',
    'priority': 'normal',
    'senderId': 'educator-2',
    'senderName': 'Coach Kim',
    'recipientId': 'user-1',
    'createdAt': now,
    'isRead': false,
    'threadId': 'thread-1',
  });
  await firestore.collection('messageThreads').doc('thread-1').set(
    <String, dynamic>{
      'participantIds': <String>['user-1', 'educator-2'],
      'participantNames': <String>['User One', 'Coach Kim'],
      'lastMessagePreview': 'Can you send the attendance note?',
      'lastMessageSenderId': 'educator-2',
      'updatedAt': now,
    },
  );
}

void main() {
  testWidgets('parent messages alias route renders the shared messages page',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await _seedMessages(firestore);
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    final MessageService messageService = MessageService(
      firestoreService: firestoreService,
      userId: 'user-1',
    );
    final GoRouter router = GoRouter(
      initialLocation: '/parent/messages',
      routes: <RouteBase>[
        GoRoute(
          path: '/parent/messages',
          builder: (BuildContext context, GoRouterState state) =>
              const RoleGate(
            allowedRoles: <UserRole>[UserRole.parent, UserRole.hq],
            child: MessagesPage(),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      _buildRouterHarness(
        messageService: messageService,
        appState: _buildParentState(),
        router: router,
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Messages'), findsOneWidget);
    expect(find.text('Mission reminder'), findsOneWidget);
    expect(find.text('Access Denied'), findsNothing);
  });

  testWidgets('messages page opens detail, marks notification read, and shows conversations',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await _seedMessages(firestore);
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    final MessageService messageService = MessageService(
      firestoreService: firestoreService,
      userId: 'user-1',
    );

    await tester.pumpWidget(
      _buildHarness(
        messageService: messageService,
        home: const MessagesPage(),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('2 unread'), findsOneWidget);
    expect(find.text('Mission reminder'), findsOneWidget);

    await tester.tap(find.text('Mission reminder'));
    await tester.pumpAndSettle();

    expect(find.text('View Details'), findsOneWidget);
    expect(find.text('From: Educator One'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('1 unread'), findsOneWidget);

    await tester.tap(find.text('Conversations'));
    await tester.pumpAndSettle();

    expect(find.text('Coach Kim'), findsOneWidget);
    expect(find.text('Can you send the attendance note?'), findsOneWidget);
  });

  testWidgets('messages page dismisses a notification from the list',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await _seedMessages(firestore);
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    final MessageService messageService = MessageService(
      firestoreService: firestoreService,
      userId: 'user-1',
    );

    await tester.pumpWidget(
      _buildHarness(
        messageService: messageService,
        home: const MessagesPage(),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Mission reminder'), findsOneWidget);

    await tester.drag(find.byKey(const Key('note-1')), const Offset(-600, 0));
    await tester.pumpAndSettle();

    expect(find.text('Mission reminder'), findsNothing);
  });

  testWidgets('notifications page marks all notifications as read',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await _seedMessages(firestore);
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    final MessageService messageService = MessageService(
      firestoreService: firestoreService,
      userId: 'user-1',
    );

    await tester.pumpWidget(
      _buildHarness(
        messageService: messageService,
        home: const NotificationsPage(),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Mark all read'), findsOneWidget);

    await tester.tap(find.text('Mark all read'));
    await tester.pumpAndSettle();

    expect(find.text('All notifications marked as read'), findsOneWidget);
    expect(find.text('Mark all read'), findsNothing);
  });

  testWidgets('notifications page dismisses notifications with user feedback',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await _seedMessages(firestore);
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    final MessageService messageService = MessageService(
      firestoreService: firestoreService,
      userId: 'user-1',
    );

    await tester.pumpWidget(
      _buildHarness(
        messageService: messageService,
        home: const NotificationsPage(),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Mission reminder'), findsOneWidget);

    await tester.drag(find.byKey(const Key('note-1')), const Offset(-600, 0));
    await tester.pumpAndSettle();

    expect(find.text('Mission reminder'), findsNothing);
    expect(find.text('Notification dismissed'), findsOneWidget);
  });
}