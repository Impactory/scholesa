import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth/app_state.dart';
import '../services/telemetry_service.dart';
import 'ai_coach_widget.dart';
import 'bos_models.dart';
import 'learning_runtime_provider.dart';

class GlobalAiAssistantOverlay extends StatelessWidget {
  const GlobalAiAssistantOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (BuildContext context, AppState appState, _) {
        final String learnerId = appState.userId?.trim() ?? '';
        final UserRole? role = appState.role;
        if (learnerId.isEmpty || role == null) {
          return const SizedBox.shrink();
        }

        final String siteId = _resolveSiteId(appState);
        if (siteId.isEmpty) {
          return const SizedBox.shrink();
        }

        final ThemeData theme = Theme.of(context);
        return SafeArea(
          child: Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 16, bottom: 16),
              child: FloatingActionButton(
                heroTag: 'global_ai_assistant_fab',
                tooltip: 'AI Assistant',
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                onPressed: () => _openAssistantSheet(
                  context,
                  role: role,
                  siteId: siteId,
                  learnerId: learnerId,
                ),
                child: const Icon(Icons.smart_toy_rounded),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openAssistantSheet(
    BuildContext context, {
    required UserRole role,
    required String siteId,
    required String learnerId,
  }) async {
    unawaited(TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'cta': 'global_ai_assistant_open',
        'surface': 'floating_assistant',
        'role': role.name,
      },
    ));

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) {
        return _GlobalAiAssistantSheet(
          siteId: siteId,
          learnerId: learnerId,
          role: role,
        );
      },
    );

    await TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'cta': 'global_ai_assistant_close',
        'surface': 'floating_assistant',
        'role': role.name,
      },
    );
  }

  String _resolveSiteId(AppState appState) {
    final String activeSiteId = appState.activeSiteId?.trim() ?? '';
    if (activeSiteId.isNotEmpty) {
      return activeSiteId;
    }
    if (appState.siteIds.isNotEmpty) {
      final String firstSite = appState.siteIds.first.trim();
      if (firstSite.isNotEmpty) {
        return firstSite;
      }
    }
    return '';
  }
}

class _GlobalAiAssistantSheet extends StatefulWidget {
  const _GlobalAiAssistantSheet({
    required this.siteId,
    required this.learnerId,
    required this.role,
  });

  final String siteId;
  final String learnerId;
  final UserRole role;

  @override
  State<_GlobalAiAssistantSheet> createState() => _GlobalAiAssistantSheetState();
}

class _GlobalAiAssistantSheetState extends State<_GlobalAiAssistantSheet> {
  late final LearningRuntimeProvider _runtime;

  @override
  void initState() {
    super.initState();
    _runtime = LearningRuntimeProvider(
      siteId: widget.siteId,
      learnerId: widget.learnerId,
      gradeBand: _gradeBandForRole(widget.role),
    );
  }

  @override
  void dispose() {
    _runtime.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.82,
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: <Widget>[
                Icon(Icons.smart_toy_rounded, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'AI Assistant',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Divider(color: scheme.outlineVariant, height: 1),
          Expanded(
            child: AiCoachWidget(
              runtime: _runtime,
              conceptTags: <String>['global-assistant', widget.role.name],
            ),
          ),
        ],
      ),
    );
  }

  GradeBand _gradeBandForRole(UserRole role) {
    switch (role) {
      case UserRole.learner:
      case UserRole.parent:
        return GradeBand.g4_6;
      case UserRole.educator:
      case UserRole.site:
      case UserRole.partner:
      case UserRole.hq:
        return GradeBand.g7_9;
    }
  }
}
