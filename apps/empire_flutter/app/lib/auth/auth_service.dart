import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/firestore_service.dart';
import '../services/logout_audit_service.dart';
import '../services/telemetry_service.dart';
import 'app_state.dart';
import 'recent_login_store.dart';

const String _defaultGoogleServerClientId = String.fromEnvironment(
  'GOOGLE_SIGN_IN_SERVER_CLIENT_ID',
);

const String _googleAppleClientId =
    String.fromEnvironment('GOOGLE_SIGN_IN_CLIENT_ID', defaultValue: '');

/// Service for handling Firebase authentication
class AuthService {
  AuthService({
    required FirebaseAuth auth,
    required FirestoreService firestoreService,
    required AppState appState,
    GoogleSignIn? googleSignIn,
    String? googleClientId,
    String? googleServerClientId,
    TargetPlatform? googleSignInPlatformOverride,
    LogoutAuditService? logoutAuditService,
    RecentLoginStore? recentLoginStore,
    Duration logoutSideEffectTimeout = const Duration(seconds: 2),
  })  : _auth = auth,
        _firestoreService = firestoreService,
        _appState = appState,
        _googleSignIn = googleSignIn ?? GoogleSignIn.instance,
        _googleClientId = googleClientId,
        _googleServerClientId = googleServerClientId,
        _googleSignInPlatformOverride = googleSignInPlatformOverride,
        _logoutAuditService = logoutAuditService ?? LogoutAuditService.instance,
        _recentLoginStore = recentLoginStore ?? RecentLoginStore(),
        _logoutSideEffectTimeout = logoutSideEffectTimeout;
  final FirebaseAuth _auth;
  final FirestoreService _firestoreService;
  final AppState _appState;
  final GoogleSignIn _googleSignIn;
  final String? _googleClientId;
  final String? _googleServerClientId;
  final TargetPlatform? _googleSignInPlatformOverride;
  final LogoutAuditService _logoutAuditService;
  final RecentLoginStore _recentLoginStore;
  final Duration _logoutSideEffectTimeout;
  Future<void>? _googleInitialization;

  Future<void> _ensureGoogleInitialized() {
    return _googleInitialization ??= _initializeGoogleSignIn();
  }

  Future<void> _initializeGoogleSignIn() {
    final String? configuredServerClientId = _normalizedOrNull(
      _googleServerClientId ?? _defaultGoogleServerClientId,
    );

    if (!_requiresAppleGoogleClientId()) {
      return _googleSignIn.initialize(
        serverClientId: configuredServerClientId,
      );
    }

    final String? configuredClientId =
        _normalizedOrNull(_googleClientId ?? _googleAppleClientId);
    if (configuredClientId == null) {
      throw StateError(
        'Google Sign-In is not configured for Apple platforms. Add GOOGLE_SIGN_IN_CLIENT_ID via --dart-define or restore CLIENT_ID in the Apple GoogleService-Info.plist.',
      );
    }

    return _googleSignIn.initialize(
      clientId: configuredClientId,
      serverClientId: configuredServerClientId,
    );
  }

  bool _requiresAppleGoogleClientId() {
    if (kIsWeb) {
      return false;
    }
    final TargetPlatform platform =
        _googleSignInPlatformOverride ?? defaultTargetPlatform;
    return platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
  }

