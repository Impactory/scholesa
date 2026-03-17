import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../auth/app_state.dart';
import 'firestore_service.dart';

/// Bootstraps the app session after Firebase init using Firestore directly
class SessionBootstrap {
  SessionBootstrap({
    required FirebaseAuth auth,
    required FirestoreService firestoreService,
    required AppState appState,
  })  : _auth = auth,
        _firestoreService = firestoreService,
        _appState = appState;
  final FirebaseAuth _auth;
  final FirestoreService _firestoreService;
  final AppState _appState;
  static const Duration _profileBootstrapTimeout = Duration(seconds: 8);

  /// Initialize session - call after Firebase.initializeApp()
  Future<void> initialize() async {
    _appState.setLoading(true);

    // Check if user is already signed in
    final User? user = _auth.currentUser;
    if (user == null) {
      _appState.setLoading(false);
      return;
    }

    try {
      // Fetch user profile directly from Firestore
      final Map<String, dynamic>? profile =
          await _firestoreService
              .getUserProfile()
              .timeout(_profileBootstrapTimeout);
      if (profile == null) {
        throw StateError('User profile does not exist');
      }
      _appState.updateFromMeResponse(profile);
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
    _appState.clear();
    _appState.setError('Failed to load user profile');
  }

  /// Listen to auth state changes and bootstrap/clear accordingly
  void listenToAuthChanges() {
    _auth.authStateChanges().listen((User? user) async {
      if (user == null) {
        _appState.clear();
      } else {
        await initialize();
      }
    });
  }
}
