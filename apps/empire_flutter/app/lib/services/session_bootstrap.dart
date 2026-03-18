import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../auth/app_state.dart';
import '../auth/recent_login_store.dart';
import 'firestore_service.dart';

/// Bootstraps the app session after Firebase init using Firestore directly
class SessionBootstrap {
  SessionBootstrap({
    required FirebaseAuth auth,
    required FirestoreService firestoreService,
    required AppState appState,
    required RecentLoginStore recentLoginStore,
  })  : _auth = auth,
        _firestoreService = firestoreService,
        _appState = appState,
        _recentLoginStore = recentLoginStore;
  final FirebaseAuth _auth;
  final FirestoreService _firestoreService;
  final AppState _appState;
  final RecentLoginStore _recentLoginStore;
  static const Duration _profileBootstrapTimeout = Duration(seconds: 8);

  /// Initialize session - call after Firebase.initializeApp()
  Future<void> initialize() async {
    _appState.setLoading(true);

    // Check if user is already signed in
    final User? user = _auth.currentUser;
    if (user == null) {
      await _clearSignedOutSessionState();
      return;
    }

    try {
      // Fetch user profile directly from Firestore
      final Map<String, dynamic>? profile = await _firestoreService
          .getUserProfile()
          .timeout(_profileBootstrapTimeout);
      if (profile == null) {
        throw StateError('User profile does not exist');
      }
      _appState.updateFromMeResponse(profile);
      await _recentLoginStore.rememberSession(
        profile: profile,
        firebaseUser: user,
      );
    } on TimeoutException {
      debugPrint('Session bootstrap timed out while loading profile');
      await _failBootstrap();
    } catch (e) {
      debugPrint('Session bootstrap failed: $e');
      await _failBootstrap();
    } finally {
      _appState.setLoading(false);
    }
  }

  Future<void> _failBootstrap() async {
    try {
      await _auth.signOut();
    } catch (_) {
      // Best effort sign-out only.
    }
    await _clearSignedOutSessionState();
    _appState.setError('Failed to load user profile');
  }

  Future<void> _clearSignedOutSessionState() async {
    try {
      await _recentLoginStore.clearActiveSession();
    } catch (_) {
      // Best effort recent-account cleanup only.
    }
    _appState.clear();
  }

  /// Listen to auth state changes and bootstrap/clear accordingly
  void listenToAuthChanges() {
    _auth.authStateChanges().listen((User? user) async {
      if (user == null) {
        await _clearSignedOutSessionState();
      } else {
        await initialize();
      }
    });
  }
}
