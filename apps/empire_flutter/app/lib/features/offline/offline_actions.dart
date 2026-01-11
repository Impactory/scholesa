import 'offline_queue.dart';

/// Convenience helpers to enqueue domain actions for offline/online sync.
class OfflineActions {
  static Future<void> queueMissionAttempt(
    OfflineQueue queue, {
    required String missionId,
    required String siteId,
    required String learnerId,
    String status = 'submitted',
    String? reflection,
    List<String> pillarCodes = const <String>[],
    List<String> artifactUrls = const <String>[],
    String? sessionOccurrenceId,
    String? actorRole,
  }) async {
    final ts = DateTime.now();
    await queue.enqueue(
      PendingAction(
        id: 'missionAttempt-$missionId-$learnerId-${ts.millisecondsSinceEpoch}',
        type: 'missionAttempt',
        payload: {
          'missionId': missionId,
          'siteId': siteId,
          'learnerId': learnerId,
          'status': status,
          'reflection': reflection,
          'pillarCodes': pillarCodes,
          'artifactUrls': artifactUrls,
          if (sessionOccurrenceId != null && sessionOccurrenceId.isNotEmpty) 'sessionOccurrenceId': sessionOccurrenceId,
          if (actorRole != null && actorRole.isNotEmpty) 'actorRole': actorRole,
          'createdAt': ts.toIso8601String(),
        },
        createdAt: ts,
      ),
    );
  }

  static Future<void> queueAttendance(
    OfflineQueue queue, {
    required String sessionOccurrenceId,
    required String siteId,
    required String learnerId,
    required String recordedBy,
    required String status,
    String? note,
    String? actorRole,
  }) async {
    final ts = DateTime.now();
    await queue.enqueue(
      PendingAction(
        id: 'attendance-$sessionOccurrenceId-$learnerId',
        type: 'attendance',
        payload: {
          'sessionOccurrenceId': sessionOccurrenceId,
          'siteId': siteId,
          'learnerId': learnerId,
          'recordedBy': recordedBy,
          'status': status,
          if (note != null && note.isNotEmpty) 'note': note,
          if (actorRole != null && actorRole.isNotEmpty) 'actorRole': actorRole,
          'timestamp': ts.toIso8601String(),
        },
        createdAt: ts,
      ),
    );
  }

  static Future<void> queuePortfolioItem(
    OfflineQueue queue, {
    required String siteId,
    required String learnerId,
    required String title,
    String? description,
    List<String> pillarCodes = const <String>[],
    String? missionId,
    String? url,
    String? actorRole,
  }) async {
    final ts = DateTime.now();
    await queue.enqueue(
      PendingAction(
        id: 'portfolio-$learnerId-${ts.millisecondsSinceEpoch}',
        type: 'portfolioItem',
        payload: {
          'siteId': siteId,
          'learnerId': learnerId,
          'title': title,
          if (description != null && description.isNotEmpty) 'description': description,
          'pillarCodes': pillarCodes,
          if (missionId != null && missionId.isNotEmpty) 'missionId': missionId,
          if (url != null && url.isNotEmpty) 'url': url,
          if (actorRole != null && actorRole.isNotEmpty) 'actorRole': actorRole,
          'createdAt': ts.toIso8601String(),
        },
        createdAt: ts,
      ),
    );
  }

  static Future<void> queueLead(
    OfflineQueue queue, {
    required String name,
    required String email,
    required String source,
    String? message,
    String? siteId,
    String? slug,
  }) async {
    final ts = DateTime.now();
    await queue.enqueue(
      PendingAction(
        id: 'lead-${ts.millisecondsSinceEpoch}-${email.trim()}',
        type: 'lead',
        payload: {
          'name': name,
          'email': email,
          'source': source,
          if (message != null && message.isNotEmpty) 'message': message,
          if (siteId != null && siteId.isNotEmpty) 'siteId': siteId,
          if (slug != null && slug.isNotEmpty) 'slug': slug,
          'createdAt': ts.toIso8601String(),
        },
        createdAt: ts,
      ),
    );
  }
}
