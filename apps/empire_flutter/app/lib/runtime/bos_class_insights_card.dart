import 'dart:async';

import 'package:flutter/material.dart';

import '../i18n/bos_coaching_i18n.dart';
import '../services/telemetry_service.dart';
import '../ui/theme/scholesa_theme.dart';
import 'bos_service.dart';

typedef BosClassInsightsLoader = Future<Map<String, dynamic>> Function({
  required String sessionOccurrenceId,
  required String siteId,
});

class BosClassInsightsCard extends StatefulWidget {
  const BosClassInsightsCard({
    required this.title,
    required this.subtitle,
    required this.emptyLabel,
    required this.sessionOccurrenceId,
    required this.siteId,
    required this.learnerNamesById,
    this.accentColor,
    this.insightsLoader,
    super.key,
  });

  final String title;
  final String subtitle;
  final String emptyLabel;
  final String? sessionOccurrenceId;
  final String? siteId;
  final Map<String, String> learnerNamesById;
  final Color? accentColor;
  final BosClassInsightsLoader? insightsLoader;

  @override
  State<BosClassInsightsCard> createState() => _BosClassInsightsCardState();
}

class _BosClassInsightsCardState extends State<BosClassInsightsCard> {
  Future<Map<String, dynamic>?>? _futureInsights;

  @override
  void initState() {
    super.initState();
    _futureInsights = _loadInsights();
  }

