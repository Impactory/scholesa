import 'dart:async';
import './bos_engine.dart';
import './telemetry_models.dart';
import './safety_guard.dart';

enum VoiceStatus { idle, listening, processing, speaking }

/// C2) Voice Pipeline
/// Manages STT streaming, TTS playback, and Barge-in.
class VoicePipeline {
  final BosEngine _bos;
  final SafetyGuard _safetyGuard;
  final String _sessionId;
  final String _learnerIdHash;
  
  final StreamController<String> _sttStream = StreamController();
  bool _isTtsPlaying = false;
  Timer? _silenceTimer;
  static const Duration _silenceThreshold = Duration(seconds: 8); // Default for 4-6 grade band
  
  final StreamController<VoiceStatus> _statusController = StreamController.broadcast();
  Stream<VoiceStatus> get statusStream => _statusController.stream;

  VoicePipeline(
    this._bos,
    this._safetyGuard, {
    String sessionId = 'session_local',
    String learnerIdHash = 'learner_local',
  }) : _sessionId = sessionId,
       _learnerIdHash = learnerIdHash {
    // Listen to BOS actions (TTS requests)
    _bos.actions.listen(_handleBosAction);
  }

  double _estimateTranscriptConfidence(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 0;
    if (trimmed.length < 12) return 0.62;
    if (trimmed.length < 30) return 0.78;
    return 0.9;
  }

  /// Simulate receiving a final transcript from STT provider
  void onSttResult(String text) {
    _cancelSilenceTimer();

    if (_isTtsPlaying) {
      _handleBargeIn();
    }
    
    _statusController.add(VoiceStatus.processing);

    // D2) PII Redaction
    final (redactedText, foundPii) = _safetyGuard.redact(text);

    if (foundPii) {
      _bos.handleEvent(BosEvent(
        eventName: BosSignal.piiDetected,
        timestampMs: DateTime.now().millisecondsSinceEpoch,
        sessionId: _sessionId,
        learnerIdHash: _learnerIdHash,
        payload: {'original_length': text.length},
      ));
    }

    // Emit Learning Signal
    _bos.handleEvent(BosEvent(
      eventName: BosSignal.sttFinalTranscript,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
        sessionId: _sessionId,
        learnerIdHash: _learnerIdHash,
      payload: {
        'transcript': redactedText,
          'confidence': _estimateTranscriptConfidence(redactedText),
      },
    ));
    
    _statusController.add(VoiceStatus.idle);
    // In a real continuous conversation, we might restart listening here
    // For now, we assume BOS will trigger next action or we wait for wake word
  }

  void _handleBosAction(String action) {
    if (action.startsWith('TTS:')) {
      final textToSpeak = action.substring(4).trim();
      _speak(textToSpeak);
    }
  }

  Future<void> _speak(String text) async {
    if (!_safetyGuard.canProceed('tts')) return;
    
    _cancelSilenceTimer();

    _bos.handleEvent(BosEvent(
      eventName: BosSignal.ttsRequestStarted,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      sessionId: _sessionId,
      learnerIdHash: _learnerIdHash,
      payload: {'text_length': text.length},
    ));

    _isTtsPlaying = true;
    _statusController.add(VoiceStatus.speaking);
    print('🔊 TTS PLAYING: "$text"');
    
    // Simulate audio duration
    await Future.delayed(Duration(milliseconds: 500)); 
    
    _isTtsPlaying = false;
    _statusController.add(VoiceStatus.listening); // Assume we listen after speaking
    _startSilenceTimer();
  }

  void _handleBargeIn() {
    print('🛑 BARGE-IN DETECTED: Stopping TTS');
    _isTtsPlaying = false;
    
    _bos.handleEvent(BosEvent(
      eventName: BosSignal.bargeInDetected,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      sessionId: _sessionId,
      learnerIdHash: _learnerIdHash,
    ));
    _statusController.add(VoiceStatus.listening);
    _startSilenceTimer();
  }

  void _startSilenceTimer() {
    _cancelSilenceTimer();
    _silenceTimer = Timer(_silenceThreshold, () {
      _bos.handleEvent(BosEvent(
        eventName: BosSignal.silenceDetected,
        timestampMs: DateTime.now().millisecondsSinceEpoch,
        sessionId: _sessionId,
        learnerIdHash: _learnerIdHash,
      ));
    });
  }

  void _cancelSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = null;
  }

  void dispose() {
    _sttStream.close();
    _statusController.close();
    _cancelSilenceTimer();
  }
}