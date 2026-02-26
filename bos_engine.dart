import 'dart:async';
import '../../services/telemetry_service.dart';
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
  int _consecutiveErrors = 0;
  DateTime _lastInteraction = DateTime.now();
  String _currentStrategy = 'direct'; // 'direct' | 'socratic'

  // Output stream for Voice/UI to consume
  final StreamController<String> _actionController = StreamController.broadcast();
  Stream<String> get actions => _actionController.stream;

  BosEngine(this._telemetry, this._safetyGuard);

  void start() {
    // In a real app, TelemetryService would expose a stream of BosEvent
    // _subscription = _telemetry.eventStream.listen(_handleEvent);
    _transitionTo(BosState.onboarding);
  }

  void dispose() {
    _subscription?.cancel();
    _actionController.close();
  }

  /// Main Control Loop Entry Point
  void handleEvent(BosEvent event) {
    _lastInteraction = DateTime.now();

    // 1. Sense (Update State Estimate)
    _updateEstimates(event);

    // 2. Control (Check Policies & Transition)
    _evaluatePolicies();
  }

  void _updateEstimates(BosEvent event) {
    if (event.eventName == BosSignal.sttFinalTranscript) {
      // B3) Confusion Policy Sensing
      final String text = event.payload['transcript'] ?? '';
      
      // Simple heuristic for demo; real system uses NLP classifier
      if (text.toLowerCase().contains("don't understand") || 
          text.toLowerCase().contains("help") ||
          text.toLowerCase().contains("stuck")) {
        _confusionScore += 0.3;
        _emitTelemetry(
          BosSignal.confusionDetected,
          metadata: {'score': _confusionScore},
        );
      }
    } else if (event.eventName == BosSignal.hintRequested) {
      _hintCount++;
    } else if (event.eventName == BosSignal.safeModeActivated) {
      _transitionTo(BosState.safeMode);
    } else if (event.eventName == BosSignal.silenceDetected) {
      _handleSilence();
    }
  }

  void _evaluatePolicies() {
    // D3) Safety Policy (Fail-Closed)
    if (_safetyGuard.isSafeMode && _currentState != BosState.safeMode) {
      _transitionTo(BosState.safeMode);
      return;
    }

    // B3.1) Confusion Policy
    if (_confusionScore > 0.7 && _currentState == BosState.instruction) {
      _transitionTo(BosState.coachingRecovery);
      return;
    }

    // B3.1.b) Mild Confusion -> Switch Strategy (Stay in Instruction)
    if (_confusionScore > 0.3 && _confusionScore <= 0.7 && _currentState == BosState.instruction) {
      if (_currentStrategy == 'direct') {
        _currentStrategy = 'socratic';
        _actionController.add('TTS: Let\'s look at this differently. What do you think happens next?');
        // Reset score slightly to give the new strategy a chance
        _confusionScore = 0.2; 
      }
      return;
    }

    // B3.2) Hint Dependency Policy
    if (_hintCount > 3 && _currentState != BosState.reflection) {
      // Force a reflection/check (Explain-it-back)
      _transitionTo(BosState.reflection);
      _actionController.add('TTS: You\'ve used a few hints. Can you explain the last step to me?');
      _hintCount = 0; // Reset after intervention
      return;
    }
    
    // B3.5) Voice Attention Policy (Silence)
    // Handled via _handleSilence triggered by event
  }

  void _handleSilence() {
    // B3.5) Voice Attention Policy Implementation
    if (_currentState == BosState.onboarding) {
      _actionController.add('TTS: Are you still there? Say "Ready" to start.');
    } else if (_currentState == BosState.instruction) {
      _actionController.add('TTS: Take your time. If you\'re stuck, just say "Help".');
    } else if (_currentState == BosState.guidedPractice) {
      // In practice, we might offer a hint
      _hintCount++; // Treat silence as a struggle signal
      _actionController.add('TTS: Would you like a hint?');
    }
  }

  void _transitionTo(BosState newState) {
    if (_currentState == newState) return;

    final BosState oldState = _currentState;
    _currentState = newState;

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
      case BosState.instruction:
        if (_currentStrategy == 'direct') {
          _actionController.add('TTS: Here is the core concept. [Direct Explanation]');
        } else {
          _actionController.add('TTS: Let\'s explore this together. [Socratic Question]');
        }
        break;
      case BosState.coachingRecovery:
        // Socratic strategy switch
        _confusionScore = 0.0; // Reset after handling
        _actionController.add('TTS: I notice this is tricky. Let\'s break it down step by step.');
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
  String get currentStrategy => _currentStrategy;
  
  void triggerSafetyTripwire() {
    _safetyGuard.triggerSafeMode('Manual Tripwire');
    _evaluatePolicies();
  }
}