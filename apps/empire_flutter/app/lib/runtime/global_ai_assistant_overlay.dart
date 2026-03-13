import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth/app_state.dart';
import '../modules/educator/educator_service.dart';
import '../services/telemetry_service.dart';
import '../ui/localization/app_strings.dart';
import '../ui/theme/scholesa_theme.dart';
import 'ai_coach_widget.dart';
import 'bos_models.dart';
import 'learning_runtime_provider.dart';

typedef RuntimeProviderFactory = LearningRuntimeProvider Function({
  required String siteId,
  required String learnerId,
  required GradeBand gradeBand,
  String? sessionOccurrenceId,
});

typedef SessionOccurrenceResolver = Future<String?> Function(
  BuildContext context, {
  required String siteId,
  required String learnerId,
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
    this.nowProvider,
  });

  final GlobalKey<NavigatorState>? navigatorKey;
  final RuntimeProviderFactory? runtimeFactory;
  final SessionOccurrenceResolver? sessionOccurrenceResolver;
  final AssistantSheetPresenter? sheetPresenter;
  final DateTime Function()? nowProvider;

  @override
  State<GlobalAiAssistantOverlay> createState() =>
      _GlobalAiAssistantOverlayState();
}

class _GlobalAiAssistantOverlayState extends State<GlobalAiAssistantOverlay>
    with SingleTickerProviderStateMixin {
  bool _assistantSheetOpen = false;
  bool _isHoveringAssistant = false;
  DateTime? _lastBosPopupAt;
  bool _bosPopupInFlight = false;
  String? _bosMonitorKey;
  LearningRuntimeProvider? _bosRuntime;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

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
              child: MouseRegion(
                onEnter: (_) {
                  if (!_isPointerPlatform()) {
                    return;
                  }
                  setState(() => _isHoveringAssistant = true);
                },
                onExit: (_) {
                  if (_isHoveringAssistant) {
                    setState(() => _isHoveringAssistant = false);
                  }
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomRight,
                  children: <Widget>[
                    if (_isPointerPlatform())
                      IgnorePointer(
                        child: AnimatedBuilder(
                          animation: _pulseController,
                          builder: (BuildContext context, Widget? child) {
                            final double scale = 1 + (_pulseController.value * 0.22);
                            final double opacity = (1 - _pulseController.value) * 0.18;
                            return Transform.scale(
                              scale: scale,
                              child: Opacity(opacity: opacity, child: child),
                            );
                          },
                          child: Container(
                            width: 74,
                            height: 74,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: ScholesaColors.leadership.withValues(alpha: 0.22),
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      right: 0,
                      bottom: 70,
                      child: IgnorePointer(
                        child: AnimatedSlide(
                          duration: const Duration(milliseconds: 180),
                          offset: _isHoveringAssistant
                              ? Offset.zero
                              : const Offset(0, 0.08),
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 180),
                            opacity: _isHoveringAssistant ? 1 : 0,
                            child: _AssistantHoverHint(
                              label: AppStrings.of(context, 'assistant.hoverHint'),
                            ),
                          ),
                        ),
                      ),
                    ),
                    FloatingActionButton(
                      heroTag: 'global_ai_assistant_fab',
                      tooltip: AppStrings.of(context, 'assistant.tooltip'),
                      backgroundColor: Colors.transparent,
                      foregroundColor: theme.colorScheme.onPrimary,
                      elevation: 0,
                      hoverElevation: 0,
                      highlightElevation: 0,
                      onPressed: () => _openAssistantSheet(
                        context,
                        role: role,
                        siteId: siteId,
                        learnerId: learnerId,
                        trigger: _isPointerPlatform() ? 'click' : 'tap',
                      ),
                      child: Container(
                        width: 56,
                        height: 56,
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
                              color: ScholesaColors.leadership.withValues(alpha: 0.28),
                              blurRadius: 12,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.smart_toy_rounded, color: Colors.white),
                      ),
                    ),
                  ],
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

    _assistantSheetOpen = true;
    try {
      final Widget sheetChild = _GlobalAiAssistantSheet(
        siteId: siteId,
        learnerId: learnerId,
        role: role,
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
      gradeBand: GradeBand.g4_6,
      sessionOccurrenceId: sessionOccurrenceId,
    );
    runtime.startListening();
    runtime.addListener(_handleBosRuntimeUpdate);

    _bosRuntime = runtime;
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
    if (widget.sessionOccurrenceResolver != null) {
      return widget.sessionOccurrenceResolver!(
        context,
        siteId: siteId,
        learnerId: learnerId,
      );
    }

    try {
      final QuerySnapshot<Map<String, dynamic>> attempts =
          await FirebaseFirestore.instance
              .collection('missionAttempts')
              .where('learnerId', isEqualTo: learnerId)
              .where('siteId', isEqualTo: siteId)
              .orderBy('updatedAt', descending: true)
              .limit(10)
              .get();

      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in attempts.docs) {
        final String value =
            (doc.data()['sessionOccurrenceId'] as String? ?? '').trim();
        if (value.isNotEmpty) return value;
      }
    } catch (_) {
      // Best-effort only; continue to interaction event fallback.
    }

    try {
      final QuerySnapshot<Map<String, dynamic>> interactions =
          await FirebaseFirestore.instance
              .collection('interactionEvents')
              .where('actorId', isEqualTo: learnerId)
              .where('siteId', isEqualTo: siteId)
              .where('eventType', isEqualTo: 'session_joined')
              .orderBy('timestamp', descending: true)
              .limit(1)
              .get();

      if (interactions.docs.isNotEmpty) {
        final Map<String, dynamic> data = interactions.docs.first.data();
        final String topLevel =
            (data['sessionOccurrenceId'] as String? ?? '').trim();
        if (topLevel.isNotEmpty) return topLevel;
        final Map<String, dynamic>? payload =
            data['payload'] as Map<String, dynamic>?;
        final String fromPayload =
            (payload?['sessionOccurrenceId'] as String? ?? '').trim();
        if (fromPayload.isNotEmpty) return fromPayload;
      }
    } catch (_) {
      // Keep null when unavailable.
    }

    return null;
  }

  void _disposeBosMonitor() {
    _bosRuntime?.removeListener(_handleBosRuntimeUpdate);
    _bosRuntime?.dispose();
    _bosRuntime = null;
    _bosMonitorKey = null;
  }

  @override
  void dispose() {
    _disposeBosMonitor();
    _pulseController.dispose();
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

class _AssistantHoverHint extends StatelessWidget {
  const _AssistantHoverHint({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.16)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          label,
          style: TextStyle(
            color: scheme.onSurface,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
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
