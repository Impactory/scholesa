import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../auth/app_state.dart';
import '../../domain/curriculum/curriculum_family_ui.dart';
import '../../i18n/shared_role_surface_i18n.dart';
import '../../services/analytics_service.dart';
import '../../services/firestore_service.dart';
import '../../services/telemetry_service.dart';
import '../../services/workflow_bridge_service.dart';
import '../../ui/auth/global_session_menu.dart';
import '../../ui/theme/scholesa_theme.dart';
import '../reports/report_actions.dart';

/// HQ Analytics Page - Platform-wide analytics and insights
class HqAnalyticsPage extends StatefulWidget {
  const HqAnalyticsPage({
    super.key,
    this.metricsLoader,
    this.supplementalLoader,
    this.kpiPacksLoader,
    this.syntheticImportLoader,
  });

  final Future<TelemetryDashboardMetrics> Function({
    String? siteId,
    String period,
  })? metricsLoader;
  final Future<HqAnalyticsSupplementalSnapshot> Function({
    String selectedSite,
  })? supplementalLoader;
  final Future<List<Map<String, dynamic>>> Function({
    String? siteId,
    int limit,
  })? kpiPacksLoader;
  final Future<Map<String, dynamic>?> Function()? syntheticImportLoader;

  @override
  State<HqAnalyticsPage> createState() => _HqAnalyticsPageState();
}

class HqAnalyticsSupplementalSnapshot {
  const HqAnalyticsSupplementalSnapshot({
    this.siteOptions = const <Map<String, dynamic>>[],
    this.pillarAnalytics = const <Map<String, dynamic>>[],
    this.siteComparison = const <Map<String, dynamic>>[],
    this.topPerformers = const <Map<String, dynamic>>[],
    this.bosMiaFeedback,
  });

  final List<Map<String, dynamic>> siteOptions;
  final List<Map<String, dynamic>> pillarAnalytics;
  final List<Map<String, dynamic>> siteComparison;
  final List<Map<String, dynamic>> topPerformers;
  final Map<String, dynamic>? bosMiaFeedback;
}

class _HqAnalyticsPageState extends State<HqAnalyticsPage> {
  String _selectedPeriod = 'month';
  String _selectedSite = 'all';
  final AnalyticsService _analyticsService = AnalyticsService.instance;
  final WorkflowBridgeService _workflowBridgeService =
      WorkflowBridgeService.instance;
  TelemetryDashboardMetrics? _metrics;
  bool _isLoadingMetrics = true;
  bool _isLoadingSupplemental = true;
  bool _isLoadingKpiPacks = true;
  bool _isLoadingSyntheticImport = true;
  String? _metricsError;
  String? _supplementalError;
  String? _kpiPacksError;
  String? _syntheticImportError;
  List<_SiteFilterOption> _siteOptions = <_SiteFilterOption>[
    const _SiteFilterOption(id: 'all', name: 'All Sites'),
  ];
  List<_PillarAnalyticsData> _pillarAnalyticsData = <_PillarAnalyticsData>[];
  List<_SiteComparisonData> _siteComparisonData = <_SiteComparisonData>[];
  List<_TopPerformerData> _topPerformersData = <_TopPerformerData>[];
  List<_HqKpiPackSummary> _kpiPacks = <_HqKpiPackSummary>[];
  _BosMiaFeedbackSummary? _bosMiaFeedbackSummary;
  _SyntheticDatasetImportSummary? _syntheticImportSummary;
  int _usabilityScore = 4;
  int _usefulnessScore = 4;
  int _reliabilityScore = 4;
  int _voiceQualityScore = 4;
  String _rolloutRecommendation = 'scale_with_guardrails';
  Set<String> _topIssues = <String>{};

  String _t(String input) {
    return SharedRoleSurfaceI18n.text(context, input);
  }

  @override
  void initState() {
    super.initState();
    TelemetryService.instance.logEvent(
      event: 'insight.viewed',
      metadata: const <String, dynamic>{
        'surface': 'hq_analytics_page',
        'insight_type': 'platform_overview',
      },
    );
    _loadMetrics();
    _loadSupplementalData();
    _loadKpiPacks();
    _loadSyntheticImportSummary();
  }

