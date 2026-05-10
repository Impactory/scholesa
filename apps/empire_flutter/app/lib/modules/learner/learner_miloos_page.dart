import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/app_state.dart';
import '../../i18n/bos_coaching_i18n.dart';
import '../../runtime/runtime.dart';
import '../../ui/auth/global_session_menu.dart';
import '../../ui/theme/scholesa_theme.dart';

class LearnerMiloOSPage extends StatelessWidget {
  const LearnerMiloOSPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState appState = context.watch<AppState>();
    final LearningRuntimeProvider? runtime =
        context.watch<LearningRuntimeProvider?>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('MiloOS Support'),
        actions: const <Widget>[
          SessionMenuButton(),
          SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            _MiloOSSupportHeader(displayName: appState.displayName),
            const SizedBox(height: 16),
            BosLearnerLoopInsightsCard(
              title: BosCoachingI18n.learnerLoopTitle(context),
              subtitle: BosCoachingI18n.learnerLoopSubtitle(context),
              emptyLabel: BosCoachingI18n.learnerLoopEmpty(context),
              learnerId: appState.userId,
              learnerName: appState.displayName,
              accentColor: ScholesaColors.learner,
            ),
            const SizedBox(height: 16),
            if (runtime == null)
              _MiloOSBlockedCard(
                title: 'MiloOS is loading',
                body: 'Runtime context is syncing. Try again in a moment.',
              )
            else
              Container(
                constraints: const BoxConstraints(minHeight: 420),
                decoration: BoxDecoration(
                  color: ScholesaColors.learner.withValues(alpha: 0.05),
                  border: Border.all(
                    color: ScholesaColors.learner.withValues(alpha: 0.1),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: AiCoachWidget(
                  runtime: runtime,
                  actorRole: UserRole.learner,
                  conceptTags: const <String>[
                    'learner_support',
                    'explain_back',
                    'miloos_provenance',
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MiloOSSupportHeader extends StatelessWidget {
  const _MiloOSSupportHeader({required this.displayName});

  final String? displayName;

  @override
  Widget build(BuildContext context) {
    final String name = displayName?.trim().isNotEmpty == true
        ? displayName!.trim()
        : 'Learner';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ScholesaColors.learner.withValues(alpha: 0.08),
        border: Border.all(
          color: ScholesaColors.learner.withValues(alpha: 0.18),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'MiloOS support for $name',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Support, explain-back checks, and AI-help provenance stay separate from capability mastery until reviewed evidence updates growth.',
            style: TextStyle(color: context.schTextSecondary),
          ),
        ],
      ),
    );
  }
}

class _MiloOSBlockedCard extends StatelessWidget {
  const _MiloOSBlockedCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ScholesaColors.warning.withValues(alpha: 0.1),
        border: Border.all(
          color: ScholesaColors.warning.withValues(alpha: 0.35),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(body, style: TextStyle(color: context.schTextSecondary)),
        ],
      ),
    );
  }
}
