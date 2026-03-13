import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../auth/app_state.dart';
import '../../domain/repositories.dart';
import '../../services/firestore_service.dart';

class LearnerOnboardingGate extends StatefulWidget {
  const LearnerOnboardingGate({
    super.key,
    required this.child,
    this.allowIncompleteSetup = false,
  });

  final Widget child;
  final bool allowIncompleteSetup;

  @override
  State<LearnerOnboardingGate> createState() => _LearnerOnboardingGateState();
}

class _LearnerOnboardingGateState extends State<LearnerOnboardingGate> {
  bool _isChecking = true;
  String? _lastCheckKey;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final AppState appState = context.read<AppState>();
    final String checkKey = <String>[
      appState.role?.name ?? 'none',
      appState.userId ?? '',
      _activeSiteId(appState),
      widget.allowIncompleteSetup.toString(),
      GoRouterState.of(context).matchedLocation,
    ].join('|');

    if (_lastCheckKey == checkKey) {
      return;
    }
    _lastCheckKey = checkKey;
    unawaited(_checkAccess());
  }

  Future<void> _checkAccess() async {
    final AppState appState = context.read<AppState>();
    final String matchedLocation = GoRouterState.of(context).matchedLocation;

    if (appState.role != UserRole.learner) {
      if (mounted) {
        setState(() => _isChecking = false);
      }
      return;
    }

    final String learnerId = appState.userId?.trim() ?? '';
    final String siteId = _activeSiteId(appState);
    if (learnerId.isEmpty || siteId.isEmpty) {
      if (mounted) {
        setState(() => _isChecking = false);
      }
      return;
    }

    if (mounted) {
      setState(() => _isChecking = true);
    }

    final LearnerProfileRepository repository = LearnerProfileRepository(
      firestore: context.read<FirestoreService>().firestore,
    );
    final bool onboardingComplete = (await repository.getByLearnerAndSite(
              learnerId: learnerId,
              siteId: siteId,
            ))
            ?.onboardingCompleted ??
        false;

    if (!mounted) {
      return;
    }

    final bool isOnboardingRoute = matchedLocation == '/learner/onboarding';
    if (!onboardingComplete && !widget.allowIncompleteSetup && !isOnboardingRoute) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.go('/learner/onboarding');
        }
      });
      return;
    }

    if (onboardingComplete && isOnboardingRoute) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.go('/learner/today');
        }
      });
      return;
    }

    setState(() => _isChecking = false);
  }

  String _activeSiteId(AppState appState) {
    final String activeSiteId = appState.activeSiteId?.trim() ?? '';
    if (activeSiteId.isNotEmpty) {
      return activeSiteId;
    }
    if (appState.siteIds.isNotEmpty) {
      return appState.siteIds.first.trim();
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    return widget.child;
  }
}