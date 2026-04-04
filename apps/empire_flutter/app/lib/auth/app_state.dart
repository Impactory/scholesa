import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// User roles in the Scholesa platform
enum UserRole {
  learner,
  educator,
  parent,
  site,
  partner,
  hq,
}

/// Extension to get role from string
extension UserRoleExtension on UserRole {
  String get value => name;

  /// Get display name for the role
  String get displayName {
    switch (this) {
      case UserRole.learner:
        return 'Learner';
      case UserRole.educator:
        return 'Educator';
      case UserRole.parent:
        return 'Parent';
      case UserRole.site:
        return 'Site Admin';
      case UserRole.partner:
        return 'Partner';
      case UserRole.hq:
        return 'HQ Admin';
    }
  }

  /// Alias for displayName for compatibility
  String get label => displayName;

  static UserRole fromString(String value) {
    final String normalized = value.trim().toLowerCase();
    switch (normalized) {
      case 'student':
      case 'learner':
        return UserRole.learner;
      case 'teacher':
      case 'educator':
        return UserRole.educator;
      case 'guardian':
      case 'parent':
        return UserRole.parent;
      case 'sitelead':
      case 'site_lead':
      case 'site':
        return UserRole.site;
      case 'partner':
        return UserRole.partner;
      case 'hq':
      case 'admin':
        return UserRole.hq;
      default:
        return UserRole.values.firstWhere(
          (UserRole role) => role.name == normalized.toLowerCase(),
          orElse: () => UserRole.learner,
        );
    }
  }
}

/// Entitlement grants for feature gating
class Entitlement extends Equatable {
  const Entitlement({
    required this.id,
    required this.feature,
    this.expiresAt,
  });
  final String id;
  final String feature;
  final DateTime? expiresAt;

  bool get isActive => expiresAt == null || expiresAt!.isAfter(DateTime.now());

  @override
  List<Object?> get props => <Object?>[id, feature, expiresAt];
}

/// Global application state holding session info
class AppState extends ChangeNotifier {
  String? _userId;
  String? _email;
  String? _displayName;
  UserRole? _role;
  String? _activeSiteId;
  String? _stageId;
  List<String> _siteIds = <String>[];
  List<Entitlement> _entitlements = <Entitlement>[];
  String _preferredLocaleCode = 'en';
  String _timeZone = 'auto';
  bool _notificationsEnabled = true;
  bool _emailNotifications = true;
  bool _pushNotifications = true;
  bool _biometricEnabled = false;
  bool _isLoading = true;
  String? _error;

  /// Role impersonation for HQ users
  UserRole? _impersonatingRole;

  // Getters
  String? get userId => _userId;
  String? get email => _email;
  String? get displayName => _displayName;

  /// Returns the effective role (impersonating role if set, otherwise actual role)
  UserRole? get role => _impersonatingRole ?? _role;

  /// Returns the actual role (ignoring impersonation)
  UserRole? get actualRole => _role;

  /// Returns the role being impersonated, if any
  UserRole? get impersonatingRole => _impersonatingRole;

  /// Returns true if currently impersonating another role
  bool get isImpersonating => _impersonatingRole != null;

  String? get activeSiteId => _activeSiteId;
  /// Learner's learning stage (discoverers/builders/explorers/innovators)
  String? get stageId => _stageId;
  List<String> get siteIds => List<String>.unmodifiable(_siteIds);
  List<Entitlement> get entitlements =>
      List<Entitlement>.unmodifiable(_entitlements);
  String get preferredLocaleCode => _preferredLocaleCode;
  Locale get preferredLocale {
    switch (_preferredLocaleCode) {
      case 'zh-CN':
        return const Locale('zh', 'CN');
      case 'zh-TW':
        return const Locale('zh', 'TW');
      default:
        return const Locale('en');
    }
  }
  String get timeZone => _timeZone;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get emailNotifications => _emailNotifications;
  bool get pushNotifications => _pushNotifications;
  bool get biometricEnabled => _biometricEnabled;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _userId != null;

