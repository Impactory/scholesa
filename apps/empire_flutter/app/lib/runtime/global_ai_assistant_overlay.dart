import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth/app_state.dart';
import '../modules/educator/educator_service.dart';
import '../services/telemetry_service.dart';
import '../ui/localization/app_strings.dart';
import 'ai_coach_widget.dart';
import 'bos_models.dart';
import 'learning_runtime_provider.dart';

class GlobalAiAssistantOverlay extends StatelessWidget {
  const GlobalAiAssistantOverlay({
    super.key,
    this.navigatorKey,
  });

  final GlobalKey<NavigatorState>? navigatorKey;

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
                tooltip: AppStrings.of(context, 'assistant.tooltip'),
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
    final BuildContext? sheetContext =
        navigatorKey?.currentContext ?? Navigator.maybeOf(context, rootNavigator: true)?.context;
    if (sheetContext == null) {
      unawaited(TelemetryService.instance.logEvent(
        event: 'assistant.open.failed',
        metadata: <String, dynamic>{
          'reason': 'missing_navigator_context',
          'surface': 'floating_assistant',
          'role': role.name,
        },
      ));
      return;
    }

    unawaited(TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'cta': 'global_ai_assistant_open',
        'surface': 'floating_assistant',
        'role': role.name,
      },
    ));

    try {
      await showModalBottomSheet<void>(
        context: sheetContext,
        isScrollControlled: true,
        useRootNavigator: true,
        useSafeArea: true,
        backgroundColor: Theme.of(sheetContext).colorScheme.surface,
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
    } catch (_) {
      unawaited(TelemetryService.instance.logEvent(
        event: 'assistant.open.failed',
        metadata: <String, dynamic>{
          'reason': 'sheet_open_error',
          'surface': 'floating_assistant',
          'role': role.name,
        },
      ));
      return;
    }

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
  LearningRuntimeProvider? _runtime;
  bool _runtimeReady = false;
  String? _sessionOccurrenceId;

  @override
  void initState() {
    super.initState();
    unawaited(_initializeRuntime());
  }

  Future<void> _initializeRuntime() async {
    final String? resolvedSessionOccurrenceId =
        await _resolveSessionOccurrenceId();
    final LearningRuntimeProvider runtime = LearningRuntimeProvider(
      siteId: widget.siteId,
      learnerId: widget.learnerId,
      gradeBand: _gradeBandForRole(widget.role),
      sessionOccurrenceId: resolvedSessionOccurrenceId,
    );
    runtime.startListening();
    if (!mounted) {
      runtime.dispose();
      return;
    }
    setState(() {
      _runtime = runtime;
      _sessionOccurrenceId = resolvedSessionOccurrenceId;
      _runtimeReady = true;
    });
  }

  Future<String?> _resolveSessionOccurrenceId() async {
    if (widget.role == UserRole.educator ||
        widget.role == UserRole.site ||
        widget.role == UserRole.hq) {
      final EducatorService? educatorService =
          context.read<EducatorService?>();
      final String? currentClassId = educatorService?.currentClass?.id;
      if (currentClassId != null && currentClassId.trim().isNotEmpty) {
        return currentClassId.trim();
      }
      if (educatorService != null && educatorService.todayClasses.isNotEmpty) {
        return educatorService.todayClasses.first.id.trim();
      }
    }

    try {
      final QuerySnapshot<Map<String, dynamic>> attempts = await FirebaseFirestore
          .instance
          .collection('missionAttempts')
          .where('learnerId', isEqualTo: widget.learnerId)
          .where('siteId', isEqualTo: widget.siteId)
          .orderBy('updatedAt', descending: true)
          .limit(10)
          .get();

      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in attempts.docs) {
        final String value = (doc.data()['sessionOccurrenceId'] as String? ?? '').trim();
        if (value.isNotEmpty) return value;
      }
    } catch (_) {
      // Best-effort only; continue to interaction event fallback.
    }

    try {
      final QuerySnapshot<Map<String, dynamic>> interactions = await FirebaseFirestore
          .instance
          .collection('interactionEvents')
          .where('actorId', isEqualTo: widget.learnerId)
          .where('siteId', isEqualTo: widget.siteId)
          .where('eventType', isEqualTo: 'session_joined')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (interactions.docs.isNotEmpty) {
        final Map<String, dynamic> data = interactions.docs.first.data();
        final String topLevel = (data['sessionOccurrenceId'] as String? ?? '').trim();
        if (topLevel.isNotEmpty) return topLevel;
        final Map<String, dynamic>? payload = data['payload'] as Map<String, dynamic>?;
        final String fromPayload = (payload?['sessionOccurrenceId'] as String? ?? '').trim();
        if (fromPayload.isNotEmpty) return fromPayload;
      }
    } catch (_) {
      // Keep null when unavailable.
    }

    return null;
  }

  @override
  void dispose() {
    _runtime?.dispose();
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
                    AppStrings.of(context, 'assistant.title'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: AppStrings.of(context, 'assistant.close'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Divider(color: scheme.outlineVariant, height: 1),
          Expanded(
            child: _runtimeReady && _runtime != null
                ? AiCoachWidget(
                    runtime: _runtime!,
                    actorRole: widget.role,
                    allowBosFallback: widget.role == UserRole.learner,
                    conceptTags: <String>[
                      'global-assistant',
                      widget.role.name,
                      if ((_sessionOccurrenceId ?? '').isNotEmpty)
                        'occurrence:${_sessionOccurrenceId!}',
                    ],
                  )
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          AppStrings.of(context, 'assistant.loading'),
                        ),
                      ],
                    ),
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
