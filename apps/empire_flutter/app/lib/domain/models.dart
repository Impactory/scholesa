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

  factory GuardianLinkModel.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
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
    this.readingLevelSelfCheck,
    this.diagnosticConfidenceBand,
    this.weeklyTargetMinutes,
    this.reminderSchedule,
    this.valuePrompt,
    this.portfolioHeadline,
    this.portfolioGoal,
    this.portfolioHighlight,
    this.ttsEnabled = false,
    this.reducedDistractionEnabled = false,
    this.keyboardOnlyEnabled = false,
    this.highContrastEnabled = false,
    this.onboardingCompleted = false,
    this.lastSetupAt,
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
  final String? readingLevelSelfCheck;
  final String? diagnosticConfidenceBand;
  final int? weeklyTargetMinutes;
  final String? reminderSchedule;
  final String? valuePrompt;
  final String? portfolioHeadline;
  final String? portfolioGoal;
  final String? portfolioHighlight;
  final bool ttsEnabled;
  final bool reducedDistractionEnabled;
  final bool keyboardOnlyEnabled;
  final bool highContrastEnabled;
  final bool onboardingCompleted;
  final Timestamp? lastSetupAt;
  final Map<String, dynamic>? emergencyContact;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory LearnerProfileModel.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return LearnerProfileModel(
      id: doc.id,
      learnerId: data['learnerId'] as String? ?? '',
      siteId: data['siteId'] as String? ?? '',
      legalName: data['legalName'] as String?,
      preferredName: data['preferredName'] as String?,
      dateOfBirth: data['dateOfBirth'] as String?,
      gradeLevel: data['gradeLevel'] as String?,
      strengths:
          List<String>.from(data['strengths'] as List? ?? const <String>[]),
      learningNeeds:
          List<String>.from(data['learningNeeds'] as List? ?? const <String>[]),
      interests:
          List<String>.from(data['interests'] as List? ?? const <String>[]),
      goals: List<String>.from(data['goals'] as List? ?? const <String>[]),
      readingLevelSelfCheck: data['readingLevelSelfCheck'] as String?,
      diagnosticConfidenceBand: data['diagnosticConfidenceBand'] as String?,
      weeklyTargetMinutes: data['weeklyTargetMinutes'] as int?,
      reminderSchedule: data['reminderSchedule'] as String?,
      valuePrompt: data['valuePrompt'] as String?,
      portfolioHeadline: data['portfolioHeadline'] as String?,
      portfolioGoal: data['portfolioGoal'] as String?,
      portfolioHighlight: data['portfolioHighlight'] as String?,
      ttsEnabled: data['ttsEnabled'] as bool? ?? false,
      reducedDistractionEnabled:
          data['reducedDistractionEnabled'] as bool? ?? false,
      keyboardOnlyEnabled: data['keyboardOnlyEnabled'] as bool? ?? false,
      highContrastEnabled: data['highContrastEnabled'] as bool? ?? false,
      onboardingCompleted: data['onboardingCompleted'] as bool? ?? false,
      lastSetupAt: data['lastSetupAt'] as Timestamp?,
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
        'readingLevelSelfCheck': readingLevelSelfCheck,
        'diagnosticConfidenceBand': diagnosticConfidenceBand,
        'weeklyTargetMinutes': weeklyTargetMinutes,
        'reminderSchedule': reminderSchedule,
        'valuePrompt': valuePrompt,
        'portfolioHeadline': portfolioHeadline,
        'portfolioGoal': portfolioGoal,
        'portfolioHighlight': portfolioHighlight,
        'ttsEnabled': ttsEnabled,
        'reducedDistractionEnabled': reducedDistractionEnabled,
        'keyboardOnlyEnabled': keyboardOnlyEnabled,
        'highContrastEnabled': highContrastEnabled,
        'onboardingCompleted': onboardingCompleted,
        'lastSetupAt': lastSetupAt,
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

  factory ParentProfileModel.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return ParentProfileModel(
      id: doc.id,
      parentId: data['parentId'] as String? ?? '',
      siteId: data['siteId'] as String? ?? '',
      legalName: data['legalName'] as String?,
      preferredName: data['preferredName'] as String?,
      phone: data['phone'] as String?,
      preferredLanguage: data['preferredLanguage'] as String?,
      communicationPreferences: List<String>.from(
          data['communicationPreferences'] as List? ?? const <String>[]),
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
      adminUserIds:
          List<String>.from(data['adminUserIds'] as List? ?? const <String>[]),
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
      pillarEmphasis: List<String>.from(
          data['pillarEmphasis'] as List? ?? const <String>[]),
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

  factory SessionOccurrenceModel.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
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

  factory AttendanceRecordModel.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
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
  const PillarModel(
      {required this.code, required this.title, this.description, this.order});

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

  factory SkillMasteryModel.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return SkillMasteryModel(
      id: doc.id,
      learnerId: data['learnerId'] as String? ?? '',
      skillId: data['skillId'] as String? ?? '',
      level: (data['level'] as num?)?.toInt() ?? 0,
      evidenceIds:
          List<String>.from(data['evidenceIds'] as List? ?? const <String>[]),
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
class CapabilityModel {
  const CapabilityModel({
    required this.id,
    required this.title,
    required this.normalizedTitle,
    required this.pillarCode,
    this.siteId,
    this.descriptor,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String normalizedTitle;
  final String pillarCode;
  final String? siteId;
  final String? descriptor;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory CapabilityModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return CapabilityModel(
      id: doc.id,
      title: data['title'] as String? ?? '',
      normalizedTitle: data['normalizedTitle'] as String? ?? '',
      pillarCode: data['pillarCode'] as String? ?? '',
      siteId: data['siteId'] as String?,
      descriptor: data['descriptor'] as String?,
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'title': title,
        'normalizedTitle': normalizedTitle,
        'pillarCode': pillarCode,
        'siteId': siteId,
        'descriptor': descriptor,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class CapabilityMasteryModel {
  const CapabilityMasteryModel({
    required this.id,
    required this.learnerId,
    required this.capabilityId,
    required this.pillarCode,
    required this.latestLevel,
    required this.highestLevel,
    this.siteId,
    this.latestEvidenceId,
    this.latestMissionAttemptId,
    this.evidenceIds = const <String>[],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String learnerId;
  final String capabilityId;
  final String pillarCode;
  final int latestLevel;
  final int highestLevel;
  final String? siteId;
  final String? latestEvidenceId;
  final String? latestMissionAttemptId;
  final List<String> evidenceIds;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory CapabilityMasteryModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return CapabilityMasteryModel(
      id: doc.id,
      learnerId: data['learnerId'] as String? ?? '',
      capabilityId: data['capabilityId'] as String? ?? '',
      pillarCode: data['pillarCode'] as String? ?? '',
      latestLevel: (data['latestLevel'] as num?)?.toInt() ?? 0,
      highestLevel: (data['highestLevel'] as num?)?.toInt() ?? 0,
      siteId: data['siteId'] as String?,
      latestEvidenceId: data['latestEvidenceId'] as String?,
      latestMissionAttemptId: data['latestMissionAttemptId'] as String?,
      evidenceIds:
          List<String>.from(data['evidenceIds'] as List? ?? const <String>[]),
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'learnerId': learnerId,
        'capabilityId': capabilityId,
        'pillarCode': pillarCode,
        'latestLevel': latestLevel,
        'highestLevel': highestLevel,
        'siteId': siteId,
        'latestEvidenceId': latestEvidenceId,
        'latestMissionAttemptId': latestMissionAttemptId,
        'evidenceIds': evidenceIds,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class CapabilityGrowthEventModel {
  const CapabilityGrowthEventModel({
    required this.id,
    required this.learnerId,
    required this.capabilityId,
    required this.pillarCode,
    required this.level,
    required this.rawScore,
    required this.maxScore,
    this.siteId,
    this.evidenceId,
    this.missionAttemptId,
    this.rubricApplicationId,
    this.educatorId,
    this.createdAt,
  });

  final String id;
  final String learnerId;
  final String capabilityId;
  final String pillarCode;
  final int level;
  final int rawScore;
  final int maxScore;
  final String? siteId;
  final String? evidenceId;
  final String? missionAttemptId;
  final String? rubricApplicationId;
  final String? educatorId;
  final Timestamp? createdAt;

  factory CapabilityGrowthEventModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return CapabilityGrowthEventModel(
      id: doc.id,
      learnerId: data['learnerId'] as String? ?? '',
      capabilityId: data['capabilityId'] as String? ?? '',
      pillarCode: data['pillarCode'] as String? ?? '',
      level: (data['level'] as num?)?.toInt() ?? 0,
      rawScore: (data['rawScore'] as num?)?.toInt() ?? 0,
      maxScore: (data['maxScore'] as num?)?.toInt() ?? 0,
      siteId: data['siteId'] as String?,
      evidenceId: data['evidenceId'] as String?,
      missionAttemptId: data['missionAttemptId'] as String?,
      rubricApplicationId: data['rubricApplicationId'] as String?,
      educatorId: data['educatorId'] as String?,
      createdAt: data['createdAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'learnerId': learnerId,
        'capabilityId': capabilityId,
        'pillarCode': pillarCode,
        'level': level,
        'rawScore': rawScore,
        'maxScore': maxScore,
        'siteId': siteId,
        'evidenceId': evidenceId,
        'missionAttemptId': missionAttemptId,
        'rubricApplicationId': rubricApplicationId,
        'educatorId': educatorId,
        'createdAt': createdAt ?? Timestamp.now(),
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
      pillarCodes:
          List<String>.from(data['pillarCodes'] as List? ?? const <String>[]),
      siteId: data['siteId'] as String?,
      skillIds:
          List<String>.from(data['skillIds'] as List? ?? const <String>[]),
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
      missionIds:
          List<String>.from(data['missionIds'] as List? ?? const <String>[]),
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

  factory MissionAttemptModel.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return MissionAttemptModel(
      id: doc.id,
      siteId: data['siteId'] as String? ?? '',
      missionId: data['missionId'] as String? ?? '',
      learnerId: data['learnerId'] as String? ?? '',
      status: data['status'] as String? ?? 'draft',
      sessionOccurrenceId: data['sessionOccurrenceId'] as String?,
      reflection: data['reflection'] as String?,
      artifactUrls:
          List<String>.from(data['artifactUrls'] as List? ?? const <String>[]),
      pillarCodes:
          List<String>.from(data['pillarCodes'] as List? ?? const <String>[]),
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
    this.evidenceRecordIds = const <String>[],
    this.capabilityIds = const <String>[],
    this.capabilityTitles = const <String>[],
    this.growthEventIds = const <String>[],
    this.missionAttemptId,
    this.rubricApplicationId,
    this.proofBundleId,
    this.proofOfLearningStatus,
    this.aiAssistanceUsed,
    this.aiAssistanceDetails,
    this.aiDisclosureStatus,
    this.educatorId,
    this.verificationPrompt,
    this.verificationStatus,
    this.source,
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
  final List<String> evidenceRecordIds;
  final List<String> capabilityIds;
  final List<String> capabilityTitles;
  final List<String> growthEventIds;
  final String? missionAttemptId;
  final String? rubricApplicationId;
  final String? proofBundleId;
  final String? proofOfLearningStatus;
  final bool? aiAssistanceUsed;
  final String? aiAssistanceDetails;
  final String? aiDisclosureStatus;
  final String? educatorId;
  final String? verificationPrompt;
  final String? verificationStatus;
  final String? source;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory PortfolioItemModel.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return PortfolioItemModel(
      id: doc.id,
      siteId: data['siteId'] as String? ?? '',
      learnerId: data['learnerId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      description: data['description'] as String?,
      artifactUrls:
          List<String>.from(data['artifactUrls'] as List? ?? const <String>[]),
      pillarCodes:
          List<String>.from(data['pillarCodes'] as List? ?? const <String>[]),
      skillIds:
          List<String>.from(data['skillIds'] as List? ?? const <String>[]),
      evidenceRecordIds: List<String>.from(
        data['evidenceRecordIds'] as List? ?? const <String>[],
      ),
      capabilityIds:
          List<String>.from(data['capabilityIds'] as List? ?? const <String>[]),
      capabilityTitles: List<String>.from(
        data['capabilityTitles'] as List? ?? const <String>[],
      ),
      growthEventIds:
          List<String>.from(data['growthEventIds'] as List? ?? const <String>[]),
      missionAttemptId: data['missionAttemptId'] as String?,
      rubricApplicationId: data['rubricApplicationId'] as String?,
      proofBundleId: data['proofBundleId'] as String?,
        proofOfLearningStatus: data['proofOfLearningStatus'] as String?,
        aiAssistanceUsed: data['aiAssistanceUsed'] as bool?,
        aiAssistanceDetails: data['aiAssistanceDetails'] as String?,
        aiDisclosureStatus: data['aiDisclosureStatus'] as String?,
      educatorId: data['educatorId'] as String?,
      verificationPrompt: data['verificationPrompt'] as String?,
      verificationStatus: data['verificationStatus'] as String?,
      source: data['source'] as String?,
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
        'evidenceRecordIds': evidenceRecordIds,
        'capabilityIds': capabilityIds,
        'capabilityTitles': capabilityTitles,
        'growthEventIds': growthEventIds,
        'missionAttemptId': missionAttemptId,
        'rubricApplicationId': rubricApplicationId,
        'proofBundleId': proofBundleId,
        'proofOfLearningStatus': proofOfLearningStatus,
        'aiAssistanceUsed': aiAssistanceUsed,
        'aiAssistanceDetails': aiAssistanceDetails,
        'aiDisclosureStatus': aiDisclosureStatus,
        'educatorId': educatorId,
        'verificationPrompt': verificationPrompt,
        'verificationStatus': verificationStatus,
        'source': source,
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
      pillarCodes:
          List<String>.from(data['pillarCodes'] as List? ?? const <String>[]),
      skillIds:
          List<String>.from(data['skillIds'] as List? ?? const <String>[]),
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

  factory AccountabilityCycleModel.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
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

  factory AccountabilityKPIModel.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
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

  factory AccountabilityCommitmentModel.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return AccountabilityCommitmentModel(
      id: doc.id,
      cycleId: data['cycleId'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      role: data['role'] as String? ?? 'learner',
      statement: data['statement'] as String? ?? '',
      pillarCodes:
          List<String>.from(data['pillarCodes'] as List? ?? const <String>[]),
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

  factory AccountabilityReviewModel.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
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

  factory AnnouncementModel.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
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

  factory MessageThreadModel.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return MessageThreadModel(
      id: doc.id,
      siteId: data['siteId'] as String? ?? '',
      participantIds: List<String>.from(
          data['participantIds'] as List? ?? const <String>[]),
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
      bullets: (data['bullets'] as List?)?.whereType<String>().toList() ??
          const <String>[],
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
    final List<dynamic> rawBlocks =
        data['bodyJson'] as List<dynamic>? ?? const <dynamic>[];
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
    this.productId,
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
  final String? productId;
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

  factory MarketplaceListingModel.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return MarketplaceListingModel(
      id: doc.id,
      partnerOrgId: data['partnerOrgId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      price: data['price'] as String? ?? '0',
      currency: data['currency'] as String? ?? 'USD',
      productId: data['productId'] as String?,
      description: data['description'] as String?,
      status: data['status'] as String? ?? 'draft',
      entitlementRoles: List<String>.from(
          data['entitlementRoles'] as List? ?? const <String>[]),
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
        'productId': productId,
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

  factory PartnerContractModel.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
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

  factory PartnerDeliverableModel.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
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

  factory SiteCheckInOutModel.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
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

  factory IncidentReportModel.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
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

  factory ExternalIdentityLinkModel.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return ExternalIdentityLinkModel(
      id: doc.id,
      siteId: data['siteId'] as String? ?? '',
      provider: data['provider'] as String? ?? '',
      providerUserId: data['providerUserId'] as String? ?? '',
      status: data['status'] as String? ?? 'unmatched',
      scholesaUserId: data['scholesaUserId'] as String?,
      suggestedMatches: (data['suggestedMatches'] as List?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
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

  factory MediaConsentModel.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
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

  factory MissionSnapshotModel.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return MissionSnapshotModel(
      id: doc.id,
      missionId: data['missionId'] as String? ?? '',
      contentHash: data['contentHash'] as String? ?? '',
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      pillarCodes:
          List<dynamic>.from(data['pillarCodes'] as List? ?? const <dynamic>[]),
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
      criteria: (data['criteria'] as List?)
              ?.map((c) => Map<String, dynamic>.from(c as Map))
              .toList() ??
          const <Map<String, dynamic>>[],
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

  factory RubricApplicationModel.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return RubricApplicationModel(
      id: doc.id,
      siteId: data['siteId'] as String? ?? '',
      missionAttemptId: data['missionAttemptId'] as String? ?? '',
      educatorId: data['educatorId'] as String? ?? '',
      rubricId: data['rubricId'] as String? ?? '',
      scores: (data['scores'] as List?)
              ?.map((s) => Map<String, dynamic>.from(s as Map))
              .toList() ??
          const <Map<String, dynamic>>[],
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

  factory PickupAuthorizationModel.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return PickupAuthorizationModel(
      id: doc.id,
      siteId: data['siteId'] as String? ?? '',
      learnerId: data['learnerId'] as String? ?? '',
      authorizedPickup: (data['authorizedPickup'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          const <Map<String, dynamic>>[],
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

  factory IntegrationConnectionModel.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return IntegrationConnectionModel(
      id: doc.id,
      ownerUserId: data['ownerUserId'] as String? ?? '',
      provider: data['provider'] as String? ?? 'google_classroom',
      status: data['status'] as String? ?? 'active',
      scopesGranted:
          (data['scopesGranted'] as List?)?.map((e) => e.toString()).toList(),
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

  factory ExternalCourseLinkModel.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
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

  factory ExternalUserLinkModel.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
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

  factory ExternalCourseworkLinkModel.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
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
class LtiPlatformRegistrationModel {
  const LtiPlatformRegistrationModel({
    required this.id,
    required this.siteId,
    required this.ownerUserId,
    required this.issuer,
    required this.clientId,
    required this.deploymentId,
    required this.authLoginUrl,
    required this.accessTokenUrl,
    required this.jwksUrl,
    this.platformName,
    this.status = 'active',
    this.lineItemsScope = true,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String siteId;
  final String ownerUserId;
  final String issuer;
  final String clientId;
  final String deploymentId;
  final String authLoginUrl;
  final String accessTokenUrl;
  final String jwksUrl;
  final String? platformName;
  final String status;
  final bool lineItemsScope;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory LtiPlatformRegistrationModel.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return LtiPlatformRegistrationModel(
      id: doc.id,
      siteId: data['siteId'] as String? ?? '',
      ownerUserId: data['ownerUserId'] as String? ?? '',
      issuer: data['issuer'] as String? ?? '',
      clientId: data['clientId'] as String? ?? '',
      deploymentId: data['deploymentId'] as String? ?? '',
      authLoginUrl: data['authLoginUrl'] as String? ?? '',
      accessTokenUrl: data['accessTokenUrl'] as String? ?? '',
      jwksUrl: data['jwksUrl'] as String? ?? '',
      platformName: data['platformName'] as String?,
      status: data['status'] as String? ?? 'active',
      lineItemsScope: data['lineItemsScope'] as bool? ?? true,
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'siteId': siteId,
        'ownerUserId': ownerUserId,
        'issuer': issuer,
        'clientId': clientId,
        'deploymentId': deploymentId,
        'authLoginUrl': authLoginUrl,
        'accessTokenUrl': accessTokenUrl,
        'jwksUrl': jwksUrl,
        'platformName': platformName,
        'status': status,
        'lineItemsScope': lineItemsScope,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class LtiResourceLinkModel {
  const LtiResourceLinkModel({
    required this.id,
    required this.registrationId,
    required this.siteId,
    required this.resourceLinkId,
    this.title,
    this.missionId,
    this.sessionId,
    this.targetPath,
    this.locale,
    this.lineItemId,
    this.lineItemUrl,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String registrationId;
  final String siteId;
  final String resourceLinkId;
  final String? title;
  final String? missionId;
  final String? sessionId;
  final String? targetPath;
  final String? locale;
  final String? lineItemId;
  final String? lineItemUrl;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory LtiResourceLinkModel.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return LtiResourceLinkModel(
      id: doc.id,
      registrationId: data['registrationId'] as String? ?? '',
      siteId: data['siteId'] as String? ?? '',
      resourceLinkId: data['resourceLinkId'] as String? ?? '',
      title: data['title'] as String?,
      missionId: data['missionId'] as String?,
      sessionId: data['sessionId'] as String?,
      targetPath: data['targetPath'] as String?,
      locale: data['locale'] as String?,
      lineItemId: data['lineItemId'] as String?,
      lineItemUrl: data['lineItemUrl'] as String?,
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'registrationId': registrationId,
        'siteId': siteId,
        'resourceLinkId': resourceLinkId,
        'title': title,
        'missionId': missionId,
        'sessionId': sessionId,
        'targetPath': targetPath,
        'locale': locale,
        'lineItemId': lineItemId,
        'lineItemUrl': lineItemUrl,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class LtiGradePassbackJobModel {
  const LtiGradePassbackJobModel({
    required this.id,
    required this.siteId,
    required this.learnerId,
    required this.missionAttemptId,
    required this.requestedBy,
    required this.scoreGiven,
    required this.scoreMaximum,
    required this.idempotencyKey,
    this.lineItemId,
    this.lineItemUrl,
    this.activityProgress = 'Submitted',
    this.gradingProgress = 'PendingManual',
    this.status = 'queued',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String siteId;
  final String learnerId;
  final String missionAttemptId;
  final String requestedBy;
  final String? lineItemId;
  final String? lineItemUrl;
  final double scoreGiven;
  final double scoreMaximum;
  final String activityProgress;
  final String gradingProgress;
  final String status;
  final String idempotencyKey;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory LtiGradePassbackJobModel.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return LtiGradePassbackJobModel(
      id: doc.id,
      siteId: data['siteId'] as String? ?? '',
      learnerId: data['learnerId'] as String? ?? '',
      missionAttemptId: data['missionAttemptId'] as String? ?? '',
      requestedBy: data['requestedBy'] as String? ?? '',
      lineItemId: data['lineItemId'] as String?,
      lineItemUrl: data['lineItemUrl'] as String?,
      scoreGiven: (data['scoreGiven'] as num?)?.toDouble() ?? 0,
      scoreMaximum: (data['scoreMaximum'] as num?)?.toDouble() ?? 0,
      activityProgress: data['activityProgress'] as String? ?? 'Submitted',
      gradingProgress: data['gradingProgress'] as String? ?? 'PendingManual',
      status: data['status'] as String? ?? 'queued',
      idempotencyKey: data['idempotencyKey'] as String? ?? '',
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'siteId': siteId,
        'learnerId': learnerId,
        'missionAttemptId': missionAttemptId,
        'requestedBy': requestedBy,
        'lineItemId': lineItemId,
        'lineItemUrl': lineItemUrl,
        'scoreGiven': scoreGiven,
        'scoreMaximum': scoreMaximum,
        'activityProgress': activityProgress,
        'gradingProgress': gradingProgress,
        'status': status,
        'idempotencyKey': idempotencyKey,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

Timestamp? _timestampOrNull(dynamic value) {
  if (value is Timestamp) return value;
  if (value is DateTime) return Timestamp.fromDate(value);
  return null;
}

List<String> _stringListOrEmpty(dynamic value) {
  if (value is! List) return const <String>[];
  return value.map((dynamic entry) => entry.toString()).toList(growable: false);
}

List<double> _doubleListOrEmpty(dynamic value) {
  if (value is! List) return const <double>[];
  return value
      .map((dynamic entry) => entry is num
          ? entry.toDouble()
          : double.tryParse(entry.toString()) ?? 0)
      .toList(growable: false);
}

List<FederatedLearningContributionDetailModel> _contributionDetailListOrEmpty(
  dynamic value,
) {
  if (value is! List) {
    return const <FederatedLearningContributionDetailModel>[];
  }
  return value
      .map((dynamic entry) => _mapOrNull(entry))
      .whereType<Map<String, dynamic>>()
      .map(FederatedLearningContributionDetailModel.fromMap)
      .toList(growable: false);
}

List<FederatedLearningSiteContributionSummaryModel>
    _siteContributionSummaryListOrEmpty(dynamic value) {
  if (value is! List) {
    return const <FederatedLearningSiteContributionSummaryModel>[];
  }
  return value
      .map((dynamic entry) => _mapOrNull(entry))
      .whereType<Map<String, dynamic>>()
      .map(FederatedLearningSiteContributionSummaryModel.fromMap)
      .toList(growable: false);
}

List<FederatedLearningEnvironmentBreakdownEntryModel>
    _environmentBreakdownListOrEmpty(dynamic value) {
  if (value is! List) {
    return const <FederatedLearningEnvironmentBreakdownEntryModel>[];
  }
  return value
      .map((dynamic entry) => _mapOrNull(entry))
      .whereType<Map<String, dynamic>>()
      .map(FederatedLearningEnvironmentBreakdownEntryModel.fromMap)
      .toList(growable: false);
}

Map<String, dynamic>? _mapOrNull(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map(
      (dynamic key, dynamic entryValue) => MapEntry(key.toString(), entryValue),
    );
  }
  return null;
}

@immutable
class FederatedLearningContributionDetailModel {
  const FederatedLearningContributionDetailModel({
    required this.summaryId,
    required this.siteId,
    required this.sampleCount,
    required this.payloadBytes,
    required this.vectorLength,
    required this.updateNorm,
    required this.schemaVersion,
    required this.rawWeight,
    required this.normScale,
    required this.effectiveWeight,
    this.runtimeTarget,
    this.traceId,
    this.payloadDigest,
  });

  final String summaryId;
  final String siteId;
  final int sampleCount;
  final int payloadBytes;
  final int vectorLength;
  final double updateNorm;
  final String schemaVersion;
  final String? runtimeTarget;
  final String? traceId;
  final String? payloadDigest;
  final double rawWeight;
  final double normScale;
  final double effectiveWeight;

  factory FederatedLearningContributionDetailModel.fromMap(
    Map<String, dynamic> data,
  ) {
    return FederatedLearningContributionDetailModel(
      summaryId: data['summaryId'] as String? ?? '',
      siteId: data['siteId'] as String? ?? '',
      sampleCount: (data['sampleCount'] as num?)?.toInt() ?? 0,
      payloadBytes: (data['payloadBytes'] as num?)?.toInt() ?? 0,
      vectorLength: (data['vectorLength'] as num?)?.toInt() ?? 0,
      updateNorm: (data['updateNorm'] as num?)?.toDouble() ?? 0,
      schemaVersion: data['schemaVersion'] as String? ?? '',
      runtimeTarget: data['runtimeTarget'] as String?,
      traceId: data['traceId'] as String?,
      payloadDigest: data['payloadDigest'] as String?,
      rawWeight: (data['rawWeight'] as num?)?.toDouble() ?? 0,
      normScale: (data['normScale'] as num?)?.toDouble() ?? 0,
      effectiveWeight: (data['effectiveWeight'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'summaryId': summaryId,
        'siteId': siteId,
        'sampleCount': sampleCount,
        'payloadBytes': payloadBytes,
        'vectorLength': vectorLength,
        'updateNorm': updateNorm,
        'schemaVersion': schemaVersion,
        'runtimeTarget': runtimeTarget,
        'traceId': traceId,
        'payloadDigest': payloadDigest,
        'rawWeight': rawWeight,
        'normScale': normScale,
        'effectiveWeight': effectiveWeight,
      };
}

@immutable
class FederatedLearningSiteContributionSummaryModel {
  const FederatedLearningSiteContributionSummaryModel({
    required this.siteId,
    required this.summaryCount,
    required this.totalSampleCount,
    required this.totalPayloadBytes,
    required this.rawWeight,
    required this.effectiveWeight,
    required this.dampedSummaryCount,
    required this.minUpdateNorm,
    required this.maxUpdateNorm,
  });

  final String siteId;
  final int summaryCount;
  final int totalSampleCount;
  final int totalPayloadBytes;
  final double rawWeight;
  final double effectiveWeight;
  final int dampedSummaryCount;
  final double minUpdateNorm;
  final double maxUpdateNorm;

  factory FederatedLearningSiteContributionSummaryModel.fromMap(
    Map<String, dynamic> data,
  ) {
    return FederatedLearningSiteContributionSummaryModel(
      siteId: data['siteId'] as String? ?? '',
      summaryCount: (data['summaryCount'] as num?)?.toInt() ?? 0,
      totalSampleCount: (data['totalSampleCount'] as num?)?.toInt() ?? 0,
      totalPayloadBytes: (data['totalPayloadBytes'] as num?)?.toInt() ?? 0,
      rawWeight: (data['rawWeight'] as num?)?.toDouble() ?? 0,
      effectiveWeight: (data['effectiveWeight'] as num?)?.toDouble() ?? 0,
      dampedSummaryCount: (data['dampedSummaryCount'] as num?)?.toInt() ?? 0,
      minUpdateNorm: (data['minUpdateNorm'] as num?)?.toDouble() ?? 0,
      maxUpdateNorm: (data['maxUpdateNorm'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'siteId': siteId,
        'summaryCount': summaryCount,
        'totalSampleCount': totalSampleCount,
        'totalPayloadBytes': totalPayloadBytes,
        'rawWeight': rawWeight,
        'effectiveWeight': effectiveWeight,
        'dampedSummaryCount': dampedSummaryCount,
        'minUpdateNorm': minUpdateNorm,
        'maxUpdateNorm': maxUpdateNorm,
      };
}

@immutable
class FederatedLearningEnvironmentBreakdownEntryModel {
  const FederatedLearningEnvironmentBreakdownEntryModel({
    required this.value,
    required this.count,
  });

  final String value;
  final int count;

  factory FederatedLearningEnvironmentBreakdownEntryModel.fromMap(
    Map<String, dynamic> data,
  ) {
    return FederatedLearningEnvironmentBreakdownEntryModel(
      value: data['value'] as String? ?? '',
      count: (data['count'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'value': value,
        'count': count,
      };
}

@immutable
class FederatedLearningExperimentModel {
  const FederatedLearningExperimentModel({
    required this.id,
    required this.name,
    required this.runtimeTarget,
    required this.status,
    required this.mergeStrategy,
    required this.requireWarmStartForTraining,
    required this.maxLocalEpochs,
    required this.maxLocalSteps,
    required this.maxTrainingWindowSeconds,
    required this.allowedSiteIds,
    required this.aggregateThreshold,
    required this.minDistinctSiteCount,
    required this.rawUpdateMaxBytes,
    required this.enablePrototypeUploads,
    this.description,
    this.featureFlagId,
    this.featureFlag,
    this.updatedBy,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String runtimeTarget;
  final String status;
  final String mergeStrategy;
  final bool requireWarmStartForTraining;
  final int maxLocalEpochs;
  final int maxLocalSteps;
  final int maxTrainingWindowSeconds;
  final List<String> allowedSiteIds;
  final int aggregateThreshold;
  final int minDistinctSiteCount;
  final int rawUpdateMaxBytes;
  final bool enablePrototypeUploads;
  final String? description;
  final String? featureFlagId;
  final Map<String, dynamic>? featureFlag;
  final String? updatedBy;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  bool get acceptsPrototypeUploads =>
      enablePrototypeUploads && (status == 'pilot_ready' || status == 'active');

  factory FederatedLearningExperimentModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return FederatedLearningExperimentModel.fromMap(
        doc.id, doc.data() ?? <String, dynamic>{});
  }

  factory FederatedLearningExperimentModel.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return FederatedLearningExperimentModel(
      id: id,
      name: data['name'] as String? ?? id,
      description: data['description'] as String?,
      runtimeTarget: data['runtimeTarget'] as String? ?? 'flutter_mobile',
      status: data['status'] as String? ?? 'draft',
      mergeStrategy: data['mergeStrategy'] as String? ??
          'norm_capped_weighted_runtime_vector_average_v2',
      requireWarmStartForTraining:
          data['requireWarmStartForTraining'] as bool? ?? false,
      maxLocalEpochs: (data['maxLocalEpochs'] as num?)?.toInt() ?? 3,
      maxLocalSteps: (data['maxLocalSteps'] as num?)?.toInt() ?? 24,
      maxTrainingWindowSeconds:
          (data['maxTrainingWindowSeconds'] as num?)?.toInt() ?? 1800,
      allowedSiteIds: _stringListOrEmpty(data['allowedSiteIds']),
      aggregateThreshold: (data['aggregateThreshold'] as num?)?.toInt() ?? 25,
      minDistinctSiteCount:
          (data['minDistinctSiteCount'] as num?)?.toInt() ?? 2,
      rawUpdateMaxBytes: (data['rawUpdateMaxBytes'] as num?)?.toInt() ?? 16384,
      enablePrototypeUploads: data['enablePrototypeUploads'] as bool? ?? false,
      featureFlagId: data['featureFlagId'] as String?,
      featureFlag: _mapOrNull(data['featureFlag']),
      updatedBy: data['updatedBy'] as String?,
      createdAt: _timestampOrNull(data['createdAt']),
      updatedAt: _timestampOrNull(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'name': name,
        'description': description,
        'runtimeTarget': runtimeTarget,
        'status': status,
        'mergeStrategy': mergeStrategy,
        'requireWarmStartForTraining': requireWarmStartForTraining,
        'maxLocalEpochs': maxLocalEpochs,
        'maxLocalSteps': maxLocalSteps,
        'maxTrainingWindowSeconds': maxTrainingWindowSeconds,
        'allowedSiteIds': allowedSiteIds,
        'aggregateThreshold': aggregateThreshold,
        'minDistinctSiteCount': minDistinctSiteCount,
        'rawUpdateMaxBytes': rawUpdateMaxBytes,
        'enablePrototypeUploads': enablePrototypeUploads,
        'featureFlagId': featureFlagId,
        'featureFlag': featureFlag,
        'updatedBy': updatedBy,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class FederatedLearningUpdateSummaryModel {
  const FederatedLearningUpdateSummaryModel({
    required this.id,
    required this.experimentId,
    required this.siteId,
    required this.traceId,
    required this.schemaVersion,
    required this.sampleCount,
    required this.vectorLength,
    required this.payloadBytes,
    required this.updateNorm,
    required this.payloadDigest,
    required this.batteryState,
    required this.networkType,
    this.optimizerStrategy,
    this.localEpochCount,
    this.localStepCount,
    this.trainingWindowSeconds,
    this.warmStartPackageId,
    this.warmStartDeliveryRecordId,
    this.warmStartModelVersion,
    this.runtimeTarget,
    this.requestedBy,
    this.status,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String experimentId;
  final String siteId;
  final String traceId;
  final String schemaVersion;
  final int sampleCount;
  final int vectorLength;
  final int payloadBytes;
  final double updateNorm;
  final String payloadDigest;
  final String batteryState;
  final String networkType;
  final String? optimizerStrategy;
  final int? localEpochCount;
  final int? localStepCount;
  final int? trainingWindowSeconds;
  final String? warmStartPackageId;
  final String? warmStartDeliveryRecordId;
  final String? warmStartModelVersion;
  final String? runtimeTarget;
  final String? requestedBy;
  final String? status;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory FederatedLearningUpdateSummaryModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return FederatedLearningUpdateSummaryModel.fromMap(
      doc.id,
      doc.data() ?? <String, dynamic>{},
    );
  }

  factory FederatedLearningUpdateSummaryModel.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return FederatedLearningUpdateSummaryModel(
      id: id,
      experimentId: data['experimentId'] as String? ?? '',
      siteId: data['siteId'] as String? ?? '',
      traceId: data['traceId'] as String? ?? '',
      schemaVersion: data['schemaVersion'] as String? ?? 'v1',
      sampleCount: (data['sampleCount'] as num?)?.toInt() ?? 0,
      vectorLength: (data['vectorLength'] as num?)?.toInt() ?? 0,
      payloadBytes: (data['payloadBytes'] as num?)?.toInt() ?? 0,
      updateNorm: (data['updateNorm'] as num?)?.toDouble() ?? 0,
      payloadDigest: data['payloadDigest'] as String? ?? '',
      batteryState: data['batteryState'] as String? ?? 'unknown',
      networkType: data['networkType'] as String? ?? 'unknown',
      optimizerStrategy: data['optimizerStrategy'] as String?,
      localEpochCount: (data['localEpochCount'] as num?)?.toInt(),
      localStepCount: (data['localStepCount'] as num?)?.toInt(),
      trainingWindowSeconds: (data['trainingWindowSeconds'] as num?)?.toInt(),
      warmStartPackageId: data['warmStartPackageId'] as String?,
      warmStartDeliveryRecordId: data['warmStartDeliveryRecordId'] as String?,
      warmStartModelVersion: data['warmStartModelVersion'] as String?,
      runtimeTarget: data['runtimeTarget'] as String?,
      requestedBy: data['requestedBy'] as String?,
      status: data['status'] as String?,
      createdAt: _timestampOrNull(data['createdAt']),
      updatedAt: _timestampOrNull(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'experimentId': experimentId,
        'siteId': siteId,
        'traceId': traceId,
        'schemaVersion': schemaVersion,
        'sampleCount': sampleCount,
        'vectorLength': vectorLength,
        'payloadBytes': payloadBytes,
        'updateNorm': updateNorm,
        'payloadDigest': payloadDigest,
        'batteryState': batteryState,
        'networkType': networkType,
        'optimizerStrategy': optimizerStrategy,
        'localEpochCount': localEpochCount,
        'localStepCount': localStepCount,
        'trainingWindowSeconds': trainingWindowSeconds,
        'warmStartPackageId': warmStartPackageId,
        'warmStartDeliveryRecordId': warmStartDeliveryRecordId,
        'warmStartModelVersion': warmStartModelVersion,
        'runtimeTarget': runtimeTarget,
        'requestedBy': requestedBy,
        'status': status,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class FederatedLearningExperimentReviewRecordModel {
  const FederatedLearningExperimentReviewRecordModel({
    required this.id,
    required this.experimentId,
    required this.status,
    required this.privacyReviewComplete,
    required this.signoffChecklistComplete,
    required this.rolloutRiskAcknowledged,
    this.notes,
    this.reviewedBy,
    this.reviewedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String experimentId;
  final String status;
  final bool privacyReviewComplete;
  final bool signoffChecklistComplete;
  final bool rolloutRiskAcknowledged;
  final String? notes;
  final String? reviewedBy;
  final Timestamp? reviewedAt;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory FederatedLearningExperimentReviewRecordModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return FederatedLearningExperimentReviewRecordModel.fromMap(
      doc.id,
      doc.data() ?? <String, dynamic>{},
    );
  }

  factory FederatedLearningExperimentReviewRecordModel.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return FederatedLearningExperimentReviewRecordModel(
      id: id,
      experimentId: data['experimentId'] as String? ?? '',
      status: data['status'] as String? ?? 'pending',
      privacyReviewComplete: data['privacyReviewComplete'] as bool? ?? false,
      signoffChecklistComplete:
          data['signoffChecklistComplete'] as bool? ?? false,
      rolloutRiskAcknowledged:
          data['rolloutRiskAcknowledged'] as bool? ?? false,
      notes: data['notes'] as String?,
      reviewedBy: data['reviewedBy'] as String?,
      reviewedAt: _timestampOrNull(data['reviewedAt']),
      createdAt: _timestampOrNull(data['createdAt']),
      updatedAt: _timestampOrNull(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'experimentId': experimentId,
        'status': status,
        'privacyReviewComplete': privacyReviewComplete,
        'signoffChecklistComplete': signoffChecklistComplete,
        'rolloutRiskAcknowledged': rolloutRiskAcknowledged,
        'notes': notes,
        'reviewedBy': reviewedBy,
        'reviewedAt': reviewedAt ?? Timestamp.now(),
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class FederatedLearningAggregationRunModel {
  const FederatedLearningAggregationRunModel({
    required this.id,
    required this.experimentId,
    required this.status,
    required this.threshold,
    required this.thresholdMet,
    this.mergeArtifactId,
    this.mergeArtifactStatus,
    this.candidateModelPackageId,
    this.candidateModelPackageStatus,
    this.candidateModelPackageFormat,
    this.mergeStrategy,
    this.normCap,
    this.effectiveTotalWeight,
    this.rawTotalWeight,
    this.dampedSummaryCount,
    this.minUpdateNorm,
    this.maxUpdateNorm,
    this.oldestSummaryCreatedAtMs,
    this.newestSummaryCreatedAtMs,
    this.summaryFreshnessSpanSeconds,
    required this.batteryStateBreakdown,
    required this.networkTypeBreakdown,
    this.boundedDigest,
    this.payloadFormat,
    this.modelVersion,
    this.runtimeVectorLength,
    this.runtimeVectorDigest,
    required this.triggerSummaryId,
    required this.summaryIds,
    required this.summaryCount,
    required this.distinctSiteCount,
    required this.contributingSiteIds,
    required this.totalSampleCount,
    required this.maxVectorLength,
    required this.totalPayloadBytes,
    required this.averageUpdateNorm,
    required this.schemaVersions,
    required this.runtimeTargets,
    required this.optimizerStrategies,
    this.compatibilityKey,
    this.warmStartPackageId,
    this.warmStartModelVersion,
    required this.contributionDetails,
    required this.siteContributionSummaries,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String experimentId;
  final String status;
  final int threshold;
  final bool thresholdMet;
  final String? mergeArtifactId;
  final String? mergeArtifactStatus;
  final String? candidateModelPackageId;
  final String? candidateModelPackageStatus;
  final String? candidateModelPackageFormat;
  final String? mergeStrategy;
  final double? normCap;
  final double? effectiveTotalWeight;
  final double? rawTotalWeight;
  final int? dampedSummaryCount;
  final double? minUpdateNorm;
  final double? maxUpdateNorm;
  final int? oldestSummaryCreatedAtMs;
  final int? newestSummaryCreatedAtMs;
  final int? summaryFreshnessSpanSeconds;
  final List<FederatedLearningEnvironmentBreakdownEntryModel>
      batteryStateBreakdown;
  final List<FederatedLearningEnvironmentBreakdownEntryModel>
      networkTypeBreakdown;
  final String? boundedDigest;
  final String? payloadFormat;
  final String? modelVersion;
  final int? runtimeVectorLength;
  final String? runtimeVectorDigest;
  final String triggerSummaryId;
  final List<String> summaryIds;
  final int summaryCount;
  final int distinctSiteCount;
  final List<String> contributingSiteIds;
  final int totalSampleCount;
  final int maxVectorLength;
  final int totalPayloadBytes;
  final double averageUpdateNorm;
  final List<String> schemaVersions;
  final List<String> runtimeTargets;
  final List<String> optimizerStrategies;
  final String? compatibilityKey;
  final String? warmStartPackageId;
  final String? warmStartModelVersion;
  final List<FederatedLearningContributionDetailModel> contributionDetails;
  final List<FederatedLearningSiteContributionSummaryModel>
      siteContributionSummaries;
  final String? createdBy;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory FederatedLearningAggregationRunModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return FederatedLearningAggregationRunModel.fromMap(
      doc.id,
      doc.data() ?? <String, dynamic>{},
    );
  }

  factory FederatedLearningAggregationRunModel.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return FederatedLearningAggregationRunModel(
      id: id,
      experimentId: data['experimentId'] as String? ?? '',
      status: data['status'] as String? ?? 'materialized',
      threshold: (data['threshold'] as num?)?.toInt() ?? 0,
      thresholdMet: data['thresholdMet'] as bool? ?? false,
      mergeArtifactId: data['mergeArtifactId'] as String?,
      mergeArtifactStatus: data['mergeArtifactStatus'] as String?,
      candidateModelPackageId: data['candidateModelPackageId'] as String?,
      candidateModelPackageStatus:
          data['candidateModelPackageStatus'] as String?,
      candidateModelPackageFormat:
          data['candidateModelPackageFormat'] as String?,
      mergeStrategy: data['mergeStrategy'] as String?,
      normCap: (data['normCap'] as num?)?.toDouble(),
      effectiveTotalWeight: (data['effectiveTotalWeight'] as num?)?.toDouble(),
      rawTotalWeight: (data['rawTotalWeight'] as num?)?.toDouble(),
      dampedSummaryCount: (data['dampedSummaryCount'] as num?)?.toInt(),
      minUpdateNorm: (data['minUpdateNorm'] as num?)?.toDouble(),
      maxUpdateNorm: (data['maxUpdateNorm'] as num?)?.toDouble(),
      oldestSummaryCreatedAtMs:
          (data['oldestSummaryCreatedAtMs'] as num?)?.toInt(),
      newestSummaryCreatedAtMs:
          (data['newestSummaryCreatedAtMs'] as num?)?.toInt(),
      summaryFreshnessSpanSeconds:
          (data['summaryFreshnessSpanSeconds'] as num?)?.toInt(),
      batteryStateBreakdown: _environmentBreakdownListOrEmpty(
        data['batteryStateBreakdown'],
      ),
      networkTypeBreakdown: _environmentBreakdownListOrEmpty(
        data['networkTypeBreakdown'],
      ),
      boundedDigest: data['boundedDigest'] as String?,
      payloadFormat: data['payloadFormat'] as String?,
      modelVersion: data['modelVersion'] as String?,
      runtimeVectorLength: (data['runtimeVectorLength'] as num?)?.toInt(),
      runtimeVectorDigest: data['runtimeVectorDigest'] as String?,
      triggerSummaryId: data['triggerSummaryId'] as String? ?? '',
      summaryIds: _stringListOrEmpty(data['summaryIds']),
      summaryCount: (data['summaryCount'] as num?)?.toInt() ?? 0,
      distinctSiteCount: (data['distinctSiteCount'] as num?)?.toInt() ?? 0,
      contributingSiteIds: _stringListOrEmpty(data['contributingSiteIds']),
      totalSampleCount: (data['totalSampleCount'] as num?)?.toInt() ?? 0,
      maxVectorLength: (data['maxVectorLength'] as num?)?.toInt() ?? 0,
      totalPayloadBytes: (data['totalPayloadBytes'] as num?)?.toInt() ?? 0,
      averageUpdateNorm: (data['averageUpdateNorm'] as num?)?.toDouble() ?? 0,
      schemaVersions: _stringListOrEmpty(data['schemaVersions']),
      runtimeTargets: _stringListOrEmpty(data['runtimeTargets']),
      optimizerStrategies: _stringListOrEmpty(data['optimizerStrategies']),
      compatibilityKey: data['compatibilityKey'] as String?,
      warmStartPackageId: data['warmStartPackageId'] as String?,
      warmStartModelVersion: data['warmStartModelVersion'] as String?,
      contributionDetails:
          _contributionDetailListOrEmpty(data['contributionDetails']),
      siteContributionSummaries: _siteContributionSummaryListOrEmpty(
        data['siteContributionSummaries'],
      ),
      createdBy: data['createdBy'] as String?,
      createdAt: _timestampOrNull(data['createdAt']),
      updatedAt: _timestampOrNull(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'experimentId': experimentId,
        'status': status,
        'threshold': threshold,
        'thresholdMet': thresholdMet,
        'mergeArtifactId': mergeArtifactId,
        'mergeArtifactStatus': mergeArtifactStatus,
        'candidateModelPackageId': candidateModelPackageId,
        'candidateModelPackageStatus': candidateModelPackageStatus,
        'candidateModelPackageFormat': candidateModelPackageFormat,
        'mergeStrategy': mergeStrategy,
        'normCap': normCap,
        'effectiveTotalWeight': effectiveTotalWeight,
        'rawTotalWeight': rawTotalWeight,
        'dampedSummaryCount': dampedSummaryCount,
        'minUpdateNorm': minUpdateNorm,
        'maxUpdateNorm': maxUpdateNorm,
        'oldestSummaryCreatedAtMs': oldestSummaryCreatedAtMs,
        'newestSummaryCreatedAtMs': newestSummaryCreatedAtMs,
        'summaryFreshnessSpanSeconds': summaryFreshnessSpanSeconds,
        'batteryStateBreakdown': batteryStateBreakdown
            .map((FederatedLearningEnvironmentBreakdownEntryModel entry) =>
                entry.toMap())
            .toList(growable: false),
        'networkTypeBreakdown': networkTypeBreakdown
            .map((FederatedLearningEnvironmentBreakdownEntryModel entry) =>
                entry.toMap())
            .toList(growable: false),
        'boundedDigest': boundedDigest,
        'payloadFormat': payloadFormat,
        'modelVersion': modelVersion,
        'runtimeVectorLength': runtimeVectorLength,
        'runtimeVectorDigest': runtimeVectorDigest,
        'triggerSummaryId': triggerSummaryId,
        'summaryIds': summaryIds,
        'summaryCount': summaryCount,
        'distinctSiteCount': distinctSiteCount,
        'contributingSiteIds': contributingSiteIds,
        'totalSampleCount': totalSampleCount,
        'maxVectorLength': maxVectorLength,
        'totalPayloadBytes': totalPayloadBytes,
        'averageUpdateNorm': averageUpdateNorm,
        'schemaVersions': schemaVersions,
        'runtimeTargets': runtimeTargets,
        'optimizerStrategies': optimizerStrategies,
        'compatibilityKey': compatibilityKey,
        'warmStartPackageId': warmStartPackageId,
        'warmStartModelVersion': warmStartModelVersion,
        'contributionDetails': contributionDetails
            .map((FederatedLearningContributionDetailModel detail) =>
                detail.toMap())
            .toList(growable: false),
        'siteContributionSummaries': siteContributionSummaries
            .map((FederatedLearningSiteContributionSummaryModel summary) =>
                summary.toMap())
            .toList(growable: false),
        'createdBy': createdBy,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class FederatedLearningMergeArtifactModel {
  const FederatedLearningMergeArtifactModel({
    required this.id,
    required this.experimentId,
    required this.aggregationRunId,
    required this.status,
    required this.mergeStrategy,
    required this.normCap,
    required this.effectiveTotalWeight,
    required this.rawTotalWeight,
    required this.dampedSummaryCount,
    required this.minUpdateNorm,
    required this.maxUpdateNorm,
    this.oldestSummaryCreatedAtMs,
    this.newestSummaryCreatedAtMs,
    this.summaryFreshnessSpanSeconds,
    required this.batteryStateBreakdown,
    required this.networkTypeBreakdown,
    required this.triggerSummaryId,
    required this.summaryIds,
    required this.boundedDigest,
    required this.payloadFormat,
    required this.modelVersion,
    required this.runtimeVectorLength,
    required this.runtimeVector,
    required this.runtimeVectorDigest,
    required this.sampleCount,
    required this.summaryCount,
    required this.distinctSiteCount,
    required this.contributingSiteIds,
    required this.schemaVersions,
    required this.runtimeTargets,
    required this.maxVectorLength,
    required this.totalPayloadBytes,
    required this.averageUpdateNorm,
    required this.optimizerStrategies,
    this.compatibilityKey,
    this.warmStartPackageId,
    this.warmStartModelVersion,
    required this.contributionDetails,
    required this.siteContributionSummaries,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String experimentId;
  final String aggregationRunId;
  final String status;
  final String mergeStrategy;
  final double normCap;
  final double effectiveTotalWeight;
  final double rawTotalWeight;
  final int dampedSummaryCount;
  final double minUpdateNorm;
  final double maxUpdateNorm;
  final int? oldestSummaryCreatedAtMs;
  final int? newestSummaryCreatedAtMs;
  final int? summaryFreshnessSpanSeconds;
  final List<FederatedLearningEnvironmentBreakdownEntryModel>
      batteryStateBreakdown;
  final List<FederatedLearningEnvironmentBreakdownEntryModel>
      networkTypeBreakdown;
  final String triggerSummaryId;
  final List<String> summaryIds;
  final String boundedDigest;
  final String payloadFormat;
  final String modelVersion;
  final int runtimeVectorLength;
  final List<double> runtimeVector;
  final String runtimeVectorDigest;
  final int sampleCount;
  final int summaryCount;
  final int distinctSiteCount;
  final List<String> contributingSiteIds;
  final List<String> schemaVersions;
  final List<String> runtimeTargets;
  final int maxVectorLength;
  final int totalPayloadBytes;
  final double averageUpdateNorm;
  final List<String> optimizerStrategies;
  final String? compatibilityKey;
  final String? warmStartPackageId;
  final String? warmStartModelVersion;
  final List<FederatedLearningContributionDetailModel> contributionDetails;
  final List<FederatedLearningSiteContributionSummaryModel>
      siteContributionSummaries;
  final String? createdBy;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory FederatedLearningMergeArtifactModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return FederatedLearningMergeArtifactModel.fromMap(
      doc.id,
      doc.data() ?? <String, dynamic>{},
    );
  }

  factory FederatedLearningMergeArtifactModel.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return FederatedLearningMergeArtifactModel(
      id: id,
      experimentId: data['experimentId'] as String? ?? '',
      aggregationRunId: data['aggregationRunId'] as String? ?? '',
      status: data['status'] as String? ?? 'generated',
      mergeStrategy: data['mergeStrategy'] as String? ?? '',
      normCap: (data['normCap'] as num?)?.toDouble() ?? 0,
      effectiveTotalWeight:
          (data['effectiveTotalWeight'] as num?)?.toDouble() ?? 0,
      rawTotalWeight: (data['rawTotalWeight'] as num?)?.toDouble() ?? 0,
      dampedSummaryCount: (data['dampedSummaryCount'] as num?)?.toInt() ?? 0,
      minUpdateNorm: (data['minUpdateNorm'] as num?)?.toDouble() ?? 0,
      maxUpdateNorm: (data['maxUpdateNorm'] as num?)?.toDouble() ?? 0,
      oldestSummaryCreatedAtMs:
          (data['oldestSummaryCreatedAtMs'] as num?)?.toInt(),
      newestSummaryCreatedAtMs:
          (data['newestSummaryCreatedAtMs'] as num?)?.toInt(),
      summaryFreshnessSpanSeconds:
          (data['summaryFreshnessSpanSeconds'] as num?)?.toInt(),
      batteryStateBreakdown: _environmentBreakdownListOrEmpty(
        data['batteryStateBreakdown'],
      ),
      networkTypeBreakdown: _environmentBreakdownListOrEmpty(
        data['networkTypeBreakdown'],
      ),
      triggerSummaryId: data['triggerSummaryId'] as String? ?? '',
      summaryIds: _stringListOrEmpty(data['summaryIds']),
      boundedDigest: data['boundedDigest'] as String? ?? '',
      payloadFormat: data['payloadFormat'] as String? ?? 'runtime_vector_v1',
      modelVersion: data['modelVersion'] as String? ?? 'fl_runtime_model_v1',
      runtimeVectorLength: (data['runtimeVectorLength'] as num?)?.toInt() ?? 0,
      runtimeVector: _doubleListOrEmpty(data['runtimeVector']),
      runtimeVectorDigest: data['runtimeVectorDigest'] as String? ?? '',
      sampleCount: (data['sampleCount'] as num?)?.toInt() ?? 0,
      summaryCount: (data['summaryCount'] as num?)?.toInt() ?? 0,
      distinctSiteCount: (data['distinctSiteCount'] as num?)?.toInt() ?? 0,
      contributingSiteIds: _stringListOrEmpty(data['contributingSiteIds']),
      schemaVersions: _stringListOrEmpty(data['schemaVersions']),
      runtimeTargets: _stringListOrEmpty(data['runtimeTargets']),
      maxVectorLength: (data['maxVectorLength'] as num?)?.toInt() ?? 0,
      totalPayloadBytes: (data['totalPayloadBytes'] as num?)?.toInt() ?? 0,
      averageUpdateNorm: (data['averageUpdateNorm'] as num?)?.toDouble() ?? 0,
      optimizerStrategies: _stringListOrEmpty(data['optimizerStrategies']),
      compatibilityKey: data['compatibilityKey'] as String?,
      warmStartPackageId: data['warmStartPackageId'] as String?,
      warmStartModelVersion: data['warmStartModelVersion'] as String?,
      contributionDetails:
          _contributionDetailListOrEmpty(data['contributionDetails']),
      siteContributionSummaries: _siteContributionSummaryListOrEmpty(
        data['siteContributionSummaries'],
      ),
      createdBy: data['createdBy'] as String?,
      createdAt: _timestampOrNull(data['createdAt']),
      updatedAt: _timestampOrNull(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'experimentId': experimentId,
        'aggregationRunId': aggregationRunId,
        'status': status,
        'mergeStrategy': mergeStrategy,
        'normCap': normCap,
        'effectiveTotalWeight': effectiveTotalWeight,
        'rawTotalWeight': rawTotalWeight,
        'dampedSummaryCount': dampedSummaryCount,
        'minUpdateNorm': minUpdateNorm,
        'maxUpdateNorm': maxUpdateNorm,
        'oldestSummaryCreatedAtMs': oldestSummaryCreatedAtMs,
        'newestSummaryCreatedAtMs': newestSummaryCreatedAtMs,
        'summaryFreshnessSpanSeconds': summaryFreshnessSpanSeconds,
        'batteryStateBreakdown': batteryStateBreakdown
            .map((FederatedLearningEnvironmentBreakdownEntryModel entry) =>
                entry.toMap())
            .toList(growable: false),
        'networkTypeBreakdown': networkTypeBreakdown
            .map((FederatedLearningEnvironmentBreakdownEntryModel entry) =>
                entry.toMap())
            .toList(growable: false),
        'triggerSummaryId': triggerSummaryId,
        'summaryIds': summaryIds,
        'boundedDigest': boundedDigest,
        'payloadFormat': payloadFormat,
        'modelVersion': modelVersion,
        'runtimeVectorLength': runtimeVectorLength,
        'runtimeVector': runtimeVector,
        'runtimeVectorDigest': runtimeVectorDigest,
        'sampleCount': sampleCount,
        'summaryCount': summaryCount,
        'distinctSiteCount': distinctSiteCount,
        'contributingSiteIds': contributingSiteIds,
        'schemaVersions': schemaVersions,
        'runtimeTargets': runtimeTargets,
        'maxVectorLength': maxVectorLength,
        'totalPayloadBytes': totalPayloadBytes,
        'averageUpdateNorm': averageUpdateNorm,
        'optimizerStrategies': optimizerStrategies,
        'compatibilityKey': compatibilityKey,
        'warmStartPackageId': warmStartPackageId,
        'warmStartModelVersion': warmStartModelVersion,
        'contributionDetails': contributionDetails
            .map((FederatedLearningContributionDetailModel detail) =>
                detail.toMap())
            .toList(growable: false),
        'siteContributionSummaries': siteContributionSummaries
            .map((FederatedLearningSiteContributionSummaryModel summary) =>
                summary.toMap())
            .toList(growable: false),
        'createdBy': createdBy,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class FederatedLearningCandidateModelPackageModel {
  const FederatedLearningCandidateModelPackageModel({
    required this.id,
    required this.experimentId,
    required this.aggregationRunId,
    required this.mergeArtifactId,
    required this.status,
    this.mergeStrategy,
    required this.triggerSummaryId,
    required this.summaryIds,
    required this.packageFormat,
    required this.rolloutStatus,
    this.latestPromotionRecordId,
    this.latestPromotionStatus,
    this.latestPromotionRevocationRecordId,
    this.latestPilotEvidenceRecordId,
    this.latestPilotEvidenceStatus,
    this.latestPilotApprovalRecordId,
    this.latestPilotApprovalStatus,
    this.latestPilotExecutionRecordId,
    this.latestPilotExecutionStatus,
    this.latestRuntimeDeliveryRecordId,
    this.latestRuntimeDeliveryStatus,
    required this.modelVersion,
    required this.packageDigest,
    required this.boundedDigest,
    this.normCap,
    this.effectiveTotalWeight,
    this.rawTotalWeight,
    this.dampedSummaryCount,
    this.minUpdateNorm,
    this.maxUpdateNorm,
    this.oldestSummaryCreatedAtMs,
    this.newestSummaryCreatedAtMs,
    this.summaryFreshnessSpanSeconds,
    required this.batteryStateBreakdown,
    required this.networkTypeBreakdown,
    required this.runtimeVectorLength,
    required this.runtimeVector,
    required this.runtimeVectorDigest,
    required this.sampleCount,
    required this.summaryCount,
    required this.distinctSiteCount,
    required this.contributingSiteIds,
    required this.schemaVersions,
    required this.runtimeTargets,
    required this.maxVectorLength,
    required this.totalPayloadBytes,
    required this.averageUpdateNorm,
    required this.optimizerStrategies,
    this.compatibilityKey,
    this.warmStartPackageId,
    this.warmStartModelVersion,
    required this.contributionDetails,
    required this.siteContributionSummaries,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String experimentId;
  final String aggregationRunId;
  final String mergeArtifactId;
  final String status;
  final String? mergeStrategy;
  final String triggerSummaryId;
  final List<String> summaryIds;
  final String packageFormat;
  final String rolloutStatus;
  final String? latestPromotionRecordId;
  final String? latestPromotionStatus;
  final String? latestPromotionRevocationRecordId;
  final String? latestPilotEvidenceRecordId;
  final String? latestPilotEvidenceStatus;
  final String? latestPilotApprovalRecordId;
  final String? latestPilotApprovalStatus;
  final String? latestPilotExecutionRecordId;
  final String? latestPilotExecutionStatus;
  final String? latestRuntimeDeliveryRecordId;
  final String? latestRuntimeDeliveryStatus;
  final String modelVersion;
  final String packageDigest;
  final String boundedDigest;
  final double? normCap;
  final double? effectiveTotalWeight;
  final double? rawTotalWeight;
  final int? dampedSummaryCount;
  final double? minUpdateNorm;
  final double? maxUpdateNorm;
  final int? oldestSummaryCreatedAtMs;
  final int? newestSummaryCreatedAtMs;
  final int? summaryFreshnessSpanSeconds;
  final List<FederatedLearningEnvironmentBreakdownEntryModel>
      batteryStateBreakdown;
  final List<FederatedLearningEnvironmentBreakdownEntryModel>
      networkTypeBreakdown;
  final int runtimeVectorLength;
  final List<double> runtimeVector;
  final String runtimeVectorDigest;
  final int sampleCount;
  final int summaryCount;
  final int distinctSiteCount;
  final List<String> contributingSiteIds;
  final List<String> schemaVersions;
  final List<String> runtimeTargets;
  final int maxVectorLength;
  final int totalPayloadBytes;
  final double averageUpdateNorm;
  final List<String> optimizerStrategies;
  final String? compatibilityKey;
  final String? warmStartPackageId;
  final String? warmStartModelVersion;
  final List<FederatedLearningContributionDetailModel> contributionDetails;
  final List<FederatedLearningSiteContributionSummaryModel>
      siteContributionSummaries;
  final String? createdBy;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory FederatedLearningCandidateModelPackageModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return FederatedLearningCandidateModelPackageModel.fromMap(
      doc.id,
      doc.data() ?? <String, dynamic>{},
    );
  }

  factory FederatedLearningCandidateModelPackageModel.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return FederatedLearningCandidateModelPackageModel(
      id: id,
      experimentId: data['experimentId'] as String? ?? '',
      aggregationRunId: data['aggregationRunId'] as String? ?? '',
      mergeArtifactId: data['mergeArtifactId'] as String? ?? '',
      status: data['status'] as String? ?? 'staged',
      mergeStrategy: data['mergeStrategy'] as String?,
      triggerSummaryId: data['triggerSummaryId'] as String? ?? '',
      summaryIds: _stringListOrEmpty(data['summaryIds']),
      packageFormat: data['packageFormat'] as String? ?? '',
      rolloutStatus: data['rolloutStatus'] as String? ?? '',
      latestPromotionRecordId: data['latestPromotionRecordId'] as String?,
      latestPromotionStatus: data['latestPromotionStatus'] as String?,
      latestPromotionRevocationRecordId:
          data['latestPromotionRevocationRecordId'] as String?,
      latestPilotEvidenceRecordId:
          data['latestPilotEvidenceRecordId'] as String?,
      latestPilotEvidenceStatus: data['latestPilotEvidenceStatus'] as String?,
      latestPilotApprovalRecordId:
          data['latestPilotApprovalRecordId'] as String?,
      latestPilotApprovalStatus: data['latestPilotApprovalStatus'] as String?,
      latestPilotExecutionRecordId:
          data['latestPilotExecutionRecordId'] as String?,
      latestPilotExecutionStatus: data['latestPilotExecutionStatus'] as String?,
      latestRuntimeDeliveryRecordId:
          data['latestRuntimeDeliveryRecordId'] as String?,
      latestRuntimeDeliveryStatus:
          data['latestRuntimeDeliveryStatus'] as String?,
      modelVersion: data['modelVersion'] as String? ?? 'fl_runtime_model_v1',
      packageDigest: data['packageDigest'] as String? ?? '',
      boundedDigest: data['boundedDigest'] as String? ?? '',
      normCap: (data['normCap'] as num?)?.toDouble(),
      effectiveTotalWeight: (data['effectiveTotalWeight'] as num?)?.toDouble(),
      rawTotalWeight: (data['rawTotalWeight'] as num?)?.toDouble(),
      dampedSummaryCount: (data['dampedSummaryCount'] as num?)?.toInt(),
      minUpdateNorm: (data['minUpdateNorm'] as num?)?.toDouble(),
      maxUpdateNorm: (data['maxUpdateNorm'] as num?)?.toDouble(),
      oldestSummaryCreatedAtMs:
          (data['oldestSummaryCreatedAtMs'] as num?)?.toInt(),
      newestSummaryCreatedAtMs:
          (data['newestSummaryCreatedAtMs'] as num?)?.toInt(),
      summaryFreshnessSpanSeconds:
          (data['summaryFreshnessSpanSeconds'] as num?)?.toInt(),
      batteryStateBreakdown: _environmentBreakdownListOrEmpty(
        data['batteryStateBreakdown'],
      ),
      networkTypeBreakdown: _environmentBreakdownListOrEmpty(
        data['networkTypeBreakdown'],
      ),
      runtimeVectorLength: (data['runtimeVectorLength'] as num?)?.toInt() ?? 0,
      runtimeVector: _doubleListOrEmpty(data['runtimeVector']),
      runtimeVectorDigest: data['runtimeVectorDigest'] as String? ?? '',
      sampleCount: (data['sampleCount'] as num?)?.toInt() ?? 0,
      summaryCount: (data['summaryCount'] as num?)?.toInt() ?? 0,
      distinctSiteCount: (data['distinctSiteCount'] as num?)?.toInt() ?? 0,
      contributingSiteIds: _stringListOrEmpty(data['contributingSiteIds']),
      schemaVersions: _stringListOrEmpty(data['schemaVersions']),
      runtimeTargets: _stringListOrEmpty(data['runtimeTargets']),
      maxVectorLength: (data['maxVectorLength'] as num?)?.toInt() ?? 0,
      totalPayloadBytes: (data['totalPayloadBytes'] as num?)?.toInt() ?? 0,
      averageUpdateNorm: (data['averageUpdateNorm'] as num?)?.toDouble() ?? 0,
      optimizerStrategies: _stringListOrEmpty(data['optimizerStrategies']),
      compatibilityKey: data['compatibilityKey'] as String?,
      warmStartPackageId: data['warmStartPackageId'] as String?,
      warmStartModelVersion: data['warmStartModelVersion'] as String?,
      contributionDetails:
          _contributionDetailListOrEmpty(data['contributionDetails']),
      siteContributionSummaries: _siteContributionSummaryListOrEmpty(
        data['siteContributionSummaries'],
      ),
      createdBy: data['createdBy'] as String?,
      createdAt: _timestampOrNull(data['createdAt']),
      updatedAt: _timestampOrNull(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'experimentId': experimentId,
        'aggregationRunId': aggregationRunId,
        'mergeArtifactId': mergeArtifactId,
        'status': status,
        'mergeStrategy': mergeStrategy,
        'triggerSummaryId': triggerSummaryId,
        'summaryIds': summaryIds,
        'packageFormat': packageFormat,
        'rolloutStatus': rolloutStatus,
        'latestPromotionRecordId': latestPromotionRecordId,
        'latestPromotionStatus': latestPromotionStatus,
        'latestPromotionRevocationRecordId': latestPromotionRevocationRecordId,
        'latestPilotEvidenceRecordId': latestPilotEvidenceRecordId,
        'latestPilotEvidenceStatus': latestPilotEvidenceStatus,
        'latestPilotApprovalRecordId': latestPilotApprovalRecordId,
        'latestPilotApprovalStatus': latestPilotApprovalStatus,
        'latestPilotExecutionRecordId': latestPilotExecutionRecordId,
        'latestPilotExecutionStatus': latestPilotExecutionStatus,
        'latestRuntimeDeliveryRecordId': latestRuntimeDeliveryRecordId,
        'latestRuntimeDeliveryStatus': latestRuntimeDeliveryStatus,
        'modelVersion': modelVersion,
        'packageDigest': packageDigest,
        'boundedDigest': boundedDigest,
        'normCap': normCap,
        'effectiveTotalWeight': effectiveTotalWeight,
        'rawTotalWeight': rawTotalWeight,
        'dampedSummaryCount': dampedSummaryCount,
        'minUpdateNorm': minUpdateNorm,
        'maxUpdateNorm': maxUpdateNorm,
        'oldestSummaryCreatedAtMs': oldestSummaryCreatedAtMs,
        'newestSummaryCreatedAtMs': newestSummaryCreatedAtMs,
        'summaryFreshnessSpanSeconds': summaryFreshnessSpanSeconds,
        'batteryStateBreakdown': batteryStateBreakdown
            .map((FederatedLearningEnvironmentBreakdownEntryModel entry) =>
                entry.toMap())
            .toList(growable: false),
        'networkTypeBreakdown': networkTypeBreakdown
            .map((FederatedLearningEnvironmentBreakdownEntryModel entry) =>
                entry.toMap())
            .toList(growable: false),
        'runtimeVectorLength': runtimeVectorLength,
        'runtimeVector': runtimeVector,
        'runtimeVectorDigest': runtimeVectorDigest,
        'sampleCount': sampleCount,
        'summaryCount': summaryCount,
        'distinctSiteCount': distinctSiteCount,
        'contributingSiteIds': contributingSiteIds,
        'schemaVersions': schemaVersions,
        'runtimeTargets': runtimeTargets,
        'maxVectorLength': maxVectorLength,
        'totalPayloadBytes': totalPayloadBytes,
        'averageUpdateNorm': averageUpdateNorm,
        'optimizerStrategies': optimizerStrategies,
        'compatibilityKey': compatibilityKey,
        'warmStartPackageId': warmStartPackageId,
        'warmStartModelVersion': warmStartModelVersion,
        'contributionDetails': contributionDetails
            .map((FederatedLearningContributionDetailModel detail) =>
                detail.toMap())
            .toList(growable: false),
        'siteContributionSummaries': siteContributionSummaries
            .map((FederatedLearningSiteContributionSummaryModel summary) =>
                summary.toMap())
            .toList(growable: false),
        'createdBy': createdBy,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class FederatedLearningPilotEvidenceRecordModel {
  const FederatedLearningPilotEvidenceRecordModel({
    required this.id,
    required this.experimentId,
    required this.candidateModelPackageId,
    required this.aggregationRunId,
    required this.mergeArtifactId,
    required this.status,
    required this.sandboxEvalComplete,
    required this.metricsSnapshotComplete,
    required this.rollbackPlanVerified,
    this.notes,
    this.reviewedBy,
    this.reviewedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String experimentId;
  final String candidateModelPackageId;
  final String aggregationRunId;
  final String mergeArtifactId;
  final String status;
  final bool sandboxEvalComplete;
  final bool metricsSnapshotComplete;
  final bool rollbackPlanVerified;
  final String? notes;
  final String? reviewedBy;
  final Timestamp? reviewedAt;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory FederatedLearningPilotEvidenceRecordModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return FederatedLearningPilotEvidenceRecordModel.fromMap(
      doc.id,
      doc.data() ?? <String, dynamic>{},
    );
  }

  factory FederatedLearningPilotEvidenceRecordModel.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return FederatedLearningPilotEvidenceRecordModel(
      id: id,
      experimentId: data['experimentId'] as String? ?? '',
      candidateModelPackageId: data['candidateModelPackageId'] as String? ?? '',
      aggregationRunId: data['aggregationRunId'] as String? ?? '',
      mergeArtifactId: data['mergeArtifactId'] as String? ?? '',
      status: data['status'] as String? ?? 'pending',
      sandboxEvalComplete: data['sandboxEvalComplete'] == true,
      metricsSnapshotComplete: data['metricsSnapshotComplete'] == true,
      rollbackPlanVerified: data['rollbackPlanVerified'] == true,
      notes: data['notes'] as String?,
      reviewedBy: data['reviewedBy'] as String?,
      reviewedAt: _timestampOrNull(data['reviewedAt']),
      createdAt: _timestampOrNull(data['createdAt']),
      updatedAt: _timestampOrNull(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'experimentId': experimentId,
        'candidateModelPackageId': candidateModelPackageId,
        'aggregationRunId': aggregationRunId,
        'mergeArtifactId': mergeArtifactId,
        'status': status,
        'sandboxEvalComplete': sandboxEvalComplete,
        'metricsSnapshotComplete': metricsSnapshotComplete,
        'rollbackPlanVerified': rollbackPlanVerified,
        'notes': notes,
        'reviewedBy': reviewedBy,
        'reviewedAt': reviewedAt ?? Timestamp.now(),
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class FederatedLearningPilotApprovalRecordModel {
  const FederatedLearningPilotApprovalRecordModel({
    required this.id,
    required this.experimentId,
    required this.candidateModelPackageId,
    required this.aggregationRunId,
    required this.mergeArtifactId,
    required this.experimentReviewRecordId,
    required this.pilotEvidenceRecordId,
    required this.candidatePromotionRecordId,
    required this.promotionTarget,
    required this.status,
    this.notes,
    this.approvedBy,
    this.approvedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String experimentId;
  final String candidateModelPackageId;
  final String aggregationRunId;
  final String mergeArtifactId;
  final String experimentReviewRecordId;
  final String pilotEvidenceRecordId;
  final String candidatePromotionRecordId;
  final String promotionTarget;
  final String status;
  final String? notes;
  final String? approvedBy;
  final Timestamp? approvedAt;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory FederatedLearningPilotApprovalRecordModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return FederatedLearningPilotApprovalRecordModel.fromMap(
      doc.id,
      doc.data() ?? <String, dynamic>{},
    );
  }

  factory FederatedLearningPilotApprovalRecordModel.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return FederatedLearningPilotApprovalRecordModel(
      id: id,
      experimentId: data['experimentId'] as String? ?? '',
      candidateModelPackageId: data['candidateModelPackageId'] as String? ?? '',
      aggregationRunId: data['aggregationRunId'] as String? ?? '',
      mergeArtifactId: data['mergeArtifactId'] as String? ?? '',
      experimentReviewRecordId:
          data['experimentReviewRecordId'] as String? ?? '',
      pilotEvidenceRecordId: data['pilotEvidenceRecordId'] as String? ?? '',
      candidatePromotionRecordId:
          data['candidatePromotionRecordId'] as String? ?? '',
      promotionTarget: data['promotionTarget'] as String? ?? '',
      status: data['status'] as String? ?? 'pending',
      notes: data['notes'] as String?,
      approvedBy: data['approvedBy'] as String?,
      approvedAt: _timestampOrNull(data['approvedAt']),
      createdAt: _timestampOrNull(data['createdAt']),
      updatedAt: _timestampOrNull(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'experimentId': experimentId,
        'candidateModelPackageId': candidateModelPackageId,
        'aggregationRunId': aggregationRunId,
        'mergeArtifactId': mergeArtifactId,
        'experimentReviewRecordId': experimentReviewRecordId,
        'pilotEvidenceRecordId': pilotEvidenceRecordId,
        'candidatePromotionRecordId': candidatePromotionRecordId,
        'promotionTarget': promotionTarget,
        'status': status,
        'notes': notes,
        'approvedBy': approvedBy,
        'approvedAt': approvedAt ?? Timestamp.now(),
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class FederatedLearningPilotExecutionRecordModel {
  const FederatedLearningPilotExecutionRecordModel({
    required this.id,
    required this.experimentId,
    required this.candidateModelPackageId,
    required this.aggregationRunId,
    required this.mergeArtifactId,
    required this.pilotApprovalRecordId,
    required this.status,
    required this.launchedSiteIds,
    required this.sessionCount,
    required this.learnerCount,
    this.notes,
    this.recordedBy,
    this.recordedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String experimentId;
  final String candidateModelPackageId;
  final String aggregationRunId;
  final String mergeArtifactId;
  final String pilotApprovalRecordId;
  final String status;
  final List<String> launchedSiteIds;
  final int sessionCount;
  final int learnerCount;
  final String? notes;
  final String? recordedBy;
  final Timestamp? recordedAt;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory FederatedLearningPilotExecutionRecordModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return FederatedLearningPilotExecutionRecordModel.fromMap(
      doc.id,
      doc.data() ?? <String, dynamic>{},
    );
  }

  factory FederatedLearningPilotExecutionRecordModel.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return FederatedLearningPilotExecutionRecordModel(
      id: id,
      experimentId: data['experimentId'] as String? ?? '',
      candidateModelPackageId: data['candidateModelPackageId'] as String? ?? '',
      aggregationRunId: data['aggregationRunId'] as String? ?? '',
      mergeArtifactId: data['mergeArtifactId'] as String? ?? '',
      pilotApprovalRecordId: data['pilotApprovalRecordId'] as String? ?? '',
      status: data['status'] as String? ?? 'planned',
      launchedSiteIds: _stringListOrEmpty(data['launchedSiteIds']),
      sessionCount: (data['sessionCount'] as num?)?.toInt() ?? 0,
      learnerCount: (data['learnerCount'] as num?)?.toInt() ?? 0,
      notes: data['notes'] as String?,
      recordedBy: data['recordedBy'] as String?,
      recordedAt: _timestampOrNull(data['recordedAt']),
      createdAt: _timestampOrNull(data['createdAt']),
      updatedAt: _timestampOrNull(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'experimentId': experimentId,
        'candidateModelPackageId': candidateModelPackageId,
        'aggregationRunId': aggregationRunId,
        'mergeArtifactId': mergeArtifactId,
        'pilotApprovalRecordId': pilotApprovalRecordId,
        'status': status,
        'launchedSiteIds': launchedSiteIds,
        'sessionCount': sessionCount,
        'learnerCount': learnerCount,
        'notes': notes,
        'recordedBy': recordedBy,
        'recordedAt': recordedAt ?? Timestamp.now(),
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class FederatedLearningRuntimeDeliveryRecordModel {
  const FederatedLearningRuntimeDeliveryRecordModel({
    required this.id,
    required this.experimentId,
    required this.candidateModelPackageId,
    required this.aggregationRunId,
    required this.mergeArtifactId,
    required this.pilotExecutionRecordId,
    required this.runtimeTarget,
    required this.targetSiteIds,
    required this.status,
    required this.packageDigest,
    required this.boundedDigest,
    required this.triggerSummaryId,
    required this.summaryIds,
    required this.schemaVersions,
    required this.optimizerStrategies,
    required this.manifestDigest,
    this.compatibilityKey,
    this.warmStartPackageId,
    this.warmStartModelVersion,
    this.expiresAt,
    this.supersededAt,
    this.supersededBy,
    this.supersededByDeliveryRecordId,
    this.supersededByCandidateModelPackageId,
    this.supersessionReason,
    this.revokedAt,
    this.revokedBy,
    this.revocationReason,
    this.terminalLifecycleStatus,
    this.rolloutControlMode,
    this.rolloutControlReason,
    this.rolloutControlReviewByAt,
    this.notes,
    this.assignedBy,
    this.assignedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String experimentId;
  final String candidateModelPackageId;
  final String aggregationRunId;
  final String mergeArtifactId;
  final String pilotExecutionRecordId;
  final String runtimeTarget;
  final List<String> targetSiteIds;
  final String status;
  final String packageDigest;
  final String boundedDigest;
  final String triggerSummaryId;
  final List<String> summaryIds;
  final List<String> schemaVersions;
  final List<String> optimizerStrategies;
  final String manifestDigest;
  final String? compatibilityKey;
  final String? warmStartPackageId;
  final String? warmStartModelVersion;
  final Timestamp? expiresAt;
  final Timestamp? supersededAt;
  final String? supersededBy;
  final String? supersededByDeliveryRecordId;
  final String? supersededByCandidateModelPackageId;
  final String? supersessionReason;
  final Timestamp? revokedAt;
  final String? revokedBy;
  final String? revocationReason;
  final String? terminalLifecycleStatus;
  final String? rolloutControlMode;
  final String? rolloutControlReason;
  final Timestamp? rolloutControlReviewByAt;
  final String? notes;
  final String? assignedBy;
  final Timestamp? assignedAt;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory FederatedLearningRuntimeDeliveryRecordModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return FederatedLearningRuntimeDeliveryRecordModel.fromMap(
      doc.id,
      doc.data() ?? <String, dynamic>{},
    );
  }

  factory FederatedLearningRuntimeDeliveryRecordModel.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return FederatedLearningRuntimeDeliveryRecordModel(
      id: id,
      experimentId: data['experimentId'] as String? ?? '',
      candidateModelPackageId: data['candidateModelPackageId'] as String? ?? '',
      aggregationRunId: data['aggregationRunId'] as String? ?? '',
      mergeArtifactId: data['mergeArtifactId'] as String? ?? '',
      pilotExecutionRecordId: data['pilotExecutionRecordId'] as String? ?? '',
      runtimeTarget: data['runtimeTarget'] as String? ?? '',
      targetSiteIds: _stringListOrEmpty(data['targetSiteIds']),
      status: data['status'] as String? ?? 'prepared',
      packageDigest: data['packageDigest'] as String? ?? '',
      boundedDigest: data['boundedDigest'] as String? ?? '',
      triggerSummaryId: data['triggerSummaryId'] as String? ?? '',
      summaryIds: _stringListOrEmpty(data['summaryIds']),
      schemaVersions: _stringListOrEmpty(data['schemaVersions']),
      optimizerStrategies: _stringListOrEmpty(data['optimizerStrategies']),
      manifestDigest: data['manifestDigest'] as String? ?? '',
      compatibilityKey: data['compatibilityKey'] as String?,
      warmStartPackageId: data['warmStartPackageId'] as String?,
      warmStartModelVersion: data['warmStartModelVersion'] as String?,
      expiresAt: _timestampOrNull(data['expiresAt']),
      supersededAt: _timestampOrNull(data['supersededAt']),
      supersededBy: data['supersededBy'] as String?,
      supersededByDeliveryRecordId:
          data['supersededByDeliveryRecordId'] as String?,
      supersededByCandidateModelPackageId:
          data['supersededByCandidateModelPackageId'] as String?,
      supersessionReason: data['supersessionReason'] as String?,
      revokedAt: _timestampOrNull(data['revokedAt']),
      revokedBy: data['revokedBy'] as String?,
      revocationReason: data['revocationReason'] as String?,
      terminalLifecycleStatus: data['terminalLifecycleStatus'] as String?,
      rolloutControlMode: data['rolloutControlMode'] as String?,
      rolloutControlReason: data['rolloutControlReason'] as String?,
      rolloutControlReviewByAt:
          _timestampOrNull(data['rolloutControlReviewByAt']),
      notes: data['notes'] as String?,
      assignedBy: data['assignedBy'] as String?,
      assignedAt: _timestampOrNull(data['assignedAt']),
      createdAt: _timestampOrNull(data['createdAt']),
      updatedAt: _timestampOrNull(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'experimentId': experimentId,
        'candidateModelPackageId': candidateModelPackageId,
        'aggregationRunId': aggregationRunId,
        'mergeArtifactId': mergeArtifactId,
        'pilotExecutionRecordId': pilotExecutionRecordId,
        'runtimeTarget': runtimeTarget,
        'targetSiteIds': targetSiteIds,
        'status': status,
        'packageDigest': packageDigest,
        'boundedDigest': boundedDigest,
        'triggerSummaryId': triggerSummaryId,
        'summaryIds': summaryIds,
        'schemaVersions': schemaVersions,
        'optimizerStrategies': optimizerStrategies,
        'manifestDigest': manifestDigest,
        'compatibilityKey': compatibilityKey,
        'warmStartPackageId': warmStartPackageId,
        'warmStartModelVersion': warmStartModelVersion,
        'expiresAt': expiresAt,
        'supersededAt': supersededAt,
        'supersededBy': supersededBy,
        'supersededByDeliveryRecordId': supersededByDeliveryRecordId,
        'supersededByCandidateModelPackageId':
            supersededByCandidateModelPackageId,
        'supersessionReason': supersessionReason,
        'revokedAt': revokedAt,
        'revokedBy': revokedBy,
        'revocationReason': revocationReason,
        'terminalLifecycleStatus': terminalLifecycleStatus,
        'rolloutControlMode': rolloutControlMode,
        'rolloutControlReason': rolloutControlReason,
        'rolloutControlReviewByAt': rolloutControlReviewByAt,
        'notes': notes,
        'assignedBy': assignedBy,
        'assignedAt': assignedAt ?? Timestamp.now(),
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class FederatedLearningRuntimeActivationRecordModel {
  const FederatedLearningRuntimeActivationRecordModel({
    required this.id,
    required this.deliveryRecordId,
    required this.experimentId,
    required this.candidateModelPackageId,
    required this.siteId,
    required this.runtimeTarget,
    required this.packageDigest,
    required this.boundedDigest,
    required this.triggerSummaryId,
    required this.summaryIds,
    required this.schemaVersions,
    required this.optimizerStrategies,
    required this.manifestDigest,
    required this.status,
    this.compatibilityKey,
    this.warmStartPackageId,
    this.warmStartModelVersion,
    this.traceId,
    this.notes,
    this.reportedBy,
    this.reportedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String deliveryRecordId;
  final String experimentId;
  final String candidateModelPackageId;
  final String siteId;
  final String runtimeTarget;
  final String packageDigest;
  final String boundedDigest;
  final String triggerSummaryId;
  final List<String> summaryIds;
  final List<String> schemaVersions;
  final List<String> optimizerStrategies;
  final String manifestDigest;
  final String status;
  final String? compatibilityKey;
  final String? warmStartPackageId;
  final String? warmStartModelVersion;
  final String? traceId;
  final String? notes;
  final String? reportedBy;
  final Timestamp? reportedAt;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory FederatedLearningRuntimeActivationRecordModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return FederatedLearningRuntimeActivationRecordModel.fromMap(
      doc.id,
      doc.data() ?? <String, dynamic>{},
    );
  }

  factory FederatedLearningRuntimeActivationRecordModel.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return FederatedLearningRuntimeActivationRecordModel(
      id: id,
      deliveryRecordId: data['deliveryRecordId'] as String? ?? '',
      experimentId: data['experimentId'] as String? ?? '',
      candidateModelPackageId: data['candidateModelPackageId'] as String? ?? '',
      siteId: data['siteId'] as String? ?? '',
      runtimeTarget: data['runtimeTarget'] as String? ?? '',
      packageDigest: data['packageDigest'] as String? ?? '',
      boundedDigest: data['boundedDigest'] as String? ?? '',
      triggerSummaryId: data['triggerSummaryId'] as String? ?? '',
      summaryIds: _stringListOrEmpty(data['summaryIds']),
      schemaVersions: _stringListOrEmpty(data['schemaVersions']),
      optimizerStrategies: _stringListOrEmpty(data['optimizerStrategies']),
      manifestDigest: data['manifestDigest'] as String? ?? '',
      status: data['status'] as String? ?? 'resolved',
      compatibilityKey: data['compatibilityKey'] as String?,
      warmStartPackageId: data['warmStartPackageId'] as String?,
      warmStartModelVersion: data['warmStartModelVersion'] as String?,
      traceId: data['traceId'] as String?,
      notes: data['notes'] as String?,
      reportedBy: data['reportedBy'] as String?,
      reportedAt: _timestampOrNull(data['reportedAt']),
      createdAt: _timestampOrNull(data['createdAt']),
      updatedAt: _timestampOrNull(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'deliveryRecordId': deliveryRecordId,
        'experimentId': experimentId,
        'candidateModelPackageId': candidateModelPackageId,
        'siteId': siteId,
        'runtimeTarget': runtimeTarget,
        'packageDigest': packageDigest,
        'boundedDigest': boundedDigest,
        'triggerSummaryId': triggerSummaryId,
        'summaryIds': summaryIds,
        'schemaVersions': schemaVersions,
        'optimizerStrategies': optimizerStrategies,
        'manifestDigest': manifestDigest,
        'status': status,
        'compatibilityKey': compatibilityKey,
        'warmStartPackageId': warmStartPackageId,
        'warmStartModelVersion': warmStartModelVersion,
        'traceId': traceId,
        'notes': notes,
        'reportedBy': reportedBy,
        'reportedAt': reportedAt ?? Timestamp.now(),
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class FederatedLearningRuntimeRolloutAlertRecordModel {
  const FederatedLearningRuntimeRolloutAlertRecordModel({
    required this.id,
    required this.experimentId,
    required this.candidateModelPackageId,
    required this.deliveryRecordId,
    required this.runtimeTarget,
    required this.targetSiteIds,
    required this.packageDigest,
    required this.boundedDigest,
    required this.triggerSummaryId,
    required this.summaryIds,
    required this.schemaVersions,
    required this.optimizerStrategies,
    required this.compatibilityKey,
    required this.warmStartPackageId,
    required this.warmStartModelVersion,
    required this.manifestDigest,
    required this.status,
    required this.fallbackCount,
    required this.pendingCount,
    this.notes,
    this.acknowledgedBy,
    this.acknowledgedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String experimentId;
  final String candidateModelPackageId;
  final String deliveryRecordId;
  final String runtimeTarget;
  final List<String> targetSiteIds;
  final String packageDigest;
  final String boundedDigest;
  final String triggerSummaryId;
  final List<String> summaryIds;
  final List<String> schemaVersions;
  final List<String> optimizerStrategies;
  final String compatibilityKey;
  final String? warmStartPackageId;
  final String? warmStartModelVersion;
  final String manifestDigest;
  final String status;
  final int fallbackCount;
  final int pendingCount;
  final String? notes;
  final String? acknowledgedBy;
  final Timestamp? acknowledgedAt;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory FederatedLearningRuntimeRolloutAlertRecordModel.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return FederatedLearningRuntimeRolloutAlertRecordModel(
      id: id,
      experimentId: data['experimentId'] as String? ?? '',
      candidateModelPackageId: data['candidateModelPackageId'] as String? ?? '',
      deliveryRecordId: data['deliveryRecordId'] as String? ?? '',
      runtimeTarget: data['runtimeTarget'] as String? ?? '',
      targetSiteIds: _stringListOrEmpty(data['targetSiteIds']),
      packageDigest: data['packageDigest'] as String? ?? '',
      boundedDigest: data['boundedDigest'] as String? ?? '',
      triggerSummaryId: data['triggerSummaryId'] as String? ?? '',
      summaryIds: _stringListOrEmpty(data['summaryIds']),
      schemaVersions: _stringListOrEmpty(data['schemaVersions']),
      optimizerStrategies: _stringListOrEmpty(data['optimizerStrategies']),
      compatibilityKey: data['compatibilityKey'] as String? ?? '',
      warmStartPackageId: data['warmStartPackageId'] as String?,
      warmStartModelVersion: data['warmStartModelVersion'] as String?,
      manifestDigest: data['manifestDigest'] as String? ?? '',
      status: data['status'] as String? ?? 'active',
      fallbackCount: (data['fallbackCount'] as num?)?.toInt() ?? 0,
      pendingCount: (data['pendingCount'] as num?)?.toInt() ?? 0,
      notes: data['notes'] as String?,
      acknowledgedBy: data['acknowledgedBy'] as String?,
      acknowledgedAt: _timestampOrNull(data['acknowledgedAt']),
      createdAt: _timestampOrNull(data['createdAt']),
      updatedAt: _timestampOrNull(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'experimentId': experimentId,
        'candidateModelPackageId': candidateModelPackageId,
        'deliveryRecordId': deliveryRecordId,
        'runtimeTarget': runtimeTarget,
        'targetSiteIds': targetSiteIds,
        'packageDigest': packageDigest,
        'boundedDigest': boundedDigest,
        'triggerSummaryId': triggerSummaryId,
        'summaryIds': summaryIds,
        'schemaVersions': schemaVersions,
        'optimizerStrategies': optimizerStrategies,
        'compatibilityKey': compatibilityKey,
        'warmStartPackageId': warmStartPackageId,
        'warmStartModelVersion': warmStartModelVersion,
        'manifestDigest': manifestDigest,
        'status': status,
        'fallbackCount': fallbackCount,
        'pendingCount': pendingCount,
        'notes': notes,
        'acknowledgedBy': acknowledgedBy,
        'acknowledgedAt': acknowledgedAt,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class FederatedLearningRuntimeRolloutEscalationRecordModel {
  const FederatedLearningRuntimeRolloutEscalationRecordModel({
    required this.id,
    required this.experimentId,
    required this.candidateModelPackageId,
    required this.deliveryRecordId,
    required this.runtimeTarget,
    required this.targetSiteIds,
    required this.packageDigest,
    required this.boundedDigest,
    required this.triggerSummaryId,
    required this.summaryIds,
    required this.schemaVersions,
    required this.optimizerStrategies,
    required this.compatibilityKey,
    required this.warmStartPackageId,
    required this.warmStartModelVersion,
    required this.manifestDigest,
    required this.status,
    required this.fallbackCount,
    required this.pendingCount,
    this.openedAt,
    this.dueAt,
    this.ownerUserId,
    this.notes,
    this.resolvedBy,
    this.resolvedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String experimentId;
  final String candidateModelPackageId;
  final String deliveryRecordId;
  final String runtimeTarget;
  final List<String> targetSiteIds;
  final String packageDigest;
  final String boundedDigest;
  final String triggerSummaryId;
  final List<String> summaryIds;
  final List<String> schemaVersions;
  final List<String> optimizerStrategies;
  final String compatibilityKey;
  final String? warmStartPackageId;
  final String? warmStartModelVersion;
  final String manifestDigest;
  final String status;
  final int fallbackCount;
  final int pendingCount;
  final Timestamp? openedAt;
  final Timestamp? dueAt;
  final String? ownerUserId;
  final String? notes;
  final String? resolvedBy;
  final Timestamp? resolvedAt;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory FederatedLearningRuntimeRolloutEscalationRecordModel.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return FederatedLearningRuntimeRolloutEscalationRecordModel(
      id: id,
      experimentId: data['experimentId'] as String? ?? '',
      candidateModelPackageId: data['candidateModelPackageId'] as String? ?? '',
      deliveryRecordId: data['deliveryRecordId'] as String? ?? '',
      runtimeTarget: data['runtimeTarget'] as String? ?? '',
      targetSiteIds: _stringListOrEmpty(data['targetSiteIds']),
      packageDigest: data['packageDigest'] as String? ?? '',
      boundedDigest: data['boundedDigest'] as String? ?? '',
      triggerSummaryId: data['triggerSummaryId'] as String? ?? '',
      summaryIds: _stringListOrEmpty(data['summaryIds']),
      schemaVersions: _stringListOrEmpty(data['schemaVersions']),
      optimizerStrategies: _stringListOrEmpty(data['optimizerStrategies']),
      compatibilityKey: data['compatibilityKey'] as String? ?? '',
      warmStartPackageId: data['warmStartPackageId'] as String?,
      warmStartModelVersion: data['warmStartModelVersion'] as String?,
      manifestDigest: data['manifestDigest'] as String? ?? '',
      status: data['status'] as String? ?? 'open',
      fallbackCount: (data['fallbackCount'] as num?)?.toInt() ?? 0,
      pendingCount: (data['pendingCount'] as num?)?.toInt() ?? 0,
      openedAt: _timestampOrNull(data['openedAt']),
      dueAt: _timestampOrNull(data['dueAt']),
      ownerUserId: data['ownerUserId'] as String?,
      notes: data['notes'] as String?,
      resolvedBy: data['resolvedBy'] as String?,
      resolvedAt: _timestampOrNull(data['resolvedAt']),
      createdAt: _timestampOrNull(data['createdAt']),
      updatedAt: _timestampOrNull(data['updatedAt']),
    );
  }
}

@immutable
class FederatedLearningRuntimeRolloutEscalationHistoryRecordModel {
  const FederatedLearningRuntimeRolloutEscalationHistoryRecordModel({
    required this.id,
    required this.escalationRecordId,
    required this.experimentId,
    required this.candidateModelPackageId,
    required this.deliveryRecordId,
    required this.runtimeTarget,
    required this.targetSiteIds,
    required this.packageDigest,
    required this.boundedDigest,
    required this.triggerSummaryId,
    required this.summaryIds,
    required this.schemaVersions,
    required this.optimizerStrategies,
    required this.compatibilityKey,
    required this.warmStartPackageId,
    required this.warmStartModelVersion,
    required this.manifestDigest,
    required this.status,
    required this.fallbackCount,
    required this.pendingCount,
    this.openedAt,
    this.dueAt,
    this.ownerUserId,
    this.notes,
    this.resolvedBy,
    this.resolvedAt,
    this.recordedBy,
    this.recordedAt,
  });

  final String id;
  final String escalationRecordId;
  final String experimentId;
  final String candidateModelPackageId;
  final String deliveryRecordId;
  final String runtimeTarget;
  final List<String> targetSiteIds;
  final String packageDigest;
  final String boundedDigest;
  final String triggerSummaryId;
  final List<String> summaryIds;
  final List<String> schemaVersions;
  final List<String> optimizerStrategies;
  final String compatibilityKey;
  final String? warmStartPackageId;
  final String? warmStartModelVersion;
  final String manifestDigest;
  final String status;
  final int fallbackCount;
  final int pendingCount;
  final Timestamp? openedAt;
  final Timestamp? dueAt;
  final String? ownerUserId;
  final String? notes;
  final String? resolvedBy;
  final Timestamp? resolvedAt;
  final String? recordedBy;
  final Timestamp? recordedAt;

  factory FederatedLearningRuntimeRolloutEscalationHistoryRecordModel.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return FederatedLearningRuntimeRolloutEscalationHistoryRecordModel(
      id: id,
      escalationRecordId: data['escalationRecordId'] as String? ?? '',
      experimentId: data['experimentId'] as String? ?? '',
      candidateModelPackageId: data['candidateModelPackageId'] as String? ?? '',
      deliveryRecordId: data['deliveryRecordId'] as String? ?? '',
      runtimeTarget: data['runtimeTarget'] as String? ?? '',
      targetSiteIds: _stringListOrEmpty(data['targetSiteIds']),
      packageDigest: data['packageDigest'] as String? ?? '',
      boundedDigest: data['boundedDigest'] as String? ?? '',
      triggerSummaryId: data['triggerSummaryId'] as String? ?? '',
      summaryIds: _stringListOrEmpty(data['summaryIds']),
      schemaVersions: _stringListOrEmpty(data['schemaVersions']),
      optimizerStrategies: _stringListOrEmpty(data['optimizerStrategies']),
      compatibilityKey: data['compatibilityKey'] as String? ?? '',
      warmStartPackageId: data['warmStartPackageId'] as String?,
      warmStartModelVersion: data['warmStartModelVersion'] as String?,
      manifestDigest: data['manifestDigest'] as String? ?? '',
      status: data['status'] as String? ?? 'open',
      fallbackCount: (data['fallbackCount'] as num?)?.toInt() ?? 0,
      pendingCount: (data['pendingCount'] as num?)?.toInt() ?? 0,
      openedAt: _timestampOrNull(data['openedAt']),
      dueAt: _timestampOrNull(data['dueAt']),
      ownerUserId: data['ownerUserId'] as String?,
      notes: data['notes'] as String?,
      resolvedBy: data['resolvedBy'] as String?,
      resolvedAt: _timestampOrNull(data['resolvedAt']),
      recordedBy: data['recordedBy'] as String?,
      recordedAt: _timestampOrNull(data['recordedAt']),
    );
  }
}

@immutable
class FederatedLearningRuntimeRolloutControlRecordModel {
  const FederatedLearningRuntimeRolloutControlRecordModel({
    required this.id,
    required this.experimentId,
    required this.candidateModelPackageId,
    required this.deliveryRecordId,
    required this.runtimeTarget,
    required this.targetSiteIds,
    required this.packageDigest,
    required this.boundedDigest,
    required this.triggerSummaryId,
    required this.summaryIds,
    required this.schemaVersions,
    required this.optimizerStrategies,
    required this.compatibilityKey,
    required this.warmStartPackageId,
    required this.warmStartModelVersion,
    required this.manifestDigest,
    required this.mode,
    this.ownerUserId,
    this.reason,
    this.reviewByAt,
    this.releasedBy,
    this.releasedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String experimentId;
  final String candidateModelPackageId;
  final String deliveryRecordId;
  final String runtimeTarget;
  final List<String> targetSiteIds;
  final String packageDigest;
  final String boundedDigest;
  final String triggerSummaryId;
  final List<String> summaryIds;
  final List<String> schemaVersions;
  final List<String> optimizerStrategies;
  final String compatibilityKey;
  final String? warmStartPackageId;
  final String? warmStartModelVersion;
  final String manifestDigest;
  final String mode;
  final String? ownerUserId;
  final String? reason;
  final Timestamp? reviewByAt;
  final String? releasedBy;
  final Timestamp? releasedAt;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory FederatedLearningRuntimeRolloutControlRecordModel.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return FederatedLearningRuntimeRolloutControlRecordModel(
      id: id,
      experimentId: data['experimentId'] as String? ?? '',
      candidateModelPackageId: data['candidateModelPackageId'] as String? ?? '',
      deliveryRecordId: data['deliveryRecordId'] as String? ?? '',
      runtimeTarget: data['runtimeTarget'] as String? ?? '',
      targetSiteIds: _stringListOrEmpty(data['targetSiteIds']),
      packageDigest: data['packageDigest'] as String? ?? '',
      boundedDigest: data['boundedDigest'] as String? ?? '',
      triggerSummaryId: data['triggerSummaryId'] as String? ?? '',
      summaryIds: _stringListOrEmpty(data['summaryIds']),
      schemaVersions: _stringListOrEmpty(data['schemaVersions']),
      optimizerStrategies: _stringListOrEmpty(data['optimizerStrategies']),
      compatibilityKey: data['compatibilityKey'] as String? ?? '',
      warmStartPackageId: data['warmStartPackageId'] as String?,
      warmStartModelVersion: data['warmStartModelVersion'] as String?,
      manifestDigest: data['manifestDigest'] as String? ?? '',
      mode: data['mode'] as String? ?? 'monitor',
      ownerUserId: data['ownerUserId'] as String?,
      reason: data['reason'] as String?,
      reviewByAt: _timestampOrNull(data['reviewByAt']),
      releasedBy: data['releasedBy'] as String?,
      releasedAt: _timestampOrNull(data['releasedAt']),
      createdAt: _timestampOrNull(data['createdAt']),
      updatedAt: _timestampOrNull(data['updatedAt']),
    );
  }
}

@immutable
class FederatedLearningRuntimeRolloutAuditEventModel {
  const FederatedLearningRuntimeRolloutAuditEventModel({
    required this.id,
    required this.action,
    required this.collection,
    required this.documentId,
    required this.timestamp,
    required this.details,
    this.userId,
  });

  final String id;
  final String action;
  final String collection;
  final String documentId;
  final int timestamp;
  final Map<String, dynamic> details;
  final String? userId;

  String get experimentId => details['experimentId'] as String? ?? '';
  String get candidateModelPackageId =>
      details['candidateModelPackageId'] as String? ?? '';
  String get deliveryRecordId => details['deliveryRecordId'] as String? ?? '';
  String get siteId => details['siteId'] as String? ?? '';
  String get status => details['status'] as String? ?? '';
  String get runtimeTarget => details['runtimeTarget'] as String? ?? '';
  String get packageDigest => details['packageDigest'] as String? ?? '';
  String get boundedDigest => details['boundedDigest'] as String? ?? '';
  String get triggerSummaryId => details['triggerSummaryId'] as String? ?? '';
  List<String> get summaryIds => _stringListOrEmpty(details['summaryIds']);
  List<String> get schemaVersions =>
      _stringListOrEmpty(details['schemaVersions']);
  List<String> get optimizerStrategies =>
      _stringListOrEmpty(details['optimizerStrategies']);
  String get compatibilityKey => details['compatibilityKey'] as String? ?? '';
  String get warmStartPackageId =>
      details['warmStartPackageId'] as String? ?? '';
  String get warmStartModelVersion =>
      details['warmStartModelVersion'] as String? ?? '';
  String get manifestDigest => details['manifestDigest'] as String? ?? '';
  String get notes => details['notes'] as String? ?? '';
  String get ownerUserId => details['ownerUserId'] as String? ?? '';
  String get acknowledgedBy => details['acknowledgedBy'] as String? ?? '';
  String get mode => details['mode'] as String? ?? '';
  String get reason => details['reason'] as String? ?? '';
  int get fallbackCount => (details['fallbackCount'] as num?)?.toInt() ?? 0;
  int get pendingCount => (details['pendingCount'] as num?)?.toInt() ?? 0;
  Timestamp? get openedAt => _timestampOrNull(details['openedAt']);
  Timestamp? get dueAt => _timestampOrNull(details['dueAt']);
  Timestamp? get reviewByAt => _timestampOrNull(details['reviewByAt']);
  List<String> get targetSiteIds =>
      _stringListOrEmpty(details['targetSiteIds']);

  factory FederatedLearningRuntimeRolloutAuditEventModel.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return FederatedLearningRuntimeRolloutAuditEventModel(
      id: id,
      action: data['action'] as String? ?? '',
      collection: data['collection'] as String? ?? '',
      documentId: data['documentId'] as String? ?? '',
      timestamp: (data['timestamp'] as num?)?.toInt() ?? 0,
      details: Map<String, dynamic>.from(
        data['details'] as Map? ?? <String, dynamic>{},
      ),
      userId: data['userId'] as String?,
    );
  }
}

@immutable
class FederatedLearningResolvedRuntimePackageModel {
  const FederatedLearningResolvedRuntimePackageModel({
    required this.packageId,
    required this.deliveryRecordId,
    required this.experimentId,
    required this.candidateModelPackageId,
    required this.siteId,
    required this.runtimeTarget,
    required this.packageDigest,
    required this.manifestDigest,
    required this.resolutionStatus,
    required this.modelVersion,
    required this.runtimeVectorLength,
    required this.runtimeVector,
    required this.runtimeVectorDigest,
    required this.rolloutStatus,
    this.expiresAt,
    this.supersededAt,
    this.supersededBy,
    this.supersededByDeliveryRecordId,
    this.supersededByCandidateModelPackageId,
    this.supersessionReason,
    this.revokedAt,
    this.revokedBy,
    this.revocationReason,
    this.rolloutControlMode,
    this.rolloutControlReason,
    this.rolloutControlReviewByAt,
    this.resolvedAt,
  });

  final String packageId;
  final String deliveryRecordId;
  final String experimentId;
  final String candidateModelPackageId;
  final String siteId;
  final String runtimeTarget;
  final String packageDigest;
  final String manifestDigest;
  final String resolutionStatus;
  final String modelVersion;
  final int runtimeVectorLength;
  final List<double> runtimeVector;
  final String runtimeVectorDigest;
  final String rolloutStatus;
  final Timestamp? expiresAt;
  final Timestamp? supersededAt;
  final String? supersededBy;
  final String? supersededByDeliveryRecordId;
  final String? supersededByCandidateModelPackageId;
  final String? supersessionReason;
  final Timestamp? revokedAt;
  final String? revokedBy;
  final String? revocationReason;
  final String? rolloutControlMode;
  final String? rolloutControlReason;
  final Timestamp? rolloutControlReviewByAt;
  final Timestamp? resolvedAt;

  bool get isUsable {
    final DateTime now = DateTime.now().toUtc();
    final DateTime? expiry = expiresAt?.toDate().toUtc();
    return resolutionStatus == 'resolved' &&
        (expiry == null || expiry.isAfter(now)) &&
        runtimeVector.isNotEmpty;
  }

  factory FederatedLearningResolvedRuntimePackageModel.fromMap(
    Map<String, dynamic> data,
  ) {
    return FederatedLearningResolvedRuntimePackageModel(
      packageId: data['packageId'] as String? ?? '',
      deliveryRecordId: data['deliveryRecordId'] as String? ?? '',
      experimentId: data['experimentId'] as String? ?? '',
      candidateModelPackageId: data['candidateModelPackageId'] as String? ?? '',
      siteId: data['siteId'] as String? ?? '',
      runtimeTarget: data['runtimeTarget'] as String? ?? '',
      packageDigest: data['packageDigest'] as String? ?? '',
      manifestDigest: data['manifestDigest'] as String? ?? '',
      resolutionStatus: data['resolutionStatus'] as String? ?? 'resolved',
      modelVersion: data['modelVersion'] as String? ?? 'fl_runtime_model_v1',
      runtimeVectorLength: (data['runtimeVectorLength'] as num?)?.toInt() ?? 0,
      runtimeVector: _doubleListOrEmpty(data['runtimeVector']),
      runtimeVectorDigest: data['runtimeVectorDigest'] as String? ?? '',
      rolloutStatus: data['rolloutStatus'] as String? ?? 'not_distributed',
      expiresAt: _timestampOrNull(data['expiresAt']),
      supersededAt: _timestampOrNull(data['supersededAt']),
      supersededBy: data['supersededBy'] as String?,
      supersededByDeliveryRecordId:
          data['supersededByDeliveryRecordId'] as String?,
      supersededByCandidateModelPackageId:
          data['supersededByCandidateModelPackageId'] as String?,
      supersessionReason: data['supersessionReason'] as String?,
      revokedAt: _timestampOrNull(data['revokedAt']),
      revokedBy: data['revokedBy'] as String?,
      revocationReason: data['revocationReason'] as String?,
      rolloutControlMode: data['rolloutControlMode'] as String?,
      rolloutControlReason: data['rolloutControlReason'] as String?,
      rolloutControlReviewByAt:
          _timestampOrNull(data['rolloutControlReviewByAt']),
      resolvedAt: _timestampOrNull(data['resolvedAt']),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'packageId': packageId,
        'deliveryRecordId': deliveryRecordId,
        'experimentId': experimentId,
        'candidateModelPackageId': candidateModelPackageId,
        'siteId': siteId,
        'runtimeTarget': runtimeTarget,
        'packageDigest': packageDigest,
        'manifestDigest': manifestDigest,
        'resolutionStatus': resolutionStatus,
        'modelVersion': modelVersion,
        'runtimeVectorLength': runtimeVectorLength,
        'runtimeVector': runtimeVector,
        'runtimeVectorDigest': runtimeVectorDigest,
        'rolloutStatus': rolloutStatus,
        'expiresAt': expiresAt,
        'supersededAt': supersededAt,
        'supersededBy': supersededBy,
        'supersededByDeliveryRecordId': supersededByDeliveryRecordId,
        'supersededByCandidateModelPackageId':
            supersededByCandidateModelPackageId,
        'supersessionReason': supersessionReason,
        'revokedAt': revokedAt,
        'revokedBy': revokedBy,
        'revocationReason': revocationReason,
        'rolloutControlMode': rolloutControlMode,
        'rolloutControlReason': rolloutControlReason,
        'rolloutControlReviewByAt': rolloutControlReviewByAt,
        'resolvedAt': resolvedAt ?? Timestamp.now(),
      };
}

@immutable
class FederatedLearningCandidatePromotionRecordModel {
  const FederatedLearningCandidatePromotionRecordModel({
    required this.id,
    required this.experimentId,
    required this.candidateModelPackageId,
    required this.aggregationRunId,
    required this.mergeArtifactId,
    required this.packageDigest,
    required this.boundedDigest,
    required this.status,
    required this.target,
    this.rationale,
    this.decidedBy,
    this.decidedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String experimentId;
  final String candidateModelPackageId;
  final String aggregationRunId;
  final String mergeArtifactId;
  final String packageDigest;
  final String boundedDigest;
  final String status;
  final String target;
  final String? rationale;
  final String? decidedBy;
  final Timestamp? decidedAt;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory FederatedLearningCandidatePromotionRecordModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return FederatedLearningCandidatePromotionRecordModel.fromMap(
      doc.id,
      doc.data() ?? <String, dynamic>{},
    );
  }

  factory FederatedLearningCandidatePromotionRecordModel.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return FederatedLearningCandidatePromotionRecordModel(
      id: id,
      experimentId: data['experimentId'] as String? ?? '',
      candidateModelPackageId: data['candidateModelPackageId'] as String? ?? '',
      aggregationRunId: data['aggregationRunId'] as String? ?? '',
      mergeArtifactId: data['mergeArtifactId'] as String? ?? '',
      packageDigest: data['packageDigest'] as String? ?? '',
      boundedDigest: data['boundedDigest'] as String? ?? '',
      status: data['status'] as String? ?? '',
      target: data['target'] as String? ?? '',
      rationale: data['rationale'] as String?,
      decidedBy: data['decidedBy'] as String?,
      decidedAt: _timestampOrNull(data['decidedAt']),
      createdAt: _timestampOrNull(data['createdAt']),
      updatedAt: _timestampOrNull(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'experimentId': experimentId,
        'candidateModelPackageId': candidateModelPackageId,
        'aggregationRunId': aggregationRunId,
        'mergeArtifactId': mergeArtifactId,
        'packageDigest': packageDigest,
        'boundedDigest': boundedDigest,
        'status': status,
        'target': target,
        'rationale': rationale,
        'decidedBy': decidedBy,
        'decidedAt': decidedAt ?? Timestamp.now(),
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class FederatedLearningCandidatePromotionRevocationRecordModel {
  const FederatedLearningCandidatePromotionRevocationRecordModel({
    required this.id,
    required this.experimentId,
    required this.candidateModelPackageId,
    required this.candidatePromotionRecordId,
    required this.aggregationRunId,
    required this.mergeArtifactId,
    required this.packageDigest,
    required this.boundedDigest,
    required this.revokedStatus,
    required this.target,
    this.rationale,
    this.revokedBy,
    this.revokedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String experimentId;
  final String candidateModelPackageId;
  final String candidatePromotionRecordId;
  final String aggregationRunId;
  final String mergeArtifactId;
  final String packageDigest;
  final String boundedDigest;
  final String revokedStatus;
  final String target;
  final String? rationale;
  final String? revokedBy;
  final Timestamp? revokedAt;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory FederatedLearningCandidatePromotionRevocationRecordModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return FederatedLearningCandidatePromotionRevocationRecordModel.fromMap(
      doc.id,
      doc.data() ?? <String, dynamic>{},
    );
  }

  factory FederatedLearningCandidatePromotionRevocationRecordModel.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return FederatedLearningCandidatePromotionRevocationRecordModel(
      id: id,
      experimentId: data['experimentId'] as String? ?? '',
      candidateModelPackageId: data['candidateModelPackageId'] as String? ?? '',
      candidatePromotionRecordId:
          data['candidatePromotionRecordId'] as String? ?? '',
      aggregationRunId: data['aggregationRunId'] as String? ?? '',
      mergeArtifactId: data['mergeArtifactId'] as String? ?? '',
      packageDigest: data['packageDigest'] as String? ?? '',
      boundedDigest: data['boundedDigest'] as String? ?? '',
      revokedStatus: data['revokedStatus'] as String? ?? '',
      target: data['target'] as String? ?? '',
      rationale: data['rationale'] as String?,
      revokedBy: data['revokedBy'] as String?,
      revokedAt: _timestampOrNull(data['revokedAt']),
      createdAt: _timestampOrNull(data['createdAt']),
      updatedAt: _timestampOrNull(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'experimentId': experimentId,
        'candidateModelPackageId': candidateModelPackageId,
        'candidatePromotionRecordId': candidatePromotionRecordId,
        'aggregationRunId': aggregationRunId,
        'mergeArtifactId': mergeArtifactId,
        'packageDigest': packageDigest,
        'boundedDigest': boundedDigest,
        'revokedStatus': revokedStatus,
        'target': target,
        'rationale': rationale,
        'revokedBy': revokedBy,
        'revokedAt': revokedAt ?? Timestamp.now(),
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

@immutable
class RosterImportModel {
  const RosterImportModel({
    required this.id,
    required this.sessionId,
    required this.educatorId,
    required this.status,
    required this.source,
    required this.rowNumber,
    this.siteId,
    this.displayName,
    this.email,
    this.learnerIdCandidate,
    this.rawRow = const <String>[],
    this.reviewNotes,
    this.reviewedBy,
    this.reviewedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? siteId;
  final String sessionId;
  final String educatorId;
  final String status;
  final String source;
  final int rowNumber;
  final String? displayName;
  final String? email;
  final String? learnerIdCandidate;
  final List<String> rawRow;
  final String? reviewNotes;
  final String? reviewedBy;
  final Timestamp? reviewedAt;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory RosterImportModel.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return RosterImportModel(
      id: doc.id,
      siteId: data['siteId'] as String?,
      sessionId: data['sessionId'] as String? ?? '',
      educatorId: data['educatorId'] as String? ?? '',
      status: data['status'] as String? ?? 'pending_provisioning',
      source: data['source'] as String? ?? 'csv_import',
      rowNumber: data['rowNumber'] as int? ?? 0,
      displayName: data['displayName'] as String?,
      email: data['email'] as String?,
      learnerIdCandidate: data['learnerIdCandidate'] as String?,
      rawRow: List<String>.from(data['rawRow'] as List? ?? const <String>[]),
      reviewNotes: data['reviewNotes'] as String?,
      reviewedBy: data['reviewedBy'] as String?,
      reviewedAt: data['reviewedAt'] as Timestamp?,
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        if (siteId != null) 'siteId': siteId,
        'sessionId': sessionId,
        'educatorId': educatorId,
        'status': status,
        'source': source,
        'rowNumber': rowNumber,
        if (displayName != null) 'displayName': displayName,
        if (email != null) 'email': email,
        if (learnerIdCandidate != null)
          'learnerIdCandidate': learnerIdCandidate,
        'rawRow': rawRow,
        if (reviewNotes != null) 'reviewNotes': reviewNotes,
        if (reviewedBy != null) 'reviewedBy': reviewedBy,
        if (reviewedAt != null) 'reviewedAt': reviewedAt,
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

  factory GitHubConnectionModel.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return GitHubConnectionModel(
      id: doc.id,
      ownerUserId: data['ownerUserId'] as String? ?? '',
      authType: data['authType'] as String? ?? 'oauth_app',
      status: data['status'] as String? ?? 'active',
      oauthScopesGranted: (data['oauthScopesGranted'] as List?)
          ?.map((e) => e.toString())
          .toList(),
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

  factory ExternalRepoLinkModel.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
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

  factory ExternalPullRequestLinkModel.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
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

  factory GitHubWebhookDeliveryModel.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
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
      entitlementRoles: List<String>.from(
          data['entitlementRoles'] as List? ?? const <String>[]),
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
      details: Map<String, dynamic>.from(
          data['details'] as Map? ?? <String, dynamic>{}),
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

// ──────────────────────────────────────────────────────
// Research Consent Models (Vibe Master §D Research Gate)
// ──────────────────────────────────────────────────────

/// Parent/guardian consent for research data collection.
class ResearchConsentModel {
  ResearchConsentModel({
    required this.id,
    required this.siteId,
    required this.learnerId,
    required this.parentId,
    this.consentGiven = false,
    this.dataShareScope = 'pseudonymised',
    this.consentDocumentUrl,
    this.consentVersion,
    this.revokedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String siteId;
  final String learnerId;
  final String parentId;

  /// Whether the parent has given research consent.
  final bool consentGiven;

  /// Scope of data sharing: 'pseudonymised', 'identifiable', 'none'.
  final String dataShareScope;

  /// URL to the signed consent document (if uploaded).
  final String? consentDocumentUrl;

  /// Version of the consent document.
  final String? consentVersion;

  /// If consent was revoked, when.
  final Timestamp? revokedAt;

  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory ResearchConsentModel.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> m = doc.data() ?? <String, dynamic>{};
    return ResearchConsentModel(
      id: doc.id,
      siteId: m['siteId'] as String? ?? '',
      learnerId: m['learnerId'] as String? ?? '',
      parentId: m['parentId'] as String? ?? '',
      consentGiven: m['consentGiven'] as bool? ?? false,
      dataShareScope: m['dataShareScope'] as String? ?? 'pseudonymised',
      consentDocumentUrl: m['consentDocumentUrl'] as String?,
      consentVersion: m['consentVersion'] as String?,
      revokedAt: m['revokedAt'] as Timestamp?,
      createdAt: m['createdAt'] as Timestamp?,
      updatedAt: m['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'siteId': siteId,
        'learnerId': learnerId,
        'parentId': parentId,
        'consentGiven': consentGiven,
        'dataShareScope': dataShareScope,
        if (consentDocumentUrl != null)
          'consentDocumentUrl': consentDocumentUrl,
        if (consentVersion != null) 'consentVersion': consentVersion,
        if (revokedAt != null) 'revokedAt': revokedAt,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

/// Learner assent for research participation (age-appropriate).
class StudentAssentModel {
  StudentAssentModel({
    required this.id,
    required this.siteId,
    required this.learnerId,
    this.assentGiven = false,
    this.assentVersion,
    this.revokedAt,
    this.createdAt,
  });

  final String id;
  final String siteId;
  final String learnerId;
  final bool assentGiven;
  final String? assentVersion;
  final Timestamp? revokedAt;
  final Timestamp? createdAt;

  factory StudentAssentModel.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> m = doc.data() ?? <String, dynamic>{};
    return StudentAssentModel(
      id: doc.id,
      siteId: m['siteId'] as String? ?? '',
      learnerId: m['learnerId'] as String? ?? '',
      assentGiven: m['assentGiven'] as bool? ?? false,
      assentVersion: m['assentVersion'] as String?,
      revokedAt: m['revokedAt'] as Timestamp?,
      createdAt: m['createdAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'siteId': siteId,
        'learnerId': learnerId,
        'assentGiven': assentGiven,
        if (assentVersion != null) 'assentVersion': assentVersion,
        if (revokedAt != null) 'revokedAt': revokedAt,
        'createdAt': createdAt ?? Timestamp.now(),
      };
}

// ──────────────────────────────────────────────────────
// Assessment Instrument Framework (Vibe Master §B)
// ──────────────────────────────────────────────────────

/// An assessment instrument (pre-test, post-test, survey, etc.).
class AssessmentInstrumentModel {
  AssessmentInstrumentModel({
    required this.id,
    required this.siteId,
    required this.title,
    required this.type,
    this.description,
    this.items = const <AssessmentItem>[],
    this.pillarCodes = const <String>[],
    this.version,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String siteId;
  final String title;

  /// Type: 'pre_test', 'post_test', 'survey', 'formative', 'summative'.
  final String type;

  final String? description;

  /// The individual items/questions in the instrument.
  final List<AssessmentItem> items;

  final List<String> pillarCodes;
  final String? version;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory AssessmentInstrumentModel.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> m = doc.data() ?? <String, dynamic>{};
    final List<dynamic> rawItems = m['items'] as List<dynamic>? ?? <dynamic>[];
    return AssessmentInstrumentModel(
      id: doc.id,
      siteId: m['siteId'] as String? ?? '',
      title: m['title'] as String? ?? '',
      type: m['type'] as String? ?? 'formative',
      description: m['description'] as String?,
      items: rawItems
          .map((dynamic e) => AssessmentItem.fromMap(e as Map<String, dynamic>))
          .toList(),
      pillarCodes:
          ((m['pillarCodes'] as List<dynamic>?)?.cast<String>()) ?? <String>[],
      version: m['version'] as String?,
      createdAt: m['createdAt'] as Timestamp?,
      updatedAt: m['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'siteId': siteId,
        'title': title,
        'type': type,
        if (description != null) 'description': description,
        'items': items.map((AssessmentItem e) => e.toMap()).toList(),
        'pillarCodes': pillarCodes,
        if (version != null) 'version': version,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}

/// A single item/question within an assessment instrument.
class AssessmentItem {
  AssessmentItem({
    required this.itemId,
    required this.prompt,
    this.itemType = 'multiple_choice',
    this.options = const <String>[],
    this.correctAnswer,
    this.maxScore = 1,
    this.skillCodes = const <String>[],
  });

  final String itemId;
  final String prompt;

  /// 'multiple_choice', 'short_answer', 'likert', 'open_ended'.
  final String itemType;

  final List<String> options;
  final String? correctAnswer;
  final int maxScore;
  final List<String> skillCodes;

  factory AssessmentItem.fromMap(Map<String, dynamic> m) => AssessmentItem(
        itemId: m['itemId'] as String? ?? '',
        prompt: m['prompt'] as String? ?? '',
        itemType: m['itemType'] as String? ?? 'multiple_choice',
        options:
            ((m['options'] as List<dynamic>?)?.cast<String>()) ?? <String>[],
        correctAnswer: m['correctAnswer'] as String?,
        maxScore: m['maxScore'] as int? ?? 1,
        skillCodes:
            ((m['skillCodes'] as List<dynamic>?)?.cast<String>()) ?? <String>[],
      );

  Map<String, dynamic> toMap() => <String, dynamic>{
        'itemId': itemId,
        'prompt': prompt,
        'itemType': itemType,
        if (options.isNotEmpty) 'options': options,
        if (correctAnswer != null) 'correctAnswer': correctAnswer,
        'maxScore': maxScore,
        if (skillCodes.isNotEmpty) 'skillCodes': skillCodes,
      };
}

/// An individual item-level response logged per learner per instrument.
class ItemResponseModel {
  ItemResponseModel({
    required this.id,
    required this.siteId,
    required this.learnerId,
    required this.instrumentId,
    required this.itemId,
    this.response,
    this.isCorrect,
    this.score = 0,
    this.timeSpentMs = 0,
    this.confidenceLevel,
    this.createdAt,
  });

  final String id;
  final String siteId;
  final String learnerId;
  final String instrumentId;
  final String itemId;
  final String? response;
  final bool? isCorrect;
  final int score;

  /// Time spent on this item in milliseconds.
  final int timeSpentMs;

  /// Learner self-reported confidence (1–5 Likert).
  final int? confidenceLevel;

  final Timestamp? createdAt;

  factory ItemResponseModel.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> m = doc.data() ?? <String, dynamic>{};
    return ItemResponseModel(
      id: doc.id,
      siteId: m['siteId'] as String? ?? '',
      learnerId: m['learnerId'] as String? ?? '',
      instrumentId: m['instrumentId'] as String? ?? '',
      itemId: m['itemId'] as String? ?? '',
      response: m['response'] as String?,
      isCorrect: m['isCorrect'] as bool?,
      score: m['score'] as int? ?? 0,
      timeSpentMs: m['timeSpentMs'] as int? ?? 0,
      confidenceLevel: m['confidenceLevel'] as int?,
      createdAt: m['createdAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'siteId': siteId,
        'learnerId': learnerId,
        'instrumentId': instrumentId,
        'itemId': itemId,
        if (response != null) 'response': response,
        if (isCorrect != null) 'isCorrect': isCorrect,
        'score': score,
        'timeSpentMs': timeSpentMs,
        if (confidenceLevel != null) 'confidenceLevel': confidenceLevel,
        'createdAt': createdAt ?? Timestamp.now(),
      };
}

class MetacognitiveCalibrationRecordModel {
  MetacognitiveCalibrationRecordModel({
    required this.id,
    required this.siteId,
    required this.learnerId,
    required this.sourceType,
    required this.sourceId,
    this.confidenceLevel,
    this.confidenceScore,
    this.accuracyScore,
    this.calibrationDelta,
    this.instrumentId,
    this.itemId,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String siteId;
  final String learnerId;
  final String sourceType;
  final String sourceId;
  final int? confidenceLevel;
  final double? confidenceScore;
  final double? accuracyScore;
  final double? calibrationDelta;
  final String? instrumentId;
  final String? itemId;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory MetacognitiveCalibrationRecordModel.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> m = doc.data() ?? <String, dynamic>{};
    return MetacognitiveCalibrationRecordModel(
      id: doc.id,
      siteId: m['siteId'] as String? ?? '',
      learnerId: m['learnerId'] as String? ?? '',
      sourceType: m['sourceType'] as String? ?? 'item_response',
      sourceId: m['sourceId'] as String? ?? doc.id,
      confidenceLevel: _readInt(m['confidenceLevel']),
      confidenceScore: _readFiniteDouble(m['confidenceScore']),
      accuracyScore: _readFiniteDouble(m['accuracyScore']),
      calibrationDelta: _readFiniteDouble(m['calibrationDelta']),
      instrumentId: m['instrumentId'] as String?,
      itemId: m['itemId'] as String?,
      createdAt: m['createdAt'] as Timestamp?,
      updatedAt: m['updatedAt'] as Timestamp?,
    );
  }

  static int? _readInt(dynamic value) {
    if (value is! num) {
      return null;
    }
    final double numeric = value.toDouble();
    if (!numeric.isFinite) {
      return null;
    }
    return value.toInt();
  }

  static double? _readFiniteDouble(dynamic value) {
    if (value is! num) {
      return null;
    }
    final double numeric = value.toDouble();
    if (!numeric.isFinite) {
      return null;
    }
    return numeric;
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'siteId': siteId,
        'learnerId': learnerId,
        'sourceType': sourceType,
        'sourceId': sourceId,
        if (confidenceLevel != null) 'confidenceLevel': confidenceLevel,
        if (confidenceScore != null) 'confidenceScore': confidenceScore,
        if (accuracyScore != null) 'accuracyScore': accuracyScore,
        if (calibrationDelta != null) 'calibrationDelta': calibrationDelta,
        if (instrumentId != null) 'instrumentId': instrumentId,
        if (itemId != null) 'itemId': itemId,
        'createdAt': createdAt ?? Timestamp.now(),
        'updatedAt': updatedAt ?? Timestamp.now(),
      };
}
