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
  _FakeUserAdminService({
    List<UserModel>? users,
    List<SiteModel>? sites,
    List<AuditLogEntry>? auditLogs,
    String? error,
    bool hasLoadedAuditLogs = true,
    bool isLoadingAuditLogs = false,
    String? auditLogError,
    this.onLoadUsers,
    this.onLoadAuditLogs,
  })  : _fakeAuditLogs =
            List<AuditLogEntry>.from(auditLogs ?? const <AuditLogEntry>[]),
        _fakeUsers = List<UserModel>.from(
          users ??
              <UserModel>[
                UserModel(
                  uid: 'user-1',
                  email: 'ava@scholesa.test',
                  displayName: 'Ava Learner',
                  role: UserRole.learner,
                  status: UserStatus.active,
                  siteIds: const <String>['site-1'],
                  createdAt: DateTime(2026, 1, 1),
                ),
              ],
        ),
        _fakeSites = List<SiteModel>.from(sites ?? const <SiteModel>[]),
        _error = error,
        _hasLoadedAuditLogs = hasLoadedAuditLogs,
        _isLoadingAuditLogs = isLoadingAuditLogs,
        _auditLogError = auditLogError,
        super(
          firestoreService: FirestoreService(
            firestore: FakeFirebaseFirestore(),
            auth: _MockFirebaseAuth(),
          ),
        );

  bool loadUsersCalled = false;
  String? lastUpdatedUserId;
  String? lastUpdatedDisplayName;
  int loadAuditLogsCallCount = 0;
  final Future<void> Function(_FakeUserAdminService service)? onLoadUsers;
  final Future<void> Function(_FakeUserAdminService service)? onLoadAuditLogs;

  final List<UserModel> _fakeUsers;
  final List<SiteModel> _fakeSites;
  final List<AuditLogEntry> _fakeAuditLogs;
  String? _error;
  String? _auditLogError;
  bool _hasLoadedAuditLogs;
  bool _isLoadingAuditLogs;

  @override
  List<UserModel> get users => List<UserModel>.unmodifiable(_fakeUsers);

  @override
  List<SiteModel> get sites => List<SiteModel>.unmodifiable(_fakeSites);

  @override
  String? get error => _error;

  @override
  List<AuditLogEntry> get auditLogs => List<AuditLogEntry>.unmodifiable(_fakeAuditLogs);

  @override
  String? get auditLogError => _auditLogError;

  @override
  bool get hasLoadedAuditLogs => _hasLoadedAuditLogs;

  @override
  bool get isLoadingAuditLogs => _isLoadingAuditLogs;

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
    if (onLoadUsers != null) {
      await onLoadUsers!(this);
    }
  }

  @override
  Future<void> loadAuditLogs({String? userId}) async {
    loadAuditLogsCallCount += 1;
    if (onLoadAuditLogs != null) {
      await onLoadAuditLogs!(this);
    }
  }

  @override
  Future<bool> updateUserDisplayName(String userId, String displayName) async {
    lastUpdatedUserId = userId;
    lastUpdatedDisplayName = displayName;
    _fakeUsers[0] = _fakeUsers[0].copyWith(displayName: displayName);
    notifyListeners();
    return true;
  }

  void setLoadState({
    String? error,
    List<UserModel>? users,
    List<SiteModel>? sites,
  }) {
    _error = error;
    if (users != null) {
      _fakeUsers
        ..clear()
        ..addAll(users);
    }
    if (sites != null) {
      _fakeSites
        ..clear()
        ..addAll(sites);
    }
    notifyListeners();
  }

  void setAuditLogState({
    String? auditLogError,
    List<AuditLogEntry>? auditLogs,
    bool? hasLoadedAuditLogs,
    bool? isLoadingAuditLogs,
  }) {
    _auditLogError = auditLogError;
    if (auditLogs != null) {
      _fakeAuditLogs
        ..clear()
        ..addAll(auditLogs);
    }
    if (hasLoadedAuditLogs != null) {
      _hasLoadedAuditLogs = hasLoadedAuditLogs;
    }
    if (isLoadingAuditLogs != null) {
      _isLoadingAuditLogs = isLoadingAuditLogs;
    }
    notifyListeners();
  }
}

