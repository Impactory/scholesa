import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/app_state.dart';
import '../i18n/bos_coaching_i18n.dart';
import '../services/telemetry_service.dart';
import '../ui/theme/scholesa_theme.dart';
import 'bos_service.dart';

class BosLearnerLoopInsightsCard extends StatefulWidget {
  const BosLearnerLoopInsightsCard({
    required this.title,
    required this.subtitle,
    required this.emptyLabel,
    required this.learnerId,
    required this.learnerName,
    this.accentColor,
    super.key,
  });

  final String title;
  final String subtitle;
  final String emptyLabel;
  final String? learnerId;
  final String? learnerName;
  final Color? accentColor;

  @override
  State<BosLearnerLoopInsightsCard> createState() =>
      _BosLearnerLoopInsightsCardState();
}

class _BosLearnerLoopInsightsCardState extends State<BosLearnerLoopInsightsCard> {
  Future<Map<String, dynamic>?>? _futureInsights;
  String? _lastSiteId;

  @override
  void initState() {
    super.initState();
    _lastSiteId = _activeSiteId();
    _futureInsights = _loadInsights();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final String? siteId = _activeSiteId();
    if (siteId != _lastSiteId) {
      _lastSiteId = siteId;
      _futureInsights = _loadInsights();
    }
  }

  @override
  void didUpdateWidget(covariant BosLearnerLoopInsightsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.learnerId != widget.learnerId) {
      _futureInsights = _loadInsights();
    }
  }

  Future<Map<String, dynamic>?> _loadInsights() async {
    final String? learnerId = widget.learnerId;
    if (learnerId == null || learnerId.isEmpty) return null;
    final AppState? appState = context.read<AppState?>();
    final String? siteId = _activeSiteId();
    if (siteId == null || siteId.isEmpty) return null;

    try {
      final Map<String, dynamic> insights =
          await BosService.instance.getLearnerLoopInsights(
        siteId: siteId,
        learnerId: learnerId,
        lookbackDays: 30,
      );

      unawaited(TelemetryService.instance.logEvent(
        event: 'insight.viewed',
        metadata: <String, dynamic>{
          'surface': 'bos_learner_loop_card',
          'insight_type': 'bos_mia_learner_loop',
          'site_id': siteId,
          'learner_id': learnerId,
          'role': appState?.role?.name,
          'status': insights['error'] == null ? 'ok' : 'fallback',
        },
      ));

      return insights;
    } catch (_) {
      unawaited(TelemetryService.instance.logEvent(
        event: 'insight.viewed',
        metadata: <String, dynamic>{
          'surface': 'bos_learner_loop_card',
          'insight_type': 'bos_mia_learner_loop',
          'site_id': siteId,
          'learner_id': learnerId,
          'role': appState?.role?.name,
          'status': 'error',
        },
      ));
      return null;
    }
  }

  String? _activeSiteId() {
    final AppState? appState = context.read<AppState?>();
    final String activeSite = appState?.activeSiteId?.trim() ?? '';
    if (activeSite.isNotEmpty) {
      return activeSite;
    }
    if (appState != null && appState.siteIds.isNotEmpty) {
      final String firstSite = appState.siteIds.first.trim();
      if (firstSite.isNotEmpty) {
        return firstSite;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Color accent = widget.accentColor ?? ScholesaColors.educator;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withValues(alpha: 0.18)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.query_stats, color: accent, size: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              widget.learnerName == null || widget.learnerName!.isEmpty
                  ? widget.subtitle
                  : '${widget.subtitle}: ${widget.learnerName}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            FutureBuilder<Map<String, dynamic>?>(
              future: _futureInsights,
              builder: (BuildContext context,
                  AsyncSnapshot<Map<String, dynamic>?> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          minHeight: 6,
                          color: accent,
                          backgroundColor: accent.withValues(alpha: 0.12),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        BosCoachingI18n.loadingInsights(context),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  );
                }
                final Map<String, dynamic>? insights = snapshot.data;
                if (insights == null) {
                  return _buildInfoState(
                    context,
                    icon: Icons.insights_outlined,
                    message: widget.emptyLabel,
                    accent: accent,
                  );
                }

                if (insights['error'] != null) {
                  return _buildInfoState(
                    context,
                    icon: Icons.error_outline_rounded,
                    message: BosCoachingI18n.errorLoadingInsights(context),
                    accent: accent,
                  );
                }

                final Map<String, dynamic> trend =
                    (insights['trend'] as Map<String, dynamic>?) ??
                        <String, dynamic>{};
                final Map<String, dynamic> state =
                    (insights['state'] as Map<String, dynamic>?) ??
                        <String, dynamic>{};
                final Map<String, dynamic> mvl =
                    (insights['mvl'] as Map<String, dynamic>?) ??
                        <String, dynamic>{};
                final List<dynamic> goals =
                    (insights['activeGoals'] as List<dynamic>?) ?? <dynamic>[];

                String pct(dynamic value) {
                  final double v = (value as num?)?.toDouble() ?? 0;
                  return '${(v * 100).toStringAsFixed(0)}%';
                }

                String delta(dynamic value) {
                  final double v = (value as num?)?.toDouble() ?? 0;
                  final String sign = v >= 0 ? '+' : '';
                  return '$sign${(v * 100).toStringAsFixed(1)}';
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        _metricChip(
                          '${BosCoachingI18n.cognition(context)} ${pct(state['cognition'])}',
                          accent,
                          context,
                        ),
                        _metricChip(
                          '${BosCoachingI18n.engagement(context)} ${pct(state['engagement'])}',
                          accent,
                          context,
                        ),
                        _metricChip(
                          '${BosCoachingI18n.integrity(context)} ${pct(state['integrity'])}',
                          accent,
                          context,
                        ),
                        _metricChip(
                          '${BosCoachingI18n.improvementScore(context)} ${delta(trend['improvementScore'])}',
                          accent,
                          context,
                        ),
                        _metricChip(
                          '${BosCoachingI18n.mvlStatus(context)} ${mvl['active'] ?? 0}/${mvl['passed'] ?? 0}/${mvl['failed'] ?? 0}',
                          accent,
                          context,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${BosCoachingI18n.latestSignal(context)}: C ${delta(trend['cognitionDelta'])}, E ${delta(trend['engagementDelta'])}, I ${delta(trend['integrityDelta'])}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ),
                    if (goals.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${BosCoachingI18n.activeGoals(context)}: ${goals.take(3).join(' • ')}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricChip(String text, Color accent, BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildInfoState(
    BuildContext context, {
    required IconData icon,
    required String message,
    required Color accent,
  }) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