  Future<void> _refreshAnalytics() async {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'cta': 'hq_analytics_refresh',
        'site': _selectedSite,
        'period': _selectedPeriod,
      },
    );
    await Future.wait<void>(<Future<void>>[
      _loadMetrics(),
      _loadSupplementalData(),
      _loadKpiPacks(),
      _loadSyntheticImportSummary(),
    ]);
  }

  Future<void> _loadMetrics() async {
    setState(() {
      _isLoadingMetrics = true;
      _metricsError = null;
    });
    try {
      final AppState appState = context.read<AppState>();
      final String? siteId = _selectedSite == 'all'
          ? null
          : _resolveSiteId(_selectedSite, appState);
      final TelemetryDashboardMetrics metrics = widget.metricsLoader != null
          ? await widget.metricsLoader!(
              siteId: siteId,
              period: _selectedPeriod,
            )
          : await _analyticsService.getTelemetryDashboardMetrics(
              siteId: siteId,
              period: _selectedPeriod,
            );
      if (!mounted) return;
      setState(() {
        _metrics = metrics;
        _isLoadingMetrics = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _metricsError = _t(
          'We could not load telemetry metrics right now. Retry to check the current state.',
        );
        _isLoadingMetrics = false;
      });
    }
  }

  String? _resolveSiteId(String selectedSite, AppState appState) {
    if (selectedSite == 'all') return null;
    final String normalized = selectedSite.toLowerCase();
    if (appState.siteIds.contains(selectedSite)) {
      return selectedSite;
    }
    for (final String siteId in appState.siteIds) {
      if (siteId.toLowerCase().contains(normalized)) {
        return siteId;
      }
    }
    if (appState.actualRole == UserRole.hq) {
      return selectedSite;
    }
    return appState.activeSiteId;
  }

  String _selectedSiteLabel() {
    if (_selectedSite == 'all') {
      return _t('All Sites');
    }
    for (final _SiteFilterOption option in _siteOptions) {
      if (option.id == _selectedSite) {
        return option.name;
      }
    }
    return _selectedSite;
  }

  bool _hasExportableAnalyticsData() {
    return _metrics != null ||
        _pillarAnalyticsData.isNotEmpty ||
        _siteComparisonData.isNotEmpty ||
        _topPerformersData.isNotEmpty ||
        _kpiPacks.isNotEmpty ||
        _bosMiaFeedbackSummary != null ||
        _syntheticImportSummary != null;
  }

  bool _hasSupplementalData() {
    return _pillarAnalyticsData.isNotEmpty ||
        _siteComparisonData.isNotEmpty ||
        _topPerformersData.isNotEmpty ||
        (_bosMiaFeedbackSummary?.submissionCount ?? 0) > 0;
  }

  Widget _buildLoadErrorCard({
    required String title,
    required String message,
    VoidCallback? onRetry,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ScholesaColors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: ScholesaColors.error.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.error_outline_rounded,
                    color: ScholesaColors.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: ScholesaColors.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(color: ScholesaColors.textSecondary),
            ),
            if (onRetry != null) ...<Widget>[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(_t('Retry')),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStaleDataBanner(String message) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.warning_amber_rounded, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: ScholesaColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  String _buildAnalyticsExport() {
    final StringBuffer buffer = StringBuffer()
      ..writeln(_t('Export HQ Analytics'))
      ..writeln('Generated: ${DateTime.now().toIso8601String()}')
      ..writeln('Site: ${_selectedSiteLabel()}')
      ..writeln('Period: $_selectedPeriod')
      ..writeln('');

    if (_metrics != null) {
      final TelemetryDashboardMetrics metrics = _metrics!;
      buffer
        ..writeln('Key Metrics')
        ..writeln('-----------')
        ..writeln(
          'Weekly accountability adherence: ${metrics.weeklyAccountabilityAdherenceRate.toStringAsFixed(1)}%',
        )
        ..writeln(
          'Educator review turnaround: ${metrics.educatorReviewTurnaroundHoursAvg?.toStringAsFixed(1) ?? 'n/a'}h',
        )
        ..writeln(
          'Educator review within SLA: ${metrics.educatorReviewWithinSlaRate?.toStringAsFixed(1) ?? 'n/a'}%',
        )
        ..writeln(
          'Intervention helped rate: ${metrics.interventionHelpedRate?.toStringAsFixed(1) ?? 'n/a'}%',
        )
        ..writeln('Intervention total: ${metrics.interventionTotal}')
        ..writeln('Review SLA hours: ${metrics.educatorReviewSlaHours}')
        ..writeln('');

      if (metrics.attendanceTrend.isNotEmpty) {
        buffer
          ..writeln('Attendance Trend')
          ..writeln('----------------');
        for (final AttendanceTrendPoint point in metrics.attendanceTrend) {
          buffer.writeln(
            '${point.date}: records=${point.records}, events=${point.events}, presentRate=${point.presentRate?.toStringAsFixed(1) ?? 'n/a'}%',
          );
        }
        buffer.writeln('');
      }
    }

    if (_metricsError != null && _metricsError!.trim().isNotEmpty) {
      buffer
        ..writeln('Metrics Error')
        ..writeln('-------------')
        ..writeln(_metricsError!.trim())
        ..writeln('');
    }

    if (_pillarAnalyticsData.isNotEmpty) {
      buffer
        ..writeln(_t('Pillar Performance'))
        ..writeln('------------------');
      for (final _PillarAnalyticsData item in _pillarAnalyticsData) {
        buffer.writeln(
          '${item.pillar}: progress=${(item.progress * 100).toStringAsFixed(1)}%, learners=${item.learners}, missions=${item.missions}',
        );
      }
      buffer.writeln('');
    }

    if (_siteComparisonData.isNotEmpty) {
      buffer
        ..writeln('Site Comparison')
        ..writeln('---------------');
      for (final _SiteComparisonData item in _siteComparisonData) {
        buffer.writeln(
          '${item.name} (${item.siteId}): learners=${item.learners}, attendance=${item.attendance}%, engagement=${item.engagement}%',
        );
      }
      buffer.writeln('');
    }

    if (_topPerformersData.isNotEmpty) {
      buffer
        ..writeln('Top Performers')
        ..writeln('--------------')
        ..writeln(
          'Ranked by reviewed capability growth and reviewed evidence, not assignment completion.',
        );
      for (final _TopPerformerData item in _topPerformersData) {
        final List<String> parts = <String>[
          '#${item.rank} ${item.name}',
          item.site,
          'reviewedEvidence=${item.reviewedEvidenceCount}',
        ];
        if (item.capabilityUpdates > 0) {
          parts.add('capabilityUpdates=${item.capabilityUpdates}');
        }
        if (item.reviewedDays > 0) {
          parts.add('reviewedDays=${item.reviewedDays}');
        }
        if (item.latestCapabilityTitle?.trim().isNotEmpty == true) {
          final String capabilityLabel = item.latestCapabilityLevel > 0
              ? '${item.latestCapabilityTitle} | level=${item.latestCapabilityLevel}/4'
              : item.latestCapabilityTitle!;
          parts.add('latestCapability=$capabilityLabel');
        }
        buffer.writeln(parts.join(' | '));
      }
      buffer.writeln('');
    }

    if (_kpiPacks.isNotEmpty) {
      buffer
        ..writeln('KPI Packs')
        ..writeln('---------');
      for (final _HqKpiPackSummary item in _kpiPacks) {
        buffer.writeln(
          '${item.title} | site=${item.siteId} | period=${item.period} | recommendation=${item.recommendation} | fidelity=${item.fidelityScore?.toStringAsFixed(1) ?? 'n/a'} | portfolio=${item.portfolioQualityGrade}',
        );
      }
      buffer.writeln('');
    }

    if (_bosMiaFeedbackSummary != null) {
      final _BosMiaFeedbackSummary feedback = _bosMiaFeedbackSummary!;
      buffer
        ..writeln('MiloOS feedback')
        ..writeln('------------------')
        ..writeln('Submissions: ${feedback.submissionCount}')
        ..writeln('Average overall: ${feedback.avgOverall.toStringAsFixed(1)}')
        ..writeln('Top recommendation: ${feedback.topRecommendationLabel}')
        ..writeln('Top issue: ${feedback.topIssueLabel}')
        ..writeln('');
    }

    if (_syntheticImportSummary != null) {
      final _SyntheticDatasetImportSummary summary = _syntheticImportSummary!;
      buffer
        ..writeln('Synthetic Dataset Import')
        ..writeln('------------------------')
        ..writeln('Summary: ${summary.summaryLabel}')
        ..writeln('Mode: ${summary.modeLabel}')
        ..writeln('Imported at: ${summary.importedAt.toIso8601String()}')
        ..writeln('Source packs: ${summary.sourcePacks.join(', ')}')
        ..writeln('Evidence rows: ${summary.evidenceRows}')
        ..writeln('Evaluation fixtures: ${summary.evaluationFixtures}')
        ..writeln('Imported collections: ${summary.importedCollections}')
        ..writeln('Interaction events: ${summary.interactionEvents}')
        ..writeln('Portfolio artifacts: ${summary.portfolioArtifacts}')
        ..writeln('Synthetic users: ${summary.syntheticUsers}')
        ..writeln('');
    }

    return buffer.toString().trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              ScholesaColors.hq.withValues(alpha: 0.05),
              Colors.white,
              ScholesaColors.futureSkills.withValues(alpha: 0.03),
            ],
          ),
        ),
        child: CustomScrollView(
          slivers: <Widget>[
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _buildFilters()),
            SliverToBoxAdapter(child: _buildKeyMetrics()),
            SliverToBoxAdapter(child: _buildKpiPackSection()),
            SliverToBoxAdapter(child: _buildSyntheticImportSummaryCard()),
            SliverToBoxAdapter(child: _buildBosMiaFeedbackSummaryCard()),
            SliverToBoxAdapter(child: _buildGrowthChart()),
            SliverToBoxAdapter(child: _buildPillarAnalytics()),
            SliverToBoxAdapter(child: _buildSiteComparison()),
            SliverToBoxAdapter(child: _buildTopPerformers()),
            const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: ScholesaColors.hqGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: ScholesaColors.hq.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.insights, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _t('Platform Analytics'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: ScholesaColors.hq,
                        ),
                  ),
                  Text(
                    _t('Comprehensive performance insights'),
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _refreshAnalytics,
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ScholesaColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.refresh_rounded,
                    color: ScholesaColors.warning),
              ),
            ),
            IconButton(
              onPressed: _openBosMiaFeedbackDialog,
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ScholesaColors.futureSkills.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.rate_review,
                    color: ScholesaColors.futureSkills),
              ),
            ),
            IconButton(
              onPressed: _exportReport,
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ScholesaColors.hq.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.download, color: ScholesaColors.hq),
              ),
            ),
            const SizedBox(width: 4),
            const SessionMenuHeaderAction(
              foregroundColor: ScholesaColors.hq,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: DropdownButton<String>(
                value: _selectedSite,
                isExpanded: true,
                underline: const SizedBox(),
                items: <DropdownMenuItem<String>>[
                  ..._siteOptions.map(
                    (_SiteFilterOption option) => DropdownMenuItem<String>(
                      value: option.id,
                      child: Text(
                          option.id == 'all' ? _t('All Sites') : option.name),
                    ),
                  ),
                ],
                onChanged: (String? value) {
                  if (value != null) {
                    TelemetryService.instance.logEvent(
                      event: 'cta.clicked',
                      metadata: <String, dynamic>{
                        'cta': 'hq_analytics_site_filter',
                        'site': value
                      },
                    );
                    setState(() => _selectedSite = value);
                    _loadMetrics();
                    _loadSupplementalData();
                    _loadKpiPacks();
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: DropdownButton<String>(
                value: _selectedPeriod,
                isExpanded: true,
                underline: const SizedBox(),
                items: <DropdownMenuItem<String>>[
                  DropdownMenuItem<String>(
                      value: 'week', child: Text(_t('This Week'))),
                  DropdownMenuItem<String>(
                      value: 'month', child: Text(_t('This Month'))),
                  DropdownMenuItem<String>(
                      value: 'quarter', child: Text(_t('This Quarter'))),
                  DropdownMenuItem<String>(
                      value: 'year', child: Text(_t('This Year'))),
                ],
                onChanged: (String? value) {
                  if (value != null) {
                    TelemetryService.instance.logEvent(
                      event: 'cta.clicked',
                      metadata: <String, dynamic>{
                        'cta': 'hq_analytics_period_filter',
                        'period': value
                      },
                    );
                    setState(() => _selectedPeriod = value);
                    _loadMetrics();
                    _loadSupplementalData();
                    _loadKpiPacks();
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyMetrics() {
    if (_isLoadingMetrics) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: CircularProgressIndicator(color: ScholesaColors.hq),
        ),
      );
    }

    if (_metricsError != null && _metrics == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: _buildLoadErrorCard(
          title: _t('Telemetry metrics are temporarily unavailable'),
          message: _metricsError!,
          onRetry: _refreshAnalytics,
        ),
      );
    }

    final TelemetryDashboardMetrics? metrics = _metrics;
    if (metrics == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                _t('Telemetry KPIs'),
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                _t('Waiting for first app telemetry sync.'),
                style: TextStyle(color: Colors.grey[700]),
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.assignment_turned_in,
                      value: '--',
                      label: _t('Weekly Accountability'),
                      trend: _t('Telemetry feed pending'),
                      trendUp: true,
                      color: ScholesaColors.futureSkills,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.timer,
                      value: '--',
                      label: _t('Review SLA'),
                      trend: _t('Telemetry feed pending'),
                      trendUp: true,
                      color: ScholesaColors.warning,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final String adherenceRate =
        '${metrics.weeklyAccountabilityAdherenceRate.toStringAsFixed(1)}%';
    final String reviewSlaRate = metrics.educatorReviewWithinSlaRate == null
        ? '--'
        : '${metrics.educatorReviewWithinSlaRate!.toStringAsFixed(1)}%';
    final String reviewTurnaround = metrics.educatorReviewTurnaroundHoursAvg ==
            null
        ? '--'
        : '${metrics.educatorReviewTurnaroundHoursAvg!.toStringAsFixed(1)}h';
    final String interventionHelped = metrics.interventionHelpedRate == null
        ? '--'
        : '${metrics.interventionHelpedRate!.toStringAsFixed(1)}%';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (_metricsError != null)
            _buildStaleDataBanner(
              _t(
                'Unable to refresh telemetry metrics right now. Showing the last successful data.',
              ),
            ),
          Text(
            _t('Telemetry KPIs'),
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: _MetricCard(
                  icon: Icons.assignment_turned_in,
                  value: adherenceRate,
                  label: _t('Weekly Accountability'),
                  trend: _t('7-day'),
                  trendUp: true,
                  color: ScholesaColors.futureSkills,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  icon: Icons.timer,
                  value: reviewSlaRate,
                  label:
                      '${_t('Review SLA')} (${metrics.educatorReviewSlaHours}h)',
                  trend: _t('within SLA'),
                  trendUp: true,
                  color: ScholesaColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: _MetricCard(
                  icon: Icons.rate_review,
                  value: reviewTurnaround,
                  label: _t('Avg Review Turnaround'),
                  trend: _t('hours'),
                  trendUp: true,
                  color: ScholesaColors.hq,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  icon: Icons.health_and_safety,
                  value: interventionHelped,
                  label: _t('Interventions Helped'),
                  trend: '${metrics.interventionTotal} ${_t('outcomes')}',
                  trendUp: true,
                  color: ScholesaColors.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiPackSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    _t('KPI Packs'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _generateKpiPack,
                  icon: const Icon(Icons.auto_graph_rounded),
                  label: Text(_t('Generate KPI Pack')),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isLoadingKpiPacks)
              const Center(child: CircularProgressIndicator())
            else if (_kpiPacksError != null && _kpiPacks.isEmpty)
              Text(
                _t('KPI packs are temporarily unavailable'),
                style: const TextStyle(color: ScholesaColors.error),
              )
            else if (_kpiPacks.isEmpty)
              Text(
                _t('No KPI packs yet'),
                style: TextStyle(color: Colors.grey[600]),
              )
            else ...<Widget>[
              if (_kpiPacksError != null)
                _buildStaleDataBanner(
                  _t(
                    'Unable to refresh KPI packs right now. Showing the last successful data.',
                  ),
                ),
              ..._kpiPacks.take(3).map(((_HqKpiPackSummary pack) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _HqKpiPackCard(pack: pack),
                );
              })),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGrowthChart() {
    final TelemetryDashboardMetrics? metrics = _metrics;
    final List<AttendanceTrendPoint> allTrend =
        metrics?.attendanceTrend ?? const <AttendanceTrendPoint>[];
    final List<AttendanceTrendPoint> trend =
        allTrend.length > 7 ? allTrend.sublist(allTrend.length - 7) : allTrend;
    final List<AttendanceTrendPoint> usableTrend = trend
        .where((AttendanceTrendPoint point) => point.presentRate != null)
        .toList();
    final double? latestRate = usableTrend.isNotEmpty
        ? usableTrend.last.presentRate?.toDouble()
        : null;
    final double? previousRate = usableTrend.length > 1
        ? usableTrend[usableTrend.length - 2].presentRate?.toDouble()
        : latestRate;
    final double? delta = latestRate != null && previousRate != null
        ? latestRate - previousRate
        : null;
    final bool trendUp = (delta ?? 0) >= 0;
    final bool attendanceRateUnavailable =
        trend.isNotEmpty && usableTrend.isEmpty;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  _t('Attendance Trend'),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                if (delta != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: (trendUp
                              ? ScholesaColors.success
                              : ScholesaColors.error)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          trendUp ? Icons.trending_up : Icons.trending_down,
                          size: 16,
                          color: trendUp
                              ? ScholesaColors.success
                              : ScholesaColors.error,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: trendUp
                                ? ScholesaColors.success
                                : ScholesaColors.error,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            if (_isLoadingMetrics)
              const SizedBox(
                height: 150,
                child: Center(
                  child: CircularProgressIndicator(color: ScholesaColors.hq),
                ),
              )
            else if (_metricsError != null && _metrics == null)
              SizedBox(
                height: 150,
                child: Center(
                  child: Text(
                    _t('Attendance data unavailable'),
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              )
            else if (trend.isEmpty)
              SizedBox(
                height: 150,
                child: Center(
                  child: Text(
                    _t('No attendance telemetry for this period'),
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              )
            else if (attendanceRateUnavailable)
              SizedBox(
                height: 150,
                child: Center(
                  child: Text(
                    _t('Attendance rate unavailable for this period'),
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              )
            else
              SizedBox(
                height: 150,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: usableTrend.map((AttendanceTrendPoint point) {
                    final double rate =
                        (point.presentRate!.toDouble() / 100).clamp(0.0, 1.0);
                    return _BarColumn(
                      label: _shortDateLabel(point.date),
                      value: rate,
                      color: ScholesaColors.hq,
                    );
                  }).toList(),
                ),
              ),
            if (!_isLoadingMetrics &&
                _metricsError == null &&
                latestRate != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                '${_t('Latest attendance:')} ${latestRate.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
            if (!_isLoadingMetrics && _metricsError == null && trend.isEmpty)
              Text(
                _t('Capture attendance records to render this trend.'),
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            if (_metricsError != null && _metrics != null)
              Text(
                _t('Showing last successful attendance trend'),
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            if (_metricsError != null && _metrics == null)
              Text(
                'Check Cloud Function logs for `getTelemetryDashboardMetrics`.',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyntheticImportSummaryCard() {
    if (_isLoadingSyntheticImport) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
        child:
            Center(child: CircularProgressIndicator(color: ScholesaColors.hq)),
      );
    }

    final _SyntheticDatasetImportSummary? summary = _syntheticImportSummary;
    if (_syntheticImportError != null && summary == null) {
      return _buildLoadErrorCard(
        title: _t('Synthetic import metadata is temporarily unavailable'),
        message: _syntheticImportError!,
        onRetry: _refreshAnalytics,
      );
    }
    if (summary == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (_syntheticImportError != null)
                _buildStaleDataBanner(
                  _t(
                    'Unable to refresh synthetic import metadata right now. Showing the last successful data.',
                  ),
                ),
              Text(
                _t('Synthetic Data'),
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                _t('Latest synthetic import manifest'),
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              const SizedBox(height: 12),
              Text(
                _t('No synthetic import metadata yet'),
                style: TextStyle(color: Colors.grey[700]),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              _t('Synthetic Data'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              _t('Latest synthetic import manifest'),
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ScholesaColors.futureSkills.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    summary.summaryLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_t('Source packs')}: ${summary.sourcePacks.join(', ')}',
                    style: TextStyle(color: Colors.grey[700], fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_t('Last import')}: ${summary.importedAtDisplay}',
                    style: TextStyle(color: Colors.grey[700], fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: _MetricCard(
                    icon: Icons.source_outlined,
                    value: '${summary.evidenceRows}',
                    label: _t('Evidence rows'),
                    trend: summary.modeLabel,
                    trendUp: true,
                    color: ScholesaColors.futureSkills,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    icon: Icons.fact_check_outlined,
                    value: '${summary.evaluationFixtures}',
                    label: _t('Evaluation fixtures'),
                    trend: _t('synthetic-only'),
                    trendUp: true,
                    color: ScholesaColors.warning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: _MetricCard(
                    icon: Icons.storage_rounded,
                    value: '${summary.importedCollections}',
                    label: _t('Imported collections'),
                    trend: '${summary.interactionEvents} ${_t('events')}',
                    trendUp: true,
                    color: ScholesaColors.hq,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    icon: Icons.inventory_2_outlined,
                    value: '${summary.portfolioArtifacts}',
                    label: _t('Portfolio artifacts'),
                    trend: '${summary.syntheticUsers} ${_t('learners')}',
                    trendUp: true,
                    color: ScholesaColors.impact,
                  ),
                ),
              ],
            ),
            if (summary.bosMiaTraining != null) ...<Widget>[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ScholesaColors.hq.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _t('Synthetic MiloOS training'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_t('Model version')}: ${summary.bosMiaTraining!.modelVersion}',
                      style: TextStyle(color: Colors.grey[700], fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_t('Training run')}: ${summary.bosMiaTraining!.trainingRunId}',
                      style: TextStyle(color: Colors.grey[700], fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _MetricCard(
                            icon: Icons.tune_rounded,
                            value:
                                '${summary.bosMiaTraining!.calibratedGradeBands}',
                            label: _t('Calibrated grade bands'),
                            trend:
                                '${summary.bosMiaTraining!.trainingRows} ${_t('training rows')}',
                            trendUp: true,
                            color: ScholesaColors.hq,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MetricCard(
                            icon: Icons.analytics_outlined,
                            value:
                                '${(summary.bosMiaTraining!.actionAccuracy * 100).toStringAsFixed(1)}%',
                            label: _t('Action accuracy'),
                            trend:
                                '${summary.bosMiaTraining!.goldEvalCases} ${_t('gold eval cases')}',
                            trendUp: true,
                            color: ScholesaColors.futureSkills,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _MetricCard(
                            icon: Icons.rule_folder_outlined,
                            value:
                                '${(summary.bosMiaTraining!.reviewPrecision * 100).toStringAsFixed(1)}%',
                            label: _t('Review precision'),
                            trend: _t('synthetic-only'),
                            trendUp: true,
                            color: ScholesaColors.warning,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MetricCard(
                            icon: Icons.fact_check_outlined,
                            value:
                                '${(summary.bosMiaTraining!.reviewRecall * 100).toStringAsFixed(1)}%',
                            label: _t('Review recall'),
                            trend: _t('Latest synthetic import manifest'),
                            trendUp: true,
                            color: ScholesaColors.impact,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBosMiaFeedbackSummaryCard() {
    if (_isLoadingSupplemental) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
        child:
            Center(child: CircularProgressIndicator(color: ScholesaColors.hq)),
      );
    }

    final _BosMiaFeedbackSummary? summary = _bosMiaFeedbackSummary;
    if (_supplementalError != null && !_hasSupplementalData()) {
      return _buildLoadErrorCard(
        title: _t('HQ MiloOS feedback is temporarily unavailable'),
        message: _supplementalError!,
        onRetry: _refreshAnalytics,
      );
    }
    if (summary == null || summary.submissionCount == 0) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                _t('HQ MiloOS feedback'),
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                _t('Real-world HQ feedback (14-day)'),
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              const SizedBox(height: 12),
              Text(
                _t('No HQ feedback submissions yet'),
                style: TextStyle(color: Colors.grey[700]),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (_supplementalError != null)
              _buildStaleDataBanner(
                _t(
                  'Unable to refresh supplemental analytics right now. Showing the last successful data.',
                ),
              ),
            Text(
              _t('HQ MiloOS feedback'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              _t('Real-world HQ feedback (14-day)'),
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: _MetricCard(
                    icon: Icons.thumb_up_alt,
                    value: '${summary.avgUsefulness.toStringAsFixed(2)}/5',
                    label: _t('Usefulness'),
                    trend: '${summary.submissionCount} ${_t('submissions')}',
                    trendUp: summary.avgUsefulness >= 4,
                    color: ScholesaColors.impact,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    icon: Icons.verified,
                    value: '${summary.avgOverall.toStringAsFixed(2)}/5',
                    label: _t('Usability'),
                    trend: _t(summary.topRecommendationLabel),
                    trendUp: summary.avgOverall >= 4,
                    color: ScholesaColors.hq,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${_t('Top recommendation')}: ${_t(summary.topRecommendationLabel)}',
              style: TextStyle(color: Colors.grey[700], fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              '${_t('Most reported issue')}: ${_t(summary.topIssueLabel)}',
              style: TextStyle(color: Colors.grey[700], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  String _shortDateLabel(String rawDate) {
    final DateTime? date = DateTime.tryParse(rawDate);
    if (date == null) return rawDate;
    return '${date.month}/${date.day}';
  }

  Widget _buildPillarAnalytics() {
    final List<_PillarAnalyticsData> rows = _pillarAnalyticsData;

    if (_supplementalError != null && !_hasSupplementalData()) {
      return _buildLoadErrorCard(
        title: _t('Supplemental analytics are temporarily unavailable'),
        message: _supplementalError!,
        onRetry: _refreshAnalytics,
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (_supplementalError != null && _hasSupplementalData())
              _buildStaleDataBanner(
                _t(
                  'Unable to refresh supplemental analytics right now. Showing the last successful data.',
                ),
              ),
            Text(
              _t('Pillar Performance'),
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 20),
            if (rows.isEmpty)
              Text(
                _t('No pillar data available'),
                style: const TextStyle(color: ScholesaColors.textSecondary),
              )
            else
              for (int index = 0; index < rows.length; index++) ...<Widget>[
                _PillarAnalyticsRow(
                  icon: _pillarIcon(rows[index].pillar),
                  label: _t(rows[index].pillar),
                  progress: rows[index].progress,
                  learners: rows[index].learners,
                  missions: rows[index].missions,
                  color: _pillarColor(rows[index].pillar),
                ),
                if (index < rows.length - 1) const SizedBox(height: 16),
              ],
          ],
        ),
      ),
    );
  }

  Widget _buildSiteComparison() {
    if (_isLoadingSupplemental) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            _t('Loading...'),
            style: const TextStyle(color: ScholesaColors.textSecondary),
          ),
        ),
      );
    }

    if (_supplementalError != null && _siteComparisonData.isEmpty) {
      return _buildLoadErrorCard(
        title: _t('Site comparison is temporarily unavailable'),
        message: _supplementalError!,
        onRetry: _refreshAnalytics,
      );
    }

    if (_siteComparisonData.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            _t('No comparison data available'),
            style: const TextStyle(color: ScholesaColors.textSecondary),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _t('Site Comparison'),
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: <Widget>[
                for (int index = 0;
                    index < _siteComparisonData.length;
                    index++) ...<Widget>[
                  _SiteComparisonRow(
                    name: _siteComparisonData[index].name,
                    learners: _siteComparisonData[index].learners,
                    attendance: _siteComparisonData[index].attendance,
                    engagement: _siteComparisonData[index].engagement,
                  ),
                  if (index < _siteComparisonData.length - 1) const Divider(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopPerformers() {
    if (_isLoadingSupplemental) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            _t('Loading...'),
            style: const TextStyle(color: ScholesaColors.textSecondary),
          ),
        ),
      );
    }

    if (_supplementalError != null && _topPerformersData.isEmpty) {
      return _buildLoadErrorCard(
        title: _t('Top performers are temporarily unavailable'),
        message: _supplementalError!,
        onRetry: _refreshAnalytics,
      );
    }

    if (_topPerformersData.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            _t('No top performers available'),
            style: const TextStyle(color: ScholesaColors.textSecondary),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                _t('Top Performers'),
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              TextButton(
                onPressed: _showAllTopPerformers,
                child: Text(_t('View All')),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._topPerformersData.map(
            (_TopPerformerData performer) => _TopPerformerCard(
              rank: performer.rank,
              name: performer.name,
              site: performer.site,
              reviewedEvidenceCount: performer.reviewedEvidenceCount,
              capabilityUpdates: performer.capabilityUpdates,
              reviewedDays: performer.reviewedDays,
              latestCapabilityTitle: performer.latestCapabilityTitle,
              latestCapabilityLevel: performer.latestCapabilityLevel,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportReport() async {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'cta': 'hq_analytics_export_report',
        'site': _selectedSite,
        'period': _selectedPeriod,
      },
    );
    if (!_hasExportableAnalyticsData()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('No HQ analytics data to export yet.')),
        ),
      );
      return;
    }
    final String fileName = _analyticsExportFileName();
    final String exportContent = _buildAnalyticsExport();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final AppState? appState = context.read<AppState?>();
    final String siteId = (appState?.activeSiteId ?? '').trim();
    await ReportActions.exportText(
      messenger: messenger,
      isMounted: () => mounted,
      fileName: fileName,
      content: exportContent,
      module: 'hq_analytics',
      surface: 'hq_analytics',
      copiedEventName: 'hq.analytics_export.copied',
      successMessage: _t('HQ analytics export downloaded.'),
      copiedMessage: _t('HQ analytics export copied to clipboard.'),
      errorMessage: _t('Unable to export HQ analytics right now.'),
      unsupportedLogMessage:
          'Export unsupported for HQ analytics export, copying content instead',
      role: 'hq',
      siteId: siteId.isEmpty ? null : siteId,
      metadata: <String, dynamic>{
        'site': _selectedSite,
        'period': _selectedPeriod,
      },
    );
  }

  String _analyticsExportFileName() {
    final String siteSegment = _selectedSite == 'all'
        ? 'all-sites'
        : _selectedSite.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    final String dateSegment =
        DateTime.now().toIso8601String().split('T').first;
    return 'hq-analytics-$siteSegment-$_selectedPeriod-$dateSegment.txt';
  }

  Future<void> _generateKpiPack() async {
    final String? siteId = _selectedSite == 'all'
        ? null
        : _resolveSiteId(_selectedSite, context.read<AppState>());
    if ((siteId ?? '').trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('Select a site to generate a KPI pack')),
        ),
      );
      return;
    }

    try {
      await _workflowBridgeService.generateKpiPack(
        siteId: siteId,
        period: _selectedPeriod == 'week' ? 'month' : _selectedPeriod,
      );
      await _loadKpiPacks();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('Generate KPI Pack')),
          backgroundColor: ScholesaColors.hq,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('Unable to load telemetry metrics:')),
          backgroundColor: ScholesaColors.error,
        ),
      );
    }
  }

  Future<void> _openBosMiaFeedbackDialog() async {
    TelemetryService.instance.logEvent(
      event: 'popup.shown',
      metadata: const <String, dynamic>{
        'popup_id': 'hq_bos_mia_feedback',
        'surface': 'hq_analytics_page',
      },
    );
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context,
              void Function(void Function()) setDialogState) {
            return AlertDialog(
              title: Text(_t('MiloOS feedback')),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        _t('Rate real-world MiloOS usefulness'),
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 16),
                      _buildScoreChips(
                        label: _t('Usability'),
                        currentValue: _usabilityScore,
                        onChanged: (int value) {
                          setDialogState(() => _usabilityScore = value);
                        },
                      ),
                      _buildScoreChips(
                        label: _t('Usefulness'),
                        currentValue: _usefulnessScore,
                        onChanged: (int value) {
                          setDialogState(() => _usefulnessScore = value);
                        },
                      ),
                      _buildScoreChips(
                        label: _t('Reliability'),
                        currentValue: _reliabilityScore,
                        onChanged: (int value) {
                          setDialogState(() => _reliabilityScore = value);
                        },
                      ),
                      _buildScoreChips(
                        label: _t('Voice quality'),
                        currentValue: _voiceQualityScore,
                        onChanged: (int value) {
                          setDialogState(() => _voiceQualityScore = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _t('Rollout recommendation'),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Map<String, String>>[
                          <String, String>{
                            'value': 'scale_now',
                            'label': _t('Scale now')
                          },
                          <String, String>{
                            'value': 'scale_with_guardrails',
                            'label': _t('Scale with guardrails')
                          },
                          <String, String>{
                            'value': 'hold_and_fix',
                            'label': _t('Hold and fix')
                          },
                        ].map((Map<String, String> option) {
                          return ChoiceChip(
                            label: Text(option['label']!),
                            selected: _rolloutRecommendation == option['value'],
                            onSelected: (_) {
                              setDialogState(() {
                                _rolloutRecommendation = option['value']!;
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _t('Top issues observed'),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Map<String, String>>[
                          <String, String>{
                            'value': 'over_triggering',
                            'label': _t('Over-triggering'),
                          },
                          <String, String>{
                            'value': 'voice_recognition_misses',
                            'label': _t('Voice recognition misses'),
                          },
                          <String, String>{
                            'value': 'weak_coaching_quality',
                            'label': _t('Weak coaching quality'),
                          },
                          <String, String>{
                            'value': 'low_reengagement',
                            'label': _t('Low learner re-engagement'),
                          },
                          <String, String>{
                            'value': 'telemetry_gaps',
                            'label': _t('Telemetry gaps'),
                          },
                        ].map((Map<String, String> option) {
                          final bool selected =
                              _topIssues.contains(option['value']);
                          return FilterChip(
                            label: Text(option['label']!),
                            selected: selected,
                            onSelected: (bool value) {
                              setDialogState(() {
                                if (value) {
                                  _topIssues = <String>{
                                    ..._topIssues,
                                    option['value']!
                                  };
                                } else {
                                  _topIssues = _topIssues
                                      .where((String issue) =>
                                          issue != option['value'])
                                      .toSet();
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    TelemetryService.instance.logEvent(
                      event: 'popup.dismissed',
                      metadata: const <String, dynamic>{
                        'popup_id': 'hq_bos_mia_feedback',
                        'surface': 'hq_analytics_page',
                      },
                    );
                    Navigator.pop(dialogContext);
                  },
                  child: Text(_t('Cancel')),
                ),
                ElevatedButton(
                  onPressed: () {
                    TelemetryService.instance.logEvent(
                      event: 'bos_mia.usability.feedback',
                      metadata: <String, dynamic>{
                        'surface': 'hq_analytics_page',
                        'site_filter': _selectedSite,
                        'period': _selectedPeriod,
                        'usability_score': _usabilityScore,
                        'usefulness_score': _usefulnessScore,
                        'reliability_score': _reliabilityScore,
                        'voice_quality_score': _voiceQualityScore,
                        'rollout_recommendation': _rolloutRecommendation,
                        'top_issues': _topIssues.toList()..sort(),
                      },
                    );
                    TelemetryService.instance.logEvent(
                      event: 'popup.completed',
                      metadata: const <String, dynamic>{
                        'popup_id': 'hq_bos_mia_feedback',
                        'surface': 'hq_analytics_page',
                        'completion_action': 'submit_feedback',
                      },
                    );
                    Navigator.pop(dialogContext);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_t('HQ feedback submitted')),
                        backgroundColor: ScholesaColors.hq,
                      ),
                    );
                  },
                  child: Text(_t('Submit feedback')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildScoreChips({
    required String label,
    required int currentValue,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: List<Widget>.generate(5, (int index) {
            final int score = index + 1;
            return ChoiceChip(
              label: Text('$score'),
              selected: currentValue == score,
              onSelected: (_) => onChanged(score),
            );
          }),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Future<void> _showAllTopPerformers() async {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: const <String, dynamic>{
        'cta': 'hq_analytics_view_all_top_performers'
      },
    );
    TelemetryService.instance.logEvent(
      event: 'insight.viewed',
      metadata: const <String, dynamic>{
        'surface': 'hq_analytics_page',
        'insight_type': 'top_performers',
      },
    );
    TelemetryService.instance.logEvent(
      event: 'popup.shown',
      metadata: const <String, dynamic>{
        'popup_id': 'hq_analytics_top_performers',
        'surface': 'hq_analytics_page',
      },
    );
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                _t('Top Performers'),
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              SizedBox(height: 12),
              ..._topPerformersData.map(
                (_TopPerformerData performer) => _TopPerformerCard(
                  rank: performer.rank,
                  name: performer.name,
                  site: performer.site,
                  reviewedEvidenceCount: performer.reviewedEvidenceCount,
                  capabilityUpdates: performer.capabilityUpdates,
                  reviewedDays: performer.reviewedDays,
                  latestCapabilityTitle: performer.latestCapabilityTitle,
                  latestCapabilityLevel: performer.latestCapabilityLevel,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    TelemetryService.instance.logEvent(
      event: 'popup.dismissed',
      metadata: const <String, dynamic>{
        'popup_id': 'hq_analytics_top_performers',
        'surface': 'hq_analytics_page',
      },
    );
  }

  Future<void> _loadSupplementalData() async {
    if (widget.supplementalLoader != null) {
      if (!mounted) return;
      setState(() {
        _isLoadingSupplemental = true;
        _supplementalError = null;
      });
      try {
        final HqAnalyticsSupplementalSnapshot snapshot =
            await widget.supplementalLoader!(selectedSite: _selectedSite);
        if (!mounted) return;
        setState(() {
          _siteOptions = <_SiteFilterOption>[
            const _SiteFilterOption(id: 'all', name: 'All Sites'),
            ...snapshot.siteOptions.map(
              (Map<String, dynamic> row) => _SiteFilterOption(
                id: (row['id'] as String?) ?? 'unknown',
                name: (row['name'] as String?) ??
                    ((row['id'] as String?) ?? 'unknown'),
              ),
            ),
          ];
          if (!_siteOptions
              .any((_SiteFilterOption option) => option.id == _selectedSite)) {
            _selectedSite = 'all';
          }
          _pillarAnalyticsData = snapshot.pillarAnalytics
              .map(
                (Map<String, dynamic> row) => _PillarAnalyticsData(
                  pillar: curriculumLegacyFamilyStorageLabelFromAny(
                    row['pillar'] as String?,
                  ),
                  progress: ((row['progress'] as num?) ?? 0).toDouble(),
                  learners: (row['learners'] as num?)?.toInt() ?? 0,
                  missions: (row['missions'] as num?)?.toInt() ?? 0,
                ),
              )
              .toList(growable: false);
          _siteComparisonData = snapshot.siteComparison
              .map(
                (Map<String, dynamic> row) => _SiteComparisonData(
                  siteId: (row['siteId'] as String?) ?? 'site',
                  name: (row['name'] as String?) ?? 'Site',
                  learners: (row['learners'] as num?)?.toInt() ?? 0,
                  attendance: (row['attendance'] as num?)?.toInt() ?? 0,
                  engagement: (row['engagement'] as num?)?.toInt() ?? 0,
                ),
              )
              .toList(growable: false);
          _topPerformersData = snapshot.topPerformers
              .map(
                (Map<String, dynamic> row) => _TopPerformerData(
                  rank: (row['rank'] as num?)?.toInt() ?? 1,
                  name: (row['name'] as String?) ?? 'Learner',
                  site: (row['site'] as String?) ?? _t('All Sites'),
                  reviewedEvidenceCount:
                      (row['reviewedEvidenceCount'] as num?)?.toInt() ??
                          (row['missionsCompleted'] as num?)?.toInt() ??
                          0,
                  capabilityUpdates:
                      (row['capabilityUpdates'] as num?)?.toInt() ?? 0,
                  reviewedDays: (row['reviewedDays'] as num?)?.toInt() ??
                      (row['streak'] as num?)?.toInt() ??
                      0,
                  latestCapabilityTitle:
                      (row['latestCapabilityTitle'] as String?)?.trim(),
                  latestCapabilityLevel:
                      (row['latestCapabilityLevel'] as num?)?.toInt() ?? 0,
                ),
              )
              .toList(growable: false);
          _bosMiaFeedbackSummary = snapshot.bosMiaFeedback == null
              ? null
              : _BosMiaFeedbackSummary(
                  submissionCount:
                      (snapshot.bosMiaFeedback!['submissionCount'] as num?)
                              ?.toInt() ??
                          0,
                  avgUsability:
                      ((snapshot.bosMiaFeedback!['avgUsability'] as num?) ?? 0)
                          .toDouble(),
                  avgUsefulness:
                      ((snapshot.bosMiaFeedback!['avgUsefulness'] as num?) ?? 0)
                          .toDouble(),
                  avgReliability:
                      ((snapshot.bosMiaFeedback!['avgReliability'] as num?) ??
                              0)
                          .toDouble(),
                  avgVoiceQuality:
                      ((snapshot.bosMiaFeedback!['avgVoiceQuality'] as num?) ??
                              0)
                          .toDouble(),
                  topRecommendation: (snapshot
                          .bosMiaFeedback!['topRecommendation'] as String?) ??
                      'scale_with_guardrails',
                  topIssue: (snapshot.bosMiaFeedback!['topIssue'] as String?) ??
                      'telemetry_gaps',
                );
          _supplementalError = null;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _supplementalError = _t(
            'We could not load supplemental analytics right now. Retry to check the current state.',
          );
        });
      } finally {
        if (mounted) {
          setState(() => _isLoadingSupplemental = false);
        }
      }
      return;
    }

    final FirestoreService? firestoreService = _maybeFirestoreService();
    if (firestoreService == null) {
      if (!mounted) return;
      setState(() {
        _isLoadingSupplemental = false;
        _supplementalError = _t(
          'We could not load supplemental analytics right now. Retry to check the current state.',
        );
        _siteOptions = <_SiteFilterOption>[
          const _SiteFilterOption(id: 'all', name: 'All Sites')
        ];
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoadingSupplemental = true;
      _supplementalError = null;
    });

    try {
      final QuerySnapshot<Map<String, dynamic>> sitesSnapshot =
          await firestoreService.firestore.collection('sites').limit(300).get();

      final Map<String, String> siteNames = <String, String>{};
      final List<_SiteComparisonData> comparison = <_SiteComparisonData>[];
      final List<_SiteFilterOption> options = <_SiteFilterOption>[
        const _SiteFilterOption(id: 'all', name: 'All Sites'),
      ];

      final QuerySnapshot<Map<String, dynamic>> missionsSnapshot =
          await firestoreService.firestore
              .collection('missions')
              .limit(500)
              .get();

      final Map<String, String> missionPillarById = <String, String>{};
      final Map<String, int> missionsByPillar = _emptyPillarCountMap();

      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in missionsSnapshot.docs) {
        final Map<String, dynamic> data = doc.data();
        final String siteId = ((data['siteId'] as String?) ?? '').trim();
        if (_selectedSite != 'all' &&
            siteId.isNotEmpty &&
            siteId != _selectedSite) {
          continue;
        }
        final String pillar = _pillarLabelFromData(data);
        missionPillarById[doc.id] = pillar;
        missionsByPillar[pillar] = (missionsByPillar[pillar] ?? 0) + 1;
      }

      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in sitesSnapshot.docs) {
        final Map<String, dynamic> data = doc.data();
        final String name = (data['name'] as String?)?.trim().isNotEmpty == true
            ? (data['name'] as String).trim()
            : doc.id;
        siteNames[doc.id] = name;
        options.add(_SiteFilterOption(id: doc.id, name: name));

        final int learners = _asInt(data['learnerCount']) ??
            ((data['learnerIds'] as List?)?.length ?? 0);
        final int educators = _asInt(data['educatorCount']) ??
            ((data['educatorIds'] as List?)?.length ?? 0);
        final int health = _asInt(data['healthScore']) ?? 75;
        final int attendance = health.clamp(0, 100);
        final int engagement = (learners == 0
                ? 0
                : ((educators * 100) ~/ (learners == 0 ? 1 : learners)) * 5)
            .clamp(0, 100);

        comparison.add(
          _SiteComparisonData(
            siteId: doc.id,
            name: name,
            learners: learners,
            attendance: attendance,
            engagement: engagement,
          ),
        );
      }

      comparison.sort((_SiteComparisonData a, _SiteComparisonData b) =>
          b.attendance.compareTo(a.attendance));
      final List<_SiteComparisonData> comparisonTop =
          comparison.take(3).toList();

      Query<Map<String, dynamic>> attemptsQuery =
          firestoreService.firestore.collection('missionAttempts');
      if (_selectedSite != 'all') {
        attemptsQuery = attemptsQuery.where('siteId', isEqualTo: _selectedSite);
      }
      final QuerySnapshot<Map<String, dynamic>> attemptsSnapshot =
          await attemptsQuery.limit(500).get();

      Query<Map<String, dynamic>> growthQuery =
          firestoreService.firestore.collection('capabilityGrowthEvents');
      if (_selectedSite != 'all') {
        growthQuery = growthQuery.where('siteId', isEqualTo: _selectedSite);
      }
      final QuerySnapshot<Map<String, dynamic>> growthSnapshot =
          await growthQuery.limit(500).get();

      final Map<String, int> reviewedEvidenceByLearner = <String, int>{};
      final Map<String, String> learnerSite = <String, String>{};
      final Map<String, Set<String>> learnerDays = <String, Set<String>>{};
      final Map<String, int> capabilityUpdatesByLearner = <String, int>{};
      final Map<String, String> latestCapabilityTitleByLearner =
          <String, String>{};
      final Map<String, int> latestCapabilityLevelByLearner = <String, int>{};
      final Map<String, DateTime> latestGrowthAtByLearner =
          <String, DateTime>{};
      final Map<String, int> attemptsByPillar = _emptyPillarCountMap();
      final Map<String, int> completedByPillar = _emptyPillarCountMap();
      final Map<String, Set<String>> learnersByPillar =
          _emptyPillarLearnerMap();

      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in attemptsSnapshot.docs) {
        final Map<String, dynamic> data = doc.data();
        final String learnerId = ((data['learnerId'] as String?) ?? '').trim();
        if (learnerId.isEmpty) continue;

        final String siteId = ((data['siteId'] as String?) ?? '').trim();
        if (siteId.isNotEmpty) learnerSite[learnerId] = siteId;

        final String missionId = ((data['missionId'] as String?) ?? '').trim();
        final String pillar =
            _pillarLabelFromAttempt(data, missionPillarById[missionId]);
        attemptsByPillar[pillar] = (attemptsByPillar[pillar] ?? 0) + 1;
        learnersByPillar.putIfAbsent(pillar, () => <String>{}).add(learnerId);
        final String status = ((data['status'] as String?) ?? '').toLowerCase();
        final String reviewStatus =
            ((data['reviewStatus'] as String?) ?? '').toLowerCase();
        final bool completed = status == 'completed' ||
            status == 'passed' ||
            status == 'mastered' ||
            status == 'done' ||
            status == 'reviewed' ||
            status == 'approved' ||
            reviewStatus == 'approved' ||
            reviewStatus == 'reviewed';
        if (completed) {
          reviewedEvidenceByLearner[learnerId] =
              (reviewedEvidenceByLearner[learnerId] ?? 0) + 1;
          final DateTime? createdAt = _toDateTime(data['createdAt']) ??
              _toDateTime(data['submittedAt']);
          if (createdAt != null) {
            final String dayKey =
                '${createdAt.year}-${createdAt.month}-${createdAt.day}';
            learnerDays.putIfAbsent(learnerId, () => <String>{}).add(dayKey);
          }
          completedByPillar[pillar] = (completedByPillar[pillar] ?? 0) + 1;
        }
      }

      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in growthSnapshot.docs) {
        final Map<String, dynamic> data = doc.data();
        final String learnerId = ((data['learnerId'] as String?) ?? '').trim();
        if (learnerId.isEmpty) continue;

        final String siteId = ((data['siteId'] as String?) ?? '').trim();
        if (siteId.isNotEmpty) {
          learnerSite[learnerId] = siteId;
        }

        capabilityUpdatesByLearner[learnerId] =
            (capabilityUpdatesByLearner[learnerId] ?? 0) + 1;

        final DateTime? occurredAt =
            _toDateTime(data['occurredAt']) ?? _toDateTime(data['createdAt']);
        final DateTime latestSeen = latestGrowthAtByLearner[learnerId] ??
            DateTime.fromMillisecondsSinceEpoch(0);
        if (occurredAt != null && occurredAt.isAfter(latestSeen)) {
          latestGrowthAtByLearner[learnerId] = occurredAt;
          final String capabilityTitle =
              ((data['capabilityTitle'] as String?) ?? '').trim();
          if (capabilityTitle.isNotEmpty) {
            latestCapabilityTitleByLearner[learnerId] = capabilityTitle;
          }
          latestCapabilityLevelByLearner[learnerId] =
              _asInt(data['currentLevel']) ??
                  _asInt(data['newLevel']) ??
                  _asInt(data['level']) ??
                  0;
        }
      }

      final List<_PillarAnalyticsData> pillarData =
          CurriculumLegacyFamilyCode.values
              .map(
                (CurriculumLegacyFamilyCode code) => _buildPillarData(
                  pillar: curriculumLegacyFamilyStorageLabel(code),
                  missionsByPillar: missionsByPillar,
                  attemptsByPillar: attemptsByPillar,
                  completedByPillar: completedByPillar,
                  learnersByPillar: learnersByPillar,
                ),
              )
              .toList(growable: false);

      final Set<String> rankedLearnerIds = <String>{
        ...reviewedEvidenceByLearner.keys,
        ...capabilityUpdatesByLearner.keys,
      };
      final List<MapEntry<String, int>> ranked = rankedLearnerIds
          .map(
            (String learnerId) => MapEntry<String, int>(
              learnerId,
              reviewedEvidenceByLearner[learnerId] ?? 0,
            ),
          )
          .toList()
        ..sort((MapEntry<String, int> a, MapEntry<String, int> b) {
          final int growthCompare =
              (capabilityUpdatesByLearner[b.key] ?? 0).compareTo(
            capabilityUpdatesByLearner[a.key] ?? 0,
          );
          if (growthCompare != 0) {
            return growthCompare;
          }
          final int evidenceCompare = b.value.compareTo(a.value);
          if (evidenceCompare != 0) {
            return evidenceCompare;
          }
          return (learnerDays[b.key]?.length ?? 0)
              .compareTo(learnerDays[a.key]?.length ?? 0);
        });
      final List<String> topLearnerIds = ranked
          .take(10)
          .map((MapEntry<String, int> entry) => entry.key)
          .toList();
      final Map<String, String> learnerNames =
          await _loadUserNames(firestoreService, topLearnerIds);

      final List<_TopPerformerData> performers = <_TopPerformerData>[];
      final int topCount = ranked.length < 3 ? ranked.length : 3;
      for (int index = 0; index < topCount; index++) {
        final String learnerId = ranked[index].key;
        final String? siteId = learnerSite[learnerId];
        final int streak = learnerDays[learnerId]?.length ?? 0;
        performers.add(
          _TopPerformerData(
            rank: index + 1,
            name: learnerNames[learnerId] ?? learnerId,
            site: siteId != null && siteNames.containsKey(siteId)
                ? siteNames[siteId]!
                : _t('All Sites'),
            reviewedEvidenceCount: ranked[index].value,
            capabilityUpdates: capabilityUpdatesByLearner[learnerId] ?? 0,
            reviewedDays: streak,
            latestCapabilityTitle: latestCapabilityTitleByLearner[learnerId],
            latestCapabilityLevel:
                latestCapabilityLevelByLearner[learnerId] ?? 0,
          ),
        );
      }

      Query<Map<String, dynamic>> feedbackQuery = firestoreService.firestore
          .collection('telemetryEvents')
          .where('eventType', isEqualTo: 'bos_mia.usability.feedback')
          .limit(200);
      if (_selectedSite != 'all') {
        feedbackQuery = feedbackQuery.where('siteId', isEqualTo: _selectedSite);
      }

      final QuerySnapshot<Map<String, dynamic>> feedbackSnapshot =
          await feedbackQuery.get();

      final _BosMiaFeedbackSummary summary =
          _summarizeBosMiaFeedback(feedbackSnapshot.docs);

      if (!mounted) return;
      setState(() {
        _siteOptions = options;
        if (!_siteOptions
            .any((_SiteFilterOption option) => option.id == _selectedSite)) {
          _selectedSite = 'all';
        }
        _pillarAnalyticsData = pillarData;
        _siteComparisonData = comparisonTop;
        _topPerformersData = performers;
        _bosMiaFeedbackSummary = summary;
        _supplementalError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _supplementalError = _t(
          'We could not load supplemental analytics right now. Retry to check the current state.',
        );
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingSupplemental = false);
      }
    }
  }

  Future<void> _loadKpiPacks() async {
    if (!mounted) return;
    setState(() {
      _isLoadingKpiPacks = true;
      _kpiPacksError = null;
    });
    try {
      final String? siteId = _selectedSite == 'all'
          ? null
          : _resolveSiteId(_selectedSite, context.read<AppState>());
      final List<Map<String, dynamic>> rows = widget.kpiPacksLoader != null
          ? await widget.kpiPacksLoader!(siteId: siteId, limit: 24)
          : await _workflowBridgeService.listKpiPacks(
              siteId: siteId,
              limit: 24,
            );
      final List<_HqKpiPackSummary> packs =
          rows.map((Map<String, dynamic> row) {
        return _HqKpiPackSummary(
          id: row['id'] as String? ?? '',
          title: row['title'] as String? ?? 'KPI Pack',
          siteId: row['siteId'] as String? ?? 'site',
          period: row['period'] as String? ?? 'month',
          recommendation: row['recommendation'] as String? ?? 'stabilize',
          fidelityScore: _readFiniteScore(row['fidelityScore']),
          portfolioQualityGrade: row['portfolioQualityGrade'] as String? ?? 'C',
          updatedAt: WorkflowBridgeService.toDateTime(row['updatedAt']) ??
              WorkflowBridgeService.toDateTime(row['createdAt']) ??
              DateTime.now(),
        );
      }).toList(growable: false)
            ..sort(
              (_HqKpiPackSummary a, _HqKpiPackSummary b) =>
                  b.updatedAt.compareTo(a.updatedAt),
            );
      if (!mounted) return;
      setState(() {
        _kpiPacks = packs;
        _kpiPacksError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _kpiPacksError = _t(
          'We could not load KPI packs right now. Retry to check the current state.',
        );
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingKpiPacks = false);
      }
    }
  }

  double? _readFiniteScore(dynamic value) {
    if (value is! num) {
      return null;
    }
    final double numeric = value.toDouble();
    if (!numeric.isFinite) {
      return null;
    }
    return (numeric.clamp(0.0, 1.0) as num).toDouble();
  }

  Future<void> _loadSyntheticImportSummary() async {
    if (!mounted) return;
    setState(() {
      _isLoadingSyntheticImport = true;
      _syntheticImportError = null;
    });
    try {
      Map<String, dynamic>? payload = widget.syntheticImportLoader != null
          ? await widget.syntheticImportLoader!()
          : null;

      if (payload == null) {
        final FirestoreService? firestoreService = _maybeFirestoreService();
        if (firestoreService != null) {
          final DocumentSnapshot<Map<String, dynamic>> latestDoc =
              await firestoreService.firestore
                  .collection('syntheticDatasetImports')
                  .doc('latest')
                  .get();
          if (latestDoc.exists) {
            payload = latestDoc.data();
          }
        }
      }

      final _SyntheticDatasetImportSummary? summary = payload == null
          ? null
          : _SyntheticDatasetImportSummary.fromMap(payload, _toDateTime);
      if (!mounted) return;
      setState(() {
        _syntheticImportSummary = summary;
        _syntheticImportError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _syntheticImportError = _t(
          'We could not load synthetic import metadata right now. Retry to check the current state.',
        );
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingSyntheticImport = false);
      }
    }
  }

  _BosMiaFeedbackSummary _summarizeBosMiaFeedback(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    if (docs.isEmpty) {
      return const _BosMiaFeedbackSummary.empty();
    }

    const Duration lookback = Duration(days: 14);
    final DateTime now = DateTime.now();
    int submissions = 0;
    double usabilityTotal = 0;
    double usefulnessTotal = 0;
    double reliabilityTotal = 0;
    double voiceQualityTotal = 0;
    final Map<String, int> recommendationCounts = <String, int>{};
    final Map<String, int> issueCounts = <String, int>{};

    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in docs) {
      final Map<String, dynamic> data = doc.data();
      final DateTime eventTime = _toDateTime(data['timestamp']) ??
          _toDateTime(data['createdAt']) ??
          now;
      if (now.difference(eventTime) > lookback) {
        continue;
      }

      final Map<String, dynamic> metadata =
          (data['metadata'] as Map<String, dynamic>?) ?? <String, dynamic>{};

      final int usability =
          (_asInt(metadata['usability_score']) ?? 0).clamp(1, 5);
      final int usefulness =
          (_asInt(metadata['usefulness_score']) ?? 0).clamp(1, 5);
      final int reliability =
          (_asInt(metadata['reliability_score']) ?? 0).clamp(1, 5);
      final int voiceQuality =
          (_asInt(metadata['voice_quality_score']) ?? 0).clamp(1, 5);
      if (usability == 0 ||
          usefulness == 0 ||
          reliability == 0 ||
          voiceQuality == 0) {
        continue;
      }

      submissions += 1;
      usabilityTotal += usability;
      usefulnessTotal += usefulness;
      reliabilityTotal += reliability;
      voiceQualityTotal += voiceQuality;

      final String recommendation =
          ((metadata['rollout_recommendation'] as String?) ?? '').trim();
      if (recommendation.isNotEmpty) {
        recommendationCounts[recommendation] =
            (recommendationCounts[recommendation] ?? 0) + 1;
      }

      final List<dynamic> issues =
          (metadata['top_issues'] as List?) ?? <dynamic>[];
      for (final dynamic issue in issues) {
        final String value = issue.toString().trim();
        if (value.isEmpty) continue;
        issueCounts[value] = (issueCounts[value] ?? 0) + 1;
      }
    }

    if (submissions == 0) {
      return const _BosMiaFeedbackSummary.empty();
    }

    String topRecommendation = 'scale_with_guardrails';
    if (recommendationCounts.isNotEmpty) {
      final List<MapEntry<String, int>> ranked = recommendationCounts.entries
          .toList()
        ..sort((MapEntry<String, int> a, MapEntry<String, int> b) =>
            b.value.compareTo(a.value));
      topRecommendation = ranked.first.key;
    }

    String topIssue = 'telemetry_gaps';
    if (issueCounts.isNotEmpty) {
      final List<MapEntry<String, int>> ranked = issueCounts.entries.toList()
        ..sort((MapEntry<String, int> a, MapEntry<String, int> b) =>
            b.value.compareTo(a.value));
      topIssue = ranked.first.key;
    }

    return _BosMiaFeedbackSummary(
      submissionCount: submissions,
      avgUsability: usabilityTotal / submissions,
      avgUsefulness: usefulnessTotal / submissions,
      avgReliability: reliabilityTotal / submissions,
      avgVoiceQuality: voiceQualityTotal / submissions,
      topRecommendation: topRecommendation,
      topIssue: topIssue,
    );
  }

  Future<Map<String, String>> _loadUserNames(
    FirestoreService firestoreService,
    List<String> learnerIds,
  ) async {
    final Map<String, String> names = <String, String>{};
    for (int i = 0; i < learnerIds.length; i += 10) {
      final List<String> chunk = learnerIds.sublist(
          i, (i + 10 > learnerIds.length) ? learnerIds.length : i + 10);

      final QuerySnapshot<Map<String, dynamic>> usersByUid =
          await firestoreService.firestore
              .collection('users')
              .where('uid', whereIn: chunk)
              .get();
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in usersByUid.docs) {
        final Map<String, dynamic> data = doc.data();
        final String uid = ((data['uid'] as String?) ?? '').trim();
        final String displayName =
            ((data['displayName'] as String?) ?? '').trim();
        if (uid.isNotEmpty && displayName.isNotEmpty) {
          names[uid] = displayName;
        }
      }

      for (final String learnerId in chunk) {
        if (names.containsKey(learnerId)) continue;
        final DocumentSnapshot<Map<String, dynamic>> userDoc =
            await firestoreService.firestore
                .collection('users')
                .doc(learnerId)
                .get();
        if (userDoc.exists) {
          final Map<String, dynamic>? data = userDoc.data();
          final String displayName =
              ((data?['displayName'] as String?) ?? '').trim();
          if (displayName.isNotEmpty) {
            names[learnerId] = displayName;
          }
        }
      }
    }
    return names;
  }

  FirestoreService? _maybeFirestoreService() {
    try {
      return context.read<FirestoreService>();
    } catch (_) {
      return null;
    }
  }

  DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }
    return null;
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  Map<String, int> _emptyPillarCountMap() {
    return <String, int>{
      for (final CurriculumLegacyFamilyCode code
          in CurriculumLegacyFamilyCode.values)
        curriculumLegacyFamilyStorageLabel(code): 0,
    };
  }

  Map<String, Set<String>> _emptyPillarLearnerMap() {
    return <String, Set<String>>{
      for (final CurriculumLegacyFamilyCode code
          in CurriculumLegacyFamilyCode.values)
        curriculumLegacyFamilyStorageLabel(code): <String>{},
    };
  }

  _PillarAnalyticsData _buildPillarData({
    required String pillar,
    required Map<String, int> missionsByPillar,
    required Map<String, int> attemptsByPillar,
    required Map<String, int> completedByPillar,
    required Map<String, Set<String>> learnersByPillar,
  }) {
    final int missions = missionsByPillar[pillar] ?? 0;
    final int attempts = attemptsByPillar[pillar] ?? 0;
    final int completed = completedByPillar[pillar] ?? 0;
    final int learners = learnersByPillar[pillar]?.length ?? 0;
    final double progress =
        attempts == 0 ? 0 : (completed / attempts).clamp(0, 1);
    return _PillarAnalyticsData(
      pillar: pillar,
      progress: progress,
      learners: learners,
      missions: missions,
    );
  }

  String _pillarLabelFromData(Map<String, dynamic> data) {
    final String direct = ((data['pillar'] as String?) ?? '').trim();
    if (direct.isNotEmpty) {
      return curriculumLegacyFamilyStorageLabelFromAny(direct);
    }
    final String code = ((data['pillarCode'] as String?) ?? '').trim();
    if (code.isNotEmpty) {
      return curriculumLegacyFamilyStorageLabelFromAny(code);
    }
    final List<dynamic> pillarCodes =
        (data['pillarCodes'] as List?) ?? <dynamic>[];
    if (pillarCodes.isNotEmpty) {
      return curriculumLegacyFamilyStorageLabelFromAny(
        pillarCodes.first.toString(),
      );
    }
    return curriculumLegacyFamilyStorageLabel(
      CurriculumLegacyFamilyCode.future_skills,
    );
  }

  String _pillarLabelFromAttempt(Map<String, dynamic> data, String? fallback) {
    final String direct = ((data['pillar'] as String?) ?? '').trim();
    if (direct.isNotEmpty) {
      return curriculumLegacyFamilyStorageLabelFromAny(direct);
    }
    final String code = ((data['pillarCode'] as String?) ?? '').trim();
    if (code.isNotEmpty) {
      return curriculumLegacyFamilyStorageLabelFromAny(code);
    }
    if (fallback != null && fallback.trim().isNotEmpty) {
      return curriculumLegacyFamilyStorageLabelFromAny(fallback);
    }
    return curriculumLegacyFamilyStorageLabel(
      CurriculumLegacyFamilyCode.future_skills,
    );
  }

  IconData _pillarIcon(String pillar) {
    return curriculumLegacyFamilyIcon(
      normalizeCurriculumLegacyFamilyCode(pillar),
    );
  }

  Color _pillarColor(String pillar) {
    return curriculumLegacyFamilyColor(
      normalizeCurriculumLegacyFamilyCode(pillar),
    );
  }
}

class _SiteFilterOption {
  const _SiteFilterOption({required this.id, required this.name});
  final String id;
  final String name;
}

class _SiteComparisonData {
  const _SiteComparisonData({
    required this.siteId,
    required this.name,
    required this.learners,
    required this.attendance,
    required this.engagement,
  });

  final String siteId;
  final String name;
  final int learners;
  final int attendance;
  final int engagement;
}

class _TopPerformerData {
  const _TopPerformerData({
    required this.rank,
    required this.name,
    required this.site,
    required this.reviewedEvidenceCount,
    required this.capabilityUpdates,
    required this.reviewedDays,
    this.latestCapabilityTitle,
    this.latestCapabilityLevel = 0,
  });

  final int rank;
  final String name;
  final String site;
  final int reviewedEvidenceCount;
  final int capabilityUpdates;
  final int reviewedDays;
  final String? latestCapabilityTitle;
  final int latestCapabilityLevel;
}

class _PillarAnalyticsData {
  const _PillarAnalyticsData({
    required this.pillar,
    required this.progress,
    required this.learners,
    required this.missions,
  });

  final String pillar;
  final double progress;
  final int learners;
  final int missions;
}

class _BosMiaFeedbackSummary {
  const _BosMiaFeedbackSummary({
    required this.submissionCount,
    required this.avgUsability,
    required this.avgUsefulness,
    required this.avgReliability,
    required this.avgVoiceQuality,
    required this.topRecommendation,
    required this.topIssue,
  });

  const _BosMiaFeedbackSummary.empty()
      : submissionCount = 0,
        avgUsability = 0,
        avgUsefulness = 0,
        avgReliability = 0,
        avgVoiceQuality = 0,
        topRecommendation = 'scale_with_guardrails',
        topIssue = 'telemetry_gaps';

  final int submissionCount;
  final double avgUsability;
  final double avgUsefulness;
  final double avgReliability;
  final double avgVoiceQuality;
  final String topRecommendation;
  final String topIssue;

  double get avgOverall =>
      (avgUsability + avgUsefulness + avgReliability + avgVoiceQuality) / 4;

  String get topRecommendationLabel {
    switch (topRecommendation) {
      case 'scale_now':
        return 'Scale now';
      case 'hold_and_fix':
        return 'Hold and fix';
      case 'scale_with_guardrails':
      default:
        return 'Scale with guardrails';
    }
  }

  String get topIssueLabel {
    switch (topIssue) {
      case 'over_triggering':
        return 'Over-triggering';
      case 'voice_recognition_misses':
        return 'Voice recognition misses';
      case 'weak_coaching_quality':
        return 'Weak coaching quality';
      case 'low_reengagement':
        return 'Low learner re-engagement';
      case 'telemetry_gaps':
      default:
        return 'Telemetry gaps';
    }
  }
}

class _SyntheticDatasetImportSummary {
  const _SyntheticDatasetImportSummary({
    required this.summaryLabel,
    required this.mode,
    required this.sourcePacks,
    required this.importedAt,
    required this.evidenceRows,
    required this.evaluationFixtures,
    required this.importedCollections,
    required this.interactionEvents,
    required this.portfolioArtifacts,
    required this.syntheticUsers,
    required this.bosMiaTraining,
  });

  factory _SyntheticDatasetImportSummary.fromMap(
    Map<String, dynamic> data,
    DateTime? Function(dynamic value) dateParser,
  ) {
    final Map<String, dynamic> sourceCounts = Map<String, dynamic>.from(
      (data['sourceCounts'] as Map?) ?? <String, dynamic>{},
    );
    final Map<String, dynamic> nativeCounts = Map<String, dynamic>.from(
      (data['nativeCounts'] as Map?) ?? <String, dynamic>{},
    );
    final List<String> sourcePacks =
        ((data['sourcePacks'] as List?) ?? <dynamic>[])
            .map((dynamic value) => value.toString())
            .toList(growable: false);
    return _SyntheticDatasetImportSummary(
      summaryLabel: (data['summaryLabel'] as String?)?.trim().isNotEmpty == true
          ? data['summaryLabel'] as String
          : 'Synthetic import',
      mode: (data['mode'] as String?)?.trim() ?? 'all',
      sourcePacks: sourcePacks,
      importedAt: dateParser(data['importedAt']) ?? DateTime.now(),
      evidenceRows: _readCount(sourceCounts, <String>[
        'fullCoreEvidenceRows',
        'starterBootstrapRows',
        'starterChallengeRows',
      ]),
      evaluationFixtures: _readCount(sourceCounts, <String>[
        'fullSuiteRows',
      ]),
      importedCollections: nativeCounts.length,
      interactionEvents:
          _readCount(nativeCounts, <String>['interactionEvents']),
      portfolioArtifacts: _readCount(nativeCounts, <String>['portfolioItems']),
      syntheticUsers: _readCount(nativeCounts, <String>['users']),
      bosMiaTraining: _BosMiaSyntheticTrainingSummary.fromMap(
        Map<String, dynamic>.from(
          (data['bosMiaTraining'] as Map?) ?? <String, dynamic>{},
        ),
        dateParser,
      ),
    );
  }

  final String summaryLabel;
  final String mode;
  final List<String> sourcePacks;
  final DateTime importedAt;
  final int evidenceRows;
  final int evaluationFixtures;
  final int importedCollections;
  final int interactionEvents;
  final int portfolioArtifacts;
  final int syntheticUsers;
  final _BosMiaSyntheticTrainingSummary? bosMiaTraining;

  String get importedAtDisplay {
    final DateTime local = importedAt.toLocal();
    final String month = local.month.toString().padLeft(2, '0');
    final String day = local.day.toString().padLeft(2, '0');
    final String hour = local.hour.toString().padLeft(2, '0');
    final String minute = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$month-$day $hour:$minute';
  }

  String get modeLabel {
    switch (mode) {
      case 'starter':
        return 'starter';
      case 'full':
        return 'full';
      case 'all':
      default:
        return 'starter + full';
    }
  }

  static int _readCount(Map<String, dynamic> values, List<String> keys) {
    int total = 0;
    for (final String key in keys) {
      final dynamic value = values[key];
      if (value is int) {
        total += value;
      } else if (value is num) {
        total += value.toInt();
      }
    }
    return total;
  }
}

class _BosMiaSyntheticTrainingSummary {
  const _BosMiaSyntheticTrainingSummary({
    required this.modelVersion,
    required this.trainingRunId,
    required this.trainedAt,
    required this.calibratedGradeBands,
    required this.trainingRows,
    required this.goldEvalCases,
    required this.actionAccuracy,
    required this.reviewPrecision,
    required this.reviewRecall,
  });

  static _BosMiaSyntheticTrainingSummary? fromMap(
    Map<String, dynamic> data,
    DateTime? Function(dynamic value) dateParser,
  ) {
    final String modelVersion = (data['modelVersion'] as String?)?.trim() ?? '';
    final String trainingRunId =
        (data['trainingRunId'] as String?)?.trim() ?? '';
    if (modelVersion.isEmpty || trainingRunId.isEmpty) {
      return null;
    }

    return _BosMiaSyntheticTrainingSummary(
      modelVersion: modelVersion,
      trainingRunId: trainingRunId,
      trainedAt: dateParser(data['trainedAt']) ?? DateTime.now(),
      calibratedGradeBands: _readMetricInt(data['calibratedGradeBands']),
      trainingRows: _readMetricInt(data['trainingRows']),
      goldEvalCases: _readMetricInt(data['goldEvalCases']),
      actionAccuracy: _readMetricDouble(data['actionAccuracy']),
      reviewPrecision: _readMetricDouble(data['reviewPrecision']),
      reviewRecall: _readMetricDouble(data['reviewRecall']),
    );
  }

  final String modelVersion;
  final String trainingRunId;
  final DateTime trainedAt;
  final int calibratedGradeBands;
  final int trainingRows;
  final int goldEvalCases;
  final double actionAccuracy;
  final double reviewPrecision;
  final double reviewRecall;
}

int _readMetricInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return 0;
}

double _readMetricDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return 0;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.trend,
    required this.trendUp,
    required this.color,
  });
  final IconData icon;
  final String value;
  final String label;
  final String trend;
  final bool trendUp;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: trendUp
                          ? ScholesaColors.success.withValues(alpha: 0.1)
                          : ScholesaColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          trendUp ? Icons.arrow_upward : Icons.arrow_downward,
                          size: 10,
                          color: trendUp
                              ? ScholesaColors.success
                              : ScholesaColors.error,
                        ),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            trend,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: trendUp
                                  ? ScholesaColors.success
                                  : ScholesaColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _BarColumn extends StatelessWidget {
  const _BarColumn(
      {required this.label, required this.value, required this.color});
  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        Container(
          width: 32,
          height: 100 * value,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
      ],
    );
  }
}

class _PillarAnalyticsRow extends StatelessWidget {
  const _PillarAnalyticsRow({
    required this.icon,
    required this.label,
    required this.progress,
    required this.learners,
    required this.missions,
    required this.color,
  });
  final IconData icon;
  final String label;
  final double progress;
  final int learners;
  final int missions;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: color.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text(
              '$learners',
              style: TextStyle(fontWeight: FontWeight.bold, color: color),
            ),
            Text(
              'learners',
              style: TextStyle(color: Colors.grey[500], fontSize: 10),
            ),
          ],
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text(
              '$missions',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'missions',
              style: TextStyle(color: Colors.grey[500], fontSize: 10),
            ),
          ],
        ),
      ],
    );
  }
}

class _SiteComparisonRow extends StatelessWidget {
  const _SiteComparisonRow({
    required this.name,
    required this.learners,
    required this.attendance,
    required this.engagement,
  });
  final String name;
  final int learners;
  final int attendance;
  final int engagement;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 2,
            child:
                Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Column(
              children: <Widget>[
                Text(
                  '$learners',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Learners',
                  style: TextStyle(color: Colors.grey[500], fontSize: 10),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: <Widget>[
                Text(
                  '$attendance%',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: ScholesaColors.success,
                  ),
                ),
                Text(
                  'Attendance',
                  style: TextStyle(color: Colors.grey[500], fontSize: 10),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: <Widget>[
                Text(
                  '$engagement%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: engagement >= 80
                        ? ScholesaColors.success
                        : ScholesaColors.warning,
                  ),
                ),
                Text(
                  'Engage',
                  style: TextStyle(color: Colors.grey[500], fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopPerformerCard extends StatelessWidget {
  const _TopPerformerCard({
    required this.rank,
    required this.name,
    required this.site,
    required this.reviewedEvidenceCount,
    required this.capabilityUpdates,
    required this.reviewedDays,
    this.latestCapabilityTitle,
    this.latestCapabilityLevel = 0,
  });
  final int rank;
  final String name;
  final String site;
  final int reviewedEvidenceCount;
  final int capabilityUpdates;
  final int reviewedDays;
  final String? latestCapabilityTitle;
  final int latestCapabilityLevel;

  Color get _rankColor {
    switch (rank) {
      case 1:
        return const Color(0xFFFFD700);
      case 2:
        return const Color(0xFFC0C0C0);
      case 3:
        return const Color(0xFFCD7F32);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _rankColor.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '#$rank',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _rankColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    site,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  if (latestCapabilityTitle?.trim().isNotEmpty == true)
                    Text(
                      latestCapabilityLevel > 0
                          ? '$latestCapabilityTitle • Level $latestCapabilityLevel/4'
                          : latestCapabilityTitle!,
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(Icons.fact_check_rounded,
                        size: 14, color: ScholesaColors.futureSkills),
                    const SizedBox(width: 4),
                    Text(
                      '$reviewedEvidenceCount reviewed',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Row(
                  children: <Widget>[
                    Icon(
                      capabilityUpdates > 0
                          ? Icons.workspace_premium_rounded
                          : Icons.calendar_today_rounded,
                      size: 14,
                      color: capabilityUpdates > 0
                          ? ScholesaColors.hq
                          : ScholesaColors.warning,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      capabilityUpdates > 0
                          ? '$capabilityUpdates growth updates'
                          : '$reviewedDays reviewed days',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HqKpiPackSummary {
  const _HqKpiPackSummary({
    required this.id,
    required this.title,
    required this.siteId,
    required this.period,
    required this.recommendation,
    required this.fidelityScore,
    required this.portfolioQualityGrade,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String siteId;
  final String period;
  final String recommendation;
  final double? fidelityScore;
  final String portfolioQualityGrade;
  final DateTime updatedAt;
}

class _HqKpiPackCard extends StatelessWidget {
  const _HqKpiPackCard({required this.pack});

  final _HqKpiPackSummary pack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ScholesaColors.hq.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  pack.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              Text(
                '${pack.updatedAt.month}/${pack.updatedAt.day}',
                style: const TextStyle(color: ScholesaColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _HqPackPill(
                label: pack.siteId,
                color: ScholesaColors.hq,
              ),
              _HqPackPill(
                label: pack.fidelityScore == null
                    ? SharedRoleSurfaceI18n.text(
                        context,
                        'Fidelity unavailable',
                      )
                    : 'fidelity ${(pack.fidelityScore! * 100).toStringAsFixed(0)}%',
                color: ScholesaColors.futureSkills,
              ),
              _HqPackPill(
                label: 'grade ${pack.portfolioQualityGrade}',
                color: ScholesaColors.warning,
              ),
              _HqPackPill(
                label: pack.recommendation,
                color: ScholesaColors.success,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HqPackPill extends StatelessWidget {
  const _HqPackPill({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
