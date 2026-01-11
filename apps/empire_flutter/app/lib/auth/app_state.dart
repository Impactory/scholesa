import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

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
    return UserRole.values.firstWhere(
      (UserRole role) => role.name == value,
      orElse: () => UserRole.learner,
    );
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

  bool get isActive =>
      expiresAt == null || expiresAt!.isAfter(DateTime.now());

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
  List<String> _siteIds = <String>[];
  List<Entitlement> _entitlements = <Entitlement>[];
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
  List<String> get siteIds => List<String>.unmodifiable(_siteIds);
  List<Entitlement> get entitlements => List<Entitlement>.unmodifiable(_entitlements);
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _userId != null;
  
  /// Check if user is HQ (can impersonate)
  bool get canImpersonate => _role == UserRole.hq;

  /// Check if user has a specific entitlement
  bool hasEntitlement(String feature) {
    return _entitlements.any((Entitlement e) => e.feature == feature && e.isActive);
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
    _siteIds = List<String>.from(data['siteIds'] as List<dynamic>? ?? <dynamic>[]);
    
    final List<dynamic> entitlementsData = data['entitlements'] as List<dynamic>? ?? <dynamic>[];
    _entitlements = entitlementsData.map<Entitlement>((dynamic e) {
      final Map<String, dynamic> item = e as Map<String, dynamic>;
      return Entitlement(
        id: item['id'] as String,
        feature: item['feature'] as String,
        expiresAt: item['expiresAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(item['expiresAt'] as int)
            : null,
      );
    }).toList();
    
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
    _siteIds = <String>[];
    _entitlements = <Entitlement>[];
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
}
