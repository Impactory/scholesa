import 'dart:async';
import '../../services/telemetry_service.dart';
import './event_types.dart';

enum VoiceStatus { idle, listening, processing, speaking }

/// Voice Intelligence Manager
/// Handles STT/TTS streams, turn-taking, and barge-in.
class VoiceManager {
  final TelemetryService _telemetry;
  VoiceStatus _status = VoiceStatus.idle;
  Timer? _silenceTimer;
  
  // Config
  final Duration _silenceThreshold = const Duration(seconds: 5); // Grade 1-3 default

  VoiceManager(this._telemetry);

  double _estimateTranscriptConfidence(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 0;
    if (trimmed.length < 10) return 0.6;
    if (trimmed.length < 24) return 0.75;
    return 0.9;
  }

  /// Start Listening (STT)
  void startListening() {
    _status = VoiceStatus.listening;
    _telemetry.logEvent(event: VoiceSignals.sttStreamStarted, metadata: {});
    
    // Simulate silence timeout (Turn-Taking)
    _startSilenceTimer();
  }

  /// Simulate receiving a transcript chunk
  void onTranscriptReceived(String text, bool isFinal) {
    _resetSilenceTimer();
    
    if (isFinal) {
      _status = VoiceStatus.processing;
      _telemetry.logEvent(
        event: VoiceSignals.sttFinalTranscript,
        metadata: {
          'transcript': _redactPii(text), // Redact before emit
          'confidence': _estimateTranscriptConfidence(text),
        },
      );
    }
  }

  /// Speak (TTS) with Barge-In support
  void speak(String text) {
    // 1. Safety check
    if (_containsUnsafeContent(text)) {
      _telemetry.logEvent(
        event: 'safety.unsafe_content_detected', 
        metadata: {'source': 'tts_plan'}
      );
      return;
    }

    _status = VoiceStatus.speaking;
    _telemetry.logEvent(
      event: VoiceSignals.ttsRequestStarted,
      metadata: {'text_length': text.length},
    );

    // Simulate audio playback...
  }

  /// Handle User Interruption
  void handleBargeIn() {
    if (_status == VoiceStatus.speaking) {
      _stopTts();
      _telemetry.logEvent(event: VoiceSignals.bargeInDetected, metadata: {});
      startListening(); // Immediately switch to listening
    }
  }

  void _stopTts() {
    _status = VoiceStatus.idle;
  }

  void _startSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(_silenceThreshold, () {
      if (_status == VoiceStatus.listening) {
        _telemetry.logEvent(
          event: VoiceSignals.turnTakingTimeout,
          metadata: {'threshold_ms': _silenceThreshold.inMilliseconds},
        );
      }
    });
  }

  void _resetSilenceTimer() {
    if (_silenceTimer != null && _silenceTimer!.isActive) {
      _silenceTimer!.cancel();
    }
  }

  String _redactPii(String input) {
    // Basic redaction
    return input.replaceAll(RegExp(r'\b\d{3}-\d{2}-\d{4}\b'), '[SSN]');
  }

  bool _containsUnsafeContent(String text) {
    final lower = text.toLowerCase();
    const blockedPatterns = <String>[
      'kill',
      'self harm',
      'suicide',
      'hate',
      'abuse',
      'violence',
    ];
    return blockedPatterns.any(lower.contains);
  }
}