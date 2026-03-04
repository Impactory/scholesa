import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/app_state.dart';
import '../services/telemetry_service.dart';
import '../ui/theme/scholesa_theme.dart';
import 'ai_coach_widget.dart';
import 'learning_runtime_provider.dart';

class AiContextCoachSection extends StatefulWidget {
  const AiContextCoachSection({
    required this.title,
    required this.subtitle,
    required this.module,
    required this.surface,
    required this.actorRole,
    this.accentColor,
    this.missionId,
    this.checkpointId,
    this.conceptTags = const <String>[],
    super.key,
  });

  final String title;
  final String subtitle;
  final String module;
  final String surface;
  final UserRole actorRole;
  final Color? accentColor;
  final String? missionId;
  final String? checkpointId;
  final List<String> conceptTags;

  @override
  State<AiContextCoachSection> createState() => _AiContextCoachSectionState();
}

class _AiContextCoachSectionState extends State<AiContextCoachSection> {
  bool _expanded = false;

  List<String> _enrichedTags(LearningRuntimeProvider runtime) {
    final Set<String> tags = <String>{
      ...widget.conceptTags.where((String tag) => tag.trim().isNotEmpty),
      'bos_mia_loop',
      'continuous_improvement',
      'surface_${widget.surface}',
      'role_${widget.actorRole.name}',
      'learner_${runtime.learnerId}',
      'site_${runtime.siteId}',
    };
    if (widget.missionId != null && widget.missionId!.trim().isNotEmpty) {
      tags.add('mission_${widget.missionId!}');
    }
    if (widget.checkpointId != null && widget.checkpointId!.trim().isNotEmpty) {
      tags.add('checkpoint_${widget.checkpointId!}');
    }
    return tags.toList();
  }

  @override
  Widget build(BuildContext context) {
    final LearningRuntimeProvider? runtime =
        context.read<LearningRuntimeProvider?>();
    if (runtime == null) {
      return const SizedBox.shrink();
    }

    final AppState? appState = context.read<AppState?>();
    final UserRole role = appState?.role ?? widget.actorRole;
    final Color color = widget.accentColor ?? ScholesaColors.futureSkills;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: <Widget>[
          Container(
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              border: Border.all(color: color.withValues(alpha: 0.2)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: Icon(Icons.smart_toy_rounded, color: color),
              title: Text(widget.title),
              subtitle: Text(widget.subtitle),
              trailing: IconButton(
                icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                onPressed: () {
                  setState(() => _expanded = !_expanded);
                  TelemetryService.instance.logEvent(
                    event: 'cta.clicked',
                    metadata: <String, dynamic>{
                      'module': widget.module,
                      'surface': widget.surface,
                      'cta': '${widget.module}_ai_${_expanded ? 'show' : 'hide'}',
                      'role': role.name,
                      'learner_id': runtime.learnerId,
                    },
                  );
                },
              ),
            ),
          ),
          if (_expanded)
            Container(
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.05),
                border: Border.all(color: color.withValues(alpha: 0.1)),
                borderRadius: BorderRadius.circular(12),
              ),
              constraints: const BoxConstraints(minHeight: 350),
              child: AiCoachWidget(
                runtime: runtime,
                actorRole: role,
                missionId: widget.missionId,
                checkpointId: widget.checkpointId,
                conceptTags: _enrichedTags(runtime),
              ),
            ),
        ],
      ),
    );
  }
}