  @override
  void didUpdateWidget(covariant BosClassInsightsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionOccurrenceId != widget.sessionOccurrenceId ||
        oldWidget.siteId != widget.siteId ||
        oldWidget.insightsLoader != widget.insightsLoader) {
      _futureInsights = _loadInsights();
    }
  }

  Future<Map<String, dynamic>?> _loadInsights() async {
    final String? sessionOccurrenceId = widget.sessionOccurrenceId?.trim();
    final String? siteId = widget.siteId?.trim();
    if (sessionOccurrenceId == null ||
        sessionOccurrenceId.isEmpty ||
        siteId == null ||
        siteId.isEmpty) {
      return null;
    }

    try {
      final BosClassInsightsLoader loader = widget.insightsLoader ??
          ({required String sessionOccurrenceId, required String siteId}) {
            return BosService.instance.getClassInsights(
              sessionOccurrenceId: sessionOccurrenceId,
              siteId: siteId,
            );
          };
      final Map<String, dynamic> insights = await loader(
        sessionOccurrenceId: sessionOccurrenceId,
        siteId: siteId,
      );
      unawaited(TelemetryService.instance.logEvent(
        event: 'educator_class_view',
        metadata: <String, dynamic>{
          'surface': 'educator_today_bos_class_insights',
          'sessionOccurrenceId': sessionOccurrenceId,
          'siteId': siteId,
          'status': 'ok',
        },
      ));
      return insights;
    } catch (_) {
      unawaited(TelemetryService.instance.logEvent(
        event: 'educator_class_view',
        metadata: <String, dynamic>{
          'surface': 'educator_today_bos_class_insights',
          'sessionOccurrenceId': sessionOccurrenceId,
          'siteId': siteId,
          'status': 'error',
        },
      ));
      return null;
    }
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
        child: SingleChildScrollView(
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
                    child: Icon(Icons.insights_rounded, color: accent, size: 18),
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
                widget.subtitle,
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

                final _BosClassInsights? parsed =
                    _BosClassInsights.tryFromPayload(
                  insights,
                  widget.learnerNamesById,
                  context,
                );

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
                            '${BosCoachingI18n.learnersTracked(context)} ${parsed.countLabel(context, parsed.learnerCount)}',
                            accent,
                            context,
                          ),
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
                            '${BosCoachingI18n.activeMvlGates(context)} ${parsed.countLabel(context, parsed.activeMvlCount)}',
                            accent,
                            context,
                          ),
                        ],
                      ),
                      if (parsed.quality.hasWarnings) ...<Widget>[
                        const SizedBox(height: 8),
                        _buildQualityState(context, accent, parsed.quality),
                      ],
                      if (parsed.hasAverageSignals) ...<Widget>[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${BosCoachingI18n.fdmStateEstimate(context)}: ${BosCoachingI18n.cognition(context)} ${parsed.pct(context, parsed.cognition)} • ${BosCoachingI18n.engagement(context)} ${parsed.pct(context, parsed.engagement)} • ${BosCoachingI18n.integrity(context)} ${parsed.pct(context, parsed.integrity)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      _buildWatchlistSection(context, accent, parsed.watchlist),
                    ],
                  ],
                );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWatchlistSection(
    BuildContext context,
    Color accent,
    List<_ClassLearnerSignal> watchlist,
  ) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    if (watchlist.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: <Widget>[
            Icon(Icons.verified_outlined, size: 18, color: accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                BosCoachingI18n.watchlistClear(context),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                BosCoachingI18n.baeWatchlist(context),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: watchlist
                    .take(3)
                    .map(
                      (_ClassLearnerSignal learner) => _watchlistChip(
                        context,
                        accent,
                        learner,
                        constraints.maxWidth,
                      ),
                    )
                    .toList(growable: false),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () =>
                      _showWatchlistSheet(context, accent, watchlist),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: Text(BosCoachingI18n.viewWatchlist(context)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _watchlistChip(
    BuildContext context,
    Color accent,
    _ClassLearnerSignal learner,
    double maxWidth,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.12)),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth > 20 ? maxWidth - 20 : maxWidth,
        ),
        child: Text(
          '${learner.displayName} ${learner.summaryLabel(context)}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
        ),
      ),
    );
  }

  Future<void> _showWatchlistSheet(
    BuildContext context,
    Color accent,
    List<_ClassLearnerSignal> watchlist,
  ) async {
    final String? sessionOccurrenceId = widget.sessionOccurrenceId?.trim();
    final String? siteId = widget.siteId?.trim();
    if (sessionOccurrenceId != null && sessionOccurrenceId.isNotEmpty) {
      unawaited(TelemetryService.instance.logEvent(
        event: 'educator_learner_drilldown',
        metadata: <String, dynamic>{
          'surface': 'educator_today_bos_class_insights',
          'sessionOccurrenceId': sessionOccurrenceId,
          if (siteId != null && siteId.isNotEmpty) 'siteId': siteId,
          'watchlistCount': watchlist.length,
        },
      ));
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) {
        final ThemeData theme = Theme.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  BosCoachingI18n.baeWatchlist(context),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  BosCoachingI18n.supportRecommended(context),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: watchlist.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (BuildContext context, int index) {
                      final _ClassLearnerSignal learner = watchlist[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: accent.withValues(alpha: 0.12),
                          child: Text(
                            learner.initials,
                            style: TextStyle(
                              color: accent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        title: Text(learner.displayName),
                        subtitle: Text(learner.summaryLabel(context)),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: accent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface,
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

class _ClassLearnerSignal {
  const _ClassLearnerSignal({
    required this.learnerId,
    required this.displayName,
    required this.cognition,
    required this.engagement,
    required this.integrity,
  });

  static _ClassLearnerSignal? tryFromMap(
    Map<String, dynamic> map,
    Map<String, String> learnerNamesById,
    BuildContext context,
  ) {
    final String learnerId = (map['learnerId'] as String? ?? '').trim();
    final Map<String, dynamic>? xHat = _asStringDynamicMap(map['x_hat']);
    final double? cognition = _readFiniteDouble(xHat, 'cognition');
    final double? engagement = _readFiniteDouble(xHat, 'engagement');
    final double? integrity = _readFiniteDouble(xHat, 'integrity');
    if (cognition == null && engagement == null && integrity == null) {
      return null;
    }
    return _ClassLearnerSignal(
      learnerId: learnerId,
      displayName: learnerNamesById[learnerId]?.trim().isNotEmpty == true
          ? learnerNamesById[learnerId]!.trim()
          : BosCoachingI18n.learnerUnavailable(context),
      cognition: cognition,
      engagement: engagement,
      integrity: integrity,
    );
  }

  final String learnerId;
  final String displayName;
  final double? cognition;
  final double? engagement;
  final double? integrity;

  bool get needsAttention =>
      (cognition != null && cognition! < 0.45) ||
      (engagement != null && engagement! < 0.45) ||
      (integrity != null && integrity! < 0.45);

  double get riskScore {
    final List<double> values = <double>[
      if (cognition != null) cognition!,
      if (engagement != null) engagement!,
      if (integrity != null) integrity!,
    ];
    if (values.isEmpty) {
      return 1.0;
    }
    return values.reduce(
      (double left, double right) => left < right ? left : right,
    );
  }

  String get initials {
    final List<String> parts = displayName.split(' ');
    if (parts.length >= 2) {
      return '${parts[0].isNotEmpty ? parts[0][0] : ''}${parts[1].isNotEmpty ? parts[1][0] : ''}'
          .toUpperCase();
    }
    return displayName.isNotEmpty ? displayName[0].toUpperCase() : 'L';
  }

  String summaryLabel(BuildContext context) {
    String pct(double? value) => value == null
        ? BosCoachingI18n.signalUnavailable(context)
        : '${(value * 100).toStringAsFixed(0)}%';
    return '${BosCoachingI18n.cognition(context)} ${pct(cognition)} • ${BosCoachingI18n.engagement(context)} ${pct(engagement)} • ${BosCoachingI18n.integrity(context)} ${pct(integrity)}';
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

double? _readFiniteDouble(Map<String, dynamic>? source, String key) {
  if (source == null) {
    return null;
  }
  final dynamic value = source[key];
  if (value is! num) {
    return null;
  }
  final double converted = value.toDouble();
  return converted.isFinite ? converted : null;
}

int? _readInt(Map<String, dynamic>? source, String key) {
  if (source == null) {
    return null;
  }
  final dynamic value = source[key];
  if (value is! num) {
    return null;
  }
  return value.toInt();
}

class _BosClassInsights {
  const _BosClassInsights({
    required this.learnerCount,
    required this.activeMvlCount,
    required this.cognition,
    required this.engagement,
    required this.integrity,
    required this.watchlist,
    required this.partialSignals,
    required this.syntheticPreview,
    required this.quality,
  });

  final int? learnerCount;
  final int? activeMvlCount;
  final double? cognition;
  final double? engagement;
  final double? integrity;
  final List<_ClassLearnerSignal> watchlist;
  final bool partialSignals;
  final bool syntheticPreview;
  final _InsightDataQuality quality;

  static _BosClassInsights? tryFromPayload(
    Map<String, dynamic> payload,
    Map<String, String> learnerNamesById,
    BuildContext context,
  ) {
    final Map<String, dynamic>? averages = _asStringDynamicMap(payload['averages']);
    final Map<String, dynamic>? coverage = _asStringDynamicMap(payload['coverage']);
    final int? learnerCount = _readInt(payload, 'learnerCount');
    final int? activeMvlCount = _readInt(payload, 'activeMvlCount');
    final dynamic rawWatchlist = payload['watchlist'] ?? payload['learners'];
    final int incompleteCoverageCount = learnerCount == null
      ? 0
      : <String>['cognition', 'engagement', 'integrity']
        .where((String key) {
          final int? coverageCount = _readInt(coverage, key);
          return coverageCount != null && coverageCount < learnerCount;
        })
        .length;
    final List<_ClassLearnerSignal> watchlist = rawWatchlist is List<dynamic>
        ? rawWatchlist
            .map(_asStringDynamicMap)
            .whereType<Map<String, dynamic>>()
            .map(
              (Map<String, dynamic> entry) => _ClassLearnerSignal.tryFromMap(
                entry,
                learnerNamesById,
                context,
              ),
            )
            .whereType<_ClassLearnerSignal>()
            .where((_ClassLearnerSignal learner) => learner.needsAttention)
            .toList(growable: false)
        : const <_ClassLearnerSignal>[];
    final _InsightDataQuality quality = _InsightDataQuality.fromStatuses(
      <_FieldStatus>[
        _intStatus(payload, 'learnerCount'),
        _intStatus(payload, 'activeMvlCount'),
        _doubleStatus(averages, 'cognition'),
        _doubleStatus(averages, 'engagement'),
        _doubleStatus(averages, 'integrity'),
        _intStatus(coverage, 'cognition'),
        _intStatus(coverage, 'engagement'),
        _intStatus(coverage, 'integrity'),
        _watchlistStatus(payload),
      ],
      incomplete: incompleteCoverageCount,
    );

    watchlist.sort((a, b) => a.riskScore.compareTo(b.riskScore));

    final _BosClassInsights parsed = _BosClassInsights(
      learnerCount: learnerCount,
      activeMvlCount: activeMvlCount,
      cognition: _readFiniteDouble(averages, 'cognition'),
      engagement: _readFiniteDouble(averages, 'engagement'),
      integrity: _readFiniteDouble(averages, 'integrity'),
      watchlist: watchlist,
      partialSignals: quality.hasWarnings,
      syntheticPreview:
          payload['synthetic'] is bool && payload['synthetic'] as bool,
      quality: quality,
    );

    if (!parsed.hasAnySignal && !parsed.quality.hasWarnings) {
      return null;
    }
    return parsed;
  }

  bool get hasAnySignal =>
      learnerCount != null ||
      activeMvlCount != null ||
      cognition != null ||
      engagement != null ||
      integrity != null ||
      watchlist.isNotEmpty;

    bool get hasAverageSignals =>
      cognition != null || engagement != null || integrity != null;

  String pct(BuildContext context, double? value) {
    if (value == null) {
      return BosCoachingI18n.signalUnavailable(context);
    }
    return '${(value * 100).toStringAsFixed(0)}%';
  }

  String countLabel(BuildContext context, int? value) {
    if (value == null) {
      return BosCoachingI18n.signalUnavailable(context);
    }
    return '$value';
  }
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

_FieldStatus _doubleStatus(Map<String, dynamic>? source, String key) {
  if (source == null || !source.containsKey(key) || source[key] == null) {
    return _FieldStatus.missing;
  }
  final dynamic value = source[key];
  if (value is! num || !value.toDouble().isFinite) {
    return _FieldStatus.malformed;
  }
  return _FieldStatus.available;
}

_FieldStatus _intStatus(Map<String, dynamic>? source, String key) {
  if (source == null || !source.containsKey(key) || source[key] == null) {
    return _FieldStatus.missing;
  }
  return source[key] is num ? _FieldStatus.available : _FieldStatus.malformed;
}

_FieldStatus _watchlistStatus(Map<String, dynamic> payload) {
  if (!payload.containsKey('watchlist') && !payload.containsKey('learners')) {
    return _FieldStatus.missing;
  }
  final dynamic rawWatchlist = payload['watchlist'] ?? payload['learners'];
  return rawWatchlist is List<dynamic>
      ? _FieldStatus.available
      : _FieldStatus.malformed;
}
