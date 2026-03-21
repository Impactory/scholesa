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
import 'package:scholesa_app/modules/messages/message_models.dart';
import 'package:scholesa_app/modules/messages/message_service.dart';
import 'package:scholesa_app/modules/messages/messages_page.dart';
import 'package:scholesa_app/services/firestore_service.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _FakeMessageService extends MessageService {
  _FakeMessageService({
    List<Message>? notifications,
    List<Conversation>? conversations,
    this.loading = false,
    this.loadError,
    this.onLoad,
  })  : _notifications = List<Message>.from(notifications ?? const <Message>[]),
        _conversations = List<Conversation>.from(conversations ?? const <Conversation>[]),
        super(
          firestoreService: FirestoreService(
            firestore: FakeFirebaseFirestore(),
            auth: _MockFirebaseAuth(),
          ),
          userId: 'test-user-1',
        );

  final List<Message> _notifications;
  final List<Conversation> _conversations;
  final bool loading;
  final String? loadError;
  final Future<void> Function(_FakeMessageService service)? onLoad;

  bool _loadingValue = false;
  String? _errorValue;

  @override
  List<Message> get notificationMessages => List<Message>.unmodifiable(_notifications);

  @override
  List<Conversation> get conversations => List<Conversation>.unmodifiable(_conversations);

  @override
  bool get isLoading => onLoad == null ? loading : _loadingValue;

  @override
  String? get error => onLoad == null ? loadError : _errorValue;

  void setLoadError(String? value) {
    _errorValue = value;
  }

  @override
  Future<void> loadMessages() async {
    if (onLoad == null) {
      return;
    }
    _loadingValue = true;
    _errorValue = null;
    notifyListeners();
    await onLoad!(this);
    _loadingValue = false;
    notifyListeners();
  }
}

class _FakeUrlLauncherPlatform extends UrlLauncherPlatform {
  final List<String> launchedUrls = <String>[];
  bool canLaunchResult = true;
  bool launchResult = true;

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => canLaunchResult;

  @override
  Future<void> closeWebView() async {}

  @override
  Future<bool> launch(
    String url, {
    required bool useSafariVC,
    required bool useWebView,
    required bool enableJavaScript,
    required bool enableDomStorage,
    required bool universalLinksOnly,
    required Map<String, String> headers,
    String? webOnlyWindowName,
  }) async {
    launchedUrls.add(url);
    return launchResult;
  }

  @override
  Future<bool> supportsCloseForMode(PreferredLaunchMode mode) async => false;

  @override
  Future<bool> supportsMode(PreferredLaunchMode mode) async => true;
}

