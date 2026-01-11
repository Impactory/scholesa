import 'package:cloud_functions/cloud_functions.dart';

class TelemetryService {
  TelemetryService._();
  static final TelemetryService instance = TelemetryService._();

  static const Set<String> allowedEvents = {
    'auth.login',
    'auth.logout',
    'attendance.recorded',
    'mission.attempt.submitted',
    'message.sent',
    'order.paid',
    'cms.page.viewed',
    'lead.submitted',
    'contract.created',
    'contract.approved',
    'deliverable.submitted',
    'deliverable.accepted',
    'payout.approved',
    'aiDraft.requested',
    'aiDraft.reviewed',
    'order.intent',
  };

  FirebaseFunctions? _functions;

  FirebaseFunctions? get _safeFunctions {
    if (_functions != null) return _functions;
    try {
      _functions = FirebaseFunctions.instance;
    } catch (_) {
      return null;
    }
    return _functions;
  }

  Future<void> logEvent({
    required String event,
    String? role,
    String? siteId,
    Map<String, dynamic>? metadata,
  }) async {
    if (!allowedEvents.contains(event)) return;
    final functions = _safeFunctions;
    if (functions == null) return;
    try {
      await functions.httpsCallable('logTelemetryEvent').call(<String, dynamic>{
        'event': event,
        if (role != null && role.isNotEmpty) 'role': role,
        if (siteId != null && siteId.isNotEmpty) 'siteId': siteId,
        if (metadata != null) 'metadata': metadata,
      });
    } catch (_) {
      // Telemetry should never break UX.
    }
  }
}
