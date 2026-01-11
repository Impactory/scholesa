import 'package:flutter/foundation.dart';
import '../../auth/app_state.dart' show UserRole, UserRoleExtension;
import '../../services/api_client.dart';
import 'user_models.dart';

/// Service for HQ user administration
class UserAdminService extends ChangeNotifier {

  UserAdminService({required ApiClient apiClient}) : _apiClient = apiClient;
  final ApiClient _apiClient;

  List<UserModel> _users = <UserModel>[];
  List<SiteModel> _sites = <SiteModel>[];
  List<AuditLogEntry> _auditLogs = <AuditLogEntry>[];
  bool _isLoading = false;
  String? _error;
  
  // Filters
  UserRole? _roleFilter;
  UserStatus? _statusFilter;
  String? _siteFilter;
  String _searchQuery = '';

  // Getters
  List<UserModel> get users => _filteredUsers;
  List<SiteModel> get sites => _sites;
  List<AuditLogEntry> get auditLogs => _auditLogs;
  bool get isLoading => _isLoading;
  String? get error => _error;
  UserRole? get roleFilter => _roleFilter;
  UserStatus? get statusFilter => _statusFilter;
  String? get siteFilter => _siteFilter;
  String get searchQuery => _searchQuery;

  List<UserModel> get _filteredUsers {
    return _users.where((UserModel user) {
      // Role filter
      if (_roleFilter != null && user.role != _roleFilter) return false;
      
      // Status filter
      if (_statusFilter != null && user.status != _statusFilter) return false;
      
      // Site filter
      if (_siteFilter != null && !user.siteIds.contains(_siteFilter)) return false;
      
      // Search query
      if (_searchQuery.isNotEmpty) {
        final String query = _searchQuery.toLowerCase();
        final bool matchesEmail = user.email.toLowerCase().contains(query);
        final bool matchesName = user.displayName?.toLowerCase().contains(query) ?? false;
        if (!matchesEmail && !matchesName) return false;
      }
      
      return true;
    }).toList();
  }

  // Stats
  int get totalUsers => _users.length;
  int get activeUsers => _users.where((UserModel u) => u.status == UserStatus.active).length;
  int get suspendedUsers => _users.where((UserModel u) => u.status == UserStatus.suspended).length;
  int get learnerCount => _users.where((UserModel u) => u.role == UserRole.learner).length;
  int get educatorCount => _users.where((UserModel u) => u.role == UserRole.educator).length;

  // Filter setters
  void setRoleFilter(UserRole? role) {
    _roleFilter = role;
    notifyListeners();
  }

  void setStatusFilter(UserStatus? status) {
    _statusFilter = status;
    notifyListeners();
  }

