import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';
import 'role_routes.dart';

class AppState extends ChangeNotifier {
  AppState({AuthServiceBase? authService}) : _authService = authService ?? AuthService();

  final AuthServiceBase _authService;
  User? _user;
  String? _role;
  Set<String> _entitlements = const {'learner'};
  List<String> _siteIds = const <String>[];
  String? _primarySiteId;
  String? _savedPreferredSite;
  bool _persistedSiteLoaded = false;

  User? get user => _user;
  String? get role => _role;
  bool get isAuthenticated => _user != null;
  Set<String> get entitlements => _entitlements;
  List<String> get siteIds => _siteIds;
  String? get primarySiteId => _primarySiteId;

  void setUser(User? user) {
    _user = user;
    if (user != null) {
      _loadPreferredSiteFor(user.uid);
    } else {
      _savedPreferredSite = null;
      _persistedSiteLoaded = false;
    }
    notifyListeners();
  }

  void setRole(String role) {
    _role = normalizeRole(role);
    notifyListeners();
  }

  void clearRole() {
    _role = null;
    notifyListeners();
  }

  void clearAuth() {
    _user = null;
    _role = null;
    _entitlements = const {'learner'};
    _siteIds = const <String>[];
    _primarySiteId = null;
    _savedPreferredSite = null;
    _persistedSiteLoaded = false;
    notifyListeners();
  }

  Future<void> refreshEntitlements() async {
    final result = await _authService.loadEntitlements();
    final normalizedRoles = result.roles.isNotEmpty
        ? result.roles.map(normalizeRole).toSet()
        : const {'learner'};
    _entitlements = normalizedRoles;
    _siteIds = result.siteIds;
    final preferredFromClaims = result.primarySiteId ?? (_siteIds.isNotEmpty ? _siteIds.first : null);
    final preferredPersisted = _persistedSiteLoaded &&
            _savedPreferredSite != null &&
            _siteIds.contains(_savedPreferredSite!)
        ? _savedPreferredSite
        : null;
    _primarySiteId = preferredPersisted ?? preferredFromClaims;
    notifyListeners();
  }

  Future<void> setPrimarySite(String? siteId) async {
    if (siteId == _primarySiteId) return;
    _primarySiteId = siteId;
    _savedPreferredSite = siteId;
    notifyListeners();

    final uid = _user?.uid;
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    if (siteId == null || siteId.isEmpty) {
      await prefs.remove('primarySite:$uid');
      return;
    }
    await prefs.setString('primarySite:$uid', siteId);
  }

  Future<void> _loadPreferredSiteFor(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('primarySite:$uid');
    _savedPreferredSite = saved;
    _persistedSiteLoaded = true;
    if (saved != null && saved.isNotEmpty && saved != _primarySiteId) {
      _primarySiteId = saved;
      notifyListeners();
    }
  }
}
