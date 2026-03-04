import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/app_state.dart';
import '../../services/analytics_service.dart';
import '../../services/firestore_service.dart';
import '../../services/telemetry_service.dart';
import '../../ui/theme/scholesa_theme.dart';

const Map<String, String> _hqAnalyticsEs = <String, String>{
  'Platform Analytics': 'Analítica de la plataforma',
  'Comprehensive performance insights': 'Insights integrales de desempeño',
  'All Sites': 'Todas las sedes',
  'Singapore': 'Singapur',
  'Kuala Lumpur': 'Kuala Lumpur',
  'Jakarta': 'Yakarta',
  'This Week': 'Esta semana',
  'This Month': 'Este mes',
  'This Quarter': 'Este trimestre',
  'This Year': 'Este año',
  'Unable to load telemetry metrics:':
    'No se pudieron cargar las métricas de telemetría:',
  'Telemetry KPIs': 'KPIs de telemetría',
  '7-day': '7 días',
  'Weekly Accountability': 'Responsabilidad semanal',
  'Review SLA': 'SLA de revisión',
  'within SLA': 'dentro del SLA',
  'Avg Review Turnaround': 'Promedio de revisión',
  'hours': 'horas',
  'Interventions Helped': 'Intervenciones efectivas',
  'outcomes': 'resultados',
  'Attendance Trend': 'Tendencia de asistencia',
  'Attendance data unavailable': 'Datos de asistencia no disponibles',
  'No attendance telemetry for this period':
    'No hay telemetría de asistencia para este periodo',
  'Latest attendance:': 'Asistencia más reciente:',
  'Capture attendance records to render this trend.':
    'Registra asistencias para mostrar esta tendencia.',
  'Pillar Performance': 'Desempeño por pilar',
  'Future Skills': 'Habilidades del futuro',
  'Leadership': 'Liderazgo',
  'Impact': 'Impacto',
  'Site Comparison': 'Comparación de sedes',
  'Top Performers': 'Mejor desempeño',
  'View All': 'Ver todo',
  'Export HQ Analytics': 'Exportar analítica HQ',
  'Generate and export the current HQ analytics summary for cross-site review.':
    'Genera y exporta el resumen actual de analítica HQ para revisión entre sedes.',
  'Loading...': 'Cargando...',
  'No comparison data available': 'No hay datos de comparación disponibles',
  'No top performers available': 'No hay mejores desempeños disponibles',
  'Cancel': 'Cancelar',
  'BOS-MIA Feedback': 'Feedback de BOS-MIA',
  'Rate real-world BOS-MIA usability':
      'Califica la usabilidad real de BOS-MIA',
  'Usability': 'Usabilidad',
  'Usefulness': 'Utilidad',
  'Reliability': 'Confiabilidad',
  'Voice quality': 'Calidad de voz',
  'Rollout recommendation': 'Recomendación de despliegue',
  'Scale now': 'Escalar ahora',
  'Scale with guardrails': 'Escalar con guardrails',
  'Hold and fix': 'Pausar y corregir',
  'Top issues observed': 'Principales issues observados',
  'Over-triggering': 'Sobre-activación',
  'Voice recognition misses': 'Fallas de reconocimiento de voz',
  'Weak coaching quality': 'Calidad de coaching débil',
  'Low learner re-engagement': 'Baja reactivación del learner',
  'Telemetry gaps': 'Brechas de telemetría',
  'Submit feedback': 'Enviar feedback',
  'HQ feedback submitted': 'Feedback de HQ enviado',
  'HQ BOS-MIA Usability': 'Usabilidad BOS-MIA (HQ)',
  'Real-world HQ feedback (14-day)': 'Feedback real de HQ (14 días)',
  'No HQ feedback submissions yet': 'Aún no hay feedback de HQ',
  'submissions': 'envíos',
  'Top recommendation': 'Recomendación principal',
  'Most reported issue': 'Issue más reportado',
  'HQ analytics report prepared for export':
    'Reporte de analítica HQ preparado para exportar',
  'Export': 'Exportar',
};

/// HQ Analytics Page - Platform-wide analytics and insights
class HqAnalyticsPage extends StatefulWidget {
  const HqAnalyticsPage({super.key});

  @override
  State<HqAnalyticsPage> createState() => _HqAnalyticsPageState();
}