Widget _buildHarness({required List<SingleChildWidget> providers}) {
  return MultiProvider(
    providers: providers,
    child: MaterialApp(
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

    expect(find.bySemanticsLabel('Account menu'), findsOneWidget);
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

  testWidgets('hq user admin shows honest unavailable name label when display name is missing',
      (WidgetTester tester) async {
    final _FakeUserAdminService service = _FakeUserAdminService(
      users: <UserModel>[
        UserModel(
          uid: 'user-1',
          email: 'ava@scholesa.test',
          role: UserRole.learner,
          status: UserStatus.active,
          siteIds: const <String>['site-1'],
          createdAt: DateTime(2026, 1, 1),
        ),
      ],
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

    expect(find.text('Name unavailable'), findsOneWidget);
    expect(find.text('No Name'), findsNothing);
  });

  testWidgets('hq user admin audit log shows honest unavailable labels for missing action and actor',
      (WidgetTester tester) async {
    final _FakeUserAdminService service = _FakeUserAdminService(
      auditLogs: <AuditLogEntry>[
        AuditLogEntry(
          id: 'audit-1',
          actorId: 'actor-1',
          action: 'audit_action_unavailable',
          entityType: 'user',
          entityId: 'user-1',
          timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
      ],
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

    await tester.tap(find.text('Audit Log'));
    await tester.pumpAndSettle();

    expect(find.text('Audit action unavailable'), findsOneWidget);
    expect(find.text('by Actor unavailable'), findsOneWidget);
    expect(find.text('Unknown'), findsNothing);
    expect(find.text('by null'), findsNothing);
  });

  testWidgets('hq user admin audit log shows honest empty state after empty load completes',
      (WidgetTester tester) async {
    final _FakeUserAdminService service = _FakeUserAdminService(
      auditLogs: const <AuditLogEntry>[],
      hasLoadedAuditLogs: true,
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

    await tester.tap(find.text('Audit Log'));
    await tester.pumpAndSettle();

    expect(find.text('No audit logs found'), findsOneWidget);
    expect(
      find.text(
        'Audit activity will appear here after user administration actions are recorded.',
      ),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('hq user admin audit log keeps spinner while audit logs are loading',
      (WidgetTester tester) async {
    final _FakeUserAdminService service = _FakeUserAdminService(
      auditLogs: const <AuditLogEntry>[],
      hasLoadedAuditLogs: false,
      isLoadingAuditLogs: true,
    );

    await tester.binding.setSurfaceSize(const Size(1440, 2000));
    await tester.pumpWidget(
      _buildHarness(
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<UserAdminService>.value(value: service),
        ],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Audit Log'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('No audit logs found'), findsNothing);
  });

  testWidgets('hq user admin audit log shows honest error state after load failure',
      (WidgetTester tester) async {
    final _FakeUserAdminService service = _FakeUserAdminService(
      auditLogs: const <AuditLogEntry>[],
      hasLoadedAuditLogs: true,
      auditLogError: 'Unable to load audit logs right now',
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

    await tester.tap(find.text('Audit Log'));
    await tester.pumpAndSettle();

    expect(find.text('Unable to load audit logs right now'), findsOneWidget);
    expect(
      find.text(
        'Try again in a moment or refresh after your connection stabilizes.',
      ),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('hq user admin audit log keeps stale entries visible after refresh failure',
      (WidgetTester tester) async {
    final _FakeUserAdminService service = _FakeUserAdminService(
      auditLogs: <AuditLogEntry>[
        AuditLogEntry(
          id: 'audit-1',
          actorId: 'hq-1',
          actorEmail: 'hq@scholesa.test',
          action: 'user.updated',
          entityType: 'user',
          entityId: 'user-1',
          timestamp: DateTime(2026, 3, 20),
        ),
      ],
      hasLoadedAuditLogs: true,
      onLoadAuditLogs: (_FakeUserAdminService current) async {
        current.setAuditLogState(
          auditLogError: 'Unable to load audit logs right now',
        );
      },
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

    await tester.tap(find.text('Audit Log'));
    await tester.pumpAndSettle();

    expect(find.text('Updated'), findsOneWidget);

    await service.loadAuditLogs();
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        'Unable to refresh audit logs right now. Showing the last successful data.',
      ),
      findsOneWidget,
    );
    expect(find.text('Updated'), findsOneWidget);
  });

  testWidgets('hq user admin users tab shows explicit unavailable state on failed load',
      (WidgetTester tester) async {
    final _FakeUserAdminService service = _FakeUserAdminService(
      users: const <UserModel>[],
      error: 'Unable to load users right now',
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

    expect(find.text('Users are temporarily unavailable'), findsOneWidget);
    expect(
      find.text('We could not load users right now. Retry to check the current state.'),
      findsOneWidget,
    );
    expect(find.text('No users found'), findsNothing);
  });

  testWidgets('hq user admin users tab keeps stale users visible after refresh failure',
      (WidgetTester tester) async {
    final _FakeUserAdminService service = _FakeUserAdminService(
      onLoadUsers: (_FakeUserAdminService current) async {
        current.setLoadState(error: 'Unable to load users right now');
      },
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

    expect(find.text('Ava Learner'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();

    expect(
      find.text('Unable to refresh users right now. Showing the last successful data.'),
      findsOneWidget,
    );
    expect(find.text('Ava Learner'), findsOneWidget);
    expect(find.text('No users found'), findsNothing);
  });

  testWidgets('hq user admin sites tab shows explicit unavailable state on failed load',
      (WidgetTester tester) async {
    final _FakeUserAdminService service = _FakeUserAdminService(
      sites: const <SiteModel>[],
      error: 'Unable to load sites right now',
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

    expect(find.text('Sites are temporarily unavailable'), findsOneWidget);
    expect(
      find.text('We could not load sites right now. Retry to check the current state.'),
      findsOneWidget,
    );
    expect(find.text('No sites available'), findsNothing);
  });

  testWidgets('hq user admin sites tab keeps stale sites visible after refresh failure',
      (WidgetTester tester) async {
    final _FakeUserAdminService service = _FakeUserAdminService(
      sites: <SiteModel>[
        SiteModel(
          id: 'site-1',
          name: 'Studio One',
          createdAt: DateTime(2026, 1, 1),
          location: 'Cape Town',
        ),
      ],
      onLoadUsers: (_FakeUserAdminService current) async {
        current.setLoadState(error: 'Unable to load sites right now');
      },
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

    expect(find.text('Studio One'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();

    expect(
      find.text('Unable to refresh sites right now. Showing the last successful data.'),
      findsOneWidget,
    );
    expect(find.text('Studio One'), findsOneWidget);
    expect(find.text('No sites available'), findsNothing);
  });
}
