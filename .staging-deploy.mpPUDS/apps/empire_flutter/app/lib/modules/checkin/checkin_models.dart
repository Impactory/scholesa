import 'package:equatable/equatable.dart';

/// Check-in/out status
enum CheckStatus {
  checkedIn,
  checkedOut,
  absent,
  late;

  String get label {
    switch (this) {
      case CheckStatus.checkedIn:
        return 'Checked In';
      case CheckStatus.checkedOut:
        return 'Checked Out';
      case CheckStatus.absent:
        return 'Absent';
      case CheckStatus.late:
        return 'Late';
    }
  }
}

/// Pick-up authorization status
enum PickupAuthStatus {
  authorized,
  pending,
  denied;

  String get label {
    switch (this) {
      case PickupAuthStatus.authorized:
        return 'Authorized';
      case PickupAuthStatus.pending:
        return 'Pending';
      case PickupAuthStatus.denied:
        return 'Denied';
    }
  }
}

/// Model for check-in/out records
class CheckRecord extends Equatable {

  const CheckRecord({
    required this.id,
    required this.visitorId,
    required this.visitorName,
    this.visitorPhone,
    required this.learnerId,
    required this.learnerName,
    required this.siteId,
    required this.timestamp,
    required this.status,
    this.authorizedById,
    this.authorizedByName,
    this.notes,
    this.photoUrl,
  });

  factory CheckRecord.fromJson(Map<String, dynamic> json) {
    return CheckRecord(
      id: json['id'] as String,
      visitorId: json['visitorId'] as String,
      visitorName: json['visitorName'] as String,
      visitorPhone: json['visitorPhone'] as String?,
      learnerId: json['learnerId'] as String,
      learnerName: json['learnerName'] as String,
      siteId: json['siteId'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      status: CheckStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => CheckStatus.checkedIn,
      ),
      authorizedById: json['authorizedById'] as String?,
      authorizedByName: json['authorizedByName'] as String?,
      notes: json['notes'] as String?,
      photoUrl: json['photoUrl'] as String?,
    );
  }
  final String id;
  final String visitorId;
  final String visitorName;
  final String? visitorPhone;
  final String learnerId;
  final String learnerName;
  final String siteId;
  final DateTime timestamp;
  final CheckStatus status;
  final String? authorizedById;
  final String? authorizedByName;
  final String? notes;
  final String? photoUrl;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'visitorId': visitorId,
      'visitorName': visitorName,
      'visitorPhone': visitorPhone,
      'learnerId': learnerId,
      'learnerName': learnerName,
      'siteId': siteId,
      'timestamp': timestamp.toIso8601String(),
      'status': status.name,
      'authorizedById': authorizedById,
      'authorizedByName': authorizedByName,
      'notes': notes,
      'photoUrl': photoUrl,
    };
  }

  CheckRecord copyWith({
    String? id,
    String? visitorId,
    String? visitorName,
    String? visitorPhone,
    String? learnerId,
    String? learnerName,
    String? siteId,
    DateTime? timestamp,
    CheckStatus? status,
    String? authorizedById,
    String? authorizedByName,
    String? notes,
    String? photoUrl,
  }) {
    return CheckRecord(
      id: id ?? this.id,
      visitorId: visitorId ?? this.visitorId,
      visitorName: visitorName ?? this.visitorName,
      visitorPhone: visitorPhone ?? this.visitorPhone,
      learnerId: learnerId ?? this.learnerId,
      learnerName: learnerName ?? this.learnerName,
      siteId: siteId ?? this.siteId,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      authorizedById: authorizedById ?? this.authorizedById,
      authorizedByName: authorizedByName ?? this.authorizedByName,
      notes: notes ?? this.notes,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        id,
        visitorId,
        visitorName,
        visitorPhone,
        learnerId,
        learnerName,
        siteId,
        timestamp,
        status,
        authorizedById,
        authorizedByName,
        notes,
        photoUrl,
      ];
}

/// Model for authorized pickup person
class AuthorizedPickup extends Equatable {

  const AuthorizedPickup({
    required this.id,
    required this.learnerId,
    required this.name,
    this.phone,
    this.email,
    required this.relationship,
    this.photoUrl,
    this.isPrimaryContact = false,
    this.expiresAt,
  });

  factory AuthorizedPickup.fromJson(Map<String, dynamic> json) {
    return AuthorizedPickup(
      id: json['id'] as String,
      learnerId: json['learnerId'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      relationship: json['relationship'] as String,
      photoUrl: json['photoUrl'] as String?,
      isPrimaryContact: json['isPrimaryContact'] as bool? ?? false,
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
    );
  }
  final String id;
  final String learnerId;
  final String name;
  final String? phone;
  final String? email;
  final String relationship;
  final String? photoUrl;
  final bool isPrimaryContact;
  final DateTime? expiresAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'learnerId': learnerId,
      'name': name,
      'phone': phone,
      'email': email,
      'relationship': relationship,
      'photoUrl': photoUrl,
      'isPrimaryContact': isPrimaryContact,
      'expiresAt': expiresAt?.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => <Object?>[
        id,
        learnerId,
        name,
        phone,
        email,
        relationship,
        photoUrl,
        isPrimaryContact,
        expiresAt,
      ];
}

/// Learner check-in summary for the day
class LearnerDaySummary extends Equatable {

  const LearnerDaySummary({
    required this.learnerId,
    required this.learnerName,
    this.learnerPhoto,
    this.currentStatus,
    this.checkedInAt,
    this.checkedOutAt,
    this.checkedInBy,
    this.checkedOutBy,
    this.authorizedPickups = const [],
  });
  final String learnerId;
  final String learnerName;
  final String? learnerPhoto;
  final CheckStatus? currentStatus;
  final DateTime? checkedInAt;
  final DateTime? checkedOutAt;
  final String? checkedInBy;
  final String? checkedOutBy;
  final List<AuthorizedPickup> authorizedPickups;

  bool get isCurrentlyPresent =>
      currentStatus == CheckStatus.checkedIn ||
      currentStatus == CheckStatus.late;

  @override
  List<Object?> get props => <Object?>[
        learnerId,
        learnerName,
        learnerPhoto,
        currentStatus,
        checkedInAt,
        checkedOutAt,
        checkedInBy,
        checkedOutBy,
        authorizedPickups,
      ];
}
