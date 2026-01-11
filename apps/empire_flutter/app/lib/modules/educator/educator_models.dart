import 'package:equatable/equatable.dart';

/// Model for today's class/session
class TodayClass extends Equatable {

  const TodayClass({
    required this.id,
    required this.sessionId,
    required this.title,
    this.description,
    required this.startTime,
    required this.endTime,
    this.location,
    required this.enrolledCount,
    this.presentCount = 0,
    required this.status,
    this.learners = const [],
  });
  final String id;
  final String sessionId;
  final String title;
  final String? description;
  final DateTime startTime;
  final DateTime endTime;
  final String? location;
  final int enrolledCount;
  final int presentCount;
  final String status; // upcoming, in_progress, completed
  final List<EnrolledLearner> learners;

  Duration get duration => endTime.difference(startTime);
  bool get isNow {
    final DateTime now = DateTime.now();
    return now.isAfter(startTime) && now.isBefore(endTime);
  }

  @override
  List<Object?> get props => <Object?>[
        id, sessionId, title, description, startTime, endTime,
        location, enrolledCount, presentCount, status, learners,
      ];
}

/// Enrolled learner in a class
class EnrolledLearner extends Equatable { // present, absent, late, null (not recorded)

  const EnrolledLearner({
    required this.id,
    required this.name,
    this.photoUrl,
    this.attendanceStatus,
  });
  final String id;
  final String name;
  final String? photoUrl;
  final String? attendanceStatus;

  @override
  List<Object?> get props => <Object?>[id, name, photoUrl, attendanceStatus];
}

/// Quick stats for educator dashboard
class EducatorDayStats extends Equatable {

  const EducatorDayStats({
    required this.totalClasses,
    required this.completedClasses,
    required this.totalLearners,
    required this.presentLearners,
    required this.missionsToReview,
    required this.unreadMessages,
  });
  final int totalClasses;
  final int completedClasses;
  final int totalLearners;
  final int presentLearners;
  final int missionsToReview;
  final int unreadMessages;

  double get attendanceRate =>
      totalLearners > 0 ? presentLearners / totalLearners : 0;

  @override
  List<Object?> get props => <Object?>[
        totalClasses, completedClasses, totalLearners,
        presentLearners, missionsToReview, unreadMessages,
      ];
}

/// Session model for session management
class EducatorSession extends Equatable { // upcoming, ongoing, completed, cancelled

  const EducatorSession({
    required this.id,
    required this.title,
    this.description,
    required this.pillar,
    required this.startTime,
    required this.endTime,
    required this.location,
    required this.enrolledCount,
    required this.maxCapacity,
    required this.status,
  });
  final String id;
  final String title;
  final String? description;
  final String pillar; // future_skills, leadership, impact
  final DateTime startTime;
  final DateTime endTime;
  final String location;
  final int enrolledCount;
  final int maxCapacity;
  final String status;

  @override
  List<Object?> get props => <Object?>[
        id, title, description, pillar, startTime, endTime,
        location, enrolledCount, maxCapacity, status,
      ];
}

/// Learner model for learner roster
class EducatorLearner extends Equatable {

  const EducatorLearner({
    required this.id,
    required this.name,
    required this.email,
    this.photoUrl,
    required this.attendanceRate,
    required this.missionsCompleted,
    required this.pillarProgress,
    required this.enrolledSessionIds,
  });
  final String id;
  final String name;
  final String email;
  final String? photoUrl;
  final int attendanceRate;
  final int missionsCompleted;
  final Map<String, double> pillarProgress; // pillar -> progress 0-1
  final List<String> enrolledSessionIds;

  @override
  List<Object?> get props => <Object?>[
        id, name, email, photoUrl, attendanceRate,
        missionsCompleted, pillarProgress, enrolledSessionIds,
      ];
}

/// Mission submission for review
class MissionSubmission extends Equatable {

  const MissionSubmission({
    required this.id,
    required this.missionId,
    required this.missionTitle,
    required this.learnerId,
    required this.learnerName,
    this.learnerPhotoUrl,
    required this.pillar,
    required this.submittedAt,
    required this.status,
    this.submissionText,
    this.attachmentUrls = const [],
    this.rating,
    this.feedback,
  });
  final String id;
  final String missionId;
  final String missionTitle;
  final String learnerId;
  final String learnerName;
  final String? learnerPhotoUrl;
  final String pillar;
  final DateTime submittedAt;
  final String status; // pending, reviewed, revision_requested, approved
  final String? submissionText;
  final List<String> attachmentUrls;
  final int? rating;
  final String? feedback;

  @override
  List<Object?> get props => <Object?>[
        id, missionId, missionTitle, learnerId, learnerName,
        learnerPhotoUrl, pillar, submittedAt, status,
        submissionText, attachmentUrls, rating, feedback,
      ];
}
