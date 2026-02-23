import 'package:equatable/equatable.dart';
import '../../auth/app_state.dart' show UserRole, UserRoleExtension;

/// User account status
enum UserStatus {
  active,
  suspended,
  pending,
  deactivated;

  String get displayName {
    switch (this) {
      case UserStatus.active:
        return 'Active';
      case UserStatus.suspended:
        return 'Suspended';
      case UserStatus.pending:
        return 'Pending';
      case UserStatus.deactivated:
        return 'Deactivated';
    }
  }

  /// Alias for displayName for compatibility
  String get label => displayName;
}

/// User model for the platform
class UserModel extends Equatable {

  const UserModel({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoURL,
    required this.role,
    this.status = UserStatus.active,
    this.siteIds = const [],
    this.parentIds,
    this.organizationId,
    required this.createdAt,
    this.updatedAt,
    this.lastLoginAt,
    this.metadata,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String?,
      photoURL: json['photoURL'] as String?,
      role: UserRoleExtension.fromString(json['role'] as String? ?? 'learner'),
      status: UserStatus.values.firstWhere(
        (e) => e.name == (json['status'] as String? ?? 'active').toLowerCase(),
        orElse: () => UserStatus.active,
      ),
      siteIds: (json['siteIds'] as List<dynamic>?)?.cast<String>() ?? [],
      parentIds: (json['parentIds'] as List<dynamic>?)?.cast<String>(),
      organizationId: json['organizationId'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
      updatedAt: json['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['updatedAt'] as int)
          : null,
      lastLoginAt: json['lastLoginAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['lastLoginAt'] as int)
          : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
  final String uid;
  final String email;
  final String? displayName;
  final String? photoURL;
  final UserRole role;
  final UserStatus status;
  final List<String> siteIds;
  final List<String>? parentIds;
  final String? organizationId;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? lastLoginAt;
  final Map<String, dynamic>? metadata;

  String get initials {
    if (displayName != null && displayName!.isNotEmpty) {
      final List<String> parts = displayName!.trim().split(' ');
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      return parts[0].substring(0, parts[0].length.clamp(0, 2)).toUpperCase();
    }
    return email.substring(0, 2).toUpperCase();
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'role': role.name,
      'status': status.name,
      'siteIds': siteIds,
      'parentIds': parentIds,
      'organizationId': organizationId,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
      'lastLoginAt': lastLoginAt?.millisecondsSinceEpoch,
      'metadata': metadata,
    };
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoURL,
    UserRole? role,
    UserStatus? status,
    List<String>? siteIds,
    List<String>? parentIds,
    String? organizationId,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastLoginAt,
    Map<String, dynamic>? metadata,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      role: role ?? this.role,
      status: status ?? this.status,
      siteIds: siteIds ?? this.siteIds,
      parentIds: parentIds ?? this.parentIds,
      organizationId: organizationId ?? this.organizationId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  List<Object?> get props => <Object?>[uid, email, role, status, siteIds];
}

/// Site model
class SiteModel extends Equatable {

  const SiteModel({
    required this.id,
    required this.name,
    this.location,
    this.siteLeadIds = const [],
    required this.createdAt,
    this.userCount = 0,
    this.learnerCount = 0,
  });

  factory SiteModel.fromJson(Map<String, dynamic> json) {
    return SiteModel(
      id: json['id'] as String,
      name: json['name'] as String,
      location: json['location'] as String?,
      siteLeadIds: (json['siteLeadIds'] as List<dynamic>?)?.cast<String>() ?? [],
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
      userCount: json['userCount'] as int? ?? 0,
      learnerCount: json['learnerCount'] as int? ?? 0,
    );
  }
  final String id;
  final String name;
  final String? location;
  final List<String> siteLeadIds;
  final DateTime createdAt;
  final int userCount;
  final int learnerCount;

  @override
  List<Object?> get props => <Object?>[id, name];
}

/// Audit log entry
class AuditLogEntry extends Equatable {

  const AuditLogEntry({
    required this.id,
    required this.actorId,
    this.actorEmail,
    required this.action,
    required this.entityType,
    required this.entityId,
    this.siteId,
    this.details,
    required this.timestamp,
  });

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) {
    return AuditLogEntry(
      id: json['id'] as String,
      actorId: json['actorId'] as String,
      actorEmail: json['actorEmail'] as String?,
      action: json['action'] as String,
      entityType: json['entityType'] as String,
      entityId: json['entityId'] as String,
      siteId: json['siteId'] as String?,
      details: json['details'] as Map<String, dynamic>?,
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
    );
  }
  final String id;
  final String actorId;
  final String? actorEmail;
  final String action;
  final String entityType;
  final String entityId;
  final String? siteId;
  final Map<String, dynamic>? details;
  final DateTime timestamp;

  @override
  List<Object?> get props => <Object?>[id, actorId, action, entityType, entityId, timestamp];
}
