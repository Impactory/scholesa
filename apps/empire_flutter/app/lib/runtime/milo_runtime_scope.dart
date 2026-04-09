import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../auth/app_state.dart';
import 'bos_event_bus.dart';
import 'bos_models.dart';
import 'learning_runtime_provider.dart';
import 'runtime_resolution.dart';

/// Provides a [LearningRuntimeProvider] to descendant widgets.
///
/// Wrap any page that uses [AiContextCoachSection] or reads
/// `context.read<LearningRuntimeProvider?>()` with this widget so the
/// runtime is available in the Provider tree.
class MiloRuntimeScope extends StatefulWidget {
  const MiloRuntimeScope({required this.child, super.key});

  final Widget child;

  @override
  State<MiloRuntimeScope> createState() => _MiloRuntimeScopeState();
}

class _MiloRuntimeScopeState extends State<MiloRuntimeScope>
    with WidgetsBindingObserver {
  LearningRuntimeProvider? _runtime;

  // Cached for dispose() where context is unavailable.
  String? _siteId;
  GradeBand? _gradeBand;
  String? _roleName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initializeRuntime());
  }

  Future<void> _initializeRuntime() async {
    try {
      final AppState? appState = context.read<AppState?>();
      if (appState == null) return;

      final String? siteId = appState.activeSiteId ??
          (appState.siteIds.isNotEmpty ? appState.siteIds.first : null);
      final String? userId = appState.userId;
      final UserRole? role = appState.role;

      if (siteId == null || userId == null || role == null) return;

      final GradeBand gradeBand = gradeBandForRole(role);

      final String? sessionOccurrenceId = await resolveSessionOccurrenceId(
        context,
        siteId: siteId,
        learnerId: userId,
        role: role,
      );

      if (!mounted) return;

      final LearningRuntimeProvider runtime = LearningRuntimeProvider(
        siteId: siteId,
        learnerId: userId,
        gradeBand: gradeBand,
        sessionOccurrenceId: sessionOccurrenceId,
      );
      runtime.startListening();

      if (!mounted) {
        runtime.dispose();
        return;
      }

      _siteId = siteId;
      _gradeBand = gradeBand;
      _roleName = role.name;

      BosEventBus.instance.track(
        eventType: 'session_joined',
        siteId: siteId,
        gradeBand: gradeBand,
        actorRole: role.name,
        sessionOccurrenceId: sessionOccurrenceId,
      );

      setState(() {
        _runtime = runtime;
      });
    } catch (_) {
      // Gracefully degrade — runtime stays null and child renders without it.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _runtime != null) {
      BosEventBus.instance.track(
        eventType: 'focus_restored',
        siteId: _siteId ?? '',
        gradeBand: _gradeBand ?? GradeBand.g4_6,
        actorRole: _roleName ?? 'learner',
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_runtime != null) {
      BosEventBus.instance.track(
        eventType: 'session_left',
        siteId: _siteId ?? '',
        gradeBand: _gradeBand ?? GradeBand.g4_6,
        actorRole: _roleName ?? 'learner',
      );
    }
    _runtime?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final LearningRuntimeProvider? runtime = _runtime;
    if (runtime == null) {
      return widget.child;
    }
    return ChangeNotifierProvider<LearningRuntimeProvider>.value(
      value: runtime,
      child: widget.child,
    );
  }
}
