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
  });
}