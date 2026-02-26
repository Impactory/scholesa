import 'dart:async';
import '../bos/bos_engine.dart';
import '../telemetry/telemetry_models.dart';
import '../safety/safety_guard.dart';

/// C2) Voice Pipeline
/// Manages STT streaming, TTS playback, and Barge-in.
class VoicePipeline {
  final BosEngine _bos;
  final SafetyGuard _safetyGuard;
  
  // Mock streams for hardware interfaces
  final StreamController<String> _sttStream = StreamController();
  bool _isTtsPlaying = false;

  VoicePipeline(this._bos, this._safetyGuard) {
    // Listen to BOS actions (TTS requests)
    _bos.actions.listen(_handleBosAction);
  }

  /// Simulate receiving a final transcript from STT provider
  void onSttResult(String text) {
    if (_isTtsPlaying) {
      _handleBargeIn();
    }

    // D2) PII Redaction
    final (redactedText, foundPii) = _safetyGuard.redact(text);

    if (foundPii) {
      _bos.handleEvent(BosEvent(
        eventName: BosSignal.piiDetected,
        timestampMs: DateTime.now().millisecondsSinceEpoch,
        sessionId: 'session_123',
        learnerIdHash: 'hash_123',
        payload: {'original_length': text.length},
      ));
    }

    // Emit Learning Signal
    _bos.handleEvent(BosEvent(
      eventName: BosSignal.sttFinalTranscript,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      sessionId: 'session_123',
      learnerIdHash: 'hash_123',
      payload: {
        'transcript': redactedText,
        'confidence': 0.95, // Mock
      },
    ));
  }

  void _handleBosAction(String action) {
    if (action.startsWith('TTS:')) {
      final textToSpeak = action.substring(4).trim();
      _speak(textToSpeak);
    }
  }

  Future<void> _speak(String text) async {
    if (!_safetyGuard.canProceed('tts')) return;

    _bos.handleEvent(BosEvent(
      eventName: BosSignal.ttsRequestStarted,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      sessionId: 'session_123',
      learnerIdHash: 'hash_123',
      payload: {'text_length': text.length},
    ));

    _isTtsPlaying = true;
    print('🔊 TTS PLAYING: "$text"');
    
    // Simulate audio duration
    await Future.delayed(Duration(milliseconds: 500)); 
    
    _isTtsPlaying = false;
  }

  void _handleBargeIn() {
    print('🛑 BARGE-IN DETECTED: Stopping TTS');
    _isTtsPlaying = false;
    
    _bos.handleEvent(BosEvent(
      eventName: BosSignal.bargeInDetected,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      sessionId: 'session_123',
      learnerIdHash: 'hash_123',
    ));
  }

  void dispose() {
    _sttStream.close();
  }
}