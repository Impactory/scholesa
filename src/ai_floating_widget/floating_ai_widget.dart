// src/ai_floating_widget/floating_ai_widget.dart
import 'package:flutter/material.dart';
import 'package:voice_manager.dart';
import 'package:bos_controller.dart';

class FloatingAIWidget extends StatefulWidget {
  final BosController bosController;
  final VoiceManager voiceManager;

  const FloatingAIWidget({
    Key? key,
    required this.bosController,
    required this.voiceManager,
  }) : super(key: key);

  @override
  _FloatingAIWidgetState createState() => _FloatingAIWidgetState();
}

class _FloatingAIWidgetState extends State<FloatingAIWidget> {
  bool _isVisible = true;
  bool _isListening = false;

  @override
  Widget build(BuildContext context) {
    return Visibility(
      visible: _isVisible,
      child: Positioned(
        bottom: 20,
        right: 20,
        child: GestureDetector(
          onTap: () {
            setState(() {
              _isListening = !_isListening;
              if (_isListening) {
                widget.voiceManager.startListening();
              } else {
                widget.voiceManager.stopListening();
              }
            });
          },
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isListening ? Colors.blue : Colors.grey,
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Icon(
              _isListening ? Icons.mic : Icons.mic_none,
              color: Colors.white,
              size: 30,
            ),
          ),
        ),
      ),
    );
  }
}