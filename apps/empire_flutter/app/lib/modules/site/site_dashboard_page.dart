import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../auth/app_state.dart';
import '../../services/analytics_service.dart';
import '../../services/export_service.dart';
import '../../services/firestore_service.dart';
import '../../services/telemetry_service.dart';
import '../../services/workflow_bridge_service.dart';
import '../../i18n/site_dashboard_i18n.dart';
import '../../ui/auth/global_session_menu.dart';
import '../../ui/theme/scholesa_theme.dart';

/// Site Dashboard Page - Analytics and overview for site administrators
class SiteDashboardPage extends StatefulWidget {
  const SiteDashboardPage({
    super.key,
    this.sharedPreferences,
    this.kpiPacksLoader,
  });

  final SharedPreferences? sharedPreferences;
  final Future<List<Map<String, dynamic>>> Function(String? siteId, int limit)?
      kpiPacksLoader;

  @override
  State<SiteDashboardPage> createState() => _SiteDashboardPageState();
}

class _SiteDashboardPageState extends State<SiteDashboardPage> {
  static const List<String> _supportedPeriods = <String>[
    'today',
    'week',
    'month',
    'term',
  ];
  String _selectedPeriod = 'week';
  final AnalyticsService _analyticsService = AnalyticsService.instance;
  final WorkflowBridgeService _workflowBridgeService =
      WorkflowBridgeService.instance;
  TelemetryDashboardMetrics? _metrics;
  bool _isLoadingMetrics = true;
  bool _isLoadingKpiPacks = true;
  bool _isLoadingActivities = true;
  String? _metricsError;
  String? _kpiPacksError;
  List<_KpiPackSummary> _kpiPacks = <_KpiPackSummary>[];
  List<_SiteActivity> _activities = <_SiteActivity>[];

  String _t(String input) {
    return SiteDashboardI18n.text(context, input);
  }

  @override
  void initState() {
    super.initState();
    TelemetryService.instance.logEvent(
      event: 'insight.viewed',
      metadata: const <String, dynamic>{
        'surface': 'site_dashboard',
        'insight_type': 'site_overview',
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _restoreSelectedPeriod().then((_) {
        if (!mounted) return;
        _loadMetrics();
        _loadKpiPacks();
      });
      _loadRecentActivity();
    });
  }

  Future<SharedPreferences> _prefs() async {
    return widget.sharedPreferences ?? await SharedPreferences.getInstance();
  }

  String _selectedPeriodPrefsKey() {
    final AppState? appState = _maybeAppState();
    final String userId = appState?.userId?.trim() ?? 'anonymous';
    final String siteId = appState?.activeSiteId?.trim() ?? 'global';
    return 'site_dashboard.selected_period.$userId.$siteId';
  }

  String _normalizeSelectedPeriod(String? raw) {
    final String candidate = (raw ?? '').trim().toLowerCase();
    if (_supportedPeriods.contains(candidate)) {
      return candidate;
    }
    return 'week';
  }

