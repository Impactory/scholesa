import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart' show UserRole;
import 'package:scholesa_app/modules/hq_admin/user_admin_page.dart';
import 'package:scholesa_app/modules/hq_admin/user_admin_service.dart';
import 'package:scholesa_app/modules/hq_admin/user_models.dart';
import 'package:scholesa_app/services/firestore_service.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _FakeUserAdminService extends UserAdminService {
  _FakeUserAdminService()
      : super(
          firestoreService: FirestoreService(
            firestore: FakeFirebaseFirestore(),
            auth: _MockFirebaseAuth(),
          ),
        );

  bool loadUsersCalled = false;
  String? lastUpdatedUserId;
  String? lastUpdatedDisplayName;

  final List<UserModel> _fakeUsers = <UserModel>[
    UserModel(
      uid: 'user-1',
      email: 'ava@scholesa.test',
      displayName: 'Ava Learner',
      role: UserRole.learner,
      status: UserStatus.active,
      siteIds: const <String>['site-1'],
      createdAt: DateTime(2026, 1, 1),
    ),
  ];

  @override
  List<UserModel> get users => List<UserModel>.unmodifiable(_fakeUsers);

  @override
  List<SiteModel> get sites => const <SiteModel>[];

  @override
  List<AuditLogEntry> get auditLogs => const <AuditLogEntry>[];

  @override
  bool get isLoading => false;

  @override
  int get totalUsers => _fakeUsers.length;

  @override
  int get activeUsers => 1;

  @override
  int get learnerCount => 1;

  @override
  int get educatorCount => 0;

  @override
  Future<void> loadUsers() async {
    loadUsersCalled = true;
  }

  @override
  Future<void> loadAuditLogs({String? userId}) async {}

  @override
  Future<bool> updateUserDisplayName(String userId, String displayName) async {
    lastUpdatedUserId = userId;
    lastUpdatedDisplayName = displayName;
    _fakeUsers[0] = _fakeUsers[0].copyWith(displayName: displayName);
    notifyListeners();
    return true;
  }
}

Widget _buildHarness({required List<SingleChildWidget> providers}) {
  return MultiProvider(
    providers: providers,
    child: MaterialApp(
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
      home: const UserAdminPage(),
    ),
  );
}

void main() {
  testWidgets('hq user admin edit persists through service before success snackbar',
      (WidgetTester tester) async {
    final _FakeUserAdminService service = _FakeUserAdminService();
    await tester.binding.setSurfaceSize(const Size(1440, 2000));

    await tester.pumpWidget(
      _buildHarness(
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<UserAdminService>.value(value: service),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(service.loadUsersCalled, isTrue);
    expect(find.text('Ava Learner'), findsOneWidget);

    await tester.tap(find.text('Ava Learner'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Edit').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'Ava Innovator');
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();

    expect(service.lastUpdatedUserId, 'user-1');
    expect(service.lastUpdatedDisplayName, 'Ava Innovator');
    expect(find.text('Profile updated for Ava Innovator'), findsOneWidget);
  });

  testWidgets('hq user admin shows site id when site name is missing',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await firestore.collection('users').doc('user-1').set(<String, dynamic>{
      'email': 'ava@scholesa.test',
      'displayName': 'Ava Learner',
      'role': 'learner',
      'status': 'active',
      'siteIds': <String>['site-1'],
      'createdAt': DateTime(2026, 1, 1).millisecondsSinceEpoch,
    });
    await firestore.collection('sites').doc('site-1').set(<String, dynamic>{
      'location': 'Studio A',
      'createdAt': DateTime(2026, 1, 1).millisecondsSinceEpoch,
    });

    final UserAdminService service = UserAdminService(
      firestoreService: FirestoreService(
        firestore: firestore,
        auth: _MockFirebaseAuth(),
      ),
    );

    await tester.binding.setSurfaceSize(const Size(1440, 2000));
    await tester.pumpWidget(
      _buildHarness(
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<UserAdminService>.value(value: service),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sites'));
    await tester.pumpAndSettle();

    expect(find.text('site-1'), findsOneWidget);
    expect(find.text('Unknown Site'), findsNothing);
  });
}