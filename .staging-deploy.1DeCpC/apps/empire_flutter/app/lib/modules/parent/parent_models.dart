import 'package:equatable/equatable.dart';

/// Model for a learner's summary visible to parents
class LearnerSummary extends Equatable { // Progress per pillar (0-1)

  const LearnerSummary({
    required this.learnerId,
    required this.learnerName,
    this.photoUrl,
    required this.currentLevel,
    required this.totalXp,
    required this.missionsCompleted,
    required this.currentStreak,
    required this.attendanceRate,
    this.recentActivities = const [],
    this.upcomingEvents = const [],
    this.pillarProgress = const {},
  });
  final String learnerId;
  final String learnerName;
  final String? photoUrl;
  final int currentLevel;
  final int totalXp;
  final int missionsCompleted;
  final int currentStreak;
  final double attendanceRate;
  final List<RecentActivity> recentActivities;
  final List<UpcomingEvent> upcomingEvents;
  final Map<String, double> pillarProgress;

  @override
  List<Object?> get props => <Object?>[
        learnerId, learnerName, photoUrl, currentLevel, totalXp,
        missionsCompleted, currentStreak, attendanceRate,
        recentActivities, upcomingEvents, pillarProgress,
      ];
}

/// Recent activity item
class RecentActivity extends Equatable {

  const RecentActivity({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.emoji,
    required this.timestamp,
  });
  final String id;
  final String title;
  final String description;
  final String type; // mission, habit, achievement, attendance
  final String emoji;
  final DateTime timestamp;

  @override
  List<Object?> get props => <Object?>[id, title, description, type, emoji, timestamp];
}

/// Upcoming event for calendar
class UpcomingEvent extends Equatable {

  const UpcomingEvent({
    required this.id,
    required this.title,
    this.description,
    required this.dateTime,
    required this.type,
    this.location,
  });
  final String id;
  final String title;
  final String? description;
  final DateTime dateTime;
  final String type; // class, mission_due, event, conference
  final String? location;

  @override
  List<Object?> get props => <Object?>[id, title, description, dateTime, type, location];
}

/// Billing summary for parents
class BillingSummary extends Equatable {

  const BillingSummary({
    required this.currentBalance,
    required this.nextPaymentAmount,
    this.nextPaymentDate,
    required this.subscriptionPlan,
    this.recentPayments = const [],
  });
  final double currentBalance;
  final double nextPaymentAmount;
  final DateTime? nextPaymentDate;
  final String subscriptionPlan;
  final List<PaymentHistory> recentPayments;

  @override
  List<Object?> get props => <Object?>[
        currentBalance, nextPaymentAmount, nextPaymentDate,
        subscriptionPlan, recentPayments,
      ];
}

/// Payment history item
class PaymentHistory extends Equatable {

  const PaymentHistory({
    required this.id,
    required this.amount,
    required this.date,
    required this.status,
    required this.description,
  });
  final String id;
  final double amount;
  final DateTime date;
  final String status; // paid, pending, failed
  final String description;

  @override
  List<Object?> get props => <Object?>[id, amount, date, status, description];
}
