import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/app_state.dart';
import '../i18n/bos_coaching_i18n.dart';
import '../services/telemetry_service.dart';
import '../ui/theme/scholesa_theme.dart';
import 'bos_service.dart';

typedef BosLearnerLoopInsightsLoader = Future<Map<String, dynamic>> Function({
  required String siteId,
  required String learnerId,
  required int lookbackDays,
});

class BosLearnerLoopInsightsCard extends StatefulWidget {
  const BosLearnerLoopInsightsCard({
    required this.title,
    required this.subtitle,
    required this.emptyLabel,
    required this.learnerId,
    required this.learnerName,
    this.accentColor,
    this.insightsLoader,
    super.key,
  });

  final String title;
  final String subtitle;
  final String emptyLabel;
  final String? learnerId;
  final String? learnerName;
  final Color? accentColor;
  final BosLearnerLoopInsightsLoader? insightsLoader;

  @override
  State<BosLearnerLoopInsightsCard> createState() =>
      _BosLearnerLoopInsightsCardState();
}

class _BosLearnerLoopInsightsCardState
    extends State<BosLearnerLoopInsightsCard> {
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
      final BosLearnerLoopInsightsLoader loader = widget.insightsLoader ??
          ({
            required String siteId,
            required String learnerId,
            required int lookbackDays,
          }) {
            return BosService.instance.getLearnerLoopInsights(
              siteId: siteId,
              learnerId: learnerId,
              lookbackDays: lookbackDays,
            );
          };
      final Map<String, dynamic> insights = await loader(
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

                final _LearnerLoopInsights? parsed =
                    _LearnerLoopInsights.tryFromPayload(insights);
                if (parsed == null) {
                  return _buildInfoState(
                    context,
                    icon: Icons.sensors_off_outlined,
                    message: BosCoachingI18n.signalUnavailable(context),
                    accent: accent,
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (!parsed.hasAnySignal) ...<Widget>[
                      _buildInfoState(
                        context,
                        icon: Icons.sensors_off_outlined,
                        message: BosCoachingI18n.signalUnavailable(context),
                        accent: accent,
                      ),
                      if (parsed.quality.hasWarnings) ...<Widget>[
                        const SizedBox(height: 8),
                        _buildQualityState(context, accent, parsed.quality),
                      ],
                    ] else ...<Widget>[
                      if (parsed.partialSignals) ...<Widget>[
                        _buildInfoState(
                          context,
                          icon: Icons.info_outline_rounded,
                          message: BosCoachingI18n.partialSignals(context),
                          accent: accent,
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (parsed.syntheticPreview) ...<Widget>[
                        _buildInfoState(
                          context,
                          icon: Icons.science_outlined,
                          message: BosCoachingI18n.syntheticPreview(context),
                          accent: accent,
                        ),
                        const SizedBox(height: 8),
                      ],
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          _metricChip(
                            '${BosCoachingI18n.cognition(context)} ${parsed.pct(context, parsed.cognition)}',
                            accent,
                            context,
                          ),
                          _metricChip(
                            '${BosCoachingI18n.engagement(context)} ${parsed.pct(context, parsed.engagement)}',
                            accent,
                            context,
                          ),
                          _metricChip(
                            '${BosCoachingI18n.integrity(context)} ${parsed.pct(context, parsed.integrity)}',
                            accent,
                            context,
                          ),
                          _metricChip(
                            '${BosCoachingI18n.improvementScore(context)} ${parsed.delta(context, parsed.improvementScore)}',
                            accent,
                            context,
                          ),
                          _metricChip(
                            '${BosCoachingI18n.mvlStatus(context)} ${parsed.mvlSummary(context)}',
                            accent,
                            context,
                          ),
                          _metricChip(
                            '${BosCoachingI18n.supportJourney(context)} ${parsed.supportJourneySummary(context)}',
                            accent,
                            context,
                          ),
                        ],
                      ),
                      if (parsed.quality.hasWarnings) ...<Widget>[
                        const SizedBox(height: 8),
                        _buildQualityState(context, accent, parsed.quality),
                      ],
                      if (parsed.hasTrendSignals) ...<Widget>[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${BosCoachingI18n.latestSignal(context)}: ${BosCoachingI18n.cognition(context)} ${parsed.delta(context, parsed.cognitionDelta)} • ${BosCoachingI18n.engagement(context)} ${parsed.delta(context, parsed.engagementDelta)} • ${BosCoachingI18n.integrity(context)} ${parsed.delta(context, parsed.integrityDelta)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                      if (parsed.activeGoals.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${BosCoachingI18n.activeGoals(context)}: ${parsed.activeGoals.take(3).join(' • ')}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildQualityState(
    BuildContext context,
    Color accent,
    _InsightDataQuality quality,
  ) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            BosCoachingI18n.dataQuality(context),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            quality.summary(context),
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            BosCoachingI18n.verifiedSignalsOnly(context),
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

Map<String, dynamic>? _asStringDynamicMap(dynamic value) {
  if (value is! Map<dynamic, dynamic>) {
    return null;
  }
  return value.map(
    (dynamic key, dynamic val) => MapEntry(key.toString(), val),
  );
}

double? _readFiniteDouble(Map<String, dynamic> source, String key) {
  final dynamic value = source[key];
  if (value is! num) {
    return null;
  }
  final double converted = value.toDouble();
  return converted.isFinite ? converted : null;
}

int? _readInt(Map<String, dynamic> source, String key) {
  final dynamic value = source[key];
  if (value is! num) {
    return null;
  }
  return value.toInt();
}

bool? _readBool(Map<String, dynamic> source, String key) {
  final dynamic value = source[key];
  return value is bool ? value : null;
}

List<String> _readTrimmedStringList(Map<String, dynamic> source, String key) {
  final dynamic value = source[key];
  if (value is! List<dynamic>) {
    return const <String>[];
  }
  return value
      .whereType<String>()
      .map((String item) => item.trim())
      .where((String item) => item.isNotEmpty)
      .toList(growable: false);
}

class _LearnerLoopInsights {
  const _LearnerLoopInsights({
    required this.cognition,
    required this.engagement,
    required this.integrity,
    required this.improvementScore,
    required this.cognitionDelta,
    required this.engagementDelta,
    required this.integrityDelta,
    required this.activeMvl,
    required this.passedMvl,
    required this.failedMvl,
    required this.aiHelpOpened,
    required this.aiHelpUsed,
    required this.aiCoachResponses,
    required this.explainBackSubmitted,
    required this.pendingExplainBack,
    required this.activeGoals,
    required this.partialSignals,
    required this.syntheticPreview,
    required this.quality,
  });

  final double? cognition;
  final double? engagement;
  final double? integrity;
  final double? improvementScore;
  final double? cognitionDelta;
  final double? engagementDelta;
  final double? integrityDelta;
  final int? activeMvl;
  final int? passedMvl;
  final int? failedMvl;
  final int? aiHelpOpened;
  final int? aiHelpUsed;
  final int? aiCoachResponses;
  final int? explainBackSubmitted;
  final int? pendingExplainBack;
  final List<String> activeGoals;
  final bool partialSignals;
  final bool syntheticPreview;
  final _InsightDataQuality quality;

  static _LearnerLoopInsights? tryFromPayload(Map<String, dynamic> payload) {
    final Map<String, dynamic> state =
        _asStringDynamicMap(payload['state']) ?? <String, dynamic>{};
    final Map<String, dynamic> trend =
        _asStringDynamicMap(payload['trend']) ?? <String, dynamic>{};
    final Map<String, dynamic> mvl =
        _asStringDynamicMap(payload['mvl']) ?? <String, dynamic>{};
    final Map<String, dynamic> eventCounts =
        _asStringDynamicMap(payload['eventCounts']) ?? <String, dynamic>{};
    final Map<String, dynamic> verification =
        _asStringDynamicMap(payload['verification']) ?? <String, dynamic>{};
    final Map<String, dynamic> availability =
        _asStringDynamicMap(payload['stateAvailability']) ??
            <String, dynamic>{};

    final int? aiHelpOpened = _readInt(verification, 'aiHelpOpened') ??
        _readInt(eventCounts, 'ai_help_opened');
    final int? aiHelpUsed = _readInt(verification, 'aiHelpUsed') ??
        _readInt(eventCounts, 'ai_help_used');
    final int? aiCoachResponses = _readInt(verification, 'aiCoachResponses') ??
        _readInt(eventCounts, 'ai_coach_response');
    final int? explainBackSubmitted =
        _readInt(verification, 'explainBackSubmitted') ??
            _readInt(eventCounts, 'explain_it_back_submitted');
    final int? pendingExplainBack =
        _readInt(verification, 'pendingExplainBack') ??
            _derivePendingExplainBack(
              opened: aiHelpOpened,
              used: aiHelpUsed,
              submitted: explainBackSubmitted,
            );
    final _InsightDataQuality quality = _InsightDataQuality.fromStatuses(
      <_FieldStatus>[
        _doubleStatus(state, 'cognition'),
        _doubleStatus(state, 'engagement'),
        _doubleStatus(state, 'integrity'),
        _doubleStatus(trend, 'improvementScore'),
        _doubleStatus(trend, 'cognitionDelta'),
        _doubleStatus(trend, 'engagementDelta'),
        _doubleStatus(trend, 'integrityDelta'),
        _intStatus(mvl, 'active'),
        _intStatus(mvl, 'passed'),
        _intStatus(mvl, 'failed'),
        _stringListStatus(payload, 'activeGoals'),
        _boolStatus(availability, 'hasCurrentState'),
        _boolStatus(availability, 'hasTrendBaseline'),
      ],
      incomplete: <bool>[
        availability['hasCurrentState'] == false,
        availability['hasTrendBaseline'] == false,
      ].where((bool value) => value).length,
    );

    final _LearnerLoopInsights parsed = _LearnerLoopInsights(
      cognition: _readFiniteDouble(state, 'cognition'),
      engagement: _readFiniteDouble(state, 'engagement'),
      integrity: _readFiniteDouble(state, 'integrity'),
      improvementScore: _readFiniteDouble(trend, 'improvementScore'),
      cognitionDelta: _readFiniteDouble(trend, 'cognitionDelta'),
      engagementDelta: _readFiniteDouble(trend, 'engagementDelta'),
      integrityDelta: _readFiniteDouble(trend, 'integrityDelta'),
      activeMvl: _readInt(mvl, 'active'),
      passedMvl: _readInt(mvl, 'passed'),
      failedMvl: _readInt(mvl, 'failed'),
      aiHelpOpened: aiHelpOpened,
      aiHelpUsed: aiHelpUsed,
      aiCoachResponses: aiCoachResponses,
      explainBackSubmitted: explainBackSubmitted,
      pendingExplainBack: pendingExplainBack,
      activeGoals: _readTrimmedStringList(payload, 'activeGoals'),
      partialSignals: quality.hasWarnings,
      syntheticPreview: _readBool(payload, 'synthetic') ?? false,
      quality: quality,
    );

    if (!parsed.hasAnySignal && !parsed.quality.hasWarnings) {
      return null;
    }
    return parsed;
  }

  bool get hasAnySignal =>
      cognition != null ||
      engagement != null ||
      integrity != null ||
      improvementScore != null ||
      cognitionDelta != null ||
      engagementDelta != null ||
      integrityDelta != null ||
      activeMvl != null ||
      passedMvl != null ||
      failedMvl != null ||
      aiHelpOpened != null ||
      aiHelpUsed != null ||
      aiCoachResponses != null ||
      explainBackSubmitted != null ||
      pendingExplainBack != null ||
      activeGoals.isNotEmpty;

  bool get hasTrendSignals =>
      cognitionDelta != null ||
      engagementDelta != null ||
      integrityDelta != null;

  String pct(BuildContext context, double? value) {
    if (value == null) {
      return BosCoachingI18n.signalUnavailable(context);
    }
    return '${(value * 100).toStringAsFixed(0)}%';
  }

  String delta(BuildContext context, double? value) {
    if (value == null) {
      return BosCoachingI18n.signalUnavailable(context);
    }
    final String sign = value >= 0 ? '+' : '';
    return '$sign${(value * 100).toStringAsFixed(1)}';
  }

  String mvlSummary(BuildContext context) {
    if (activeMvl == null || passedMvl == null || failedMvl == null) {
      return BosCoachingI18n.signalUnavailable(context);
    }
    return '$activeMvl/$passedMvl/$failedMvl';
  }

  String supportJourneySummary(BuildContext context) {
    if (aiHelpOpened == null ||
        aiCoachResponses == null ||
        explainBackSubmitted == null ||
        pendingExplainBack == null) {
      return BosCoachingI18n.signalUnavailable(context);
    }
    return '$aiHelpOpened opened/$aiCoachResponses responses/$explainBackSubmitted explained/$pendingExplainBack pending';
  }
}

int? _derivePendingExplainBack({
  required int? opened,
  required int? used,
  required int? submitted,
}) {
  if (opened == null && used == null || submitted == null) {
    return null;
  }
  final int expected =
      (opened ?? 0) > (used ?? 0) ? (opened ?? 0) : (used ?? 0);
  final int pending = expected - submitted;
  return pending > 0 ? pending : 0;
}

enum _FieldStatus { available, missing, malformed }

class _InsightDataQuality {
  const _InsightDataQuality({
    required this.available,
    required this.incomplete,
    required this.missing,
    required this.malformed,
  });

  factory _InsightDataQuality.fromStatuses(
    List<_FieldStatus> statuses, {
    int incomplete = 0,
  }) {
    int available = 0;
    int missing = 0;
    int malformed = 0;
    for (final _FieldStatus status in statuses) {
      switch (status) {
        case _FieldStatus.available:
          available += 1;
        case _FieldStatus.missing:
          missing += 1;
        case _FieldStatus.malformed:
          malformed += 1;
      }
    }
    return _InsightDataQuality(
      available: available,
      incomplete: incomplete,
      missing: missing,
      malformed: malformed,
    );
  }

  final int available;
  final int incomplete;
  final int missing;
  final int malformed;

  bool get hasWarnings => incomplete > 0 || missing > 0 || malformed > 0;

  String summary(BuildContext context) {
    return '${BosCoachingI18n.qualityAvailable(context)} $available • ${BosCoachingI18n.qualityIncomplete(context)} $incomplete • ${BosCoachingI18n.qualityMissing(context)} $missing • ${BosCoachingI18n.qualityMalformed(context)} $malformed';
  }
}

_FieldStatus _doubleStatus(Map<String, dynamic> source, String key) {
  if (!source.containsKey(key) || source[key] == null) {
    return _FieldStatus.missing;
  }
  final dynamic value = source[key];
  if (value is! num || !value.toDouble().isFinite) {
    return _FieldStatus.malformed;
  }
  return _FieldStatus.available;
}

_FieldStatus _intStatus(Map<String, dynamic> source, String key) {
  if (!source.containsKey(key) || source[key] == null) {
    return _FieldStatus.missing;
  }
  return source[key] is num ? _FieldStatus.available : _FieldStatus.malformed;
}

_FieldStatus _boolStatus(Map<String, dynamic> source, String key) {
  if (!source.containsKey(key) || source[key] == null) {
    return _FieldStatus.missing;
  }
  return source[key] is bool ? _FieldStatus.available : _FieldStatus.malformed;
}

_FieldStatus _stringListStatus(Map<String, dynamic> source, String key) {
  if (!source.containsKey(key) || source[key] == null) {
    return _FieldStatus.missing;
  }
  final dynamic value = source[key];
  if (value is! List<dynamic>) {
    return _FieldStatus.malformed;
  }
  return value.whereType<String>().any((String item) => item.trim().isNotEmpty)
      ? _FieldStatus.available
      : _FieldStatus.malformed;
}
