import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/firestore_service.dart';
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
        _googleSignIn = googleSignIn ?? GoogleSignIn(
          scopes: <String>['email', 'profile'],
        );
  final FirebaseAuth _auth;
  final FirestoreService _firestoreService;
  final AppState _appState;
  final GoogleSignIn _googleSignIn;

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
    // Sign out from Google if signed in with Google
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Ignore if not signed in with Google
    }
    await _auth.signOut();
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
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        
        if (googleUser == null) {
          // User cancelled the sign-in
          _appState.setLoading(false);
          return;
        }

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final OAuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        await _auth.signInWithCredential(credential);
      }
      
      // Ensure user profile exists in Firestore
      final User? user = _auth.currentUser;
      if (user != null) {
        final Map<String, dynamic>? existingProfile = await _firestoreService.getUserProfile();
        if (existingProfile == null) {
          // Create profile for new SSO user
          await _firestoreService.createUserProfile(
            displayName: user.displayName ?? user.email?.split('@').first ?? 'User',
          );
        }
      }
      
      await _bootstrapSession();
    } on FirebaseAuthException catch (e) {
      _appState.setError(_mapAuthError(e.code));
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
        'tenant': 'common', // Allow any Microsoft account (personal or work/school)
      });

      if (kIsWeb) {
        await _auth.signInWithPopup(microsoftProvider);
      } else {
        await _auth.signInWithProvider(microsoftProvider);
      }
      
      // Ensure user profile exists in Firestore
      final User? user = _auth.currentUser;
      if (user != null) {
        final Map<String, dynamic>? existingProfile = await _firestoreService.getUserProfile();
        if (existingProfile == null) {
          await _firestoreService.createUserProfile(
            displayName: user.displayName ?? user.email?.split('@').first ?? 'User',
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
