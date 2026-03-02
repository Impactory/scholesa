import './bos_engine.dart';
import './voice_pipeline.dart';

/// Snapshot of BOS + Voice status for debugging non-UI flows.
class BosDebugSnapshot {
  final String state;
  final String strategy;
  final double confusionScore;
  final VoiceStatus voiceStatus;

  const BosDebugSnapshot({
    required this.state,
    required this.strategy,
    required this.confusionScore,
    required this.voiceStatus,
  });

  Map<String, dynamic> toMap() {
    return {
      'state': state,
      'strategy': strategy,
      'confusionScore': confusionScore,
      'voiceStatus': voiceStatus.name,
    };
  }
}

/// Root-level debug helper that avoids Flutter UI dependencies.
class BosDebugOverlay {
  final BosEngine bosEngine;
  final VoicePipeline voicePipeline;

  const BosDebugOverlay({
    required this.bosEngine,
    required this.voicePipeline,
  });

  BosDebugSnapshot snapshot({VoiceStatus voiceStatus = VoiceStatus.idle}) {
    return BosDebugSnapshot(
      state: bosEngine.currentState.name,
      strategy: bosEngine.currentStrategy,
      confusionScore: bosEngine.confusionScore,
      voiceStatus: voiceStatus,
    );
  }

  String renderDebugLine({VoiceStatus voiceStatus = VoiceStatus.idle}) {
    final data = snapshot(voiceStatus: voiceStatus);
    return 'BOS=${data.state.toUpperCase()} | STRATEGY=${data.strategy.toUpperCase()} | '
        'CONFUSION=${data.confusionScore.toStringAsFixed(2)} | VOICE=${data.voiceStatus.name.toUpperCase()}';
  }
}
