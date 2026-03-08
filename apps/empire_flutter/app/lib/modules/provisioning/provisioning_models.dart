import 'package:equatable/equatable.dart';

DateTime? _coerceDateTime(dynamic value) {
  if (value is DateTime) return value;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value.trim());
  }
  if (value is Map) {
    final dynamic secondsRaw = value['seconds'] ?? value['_seconds'];
    final dynamic nanosRaw = value['nanoseconds'] ?? value['_nanoseconds'];
    final int? seconds =
        secondsRaw is int ? secondsRaw : int.tryParse('$secondsRaw');
    final int nanos =
        nanosRaw is int ? nanosRaw : int.tryParse('$nanosRaw') ?? 0;
    if (seconds != null) {
      return DateTime.fromMillisecondsSinceEpoch(
        (seconds * 1000) + (nanos ~/ 1000000),
      );
    }
  }
  return null;
}

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
        siteIds:
            List<String>.from(json['siteIds'] as List<dynamic>? ?? <dynamic>[]),
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
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
  List<Object?> get props =>
      <Object?>[id, siteId, userId, displayName, gradeLevel];
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
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
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
  List<Object?> get props =>
      <Object?>[id, siteId, parentId, learnerId, relationship];
}

/// Cohort launch workflow for site provisioning.
class CohortLaunch extends Equatable {
  const CohortLaunch({
    required this.id,
    required this.siteId,
    required this.cohortName,
    required this.ageBand,
    required this.scheduleLabel,
    required this.programFormat,
    required this.curriculumTerm,
    required this.rosterStatus,
    required this.parentCommunicationStatus,
    required this.baselineSurveyStatus,
    required this.kickoffStatus,
    required this.status,
    this.instructorId,
    this.welcomePackStatus,
    this.deviceReadinessStatus,
    this.kitReadinessStatus,
    this.learnerCount,
    this.notes,
    this.updatedAt,
  });

  factory CohortLaunch.fromJson(Map<String, dynamic> json) => CohortLaunch(
        id: json['id'] as String,
        siteId: json['siteId'] as String? ?? '',
        cohortName: json['cohortName'] as String? ?? 'Cohort',
        ageBand: json['ageBand'] as String? ?? 'mixed',
        scheduleLabel: json['scheduleLabel'] as String? ?? 'TBD',
        programFormat: json['programFormat'] as String? ?? 'gold',
        curriculumTerm: json['curriculumTerm'] as String? ?? 'Term 1',
        rosterStatus: json['rosterStatus'] as String? ?? 'draft',
        parentCommunicationStatus:
            json['parentCommunicationStatus'] as String? ?? 'pending',
        baselineSurveyStatus:
            json['baselineSurveyStatus'] as String? ?? 'pending',
        kickoffStatus: json['kickoffStatus'] as String? ?? 'pending',
        status: json['status'] as String? ?? 'planning',
        instructorId: json['instructorId'] as String?,
        welcomePackStatus: json['welcomePackStatus'] as String?,
        deviceReadinessStatus: json['deviceReadinessStatus'] as String?,
        kitReadinessStatus: json['kitReadinessStatus'] as String?,
        learnerCount: (json['learnerCount'] as num?)?.toInt(),
        notes: json['notes'] as String?,
        updatedAt: _coerceDateTime(json['updatedAt'] ?? json['createdAt']),
      );

  final String id;
  final String siteId;
  final String cohortName;
  final String ageBand;
  final String scheduleLabel;
  final String programFormat;
  final String curriculumTerm;
  final String rosterStatus;
  final String parentCommunicationStatus;
  final String baselineSurveyStatus;
  final String kickoffStatus;
  final String status;
  final String? instructorId;
  final String? welcomePackStatus;
  final String? deviceReadinessStatus;
  final String? kitReadinessStatus;
  final int? learnerCount;
  final String? notes;
  final DateTime? updatedAt;

  @override
  List<Object?> get props => <Object?>[
        id,
        siteId,
        cohortName,
        ageBand,
        scheduleLabel,
        programFormat,
        curriculumTerm,
        rosterStatus,
        parentCommunicationStatus,
        baselineSurveyStatus,
        kickoffStatus,
        status,
        learnerCount,
        updatedAt,
      ];
}
