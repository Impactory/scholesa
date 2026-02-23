import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

typedef TelemetryDispatcher = Future<void> Function(
  Map<String, dynamic> payload,
);

const String _telemetryDispatcherZoneKey = 'scholesa.telemetry.dispatcher';

class TelemetryFailure {
  TelemetryFailure({
    required this.event,
    required this.payload,
    required this.error,
    required this.stackTrace,
    required this.occurredAt,
  });

  final String event;
  final Map<String, dynamic> payload;
  final Object error;
  final StackTrace stackTrace;
  final DateTime occurredAt;
}

class TelemetryService {
  TelemetryService._();
  static final TelemetryService instance = TelemetryService._();
  static const String _defaultAppVersion =
      String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0-rc.2');

  static const Set<String> knownCoreEvents = {
    'auth.login',
    'auth.logout',
    'attendance.recorded',
    'mission.attempt.submitted',
    'message.sent',
    'order.paid',
    'cms.page.viewed',
    'popup.shown',
    'popup.dismissed',
    'popup.completed',
    'nudge.snoozed',
    'insight.viewed',
    'support.applied',
    'support.outcome.logged',
    'educator.review.completed',
    'site.checkin',
    'site.checkout',
    'site.late_pickup.flagged',
    'schedule.viewed',
    'room.conflict.detected',
    'substitute.requested',
    'substitute.assigned',
    'mission.snapshot.created',
    'rubric.applied',
    'rubric.shared_to_parent_summary',
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
    'site.switched',
    'export.requested',
    'export.downloaded',
    'notification.requested',
    'fdm.state.changed',
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
  TelemetryDispatcher? _dispatcher;
  final List<TelemetryFailure> _recentFailures = <TelemetryFailure>[];
  static const int _maxRetainedFailures = 100;
  static Future<T> runWithDispatcher<T>(
    TelemetryDispatcher dispatcher,
    Future<T> Function() body,
  ) {
    return runZoned(
      body,
      zoneValues: <Object?, Object?>{_telemetryDispatcherZoneKey: dispatcher},
    );
  }

  FirebaseFunctions get _requiredFunctions {
    return _functions ??= FirebaseFunctions.instance;
  }

  void configureDispatcher(TelemetryDispatcher dispatcher) {
    _dispatcher = dispatcher;
  }

  void clearDispatcherOverride() {
    _dispatcher = null;
  }

  List<TelemetryFailure> get recentFailures =>
      List<TelemetryFailure>.unmodifiable(_recentFailures);

  void clearFailures() {
    _recentFailures.clear();
  }

  Future<void> logEvent({
    required String event,
    String? role,
    String? siteId,
    Map<String, dynamic>? metadata,
  }) async {
    final Map<String, dynamic> enrichedMetadata = <String, dynamic>{
      ...(metadata ?? const <String, dynamic>{}),
    };
    enrichedMetadata.putIfAbsent('appVersion', () => _defaultAppVersion);

    final Map<String, dynamic> payload = <String, dynamic>{
      'event': event,
      if (role != null && role.isNotEmpty) 'role': role,
      if (siteId != null && siteId.isNotEmpty) 'siteId': siteId,
      'metadata': enrichedMetadata,
    };

    try {
      final TelemetryDispatcher? zonedDispatcher =
          Zone.current[_telemetryDispatcherZoneKey] as TelemetryDispatcher?;

      if (zonedDispatcher != null) {
        await zonedDispatcher(payload);
        return;
      }

      if (_dispatcher != null) {
        await _dispatcher!(payload);
        return;
      }

      await _requiredFunctions.httpsCallable('logTelemetryEvent').call(payload);
    } catch (error, stackTrace) {
      _recentFailures.add(
        TelemetryFailure(
          event: event,
          payload: Map<String, dynamic>.from(payload),
          error: error,
          stackTrace: stackTrace,
          occurredAt: DateTime.now(),
        ),
      );
      if (_recentFailures.length > _maxRetainedFailures) {
        _recentFailures.removeRange(
            0, _recentFailures.length - _maxRetainedFailures);
      }
      debugPrint('TelemetryService failure for "$event": $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
