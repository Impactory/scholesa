import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'bos_models.dart';

// ──────────────────────────────────────────────────────
// BOS Event Bus
// Spec: BOS_MIA_EVENT_SCHEMA.md / HOW_TO §1 (endpoint 1)
// ──────────────────────────────────────────────────────

/// Client-side event bus for BOS interaction events.
///
/// Events are buffered locally and flushed to Firestore in batches.
/// If offline, they accumulate until connectivity returns.
class BosEventBus {
  BosEventBus._();
  static final BosEventBus instance = BosEventBus._();

  final List<Map<String, dynamic>> _buffer = <Map<String, dynamic>>[];
  Timer? _flushTimer;

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
    // ── AI Coach (A0 control surface)
    'ai_help_opened',
    'ai_help_used',
    'ai_coach_response',
    'ai_coach_feedback',
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
    // ── Educator insights
    'educator_class_view',
    'educator_learner_drilldown',
  };

  /// Enqueue a [BosEvent] for asynchronous flush.
  void emit(BosEvent event) {
    if (!allowedBosEvents.contains(event.eventType)) return;
    _buffer.add(event.toMap());
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
    final User? user = FirebaseAuth.instance.currentUser;
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

    final List<Map<String, dynamic>> batch =
        List<Map<String, dynamic>>.from(_buffer);
    _buffer.clear();

    final WriteBatch wb = FirebaseFirestore.instance.batch();
    final CollectionReference<Map<String, dynamic>> col =
        FirebaseFirestore.instance.collection('interactionEvents');

    for (final Map<String, dynamic> event in batch) {
      wb.set(col.doc(), event);
    }

    try {
      await wb.commit();
    } catch (_) {
      // Re-buffer on failure (offline resilience).
      _buffer.insertAll(0, batch);
      _scheduleFlush();
    }
  }

  /// Force immediate flush (e.g. on app suspend).
  Future<void> flushNow() async {
    _flushTimer?.cancel();
    await _flush();
  }
}
