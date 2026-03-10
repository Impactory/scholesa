import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/services/firestore_service.dart';
import 'package:scholesa_app/services/session_bootstrap.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

class MockFirestoreService extends Mock implements FirestoreService {}

void main() {
  late MockFirebaseAuth mockAuth;
  late MockFirestoreService mockFirestore;
  late MockUser mockUser;
  late AppState appState;
  late SessionBootstrap sessionBootstrap;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockFirestore = MockFirestoreService();
    mockUser = MockUser();
    appState = AppState();
    sessionBootstrap = SessionBootstrap(
      auth: mockAuth,
      firestoreService: mockFirestore,
      appState: appState,
    );

    when(() => mockAuth.currentUser).thenReturn(mockUser);
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
    });

    test('recovers with fallback profile when profile is missing', () async {
      when(() => mockFirestore.getUserProfile()).thenAnswer((_) async => null);
      when(() => mockFirestore.buildBootstrapFallbackProfile(mockUser))
          .thenAnswer(
        (_) async => <String, dynamic>{
          'userId': 'uid-123',
          'email': 'test@example.com',
          'displayName': 'Test User',
          'role': 'learner',
          'activeSiteId': null,
          'siteIds': <String>[],
          'entitlements': <dynamic>[],
        },
      );

      await sessionBootstrap.initialize();

      expect(appState.isAuthenticated, isTrue);
      expect(appState.role, UserRole.learner);
      expect(appState.error, isNull);
      verifyNever(() => mockAuth.signOut());
      verify(() => mockFirestore.buildBootstrapFallbackProfile(mockUser))
          .called(1);
    });
  });
}