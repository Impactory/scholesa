import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/auth/recent_login_store.dart';
import 'package:scholesa_app/services/firestore_service.dart';
import 'package:scholesa_app/services/session_bootstrap.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

class MockFirestoreService extends Mock implements FirestoreService {}

class FakeRecentLoginStore extends Fake implements RecentLoginStore {
  RecentLoginAccount? rememberedAccount;
  bool clearedActiveSession = false;
  bool throwOnClear = false;

  @override
  Future<void> rememberSession({
    required Map<String, dynamic> profile,
    required User firebaseUser,
  }) async {
    rememberedAccount = RecentLoginAccount(
      userId: profile['userId'] as String,
      email: profile['email'] as String,
      displayName: profile['displayName'] as String,
      provider: RecentLoginProvider.email,
      lastUsedAt: DateTime(2026, 3, 17),
    );
  }

  @override
  Future<void> clearActiveSession() async {
    if (throwOnClear) {
      throw StateError('prefs unavailable');
    }
    clearedActiveSession = true;
  }
}

void main() {
  late MockFirebaseAuth mockAuth;
  late MockFirestoreService mockFirestore;
  late MockUser mockUser;
  late AppState appState;
  late SessionBootstrap sessionBootstrap;
  late FakeRecentLoginStore recentLoginStore;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockFirestore = MockFirestoreService();
    mockUser = MockUser();
    appState = AppState();
    recentLoginStore = FakeRecentLoginStore();
    sessionBootstrap = SessionBootstrap(
      auth: mockAuth,
      firestoreService: mockFirestore,
      appState: appState,
      recentLoginStore: recentLoginStore,
    );

    when(() => mockAuth.currentUser).thenReturn(mockUser);
    when(() => mockAuth.signOut()).thenAnswer((_) async {});
    when(() => mockUser.uid).thenReturn('uid-123');
    when(() => mockUser.email).thenReturn('test@example.com');
    when(() => mockUser.displayName).thenReturn('Test User');
    when(() => mockAuth.authStateChanges())
        .thenAnswer((_) => const Stream<User?>.empty());
  });

  group('SessionBootstrap', () {
    test('hydrates app state when profile exists', () async {
      when(() => mockFirestore.getUserProfile()).thenAnswer(
        (_) async => <String, dynamic>{
          'userId': 'uid-123',
          'email': 'test@example.com',
          'displayName': 'Test User',
          'role': 'site',
          'activeSiteId': 'site1',
          'siteIds': <String>['site1'],
          'entitlements': <dynamic>[],
        },
      );

      await sessionBootstrap.initialize();

      expect(appState.isAuthenticated, isTrue);
      expect(appState.role, UserRole.site);
      expect(appState.activeSiteId, 'site1');
      expect(appState.error, isNull);
      expect(recentLoginStore.rememberedAccount?.email, 'test@example.com');
    });

    test('signs out and surfaces profile error when profile is missing', () async {
      when(() => mockFirestore.getUserProfile()).thenAnswer((_) async => null);

      await sessionBootstrap.initialize();

      expect(appState.isAuthenticated, isFalse);
      expect(appState.role, isNull);
      expect(appState.error, 'Failed to load user profile');
      expect(recentLoginStore.clearedActiveSession, isTrue);
      verify(() => mockAuth.signOut()).called(1);
    });

    test('clears stale recent active session when Firebase has no current user',
        () async {
      appState.updateFromMeResponse(<String, dynamic>{
        'userId': 'stale-user',
        'email': 'stale@example.com',
        'displayName': 'Stale User',
        'role': 'site',
        'activeSiteId': 'site-1',
        'siteIds': <String>['site-1'],
        'entitlements': <dynamic>[],
      });
      when(() => mockAuth.currentUser).thenReturn(null);

      await sessionBootstrap.initialize();

      expect(recentLoginStore.clearedActiveSession, isTrue);
      expect(appState.isAuthenticated, isFalse);
      expect(appState.error, isNull);
    });

    test('still clears app state when recent-session cleanup throws on startup',
        () async {
      appState.updateFromMeResponse(<String, dynamic>{
        'userId': 'stale-user',
        'email': 'stale@example.com',
        'displayName': 'Stale User',
        'role': 'site',
        'activeSiteId': 'site-1',
        'siteIds': <String>['site-1'],
        'entitlements': <dynamic>[],
      });
      recentLoginStore.throwOnClear = true;
      when(() => mockAuth.currentUser).thenReturn(null);

      await sessionBootstrap.initialize();

      expect(appState.isAuthenticated, isFalse);
      expect(appState.error, isNull);
    });

    test('auth-state sign-out event clears app state even if recent-session cleanup fails',
        () async {
      final StreamController<User?> authController =
          StreamController<User?>();
      addTearDown(authController.close);
      when(() => mockAuth.authStateChanges())
          .thenAnswer((_) => authController.stream);
      recentLoginStore.throwOnClear = true;
      appState.updateFromMeResponse(<String, dynamic>{
        'userId': 'uid-123',
        'email': 'test@example.com',
        'displayName': 'Test User',
        'role': 'site',
        'activeSiteId': 'site-1',
        'siteIds': <String>['site-1'],
        'entitlements': <dynamic>[],
      });

      sessionBootstrap.listenToAuthChanges();
      authController.add(null);
      await Future<void>.delayed(Duration.zero);

      expect(appState.isAuthenticated, isFalse);
      expect(appState.error, isNull);
    });
  });
}
