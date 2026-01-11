import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

@immutable
class UserModel {
  const UserModel({
    required this.id,
    required this.email,
    required this.role,
    this.displayName,
    this.siteIds = const <String>[],
    this.activeSiteId,
    this.provisionedBy,
    this.provisionedAt,
    this.createdAt,
    this.updatedAt,
    this.archived = false,
  });

  final String id;
  final String email;
  final String role;
  final String? displayName;
  final List<String> siteIds;
  final String? activeSiteId;
  final String? provisionedBy;
  final Timestamp? provisionedAt;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;
  final bool archived;

  factory UserModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return UserModel(
      id: doc.id,
      email: data['email'] as String? ?? '',
      role: data['role'] as String? ?? 'learner',
      displayName: data['displayName'] as String?,
      siteIds: List<String>.from(data['siteIds'] as List? ?? const <String>[]),
      activeSiteId: data['activeSiteId'] as String?,
      provisionedBy: data['provisionedBy'] as String?,
      provisionedAt: data['provisionedAt'] as Timestamp?,
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
      archived: data['archived'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'email': email,
        'role': role,
        'displayName': displayName,
        'siteIds': siteIds,
        'activeSiteId': activeSiteId,
        'provisionedBy': provisionedBy,
        'provisionedAt': provisionedAt,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
        'archived': archived,
      };
}

@immutable
class GuardianLinkModel {
  const GuardianLinkModel({
    required this.id,
    required this.parentId,
    required this.learnerId,
    required this.siteId,
    this.relationship,
    this.isPrimary,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String parentId;
  final String learnerId;
  final String siteId;
  final String? relationship;
  final bool? isPrimary;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory GuardianLinkModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return GuardianLinkModel(
      id: doc.id,
      parentId: data['parentId'] as String? ?? '',
      learnerId: data['learnerId'] as String? ?? '',
      siteId: data['siteId'] as String? ?? '',
      relationship: data['relationship'] as String?,
      isPrimary: data['isPrimary'] as bool?,
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'parentId': parentId,
        'learnerId': learnerId,
        'siteId': siteId,
        'relationship': relationship,
        'isPrimary': isPrimary,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class LearnerProfileModel {
  const LearnerProfileModel({
    required this.id,
    required this.learnerId,
    required this.siteId,
    this.legalName,
    this.preferredName,
    this.dateOfBirth,
    this.gradeLevel,
    this.strengths = const <String>[],
    this.learningNeeds = const <String>[],
    this.interests = const <String>[],
    this.goals = const <String>[],
    this.emergencyContact,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String learnerId;
  final String siteId;
  final String? legalName;
  final String? preferredName;
  final String? dateOfBirth;
  final String? gradeLevel;
  final List<String> strengths;
  final List<String> learningNeeds;
  final List<String> interests;
  final List<String> goals;
  final Map<String, dynamic>? emergencyContact;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory LearnerProfileModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return LearnerProfileModel(
      id: doc.id,
      learnerId: data['learnerId'] as String? ?? '',
      siteId: data['siteId'] as String? ?? '',
      legalName: data['legalName'] as String?,
      preferredName: data['preferredName'] as String?,
      dateOfBirth: data['dateOfBirth'] as String?,
      gradeLevel: data['gradeLevel'] as String?,
      strengths: List<String>.from(data['strengths'] as List? ?? const <String>[]),
      learningNeeds: List<String>.from(data['learningNeeds'] as List? ?? const <String>[]),
      interests: List<String>.from(data['interests'] as List? ?? const <String>[]),
      goals: List<String>.from(data['goals'] as List? ?? const <String>[]),
      emergencyContact: data['emergencyContact'] as Map<String, dynamic>?,
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'learnerId': learnerId,
        'siteId': siteId,
        'legalName': legalName,
        'preferredName': preferredName,
        'dateOfBirth': dateOfBirth,
        'gradeLevel': gradeLevel,
        'strengths': strengths,
        'learningNeeds': learningNeeds,
        'interests': interests,
        'goals': goals,
        'emergencyContact': emergencyContact,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class ParentProfileModel {
  const ParentProfileModel({
    required this.id,
    required this.parentId,
    required this.siteId,
    this.legalName,
    this.preferredName,
    this.phone,
    this.preferredLanguage,
    this.communicationPreferences = const <String>[],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String parentId;
  final String siteId;
  final String? legalName;
  final String? preferredName;
  final String? phone;
  final String? preferredLanguage;
  final List<String> communicationPreferences;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory ParentProfileModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return ParentProfileModel(
      id: doc.id,
      parentId: data['parentId'] as String? ?? '',
      siteId: data['siteId'] as String? ?? '',
      legalName: data['legalName'] as String?,
      preferredName: data['preferredName'] as String?,
      phone: data['phone'] as String?,
      preferredLanguage: data['preferredLanguage'] as String?,
      communicationPreferences: List<String>.from(data['communicationPreferences'] as List? ?? const <String>[]),
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'parentId': parentId,
        'siteId': siteId,
        'legalName': legalName,
        'preferredName': preferredName,
        'phone': phone,
        'preferredLanguage': preferredLanguage,
        'communicationPreferences': communicationPreferences,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class HabitModel {
  const HabitModel({
    required this.id,
    required this.learnerId,
    required this.siteId,
    required this.title,
    this.status = 'active',
    this.frequency,
    this.nextCheckInAt,
    this.lastCompletedAt,
    this.lastReflectedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String learnerId;
  final String siteId;
  final String title;
  final String status;
  final String? frequency;
  final Timestamp? nextCheckInAt;
  final Timestamp? lastCompletedAt;
  final Timestamp? lastReflectedAt;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory HabitModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return HabitModel(
      id: doc.id,
      learnerId: data['learnerId'] as String? ?? '',
      siteId: data['siteId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      status: data['status'] as String? ?? 'active',
      frequency: data['frequency'] as String?,
      nextCheckInAt: data['nextCheckInAt'] as Timestamp?,
      lastCompletedAt: data['lastCompletedAt'] as Timestamp?,
      lastReflectedAt: data['lastReflectedAt'] as Timestamp?,
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'learnerId': learnerId,
        'siteId': siteId,
        'title': title,
        'status': status,
        'frequency': frequency,
        'nextCheckInAt': nextCheckInAt,
        'lastCompletedAt': lastCompletedAt,
        'lastReflectedAt': lastReflectedAt,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class SiteModel {
  const SiteModel({
    required this.id,
    required this.name,
    this.timezone,
    this.address,
    this.adminUserIds = const <String>[],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String? timezone;
  final String? address;
  final List<String> adminUserIds;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory SiteModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return SiteModel(
      id: doc.id,
      name: data['name'] as String? ?? '',
      timezone: data['timezone'] as String?,
      address: data['address'] as String?,
      adminUserIds: List<String>.from(data['adminUserIds'] as List? ?? const <String>[]),
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'name': name,
        'timezone': timezone,
        'address': address,
        'adminUserIds': adminUserIds,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class SessionModel {
  const SessionModel({
    required this.id,
    required this.siteId,
    required this.name,
    this.educatorId,
    this.pillarEmphasis = const <String>[],
    this.schedule,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String siteId;
  final String name;
  final String? educatorId;
  final List<String> pillarEmphasis;
  final Map<String, dynamic>? schedule;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory SessionModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return SessionModel(
      id: doc.id,
      siteId: data['siteId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      educatorId: data['educatorId'] as String?,
      pillarEmphasis: List<String>.from(data['pillarEmphasis'] as List? ?? const <String>[]),
      schedule: data['schedule'] as Map<String, dynamic>?,
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'siteId': siteId,
        'name': name,
        'educatorId': educatorId,
        'pillarEmphasis': pillarEmphasis,
        'schedule': schedule,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class SessionOccurrenceModel {
  const SessionOccurrenceModel({
    required this.id,
    required this.sessionId,
    required this.siteId,
    required this.date,
    required this.startAt,
    required this.endAt,
    this.educatorId,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String sessionId;
  final String siteId;
  final String date;
  final Timestamp startAt;
  final Timestamp endAt;
  final String? educatorId;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory SessionOccurrenceModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return SessionOccurrenceModel(
      id: doc.id,
      sessionId: data['sessionId'] as String? ?? '',
      siteId: data['siteId'] as String? ?? '',
      date: data['date'] as String? ?? '',
      startAt: data['startAt'] as Timestamp? ?? Timestamp.now(),
      endAt: data['endAt'] as Timestamp? ?? Timestamp.now(),
      educatorId: data['educatorId'] as String?,
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'sessionId': sessionId,
        'siteId': siteId,
        'date': date,
        'startAt': startAt,
        'endAt': endAt,
        'educatorId': educatorId,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class EnrollmentModel {
  const EnrollmentModel({
    required this.id,
    required this.siteId,
    required this.sessionId,
    required this.learnerId,
    this.status,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String siteId;
  final String sessionId;
  final String learnerId;
  final String? status;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory EnrollmentModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return EnrollmentModel(
      id: doc.id,
      siteId: data['siteId'] as String? ?? '',
      sessionId: data['sessionId'] as String? ?? '',
      learnerId: data['learnerId'] as String? ?? '',
      status: data['status'] as String?,
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'siteId': siteId,
        'sessionId': sessionId,
        'learnerId': learnerId,
        'status': status,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class AttendanceRecordModel {
  const AttendanceRecordModel({
    required this.id,
    required this.siteId,
    required this.sessionOccurrenceId,
    required this.learnerId,
    required this.status,
    required this.recordedBy,
    this.note,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String siteId;
  final String sessionOccurrenceId;
  final String learnerId;
  final String status;
  final String recordedBy;
  final String? note;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory AttendanceRecordModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return AttendanceRecordModel(
      id: doc.id,
      siteId: data['siteId'] as String? ?? '',
      sessionOccurrenceId: data['sessionOccurrenceId'] as String? ?? '',
      learnerId: data['learnerId'] as String? ?? '',
      status: data['status'] as String? ?? 'present',
      recordedBy: data['recordedBy'] as String? ?? '',
      note: data['note'] as String?,
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'siteId': siteId,
        'sessionOccurrenceId': sessionOccurrenceId,
        'learnerId': learnerId,
        'status': status,
        'recordedBy': recordedBy,
        'note': note,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class PillarModel {
  const PillarModel({required this.code, required this.title, this.description, this.order});

  final String code;
  final String title;
  final String? description;
  final int? order;

  factory PillarModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return PillarModel(
      code: doc.id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String?,
      order: data['order'] as int?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'title': title,
        'description': description,
        'order': order,
      };
}

@immutable
class SkillModel {
  const SkillModel({
    required this.id,
    required this.name,
    required this.pillarCode,
    this.description,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String pillarCode;
  final String? description;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory SkillModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return SkillModel(
      id: doc.id,
      name: data['name'] as String? ?? '',
      pillarCode: data['pillarCode'] as String? ?? '',
      description: data['description'] as String?,
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'name': name,
        'pillarCode': pillarCode,
        'description': description,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class SkillMasteryModel {
  const SkillMasteryModel({
    required this.id,
    required this.learnerId,
    required this.skillId,
    required this.level,
    this.evidenceIds = const <String>[],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String learnerId;
  final String skillId;
  final int level;
  final List<String> evidenceIds;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory SkillMasteryModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return SkillMasteryModel(
      id: doc.id,
      learnerId: data['learnerId'] as String? ?? '',
      skillId: data['skillId'] as String? ?? '',
      level: (data['level'] as num?)?.toInt() ?? 0,
      evidenceIds: List<String>.from(data['evidenceIds'] as List? ?? const <String>[]),
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'learnerId': learnerId,
        'skillId': skillId,
        'level': level,
        'evidenceIds': evidenceIds,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class MissionModel {
  const MissionModel({
    required this.id,
    required this.title,
    required this.description,
    required this.pillarCodes,
    this.siteId,
    this.skillIds = const <String>[],
    this.difficulty,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String description;
  final List<String> pillarCodes;
  final String? siteId;
  final List<String> skillIds;
  final String? difficulty;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory MissionModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return MissionModel(
      id: doc.id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      pillarCodes: List<String>.from(data['pillarCodes'] as List? ?? const <String>[]),
      siteId: data['siteId'] as String?,
      skillIds: List<String>.from(data['skillIds'] as List? ?? const <String>[]),
      difficulty: data['difficulty'] as String?,
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'title': title,
        'description': description,
        'pillarCodes': pillarCodes,
        'siteId': siteId,
        'skillIds': skillIds,
        'difficulty': difficulty,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class MissionPlanModel {
  const MissionPlanModel({
    required this.id,
    required this.siteId,
    required this.sessionOccurrenceId,
    required this.educatorId,
    required this.missionIds,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String siteId;
  final String sessionOccurrenceId;
  final String educatorId;
  final List<String> missionIds;
  final String? notes;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory MissionPlanModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return MissionPlanModel(
      id: doc.id,
      siteId: data['siteId'] as String? ?? '',
      sessionOccurrenceId: data['sessionOccurrenceId'] as String? ?? '',
      educatorId: data['educatorId'] as String? ?? '',
      missionIds: List<String>.from(data['missionIds'] as List? ?? const <String>[]),
      notes: data['notes'] as String?,
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'siteId': siteId,
        'sessionOccurrenceId': sessionOccurrenceId,
        'educatorId': educatorId,
        'missionIds': missionIds,
        'notes': notes,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class MissionAttemptModel {
  const MissionAttemptModel({
    required this.id,
    required this.siteId,
    required this.missionId,
    required this.learnerId,
    required this.status,
    this.sessionOccurrenceId,
    this.reflection,
    this.artifactUrls = const <String>[],
    this.pillarCodes = const <String>[],
    this.reviewedBy,
    this.reviewNotes,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String siteId;
  final String missionId;
  final String learnerId;
  final String status;
  final String? sessionOccurrenceId;
  final String? reflection;
  final List<String> artifactUrls;
  final List<String> pillarCodes;
  final String? reviewedBy;
  final String? reviewNotes;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory MissionAttemptModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return MissionAttemptModel(
      id: doc.id,
      siteId: data['siteId'] as String? ?? '',
      missionId: data['missionId'] as String? ?? '',
      learnerId: data['learnerId'] as String? ?? '',
      status: data['status'] as String? ?? 'draft',
      sessionOccurrenceId: data['sessionOccurrenceId'] as String?,
      reflection: data['reflection'] as String?,
      artifactUrls: List<String>.from(data['artifactUrls'] as List? ?? const <String>[]),
      pillarCodes: List<String>.from(data['pillarCodes'] as List? ?? const <String>[]),
      reviewedBy: data['reviewedBy'] as String?,
      reviewNotes: data['reviewNotes'] as String?,
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'siteId': siteId,
        'missionId': missionId,
        'learnerId': learnerId,
        'status': status,
        'sessionOccurrenceId': sessionOccurrenceId,
        'reflection': reflection,
        'artifactUrls': artifactUrls,
        'pillarCodes': pillarCodes,
        'reviewedBy': reviewedBy,
        'reviewNotes': reviewNotes,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class PortfolioModel {
  const PortfolioModel({
    required this.id,
    required this.siteId,
    required this.learnerId,
    this.title,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String siteId;
  final String learnerId;
  final String? title;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory PortfolioModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return PortfolioModel(
      id: doc.id,
      siteId: data['siteId'] as String? ?? '',
      learnerId: data['learnerId'] as String? ?? '',
      title: data['title'] as String?,
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'siteId': siteId,
        'learnerId': learnerId,
        'title': title,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class PortfolioItemModel {
  const PortfolioItemModel({
    required this.id,
    required this.siteId,
    required this.learnerId,
    required this.title,
    this.description,
    this.artifactUrls = const <String>[],
    this.pillarCodes = const <String>[],
    this.skillIds = const <String>[],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String siteId;
  final String learnerId;
  final String title;
  final String? description;
  final List<String> artifactUrls;
  final List<String> pillarCodes;
  final List<String> skillIds;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory PortfolioItemModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return PortfolioItemModel(
      id: doc.id,
      siteId: data['siteId'] as String? ?? '',
      learnerId: data['learnerId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      description: data['description'] as String?,
      artifactUrls: List<String>.from(data['artifactUrls'] as List? ?? const <String>[]),
      pillarCodes: List<String>.from(data['pillarCodes'] as List? ?? const <String>[]),
      skillIds: List<String>.from(data['skillIds'] as List? ?? const <String>[]),
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'siteId': siteId,
        'learnerId': learnerId,
        'title': title,
        'description': description,
        'artifactUrls': artifactUrls,
        'pillarCodes': pillarCodes,
        'skillIds': skillIds,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class CredentialModel {
  const CredentialModel({
    required this.id,
    required this.siteId,
    required this.learnerId,
    required this.title,
    required this.issuedAt,
    this.pillarCodes = const <String>[],
    this.skillIds = const <String>[],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String siteId;
  final String learnerId;
  final String title;
  final Timestamp issuedAt;
  final List<String> pillarCodes;
  final List<String> skillIds;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory CredentialModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return CredentialModel(
      id: doc.id,
      siteId: data['siteId'] as String? ?? '',
      learnerId: data['learnerId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      issuedAt: data['issuedAt'] as Timestamp? ?? Timestamp.now(),
      pillarCodes: List<String>.from(data['pillarCodes'] as List? ?? const <String>[]),
      skillIds: List<String>.from(data['skillIds'] as List? ?? const <String>[]),
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'siteId': siteId,
        'learnerId': learnerId,
        'title': title,
        'issuedAt': issuedAt,
        'pillarCodes': pillarCodes,
        'skillIds': skillIds,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class AccountabilityCycleModel {
  const AccountabilityCycleModel({
    required this.id,
    required this.scopeType,
    required this.scopeId,
    required this.startDate,
    required this.endDate,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String scopeType;
  final String scopeId;
  final String startDate;
  final String endDate;
  final String status;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory AccountabilityCycleModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return AccountabilityCycleModel(
      id: doc.id,
      scopeType: data['scopeType'] as String? ?? 'learner',
      scopeId: data['scopeId'] as String? ?? '',
      startDate: data['startDate'] as String? ?? '',
      endDate: data['endDate'] as String? ?? '',
      status: data['status'] as String? ?? 'planned',
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'scopeType': scopeType,
        'scopeId': scopeId,
        'startDate': startDate,
        'endDate': endDate,
        'status': status,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class AccountabilityKPIModel {
  const AccountabilityKPIModel({
    required this.id,
    required this.cycleId,
    required this.name,
    required this.target,
    required this.currentValue,
    this.unit,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String cycleId;
  final String name;
  final num target;
  final num currentValue;
  final String? unit;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory AccountabilityKPIModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return AccountabilityKPIModel(
      id: doc.id,
      cycleId: data['cycleId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      target: data['target'] as num? ?? 0,
      currentValue: data['currentValue'] as num? ?? 0,
      unit: data['unit'] as String?,
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'cycleId': cycleId,
        'name': name,
        'target': target,
        'currentValue': currentValue,
        'unit': unit,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class AccountabilityCommitmentModel {
  const AccountabilityCommitmentModel({
    required this.id,
    required this.cycleId,
    required this.userId,
    required this.role,
    required this.statement,
    this.pillarCodes = const <String>[],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String cycleId;
  final String userId;
  final String role;
  final String statement;
  final List<String> pillarCodes;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory AccountabilityCommitmentModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return AccountabilityCommitmentModel(
      id: doc.id,
      cycleId: data['cycleId'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      role: data['role'] as String? ?? 'learner',
      statement: data['statement'] as String? ?? '',
      pillarCodes: List<String>.from(data['pillarCodes'] as List? ?? const <String>[]),
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'cycleId': cycleId,
        'userId': userId,
        'role': role,
        'statement': statement,
        'pillarCodes': pillarCodes,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class AccountabilityReviewModel {
  const AccountabilityReviewModel({
    required this.id,
    required this.cycleId,
    required this.reviewerId,
    required this.revieweeId,
    this.notes,
    this.rating,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String cycleId;
  final String reviewerId;
  final String revieweeId;
  final String? notes;
  final num? rating;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory AccountabilityReviewModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return AccountabilityReviewModel(
      id: doc.id,
      cycleId: data['cycleId'] as String? ?? '',
      reviewerId: data['reviewerId'] as String? ?? '',
      revieweeId: data['revieweeId'] as String? ?? '',
      notes: data['notes'] as String?,
      rating: data['rating'] as num?,
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'cycleId': cycleId,
        'reviewerId': reviewerId,
        'revieweeId': revieweeId,
        'notes': notes,
        'rating': rating,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class AnnouncementModel {
  const AnnouncementModel({
    required this.id,
    required this.siteId,
    required this.title,
    required this.body,
    required this.roles,
    this.createdAt,
    this.publishedAt,
  });

  final String id;
  final String siteId;
  final String title;
  final String body;
  final List<String> roles;
  final Timestamp? createdAt;
  final Timestamp? publishedAt;

  factory AnnouncementModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return AnnouncementModel(
      id: doc.id,
      siteId: data['siteId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      roles: List<String>.from(data['roles'] as List? ?? const <String>[]),
      createdAt: data['createdAt'] as Timestamp?,
      publishedAt: data['publishedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'siteId': siteId,
        'title': title,
        'body': body,
        'roles': roles,
        'createdAt': createdAt ?? Timestamp.now(),
        'publishedAt': publishedAt,
      };
}

@immutable
class MessageThreadModel {
  const MessageThreadModel({
    required this.id,
    required this.siteId,
    required this.participantIds,
    this.subject,
    this.createdAt,
  });

  final String id;
  final String siteId;
  final List<String> participantIds;
  final String? subject;
  final Timestamp? createdAt;

  factory MessageThreadModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return MessageThreadModel(
      id: doc.id,
      siteId: data['siteId'] as String? ?? '',
      participantIds: List<String>.from(data['participantIds'] as List? ?? const <String>[]),
      subject: data['subject'] as String?,
      createdAt: data['createdAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'siteId': siteId,
        'participantIds': participantIds,
        'subject': subject,
        'createdAt': createdAt ?? Timestamp.now(),
      };
}

@immutable
class MessageModel {
  const MessageModel({
    required this.id,
    required this.threadId,
    required this.siteId,
    required this.senderId,
    required this.senderRole,
    required this.body,
    this.createdAt,
  });

  final String id;
  final String threadId;
  final String siteId;
  final String senderId;
  final String senderRole;
  final String body;
  final Timestamp? createdAt;

  factory MessageModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return MessageModel(
      id: doc.id,
      threadId: data['threadId'] as String? ?? '',
      siteId: data['siteId'] as String? ?? '',
      senderId: data['senderId'] as String? ?? '',
      senderRole: data['senderRole'] as String? ?? '',
      body: data['body'] as String? ?? '',
      createdAt: data['createdAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'threadId': threadId,
        'siteId': siteId,
        'senderId': senderId,
        'senderRole': senderRole,
        'body': body,
        'createdAt': createdAt ?? Timestamp.now(),
      };
}

@immutable
class CmsBlockModel {
  const CmsBlockModel({
    required this.type,
    this.title,
    this.body,
    this.bullets = const <String>[],
    this.imageUrl,
  });

  final String type;
  final String? title;
  final String? body;
  final List<String> bullets;
  final String? imageUrl;

  factory CmsBlockModel.fromMap(Map<String, dynamic> data) {
    return CmsBlockModel(
      type: data['type'] as String? ?? 'section',
      title: data['title'] as String?,
      body: data['body'] as String?,
      bullets: (data['bullets'] as List?)?.whereType<String>().toList() ?? const <String>[],
      imageUrl: data['imageUrl'] as String?,
    );
  }
}

@immutable
class CmsPageModel {
  const CmsPageModel({
    required this.slug,
    required this.title,
    required this.status,
    required this.audience,
    this.heroTitle,
    this.heroSubtitle,
    this.blocks = const <CmsBlockModel>[],
    this.updatedAt,
  });

  final String slug;
  final String title;
  final String status;
  final String audience;
  final String? heroTitle;
  final String? heroSubtitle;
  final List<CmsBlockModel> blocks;
  final Timestamp? updatedAt;

  factory CmsPageModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final List<dynamic> rawBlocks = data['bodyJson'] as List<dynamic>? ?? const <dynamic>[];
    return CmsPageModel(
      slug: data['slug'] as String? ?? doc.id,
      title: data['title'] as String? ?? (doc.id.isNotEmpty ? doc.id : 'Page'),
      status: data['status'] as String? ?? 'draft',
      audience: data['audience'] as String? ?? 'public',
      heroTitle: data['heroTitle'] as String?,
      heroSubtitle: data['heroSubtitle'] as String?,
      blocks: rawBlocks
          .whereType<Map<String, dynamic>>()
          .map((Map<String, dynamic> block) => CmsBlockModel.fromMap(block))
          .toList(),
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }
}

@immutable
class LeadModel {
  const LeadModel({
    required this.id,
    required this.name,
    required this.email,
    required this.source,
    this.status = 'new',
    this.message,
    this.siteId,
    this.slug,
    this.createdAt,
  });

  final String id;
  final String name;
  final String email;
  final String source;
  final String status;
  final String? message;
  final String? siteId;
  final String? slug;
  final Timestamp? createdAt;

  factory LeadModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return LeadModel(
      id: doc.id,
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      source: data['source'] as String? ?? 'unknown',
      status: data['status'] as String? ?? 'new',
      message: data['message'] as String?,
      siteId: data['siteId'] as String?,
      slug: data['slug'] as String?,
      createdAt: data['createdAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'name': name,
        'email': email,
        'source': source,
        'status': status,
        'message': message,
        'siteId': siteId,
        'slug': slug,
        'createdAt': createdAt ?? Timestamp.now(),
      };
}

@immutable
class PartnerOrgModel {
  const PartnerOrgModel({
    required this.id,
    required this.name,
    required this.ownerId,
    this.contactEmail,
    this.status = 'active',
    this.createdAt,
  });

  final String id;
  final String name;
  final String ownerId;
  final String? contactEmail;
  final String status;
  final Timestamp? createdAt;

  factory PartnerOrgModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return PartnerOrgModel(
      id: doc.id,
      name: data['name'] as String? ?? '',
      ownerId: data['ownerId'] as String? ?? '',
      contactEmail: data['contactEmail'] as String?,
      status: data['status'] as String? ?? 'active',
      createdAt: data['createdAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'name': name,
        'ownerId': ownerId,
        'contactEmail': contactEmail,
        'status': status,
        'createdAt': createdAt ?? Timestamp.now(),
      };
}

@immutable
class MarketplaceListingModel {
  const MarketplaceListingModel({
    required this.id,
    required this.partnerOrgId,
    required this.title,
    required this.price,
    required this.currency,
    this.description,
    this.status = 'draft',
    this.entitlementRoles = const <String>[],
    this.createdBy,
    this.submittedBy,
    this.submittedAt,
    this.approvedBy,
    this.approvedAt,
    this.publishedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String partnerOrgId;
  final String title;
  final String price;
  final String currency;
  final String? description;
  final String status;
  final List<String> entitlementRoles;
  final String? createdBy;
  final String? submittedBy;
  final Timestamp? submittedAt;
  final String? approvedBy;
  final Timestamp? approvedAt;
  final Timestamp? publishedAt;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory MarketplaceListingModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return MarketplaceListingModel(
      id: doc.id,
      partnerOrgId: data['partnerOrgId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      price: data['price'] as String? ?? '0',
      currency: data['currency'] as String? ?? 'USD',
      description: data['description'] as String?,
      status: data['status'] as String? ?? 'draft',
      entitlementRoles: List<String>.from(data['entitlementRoles'] as List? ?? const <String>[]),
      createdBy: data['createdBy'] as String?,
      submittedBy: data['submittedBy'] as String?,
      submittedAt: data['submittedAt'] as Timestamp?,
      approvedBy: data['approvedBy'] as String?,
      approvedAt: data['approvedAt'] as Timestamp?,
      publishedAt: data['publishedAt'] as Timestamp?,
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'partnerOrgId': partnerOrgId,
        'title': title,
        'price': price,
        'currency': currency,
        'description': description,
        'status': status,
        'entitlementRoles': entitlementRoles,
        'createdBy': createdBy,
        'submittedBy': submittedBy,
        'submittedAt': submittedAt,
        'approvedBy': approvedBy,
        'approvedAt': approvedAt,
        'publishedAt': publishedAt,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class PartnerContractModel {
  const PartnerContractModel({
    required this.id,
    required this.partnerOrgId,
    required this.title,
    required this.amount,
    required this.currency,
    this.status = 'draft',
    this.createdBy,
    this.dueDate,
    this.approvedBy,
    this.approvedAt,
    this.createdAt,
  });

  final String id;
  final String partnerOrgId;
  final String title;
  final String amount;
  final String currency;
  final String status;
  final String? createdBy;
  final Timestamp? dueDate;
  final String? approvedBy;
  final Timestamp? approvedAt;
  final Timestamp? createdAt;

  factory PartnerContractModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return PartnerContractModel(
      id: doc.id,
      partnerOrgId: data['partnerOrgId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      amount: data['amount'] as String? ?? '0',
      currency: data['currency'] as String? ?? 'USD',
      status: data['status'] as String? ?? 'draft',
      createdBy: data['createdBy'] as String?,
      dueDate: data['dueDate'] as Timestamp?,
      approvedBy: data['approvedBy'] as String?,
      approvedAt: data['approvedAt'] as Timestamp?,
      createdAt: data['createdAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'partnerOrgId': partnerOrgId,
        'title': title,
        'amount': amount,
        'currency': currency,
        'status': status,
        'createdBy': createdBy,
        'dueDate': dueDate,
        'approvedBy': approvedBy,
        'approvedAt': approvedAt,
        'createdAt': createdAt ?? Timestamp.now(),
      };
}

@immutable
class PartnerDeliverableModel {
  const PartnerDeliverableModel({
    required this.id,
    required this.contractId,
    required this.title,
    this.description,
    this.evidenceUrl,
    this.status = 'submitted',
    this.submittedBy,
    this.submittedAt,
    this.acceptedBy,
    this.acceptedAt,
  });

  final String id;
  final String contractId;
  final String title;
  final String? description;
  final String? evidenceUrl;
  final String status;
  final String? submittedBy;
  final Timestamp? submittedAt;
  final String? acceptedBy;
  final Timestamp? acceptedAt;

  factory PartnerDeliverableModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return PartnerDeliverableModel(
      id: doc.id,
      contractId: data['contractId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      description: data['description'] as String?,
      evidenceUrl: data['evidenceUrl'] as String?,
      status: data['status'] as String? ?? 'submitted',
      submittedBy: data['submittedBy'] as String?,
      submittedAt: data['submittedAt'] as Timestamp?,
      acceptedBy: data['acceptedBy'] as String?,
      acceptedAt: data['acceptedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'contractId': contractId,
        'title': title,
        'description': description,
        'evidenceUrl': evidenceUrl,
        'status': status,
        'submittedBy': submittedBy,
        'submittedAt': submittedAt ?? Timestamp.now(),
        'acceptedBy': acceptedBy,
        'acceptedAt': acceptedAt,
      };
}

@immutable
class PayoutModel {
  const PayoutModel({
    required this.id,
    required this.contractId,
    required this.amount,
    required this.currency,
    this.status = 'pending',
    this.createdBy,
    this.approvedBy,
    this.approvedAt,
    this.providerTransferId,
    this.createdAt,
  });

  final String id;
  final String contractId;
  final String amount;
  final String currency;
  final String status;
  final String? createdBy;
  final String? approvedBy;
  final Timestamp? approvedAt;
  final String? providerTransferId;
  final Timestamp? createdAt;

  factory PayoutModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return PayoutModel(
      id: doc.id,
      contractId: data['contractId'] as String? ?? '',
      amount: data['amount'] as String? ?? '0',
      currency: data['currency'] as String? ?? 'USD',
      status: data['status'] as String? ?? 'pending',
      createdBy: data['createdBy'] as String?,
      approvedBy: data['approvedBy'] as String?,
      approvedAt: data['approvedAt'] as Timestamp?,
      providerTransferId: data['providerTransferId'] as String?,
      createdAt: data['createdAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'contractId': contractId,
        'amount': amount,
        'currency': currency,
        'status': status,
        'createdBy': createdBy,
        'approvedBy': approvedBy,
        'approvedAt': approvedAt,
        'providerTransferId': providerTransferId,
        'createdAt': createdAt ?? Timestamp.now(),
      };
}

@immutable
class SiteCheckInOutModel {
  const SiteCheckInOutModel({
    required this.id,
    required this.siteId,
    required this.learnerId,
    required this.date,
    this.checkInAt,
    this.checkInBy,
    this.checkOutAt,
    this.checkOutBy,
    this.pickedUpByName,
    this.latePickupFlag,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String siteId;
  final String learnerId;
  final String date; // YYYY-MM-DD
  final Timestamp? checkInAt;
  final String? checkInBy;
  final Timestamp? checkOutAt;
  final String? checkOutBy;
  final String? pickedUpByName;
  final bool? latePickupFlag;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory SiteCheckInOutModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return SiteCheckInOutModel(
      id: doc.id,
      siteId: data['siteId'] as String? ?? '',
      learnerId: data['learnerId'] as String? ?? '',
      date: data['date'] as String? ?? '',
      checkInAt: data['checkInAt'] as Timestamp?,
      checkInBy: data['checkInBy'] as String?,
      checkOutAt: data['checkOutAt'] as Timestamp?,
      checkOutBy: data['checkOutBy'] as String?,
      pickedUpByName: data['pickedUpByName'] as String?,
      latePickupFlag: data['latePickupFlag'] as bool?,
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'siteId': siteId,
        'learnerId': learnerId,
        'date': date,
        'checkInAt': checkInAt,
        'checkInBy': checkInBy,
        'checkOutAt': checkOutAt,
        'checkOutBy': checkOutBy,
        'pickedUpByName': pickedUpByName,
        'latePickupFlag': latePickupFlag,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class IncidentReportModel {
  const IncidentReportModel({
    required this.id,
    required this.siteId,
    required this.reportedBy,
    required this.severity,
    required this.category,
    required this.status,
    required this.summary,
    this.learnerId,
    this.sessionOccurrenceId,
    this.details,
    this.reviewedBy,
    this.reviewedAt,
    this.closedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String siteId;
  final String reportedBy;
  final String severity;
  final String category;
  final String status;
  final String summary;
  final String? learnerId;
  final String? sessionOccurrenceId;
  final String? details;
  final String? reviewedBy;
  final Timestamp? reviewedAt;
  final Timestamp? closedAt;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory IncidentReportModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return IncidentReportModel(
      id: doc.id,
      siteId: data['siteId'] as String? ?? '',
      reportedBy: data['reportedBy'] as String? ?? '',
      severity: data['severity'] as String? ?? 'minor',
      category: data['category'] as String? ?? 'other',
      status: data['status'] as String? ?? 'draft',
      summary: data['summary'] as String? ?? '',
      learnerId: data['learnerId'] as String?,
      sessionOccurrenceId: data['sessionOccurrenceId'] as String?,
      details: data['details'] as String?,
      reviewedBy: data['reviewedBy'] as String?,
      reviewedAt: data['reviewedAt'] as Timestamp?,
      closedAt: data['closedAt'] as Timestamp?,
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'siteId': siteId,
        'reportedBy': reportedBy,
        'severity': severity,
        'category': category,
        'status': status,
        'summary': summary,
        'learnerId': learnerId,
        'sessionOccurrenceId': sessionOccurrenceId,
        'details': details,
        'reviewedBy': reviewedBy,
        'reviewedAt': reviewedAt,
        'closedAt': closedAt,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class ExternalIdentityLinkModel {
  const ExternalIdentityLinkModel({
    required this.id,
    required this.siteId,
    required this.provider,
    required this.providerUserId,
    required this.status,
    this.scholesaUserId,
    this.suggestedMatches,
    this.approvedBy,
    this.approvedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String siteId;
  final String provider;
  final String providerUserId;
  final String status;
  final String? scholesaUserId;
  final List<Map<String, dynamic>>? suggestedMatches;
  final String? approvedBy;
  final Timestamp? approvedAt;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory ExternalIdentityLinkModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return ExternalIdentityLinkModel(
      id: doc.id,
      siteId: data['siteId'] as String? ?? '',
      provider: data['provider'] as String? ?? '',
      providerUserId: data['providerUserId'] as String? ?? '',
      status: data['status'] as String? ?? 'unmatched',
      scholesaUserId: data['scholesaUserId'] as String?,
      suggestedMatches: (data['suggestedMatches'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      approvedBy: data['approvedBy'] as String?,
      approvedAt: data['approvedAt'] as Timestamp?,
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'siteId': siteId,
        'provider': provider,
        'providerUserId': providerUserId,
        'status': status,
        'scholesaUserId': scholesaUserId,
        'suggestedMatches': suggestedMatches,
        'approvedBy': approvedBy,
        'approvedAt': approvedAt,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

  @immutable
  class MediaConsentModel {
    const MediaConsentModel({
      required this.id,
      required this.siteId,
      required this.learnerId,
      required this.photoCaptureAllowed,
      required this.shareWithLinkedParents,
      required this.marketingUseAllowed,
      required this.consentStatus,
      this.consentStartDate,
      this.consentEndDate,
      this.consentDocumentUrl,
      this.createdAt,
      this.updatedAt,
    });

    final String id;
    final String siteId;
    final String learnerId;
    final bool photoCaptureAllowed;
    final bool shareWithLinkedParents;
    final bool marketingUseAllowed;
    final String consentStatus;
    final String? consentStartDate;
    final String? consentEndDate;
    final String? consentDocumentUrl;
    final Timestamp? createdAt;
    final Timestamp? updatedAt;

    factory MediaConsentModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
      final data = doc.data() ?? <String, dynamic>{};
      return MediaConsentModel(
        id: doc.id,
        siteId: data['siteId'] as String? ?? '',
        learnerId: data['learnerId'] as String? ?? '',
        photoCaptureAllowed: data['photoCaptureAllowed'] as bool? ?? false,
        shareWithLinkedParents: data['shareWithLinkedParents'] as bool? ?? false,
        marketingUseAllowed: data['marketingUseAllowed'] as bool? ?? false,
        consentStatus: data['consentStatus'] as String? ?? 'active',
        consentStartDate: data['consentStartDate'] as String?,
        consentEndDate: data['consentEndDate'] as String?,
        consentDocumentUrl: data['consentDocumentUrl'] as String?,
        createdAt: data['createdAt'] as Timestamp?,
        updatedAt: data['updatedAt'] as Timestamp?,
      );
    }

    Map<String, dynamic> toMap() => <String, dynamic>{
          'siteId': siteId,
          'learnerId': learnerId,
          'photoCaptureAllowed': photoCaptureAllowed,
          'shareWithLinkedParents': shareWithLinkedParents,
          'marketingUseAllowed': marketingUseAllowed,
          'consentStatus': consentStatus,
          'consentStartDate': consentStartDate,
          'consentEndDate': consentEndDate,
          'consentDocumentUrl': consentDocumentUrl,
          'createdAt': createdAt ?? Timestamp.now(),
          'updatedAt': updatedAt ?? Timestamp.now(),
        };
  }

  @immutable
  class RoomModel {
    const RoomModel({
      required this.id,
      required this.siteId,
      required this.name,
      this.capacity,
      this.createdAt,
      this.updatedAt,
    });

    final String id;
    final String siteId;
    final String name;
    final int? capacity;
    final Timestamp? createdAt;
    final Timestamp? updatedAt;

    factory RoomModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
      final data = doc.data() ?? <String, dynamic>{};
      return RoomModel(
        id: doc.id,
        siteId: data['siteId'] as String? ?? '',
        name: data['name'] as String? ?? '',
        capacity: data['capacity'] as int?,
        createdAt: data['createdAt'] as Timestamp?,
        updatedAt: data['updatedAt'] as Timestamp?,
      );
    }

    Map<String, dynamic> toMap() => <String, dynamic>{
          'siteId': siteId,
          'name': name,
          'capacity': capacity,
          'createdAt': createdAt ?? Timestamp.now(),
          'updatedAt': updatedAt ?? Timestamp.now(),
        };
  }

  @immutable
  class MissionSnapshotModel {
    const MissionSnapshotModel({
      required this.id,
      required this.missionId,
      required this.contentHash,
      required this.title,
      required this.description,
      required this.pillarCodes,
      this.skillIds,
      this.bodyJson,
      this.publisherType,
      this.publisherId,
      this.publishedAt,
      this.createdAt,
      this.updatedAt,
    });

    final String id;
    final String missionId;
    final String contentHash;
    final String title;
    final String description;
    final List<dynamic> pillarCodes;
    final List<String>? skillIds;
    final dynamic bodyJson;
    final String? publisherType;
    final String? publisherId;
    final Timestamp? publishedAt;
    final Timestamp? createdAt;
    final Timestamp? updatedAt;

    factory MissionSnapshotModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
      final data = doc.data() ?? <String, dynamic>{};
      return MissionSnapshotModel(
        id: doc.id,
        missionId: data['missionId'] as String? ?? '',
        contentHash: data['contentHash'] as String? ?? '',
        title: data['title'] as String? ?? '',
        description: data['description'] as String? ?? '',
        pillarCodes: List<dynamic>.from(data['pillarCodes'] as List? ?? const <dynamic>[]),
        skillIds: (data['skillIds'] as List?)?.map((e) => e.toString()).toList(),
        bodyJson: data['bodyJson'],
        publisherType: data['publisherType'] as String?,
        publisherId: data['publisherId'] as String?,
        publishedAt: data['publishedAt'] as Timestamp?,
        createdAt: data['createdAt'] as Timestamp?,
        updatedAt: data['updatedAt'] as Timestamp?,
      );
    }

    Map<String, dynamic> toMap() => <String, dynamic>{
          'missionId': missionId,
          'contentHash': contentHash,
          'title': title,
          'description': description,
          'pillarCodes': pillarCodes,
          'skillIds': skillIds,
          'bodyJson': bodyJson,
          'publisherType': publisherType,
          'publisherId': publisherId,
          'publishedAt': publishedAt,
          'createdAt': createdAt ?? Timestamp.now(),
          'updatedAt': updatedAt ?? Timestamp.now(),
        };
  }

  @immutable
  class RubricModel {
    const RubricModel({
      required this.id,
      required this.title,
      this.siteId,
      this.criteria = const <Map<String, dynamic>>[],
      this.createdAt,
      this.updatedAt,
    });

    final String id;
    final String title;
    final String? siteId;
    final List<Map<String, dynamic>> criteria;
    final Timestamp? createdAt;
    final Timestamp? updatedAt;

    factory RubricModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
      final data = doc.data() ?? <String, dynamic>{};
      return RubricModel(
        id: doc.id,
        title: data['title'] as String? ?? '',
        siteId: data['siteId'] as String?,
        criteria: (data['criteria'] as List?)?.map((c) => Map<String, dynamic>.from(c as Map)).toList() ?? const <Map<String, dynamic>>[],
        createdAt: data['createdAt'] as Timestamp?,
        updatedAt: data['updatedAt'] as Timestamp?,
      );
    }

    Map<String, dynamic> toMap() => <String, dynamic>{
          'title': title,
          'siteId': siteId,
          'criteria': criteria,
          'createdAt': createdAt ?? Timestamp.now(),
          'updatedAt': updatedAt ?? Timestamp.now(),
        };
  }

  @immutable
  class RubricApplicationModel {
    const RubricApplicationModel({
      required this.id,
      required this.siteId,
      required this.missionAttemptId,
      required this.educatorId,
      required this.rubricId,
      required this.scores,
      this.overallNote,
      this.createdAt,
      this.updatedAt,
    });

    final String id;
    final String siteId;
    final String missionAttemptId;
    final String educatorId;
    final String rubricId;
    final List<Map<String, dynamic>> scores;
    final String? overallNote;
    final Timestamp? createdAt;
    final Timestamp? updatedAt;

    factory RubricApplicationModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
      final data = doc.data() ?? <String, dynamic>{};
      return RubricApplicationModel(
        id: doc.id,
        siteId: data['siteId'] as String? ?? '',
        missionAttemptId: data['missionAttemptId'] as String? ?? '',
        educatorId: data['educatorId'] as String? ?? '',
        rubricId: data['rubricId'] as String? ?? '',
        scores: (data['scores'] as List?)?.map((s) => Map<String, dynamic>.from(s as Map)).toList() ?? const <Map<String, dynamic>>[],
        overallNote: data['overallNote'] as String?,
        createdAt: data['createdAt'] as Timestamp?,
        updatedAt: data['updatedAt'] as Timestamp?,
      );
    }

    Map<String, dynamic> toMap() => <String, dynamic>{
          'siteId': siteId,
          'missionAttemptId': missionAttemptId,
          'educatorId': educatorId,
          'rubricId': rubricId,
          'scores': scores,
          'overallNote': overallNote,
          'createdAt': createdAt ?? Timestamp.now(),
          'updatedAt': updatedAt ?? Timestamp.now(),
        };
  }

@immutable
class PickupAuthorizationModel {
  const PickupAuthorizationModel({
    required this.id,
    required this.siteId,
    required this.learnerId,
    required this.authorizedPickup,
    required this.updatedBy,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String siteId;
  final String learnerId;
  final List<Map<String, dynamic>> authorizedPickup;
  final String updatedBy;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory PickupAuthorizationModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return PickupAuthorizationModel(
      id: doc.id,
      siteId: data['siteId'] as String? ?? '',
      learnerId: data['learnerId'] as String? ?? '',
      authorizedPickup: (data['authorizedPickup'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? const <Map<String, dynamic>>[],
      updatedBy: data['updatedBy'] as String? ?? '',
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'siteId': siteId,
        'learnerId': learnerId,
        'authorizedPickup': authorizedPickup,
        'updatedBy': updatedBy,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class IntegrationConnectionModel {
  const IntegrationConnectionModel({
    required this.id,
    required this.ownerUserId,
    required this.provider,
    required this.status,
    this.scopesGranted,
    this.tokenRef,
    this.lastError,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String ownerUserId;
  final String provider;
  final String status;
  final List<String>? scopesGranted;
  final String? tokenRef;
  final String? lastError;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory IntegrationConnectionModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return IntegrationConnectionModel(
      id: doc.id,
      ownerUserId: data['ownerUserId'] as String? ?? '',
      provider: data['provider'] as String? ?? 'google_classroom',
      status: data['status'] as String? ?? 'active',
      scopesGranted: (data['scopesGranted'] as List?)?.map((e) => e.toString()).toList(),
      tokenRef: data['tokenRef'] as String?,
      lastError: data['lastError'] as String?,
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'ownerUserId': ownerUserId,
        'provider': provider,
        'status': status,
        'scopesGranted': scopesGranted,
        'tokenRef': tokenRef,
        'lastError': lastError,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class ExternalCourseLinkModel {
  const ExternalCourseLinkModel({
    required this.id,
    required this.provider,
    required this.providerCourseId,
    required this.ownerUserId,
    required this.siteId,
    required this.sessionId,
    this.syncPolicy,
    this.lastRosterSyncAt,
    this.lastCourseworkSyncAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String provider;
  final String providerCourseId;
  final String ownerUserId;
  final String siteId;
  final String sessionId;
  final String? syncPolicy;
  final Timestamp? lastRosterSyncAt;
  final Timestamp? lastCourseworkSyncAt;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory ExternalCourseLinkModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return ExternalCourseLinkModel(
      id: doc.id,
      provider: data['provider'] as String? ?? 'google_classroom',
      providerCourseId: data['providerCourseId'] as String? ?? '',
      ownerUserId: data['ownerUserId'] as String? ?? '',
      siteId: data['siteId'] as String? ?? '',
      sessionId: data['sessionId'] as String? ?? '',
      syncPolicy: data['syncPolicy'] as String?,
      lastRosterSyncAt: data['lastRosterSyncAt'] as Timestamp?,
      lastCourseworkSyncAt: data['lastCourseworkSyncAt'] as Timestamp?,
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'provider': provider,
        'providerCourseId': providerCourseId,
        'ownerUserId': ownerUserId,
        'siteId': siteId,
        'sessionId': sessionId,
        'syncPolicy': syncPolicy,
        'lastRosterSyncAt': lastRosterSyncAt,
        'lastCourseworkSyncAt': lastCourseworkSyncAt,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class ExternalUserLinkModel {
  const ExternalUserLinkModel({
    required this.id,
    required this.provider,
    required this.providerUserId,
    required this.scholesaUserId,
    required this.siteId,
    this.roleHint,
    this.matchSource,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String provider;
  final String providerUserId;
  final String scholesaUserId;
  final String siteId;
  final String? roleHint;
  final String? matchSource;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory ExternalUserLinkModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return ExternalUserLinkModel(
      id: doc.id,
      provider: data['provider'] as String? ?? 'google_classroom',
      providerUserId: data['providerUserId'] as String? ?? '',
      scholesaUserId: data['scholesaUserId'] as String? ?? '',
      siteId: data['siteId'] as String? ?? '',
      roleHint: data['roleHint'] as String?,
      matchSource: data['matchSource'] as String?,
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'provider': provider,
        'providerUserId': providerUserId,
        'scholesaUserId': scholesaUserId,
        'siteId': siteId,
        'roleHint': roleHint,
        'matchSource': matchSource,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class ExternalCourseworkLinkModel {
  const ExternalCourseworkLinkModel({
    required this.id,
    required this.provider,
    required this.providerCourseId,
    required this.providerCourseWorkId,
    required this.siteId,
    required this.missionId,
    this.sessionId,
    this.sessionOccurrenceId,
    required this.publishedBy,
    required this.publishedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String provider;
  final String providerCourseId;
  final String providerCourseWorkId;
  final String siteId;
  final String missionId;
  final String? sessionId;
  final String? sessionOccurrenceId;
  final String publishedBy;
  final Timestamp publishedAt;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory ExternalCourseworkLinkModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return ExternalCourseworkLinkModel(
      id: doc.id,
      provider: data['provider'] as String? ?? 'google_classroom',
      providerCourseId: data['providerCourseId'] as String? ?? '',
      providerCourseWorkId: data['providerCourseWorkId'] as String? ?? '',
      siteId: data['siteId'] as String? ?? '',
      missionId: data['missionId'] as String? ?? '',
      sessionId: data['sessionId'] as String?,
      sessionOccurrenceId: data['sessionOccurrenceId'] as String?,
      publishedBy: data['publishedBy'] as String? ?? '',
      publishedAt: data['publishedAt'] as Timestamp? ?? Timestamp.now(),
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'provider': provider,
        'providerCourseId': providerCourseId,
        'providerCourseWorkId': providerCourseWorkId,
        'siteId': siteId,
        'missionId': missionId,
        'sessionId': sessionId,
        'sessionOccurrenceId': sessionOccurrenceId,
        'publishedBy': publishedBy,
        'publishedAt': publishedAt,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class SyncJobModel {
  const SyncJobModel({
    required this.id,
    required this.type,
    required this.requestedBy,
    required this.status,
    this.siteId,
    this.cursor,
    this.nextPageToken,
    this.lastError,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String type;
  final String requestedBy;
  final String status;
  final String? siteId;
  final String? cursor;
  final String? nextPageToken;
  final String? lastError;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory SyncJobModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return SyncJobModel(
      id: doc.id,
      type: data['type'] as String? ?? 'roster_import',
      requestedBy: data['requestedBy'] as String? ?? '',
      status: data['status'] as String? ?? 'queued',
      siteId: data['siteId'] as String?,
      cursor: data['cursor'] as String?,
      nextPageToken: data['nextPageToken'] as String?,
      lastError: data['lastError'] as String?,
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'type': type,
        'requestedBy': requestedBy,
        'status': status,
        'siteId': siteId,
        'cursor': cursor,
        'nextPageToken': nextPageToken,
        'lastError': lastError,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class SyncCursorModel {
  const SyncCursorModel({
    required this.id,
    required this.ownerUserId,
    required this.provider,
    required this.providerCourseId,
    required this.cursorType,
    this.nextPageToken,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String ownerUserId;
  final String provider;
  final String providerCourseId;
  final String cursorType;
  final String? nextPageToken;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory SyncCursorModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return SyncCursorModel(
      id: doc.id,
      ownerUserId: data['ownerUserId'] as String? ?? '',
      provider: data['provider'] as String? ?? 'google_classroom',
      providerCourseId: data['providerCourseId'] as String? ?? '',
      cursorType: data['cursorType'] as String? ?? 'roster',
      nextPageToken: data['nextPageToken'] as String?,
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'ownerUserId': ownerUserId,
        'provider': provider,
        'providerCourseId': providerCourseId,
        'cursorType': cursorType,
        'nextPageToken': nextPageToken,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class GitHubConnectionModel {
  const GitHubConnectionModel({
    required this.id,
    required this.ownerUserId,
    required this.authType,
    required this.status,
    this.oauthScopesGranted,
    this.tokenRef,
    this.installationId,
    this.orgLogin,
    this.lastError,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String ownerUserId;
  final String authType;
  final String status;
  final List<String>? oauthScopesGranted;
  final String? tokenRef;
  final String? installationId;
  final String? orgLogin;
  final String? lastError;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory GitHubConnectionModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return GitHubConnectionModel(
      id: doc.id,
      ownerUserId: data['ownerUserId'] as String? ?? '',
      authType: data['authType'] as String? ?? 'oauth_app',
      status: data['status'] as String? ?? 'active',
      oauthScopesGranted: (data['oauthScopesGranted'] as List?)?.map((e) => e.toString()).toList(),
      tokenRef: data['tokenRef'] as String?,
      installationId: data['installationId'] as String?,
      orgLogin: data['orgLogin'] as String?,
      lastError: data['lastError'] as String?,
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'ownerUserId': ownerUserId,
        'authType': authType,
        'status': status,
        'oauthScopesGranted': oauthScopesGranted,
        'tokenRef': tokenRef,
        'installationId': installationId,
        'orgLogin': orgLogin,
        'lastError': lastError,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class ExternalRepoLinkModel {
  const ExternalRepoLinkModel({
    required this.id,
    required this.siteId,
    required this.repoFullName,
    required this.repoUrl,
    this.learnerId,
    this.educatorId,
    this.installationId,
    this.missionId,
    this.missionAttemptId,
    this.status,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String siteId;
  final String repoFullName;
  final String repoUrl;
  final String? learnerId;
  final String? educatorId;
  final String? installationId;
  final String? missionId;
  final String? missionAttemptId;
  final String? status;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory ExternalRepoLinkModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return ExternalRepoLinkModel(
      id: doc.id,
      siteId: data['siteId'] as String? ?? '',
      repoFullName: data['repoFullName'] as String? ?? '',
      repoUrl: data['repoUrl'] as String? ?? '',
      learnerId: data['learnerId'] as String?,
      educatorId: data['educatorId'] as String?,
      installationId: data['installationId'] as String?,
      missionId: data['missionId'] as String?,
      missionAttemptId: data['missionAttemptId'] as String?,
      status: data['status'] as String?,
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'siteId': siteId,
        'repoFullName': repoFullName,
        'repoUrl': repoUrl,
        'learnerId': learnerId,
        'educatorId': educatorId,
        'installationId': installationId,
        'missionId': missionId,
        'missionAttemptId': missionAttemptId,
        'status': status,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class ExternalPullRequestLinkModel {
  const ExternalPullRequestLinkModel({
    required this.id,
    required this.repoFullName,
    required this.prNumber,
    required this.prUrl,
    this.learnerId,
    this.missionAttemptId,
    this.status,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String repoFullName;
  final int prNumber;
  final String prUrl;
  final String? learnerId;
  final String? missionAttemptId;
  final String? status;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory ExternalPullRequestLinkModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return ExternalPullRequestLinkModel(
      id: doc.id,
      repoFullName: data['repoFullName'] as String? ?? '',
      prNumber: (data['prNumber'] as num?)?.toInt() ?? 0,
      prUrl: data['prUrl'] as String? ?? '',
      learnerId: data['learnerId'] as String?,
      missionAttemptId: data['missionAttemptId'] as String?,
      status: data['status'] as String?,
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'repoFullName': repoFullName,
        'prNumber': prNumber,
        'prUrl': prUrl,
        'learnerId': learnerId,
        'missionAttemptId': missionAttemptId,
        'status': status,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class GitHubWebhookDeliveryModel {
  const GitHubWebhookDeliveryModel({
    required this.id,
    required this.deliveryId,
    required this.event,
    this.repoFullName,
    this.installationId,
    this.processedAt,
    this.status,
    this.lastError,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String deliveryId;
  final String event;
  final String? repoFullName;
  final String? installationId;
  final Timestamp? processedAt;
  final String? status;
  final String? lastError;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory GitHubWebhookDeliveryModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return GitHubWebhookDeliveryModel(
      id: doc.id,
      deliveryId: data['deliveryId'] as String? ?? '',
      event: data['event'] as String? ?? '',
      repoFullName: data['repoFullName'] as String?,
      installationId: data['installationId'] as String?,
      processedAt: data['processedAt'] as Timestamp?,
      status: data['status'] as String?,
      lastError: data['lastError'] as String?,
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'deliveryId': deliveryId,
        'event': event,
        'repoFullName': repoFullName,
        'installationId': installationId,
        'processedAt': processedAt,
        'status': status,
        'lastError': lastError,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class AiDraftModel {
  const AiDraftModel({
    required this.id,
    required this.requesterId,
    required this.siteId,
    required this.title,
    required this.prompt,
    this.status = 'requested',
    this.reviewerId,
    this.reviewNotes,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String requesterId;
  final String siteId;
  final String title;
  final String prompt;
  final String status;
  final String? reviewerId;
  final String? reviewNotes;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory AiDraftModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return AiDraftModel(
      id: doc.id,
      requesterId: data['requesterId'] as String? ?? '',
      siteId: data['siteId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      prompt: data['prompt'] as String? ?? '',
      status: data['status'] as String? ?? 'requested',
      reviewerId: data['reviewerId'] as String?,
      reviewNotes: data['reviewNotes'] as String?,
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'requesterId': requesterId,
        'siteId': siteId,
        'title': title,
        'prompt': prompt,
        'status': status,
        'reviewerId': reviewerId,
        'reviewNotes': reviewNotes,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class OrderModel {
  const OrderModel({
    required this.id,
    required this.siteId,
    required this.userId,
    required this.productId,
    required this.amount,
    required this.currency,
    this.status = 'paid',
    this.entitlementRoles = const <String>[],
    this.createdAt,
    this.paidAt,
  });

  final String id;
  final String siteId;
  final String userId;
  final String productId;
  final String amount;
  final String currency;
  final String status;
  final List<String> entitlementRoles;
  final Timestamp? createdAt;
  final Timestamp? paidAt;

  factory OrderModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return OrderModel(
      id: doc.id,
      siteId: data['siteId'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      productId: data['productId'] as String? ?? '',
      amount: data['amount'] as String? ?? '0',
      currency: data['currency'] as String? ?? 'USD',
      status: data['status'] as String? ?? 'paid',
      entitlementRoles: List<String>.from(data['entitlementRoles'] as List? ?? const <String>[]),
      createdAt: data['createdAt'] as Timestamp?,
      paidAt: data['paidAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'siteId': siteId,
        'userId': userId,
        'productId': productId,
        'amount': amount,
        'currency': currency,
        'status': status,
        'entitlementRoles': entitlementRoles,
        'createdAt': createdAt ?? Timestamp.now(),
        'paidAt': paidAt ?? Timestamp.now(),
      };
}

@immutable
class EntitlementModel {
  const EntitlementModel({
    required this.id,
    required this.userId,
    required this.siteId,
    required this.productId,
    this.roles = const <String>[],
    this.expiresAt,
    this.createdAt,
  });

  final String id;
  final String userId;
  final String siteId;
  final String productId;
  final List<String> roles;
  final Timestamp? expiresAt;
  final Timestamp? createdAt;

  factory EntitlementModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return EntitlementModel(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      siteId: data['siteId'] as String? ?? '',
      productId: data['productId'] as String? ?? '',
      roles: List<String>.from(data['roles'] as List? ?? const <String>[]),
      expiresAt: data['expiresAt'] as Timestamp?,
      createdAt: data['createdAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'userId': userId,
        'siteId': siteId,
        'productId': productId,
        'roles': roles,
        'expiresAt': expiresAt,
        'createdAt': createdAt ?? Timestamp.now(),
      };
}

@immutable
class FulfillmentModel {
  const FulfillmentModel({
    required this.id,
    required this.orderId,
    required this.listingId,
    required this.userId,
    required this.status,
    this.siteId,
    this.note,
    this.fulfilledAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String orderId;
  final String listingId;
  final String userId;
  final String status;
  final String? siteId;
  final String? note;
  final Timestamp? fulfilledAt;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory FulfillmentModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return FulfillmentModel(
      id: doc.id,
      orderId: data['orderId'] as String? ?? '',
      listingId: data['listingId'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      status: data['status'] as String? ?? 'pending',
      siteId: data['siteId'] as String?,
      note: data['note'] as String?,
      fulfilledAt: data['fulfilledAt'] as Timestamp?,
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'orderId': orderId,
        'listingId': listingId,
        'userId': userId,
        'status': status,
        'siteId': siteId,
        'note': note,
        'fulfilledAt': fulfilledAt,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class AuditLogModel {
  const AuditLogModel({
    required this.id,
    required this.actorId,
    required this.actorRole,
    required this.action,
    required this.entityType,
    required this.entityId,
    this.siteId,
    this.details = const <String, dynamic>{},
    this.createdAt,
  });

  final String id;
  final String actorId;
  final String actorRole;
  final String action;
  final String entityType;
  final String entityId;
  final String? siteId;
  final Map<String, dynamic> details;
  final Timestamp? createdAt;

  factory AuditLogModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return AuditLogModel(
      id: doc.id,
      actorId: data['actorId'] as String? ?? '',
      actorRole: data['actorRole'] as String? ?? '',
      action: data['action'] as String? ?? '',
      entityType: data['entityType'] as String? ?? '',
      entityId: data['entityId'] as String? ?? '',
      siteId: data['siteId'] as String?,
      details: Map<String, dynamic>.from(data['details'] as Map? ?? <String, dynamic>{}),
      createdAt: data['createdAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'actorId': actorId,
        'actorRole': actorRole,
        'action': action,
        'entityType': entityType,
        'entityId': entityId,
        'siteId': siteId,
        'details': details,
        'createdAt': createdAt ?? Timestamp.now(),
      };
}
