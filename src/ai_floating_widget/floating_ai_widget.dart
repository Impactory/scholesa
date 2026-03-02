import '../../voice_manager.dart';

abstract class BosController {
  void onFloatingAssistantToggled({required bool listening});
}

class FloatingAIWidget {
  final BosController bosController;
  final VoiceManager voiceManager;

  bool _isVisible = true;
  bool _isListening = false;

  FloatingAIWidget({
    required this.bosController,
    required this.voiceManager,
  });

  bool get isVisible => _isVisible;
  bool get isListening => _isListening;

  void setVisible(bool visible) {
    _isVisible = visible;
  }

  void toggleListening() {
    _isListening = !_isListening;
    if (_isListening) {
      voiceManager.startListening();
    }
    bosController.onFloatingAssistantToggled(listening: _isListening);
  }
}
