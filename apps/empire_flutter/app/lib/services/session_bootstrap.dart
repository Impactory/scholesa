import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../auth/app_state.dart';
import 'api_client.dart';

/// Bootstraps the app session after Firebase init
class SessionBootstrap {

  SessionBootstrap({
    required FirebaseAuth auth,
    required ApiClient apiClient,
    required AppState appState,
  })  : _auth = auth,
        _apiClient = apiClient,
        _appState = appState;
  final FirebaseAuth _auth;
  final ApiClient _apiClient;
  final AppState _appState;

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
      // Fetch user profile from API
      final Map<String, dynamic> response = await _apiClient.get('/v1/me');
      _appState.updateFromMeResponse(response);
    } catch (e) {
      debugPrint('Session bootstrap failed: $e');
      // Clear any stale auth state if API fails
      if (e is ApiException && e.statusCode == 401) {
        await _auth.signOut();
        _appState.clear();
      } else {
        _appState.setError('Failed to load profile. Please try again.');
      }
    }
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
