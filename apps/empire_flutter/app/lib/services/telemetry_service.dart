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
    'cta.clicked',
    // BOS+MIA Runtime Events
    'mission_viewed',
    'mission_selected',
    'mission_started',
    'mission_completed',
    'checkpoint_started',
    'checkpoint_submitted',
    'checkpoint_graded',
    'artifact_created',
    'artifact_submitted',
    'artifact_reviewed',
    'ai_help_opened',
    'ai_help_used',
    'ai_coach_response',
    'ai_coach_feedback',
    'mvl_gate_triggered',
    'mvl_evidence_attached',
    'mvl_passed',
    'mvl_failed',
    'teacher_override_mvl',
    'teacher_override_intervention',
    'contestability_requested',
    'contestability_resolved',
    'session_joined',
    'session_left',
    'idle_detected',
    'focus_restored',
    'educator_class_view',
    'educator_learner_drilldown',
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
