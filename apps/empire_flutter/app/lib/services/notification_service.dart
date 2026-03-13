import 'package:cloud_functions/cloud_functions.dart';

/// NotificationService requests external notifications (email/sms/push) via server pipeline.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();
  FirebaseFunctions get _functions => FirebaseFunctions.instance;
  static Future<dynamic> Function(
    String callableName,
    Map<String, dynamic> payload,
  )? _callableInvokerOverride;

  static Future<T> runWithCallableInvoker<T>(
    Future<dynamic> Function(String callableName, Map<String, dynamic> payload)
        invoker,
    Future<T> Function() action,
  ) async {
    final Future<dynamic> Function(String callableName, Map<String, dynamic> payload)?
        previous = _callableInvokerOverride;
    _callableInvokerOverride = invoker;
    try {
      return await action();
    } finally {
      _callableInvokerOverride = previous;
    }
  }

  Future<void> _call(String callableName, Map<String, dynamic> payload) async {
    if (_callableInvokerOverride != null) {
      await _callableInvokerOverride!(callableName, payload);
      return;
    }
    await _functions.httpsCallable(callableName).call(payload);
  }

  Future<void> requestSend({
    required String channel,
    required String threadId,
    required String messageId,
    required String siteId,
  }) async {
    try {
      await _call('requestNotificationSend', <String, dynamic>{
        'channel': channel,
        'threadId': threadId,
        'messageId': messageId,
        'siteId': siteId,
      });
    } catch (_) {
      // Best-effort; do not break UI on failure.
    }
  }

  Future<void> syncLearnerReminderPreference({
    required String siteId,
    required String schedule,
    required int weeklyTargetMinutes,
    required String localeCode,
    required String timeZone,
    String? valuePrompt,
  }) async {
    try {
      await _call('syncLearnerReminderPreference', <String, dynamic>{
        'siteId': siteId,
        'schedule': schedule,
        'weeklyTargetMinutes': weeklyTargetMinutes,
        'localeCode': localeCode,
        'timeZone': timeZone,
        'valuePrompt': valuePrompt,
      });
    } catch (_) {
      // Best-effort; do not break UI on failure.
    }
  }
}