  /// Check if user is HQ (can impersonate)
  bool get canImpersonate => _role == UserRole.hq;

  /// Check if user has a specific entitlement
  bool hasEntitlement(String feature) {
    return _entitlements
        .any((Entitlement e) => e.feature == feature && e.isActive);
  }

  /// Update state from /v1/me response
  void updateFromMeResponse(Map<String, dynamic> data) {
    _userId = data['userId'] as String?;
    _email = data['email'] as String?;
    _displayName = data['displayName'] as String?;
    _role = data['role'] != null
        ? UserRoleExtension.fromString(data['role'] as String)
        : null;
    _activeSiteId = data['activeSiteId'] as String?;
    _stageId = data['stageId'] as String?;
    _siteIds =
        List<String>.from(data['siteIds'] as List<dynamic>? ?? <dynamic>[]);
    _preferredLocaleCode = _canonicalLocaleCode(data['localeCode'] as String?);
    _timeZone = (data['timeZone'] as String?) ?? 'auto';
    _notificationsEnabled = data['notificationsEnabled'] as bool? ?? true;
    _emailNotifications = data['emailNotifications'] as bool? ?? true;
    _pushNotifications = data['pushNotifications'] as bool? ?? true;
    _biometricEnabled = data['biometricEnabled'] as bool? ?? false;

    final List<dynamic> entitlementsData =
        data['entitlements'] as List<dynamic>? ?? <dynamic>[];
    _entitlements = <Entitlement>[];
    for (final dynamic e in entitlementsData) {
      try {
        if (e is Map<String, dynamic>) {
          final String? id = e['id'] as String?;
          final String? feature = e['feature'] as String?;
          if (id != null && feature != null) {
            _entitlements.add(Entitlement(
              id: id,
              feature: feature,
              expiresAt: e['expiresAt'] != null
                  ? DateTime.fromMillisecondsSinceEpoch(e['expiresAt'] as int)
                  : null,
            ));
          }
        }
      } catch (ex) {
        debugPrint('Failed to parse entitlement: $e, error: $ex');
        // Skip malformed entitlements instead of crashing
      }
    }

    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  /// Switch active site
  void switchSite(String siteId) {
    if (_siteIds.contains(siteId)) {
      _activeSiteId = siteId;
      notifyListeners();
    }
  }

  /// Set loading state
  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Set error state
  void setError(String? error) {
    _error = error;
    _isLoading = false;
    notifyListeners();
  }

  /// Clear error state
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Clear state on logout
  void clear() {
    _userId = null;
    _email = null;
    _displayName = null;
    _role = null;
    _activeSiteId = null;
    _stageId = null;
    _siteIds = <String>[];
    _entitlements = <Entitlement>[];
    _preferredLocaleCode = 'en';
    _timeZone = 'auto';
    _notificationsEnabled = true;
    _emailNotifications = true;
    _pushNotifications = true;
    _biometricEnabled = false;
    _isLoading = false;
    _error = null;
    _impersonatingRole = null;
    notifyListeners();
  }

  /// Set impersonation role (HQ only)
  void setImpersonation(UserRole targetRole) {
    if (_role == UserRole.hq && targetRole != UserRole.hq) {
      _impersonatingRole = targetRole;
      notifyListeners();
    }
  }

  /// Clear impersonation and return to HQ view
  void clearImpersonation() {
    _impersonatingRole = null;
    notifyListeners();
  }

  String _canonicalLocaleCode(String? rawLocale) {
    final String normalized = (rawLocale ?? '').trim();
    switch (normalized) {
      case 'zh':
      case 'zh-CN':
      case 'zh-Hans':
        return 'zh-CN';
      case 'zh-TW':
      case 'zh-Hant':
        return 'zh-TW';
      default:
        return 'en';
    }
  }
}
