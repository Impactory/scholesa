import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth/app_state.dart';
import '../services/telemetry_service.dart';
import '../ui/localization/app_strings.dart';
import '../ui/theme/scholesa_theme.dart';
import 'ai_coach_widget.dart';
import 'bos_event_bus.dart';
import 'bos_models.dart';
import 'learning_runtime_provider.dart';
import 'runtime_resolution.dart';

typedef RuntimeProviderFactory = LearningRuntimeProvider Function({
  required String siteId,
  required String learnerId,
  required GradeBand gradeBand,
  String? sessionOccurrenceId,
});

typedef AssistantSheetPresenter = Future<void> Function(
  BuildContext context,
  Widget child,
);

class GlobalAiAssistantOverlay extends StatefulWidget {
  const GlobalAiAssistantOverlay({
    super.key,
    this.navigatorKey,
    this.runtimeFactory,
    this.sessionOccurrenceResolver,
    this.sheetPresenter,
    this.firestore,
    this.nowProvider,
  });

  final GlobalKey<NavigatorState>? navigatorKey;
  final RuntimeProviderFactory? runtimeFactory;
  final SessionOccurrenceResolver? sessionOccurrenceResolver;
  final AssistantSheetPresenter? sheetPresenter;
  final FirebaseFirestore? firestore;
  final DateTime Function()? nowProvider;

  @override
  State<GlobalAiAssistantOverlay> createState() =>
      _GlobalAiAssistantOverlayState();
}

class _GlobalAiAssistantOverlayState extends State<GlobalAiAssistantOverlay> {
  bool _assistantSheetOpen = false;
  DateTime? _lastBosPopupAt;
  bool _bosPopupInFlight = false;
  String? _bosMonitorKey;
  LearningRuntimeProvider? _bosRuntime;

  bool _isHesitating(XHat state) {
    return state.engagement <= 0.42 || state.cognition <= 0.38;
  }

