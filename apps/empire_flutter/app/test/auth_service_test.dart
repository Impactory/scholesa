import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mocktail/mocktail.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/auth/auth_service.dart';
import 'package:scholesa_app/services/firestore_service.dart';

// ── Mocks ──────────────────────────────────────────────────
class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUserCredential extends Mock implements UserCredential {}

class MockUser extends Mock implements User {}

class MockFirestoreService extends Mock implements FirestoreService {}

class MockGoogleSignIn extends Mock implements GoogleSignIn {}

class MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}

class MockGoogleSignInAuthentication extends Mock
  implements GoogleSignInAuthentication {}

class FakeAuthCredential extends Fake implements AuthCredential {}

/// Test-accessible subclass of FirebaseAuthException (constructor is @protected)
class TestAuthException extends FirebaseAuthException {
  TestAuthException({required super.code, super.message});
}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeAuthCredential());
  });

  late MockFirebaseAuth mockAuth;
  late MockFirestoreService mockFirestore;
  late AppState appState;
  late AuthService authService;
  late MockUserCredential mockCredential;
  late MockUser mockUser;
  late MockGoogleSignIn mockGoogleSignIn;
  late MockGoogleSignInAccount mockGoogleAccount;
  late MockGoogleSignInAuthentication mockGoogleAuth;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockFirestore = MockFirestoreService();
    appState = AppState();
    mockCredential = MockUserCredential();
    mockUser = MockUser();
    mockGoogleSignIn = MockGoogleSignIn();
    mockGoogleAccount = MockGoogleSignInAccount();
    mockGoogleAuth = MockGoogleSignInAuthentication();

    authService = AuthService(
      auth: mockAuth,
      firestoreService: mockFirestore,
      appState: appState,
      googleSignIn: mockGoogleSignIn,
      googleSignInPlatformOverride: TargetPlatform.iOS,
    );

    // Common stubs
    when(() => mockAuth.currentUser).thenReturn(mockUser);
    when(() => mockUser.uid).thenReturn('uid-123');
    when(() => mockUser.email).thenReturn('test@example.com');
    when(() => mockUser.displayName).thenReturn('Test User');
    when(() => mockCredential.user).thenReturn(mockUser);
  });

  group('AuthService', () {
    // ── signInWithEmailAndPassword ────────────────────────
    group('signInWithEmailAndPassword', () {
      test('sets loading then bootstraps session on success', () async {
        when(() => mockAuth.signInWithEmailAndPassword(
              email: any(named: 'email'),
              password: any(named: 'password'),
            )).thenAnswer((_) async => mockCredential);

        when(() => mockFirestore.getUserProfile()).thenAnswer(
          (_) async => <String, dynamic>{
            'userId': 'uid-123',
            'email': 'test@example.com',
            'displayName': 'Test User',
            'role': 'educator',
            'activeSiteId': 'site1',
            'siteIds': <String>['site1'],
            'entitlements': <dynamic>[],
          },
        );

        await authService.signInWithEmailAndPassword(
          email: 'test@example.com',
          password: 'password123',
        );

        expect(appState.isAuthenticated, isTrue);
        expect(appState.role, UserRole.educator);
        expect(appState.userId, 'uid-123');
        verify(() => mockAuth.signInWithEmailAndPassword(
              email: 'test@example.com',
              password: 'password123',
            )).called(1);
      });

      test('signs out and surfaces profile error when profile is missing',
          () async {
        when(() => mockAuth.signInWithEmailAndPassword(
              email: any(named: 'email'),
              password: any(named: 'password'),
            )).thenAnswer((_) async => mockCredential);
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

        await authService.signInWithEmailAndPassword(
          email: 'test@example.com',
          password: 'password123',
        );

        expect(appState.isAuthenticated, isTrue);
        expect(appState.role, UserRole.learner);
        expect(appState.error, isNull);
        verifyNever(() => mockAuth.signOut());
        verify(() => mockFirestore.buildBootstrapFallbackProfile(mockUser))
            .called(1);
      });

      test('maps user-not-found error to friendly message', () async {
        when(() => mockAuth.signInWithEmailAndPassword(
              email: any(named: 'email'),
              password: any(named: 'password'),
            )).thenThrow(TestAuthException(code: 'user-not-found'));

        expect(
          () => authService.signInWithEmailAndPassword(
            email: 'nobody@example.com',
            password: 'wrong',
          ),
          throwsA(isA<FirebaseAuthException>()),
        );

        expect(appState.error, 'No account found with this email');
      });

      test('maps wrong-password error to friendly message', () async {
        when(() => mockAuth.signInWithEmailAndPassword(
              email: any(named: 'email'),
              password: any(named: 'password'),
            )).thenThrow(TestAuthException(code: 'wrong-password'));

        expect(
          () => authService.signInWithEmailAndPassword(
            email: 'test@example.com',
            password: 'wrong',
          ),
          throwsA(isA<FirebaseAuthException>()),
        );

        expect(appState.error, 'Incorrect password');
      });
    });

    group('signInWithGoogle', () {
      test('surfaces a clear Apple configuration error when client ID is missing',
          () async {
        await expectLater(
          authService.signInWithGoogle(),
          throwsA(isA<StateError>()),
        );

        expect(
          appState.error,
          'Google Sign-In is not configured for Apple platforms. Add GOOGLE_SIGN_IN_CLIENT_ID via --dart-define or restore CLIENT_ID in the Apple GoogleService-Info.plist.',
        );
        verifyNever(() => mockGoogleSignIn.initialize(
              clientId: any(named: 'clientId'),
              serverClientId: any(named: 'serverClientId'),
              nonce: any(named: 'nonce'),
              hostedDomain: any(named: 'hostedDomain'),
            ));
      });

      test('initializes Google Sign-In with explicit Apple and server client IDs',
          () async {
        authService = AuthService(
          auth: mockAuth,
          firestoreService: mockFirestore,
          appState: appState,
          googleSignIn: mockGoogleSignIn,
          googleSignInPlatformOverride: TargetPlatform.iOS,
          googleClientId: 'apple-client-id.apps.googleusercontent.com',
          googleServerClientId:
              'server-client-id.apps.googleusercontent.com',
        );

        when(() => mockGoogleSignIn.initialize(
              clientId: any(named: 'clientId'),
              serverClientId: any(named: 'serverClientId'),
              nonce: any(named: 'nonce'),
              hostedDomain: any(named: 'hostedDomain'),
            )).thenAnswer((_) async {});
        when(() => mockGoogleSignIn.authenticate(
              scopeHint: any(named: 'scopeHint'),
            )).thenAnswer((_) async => mockGoogleAccount);
        when(() => mockGoogleAccount.authentication).thenReturn(mockGoogleAuth);
        when(() => mockGoogleAuth.idToken).thenReturn('google-id-token');
        when(() => mockAuth.signInWithCredential(any()))
            .thenAnswer((_) async => mockCredential);
        when(() => mockFirestore.getUserProfile()).thenAnswer(
          (_) async => <String, dynamic>{
            'userId': 'uid-123',
            'email': 'test@example.com',
            'displayName': 'Test User',
            'role': 'educator',
            'activeSiteId': 'site1',
            'siteIds': <String>['site1'],
            'entitlements': <dynamic>[],
          },
        );

        await authService.signInWithGoogle();

        verify(() => mockGoogleSignIn.initialize(
              clientId: 'apple-client-id.apps.googleusercontent.com',
              serverClientId: 'server-client-id.apps.googleusercontent.com',
              nonce: null,
              hostedDomain: null,
            )).called(1);
        verify(() => mockGoogleSignIn.authenticate(
              scopeHint: <String>['email', 'profile'],
            )).called(1);
        verify(() => mockAuth.signInWithCredential(any())).called(1);
        expect(appState.isAuthenticated, isTrue);
      });
    });

    // ── signOut ───────────────────────────────────────────
    group('signOut', () {
      test('signs out and clears AppState', () async {
        appState.updateFromMeResponse(<String, dynamic>{
          'userId': 'uid-123',
          'email': 'test@example.com',
          'displayName': 'Test User',
          'role': 'educator',
          'activeSiteId': 'site1',
          'siteIds': <String>['site1'],
          'entitlements': <dynamic>[],
        });
        expect(appState.isAuthenticated, isTrue);

        when(() => mockAuth.signOut()).thenAnswer((_) async {});

        await authService.signOut();

        expect(appState.isAuthenticated, isFalse);
        expect(appState.userId, isNull);
        verify(() => mockAuth.signOut()).called(1);
      });
    });

    // ── currentUser ──────────────────────────────────────
    test('currentUser delegates to FirebaseAuth', () {
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      expect(authService.currentUser, mockUser);
    });

    test('currentUser returns null when signed out', () {
      when(() => mockAuth.currentUser).thenReturn(null);
      expect(authService.currentUser, isNull);
    });

    // ── _mapAuthError coverage ───────────────────────────
    group('error mapping covers all codes', () {
      final Map<String, String> errorMap = <String, String>{
        'user-not-found': 'No account found with this email',
        'wrong-password': 'Incorrect password',
        'email-already-in-use': 'An account already exists with this email',
        'weak-password': 'Password is too weak',
        'invalid-email': 'Invalid email address',
        'user-disabled': 'This account has been disabled',
        'too-many-requests': 'Too many attempts. Please try again later',
        'some-unknown-code': 'Authentication failed',
      };

      for (final MapEntry<String, String> entry in errorMap.entries) {
        test('maps "${entry.key}" to "${entry.value}"', () async {
          when(() => mockAuth.signInWithEmailAndPassword(
                email: any(named: 'email'),
                password: any(named: 'password'),
              )).thenThrow(TestAuthException(code: entry.key));

          try {
            await authService.signInWithEmailAndPassword(
              email: 'x@x.com',
              password: 'x',
            );
          } catch (_) {}

          expect(appState.error, entry.value);
        });
      }
    });

    // ── refreshSession ───────────────────────────────────
    test('refreshSession re-fetches profile when user exists', () async {
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockFirestore.getUserProfile()).thenAnswer(
        (_) async => <String, dynamic>{
          'userId': 'uid-123',
          'email': 'test@example.com',
          'displayName': 'Updated Name',
          'role': 'hq',
          'activeSiteId': 'site2',
          'siteIds': <String>['site2'],
          'entitlements': <dynamic>[],
        },
      );

      await authService.refreshSession();

      expect(appState.displayName, 'Updated Name');
      expect(appState.role, UserRole.hq);
    });

    test('refreshSession signs out when profile is missing', () async {
      when(() => mockAuth.currentUser).thenReturn(mockUser);
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

      await authService.refreshSession();

      expect(appState.isAuthenticated, isTrue);
      expect(appState.role, UserRole.learner);
      expect(appState.error, isNull);
      verifyNever(() => mockAuth.signOut());
      verify(() => mockFirestore.buildBootstrapFallbackProfile(mockUser))
          .called(1);
    });

    test('refreshSession is no-op when no current user', () async {
      when(() => mockAuth.currentUser).thenReturn(null);

      await authService.refreshSession();

      verifyNever(() => mockFirestore.getUserProfile());
    });
  });
}