  Future<void> _restoreSelectedPeriod() async {
    try {
      final SharedPreferences prefs = await _prefs();
      final String restored =
          _normalizeSelectedPeriod(prefs.getString(_selectedPeriodPrefsKey()));
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedPeriod = restored;
      });
    } catch (error) {
      debugPrint('Failed to restore site dashboard period: $error');
    }
  }

  Future<void> _setSelectedPeriod(String period) async {
    final String normalized = _normalizeSelectedPeriod(period);
    if (!mounted || normalized == _selectedPeriod) {
      return;
    }
    setState(() {
      _selectedPeriod = normalized;
    });
    try {
      final SharedPreferences prefs = await _prefs();
      await prefs.setString(_selectedPeriodPrefsKey(), normalized);
    } catch (error) {
      debugPrint('Failed to save site dashboard period: $error');
    }
  }

  Future<void> _loadMetrics() async {
    setState(() {
      _isLoadingMetrics = true;
      _metricsError = null;
    });
    try {
      final AppState? appState = _maybeAppState();
      if (appState == null || (appState.activeSiteId ?? '').trim().isEmpty) {
        if (!mounted) return;
        setState(() {
          _metrics = null;
          _isLoadingMetrics = false;
        });
        return;
      }
      final String period = _selectedPeriodToTelemetryPeriod(_selectedPeriod);
      final TelemetryDashboardMetrics metrics =
          await _analyticsService.getTelemetryDashboardMetrics(
        siteId: appState.activeSiteId,
        period: period,
      );
      if (!mounted) return;
      setState(() {
        _metrics = metrics;
        _isLoadingMetrics = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _metricsError = error.toString();
        _isLoadingMetrics = false;
      });
    }
  }

  String _selectedPeriodToTelemetryPeriod(String selectedPeriod) {
    switch (selectedPeriod) {
      case 'today':
      case 'week':
        return 'week';
      case 'month':
        return 'month';
      case 'term':
        return 'quarter';
      default:
        return 'week';
    }
  }

  String _selectedPeriodToKpiPackPeriod(String selectedPeriod) {
    switch (selectedPeriod) {
      case 'term':
        return 'quarter';
      case 'today':
      case 'week':
      case 'month':
      default:
        return 'month';
    }
  }

  Future<void> _loadKpiPacks() async {
    final String? siteId = _maybeAppState()?.activeSiteId;
    if (!mounted) return;
    setState(() {
      _isLoadingKpiPacks = true;
      _kpiPacksError = null;
    });
    final bool hadKpiPacks = _kpiPacks.isNotEmpty;
    try {
      final List<Map<String, dynamic>> rows =
          widget.kpiPacksLoader != null
              ? await widget.kpiPacksLoader!(siteId, 12)
              : await _workflowBridgeService.listKpiPacks(
                  siteId: siteId,
                  limit: 12,
                );
      if (!mounted) return;
      final List<_KpiPackSummary> packs = rows
          .map(
            (Map<String, dynamic> row) => _KpiPackSummary(
              id: _trimmedOrNull(row['id']) ?? '',
              title: _trimmedOrNull(row['title']) ?? _t('KPI Pack'),
              period: _trimmedOrNull(row['period']),
              recommendation: _trimmedOrNull(row['recommendation']),
              status: _trimmedOrNull(row['status']),
              fidelityScore: _readFiniteScore(row['fidelityScore']),
              portfolioQualityGrade:
                  _trimmedOrNull(row['portfolioQualityGrade']),
              generatedAt: WorkflowBridgeService.toDateTime(row['updatedAt']) ??
                  WorkflowBridgeService.toDateTime(row['createdAt']),
            ),
          )
          .toList()
        ..sort((_KpiPackSummary a, _KpiPackSummary b) {
          final DateTime aTime =
              a.generatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final DateTime bTime =
              b.generatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime);
        });
      setState(() {
        _kpiPacks = packs;
        _kpiPacksError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _kpiPacksError = hadKpiPacks
            ? _t('Unable to refresh KPI packs right now. Showing the last successful data.')
            : _t('We could not load KPI packs right now. Retry to check the current state.');
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingKpiPacks = false);
      }
    }
  }

  Future<void> _refreshDashboard() async {
    await Future.wait(<Future<void>>[
      _loadMetrics(),
      _loadKpiPacks(),
      _loadRecentActivity(),
    ]);
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

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isDark = scheme.brightness == Brightness.dark;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              isDark
                  ? scheme.surface
                  : ScholesaColors.site.withValues(alpha: 0.05),
              isDark ? scheme.surfaceContainerLow : scheme.surface,
              isDark
                  ? scheme.surfaceContainer
                  : ScholesaColors.futureSkills.withValues(alpha: 0.03),
            ],
          ),
        ),
        child: CustomScrollView(
          slivers: <Widget>[
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _buildPeriodSelector()),
            SliverToBoxAdapter(child: _buildKeyMetrics()),
            SliverToBoxAdapter(child: _buildKpiPackSection()),
            SliverToBoxAdapter(child: _buildAttendanceChart()),
            SliverToBoxAdapter(child: _buildRecentActivity()),
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
                gradient: ScholesaColors.siteGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: ScholesaColors.site.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.analytics, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _t('Site Dashboard'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: ScholesaColors.site,
                        ),
                  ),
                  Text(
                    _t('Pilot Studio Overview'),
                    style: TextStyle(
                        color: context.schTextSecondary, fontSize: 14),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: _t('Refresh'),
              onPressed: _refreshDashboard,
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ScholesaColors.site.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.refresh_rounded, color: ScholesaColors.site),
              ),
            ),
            IconButton(
              onPressed: _exportReport,
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ScholesaColors.site.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.download, color: ScholesaColors.site),
              ),
            ),
            const SessionMenuButton(
              foregroundColor: ScholesaColors.site,
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: <Widget>[
          _PeriodChip(
            label: _t('Today'),
            isSelected: _selectedPeriod == 'today',
            onTap: () async {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: const <String, dynamic>{
                  'cta': 'site_dashboard_period_today',
                },
              );
              await _setSelectedPeriod('today');
              _loadMetrics();
              _loadKpiPacks();
            },
          ),
          const SizedBox(width: 8),
          _PeriodChip(
            label: _t('This Week'),
            isSelected: _selectedPeriod == 'week',
            onTap: () async {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: const <String, dynamic>{
                  'cta': 'site_dashboard_period_week',
                },
              );
              await _setSelectedPeriod('week');
              _loadMetrics();
              _loadKpiPacks();
            },
          ),
          const SizedBox(width: 8),
          _PeriodChip(
            label: _t('This Month'),
            isSelected: _selectedPeriod == 'month',
            onTap: () async {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: const <String, dynamic>{
                  'cta': 'site_dashboard_period_month',
                },
              );
              await _setSelectedPeriod('month');
              _loadMetrics();
              _loadKpiPacks();
            },
          ),
          const SizedBox(width: 8),
          _PeriodChip(
            label: _t('Term'),
            isSelected: _selectedPeriod == 'term',
            onTap: () async {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: const <String, dynamic>{
                  'cta': 'site_dashboard_period_term',
                },
              );
              await _setSelectedPeriod('term');
              _loadMetrics();
              _loadKpiPacks();
            },
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
        decoration: _dashboardCardDecoration(context),
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
                  label: Text(_t('Generate Pack')),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isLoadingKpiPacks)
              const Center(child: CircularProgressIndicator())
            else if (_kpiPacksError != null && _kpiPacks.isEmpty)
              _buildLoadErrorCard(
                _t('KPI packs are temporarily unavailable'),
                _kpiPacksError!,
              )
            else if (_kpiPacks.isEmpty)
              Text(
                _t('No KPI packs yet'),
                style: TextStyle(color: context.schTextSecondary),
              )
            else ...<Widget>[
              if (_kpiPacksError != null)
                _buildStaleDataBanner(_kpiPacksError!),
              Text(
                _t('Latest KPI pack'),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: context.schTextSecondary,
                ),
              ),
              const SizedBox(height: 8),
              _buildKpiPackCard(_kpiPacks.first),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoadErrorCard(String title, String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _dashboardCardDecoration(context, radius: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: context.schTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(color: context.schTextSecondary),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _loadKpiPacks,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(_t('Retry')),
          ),
        ],
      ),
    );
  }

  Widget _buildStaleDataBanner(String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.warning_amber_rounded, color: Colors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: context.schTextPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiPackCard(_KpiPackSummary pack) {
    final String statusLabel = pack.status ?? _t('Status unavailable');
    final String fidelityLabel = pack.fidelityScore == null
        ? _t('Fidelity Score unavailable')
        : '${_t('Fidelity Score')}: ${(pack.fidelityScore! * 100).toStringAsFixed(0)}%';
    final String portfolioGradeLabel = pack.portfolioQualityGrade == null
        ? _t('Portfolio Grade unavailable')
        : '${_t('Portfolio Grade')}: ${pack.portfolioQualityGrade}';
    final String recommendationLabel = pack.recommendation == null
        ? _t('Recommendation unavailable')
        : '${_t('Recommendation')}: ${pack.recommendation}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ScholesaColors.site.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.12),
        ),
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
              _DashboardPill(
                label: statusLabel,
                color: pack.status == 'generated'
                    ? ScholesaColors.success
                    : ScholesaColors.warning,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _DashboardPill(
                label: fidelityLabel,
                color: ScholesaColors.site,
              ),
              _DashboardPill(
                label: portfolioGradeLabel,
                color: ScholesaColors.futureSkills,
              ),
              _DashboardPill(
                label: recommendationLabel,
                color: ScholesaColors.warning,
              ),
            ],
          ),
          if (pack.generatedAt != null) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              pack.period == null
                  ? _formatShortDateTime(pack.generatedAt!)
                  : '${pack.period} • ${_formatShortDateTime(pack.generatedAt!)}',
              style: TextStyle(color: context.schTextSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildKeyMetrics() {
    if (_isLoadingMetrics) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: CircularProgressIndicator(color: ScholesaColors.site),
        ),
      );
    }

    if (_metricsError != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ScholesaColors.error.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${_t('Unable to load telemetry metrics:')} $_metricsError',
            style: const TextStyle(color: ScholesaColors.error),
          ),
        ),
      );
    }

    final TelemetryDashboardMetrics? metrics = _metrics;
    if (metrics == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: _dashboardCardDecoration(context, radius: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                _t('Telemetry KPIs'),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: context.schTextPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _t('Waiting for first app telemetry sync.'),
                style: TextStyle(color: context.schTextSecondary),
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
                  trend: '7-day',
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
                  color: ScholesaColors.site,
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

  Widget _buildAttendanceChart() {
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
        decoration: _dashboardCardDecoration(context),
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
                height: 120,
                child: Center(
                  child: CircularProgressIndicator(color: ScholesaColors.site),
                ),
              ),
            if (!_isLoadingMetrics && _metricsError != null)
              SizedBox(
                height: 120,
                child: Center(
                  child: Text(
                    _t('Attendance data unavailable'),
                    style: TextStyle(color: context.schTextSecondary),
                  ),
                ),
              ),
            if (!_isLoadingMetrics && _metricsError == null && trend.isEmpty)
              SizedBox(
                height: 120,
                child: Center(
                  child: Text(
                    _t('No attendance telemetry for this period'),
                    style: TextStyle(color: context.schTextSecondary),
                  ),
                ),
              ),
            if (!_isLoadingMetrics &&
                _metricsError == null &&
                attendanceRateUnavailable)
              SizedBox(
                height: 120,
                child: Center(
                  child: Text(
                    _t('Attendance rate unavailable for this period'),
                    style: TextStyle(color: context.schTextSecondary),
                  ),
                ),
              ),
            if (!_isLoadingMetrics &&
                _metricsError == null &&
                usableTrend.isNotEmpty)
              SizedBox(
                height: 120,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: usableTrend.map((AttendanceTrendPoint point) {
                    final double rate =
                        (point.presentRate!.toDouble() / 100).clamp(0.0, 1.0);
                    return _BarColumn(
                      label: _shortDateLabel(point.date),
                      value: rate,
                    );
                  }).toList(),
                ),
              ),
            if (!_isLoadingMetrics &&
                _metricsError == null &&
                latestRate != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${_t('Latest attendance:')} ${latestRate.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: context.schTextSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                _t('Recent Activity'),
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              TextButton(
                onPressed: _showAllRecentActivity,
                child: Text(_t('View All')),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_isLoadingActivities)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  _t('Loading...'),
                  style: TextStyle(color: context.schTextSecondary),
                ),
              ),
            ),
          if (!_isLoadingActivities && _activities.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  _t('No recent activity yet'),
                  style: TextStyle(color: context.schTextSecondary),
                ),
              ),
            ),
          ..._activities.map(
            (_SiteActivity activity) => _ActivityItem(
              icon: activity.icon,
              title: _t(activity.title),
              subtitle: _t(activity.subtitle),
              time: _t(activity.time),
              color: activity.color,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generateKpiPack() async {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'cta': 'site_dashboard_generate_kpi_pack',
        'period': _selectedPeriod,
      },
    );
    try {
      final String? siteId = _maybeAppState()?.activeSiteId;
      await _workflowBridgeService.generateKpiPack(
        siteId: siteId,
        period: _selectedPeriodToKpiPackPeriod(_selectedPeriod),
      );
      await _loadKpiPacks();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_t('KPI Packs')}: ${_t('Generate')} ${_selectedPeriodToKpiPackPeriod(_selectedPeriod)}',
          ),
          backgroundColor: ScholesaColors.site,
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

  String _shortDateLabel(String rawDate) {
    final DateTime? date = DateTime.tryParse(rawDate);
    if (date == null) return rawDate;
    return '${date.month}/${date.day}';
  }

  Future<void> _exportReport() async {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'cta': 'site_dashboard_export_report',
        'period': _selectedPeriod,
      },
    );
    if (!_hasExportableReportData()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('No site dashboard data to export yet.')),
        ),
      );
      return;
    }
    final String fileName = _siteReportFileName();
    final String reportContent = _buildSiteReportExport();
    try {
      final String? savedLocation = await ExportService.instance.saveTextFile(
        fileName: fileName,
        content: reportContent,
      );
      if (savedLocation == null || !mounted) {
        return;
      }
      TelemetryService.instance.logEvent(
        event: 'export.downloaded',
        metadata: <String, dynamic>{
          'surface': 'site_dashboard',
          'period': _selectedPeriod,
          'file_name': fileName,
        },
      );
      await _persistReportGeneratedEvent(
        fileName: fileName,
        status: 'downloaded',
      );
    } on UnsupportedError catch (error) {
      debugPrint(
          'Export unsupported for site dashboard report, copying report instead: $error');
      await Clipboard.setData(ClipboardData(text: reportContent));
      TelemetryService.instance.logEvent(
        event: 'site.report_export.copied',
        metadata: <String, dynamic>{
          'surface': 'site_dashboard',
          'period': _selectedPeriod,
          'file_name': fileName,
          'fallback': 'clipboard',
        },
      );
      await _persistReportGeneratedEvent(
        fileName: fileName,
        status: 'copied',
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('Unable to export site report right now.')),
          backgroundColor: ScholesaColors.error,
        ),
      );
    }
  }

  bool _hasExportableReportData() {
    return _metrics != null || _kpiPacks.isNotEmpty || _activities.isNotEmpty;
  }

  String _siteReportFileName() {
    final String siteSegment =
        (_maybeAppState()?.activeSiteId ?? 'site-dashboard').trim();
    final String normalizedSite =
        siteSegment.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    final String dateSegment =
        DateTime.now().toIso8601String().split('T').first;
    return '$normalizedSite-site-dashboard-$_selectedPeriod-$dateSegment.txt';
  }

  String _buildSiteReportExport() {
    final AppState? appState = _maybeAppState();
    final String siteId =
        (appState?.activeSiteId ?? '').trim().isNotEmpty ? appState!.activeSiteId!.trim() : _t('Site unavailable');
    final StringBuffer buffer = StringBuffer()
      ..writeln(_t('Export Site Report'))
      ..writeln('Generated: ${DateTime.now().toIso8601String()}')
      ..writeln('Site: $siteId')
      ..writeln('Period: $_selectedPeriod')
      ..writeln('')
      ..writeln('Telemetry Metrics')
      ..writeln('----------------');

    final TelemetryDashboardMetrics? metrics = _metrics;
    if (metrics == null) {
      buffer.writeln(_metricsError ?? _t('No site dashboard data to export yet.'));
    } else {
      buffer.writeln(
        'Weekly accountability adherence: '
        '${metrics.weeklyAccountabilityAdherenceRate.toStringAsFixed(1)}%',
      );
      buffer.writeln(
        'Educator review turnaround: '
        '${metrics.educatorReviewTurnaroundHoursAvg?.toStringAsFixed(1) ?? 'n/a'} hours',
      );
      buffer.writeln(
        'Educator SLA within rate: '
        '${metrics.educatorReviewWithinSlaRate?.toStringAsFixed(1) ?? 'n/a'}%',
      );
      buffer.writeln(
        'Intervention helped rate: '
        '${metrics.interventionHelpedRate?.toStringAsFixed(1) ?? 'n/a'}%',
      );
      buffer.writeln('Intervention total: ${metrics.interventionTotal}');
      if (metrics.attendanceTrend.isNotEmpty) {
        buffer
          ..writeln('')
          ..writeln('Attendance Trend')
          ..writeln('----------------');
        for (final AttendanceTrendPoint point in metrics.attendanceTrend) {
          buffer.writeln(
            '${point.date} | records=${point.records} | events=${point.events} | presentRate=${point.presentRate?.toStringAsFixed(1) ?? 'n/a'}',
          );
        }
      }
    }

    buffer
      ..writeln('')
      ..writeln('KPI Packs')
      ..writeln('---------');
    if (_kpiPacks.isEmpty) {
      buffer.writeln(_t('No KPI packs yet'));
    } else {
      for (final _KpiPackSummary pack in _kpiPacks) {
        buffer.writeln(
          '${pack.title} | period=${pack.period ?? '-'} | status=${pack.status ?? '-'} | recommendation=${pack.recommendation ?? '-'} | fidelity=${pack.fidelityScore?.toStringAsFixed(2) ?? '-'} | generatedAt=${pack.generatedAt?.toIso8601String() ?? '-'}',
        );
      }
    }

    buffer
      ..writeln('')
      ..writeln('Recent Activity')
      ..writeln('---------------');
    if (_activities.isEmpty) {
      buffer.writeln(_t('No recent activity yet'));
    } else {
      for (final _SiteActivity activity in _activities) {
        buffer.writeln(
          '${activity.time} | ${activity.title} | ${activity.subtitle}',
        );
      }
    }

    return buffer.toString().trim();
  }

  Future<void> _showAllRecentActivity() async {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: const <String, dynamic>{
        'cta': 'site_dashboard_view_all_recent_activity'
      },
    );
    TelemetryService.instance.logEvent(
      event: 'popup.shown',
      metadata: const <String, dynamic>{
        'popup_id': 'site_dashboard_recent_activity',
        'surface': 'site_dashboard',
      },
    );
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                _t('All Recent Activity'),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            if (_activities.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  _t('No recent activity yet'),
                  style: TextStyle(color: context.schTextSecondary),
                ),
              ),
            ..._activities.map(
              (_SiteActivity activity) => _ActivityItem(
                icon: activity.icon,
                title: _t(activity.title),
                subtitle: _t(activity.subtitle),
                time: _t(activity.time),
                color: activity.color,
              ),
            ),
          ],
        ),
      ),
    );
    TelemetryService.instance.logEvent(
      event: 'popup.dismissed',
      metadata: const <String, dynamic>{
        'popup_id': 'site_dashboard_recent_activity',
        'surface': 'site_dashboard',
        'reason': 'closed_without_action',
      },
    );
  }

  BoxDecoration _dashboardCardDecoration(
    BuildContext context, {
    double radius = 20,
  }) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return BoxDecoration(
      color: context.schSurfaceStrong,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: scheme.outline.withValues(alpha: 0.18)),
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  Future<void> _persistReportGeneratedEvent({
    required String fileName,
    required String status,
  }) async {
    final AppState? appState = _maybeAppState();
    final FirestoreService? firestoreService = _maybeFirestoreService();
    final bool copied = status == 'copied';
    final String activitySubtitle = copied
        ? '${_selectedPeriod[0].toUpperCase()}${_selectedPeriod.substring(1)} ${_t('report export copied')}'
        : '${_selectedPeriod[0].toUpperCase()}${_selectedPeriod.substring(1)} ${_t('report export downloaded')}';
    final String snackbarMessage =
        copied ? _t('Site report copied for sharing.') : _t('Site report exported.');

    if (appState == null || firestoreService == null) {
      if (!mounted) return;
      setState(() {
        _activities.insert(
          0,
          _SiteActivity(
            icon: Icons.download_done,
            title: _t('Site report exported'),
            subtitle: activitySubtitle,
            time: _t('just now'),
            color: ScholesaColors.site,
          ),
        );
        if (_activities.length > 8) {
          _activities.removeLast();
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(snackbarMessage),
          backgroundColor: ScholesaColors.site,
        ),
      );
      return;
    }

    final String siteId = (appState.activeSiteId ??
            (appState.siteIds.isNotEmpty ? appState.siteIds.first : ''))
        .trim();

    if (siteId.isNotEmpty) {
      await firestoreService.firestore.collection('siteOpsEvents').add(
        <String, dynamic>{
          'siteId': siteId,
          'action': 'Export Site Report',
          'period': _selectedPeriod,
          'status': status,
          'fileName': fileName,
          'createdAt': FieldValue.serverTimestamp(),
        },
      );
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(snackbarMessage),
        backgroundColor: ScholesaColors.site,
      ),
    );
    await _loadRecentActivity();
  }

  Future<void> _loadRecentActivity() async {
    final AppState? appState = _maybeAppState();
    final FirestoreService? firestoreService = _maybeFirestoreService();
    if (appState == null || firestoreService == null) {
      if (!mounted) return;
      setState(() {
        _isLoadingActivities = false;
        _activities = <_SiteActivity>[];
      });
      return;
    }

    final String siteId = (appState.activeSiteId ??
            (appState.siteIds.isNotEmpty ? appState.siteIds.first : ''))
        .trim();

    if (!mounted) return;
    setState(() => _isLoadingActivities = true);

    try {
      if (siteId.isEmpty) {
        if (!mounted) return;
        setState(() => _activities = <_SiteActivity>[]);
        return;
      }

      final List<_TimedSiteActivity> feed = <_TimedSiteActivity>[];

      QuerySnapshot<Map<String, dynamic>> incidentsSnap;
      try {
        incidentsSnap = await firestoreService.firestore
            .collection('incidents')
            .where('siteId', isEqualTo: siteId)
            .orderBy('reportedAt', descending: true)
            .limit(20)
            .get();
      } catch (_) {
        incidentsSnap = await firestoreService.firestore
            .collection('incidents')
            .where('siteId', isEqualTo: siteId)
            .limit(20)
            .get();
      }
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in incidentsSnap.docs) {
        final Map<String, dynamic> data = doc.data();
        final DateTime? at = _toDateTime(data['reportedAt']) ??
            _toDateTime(data['createdAt']) ??
            _toDateTime(data['updatedAt']);
        if (at == null) continue;
        final String summary =
            (data['title'] as String?)?.trim().isNotEmpty == true
                ? (data['title'] as String).trim()
                : (data['description'] as String?) ?? _t('Incident reported');
        feed.add(
          _TimedSiteActivity(
            at: at,
            icon: Icons.warning_rounded,
            title: _t('Incident reported'),
            subtitle: summary,
            color: ScholesaColors.warning,
          ),
        );
      }

      QuerySnapshot<Map<String, dynamic>> opsEventSnap;
      try {
        opsEventSnap = await firestoreService.firestore
            .collection('siteOpsEvents')
            .where('siteId', isEqualTo: siteId)
            .orderBy('createdAt', descending: true)
            .limit(30)
            .get();
      } catch (_) {
        opsEventSnap = await firestoreService.firestore
            .collection('siteOpsEvents')
            .where('siteId', isEqualTo: siteId)
            .limit(30)
            .get();
      }
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in opsEventSnap.docs) {
        final Map<String, dynamic> data = doc.data();
        final DateTime? at = _toDateTime(data['createdAt']);
        if (at == null) continue;
        final String action =
            (data['action'] as String?)?.trim() ?? _t('Site operation event');
        final String status = (data['status'] as String?)?.trim() ?? '';
        final ({IconData icon, Color color}) visual =
            _mapActivityVisual(action);
        final String subtitle = action == 'Export Site Report'
          ? '${_selectedPeriod[0].toUpperCase()}${_selectedPeriod.substring(1)} ${status == 'downloaded' ? _t('report export downloaded') : status == 'copied' ? _t('report export copied') : _t('report export request logged')}'
          : _t('Site operation event');
        feed.add(
          _TimedSiteActivity(
            at: at,
            icon: visual.icon,
            title: action,
            subtitle: subtitle,
            color: visual.color,
          ),
        );
      }

      feed.sort(
          (_TimedSiteActivity a, _TimedSiteActivity b) => b.at.compareTo(a.at));
      final List<_SiteActivity> activities = feed
          .take(8)
          .map(
            (_TimedSiteActivity item) => _SiteActivity(
              icon: item.icon,
              title: item.title,
              subtitle: item.subtitle,
              time: _relativeTimeLabel(item.at),
              color: item.color,
            ),
          )
          .toList();

      if (!mounted) return;
      setState(() => _activities = activities);
    } finally {
      if (mounted) {
        setState(() => _isLoadingActivities = false);
      }
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

  String _relativeTimeLabel(DateTime value) {
    final Duration diff = DateTime.now().difference(value);
    if (diff.inMinutes < 1) return _t('just now');
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  ({IconData icon, Color color}) _mapActivityVisual(String action) {
    switch (action) {
      case 'Check-in':
        return (icon: Icons.login_rounded, color: ScholesaColors.success);
      case 'Check-out':
        return (icon: Icons.logout_rounded, color: ScholesaColors.site);
      case 'Export Site Report':
        return (icon: Icons.download_done, color: ScholesaColors.site);
      default:
        return (icon: Icons.bolt_rounded, color: ScholesaColors.futureSkills);
    }
  }

  AppState? _maybeAppState() {
    try {
      return context.read<AppState>();
    } catch (_) {
      return null;
    }
  }

  FirestoreService? _maybeFirestoreService() {
    try {
      return context.read<FirestoreService>();
    } catch (_) {
      return null;
    }
  }

  String _formatShortDateTime(DateTime value) {
    return '${value.month}/${value.day}/${value.year}';
  }

  String? _trimmedOrNull(dynamic value) {
    if (value is! String) {
      return null;
    }
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

class _TimedSiteActivity {
  const _TimedSiteActivity({
    required this.at,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final DateTime at;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
}

class _KpiPackSummary {
  const _KpiPackSummary({
    required this.id,
    required this.title,
    required this.period,
    required this.recommendation,
    required this.status,
    required this.fidelityScore,
    required this.portfolioQualityGrade,
    this.generatedAt,
  });

  final String id;
  final String title;
  final String? period;
  final String? recommendation;
  final String? status;
  final double? fidelityScore;
  final String? portfolioQualityGrade;
  final DateTime? generatedAt;
}

class _DashboardPill extends StatelessWidget {
  const _DashboardPill({
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

class _SiteActivity {
  const _SiteActivity({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String time;
  final Color color;
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? ScholesaColors.site
              : ScholesaColors.site.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : ScholesaColors.site,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
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
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.schSurfaceStrong,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.18)),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                    Text(
                      trend,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: trendUp
                            ? ScholesaColors.success
                            : ScholesaColors.error,
                      ),
                    ),
                  ],
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
            style: TextStyle(color: context.schTextSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _BarColumn extends StatelessWidget {
  const _BarColumn({required this.label, required this.value});
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        Container(
          width: 32,
          height: 80 * value,
          decoration: BoxDecoration(
            gradient: ScholesaColors.siteGradient,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
        ),
      ],
    );
  }
}

class _ActivityItem extends StatelessWidget {
  const _ActivityItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.color,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final String time;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.schSurfaceStrong,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outline.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                        color: context.schTextSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            Text(
              time,
              style: TextStyle(
                color: context.schTextSecondary.withValues(alpha: 0.72),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
