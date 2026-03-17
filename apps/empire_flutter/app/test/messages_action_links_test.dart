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
import 'package:scholesa_app/modules/messages/message_service.dart';
import 'package:scholesa_app/modules/messages/messages_page.dart';
import 'package:scholesa_app/services/firestore_service.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

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
}) {
  return MultiProvider(
    providers: providers,
    child: MaterialApp.router(
      routerConfig: router,
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
}) async {
  await firestore.collection('messages').doc(id).set(<String, dynamic>{
    'title': title,
    'body': 'Open the linked detail flow.',
    'type': 'announcement',
    'priority': 'normal',
    'recipientId': 'test-user-1',
    'senderName': 'Scholesa Team',
    'createdAt': Timestamp.fromDate(DateTime(2026, 3, 17, 9)),
    'isRead': false,
    'actionUrl': actionUrl,
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
  });
}
