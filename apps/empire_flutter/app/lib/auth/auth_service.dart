import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../services/firestore_service.dart';
import 'app_state.dart';

/// Service for handling Firebase authentication
class AuthService {

  AuthService({
    required FirebaseAuth auth,
    required FirestoreService firestoreService,
    required AppState appState,
  })  : _auth = auth,
        _firestoreService = firestoreService,
        _appState = appState;
  final FirebaseAuth _auth;
  final FirestoreService _firestoreService;
  final AppState _appState;

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

  /// Register with email and password
  Future<void> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      _appState.setLoading(true);
      final UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await credential.user?.updateDisplayName(displayName);
      // Create user profile in Firestore
      await _firestoreService.createUserProfile(displayName: displayName);
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
    await _auth.signOut();
    _appState.clear();
  }

  /// Bootstrap session by fetching user profile from Firestore
  Future<void> _bootstrapSession() async {
    try {
      final Map<String, dynamic>? profile = await _firestoreService.getUserProfile();
      if (profile != null) {
        _appState.updateFromMeResponse(profile);
      }
    } catch (e) {
      debugPrint('Failed to bootstrap session: $e');
      _appState.setError('Failed to load user profile');
      rethrow;
    }
  }

  /// Refresh session (fetch profile from Firestore again)
  Future<void> refreshSession() async {
    if (currentUser == null) return;
    await _bootstrapSession();
  }

  /// Map Firebase auth error codes to user-friendly messages
  String _mapAuthError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email';
      case 'wrong-password':
        return 'Incorrect password';
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
      default:
        return 'Authentication failed';
    }
  }
}