  String? _normalizedOrNull(String? value) {
    if (value == null) {
      return null;
    }
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
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
      _appState.clearError();
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _bootstrapSession();
    } on FirebaseAuthException catch (e) {
      _appState.setError(_mapAuthError(e.code));
      rethrow;
    } catch (e) {
      debugPrint('Email sign-in error: $e');
      if ((_appState.error ?? '').isEmpty) {
        _appState.setError('An unexpected error occurred');
      }
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut({String source = 'unknown'}) async {
    final String? roleName = _appState.role?.name;
    final String? activeSiteId = _normalizedOrNull(_appState.activeSiteId);
    final String? impersonatingRole = _appState.impersonatingRole?.name;
    unawaited(_signOutFromGoogleBestEffort());
    unawaited(_logLogoutTelemetry(
      source: source,
      roleName: roleName,
      activeSiteId: activeSiteId,
      impersonatingRole: impersonatingRole,
    ));
    unawaited(_recordLogoutAudit(
      source: source,
      roleName: roleName,
      activeSiteId: activeSiteId,
      impersonatingRole: impersonatingRole,
    ));
    await _auth.signOut();
    try {
      await _recentLoginStore.clearActiveSession();
    } catch (_) {
      // Ignore recent-account persistence errors
    }
    _appState.clear();
  }

  Future<void> _signOutFromGoogleBestEffort() async {
    try {
      await _googleSignIn.signOut().timeout(_logoutSideEffectTimeout);
    } catch (_) {
      // Provider cleanup must never block Firebase sign-out or local state clear.
    }
  }

  Future<void> _logLogoutTelemetry({
    required String source,
    required String? roleName,
    required String? activeSiteId,
    required String? impersonatingRole,
  }) async {
    try {
      await TelemetryService.instance.logEvent(
        event: 'auth.logout',
        metadata: <String, dynamic>{
          'source': source,
          if (roleName != null) 'role': roleName,
          if (activeSiteId != null) 'site_id': activeSiteId,
          if (impersonatingRole != null)
            'impersonating_role': impersonatingRole,
        },
      ).timeout(_logoutSideEffectTimeout);
    } catch (_) {
      // Best-effort telemetry must not block the user from signing out.
    }
  }

  Future<void> _recordLogoutAudit({
    required String source,
    required String? roleName,
    required String? activeSiteId,
    required String? impersonatingRole,
  }) async {
    try {
      await _logoutAuditService
          .recordLogout(
            source: source,
            role: roleName,
            siteId: activeSiteId,
            impersonatingRole: impersonatingRole,
          )
          .timeout(_logoutSideEffectTimeout);
    } catch (_) {
      // Best-effort durable audit logging must not block sign-out.
    }
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
        try {
          await _googleSignIn.signOut();
        } catch (_) {
          // Best effort: still continue to the account chooser if no session exists.
        }
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

      // Bootstrap session with the provisioned Firestore profile.
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
    } on StateError catch (e) {
      _appState.setError(e.message);
      rethrow;
    } catch (e) {
      debugPrint('Google sign-in error: $e');
      if ((_appState.error ?? '').isEmpty) {
        _appState.setError('Failed to sign in with Google');
      }
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
      // Use the Firebase project's configured auth handler endpoint.
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

      // Bootstrap session with the provisioned Firestore profile.
      await _bootstrapSession();
    } on FirebaseAuthException catch (e) {
      _appState.setError(_mapAuthError(e.code));
      rethrow;
    } catch (e) {
      debugPrint('Microsoft sign-in error: $e');
      if ((_appState.error ?? '').isEmpty) {
        _appState.setError('Failed to sign in with Microsoft');
      }
      rethrow;
    }
  }

  /// Bootstrap session by fetching user profile from Firestore
  Future<void> _bootstrapSession() async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) {
        throw StateError('Not authenticated');
      }

      final Map<String, dynamic>? profile =
          await _firestoreService.getUserProfile();
      if (profile == null) {
        throw StateError('User profile does not exist');
      }
      _appState.updateFromMeResponse(profile);
      await _recentLoginStore.rememberSession(
        profile: profile,
        firebaseUser: user,
      );
    } catch (e) {
      debugPrint('Error in _bootstrapSession: $e');
      debugPrintStack(label: '_bootstrapSession error stack');
      final User? user = _auth.currentUser;
      if (user != null) {
        try {
          await _auth.signOut();
        } catch (_) {
          // Best effort sign-out only.
        }
      }
      try {
        await _recentLoginStore.clearActiveSession();
      } catch (_) {
        // Best effort recent-account cleanup only.
      }
      _appState.clear();
      _appState.setError('Failed to load user profile');
      rethrow;
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