  bool _isPointerPlatform() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return true;
      case TargetPlatform.iOS:
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
        return false;
    }
  }

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

        _syncBosAutoPopupMonitor(
          context,
          role: role,
          siteId: siteId,
          learnerId: learnerId,
        );

        final ThemeData theme = Theme.of(context);
        return SafeArea(
          child: Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 16, bottom: 16),
              child: SizedBox.square(
                dimension: 52,
                child: FloatingActionButton(
                  heroTag: 'global_ai_assistant_fab',
                  tooltip: AppStrings.of(context, 'assistant.tooltip'),
                  backgroundColor: Colors.transparent,
                  foregroundColor: theme.colorScheme.onPrimary,
                  elevation: 0,
                  hoverElevation: 0,
                  focusElevation: 0,
                  highlightElevation: 0,
                  shape: const CircleBorder(),
                  onPressed: () => _openAssistantSheet(
                    context,
                    role: role,
                    siteId: siteId,
                    learnerId: learnerId,
                    trigger: _isPointerPlatform() ? 'click' : 'tap',
                  ),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          ScholesaColors.futureSkills,
                          ScholesaColors.leadership,
                          ScholesaColors.impact,
                        ],
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: ScholesaColors.leadership.withValues(alpha: 0.22),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.smart_toy_rounded, color: Colors.white),
                  ),
                ),
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
    required String trigger,
  }) async {
    if (_assistantSheetOpen) {
      return;
    }

    final BuildContext? sheetContext =
        widget.navigatorKey?.currentContext ??
            Navigator.maybeOf(context, rootNavigator: true)?.context;
    if (sheetContext == null) {
      unawaited(TelemetryService.instance.logEvent(
        event: 'assistant.open.failed',
        metadata: <String, dynamic>{
          'reason': 'missing_navigator_context',
          'surface': 'floating_assistant',
          'role': role.name,
          'trigger': trigger,
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
        'trigger': trigger,
      },
    ));

    if (role == UserRole.learner) {
      _bosRuntime?.trackEvent(
        'interaction_signal_observed',
        payload: <String, dynamic>{
          'signalFamily': 'pointer',
          'source': 'global_ai_assistant_open',
          'target': 'assistant_fab',
          'trigger': trigger,
          'interactionCount': 1,
        },
      );
    }

    _assistantSheetOpen = true;
    try {
      final Widget sheetChild = _GlobalAiAssistantSheet(
        siteId: siteId,
        learnerId: learnerId,
        role: role,
        sessionOccurrenceResolver: widget.sessionOccurrenceResolver,
        firestore: widget.firestore,
      );
      if (widget.sheetPresenter != null) {
        await widget.sheetPresenter!(sheetContext, sheetChild);
      } else {
        await showModalBottomSheet<void>(
          context: sheetContext,
          isScrollControlled: true,
          useRootNavigator: true,
          useSafeArea: true,
          backgroundColor: Theme.of(sheetContext).colorScheme.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (BuildContext sheetContext) => sheetChild,
        );
      }
    } catch (_) {
      unawaited(TelemetryService.instance.logEvent(
        event: 'assistant.open.failed',
        metadata: <String, dynamic>{
          'reason': 'sheet_open_error',
          'surface': 'floating_assistant',
          'role': role.name,
          'trigger': trigger,
        },
      ));
      _assistantSheetOpen = false;
      return;
    }

    _assistantSheetOpen = false;

    await TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'cta': 'global_ai_assistant_close',
        'surface': 'floating_assistant',
        'role': role.name,
        'trigger': trigger,
      },
    );
  }

  void _syncBosAutoPopupMonitor(
    BuildContext context, {
    required UserRole role,
    required String siteId,
    required String learnerId,
  }) {
    if (role != UserRole.learner) {
      _disposeBosMonitor();
      return;
    }

    final String monitorKey = '$siteId::$learnerId';
    if (_bosMonitorKey == monitorKey && _bosRuntime != null) {
      return;
    }

    _disposeBosMonitor();
    _bosMonitorKey = monitorKey;
    unawaited(_initializeBosMonitor(
      context,
      monitorKey: monitorKey,
      siteId: siteId,
      learnerId: learnerId,
    ));
  }

  Future<void> _initializeBosMonitor(
    BuildContext context, {
    required String monitorKey,
    required String siteId,
    required String learnerId,
  }) async {
    final String? sessionOccurrenceId = await _resolveSessionOccurrenceId(
      context,
      siteId: siteId,
      learnerId: learnerId,
    );

    if (!mounted || _bosMonitorKey != monitorKey) {
      return;
    }

    final GradeBand monitorGradeBand = gradeBandForRole(UserRole.learner);

    final RuntimeProviderFactory runtimeFactory =
        widget.runtimeFactory ??
            ({
              required String siteId,
              required String learnerId,
              required GradeBand gradeBand,
              String? sessionOccurrenceId,
            }) =>
                LearningRuntimeProvider(
                  siteId: siteId,
                  learnerId: learnerId,
                  gradeBand: gradeBand,
                  sessionOccurrenceId: sessionOccurrenceId,
                );
    final LearningRuntimeProvider runtime = runtimeFactory(
      siteId: siteId,
      learnerId: learnerId,
      gradeBand: monitorGradeBand,
      sessionOccurrenceId: sessionOccurrenceId,
    );
    runtime.startListening();
    runtime.addListener(_handleBosRuntimeUpdate);

    _bosRuntime = runtime;

    // Emit session_joined so the backend BOS runtime can scope events
    // from this overlay's independent LearningRuntimeProvider.
    BosEventBus.instance.track(
      eventType: 'session_joined',
      siteId: siteId,
      gradeBand: monitorGradeBand,
      actorRole: 'learner',
      sessionOccurrenceId: sessionOccurrenceId,
      payload: <String, dynamic>{'source': 'global_ai_assistant_overlay'},
    );

    unawaited(_handleBosRuntimeUpdate());
  }

  Future<void> _handleBosRuntimeUpdate() async {
    final LearningRuntimeProvider? runtime = _bosRuntime;
    if (!mounted || runtime == null || _assistantSheetOpen || _bosPopupInFlight) {
      return;
    }

    final XHat? state = runtime.state?.xHat;
    if (state == null || !_isHesitating(state)) {
      return;
    }

    final DateTime now = widget.nowProvider?.call() ?? DateTime.now();
    if (_lastBosPopupAt != null &&
        now.difference(_lastBosPopupAt!) < const Duration(minutes: 3)) {
      return;
    }

    final AppState? appState = context.read<AppState?>();
    final UserRole? role = appState?.role;
    final String learnerId = (appState?.userId ?? '').trim();
    final String siteId = appState == null ? '' : _resolveSiteId(appState);
    if (role != UserRole.learner || learnerId.isEmpty || siteId.isEmpty) {
      return;
    }

    _bosPopupInFlight = true;
    _lastBosPopupAt = now;
    try {
      await _openAssistantSheet(
        context,
        role: role!,
        siteId: siteId,
        learnerId: learnerId,
        trigger: 'bos_auto_popup',
      );
    } finally {
      _bosPopupInFlight = false;
    }
  }

  Future<String?> _resolveSessionOccurrenceId(
    BuildContext context, {
    required String siteId,
    required String learnerId,
  }) async {
    return resolveSessionOccurrenceId(
      context,
      siteId: siteId,
      learnerId: learnerId,
      sessionOccurrenceResolver: widget.sessionOccurrenceResolver,
      firestore: widget.firestore,
    );
  }

  void _disposeBosMonitor() {
    final LearningRuntimeProvider? runtime = _bosRuntime;
    if (runtime != null) {
      // Emit session_left to match the session_joined emitted in
      // _initializeBosMonitor, so the backend can correctly scope events.
      BosEventBus.instance.track(
        eventType: 'session_left',
        siteId: runtime.siteId,
        gradeBand: runtime.gradeBand,
        actorRole: 'learner',
        sessionOccurrenceId: runtime.sessionOccurrenceId,
        payload: <String, dynamic>{'source': 'global_ai_assistant_overlay'},
      );
      runtime.removeListener(_handleBosRuntimeUpdate);
      runtime.dispose();
    }
    _bosRuntime = null;
    _bosMonitorKey = null;
  }

  @override
  void dispose() {
    _disposeBosMonitor();
    super.dispose();
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
    this.sessionOccurrenceResolver,
    this.firestore,
  });

  final String siteId;
  final String learnerId;
  final UserRole role;
  final SessionOccurrenceResolver? sessionOccurrenceResolver;
  final FirebaseFirestore? firestore;

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
    return resolveSessionOccurrenceId(
      context,
      siteId: widget.siteId,
      learnerId: widget.learnerId,
      role: widget.role,
      sessionOccurrenceResolver: widget.sessionOccurrenceResolver,
      firestore: widget.firestore,
    );
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
                    autoSpeakGreeting: true,
                    autoAssistOnHesitation: widget.role == UserRole.learner,
                    voiceOnlyConversation: widget.role == UserRole.learner,
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

  GradeBand _gradeBandForRole(UserRole role) => gradeBandForRole(role);
}
