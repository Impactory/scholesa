import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:scholesa_app/main.dart';
import 'package:scholesa_app/auth/app_state.dart';

void main() {
  group('AppState', () {
    test('initial state is correct', () {
      final AppState appState = AppState();
      
      expect(appState.userId, isNull);
      expect(appState.role, isNull);
      expect(appState.isAuthenticated, isFalse);
      expect(appState.isLoading, isTrue);
      expect(appState.siteIds, isEmpty);
      expect(appState.entitlements, isEmpty);
    });

    test('updateFromMeResponse sets state correctly', () {
      final AppState appState = AppState();
      
      appState.updateFromMeResponse(<String, dynamic>{
        'userId': 'user123',
        'email': 'test@example.com',
        'displayName': 'Test User',
        'role': 'educator',
        'activeSiteId': 'site1',
        'siteIds': <String>['site1', 'site2'],
        'entitlements': <Map<String, String>>[
          <String, String>{'id': 'ent1', 'feature': 'premium'},
        ],
      });

      expect(appState.userId, equals('user123'));
      expect(appState.email, equals('test@example.com'));
      expect(appState.displayName, equals('Test User'));
      expect(appState.role, equals(UserRole.educator));
      expect(appState.activeSiteId, equals('site1'));
      expect(appState.siteIds, equals(<String>['site1', 'site2']));
      expect(appState.isAuthenticated, isTrue);
      expect(appState.isLoading, isFalse);
      expect(appState.hasEntitlement('premium'), isTrue);
      expect(appState.hasEntitlement('other'), isFalse);
    });

    test('clear resets state', () {
      final AppState appState = AppState();
      
      appState.updateFromMeResponse(<String, dynamic>{
        'userId': 'user123',
        'email': 'test@example.com',
        'displayName': 'Test User',
        'role': 'educator',
        'activeSiteId': 'site1',
        'siteIds': <String>['site1'],
        'entitlements': <dynamic>[],
      });

      appState.clear();

      expect(appState.userId, isNull);
      expect(appState.isAuthenticated, isFalse);
      expect(appState.isLoading, isFalse);
    });

    test('switchSite only allows valid sites', () {
      final AppState appState = AppState();
      
      appState.updateFromMeResponse(<String, dynamic>{
        'userId': 'user123',
        'email': 'test@example.com',
        'displayName': 'Test User',
        'role': 'site',
        'activeSiteId': 'site1',
        'siteIds': <String>['site1', 'site2'],
        'entitlements': <dynamic>[],
      });

      appState.switchSite('site2');
      expect(appState.activeSiteId, equals('site2'));

      appState.switchSite('site3'); // Invalid
      expect(appState.activeSiteId, equals('site2')); // Unchanged
    });
  });

  group('UserRole', () {
    test('fromString parses all roles', () {
      expect(UserRoleExtension.fromString('learner'), equals(UserRole.learner));
      expect(UserRoleExtension.fromString('educator'), equals(UserRole.educator));
      expect(UserRoleExtension.fromString('parent'), equals(UserRole.parent));
      expect(UserRoleExtension.fromString('site'), equals(UserRole.site));
      expect(UserRoleExtension.fromString('partner'), equals(UserRole.partner));
      expect(UserRoleExtension.fromString('hq'), equals(UserRole.hq));
    });

    test('fromString defaults to learner for unknown', () {
      expect(UserRoleExtension.fromString('unknown'), equals(UserRole.learner));
    });
  });
}
