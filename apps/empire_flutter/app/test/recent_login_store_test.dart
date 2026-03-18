import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:scholesa_app/auth/recent_login_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockUser extends Mock implements User {}

class _MockUserInfo extends Mock implements UserInfo {}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  _MockUser buildUser({
    required String uid,
    required String email,
    required String displayName,
    required String providerId,
  }) {
    final _MockUser user = _MockUser();
    final _MockUserInfo providerInfo = _MockUserInfo();
    when(() => user.uid).thenReturn(uid);
    when(() => user.email).thenReturn(email);
    when(() => user.displayName).thenReturn(displayName);
    when(() => user.providerData).thenReturn(<UserInfo>[providerInfo]);
    when(() => providerInfo.providerId).thenReturn(providerId);
    return user;
  }

  group('RecentLoginStore', () {
    test('clearActiveSession keeps remembered accounts for shared devices',
        () async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final RecentLoginStore store =
          RecentLoginStore(sharedPreferences: prefs);

      await store.rememberSession(
        profile: <String, dynamic>{
          'userId': 'parent-1',
          'email': 'family@example.com',
          'displayName': 'Family Account',
        },
        firebaseUser: buildUser(
          uid: 'parent-1',
          email: 'family@example.com',
          displayName: 'Family Account',
          providerId: 'password',
        ),
      );
      await store.rememberSession(
        profile: <String, dynamic>{
          'userId': 'parent-2',
          'email': 'guardian@example.com',
          'displayName': 'Guardian Account',
        },
        firebaseUser: buildUser(
          uid: 'parent-2',
          email: 'guardian@example.com',
          displayName: 'Guardian Account',
          providerId: 'google.com',
        ),
      );

      expect(store.activeUserId, 'parent-2');
      expect(store.recentAccounts, hasLength(2));

      await store.clearActiveSession();

      expect(store.activeUserId, isNull);
      expect(store.recentAccounts.map((RecentLoginAccount account) => account.userId), <String>[
        'parent-2',
        'parent-1',
      ]);
      expect(
        prefs.getString('scholesa.auth.active_user_id.v1'),
        isNull,
      );
    });

    test('initialize clears a stale active user marker', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'scholesa.auth.recent_accounts.v1': jsonEncode(<Map<String, dynamic>>[
          <String, dynamic>{
            'userId': 'parent-1',
            'email': 'family@example.com',
            'displayName': 'Family Account',
            'provider': 'email',
            'lastUsedAt': DateTime(2026, 3, 17, 9).toIso8601String(),
          },
        ]),
        'scholesa.auth.active_user_id.v1': 'missing-parent',
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final RecentLoginStore store =
          RecentLoginStore(sharedPreferences: prefs);

      await store.initialize();

      expect(store.activeUserId, isNull);
      expect(store.recentAccounts, hasLength(1));
      expect(
        prefs.getString('scholesa.auth.active_user_id.v1'),
        isNull,
      );
    });
  });
}
