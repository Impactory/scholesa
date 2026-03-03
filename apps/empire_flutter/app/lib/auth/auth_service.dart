import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/firestore_service.dart';
import '../services/telemetry_service.dart';
import 'app_state.dart';

/// Service for handling Firebase authentication
class AuthService {
  AuthService({
    required FirebaseAuth auth,
    required FirestoreService firestoreService,
    required AppState appState,
    GoogleSignIn? googleSignIn,
  })  : _auth = auth,
        _firestoreService = firestoreService,
        _appState = appState,
        _googleSignIn = googleSignIn ?? GoogleSignIn.instance;
  final FirebaseAuth _auth;
  final FirestoreService _firestoreService;
  final AppState _appState;
  final GoogleSignIn _googleSignIn;
  Future<void>? _googleInitialization;

  Future<void> _ensureGoogleInitialized() {
    return _googleInitialization ??= _googleSignIn.initialize();
  }

  /// Current Firebase user
  User? get currentUser => _auth.currentUser;

  /// Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign in with email and password
  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      _appState.setLoading(true);
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _bootstrapSession();
    } on FirebaseAuthException catch (e) {
      _appState.setError(_mapAuthError(e.code));
      rethrow;
    } catch (e) {
      _appState.setError('An unexpected error occurred');
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    // Sign out from Google if signed in with Google
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Ignore if not signed in with Google
    }
    await _auth.signOut();
    // Clear SharedPreferences (all keys)
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (_) {
      // Ignore errors clearing prefs
    }
    try {
      await TelemetryService.instance.logEvent(event: 'auth.logout');
    } catch (_) {
      // Best-effort telemetry
    }
    _appState.clear();
  }

  /// Sign in with Google
  Future<void> signInWithGoogle() async {
    try {
      _appState.setLoading(true);
      _appState.clearError();

      if (kIsWeb) {
        // Web: Use popup sign-in
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');

        await _auth.signInWithPopup(googleProvider);
      } else {
        // Mobile: Use native Google Sign-In
        await _ensureGoogleInitialized();
        final GoogleSignInAccount googleUser = await _googleSignIn.authenticate(
          scopeHint: <String>['email', 'profile'],
        );

        final GoogleSignInAuthentication googleAuth = googleUser.authentication;
        if (googleAuth.idToken == null) {
          throw FirebaseAuthException(
            code: 'missing-id-token',
            message: 'Google sign-in did not return an ID token',
          );
        }
        final OAuthCredential credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );

        await _auth.signInWithCredential(credential);
      }

      // Ensure user profile exists in Firestore
      final User? user = _auth.currentUser;
      if (user != null) {
        final Map<String, dynamic>? existingProfile =
            await _firestoreService.getUserProfile();
        if (existingProfile == null) {
          // Create profile for new SSO user
          await _firestoreService.createUserProfile(
            displayName:
                user.displayName ?? user.email?.split('@').first ?? 'User',
          );
        }
      }

      await _bootstrapSession();
    } on FirebaseAuthException catch (e) {
      _appState.setError(_mapAuthError(e.code));
      rethrow;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        _appState.setLoading(false);
        return;
      }
      _appState.setError('Failed to sign in with Google');
      rethrow;
    } catch (e) {
      debugPrint('Google sign-in error: $e');
      _appState.setError('Failed to sign in with Google');
      rethrow;
    }
  }

  /// Sign in with Microsoft (via Firebase Auth)
  Future<void> signInWithMicrosoft() async {
    try {
      _appState.setLoading(true);
      _appState.clearError();

      final OAuthProvider microsoftProvider = OAuthProvider('microsoft.com');
      microsoftProvider.addScope('email');
      microsoftProvider.addScope('profile');
      microsoftProvider.addScope('openid');

      // Set custom parameters for Microsoft login
      // Using Firebase auth handler: https://studio-3328096157-e3f79.firebaseapp.com/__/auth/handler
      microsoftProvider.setCustomParameters(<String, String>{
        'prompt': 'select_account',
        'tenant':
            'common', // Allow any Microsoft account (personal or work/school)
      });

      if (kIsWeb) {
        await _auth.signInWithPopup(microsoftProvider);
      } else {
        await _auth.signInWithProvider(microsoftProvider);
      }

      // Ensure user profile exists in Firestore
      final User? user = _auth.currentUser;
      if (user != null) {
        final Map<String, dynamic>? existingProfile =
            await _firestoreService.getUserProfile();
        if (existingProfile == null) {
          await _firestoreService.createUserProfile(
            displayName:
                user.displayName ?? user.email?.split('@').first ?? 'User',
          );
        }
      }

      await _bootstrapSession();
    } on FirebaseAuthException catch (e) {
      _appState.setError(_mapAuthError(e.code));
      rethrow;
    } catch (e) {
      debugPrint('Microsoft sign-in error: $e');
      _appState.setError('Failed to sign in with Microsoft');
      rethrow;
    }
  }

  /// Bootstrap session by fetching user profile from Firestore
  Future<void> _bootstrapSession() async {
    try {
      final Map<String, dynamic>? profile =
          await _firestoreService.getUserProfile();
      if (profile != null) {
        _appState.updateFromMeResponse(profile);
      } else {
        final User? user = _auth.currentUser;
        if (user != null) {
          _appState.updateFromMeResponse(<String, dynamic>{
            'userId': user.uid,
            'email': user.email ?? '',
            'displayName': user.displayName ?? user.email?.split('@')[0] ?? '',
            'role': 'learner',
            'activeSiteId': null,
            'siteIds': <String>[],
            'entitlements': <Map<String, dynamic>>[],
          });
        }
      }
    } catch (e) {
      debugPrint('Failed to bootstrap session: $e');
      final User? user = _auth.currentUser;
      if (user != null) {
        _appState.updateFromMeResponse(<String, dynamic>{
          'userId': user.uid,
          'email': user.email ?? '',
          'displayName': user.displayName ?? user.email?.split('@')[0] ?? '',
          'role': 'learner',
          'activeSiteId': null,
          'siteIds': <String>[],
          'entitlements': <Map<String, dynamic>>[],
        });
      } else {
        _appState.setError('Failed to load user profile');
        rethrow;
      }
    }
  }

  /// Refresh session (fetch profile from Firestore again)
  Future<void> refreshSession() async {
    if (currentUser == null) return;
    await _bootstrapSession();
  }

  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');
    if (user.email == null || user.email!.isEmpty) {
      throw Exception('Password update is not available for this account');
    }

    try {
      final AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      _appState.setError(_mapAuthError(e.code));
      rethrow;
    }
  }

  Future<void> updateEmail({
    required String currentPassword,
    required String newEmail,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');
    if (user.email == null || user.email!.isEmpty) {
      throw Exception('Email update is not available for this account');
    }

    try {
      final AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.verifyBeforeUpdateEmail(newEmail);
      await _firestoreService.updateUserProfile(<String, dynamic>{
        'email': newEmail,
      });
      await refreshSession();
    } on FirebaseAuthException catch (e) {
      _appState.setError(_mapAuthError(e.code));
      rethrow;
    }
  }

  Future<void> updatePhoneNumberInProfile(String phoneNumber) async {
    final User? user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');
    await _firestoreService.updateUserProfile(<String, dynamic>{
      'phoneNumber': phoneNumber,
    });
    await refreshSession();
  }

  Future<void> deleteAccount({String? currentPassword}) async {
    final User? user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    try {
      if (currentPassword != null &&
          currentPassword.isNotEmpty &&
          user.email != null &&
          user.email!.isNotEmpty) {
        final AuthCredential credential = EmailAuthProvider.credential(
          email: user.email!,
          password: currentPassword,
        );
        await user.reauthenticateWithCredential(credential);
      }

      await _firestoreService.deleteCurrentUserProfile();
      await user.delete();
      _appState.clear();
    } on FirebaseAuthException catch (e) {
      _appState.setError(_mapAuthError(e.code));
      rethrow;
    }
  }

  /// Map Firebase auth error codes to user-friendly messages
  String _mapAuthError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return 'Invalid email or password';
      case 'email-already-in-use':
        return 'An account already exists with this email';
      case 'weak-password':
        return 'Password is too weak';
      case 'invalid-email':
        return 'Invalid email address';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later';
      case 'requires-recent-login':
        return 'Please sign in again to continue this action';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled';
      case 'invalid-api-key':
        return 'Authentication is misconfigured. Contact support';
      case 'app-not-authorized':
        return 'This app is not authorized for Firebase Auth';
      default:
        return 'Authentication failed';
    }
  }
}
