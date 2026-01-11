import 'package:equatable/equatable.dart';

/// User profile types
class UserProfile extends Equatable {

  const UserProfile({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
    required this.siteIds,
    required this.createdAt,
    this.lastLoginAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] as String,
        email: json['email'] as String,
        displayName: json['displayName'] as String,
        role: json['role'] as String,
        siteIds: List<String>.from(json['siteIds'] as List<dynamic>? ?? <dynamic>[]),
        createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
        lastLoginAt: json['lastLoginAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(json['lastLoginAt'] as int)
            : null,
      );
  final String id;
  final String email;
  final String displayName;
  final String role;
  final List<String> siteIds;
  final DateTime createdAt;
  final DateTime? lastLoginAt;

  @override
  List<Object?> get props => <Object?>[id, email, displayName, role, siteIds];
}

/// Learner profile
class LearnerProfile extends Equatable {

  const LearnerProfile({
    required this.id,
    required this.siteId,
    required this.userId,
    required this.displayName,
    this.gradeLevel,
    this.dateOfBirth,
    this.notes,
  });

  factory LearnerProfile.fromJson(Map<String, dynamic> json) => LearnerProfile(
        id: json['id'] as String,
        siteId: json['siteId'] as String,
        userId: json['userId'] as String,
        displayName: json['displayName'] as String,
        gradeLevel: json['gradeLevel'] as int?,
        dateOfBirth: json['dateOfBirth'] != null
            ? DateTime.fromMillisecondsSinceEpoch(json['dateOfBirth'] as int)
            : null,
        notes: json['notes'] as String?,
      );
  final String id;
  final String siteId;
  final String userId;
  final String displayName;
  final int? gradeLevel;
  final DateTime? dateOfBirth;
  final String? notes;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'siteId': siteId,
        'userId': userId,
        'displayName': displayName,
        if (gradeLevel != null) 'gradeLevel': gradeLevel,
        if (dateOfBirth != null)
          'dateOfBirth': dateOfBirth!.millisecondsSinceEpoch,
        if (notes != null) 'notes': notes,
      };

  @override
  List<Object?> get props => <Object?>[id, siteId, userId, displayName, gradeLevel];
}

/// Parent profile
class ParentProfile extends Equatable {

  const ParentProfile({
    required this.id,
    required this.siteId,
    required this.userId,
    required this.displayName,
    this.phone,
    this.email,
  });

  factory ParentProfile.fromJson(Map<String, dynamic> json) => ParentProfile(
        id: json['id'] as String,
        siteId: json['siteId'] as String,
        userId: json['userId'] as String,
        displayName: json['displayName'] as String,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
      );
  final String id;
  final String siteId;
  final String userId;
  final String displayName;
  final String? phone;
  final String? email;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'siteId': siteId,
        'userId': userId,
        'displayName': displayName,
        if (phone != null) 'phone': phone,
        if (email != null) 'email': email,
      };

  @override
  List<Object?> get props => <Object?>[id, siteId, userId, displayName];
}

/// Guardian link between parent and learner
class GuardianLink extends Equatable {

  const GuardianLink({
    required this.id,
    required this.siteId,
    required this.parentId,
    required this.learnerId,
    required this.relationship,
    this.isPrimary = false,
    required this.createdAt,
    required this.createdBy,
    this.parentName,
    this.learnerName,
  });

  factory GuardianLink.fromJson(Map<String, dynamic> json) => GuardianLink(
        id: json['id'] as String,
        siteId: json['siteId'] as String,
        parentId: json['parentId'] as String,
        learnerId: json['learnerId'] as String,
        relationship: json['relationship'] as String,
        isPrimary: json['isPrimary'] as bool? ?? false,
        createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
        createdBy: json['createdBy'] as String,
        parentName: json['parentName'] as String?,
        learnerName: json['learnerName'] as String?,
      );
  final String id;
  final String siteId;
  final String parentId;
  final String learnerId;
  final String relationship;
  final bool isPrimary;
  final DateTime createdAt;
  final String createdBy;
  // Display names (resolved from user lookups)
  final String? parentName;
  final String? learnerName;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'siteId': siteId,
        'parentId': parentId,
        'learnerId': learnerId,
        'relationship': relationship,
        'isPrimary': isPrimary,
      };

  @override
  List<Object?> get props => <Object?>[id, siteId, parentId, learnerId, relationship];
}
