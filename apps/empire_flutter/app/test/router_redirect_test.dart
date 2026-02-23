import 'package:flutter_test/flutter_test.dart';
import 'package:scholesa_app/auth/app_state.dart';

/// Tests for the auth redirect logic defined in app_router.dart.
///
/// The redirect rules (from router/app_router.dart L101-125):
///   1. If loading AND on public route → stay (return null)
///   2. If loading AND NOT on public route → redirect to /welcome
///   3. If NOT logged in AND NOT on public route → redirect to /welcome
///   4. If logged in AND on public route → redirect to / (dashboard)
///   5. Otherwise → stay (return null)
///
/// Public routes: /welcome, /login, /register
///
/// We test the AppState transitions that drive these redirect decisions.
void main() {
  group('Router redirect logic', () {
    // ── AppState drives redirect decisions ─────────────────
    test('fresh AppState: isLoading=true, isAuthenticated=false', () {
      final AppState state = AppState();

      // During loading: unauthenticated users on public routes stay put
      expect(state.isLoading, isTrue);
      expect(state.isAuthenticated, isFalse);

      // Redirect logic: isLoading && isPublicRoute → null (stay)
      expect(_redirectResult(state, isPublicRoute: true), isNull);

      // Redirect logic: isLoading && !isPublicRoute → /welcome
      expect(_redirectResult(state, isPublicRoute: false), '/welcome');
    });

    test('after updateFromMeResponse: isAuthenticated=true, isLoading=false',
        () {
      final AppState state = AppState();
      state.updateFromMeResponse(<String, dynamic>{
        'userId': 'uid-1',
        'email': 'test@scholesa.com',
        'displayName': 'Test User',
        'role': 'educator',
        'activeSiteId': 'site1',
        'siteIds': <String>['site1'],
        'entitlements': <dynamic>[],
      });

      expect(state.isAuthenticated, isTrue);
      expect(state.isLoading, isFalse);

      // Authenticated user on public route → redirect to dashboard
      expect(_redirectResult(state, isPublicRoute: true), '/');

      // Authenticated user on protected route → stay
      expect(_redirectResult(state, isPublicRoute: false), isNull);
    });

    test('after clear: isAuthenticated=false, isLoading=false', () {
      final AppState state = AppState();
      state.updateFromMeResponse(<String, dynamic>{
        'userId': 'uid-1',
        'email': 'test@scholesa.com',
        'displayName': 'Test User',
        'role': 'learner',
        'activeSiteId': 'site1',
        'siteIds': <String>['site1'],
        'entitlements': <dynamic>[],
      });
      state.clear();

      expect(state.isAuthenticated, isFalse);
      expect(state.isLoading, isFalse);

      // Unauthenticated on protected route → redirect to /welcome
      expect(_redirectResult(state, isPublicRoute: false), '/welcome');

      // Unauthenticated on public route → stay
      expect(_redirectResult(state, isPublicRoute: true), isNull);
    });

    test('role-to-dashboard mapping: all 6 roles authenticate', () {
      for (final UserRole role in UserRole.values) {
        final AppState state = AppState();
        state.updateFromMeResponse(<String, dynamic>{
          'userId': 'uid-${role.name}',
          'email': '${role.name}@scholesa.com',
          'displayName': '${role.name} user',
          'role': role.name,
          'activeSiteId': 'site1',
          'siteIds': <String>['site1'],
          'entitlements': <dynamic>[],
        });

        expect(state.isAuthenticated, isTrue,
            reason: '${role.name} should be authenticated');
        expect(state.role, role);
      }
    });

    test('setLoading toggles loading state for redirect', () {
      final AppState state = AppState();
      expect(state.isLoading, isTrue); // Default

      state.setLoading(false);
      expect(state.isLoading, isFalse);

      // Not loading, not authenticated, protected route → /welcome
      expect(_redirectResult(state, isPublicRoute: false), '/welcome');

      // Not loading, not authenticated, public route → stay
      expect(_redirectResult(state, isPublicRoute: true), isNull);
    });
  });
}

/// Simulates the redirect logic from app_router.dart L101-125 using AppState
String? _redirectResult(AppState appState, {required bool isPublicRoute}) {
  final bool isLoading = appState.isLoading;
  final bool isLoggedIn = appState.isAuthenticated;

  if (isLoading && isPublicRoute) return null;
  if (isLoading && !isPublicRoute) return '/welcome';
  if (!isLoggedIn && !isPublicRoute) return '/welcome';
  if (isLoggedIn && isPublicRoute) return '/';
  return null;
}
