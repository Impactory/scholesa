import 'package:cloud_functions/cloud_functions.dart';

/// NotificationService requests external notifications (email/sms/push) via server pipeline.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  Future<void> requestSend({
    required String channel,
    required String threadId,
    required String messageId,
    required String siteId,
  }) async {
    try {
      await _functions.httpsCallable('requestNotificationSend').call(<String, dynamic>{
        'channel': channel,
        'threadId': threadId,
        'messageId': messageId,
        'siteId': siteId,
      });
    } catch (_) {
      // Best-effort; do not break UI on failure.
    }
  }
}
