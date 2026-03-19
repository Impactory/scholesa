import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/modules/hq_admin/hq_curriculum_page.dart';
import 'package:scholesa_app/modules/messages/message_service.dart';
import 'package:scholesa_app/modules/messages/messages_page.dart';
import 'package:scholesa_app/modules/partner/partner_payouts_page.dart';
import 'package:scholesa_app/modules/partner/partner_service.dart';
import 'package:scholesa_app/services/firestore_service.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

AppState _buildAppState({
  required UserRole role,
  required Locale locale,
}) {
  final AppState appState = AppState();
  appState.updateFromMeResponse(<String, dynamic>{
    'userId': 'test-user-1',
    'email': 'test-user-1@scholesa.test',
    'displayName': 'Test User',
    'role': role.name,
    'activeSiteId': 'site-1',
    'siteIds': <String>['site-1'],
    'localeCode': locale.languageCode == 'zh'
        ? 'zh-${locale.countryCode}'
        : 'en',
    'entitlements': <Map<String, dynamic>>[],
  });
  return appState;
}

Widget _buildHarness({
  required Locale locale,
  required Widget child,
  required List<SingleChildWidget> providers,
}) {
  return MultiProvider(
    providers: providers,
    child: MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        splashFactory: NoSplash.splashFactory,
      ),
      locale: locale,
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
      home: child,
    ),
  );
}

void main() {
  group('Shared role tri-locale surfaces', () {
    testWidgets('messages page renders zh-CN copy',
        (WidgetTester tester) async {
      final Locale locale = const Locale('zh', 'CN');
      final FirestoreService firestoreService = FirestoreService(
        firestore: FakeFirebaseFirestore(),
        auth: _MockFirebaseAuth(),
      );
      final MessageService messageService = MessageService(
        firestoreService: firestoreService,
        userId: 'test-user-1',
      );

      await tester.binding.setSurfaceSize(const Size(1280, 1800));
      await tester.pumpWidget(
        _buildHarness(
          locale: locale,
          child: const MessagesPage(),
          providers: <SingleChildWidget>[
            Provider<FirestoreService>.value(value: firestoreService),
            ChangeNotifierProvider<MessageService>.value(value: messageService),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('消息'), findsOneWidget);
      expect(find.text('通知'), findsOneWidget);
      expect(find.text('暂无通知'), findsOneWidget);
    });

    testWidgets('hq curriculum page renders zh-TW copy',
        (WidgetTester tester) async {
      final Locale locale = const Locale('zh', 'TW');
      final FirestoreService firestoreService = FirestoreService(
        firestore: FakeFirebaseFirestore(),
        auth: _MockFirebaseAuth(),
      );
      final AppState appState = _buildAppState(
        role: UserRole.hq,
        locale: locale,
      );

      await tester.binding.setSurfaceSize(const Size(1280, 1800));
      await tester.pumpWidget(
        _buildHarness(
          locale: locale,
          child: const HqCurriculumPage(),
          providers: <SingleChildWidget>[
            Provider<FirestoreService>.value(value: firestoreService),
            ChangeNotifierProvider<AppState>.value(value: appState),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('課程管理'), findsOneWidget);
      expect(find.text('已發佈'), findsOneWidget);
      expect(find.text('新課程'), findsOneWidget);
    });

    testWidgets('partner payouts page renders zh-CN copy',
        (WidgetTester tester) async {
      final Locale locale = const Locale('zh', 'CN');
      final FirestoreService firestoreService = FirestoreService(
        firestore: FakeFirebaseFirestore(),
        auth: _MockFirebaseAuth(),
      );
      final PartnerService partnerService = PartnerService(
        firestoreService: firestoreService,
        partnerId: 'partner-1',
      );

      await tester.binding.setSurfaceSize(const Size(1280, 1800));
      await tester.pumpWidget(
        _buildHarness(
          locale: locale,
          child: const PartnerPayoutsPage(),
          providers: <SingleChildWidget>[
            Provider<FirestoreService>.value(value: firestoreService),
            ChangeNotifierProvider<PartnerService>.value(value: partnerService),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('付款'), findsOneWidget);
      expect(find.text('暂无付款'), findsOneWidget);
      expect(find.text('你的付款记录将显示在这里'), findsOneWidget);
    });
  });
}