  void setSiteFilter(String? siteId) {
    _siteFilter = siteId;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void clearFilters() {
    _roleFilter = null;
    _statusFilter = null;
    _siteFilter = null;
    _searchQuery = '';
    notifyListeners();
  }

  /// Load all users (HQ only)
  Future<void> loadUsers() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // TODO: Replace with real API call
      // final response = await _apiClient.get('/v1/admin/users');
      // _users = (response['users'] as List).map((u) => UserModel.fromJson(u)).toList();
      
      // Mock data for development
      await Future.delayed(const Duration(milliseconds: 500));
      _users = _generateMockUsers();
      _sites = _generateMockSites();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load audit logs
  Future<void> loadAuditLogs({String? userId}) async {
    try {
      // TODO: Replace with real API call
      await Future.delayed(const Duration(milliseconds: 300));
      _auditLogs = _generateMockAuditLogs(userId: userId);
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load audit logs: $e');
    }
  }

  /// Create a new user
  Future<UserModel?> createUser({
    required String email,
    required String displayName,
    required UserRole role,
    required List<String> siteIds,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      // TODO: Replace with real API call
      // final response = await _apiClient.post('/v1/admin/users', body: {...});
      
      await Future.delayed(const Duration(milliseconds: 500));
      
      final UserModel newUser = UserModel(
        uid: 'user_${DateTime.now().millisecondsSinceEpoch}',
        email: email,
        displayName: displayName,
        role: role,
        status: UserStatus.pending,
        siteIds: siteIds,
        createdAt: DateTime.now(),
      );
      
      _users = <UserModel>[..._users, newUser];
      notifyListeners();
      return newUser;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update user role
  Future<bool> updateUserRole(String userId, UserRole newRole) async {
    try {
      // TODO: Replace with real API call
      await Future.delayed(const Duration(milliseconds: 300));
      
      final int index = _users.indexWhere((UserModel u) => u.uid == userId);
      if (index != -1) {
        _users[index] = _users[index].copyWith(
          role: newRole,
          updatedAt: DateTime.now(),
        );
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Update user status (suspend/reactivate)
  Future<bool> updateUserStatus(String userId, UserStatus newStatus) async {
    try {
      // TODO: Replace with real API call
      await Future.delayed(const Duration(milliseconds: 300));
      
      final int index = _users.indexWhere((UserModel u) => u.uid == userId);
      if (index != -1) {
        _users[index] = _users[index].copyWith(
          status: newStatus,
          updatedAt: DateTime.now(),
        );
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Add user to site
  Future<bool> addUserToSite(String userId, String siteId) async {
    try {
      final int index = _users.indexWhere((UserModel u) => u.uid == userId);
      if (index != -1) {
        final UserModel user = _users[index];
        if (!user.siteIds.contains(siteId)) {
          _users[index] = user.copyWith(
            siteIds: <String>[...user.siteIds, siteId],
            updatedAt: DateTime.now(),
          );
          notifyListeners();
        }
        return true;
      }
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Remove user from site
  Future<bool> removeUserFromSite(String userId, String siteId) async {
    try {
      final int index = _users.indexWhere((UserModel u) => u.uid == userId);
      if (index != -1) {
        final UserModel user = _users[index];
        _users[index] = user.copyWith(
          siteIds: user.siteIds.where((String s) => s != siteId).toList(),
          updatedAt: DateTime.now(),
        );
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Delete user (deactivate)
  Future<bool> deleteUser(String userId) async {
    return updateUserStatus(userId, UserStatus.deactivated);
  }

  // Mock data generators
  List<UserModel> _generateMockUsers() {
    return <UserModel>[
      UserModel(
        uid: 'hq_001',
        email: 'admin@scholesa.com',
        displayName: 'Super Admin',
        role: UserRole.hq,
        siteIds: const <String>['site_001', 'site_002', 'site_003'],
        createdAt: DateTime.now().subtract(const Duration(days: 365)),
        lastLoginAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      UserModel(
        uid: 'edu_001',
        email: 'maria.johnson@scholesa.com',
        displayName: 'Maria Johnson',
        role: UserRole.educator,
        siteIds: const <String>['site_001'],
        createdAt: DateTime.now().subtract(const Duration(days: 180)),
        lastLoginAt: DateTime.now().subtract(const Duration(hours: 5)),
      ),
      UserModel(
        uid: 'edu_002',
        email: 'james.wilson@scholesa.com',
        displayName: 'James Wilson',
        role: UserRole.educator,
        siteIds: const <String>['site_001', 'site_002'],
        createdAt: DateTime.now().subtract(const Duration(days: 120)),
        lastLoginAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      UserModel(
        uid: 'site_001',
        email: 'site.manager@downtown.com',
        displayName: 'Downtown Site Manager',
        role: UserRole.site,
        siteIds: const <String>['site_001'],
        createdAt: DateTime.now().subtract(const Duration(days: 200)),
        lastLoginAt: DateTime.now().subtract(const Duration(hours: 8)),
      ),
      UserModel(
        uid: 'learner_001',
        email: 'alex.student@email.com',
        displayName: 'Alex Chen',
        role: UserRole.learner,
        siteIds: const <String>['site_001'],
        parentIds: const <String>['parent_001'],
        createdAt: DateTime.now().subtract(const Duration(days: 90)),
        lastLoginAt: DateTime.now().subtract(const Duration(hours: 12)),
      ),
      UserModel(
        uid: 'learner_002',
        email: 'emma.student@email.com',
        displayName: 'Emma Rodriguez',
        role: UserRole.learner,
        siteIds: const <String>['site_001'],
        parentIds: const <String>['parent_002'],
        createdAt: DateTime.now().subtract(const Duration(days: 85)),
        lastLoginAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      UserModel(
        uid: 'learner_003',
        email: 'noah.student@email.com',
        displayName: 'Noah Williams',
        role: UserRole.learner,
        status: UserStatus.suspended,
        siteIds: const <String>['site_002'],
        createdAt: DateTime.now().subtract(const Duration(days: 60)),
      ),
      UserModel(
        uid: 'parent_001',
        email: 'chen.parent@email.com',
        displayName: 'Wei Chen',
        role: UserRole.parent,
        siteIds: const <String>['site_001'],
        createdAt: DateTime.now().subtract(const Duration(days: 90)),
        lastLoginAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
      UserModel(
        uid: 'parent_002',
        email: 'rodriguez.parent@email.com',
        displayName: 'Sofia Rodriguez',
        role: UserRole.parent,
        siteIds: const <String>['site_001'],
        createdAt: DateTime.now().subtract(const Duration(days: 85)),
        lastLoginAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      UserModel(
        uid: 'partner_001',
        email: 'content@partner.com',
        displayName: 'Learning Partners Inc',
        role: UserRole.partner,
        siteIds: const <String>[],
        organizationId: 'org_partners',
        createdAt: DateTime.now().subtract(const Duration(days: 150)),
      ),
    ];
  }

  List<SiteModel> _generateMockSites() {
    return <SiteModel>[
      SiteModel(
        id: 'site_001',
        name: 'Downtown Learning Studio',
        location: '123 Main St, Downtown',
        siteLeadIds: const <String>['site_001'],
        createdAt: DateTime.now().subtract(const Duration(days: 400)),
        userCount: 45,
        learnerCount: 32,
      ),
      SiteModel(
        id: 'site_002',
        name: 'Uptown Academy',
        location: '456 Oak Ave, Uptown',
        siteLeadIds: const <String>[],
        createdAt: DateTime.now().subtract(const Duration(days: 300)),
        userCount: 28,
        learnerCount: 20,
      ),
      SiteModel(
        id: 'site_003',
        name: 'Riverside Campus',
        location: '789 River Rd',
        siteLeadIds: const <String>[],
        createdAt: DateTime.now().subtract(const Duration(days: 100)),
        userCount: 15,
        learnerCount: 10,
      ),
    ];
  }

  List<AuditLogEntry> _generateMockAuditLogs({String? userId}) {
    final List<AuditLogEntry> logs = <AuditLogEntry>[
      AuditLogEntry(
        id: 'log_001',
        actorId: 'hq_001',
        actorEmail: 'admin@scholesa.com',
        action: 'user.role_updated',
        entityType: 'User',
        entityId: 'edu_001',
        siteId: 'site_001',
        details: const <String, dynamic>{'oldRole': 'learner', 'newRole': 'educator'},
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      AuditLogEntry(
        id: 'log_002',
        actorId: 'hq_001',
        actorEmail: 'admin@scholesa.com',
        action: 'user.suspended',
        entityType: 'User',
        entityId: 'learner_003',
        siteId: 'site_002',
        details: const <String, dynamic>{'reason': 'Policy violation'},
        timestamp: DateTime.now().subtract(const Duration(hours: 5)),
      ),
      AuditLogEntry(
        id: 'log_003',
        actorId: 'hq_001',
        actorEmail: 'admin@scholesa.com',
        action: 'user.created',
        entityType: 'User',
        entityId: 'learner_002',
        siteId: 'site_001',
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
      ),
      AuditLogEntry(
        id: 'log_004',
        actorId: 'site_001',
        actorEmail: 'site.manager@downtown.com',
        action: 'user.site_added',
        entityType: 'User',
        entityId: 'edu_002',
        siteId: 'site_002',
        timestamp: DateTime.now().subtract(const Duration(days: 2)),
      ),
    ];

    if (userId != null) {
      return logs.where((AuditLogEntry l) => l.entityId == userId).toList();
    }
    return logs;
  }
}
