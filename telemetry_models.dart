import 'package:flutter/foundation.dart';

/// A2) Canonical Event Envelope
/// Immutable, structured event for all system signals.
@immutable
class BosEvent {
  final String eventName;
  final String eventVersion;
  final int timestampMs;
  final String sessionId;
  final String learnerIdHash; // Hashed for privacy
  final String actor; // 'learner', 'teacher', 'system'
  final Map<String, dynamic> context;
  final Map<String, dynamic> privacy;
  final Map<String, dynamic> payload;
  final Map<String, dynamic> metrics;
  final String? traceId;

  const BosEvent({
    required this.eventName,
    this.eventVersion = '1.0.0',
    required this.timestampMs,
    required this.sessionId,
    required this.learnerIdHash,
    this.actor = 'system',
    this.context = const {},
    this.privacy = const {'data_class': 'pseudonymous'},
    this.payload = const {},
    this.metrics = const {},
    this.traceId,
  });

  Map<String, dynamic> toMap() {
    return {
      'event_name': eventName,
      'event_version': eventVersion,
      'timestamp_ms': timestampMs,
      'session_id': sessionId,
      'learner_id_hash': learnerIdHash,
      'actor': actor,
      'context': context,
      'privacy': privacy,
      'payload': payload,
      'metrics': metrics,
      'trace_id': traceId,
    };
  }
}

/// A3) Event Taxonomy Constants
class BosSignal {
  // Learning
  static const String sessionStarted = 'session_started';
  static const String confusionDetected = 'confusion_detected';
  static const String hintRequested = 'hint_requested';
  static const String masteryUpdated = 'mastery_estimate_updated';
  
  // Voice
  static const String sttFinalTranscript = 'stt_final_transcript';
  static const String ttsRequestStarted = 'tts_request_started';
  static const String bargeInDetected = 'barge_in_detected';
  static const String silenceDetected = 'silence_detected';

  // Safety
  static const String piiDetected = 'pii_detected_redacted';
  static const String safeModeActivated = 'safe_mode_activated';
  static const String policyBlock = 'policy_check_blocked';
}