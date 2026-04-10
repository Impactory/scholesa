import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../offline/offline_queue.dart';
import 'bos_models.dart';
import 'bos_service.dart';

// ──────────────────────────────────────────────────────
// BOS Event Bus  (44 allowed event types)
// Spec: BOS_MIA_EVENT_SCHEMA.md / HOW_TO §1 (endpoint 1)
// ──────────────────────────────────────────────────────

/// Client-side event bus for BOS interaction events.
///
/// Events are buffered locally and flushed via server ingest endpoint.
/// If offline, they accumulate until connectivity returns.
class BosEventBus {
  BosEventBus._();
  static final BosEventBus instance = BosEventBus._();

  final List<BosEvent> _buffer = <BosEvent>[];
  Timer? _flushTimer;
  static const int _maxBufferSize = 500;
  static OfflineQueue? _offlineQueue;

  // Client-side rate limit mirroring backend's 60 events/minute.
  static const int _rateLimitPerMinute = 60;
  final List<DateTime> _emitTimestamps = <DateTime>[];
  int _droppedByRateLimit = 0;

  /// Number of events dropped by client-side rate limiting since last reset.
  int get droppedByRateLimit => _droppedByRateLimit;

  /// Set the offline queue for persisting unflushed events on app suspend.
  static void setOfflineQueue(OfflineQueue queue) {
    _offlineQueue = queue;
  }

  /// All BOS event types that the client is allowed to emit.
  static const Set<String> allowedBosEvents = <String>{
    // ── Mission lifecycle
    'mission_viewed',
    'mission_selected',
    'mission_started',
    'mission_completed',
    // ── Checkpoint / artifact
    'checkpoint_started',
    'checkpoint_submitted',
    'checkpoint_graded',
    'artifact_created',
    'artifact_submitted',
    'artifact_reviewed',
    'artifact_version_saved',
    'debug_attempted',
    // ── AI help (A0 control surface)
    'ai_help_opened',
    'ai_help_used',
    'ai_coach_response',
    'ai_coach_feedback',
    'ai_learning_goal_updated',
    // ── Metacognition (feeds FDM y_t — Math Contract §8)
    'explain_it_back_submitted',
    'source_check_performed',
    'retrieval_attempted',
    'reflection_submitted',
    // ── MVL (Metacognitive Verification Loop)
    'mvl_gate_triggered',
    'mvl_evidence_attached',
    'mvl_passed',
    'mvl_failed',
    'mvl_needs_more_evidence',
    'mvl_evidence_submitted',
    // ── Teacher override (supervisory control g_t)
    'teacher_override_mvl',
    'teacher_override_intervention',
    'teacher_override_applied',
    // ── Contestability
    'contestability_requested',
    'contestability_resolved',
    // ── Navigation / engagement signals
    'session_joined',
    'session_left',
    'idle_detected',
    'focus_restored',
    'interaction_signal_observed',
    // ── Voice I/O signals (feeds FDM)
    'voice_stt_completed',
    'voice_tts_played',
    // ── Educator insights
    'educator_class_view',
    'educator_learner_drilldown',
    // ── Educator engagement tools (live session)
    'cold_call',
    'poll',
    'exit_ticket',
  };

  /// Enqueue a [BosEvent] for asynchronous flush.
  void emit(BosEvent event) {
    if (!allowedBosEvents.contains(event.eventType)) return;

    // Client-side rate limiting: drop events that would exceed the backend's
    // 60 events/minute limit to avoid silent server-side drops.
    final DateTime now = DateTime.now();
    final DateTime windowStart = now.subtract(const Duration(minutes: 1));
    _emitTimestamps.removeWhere((DateTime t) => t.isBefore(windowStart));
    if (_emitTimestamps.length >= _rateLimitPerMinute) {
      _droppedByRateLimit++;
      return;
    }
    _emitTimestamps.add(now);

    _buffer.add(event);
    if (_buffer.length > _maxBufferSize) {
      _buffer.removeRange(0, _buffer.length - _maxBufferSize);
    }
    _scheduleFlush();
  }

  /// Convenience: build & emit from raw parameters.
  void track({
    required String eventType,
    required String siteId,
    required GradeBand gradeBand,
    String actorRole = 'learner',
    String? sessionOccurrenceId,
    String? missionId,
    String? checkpointId,
    ContextMode contextMode = ContextMode.unknown,
    String? actorIdPseudo,
    String? assignmentId,
    String? lessonId,
    Map<String, dynamic> payload = const <String, dynamic>{},
  }) {
    if (Firebase.apps.isEmpty) return;

    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } on FirebaseException {
      return;
    }

    if (user == null) return;

    emit(BosEvent(
      eventType: eventType,
      siteId: siteId,
      actorId: user.uid,
      actorRole: actorRole,
      gradeBand: gradeBand,
      sessionOccurrenceId: sessionOccurrenceId,
      missionId: missionId,
      checkpointId: checkpointId,
      contextMode: contextMode,
      actorIdPseudo: actorIdPseudo,
      assignmentId: assignmentId,
      lessonId: lessonId,
      payload: payload,
    ));
  }

  void _scheduleFlush() {
    _flushTimer?.cancel();
    _flushTimer = Timer(const Duration(seconds: 2), _flush);
  }

  Future<void> _flush() async {
    if (_buffer.isEmpty) return;

    final List<BosEvent> batch = List<BosEvent>.from(_buffer);
    _buffer.clear();

    try {
      for (final BosEvent event in batch) {
        await BosService.instance.ingestEvent(event);
      }
    } catch (_) {
      // Re-buffer on failure (offline resilience) with backoff.
      _buffer.insertAll(0, batch);
      _flushTimer?.cancel();
      _flushTimer = Timer(const Duration(seconds: 10), _flush);
    }
  }

  /// Force immediate flush (e.g. on app suspend).
  /// If flush fails and offline queue is available, persists remaining events.
  Future<void> flushNow() async {
    _flushTimer?.cancel();
    await _flush();
    // Persist any remaining unflushed events to offline queue.
    if (_buffer.isNotEmpty && _offlineQueue != null) {
      for (final BosEvent event in _buffer) {
        await _offlineQueue!.enqueue(OpType.bosEventIngest, event.toMap());
      }
      _buffer.clear();
    }
  }
}
