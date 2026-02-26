/// Standardized Event Envelope for all Telemetry
class TelemetryEvent {
  final String eventName;
  final String eventVersion;
  final int timestampMs;
  final String sessionId;
  final String learnerIdHash; // Hashed for privacy
  final String deviceIdHash;
  final String actor; // 'learner' | 'teacher' | 'system'
  final Map<String, dynamic> context;
  final Map<String, dynamic> privacy;
  final Map<String, dynamic> payload;
  final Map<String, dynamic> metrics;
  final Map<String, dynamic>? trace;

  TelemetryEvent({
    required this.eventName,
    this.eventVersion = '1.0.0',
    required this.timestampMs,
    required this.sessionId,
    required this.learnerIdHash,
    required this.deviceIdHash,
    required this.actor,
    required this.context,
    required this.privacy,
    required this.payload,
    this.metrics = const {},
    this.trace,
  });

  Map<String, dynamic> toJson() => {
        'event_name': eventName,
        'event_version': eventVersion,
        'timestamp_ms': timestampMs,
        'session_id': sessionId,
        'learner_id_hash': learnerIdHash,
        'device_id_hash': deviceIdHash,
        'actor': actor,
        'context': context,
        'privacy': privacy,
        'payload': payload,
        'metrics': metrics,
        'trace': trace,
      };
}

/// BOS State Definitions
enum BosState {
  onboarding,
  instruction,
  guidedPractice,
  buildTime,
  checkpoint,
  reflection,
  coachingRecovery,
  safeMode,
}

/// Voice Signals
class VoiceSignals {
  static const String sttStreamStarted = 'voice.stt_stream_started';
  static const String sttFinalTranscript = 'voice.stt_final_transcript';
  static const String ttsRequestStarted = 'voice.tts_request_started';
  static const String bargeInDetected = 'voice.barge_in_detected';
  static const String turnTakingTimeout = 'voice.turn_taking_timeout';
}

/// Learning Signals
class LearningSignals {
  static const String confusionDetected = 'learning.confusion_detected';
  static const String hintRequested = 'learning.hint_requested';
  static const String masteryUpdated = 'learning.mastery_estimate_updated';
}