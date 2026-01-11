import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/models.dart';
import '../../domain/repositories.dart';
import '../../services/telemetry_service.dart';
import 'offline_queue.dart';

/// Registers dispatchers that persist queued actions when back online.
void registerOfflineDispatchers(OfflineQueue queue) {
  final attendanceRepository = AttendanceRepository();
  final missionAttemptRepository = MissionAttemptRepository();
  final portfolioItemRepository = PortfolioItemRepository();
  final credentialRepository = CredentialRepository();
  final auditLogRepository = AuditLogRepository();
  final leadRepository = LeadRepository();
  final messageRepository = MessageRepository();

  queue.registerDispatcher('demo', (action) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    return _write('offlineDemoActions', user.uid, action);
  });

  queue.registerDispatcher('lead', (action) async {
    final payload = action.payload;
    final String? name = _string(payload, 'name');
    final String? email = _string(payload, 'email');
    if (name == null || name.isEmpty || email == null || email.isEmpty) {
      return false;
    }
    final String source = _string(payload, 'source') ?? 'unknown';
    try {
      await leadRepository.createLead(
        name: name,
        email: email,
        source: source,
        message: _string(payload, 'message'),
        siteId: _string(payload, 'siteId'),
        slug: _string(payload, 'slug'),
      );
      await TelemetryService.instance.logEvent(
        event: 'lead.submitted',
        metadata: {
          'source': source,
          if (_string(payload, 'slug') != null) 'slug': _string(payload, 'slug'),
        },
      );
      return true;
    } catch (_) {
      return false;
    }
  });

  queue.registerDispatcher('attendance', (action) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final payload = action.payload;
    final String? siteIdValue = _string(payload, 'siteId');
    final String? sessionOccurrenceIdValue = _string(payload, 'sessionOccurrenceId');
    final String? learnerIdValue = _string(payload, 'learnerId');
    final String recordedBy = _string(payload, 'recordedBy') ?? user.uid;
    final String status = _string(payload, 'status') ?? 'present';
    if ([siteIdValue, sessionOccurrenceIdValue, learnerIdValue, recordedBy, status].any((String? v) => v == null || v.isEmpty)) {
      return false;
    }
    final String siteId = siteIdValue!;
    final String sessionOccurrenceId = sessionOccurrenceIdValue!;
    final String learnerId = learnerIdValue!;
    final model = AttendanceRecordModel(
      id: attendanceRepository.deterministicId(sessionOccurrenceId, learnerId),
      siteId: siteId,
      sessionOccurrenceId: sessionOccurrenceId,
      learnerId: learnerId,
      status: status,
      recordedBy: recordedBy,
      note: _string(payload, 'note'),
      createdAt: Timestamp.fromDate(action.createdAt),
      updatedAt: Timestamp.now(),
    );
    try {
      await attendanceRepository.upsert(model);
      await auditLogRepository.log(
        AuditLogModel(
          id: 'audit-attendance-${model.id}-${action.createdAt.millisecondsSinceEpoch}',
          actorId: user.uid,
          actorRole: _string(payload, 'actorRole') ?? 'educator',
          action: 'attendance.upsert',
          entityType: 'attendanceRecord',
          entityId: model.id,
          siteId: siteId,
          details: {
            'sessionOccurrenceId': sessionOccurrenceId,
            'learnerId': learnerId,
            'status': status,
          },
          createdAt: Timestamp.now(),
        ),
      );
      try {
        await TelemetryService.instance.logEvent(
          event: 'attendance.recorded',
          role: _string(payload, 'actorRole') ?? 'educator',
          siteId: siteId,
          metadata: {
            'sessionOccurrenceId': sessionOccurrenceId,
            'learnerId': learnerId,
            'status': status,
          },
        );
      } catch (_) {
        // Best-effort telemetry; do not fail dispatch.
      }
      return true;
    } catch (_) {
      return false;
    }
  });

  queue.registerDispatcher('missionAttempt', (action) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final payload = action.payload;
    final String? siteIdValue = _string(payload, 'siteId');
    final String? missionIdValue = _string(payload, 'missionId');
    final String learnerIdValue = _string(payload, 'learnerId') ?? user.uid;
    final String status = _string(payload, 'status') ?? 'submitted';
    if ([siteIdValue, missionIdValue].any((String? v) => v == null || v.isEmpty) || learnerIdValue.isEmpty) {
      return false;
    }
    final String siteId = siteIdValue!;
    final String missionId = missionIdValue!;
    final String learnerId = learnerIdValue;
    final model = MissionAttemptModel(
      id: action.id,
      siteId: siteId,
      missionId: missionId,
      learnerId: learnerId,
      status: status,
      sessionOccurrenceId: _string(payload, 'sessionOccurrenceId'),
      reflection: _string(payload, 'reflection'),
      artifactUrls: _stringList(payload, 'artifactUrls'),
      pillarCodes: _stringList(payload, 'pillarCodes'),
      createdAt: Timestamp.fromDate(action.createdAt),
      updatedAt: Timestamp.now(),
    );
    try {
      await missionAttemptRepository.upsert(model);
      await auditLogRepository.log(
        AuditLogModel(
          id: 'audit-missionAttempt-${model.id}-${action.createdAt.millisecondsSinceEpoch}',
          actorId: user.uid,
          actorRole: _string(payload, 'actorRole') ?? 'learner',
          action: 'missionAttempt.upsert',
          entityType: 'missionAttempt',
          entityId: model.id,
          siteId: siteId,
          details: {
            'missionId': missionId,
            'status': status,
          },
          createdAt: Timestamp.now(),
        ),
      );
      try {
        await TelemetryService.instance.logEvent(
          event: 'mission.attempt.submitted',
          role: _string(payload, 'actorRole') ?? 'learner',
          siteId: siteId,
          metadata: {
            'missionId': missionId,
            'learnerId': learnerId,
            'status': status,
          },
        );
      } catch (_) {
        // Best-effort telemetry; do not fail dispatch.
      }
      return true;
    } catch (_) {
      return false;
    }
  });

  queue.registerDispatcher('portfolioItem', (action) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final payload = action.payload;
    final String? siteIdValue = _string(payload, 'siteId');
    final String learnerIdValue = _string(payload, 'learnerId') ?? user.uid;
    final String? titleValue = _string(payload, 'title');
    if ([siteIdValue, titleValue].any((String? v) => v == null || v.isEmpty) || learnerIdValue.isEmpty) {
      return false;
    }
    final String siteId = siteIdValue!;
    final String learnerId = learnerIdValue;
    final String title = titleValue!;
    final model = PortfolioItemModel(
      id: action.id,
      siteId: siteId,
      learnerId: learnerId,
      title: title,
      description: _string(payload, 'description'),
      pillarCodes: _stringList(payload, 'pillarCodes'),
      artifactUrls: _stringList(payload, 'artifactUrls'),
      skillIds: _stringList(payload, 'skillIds'),
      createdAt: Timestamp.fromDate(action.createdAt),
      updatedAt: Timestamp.now(),
    );
    try {
      await portfolioItemRepository.upsert(model);
      await auditLogRepository.log(
        AuditLogModel(
          id: 'audit-portfolio-${model.id}-${action.createdAt.millisecondsSinceEpoch}',
          actorId: user.uid,
          actorRole: _string(payload, 'actorRole') ?? 'learner',
          action: 'portfolioItem.upsert',
          entityType: 'portfolioItem',
          entityId: model.id,
          siteId: siteId,
          details: {
            'learnerId': learnerId,
            'missionId': _string(payload, 'missionId'),
          },
          createdAt: Timestamp.now(),
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  });

  queue.registerDispatcher('credential', (action) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final payload = action.payload;
    final String? siteIdValue = _string(payload, 'siteId');
    final String learnerIdValue = _string(payload, 'learnerId') ?? user.uid;
    final String? titleValue = _string(payload, 'title');
    final DateTime issuedAt = _parseDate(_string(payload, 'issuedAt')) ?? action.createdAt;
    if ([siteIdValue, titleValue].any((String? v) => v == null || v.isEmpty) || learnerIdValue.isEmpty) {
      return false;
    }
    final String siteId = siteIdValue!;
    final String title = titleValue!;
    final model = CredentialModel(
      id: action.id,
      siteId: siteId,
      learnerId: learnerIdValue,
      title: title,
      issuedAt: Timestamp.fromDate(issuedAt),
      pillarCodes: _stringList(payload, 'pillarCodes'),
      skillIds: _stringList(payload, 'skillIds'),
      createdAt: Timestamp.fromDate(action.createdAt),
      updatedAt: Timestamp.now(),
    );
    try {
      await credentialRepository.upsert(model);
      await auditLogRepository.log(
        AuditLogModel(
          id: 'audit-credential-${model.id}-${action.createdAt.millisecondsSinceEpoch}',
          actorId: user.uid,
          actorRole: _string(payload, 'actorRole') ?? 'educator',
          action: 'credential.upsert',
          entityType: 'credential',
          entityId: model.id,
          siteId: siteId,
          details: {
            'learnerId': learnerIdValue,
            'title': title,
          },
          createdAt: Timestamp.now(),
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  });

  // Messaging drafts are allowed offline only for in-app delivery (no external notification).
  queue.registerDispatcher('message', (action) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final payload = action.payload;
    final String? siteId = _string(payload, 'siteId');
    final String? threadId = _string(payload, 'threadId');
    final String? body = _string(payload, 'body');
    final String role = _string(payload, 'role') ?? 'learner';
    if ([siteId, threadId, body].any((v) => v == null || v.isEmpty)) return false;
    final model = MessageModel(
      id: action.id,
      threadId: threadId!,
      siteId: siteId!,
      senderId: user.uid,
      senderRole: role,
      body: body!,
      createdAt: Timestamp.fromDate(action.createdAt),
    );
    try {
      await messageRepository.add(model);
      try {
        await TelemetryService.instance.logEvent(
          event: 'message.sent',
          role: role,
          siteId: siteId,
          metadata: {'threadId': threadId, 'length': body.length, 'offline': true},
        );
      } catch (_) {}
      return true;
    } catch (_) {
      return false;
    }
  });
}

Future<bool> _write(String collection, String uid, PendingAction action) async {
  try {
    await FirebaseFirestore.instance.collection(collection).add({
      'uid': uid,
      'payload': action.payload,
      'createdAt': Timestamp.fromDate(action.createdAt),
      'syncedAt': Timestamp.now(),
      'type': action.type,
    });
    return true;
  } catch (_) {
    return false;
  }
}

String? _string(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is String) return value;
  return null;
}

List<String> _stringList(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is List) {
    return value.whereType<String>().where((String v) => v.isNotEmpty).toList();
  }
  return const <String>[];
}

DateTime? _parseDate(String? value) {
  if (value == null || value.isEmpty) return null;
  try {
    return DateTime.parse(value);
  } catch (_) {
    return null;
  }
}
