import 'dart:async';
import '../../services/telemetry_service.dart';
import '../telemetry/event_types.dart';
import '../telemetry/telemetry_models.dart';
import '../safety/safety_guard.dart';

/// B2) BOS States
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

/// Behavioral Orchestration System (BOS)
/// Closed-loop controller for learner state.
class BosEngine {
  BosState _currentState = BosState.onboarding;
  final TelemetryService _telemetry;
  final SafetyGuard _safetyGuard;
  StreamSubscription? _subscription;

  // State Variables (The "x_hat" estimate)
  double _confusionScore = 0.0;
  int _hintCount = 0;
  bool _safetyFlag = false;
  int _consecutiveErrors = 0;
  DateTime _lastInteraction = DateTime.now();

  BosEngine(this._telemetry);
  // Output stream for Voice/UI to consume
  final StreamController<String> _actionController = StreamController.broadcast();
  Stream<String> get actions => _actionController.stream;

  BosEngine(this._telemetry, this._safetyGuard);

  void start() {
    _subscription = _telemetry.events.listen(_handleEvent);
    // In a real app, TelemetryService would expose a stream of BosEvent
    // _subscription = _telemetry.eventStream.listen(_handleEvent);
    _transitionTo(BosState.onboarding);
  }

  void dispose() {
    _subscription?.cancel();
    _actionController.close();
  }

  void _handleEvent(TelemetryEvent event) {
  /// Main Control Loop Entry Point
  void handleEvent(BosEvent event) {
    _lastInteraction = DateTime.now();

    // 1. Sense (Update State Estimate)
    _updateEstimates(event);

    // 2. Control (Check Policies & Transition)
    _evaluatePolicies();
  }

  void _updateEstimates(TelemetryEvent event) {
    if (event.eventName == VoiceSignals.sttFinalTranscript) {
      // Analyze text for confusion (Mock NLP)
  void _updateEstimates(BosEvent event) {
    if (event.eventName == BosSignal.sttFinalTranscript) {
      // B3) Confusion Policy Sensing
      final String text = event.payload['transcript'] ?? '';
      if (text.contains("don't understand") || text.contains("help")) {
      
      // Simple heuristic for demo; real system uses NLP classifier
      if (text.toLowerCase().contains("don't understand") || 
          text.toLowerCase().contains("help") ||
          text.toLowerCase().contains("stuck")) {
        _confusionScore += 0.3;
        _telemetry.logEvent(
          event: LearningSignals.confusionDetected,
        _emitTelemetry(
          BosSignal.confusionDetected,
          metadata: {'score': _confusionScore},
        );
      }
    } else if (event.eventName == LearningSignals.hintRequested) {
    } else if (event.eventName == BosSignal.hintRequested) {
      _hintCount++;
    } else if (event.eventName == BosSignal.safeModeActivated) {
      _transitionTo(BosState.safeMode);
    }
  }

  void _evaluatePolicies() {
    // Safety Policy (Fail-Closed)
    if (_safetyFlag) {
      if (_currentState != BosState.safeMode) {
        _transitionTo(BosState.safeMode);
      }
    // D3) Safety Policy (Fail-Closed)
    if (_safetyGuard.isSafeMode && _currentState != BosState.safeMode) {
      _transitionTo(BosState.safeMode);
      return;
    }

    // Confusion Policy
    // B3.1) Confusion Policy
    if (_confusionScore > 0.7 && _currentState == BosState.instruction) {
      _transitionTo(BosState.coachingRecovery);
      _actionController.add('TTS: I notice this is tricky. Let\'s break it down.');
      return;
    }

    // Hint Dependency Policy
    // B3.2) Hint Dependency Policy
    if (_hintCount > 3 && _currentState != BosState.reflection) {
      // Force a reflection/check
      // Force a reflection/check (Explain-it-back)
      _transitionTo(BosState.reflection);
      _actionController.add('TTS: You\'ve used a few hints. Can you explain the last step to me?');
      _hintCount = 0; // Reset after intervention
      return;
    }
    
    // B3.5) Voice Attention Policy (Silence)
    // This would typically be triggered by a timer or silence event
  }

  void _transitionTo(BosState newState) {
    if (_currentState == newState) return;

    final BosState oldState = _currentState;
    _currentState = newState;

    _telemetry.logEvent(
      event: 'bos.state_changed',
    _emitTelemetry(
      'bos_state_changed',
      metadata: {
        'from': oldState.toString(),
        'to': newState.toString(),
        'reason': _deriveTransitionReason(oldState, newState),
      },
    );

    _onStateEntry(newState);
  }

  void _onStateEntry(BosState state) {
    switch (state) {
      case BosState.onboarding:
        _actionController.add('TTS: Welcome! I\'m your AI Coach. Ready to start?');
        break;
      case BosState.coachingRecovery:
        // Socratic strategy switch
        _confusionScore = 0.0; // Reset after handling
        break;
      case BosState.safeMode:
        _actionController.add('TTS: I need to pause for a moment. Please ask a teacher for help.');
        break;
      default:
        break;
    }
  }

  String _deriveTransitionReason(BosState from, BosState to) {
    if (to == BosState.coachingRecovery) return 'high_confusion';
    if (to == BosState.safeMode) return 'safety_violation';
    if (to == BosState.reflection) return 'hint_dependency';
    return 'normal_flow';
  }
  
  void _emitTelemetry(String name, {Map<String, dynamic>? metadata}) {
    // In real implementation, construct full BosEvent
    // _telemetry.logEvent(...)
  }

  // For testing
  BosState get currentState => _currentState;
  double get confusionScore => _confusionScore;
  
  void triggerSafetyTripwire() {
    _safetyFlag = true;
    _safetyGuard.triggerSafeMode('Manual Tripwire');
    _evaluatePolicies();
  }
}