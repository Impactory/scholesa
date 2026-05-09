import 'dart:async';

import './telemetry_models.dart';

/// Minimal BOS event bridge used by the standalone voice pipeline prototype.
class BosEngine {
  final StreamController<String> _actionsController = StreamController<String>.broadcast();
  final StreamController<BosEvent> _eventsController = StreamController<BosEvent>.broadcast();

  Stream<String> get actions => _actionsController.stream;

  Stream<BosEvent> get events => _eventsController.stream;

  void handleEvent(BosEvent event) {
    if (_eventsController.isClosed) return;
    _eventsController.add(event);
  }

  void requestTts(String text) {
    if (_actionsController.isClosed) return;
    _actionsController.add('TTS: $text');
  }

  Future<void> dispose() async {
    await _actionsController.close();
    await _eventsController.close();
  }
}