class _HqAnalyticsPageState extends State<HqAnalyticsPage> {
  String _selectedPeriod = 'month';
  String _selectedSite = 'all';
  final AnalyticsService _analyticsService = AnalyticsService.instance;
  TelemetryDashboardMetrics? _metrics;
  bool _isLoadingMetrics = true;
  bool _isLoadingSupplemental = true;
  String? _metricsError;
  List<_SiteFilterOption> _siteOptions = <_SiteFilterOption>[
    const _SiteFilterOption(id: 'all', name: 'All Sites'),
  ];
  List<_PillarAnalyticsData> _pillarAnalyticsData = <_PillarAnalyticsData>[];
  List<_SiteComparisonData> _siteComparisonData = <_SiteComparisonData>[];
  List<_TopPerformerData> _topPerformersData = <_TopPerformerData>[];
  _BosMiaFeedbackSummary? _bosMiaFeedbackSummary;
  int _usabilityScore = 4;
  int _usefulnessScore = 4;
  int _reliabilityScore = 4;
  int _voiceQualityScore = 4;
  String _rolloutRecommendation = 'scale_with_guardrails';
  Set<String> _topIssues = <String>{};

  String _t(String input) {
    final String locale = Localizations.localeOf(context).languageCode;
    if (locale != 'es') return input;
    return _hqAnalyticsEs[input] ?? input;
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
      final TelemetryDashboardMetrics metrics =
          await _analyticsService.getTelemetryDashboardMetrics(
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
        _metricsError = error.toString();
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
              onPressed: _openBosMiaFeedbackDialog,
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ScholesaColors.futureSkills.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.rate_review, color: ScholesaColors.futureSkills),
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
                      child: Text(option.id == 'all' ? _t('All Sites') : option.name),
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
      return const SizedBox.shrink();
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
                  label: '${_t('Review SLA')} (${metrics.educatorReviewSlaHours}h)',
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

  Widget _buildGrowthChart() {
    final TelemetryDashboardMetrics? metrics = _metrics;
    final List<AttendanceTrendPoint> allTrend =
        metrics?.attendanceTrend ?? const <AttendanceTrendPoint>[];
    final List<AttendanceTrendPoint> trend =
        allTrend.length > 7 ? allTrend.sublist(allTrend.length - 7) : allTrend;
    final double latestRate =
        trend.isNotEmpty ? (trend.last.presentRate ?? 0) : 0;
    final double previousRate = trend.length > 1
        ? (trend[trend.length - 2].presentRate ?? 0)
        : latestRate;
    final double delta = latestRate - previousRate;
    final bool trendUp = delta >= 0;

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
            else if (_metricsError != null)
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
            else
              SizedBox(
                height: 150,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: trend.map((AttendanceTrendPoint point) {
                    final double rate =
                        ((point.presentRate ?? 0) / 100).clamp(0.0, 1.0);
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
                trend.isNotEmpty) ...<Widget>[
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
            if (_metricsError != null)
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

  Widget _buildBosMiaFeedbackSummaryCard() {
    if (_isLoadingSupplemental) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Center(child: CircularProgressIndicator(color: ScholesaColors.hq)),
      );
    }

    final _BosMiaFeedbackSummary? summary = _bosMiaFeedbackSummary;
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
                _t('HQ BOS-MIA Usability'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
            Text(
              _t('HQ BOS-MIA Usability'),
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
    final List<_PillarAnalyticsData> data = _pillarAnalyticsData;
    final List<_PillarAnalyticsData> fallback = <_PillarAnalyticsData>[
      const _PillarAnalyticsData(
        pillar: 'Future Skills',
        progress: 0,
        learners: 0,
        missions: 0,
      ),
      const _PillarAnalyticsData(
        pillar: 'Leadership',
        progress: 0,
        learners: 0,
        missions: 0,
      ),
      const _PillarAnalyticsData(
        pillar: 'Impact',
        progress: 0,
        learners: 0,
        missions: 0,
      ),
    ];
    final List<_PillarAnalyticsData> rows =
        data.isEmpty ? fallback : data;

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
            Text(
              _t('Pillar Performance'),
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 20),
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
                for (int index = 0; index < _siteComparisonData.length; index++) ...<Widget>[
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
              missionsCompleted: performer.missionsCompleted,
              streak: performer.streak,
            ),
          ),
        ],
      ),
    );
  }

  void _exportReport() {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'cta': 'hq_analytics_export_report',
        'site': _selectedSite,
        'period': _selectedPeriod,
      },
    );
    TelemetryService.instance.logEvent(
      event: 'popup.shown',
      metadata: <String, dynamic>{
        'popup_id': 'hq_analytics_export_report',
        'surface': 'hq_analytics_page',
      },
    );
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(_t('Export HQ Analytics')),
        content: Text(
          _t('Generate and export the current HQ analytics summary for cross-site review.'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: const <String, dynamic>{
                  'cta': 'hq_analytics_cancel_export',
                  'surface': 'export_report_dialog',
                },
              );
              TelemetryService.instance.logEvent(
                event: 'popup.dismissed',
                metadata: const <String, dynamic>{
                  'popup_id': 'hq_analytics_export_report',
                  'surface': 'export_report_dialog',
                },
              );
              Navigator.pop(dialogContext);
            },
            child: Text(_t('Cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: const <String, dynamic>{
                  'cta': 'hq_analytics_confirm_export',
                  'surface': 'export_report_dialog',
                },
              );
              TelemetryService.instance.logEvent(
                event: 'popup.completed',
                metadata: const <String, dynamic>{
                  'popup_id': 'hq_analytics_export_report',
                  'surface': 'export_report_dialog',
                  'completion_action': 'export',
                },
              );
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_t('HQ analytics report prepared for export')),
                  backgroundColor: ScholesaColors.hq,
                ),
              );
            },
            child: Text(_t('Export')),
          ),
        ],
      ),
    );
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
          builder: (BuildContext context, void Function(void Function()) setDialogState) {
            return AlertDialog(
              title: Text(_t('BOS-MIA Feedback')),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        _t('Rate real-world BOS-MIA usability'),
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
                          <String, String>{'value': 'scale_now', 'label': _t('Scale now')},
                          <String, String>{
                            'value': 'scale_with_guardrails',
                            'label': _t('Scale with guardrails')
                          },
                          <String, String>{'value': 'hold_and_fix', 'label': _t('Hold and fix')},
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
                          final bool selected = _topIssues.contains(option['value']);
                          return FilterChip(
                            label: Text(option['label']!),
                            selected: selected,
                            onSelected: (bool value) {
                              setDialogState(() {
                                if (value) {
                                  _topIssues = <String>{..._topIssues, option['value']!};
                                } else {
                                  _topIssues = _topIssues
                                      .where((String issue) => issue != option['value'])
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
                  missionsCompleted: performer.missionsCompleted,
                  streak: performer.streak,
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
    final FirestoreService? firestoreService = _maybeFirestoreService();
    if (firestoreService == null) {
      if (!mounted) return;
      setState(() {
        _isLoadingSupplemental = false;
        _siteOptions = <_SiteFilterOption>[const _SiteFilterOption(id: 'all', name: 'All Sites')];
        _pillarAnalyticsData = <_PillarAnalyticsData>[];
        _siteComparisonData = <_SiteComparisonData>[];
        _topPerformersData = <_TopPerformerData>[];
      });
      return;
    }

    if (!mounted) return;
    setState(() => _isLoadingSupplemental = true);

    try {
      final QuerySnapshot<Map<String, dynamic>> sitesSnapshot =
          await firestoreService.firestore.collection('sites').limit(300).get();

      final Map<String, String> siteNames = <String, String>{};
      final List<_SiteComparisonData> comparison = <_SiteComparisonData>[];
      final List<_SiteFilterOption> options = <_SiteFilterOption>[
        const _SiteFilterOption(id: 'all', name: 'All Sites'),
      ];

      final QuerySnapshot<Map<String, dynamic>> missionsSnapshot =
          await firestoreService.firestore.collection('missions').limit(500).get();

      final Map<String, String> missionPillarById = <String, String>{};
      final Map<String, int> missionsByPillar = <String, int>{
        'Future Skills': 0,
        'Leadership': 0,
        'Impact': 0,
      };

      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in missionsSnapshot.docs) {
        final Map<String, dynamic> data = doc.data();
        final String siteId = ((data['siteId'] as String?) ?? '').trim();
        if (_selectedSite != 'all' && siteId.isNotEmpty && siteId != _selectedSite) {
          continue;
        }
        final String pillar = _pillarLabelFromData(data);
        missionPillarById[doc.id] = pillar;
        missionsByPillar[pillar] = (missionsByPillar[pillar] ?? 0) + 1;
      }

      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in sitesSnapshot.docs) {
        final Map<String, dynamic> data = doc.data();
        final String name =
            (data['name'] as String?)?.trim().isNotEmpty == true
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
        final int engagement =
            (learners == 0 ? 0 : ((educators * 100) ~/ (learners == 0 ? 1 : learners)) * 5)
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
      final List<_SiteComparisonData> comparisonTop = comparison.take(3).toList();

      Query<Map<String, dynamic>> attemptsQuery =
          firestoreService.firestore.collection('missionAttempts');
      if (_selectedSite != 'all') {
        attemptsQuery = attemptsQuery.where('siteId', isEqualTo: _selectedSite);
      }
      final QuerySnapshot<Map<String, dynamic>> attemptsSnapshot =
          await attemptsQuery.limit(500).get();

      final Map<String, int> attemptsByLearner = <String, int>{};
      final Map<String, String> learnerSite = <String, String>{};
      final Map<String, Set<String>> learnerDays = <String, Set<String>>{};
      final Map<String, int> attemptsByPillar = <String, int>{
        'Future Skills': 0,
        'Leadership': 0,
        'Impact': 0,
      };
      final Map<String, int> completedByPillar = <String, int>{
        'Future Skills': 0,
        'Leadership': 0,
        'Impact': 0,
      };
      final Map<String, Set<String>> learnersByPillar = <String, Set<String>>{
        'Future Skills': <String>{},
        'Leadership': <String>{},
        'Impact': <String>{},
      };

      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in attemptsSnapshot.docs) {
        final Map<String, dynamic> data = doc.data();
        final String learnerId = ((data['learnerId'] as String?) ?? '').trim();
        if (learnerId.isEmpty) continue;

        attemptsByLearner[learnerId] = (attemptsByLearner[learnerId] ?? 0) + 1;
        final String siteId = ((data['siteId'] as String?) ?? '').trim();
        if (siteId.isNotEmpty) learnerSite[learnerId] = siteId;

        final DateTime? createdAt = _toDateTime(data['createdAt']) ?? _toDateTime(data['submittedAt']);
        if (createdAt != null) {
          final String dayKey = '${createdAt.year}-${createdAt.month}-${createdAt.day}';
          learnerDays.putIfAbsent(learnerId, () => <String>{}).add(dayKey);
        }

        final String missionId = ((data['missionId'] as String?) ?? '').trim();
        final String pillar = _pillarLabelFromAttempt(data, missionPillarById[missionId]);
        attemptsByPillar[pillar] = (attemptsByPillar[pillar] ?? 0) + 1;
        learnersByPillar.putIfAbsent(pillar, () => <String>{}).add(learnerId);
        final String status = ((data['status'] as String?) ?? '').toLowerCase();
        final bool completed = status == 'completed' ||
            status == 'passed' ||
            status == 'mastered' ||
            status == 'done';
        if (completed) {
          completedByPillar[pillar] = (completedByPillar[pillar] ?? 0) + 1;
        }
      }

      final List<_PillarAnalyticsData> pillarData = <_PillarAnalyticsData>[
        _buildPillarData(
          pillar: 'Future Skills',
          missionsByPillar: missionsByPillar,
          attemptsByPillar: attemptsByPillar,
          completedByPillar: completedByPillar,
          learnersByPillar: learnersByPillar,
        ),
        _buildPillarData(
          pillar: 'Leadership',
          missionsByPillar: missionsByPillar,
          attemptsByPillar: attemptsByPillar,
          completedByPillar: completedByPillar,
          learnersByPillar: learnersByPillar,
        ),
        _buildPillarData(
          pillar: 'Impact',
          missionsByPillar: missionsByPillar,
          attemptsByPillar: attemptsByPillar,
          completedByPillar: completedByPillar,
          learnersByPillar: learnersByPillar,
        ),
      ];

      final List<MapEntry<String, int>> ranked = attemptsByLearner.entries.toList()
        ..sort((MapEntry<String, int> a, MapEntry<String, int> b) => b.value.compareTo(a.value));
      final List<String> topLearnerIds = ranked.take(10).map((MapEntry<String, int> entry) => entry.key).toList();
      final Map<String, String> learnerNames = await _loadUserNames(firestoreService, topLearnerIds);

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
            missionsCompleted: ranked[index].value,
            streak: streak,
          ),
        );
      }

      Query<Map<String, dynamic>> feedbackQuery = firestoreService
          .firestore
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
        if (!_siteOptions.any((_SiteFilterOption option) => option.id == _selectedSite)) {
          _selectedSite = 'all';
        }
        _pillarAnalyticsData = pillarData;
        _siteComparisonData = comparisonTop;
        _topPerformersData = performers;
        _bosMiaFeedbackSummary = summary;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pillarAnalyticsData = <_PillarAnalyticsData>[];
        _siteComparisonData = <_SiteComparisonData>[];
        _topPerformersData = <_TopPerformerData>[];
        _bosMiaFeedbackSummary = null;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingSupplemental = false);
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

      final int usability = (_asInt(metadata['usability_score']) ?? 0).clamp(1, 5);
      final int usefulness = (_asInt(metadata['usefulness_score']) ?? 0).clamp(1, 5);
      final int reliability = (_asInt(metadata['reliability_score']) ?? 0).clamp(1, 5);
      final int voiceQuality = (_asInt(metadata['voice_quality_score']) ?? 0).clamp(1, 5);
      if (usability == 0 || usefulness == 0 || reliability == 0 || voiceQuality == 0) {
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

      final List<dynamic> issues = (metadata['top_issues'] as List?) ?? <dynamic>[];
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
      final List<MapEntry<String, int>> ranked = recommendationCounts.entries.toList()
        ..sort((MapEntry<String, int> a, MapEntry<String, int> b) => b.value.compareTo(a.value));
      topRecommendation = ranked.first.key;
    }

    String topIssue = 'telemetry_gaps';
    if (issueCounts.isNotEmpty) {
      final List<MapEntry<String, int>> ranked = issueCounts.entries.toList()
        ..sort((MapEntry<String, int> a, MapEntry<String, int> b) => b.value.compareTo(a.value));
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

      final QuerySnapshot<Map<String, dynamic>> usersByUid = await firestoreService
          .firestore
          .collection('users')
          .where('uid', whereIn: chunk)
          .get();
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in usersByUid.docs) {
        final Map<String, dynamic> data = doc.data();
        final String uid = ((data['uid'] as String?) ?? '').trim();
        final String displayName = ((data['displayName'] as String?) ?? '').trim();
        if (uid.isNotEmpty && displayName.isNotEmpty) {
          names[uid] = displayName;
        }
      }

      for (final String learnerId in chunk) {
        if (names.containsKey(learnerId)) continue;
        final DocumentSnapshot<Map<String, dynamic>> userDoc =
            await firestoreService.firestore.collection('users').doc(learnerId).get();
        if (userDoc.exists) {
          final Map<String, dynamic>? data = userDoc.data();
          final String displayName = ((data?['displayName'] as String?) ?? '').trim();
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
    final double progress = attempts == 0 ? 0 : (completed / attempts).clamp(0, 1);
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
      return _normalizePillarLabel(direct);
    }
    final String code = ((data['pillarCode'] as String?) ?? '').trim();
    if (code.isNotEmpty) {
      return _normalizePillarLabel(code);
    }
    final List<dynamic> pillarCodes = (data['pillarCodes'] as List?) ?? <dynamic>[];
    if (pillarCodes.isNotEmpty) {
      return _normalizePillarLabel(pillarCodes.first.toString());
    }
    return 'Future Skills';
  }

  String _pillarLabelFromAttempt(Map<String, dynamic> data, String? fallback) {
    final String direct = ((data['pillar'] as String?) ?? '').trim();
    if (direct.isNotEmpty) {
      return _normalizePillarLabel(direct);
    }
    final String code = ((data['pillarCode'] as String?) ?? '').trim();
    if (code.isNotEmpty) {
      return _normalizePillarLabel(code);
    }
    if (fallback != null && fallback.trim().isNotEmpty) {
      return _normalizePillarLabel(fallback);
    }
    return 'Future Skills';
  }

  String _normalizePillarLabel(String raw) {
    final String normalized = raw.trim().toLowerCase();
    if (normalized.contains('future')) return 'Future Skills';
    if (normalized.contains('leadership')) return 'Leadership';
    if (normalized.contains('impact')) return 'Impact';
    return 'Future Skills';
  }

  IconData _pillarIcon(String pillar) {
    switch (_normalizePillarLabel(pillar)) {
      case 'Leadership':
        return Icons.emoji_events;
      case 'Impact':
        return Icons.eco;
      case 'Future Skills':
      default:
        return Icons.code;
    }
  }

  Color _pillarColor(String pillar) {
    switch (_normalizePillarLabel(pillar)) {
      case 'Leadership':
        return ScholesaColors.leadership;
      case 'Impact':
        return ScholesaColors.impact;
      case 'Future Skills':
      default:
        return ScholesaColors.futureSkills;
    }
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
    required this.missionsCompleted,
    required this.streak,
  });

  final int rank;
  final String name;
  final String site;
  final int missionsCompleted;
  final int streak;
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
    required this.missionsCompleted,
    required this.streak,
  });
  final int rank;
  final String name;
  final String site;
  final int missionsCompleted;
  final int streak;

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
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(Icons.rocket_launch,
                        size: 14, color: ScholesaColors.futureSkills),
                    const SizedBox(width: 4),
                    Text(
                      '$missionsCompleted',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Row(
                  children: <Widget>[
                    const Icon(Icons.local_fire_department,
                        size: 14, color: ScholesaColors.warning),
                    const SizedBox(width: 4),
                    Text(
                      '$streak days',
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