Widget _buildHarness({
  required GoRouter router,
  required List<SingleChildWidget> providers,
  Locale locale = const Locale('en'),
}) {
  return MultiProvider(
    providers: providers,
    child: MaterialApp.router(
      locale: locale,
      routerConfig: router,
      theme: ThemeData(
        useMaterial3: true,
        splashFactory: NoSplash.splashFactory,
      ),
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

Future<void> _seedMessage(
  FakeFirebaseFirestore firestore, {
  required String id,
  required String title,
  required String actionUrl,
  String? senderName = 'Scholesa Team',
}) async {
  await firestore.collection('messages').doc(id).set(<String, dynamic>{
    'title': title,
    'body': 'Open the linked detail flow.',
    'type': 'announcement',
    'priority': 'normal',
    'recipientId': 'test-user-1',
    if (senderName != null) 'senderName': senderName,
    'createdAt': Timestamp.fromDate(DateTime(2026, 3, 17, 9)),
    'isRead': false,
    'actionUrl': actionUrl,
  });
}

Future<void> _seedConversation(
  FakeFirebaseFirestore firestore, {
  required String id,
  required List<String> participantNames,
}) async {
  await firestore.collection('messageThreads').doc(id).set(<String, dynamic>{
    'participantIds': <String>['test-user-1', 'educator-1'],
    'participantNames': participantNames,
    'updatedAt': Timestamp.fromDate(DateTime(2026, 3, 17, 10)),
    'lastMessagePreview': 'Latest thread update.',
    'lastMessageSenderId': 'educator-1',
    'title': 'Direct conversation',
  });
}

void main() {
  group('message detail action links', () {
    testWidgets('internal action links navigate to the routed destination',
        (WidgetTester tester) async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      await _seedMessage(
        firestore,
        id: 'message-internal',
        title: 'Review your profile',
        actionUrl: '/profile',
      );
      final FirestoreService firestoreService = FirestoreService(
        firestore: firestore,
        auth: _MockFirebaseAuth(),
      );
      final MessageService messageService = MessageService(
        firestoreService: firestoreService,
        userId: 'test-user-1',
      );
      final GoRouter router = GoRouter(
        initialLocation: '/messages',
        routes: <RouteBase>[
          GoRoute(
            path: '/messages',
            builder: (BuildContext context, GoRouterState state) =>
                const MessagesPage(),
          ),
          GoRoute(
            path: '/profile',
            builder: (BuildContext context, GoRouterState state) =>
                const Scaffold(
                    body: Center(child: Text('Profile Destination'))),
          ),
        ],
      );

      await tester.pumpWidget(
        _buildHarness(
          router: router,
          providers: <SingleChildWidget>[
            Provider<FirestoreService>.value(value: firestoreService),
            ChangeNotifierProvider<MessageService>.value(value: messageService),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Review your profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('View Details'));
      await tester.pumpAndSettle();

      expect(find.text('Profile Destination'), findsOneWidget);
    });

    testWidgets('external action links launch outside the app',
        (WidgetTester tester) async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      await _seedMessage(
        firestore,
        id: 'message-external',
        title: 'Open policy update',
        actionUrl: 'https://scholesa.com/policy-update',
      );
      final FirestoreService firestoreService = FirestoreService(
        firestore: firestore,
        auth: _MockFirebaseAuth(),
      );
      final MessageService messageService = MessageService(
        firestoreService: firestoreService,
        userId: 'test-user-1',
      );
      final GoRouter router = GoRouter(
        initialLocation: '/messages',
        routes: <RouteBase>[
          GoRoute(
            path: '/messages',
            builder: (BuildContext context, GoRouterState state) =>
                const MessagesPage(),
          ),
        ],
      );
      final _FakeUrlLauncherPlatform launcherPlatform =
          _FakeUrlLauncherPlatform();
      final UrlLauncherPlatform previousLauncherPlatform =
          UrlLauncherPlatform.instance;
      UrlLauncherPlatform.instance = launcherPlatform;

      try {
        await tester.pumpWidget(
          _buildHarness(
            router: router,
            providers: <SingleChildWidget>[
              Provider<FirestoreService>.value(value: firestoreService),
              ChangeNotifierProvider<MessageService>.value(
                  value: messageService),
            ],
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open policy update'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('View Details'));
        await tester.pumpAndSettle();

        expect(
          launcherPlatform.launchedUrls,
          contains('https://scholesa.com/policy-update'),
        );
      } finally {
        UrlLauncherPlatform.instance = previousLauncherPlatform;
      }
    });

    testWidgets('messages page shows explicit unavailable identity labels',
        (WidgetTester tester) async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      await _seedMessage(
        firestore,
        id: 'message-missing-sender',
        title: 'Sender label regression',
        actionUrl: '/profile',
        senderName: ' unknown ',
      );
      await _seedConversation(
        firestore,
        id: 'thread-missing-participant',
        participantNames: <String>['Test User', ' unknown '],
      );
      final FirestoreService firestoreService = FirestoreService(
        firestore: firestore,
        auth: _MockFirebaseAuth(),
      );
      final MessageService messageService = MessageService(
        firestoreService: firestoreService,
        userId: 'test-user-1',
      );
      final GoRouter router = GoRouter(
        initialLocation: '/messages',
        routes: <RouteBase>[
          GoRoute(
            path: '/messages',
            builder: (BuildContext context, GoRouterState state) =>
                const MessagesPage(),
          ),
          GoRoute(
            path: '/profile',
            builder: (BuildContext context, GoRouterState state) =>
                const Scaffold(body: SizedBox.shrink()),
          ),
        ],
      );

      await tester.pumpWidget(
        _buildHarness(
          router: router,
          locale: const Locale('zh', 'CN'),
          providers: <SingleChildWidget>[
            Provider<FirestoreService>.value(value: firestoreService),
            ChangeNotifierProvider<MessageService>.value(value: messageService),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sender label regression'), findsOneWidget);
      expect(find.textContaining('发送者信息不可用'), findsWidgets);
      expect(find.text('Sender unavailable'), findsNothing);

      await tester.tap(find.text('对话'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('对话参与者信息不可用'),
        findsOneWidget,
      );
      expect(find.text('Unknown'), findsNothing);
      expect(find.text('unknown'), findsNothing);
    });

    testWidgets('messages page shows honest error state when notifications fail to load',
        (WidgetTester tester) async {
      final _FakeMessageService messageService = _FakeMessageService(
        loadError: 'Failed to load messages: boom',
      );
      final GoRouter router = GoRouter(
        initialLocation: '/messages',
        routes: <RouteBase>[
          GoRoute(
            path: '/messages',
            builder: (BuildContext context, GoRouterState state) =>
                const MessagesPage(),
          ),
        ],
      );

      await tester.pumpWidget(
        _buildHarness(
          router: router,
          locale: const Locale('zh', 'CN'),
          providers: <SingleChildWidget>[
            ChangeNotifierProvider<MessageService>.value(value: messageService),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('目前无法加载消息'), findsOneWidget);
      expect(find.textContaining('请稍后重试'), findsOneWidget);
      expect(find.text('暂无通知'), findsNothing);
    });

    testWidgets('messages conversations tab keeps spinner while shared load is still in flight',
        (WidgetTester tester) async {
      final _FakeMessageService messageService = _FakeMessageService(
        loading: true,
      );
      final GoRouter router = GoRouter(
        initialLocation: '/messages',
        routes: <RouteBase>[
          GoRoute(
            path: '/messages',
            builder: (BuildContext context, GoRouterState state) =>
                const MessagesPage(),
          ),
        ],
      );

      await tester.pumpWidget(
        _buildHarness(
          router: router,
          providers: <SingleChildWidget>[
            ChangeNotifierProvider<MessageService>.value(value: messageService),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Conversations'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('No conversations'), findsNothing);
    });

    testWidgets('messages page keeps stale inbox data visible after refresh failure',
        (WidgetTester tester) async {
      int loadCount = 0;
      final _FakeMessageService messageService = _FakeMessageService(
        notifications: <Message>[
          Message(
            id: 'message-1',
            title: 'Parent update',
            body: 'Bring the prototype notes tomorrow.',
            type: MessageType.announcement,
            senderName: 'Scholesa Team',
            createdAt: DateTime(2026, 3, 17, 9),
            isRead: false,
          ),
        ],
        conversations: <Conversation>[
          Conversation(
            id: 'thread-1',
            participantIds: const <String>['test-user-1', 'educator-1'],
            participantNames: const <String>['Test User', 'Educator One'],
            lastMessage: Message(
              id: 'thread-message-1',
              title: 'Direct conversation',
              body: 'Latest thread update.',
              type: MessageType.direct,
              senderName: 'Educator One',
              createdAt: DateTime(2026, 3, 17, 10),
              isRead: false,
            ),
            updatedAt: DateTime(2026, 3, 17, 10),
            unreadCount: 1,
          ),
        ],
        onLoad: (_FakeMessageService service) async {
          loadCount += 1;
          if (loadCount > 1) {
            service.setLoadError('Failed to load messages: boom');
          }
        },
      );
      final GoRouter router = GoRouter(
        initialLocation: '/messages',
        routes: <RouteBase>[
          GoRoute(
            path: '/messages',
            builder: (BuildContext context, GoRouterState state) =>
                const MessagesPage(),
          ),
        ],
      );

      await tester.pumpWidget(
        _buildHarness(
          router: router,
          providers: <SingleChildWidget>[
            ChangeNotifierProvider<MessageService>.value(value: messageService),
          ],
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Parent update'), findsOneWidget);

      await tester.tap(find.byTooltip('Refresh'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Parent update'), findsOneWidget);
      expect(
        find.text(
          'Unable to refresh messages right now. Showing the last successful data. Failed to load messages: boom',
        ),
        findsOneWidget,
      );
      expect(find.text('No notifications'), findsNothing);
    });
  });
}
