import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum RecentLoginProvider {
  email,
  google,
  microsoft,
  unknown,
}

class RecentLoginAccount extends Equatable {
  const RecentLoginAccount({
    required this.userId,
    required this.email,
    required this.displayName,
    required this.provider,
    required this.lastUsedAt,
  });

  factory RecentLoginAccount.fromJson(Map<String, dynamic> json) {
    return RecentLoginAccount(
      userId: json['userId'] as String? ?? '',
      email: json['email'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      provider: RecentLoginProvider.values.firstWhere(
        (RecentLoginProvider provider) => provider.name == json['provider'],
        orElse: () => RecentLoginProvider.unknown,
      ),
      lastUsedAt: DateTime.tryParse(json['lastUsedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  final String userId;
  final String email;
  final String displayName;
  final RecentLoginProvider provider;
  final DateTime lastUsedAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'userId': userId,
      'email': email,
      'displayName': displayName,
      'provider': provider.name,
      'lastUsedAt': lastUsedAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => <Object?>[
        userId,
        email,
        displayName,
        provider,
        lastUsedAt,
      ];
}

class RecentLoginStore extends ChangeNotifier {
  RecentLoginStore({SharedPreferences? sharedPreferences})
      : _sharedPreferences = sharedPreferences;

  static const String _recentAccountsKey =
      'scholesa.auth.recent_accounts.v1';
  static const String _activeUserIdKey = 'scholesa.auth.active_user_id.v1';
  static const int _maxRecentAccounts = 6;

  final SharedPreferences? _sharedPreferences;

  SharedPreferences? _prefs;
  bool _isInitialized = false;
  List<RecentLoginAccount> _recentAccounts = const <RecentLoginAccount>[];
  String? _activeUserId;

  bool get isInitialized => _isInitialized;
  String? get activeUserId => _activeUserId;
  List<RecentLoginAccount> get recentAccounts =>
      List<RecentLoginAccount>.unmodifiable(_recentAccounts);

  Future<void> initialize() async {
    final SharedPreferences prefs = await _ensurePrefs();
    _recentAccounts = _readAccounts(prefs);
    _activeUserId = _normalizedOrNull(prefs.getString(_activeUserIdKey));
    if (_activeUserId != null &&
        !_recentAccounts.any(
          (RecentLoginAccount account) => account.userId == _activeUserId,
        )) {
      _activeUserId = null;
      await prefs.remove(_activeUserIdKey);
    }
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> rememberSession({
    required Map<String, dynamic> profile,
    required User firebaseUser,
  }) async {
    final SharedPreferences prefs = await _ensurePrefs();
    final String userId = (profile['userId'] as String? ?? firebaseUser.uid).trim();
    final String email =
        ((profile['email'] as String?) ?? firebaseUser.email ?? '').trim();
    if (userId.isEmpty || email.isEmpty) {
      return;
    }

    final String displayName =
        ((profile['displayName'] as String?) ?? firebaseUser.displayName ?? email)
            .trim();
    final RecentLoginAccount nextAccount = RecentLoginAccount(
      userId: userId,
      email: email,
      displayName: displayName.isEmpty ? email : displayName,
      provider: _providerFromFirebaseUser(firebaseUser),
      lastUsedAt: DateTime.now(),
    );

    final List<RecentLoginAccount> updated = <RecentLoginAccount>[
      nextAccount,
      ..._recentAccounts.where((RecentLoginAccount account) =>
          account.userId != nextAccount.userId &&
          account.email.toLowerCase() != nextAccount.email.toLowerCase()),
    ];

    _recentAccounts = updated.take(_maxRecentAccounts).toList(growable: false);
    _activeUserId = nextAccount.userId;
    await _persist(prefs);
  }

  Future<void> clearActiveSession() async {
    final SharedPreferences prefs = await _ensurePrefs();
    _activeUserId = null;
    await prefs.remove(_activeUserIdKey);
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> forgetAccount(String userId) async {
    final SharedPreferences prefs = await _ensurePrefs();
    _recentAccounts = _recentAccounts
        .where((RecentLoginAccount account) => account.userId != userId)
        .toList(growable: false);
    if (_activeUserId == userId) {
      _activeUserId = null;
      await prefs.remove(_activeUserIdKey);
    }
    await prefs.setString(_recentAccountsKey, jsonEncode(
      _recentAccounts
          .map((RecentLoginAccount account) => account.toJson())
          .toList(growable: false),
    ));
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _persist(SharedPreferences prefs) async {
    await prefs.setString(
      _recentAccountsKey,
      jsonEncode(
        _recentAccounts
            .map((RecentLoginAccount account) => account.toJson())
            .toList(growable: false),
      ),
    );
    if (_activeUserId == null) {
      await prefs.remove(_activeUserIdKey);
    } else {
      await prefs.setString(_activeUserIdKey, _activeUserId!);
    }
    _isInitialized = true;
    notifyListeners();
  }

  Future<SharedPreferences> _ensurePrefs() async {
    final SharedPreferences prefs = _prefs ?? _sharedPreferences ??
        await SharedPreferences.getInstance();
    _prefs = prefs;
    return prefs;
  }

  List<RecentLoginAccount> _readAccounts(SharedPreferences prefs) {
    final String? raw = prefs.getString(_recentAccountsKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <RecentLoginAccount>[];
    }
    try {
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map>()
          .map(
            (Map entry) => RecentLoginAccount.fromJson(
              Map<String, dynamic>.from(entry),
            ),
          )
          .where((RecentLoginAccount account) =>
              account.userId.trim().isNotEmpty && account.email.trim().isNotEmpty)
          .toList(growable: false);
    } catch (e) {
      debugPrint('Failed to decode recent login accounts: $e');
      return const <RecentLoginAccount>[];
    }
  }

  RecentLoginProvider _providerFromFirebaseUser(User user) {
    for (final UserInfo info in user.providerData) {
      switch (info.providerId) {
        case 'password':
          return RecentLoginProvider.email;
        case 'google.com':
          return RecentLoginProvider.google;
        case 'microsoft.com':
          return RecentLoginProvider.microsoft;
      }
    }
    return RecentLoginProvider.unknown;
  }

  String? _normalizedOrNull(String? value) {
    if (value == null) {
      return null;
    }
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
