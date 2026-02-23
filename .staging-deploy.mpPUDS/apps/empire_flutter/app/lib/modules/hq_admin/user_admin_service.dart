import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../auth/app_state.dart' show UserRole;
import '../../services/firestore_service.dart';
import 'user_models.dart';

/// Service for HQ user administration - wired to Firebase
class UserAdminService extends ChangeNotifier {

  UserAdminService({required FirestoreService firestoreService}) 
      : _firestoreService = firestoreService;
  
  // ignore: unused_field
  final FirestoreService _firestoreService;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

  /// Load all users from Firebase (HQ only)
  Future<void> loadUsers() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Load users from Firebase
      final QuerySnapshot<Map<String, dynamic>> usersSnapshot =
          await _firestore.collection('users').get();
      
      _users = usersSnapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        final Map<String, dynamic> data = doc.data();
        return UserModel(
          uid: doc.id,
          email: data['email'] as String? ?? '',
          displayName: data['displayName'] as String?,
          role: _parseRole(data['role'] as String?),
          status: _parseStatus(data['status'] as String?),
          siteIds: List<String>.from(data['siteIds'] as List<dynamic>? ?? <dynamic>[]),
          parentIds: List<String>.from(data['parentIds'] as List<dynamic>? ?? <dynamic>[]),
          organizationId: data['organizationId'] as String?,
          createdAt: _parseTimestamp(data['createdAt']) ?? DateTime.now(),
          updatedAt: _parseTimestamp(data['updatedAt']),
          lastLoginAt: _parseTimestamp(data['lastLoginAt']),
        );
      }).toList();

      // Load sites from Firebase
      final QuerySnapshot<Map<String, dynamic>> sitesSnapshot =
          await _firestore.collection('sites').get();
      
      _sites = sitesSnapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        final Map<String, dynamic> data = doc.data();
        return SiteModel(
          id: doc.id,
          name: data['name'] as String? ?? 'Unknown Site',
          location: data['location'] as String?,
          siteLeadIds: List<String>.from(data['siteLeadIds'] as List<dynamic>? ?? <dynamic>[]),
          createdAt: _parseTimestamp(data['createdAt']) ?? DateTime.now(),
          userCount: _users.where((UserModel u) => u.siteIds.contains(doc.id)).length,
          learnerCount: _users.where((UserModel u) => 
            u.siteIds.contains(doc.id) && u.role == UserRole.learner
          ).length,
        );
      }).toList();

      debugPrint('Loaded ${_users.length} users and ${_sites.length} sites from Firebase');
    } catch (e) {
      debugPrint('Error loading users from Firebase: $e');
      _error = 'Failed to load users: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Parse role from string
  UserRole _parseRole(String? roleStr) {
    if (roleStr == null) return UserRole.learner;
    switch (roleStr.toLowerCase()) {
      case 'hq':
        return UserRole.hq;
      case 'educator':
        return UserRole.educator;
      case 'site':
        return UserRole.site;
      case 'parent':
        return UserRole.parent;
      case 'partner':
        return UserRole.partner;
      default:
        return UserRole.learner;
    }
  }

  /// Parse status from string
  UserStatus _parseStatus(String? statusStr) {
    if (statusStr == null) return UserStatus.active;
    switch (statusStr.toLowerCase()) {
      case 'suspended':
        return UserStatus.suspended;
      case 'deactivated':
        return UserStatus.deactivated;
      case 'pending':
        return UserStatus.pending;
      default:
        return UserStatus.active;
    }
  }

  /// Parse Firestore Timestamp to DateTime
  DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  /// Load audit logs from Firebase
  Future<void> loadAuditLogs({String? userId}) async {
    try {
      Query<Map<String, dynamic>> query = _firestore.collection('auditLogs')
          .orderBy('timestamp', descending: true)
          .limit(100);
      
      if (userId != null) {
        query = query.where('entityId', isEqualTo: userId);
      }

      final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();
      
      _auditLogs = snapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        final Map<String, dynamic> data = doc.data();
        return AuditLogEntry(
          id: doc.id,
          actorId: data['actorId'] as String? ?? '',
          actorEmail: data['actorEmail'] as String?,
          action: data['action'] as String? ?? 'unknown',
          entityType: data['entityType'] as String? ?? 'Unknown',
          entityId: data['entityId'] as String? ?? '',
          siteId: data['siteId'] as String?,
          details: data['details'] as Map<String, dynamic>?,
          timestamp: _parseTimestamp(data['timestamp']) ?? DateTime.now(),
        );
      }).toList();
      
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load audit logs: $e');
    }
  }

  /// Create a new user in Firebase
  Future<UserModel?> createUser({
    required String email,
    required String displayName,
    required UserRole role,
    required List<String> siteIds,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Create user document in Firebase
      final DocumentReference<Map<String, dynamic>> docRef = 
          await _firestore.collection('users').add(<String, dynamic>{
        'email': email,
        'displayName': displayName,
        'role': role.name,
        'status': 'pending',
        'siteIds': siteIds,
        'entitlements': <Map<String, dynamic>>[],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Log the action
      await _logAuditAction(
        action: 'user.created',
        entityType: 'User',
        entityId: docRef.id,
        details: <String, dynamic>{
          'email': email,
          'role': role.name,
          'siteIds': siteIds,
        },
      );

      final UserModel newUser = UserModel(
        uid: docRef.id,
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

  /// Update user role in Firebase
  Future<bool> updateUserRole(String userId, UserRole newRole) async {
    try {
      final int index = _users.indexWhere((UserModel u) => u.uid == userId);
      if (index == -1) return false;

      final UserRole oldRole = _users[index].role;

      await _firestore.collection('users').doc(userId).update(<String, dynamic>{
        'role': newRole.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Log the action
      await _logAuditAction(
        action: 'user.role_updated',
        entityType: 'User',
        entityId: userId,
        details: <String, dynamic>{
          'oldRole': oldRole.name,
          'newRole': newRole.name,
        },
      );

      _users[index] = _users[index].copyWith(
        role: newRole,
        updatedAt: DateTime.now(),
      );
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Update user status in Firebase (suspend/reactivate)
  Future<bool> updateUserStatus(String userId, UserStatus newStatus) async {
    try {
      final int index = _users.indexWhere((UserModel u) => u.uid == userId);
      if (index == -1) return false;

      final UserStatus oldStatus = _users[index].status;

      await _firestore.collection('users').doc(userId).update(<String, dynamic>{
        'status': newStatus.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Log the action
      await _logAuditAction(
        action: newStatus == UserStatus.suspended ? 'user.suspended' : 'user.status_updated',
        entityType: 'User',
        entityId: userId,
        details: <String, dynamic>{
          'oldStatus': oldStatus.name,
          'newStatus': newStatus.name,
        },
      );

      _users[index] = _users[index].copyWith(
        status: newStatus,
        updatedAt: DateTime.now(),
      );
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Add user to site in Firebase
  Future<bool> addUserToSite(String userId, String siteId) async {
    try {
      final int index = _users.indexWhere((UserModel u) => u.uid == userId);
      if (index == -1) return false;

      final UserModel user = _users[index];
      if (user.siteIds.contains(siteId)) return true; // Already in site

      final List<String> newSiteIds = <String>[...user.siteIds, siteId];

      await _firestore.collection('users').doc(userId).update(<String, dynamic>{
        'siteIds': newSiteIds,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Log the action
      await _logAuditAction(
        action: 'user.site_added',
        entityType: 'User',
        entityId: userId,
        siteId: siteId,
      );

      _users[index] = user.copyWith(
        siteIds: newSiteIds,
        updatedAt: DateTime.now(),
      );
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Remove user from site in Firebase
  Future<bool> removeUserFromSite(String userId, String siteId) async {
    try {
      final int index = _users.indexWhere((UserModel u) => u.uid == userId);
      if (index == -1) return false;

      final UserModel user = _users[index];
      final List<String> newSiteIds = user.siteIds.where((String s) => s != siteId).toList();

      await _firestore.collection('users').doc(userId).update(<String, dynamic>{
        'siteIds': newSiteIds,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Log the action
      await _logAuditAction(
        action: 'user.site_removed',
        entityType: 'User',
        entityId: userId,
        siteId: siteId,
      );

      _users[index] = user.copyWith(
        siteIds: newSiteIds,
        updatedAt: DateTime.now(),
      );
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Delete user (deactivate in Firebase)
  Future<bool> deleteUser(String userId) async {
    return updateUserStatus(userId, UserStatus.deactivated);
  }

  /// Helper to log audit actions
  Future<void> _logAuditAction({
    required String action,
    required String entityType,
    String? entityId,
    String? siteId,
    Map<String, dynamic>? details,
  }) async {
    try {
      await _firestore.collection('auditLogs').add(<String, dynamic>{
        'action': action,
        'entityType': entityType,
        'entityId': entityId,
        'siteId': siteId,
        'details': details,
        'timestamp': FieldValue.serverTimestamp(),
        // Actor info will be filled by security rules or cloud function
      });
    } catch (e) {
      debugPrint('Failed to log audit action: $e');
    }
  }
}
