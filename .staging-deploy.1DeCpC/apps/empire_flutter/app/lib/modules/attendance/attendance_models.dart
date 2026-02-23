import 'package:equatable/equatable.dart';

/// Attendance status
enum AttendanceStatus {
  present,
  late,
  absent,
  excused,
}

/// Attendance record model
class AttendanceRecord extends Equatable {

  const AttendanceRecord({
    this.id,
    this.siteId,
    required this.occurrenceId,
    required this.learnerId,
    required this.status,
    this.notes,
    required this.recordedAt,
    this.recordedBy,
    this.isOffline = false,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) => AttendanceRecord(
        id: json['id'] as String?,
        siteId: json['siteId'] as String?,
        occurrenceId: json['occurrenceId'] as String,
        learnerId: json['learnerId'] as String,
        status: AttendanceStatus.values.firstWhere(
          (AttendanceStatus s) => s.name == json['status'],
          orElse: () => AttendanceStatus.absent,
        ),
        notes: json['notes'] as String? ?? json['note'] as String?,
        recordedAt: json['recordedAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(json['recordedAt'] as int)
            : DateTime.now(),
        recordedBy: json['recordedBy'] as String?,
      );
  final String? id;
  final String? siteId;
  final String occurrenceId;
  final String learnerId;
  final AttendanceStatus status;
  final String? notes;
  final DateTime recordedAt;
  final String? recordedBy;
  final bool isOffline;

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (id != null) 'id': id,
        if (siteId != null) 'siteId': siteId,
        'occurrenceId': occurrenceId,
        'learnerId': learnerId,
        'status': status.name,
        'notes': notes,
        'recordedAtClient': recordedAt.millisecondsSinceEpoch,
        'recordedBy': recordedBy,
      };

  AttendanceRecord copyWith({
    String? id,
    String? siteId,
    String? occurrenceId,
    String? learnerId,
    AttendanceStatus? status,
    String? notes,
    DateTime? recordedAt,
    String? recordedBy,
    bool? isOffline,
  }) {
    return AttendanceRecord(
      id: id ?? this.id,
      siteId: siteId ?? this.siteId,
      occurrenceId: occurrenceId ?? this.occurrenceId,
      learnerId: learnerId ?? this.learnerId,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      recordedAt: recordedAt ?? this.recordedAt,
      recordedBy: recordedBy ?? this.recordedBy,
      isOffline: isOffline ?? this.isOffline,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        id,
        siteId,
        occurrenceId,
        learnerId,
        status,
        notes,
        recordedAt,
        recordedBy,
      ];
}

/// Learner in roster
class RosterLearner extends Equatable {

  const RosterLearner({
    required this.id,
    required this.displayName,
    this.photoUrl,
    this.currentAttendance,
  });

  factory RosterLearner.fromJson(Map<String, dynamic> json) => RosterLearner(
        id: json['id'] as String,
        displayName: json['displayName'] as String,
        photoUrl: json['photoUrl'] as String?,
        currentAttendance: json['attendance'] != null
            ? AttendanceRecord.fromJson(json['attendance'] as Map<String, dynamic>)
            : null,
      );
  final String id;
  final String displayName;
  final String? photoUrl;
  final AttendanceRecord? currentAttendance;

  @override
  List<Object?> get props => <Object?>[id, displayName, photoUrl, currentAttendance];
}

/// Session occurrence
class SessionOccurrence extends Equatable {

  const SessionOccurrence({
    required this.id,
    required this.sessionId,
    required this.siteId,
    required this.title,
    required this.startTime,
    this.endTime,
    this.roomName,
    this.roster = const <RosterLearner>[],
    this.learnerCount,
  });

  factory SessionOccurrence.fromJson(Map<String, dynamic> json) => SessionOccurrence(
        id: json['id'] as String,
        sessionId: json['sessionId'] as String,
        siteId: json['siteId'] as String,
        title: json['title'] as String,
        startTime: DateTime.fromMillisecondsSinceEpoch(json['startTime'] as int),
        endTime: json['endTime'] != null 
            ? DateTime.fromMillisecondsSinceEpoch(json['endTime'] as int)
            : null,
        roomName: json['roomName'] as String?,
        roster: (json['roster'] as List?)
                ?.map((dynamic e) => RosterLearner.fromJson(e as Map<String, dynamic>))
                .toList() ??
            <RosterLearner>[],
        learnerCount: json['learnerCount'] as int?,
      );
  final String id;
  final String sessionId;
  final String siteId;
  final String title;
  final DateTime startTime;
  final DateTime? endTime;
  final String? roomName;
  final List<RosterLearner> roster;
  final int? learnerCount;

  SessionOccurrence copyWith({
    String? id,
    String? sessionId,
    String? siteId,
    String? title,
    DateTime? startTime,
    DateTime? endTime,
    String? roomName,
    List<RosterLearner>? roster,
    int? learnerCount,
  }) {
    return SessionOccurrence(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      siteId: siteId ?? this.siteId,
      title: title ?? this.title,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      roomName: roomName ?? this.roomName,
      roster: roster ?? this.roster,
      learnerCount: learnerCount ?? this.learnerCount,
    );
  }

  @override
  List<Object?> get props => <Object?>[id, sessionId, siteId, title, startTime, endTime, learnerCount];
}
