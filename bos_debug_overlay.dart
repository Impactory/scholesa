import 'package:flutter/material.dart';
import '../../bos/bos_engine.dart';
import '../../voice/voice_pipeline.dart';

/// Visualizes the internal state of the BOS and Voice Pipeline.
/// Essential for "Proof of Work" and debugging invisible voice interactions.
class BosDebugOverlay extends StatelessWidget {
  final BosEngine bosEngine;
  final VoicePipeline voicePipeline;

  const BosDebugOverlay({
    super.key,
    required this.bosEngine,
    required this.voicePipeline,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.black87,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'BOS TELEMETRY',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            _buildStateRow(),
            const Divider(color: Colors.white24, height: 24),
            _buildVoiceStatus(),
            const SizedBox(height: 12),
            _buildConfusionMeter(),
          ],
        ),
      ),
    );
  }

  Widget _buildStateRow() {
    // Note: In a real app, use StreamBuilder on bosEngine.stateStream.
    // Here we assume the parent rebuilds or we'd wrap this in a StreamBuilder.
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('STATE', style: TextStyle(color: Colors.white70, fontSize: 10)),
            const SizedBox(height: 4),
            Text(
              bosEngine.currentState.name.toUpperCase(),
              style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text('STRATEGY', style: TextStyle(color: Colors.white70, fontSize: 10)),
            const SizedBox(height: 4),
            Text(
              bosEngine.currentStrategy.toUpperCase(),
              style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVoiceStatus() {
    return StreamBuilder<VoiceStatus>(
      stream: voicePipeline.statusStream,
      initialData: VoiceStatus.idle,
      builder: (context, snapshot) {
        final status = snapshot.data!;
        Color statusColor = Colors.grey;
        IconData icon = Icons.mic_off;

        switch (status) {
          case VoiceStatus.listening:
            statusColor = Colors.greenAccent;
            icon = Icons.mic;
            break;
          case VoiceStatus.speaking:
            statusColor = Colors.blueAccent;
            icon = Icons.volume_up;
            break;
          case VoiceStatus.processing:
            statusColor = Colors.purpleAccent;
            icon = Icons.psychology;
            break;
          case VoiceStatus.idle:
            statusColor = Colors.grey;
            icon = Icons.mic_none;
            break;
        }

        return Row(
          children: [
            Icon(icon, color: statusColor, size: 20),
            const SizedBox(width: 8),
            Text(
              status.name.toUpperCase(),
              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ],
        );
      },
    );
  }

  Widget _buildConfusionMeter() {
    final score = bosEngine.confusionScore;
    final isHigh = score > 0.7;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('CONFUSION EST.', style: TextStyle(color: Colors.white70, fontSize: 10)),
            Text(
              score.toStringAsFixed(2),
              style: TextStyle(
                color: isHigh ? Colors.redAccent : Colors.greenAccent,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: score.clamp(0.0, 1.0),
          backgroundColor: Colors.white10,
          valueColor: AlwaysStoppedAnimation<Color>(
            isHigh ? Colors.redAccent : Colors.greenAccent,
          ),
        ),
      ],
    );
  }
}