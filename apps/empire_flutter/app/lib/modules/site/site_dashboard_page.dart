import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../auth/app_state.dart';
import '../../services/analytics_service.dart';
import '../../services/firestore_service.dart';
import '../../services/telemetry_service.dart';
import '../../ui/theme/scholesa_theme.dart';

const Map<String, String> _siteDashboardEs = <String, String>{
  'New enrollment': 'Nueva inscripción',
  'Emma Johnson joined AI Explorers':
    'Emma Johnson se unió a Exploradores de IA',
  'Mission completed': 'Misión completada',
  'Liam Chen completed "Build a Robot"':
    'Liam Chen completó "Construye un robot"',
  'Achievement unlocked': 'Logro desbloqueado',
  'Sofia Martinez earned "Code Master" badge':
    'Sofia Martinez obtuvo la insignia "Maestro de código"',
  '2 hours ago': 'Hace 2 horas',
  '4 hours ago': 'Hace 4 horas',
  '6 hours ago': 'Hace 6 horas',
  'Site Dashboard': 'Panel de sede',
  'Pilot Studio Overview': 'Resumen del estudio piloto',
  'Today': 'Hoy',
  'This Week': 'Esta semana',
  'This Month': 'Este mes',
  'Term': 'Periodo',
  'Unable to load telemetry metrics:':
    'No se pudieron cargar las métricas de telemetría:',
  'Telemetry KPIs': 'KPIs de telemetría',
  'Telemetry feed pending': 'Feed de telemetría pendiente',
  'Waiting for first data sync from BOS-MIA telemetry.':
      'Esperando la primera sincronización de datos de telemetría BOS-MIA.',
  'Weekly Accountability': 'Responsabilidad semanal',
  'within SLA': 'dentro del SLA',
  'Avg Review Turnaround': 'Promedio de revisión',
  'Review SLA': 'SLA de revisión',
  'Interventions Helped': 'Intervenciones efectivas',
  'outcomes': 'resultados',
  'Attendance Trend': 'Tendencia de asistencia',
  'Attendance data unavailable': 'Datos de asistencia no disponibles',
  'No attendance telemetry for this period':
    'No hay telemetría de asistencia para este periodo',
  'Latest attendance:': 'Asistencia más reciente:',
  'Pillar Progress (Site Average)': 'Progreso por pilar (promedio del sitio)',
  'Future Skills': 'Habilidades del futuro',
  'Leadership': 'Liderazgo',
  'Impact': 'Impacto',
  'Recent Activity': 'Actividad reciente',
  'View All': 'Ver todo',
  'Export Site Report': 'Exportar reporte del sitio',
  'Generate a': 'Generar un',
  'summary report for this site dashboard.':
    'reporte resumido para este panel del sitio.',
  'Cancel': 'Cancelar',
  'Report generated': 'Reporte generado',
  'report ready for download': 'reporte listo para descargar',
  'just now': 'justo ahora',
  'report prepared for download': 'reporte preparado para descargar',
  'Generate': 'Generar',
  'All Recent Activity': 'Toda la actividad reciente',
  'Loading...': 'Cargando...',
  'No recent activity yet': 'Aún no hay actividad reciente',
  'Incident reported': 'Incidente reportado',
  'Site operation event': 'Evento de operación del sitio',
};

/// Site Dashboard Page - Analytics and overview for site administrators
class SiteDashboardPage extends StatefulWidget {
  const SiteDashboardPage({super.key});

  @override
  State<SiteDashboardPage> createState() => _SiteDashboardPageState();
}

class _SiteDashboardPageState extends State<SiteDashboardPage> {
  String _selectedPeriod = 'week';
  final AnalyticsService _analyticsService = AnalyticsService.instance;
  TelemetryDashboardMetrics? _metrics;
  bool _isLoadingMetrics = true;
  bool _isLoadingActivities = true;
  String? _metricsError;
  List<_SiteActivity> _activities = <_SiteActivity>[];

  String _t(String input) {
    final String locale = Localizations.localeOf(context).languageCode;
    if (locale != 'es') return input;
    return _siteDashboardEs[input] ?? input;
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
    _loadMetrics();
    _loadRecentActivity();
  }

  Future<void> _loadMetrics() async {
    setState(() {
      _isLoadingMetrics = true;
      _metricsError = null;
    });
    try {
      final AppState appState = context.read<AppState>();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              ScholesaColors.site.withValues(alpha: 0.05),
              Colors.white,
              ScholesaColors.futureSkills.withValues(alpha: 0.03),
            ],
          ),
        ),
        child: CustomScrollView(
          slivers: <Widget>[
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _buildPeriodSelector()),
            SliverToBoxAdapter(child: _buildKeyMetrics()),
            SliverToBoxAdapter(child: _buildAttendanceChart()),
            SliverToBoxAdapter(child: _buildPillarBreakdown()),
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
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
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
            onTap: () {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: const <String, dynamic>{
                  'cta': 'site_dashboard_period_today',
                },
              );
              setState(() => _selectedPeriod = 'today');
              _loadMetrics();
            },
          ),
          const SizedBox(width: 8),
          _PeriodChip(
            label: _t('This Week'),
            isSelected: _selectedPeriod == 'week',
            onTap: () {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: const <String, dynamic>{
                  'cta': 'site_dashboard_period_week',
                },
              );
              setState(() => _selectedPeriod = 'week');
              _loadMetrics();
            },
          ),
          const SizedBox(width: 8),
          _PeriodChip(
            label: _t('This Month'),
            isSelected: _selectedPeriod == 'month',
            onTap: () {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: const <String, dynamic>{
                  'cta': 'site_dashboard_period_month',
                },
              );
              setState(() => _selectedPeriod = 'month');
              _loadMetrics();
            },
          ),
          const SizedBox(width: 8),
          _PeriodChip(
            label: _t('Term'),
            isSelected: _selectedPeriod == 'term',
            onTap: () {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: const <String, dynamic>{
                  'cta': 'site_dashboard_period_term',
                },
              );
              setState(() => _selectedPeriod = 'term');
              _loadMetrics();
            },
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
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                _t('Waiting for first data sync from BOS-MIA telemetry.'),
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
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              ),
            if (!_isLoadingMetrics && _metricsError == null && trend.isEmpty)
              SizedBox(
                height: 120,
                child: Center(
                  child: Text(
                    _t('No attendance telemetry for this period'),
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              ),
            if (!_isLoadingMetrics && _metricsError == null && trend.isNotEmpty)
              SizedBox(
                height: 120,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: trend.map((AttendanceTrendPoint point) {
                    final double rate =
                        ((point.presentRate ?? 0) / 100).clamp(0.0, 1.0);
                    return _BarColumn(
                      label: _shortDateLabel(point.date),
                      value: rate,
                    );
                  }).toList(),
                ),
              ),
            if (!_isLoadingMetrics && _metricsError == null && trend.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${_t('Latest attendance:')} ${latestRate.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPillarBreakdown() {
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
              _t('Pillar Progress (Site Average)'),
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 20),
            _PillarProgressRow(
              icon: Icons.code,
              label: _t('Future Skills'),
              progress: 0.72,
              color: ScholesaColors.futureSkills,
            ),
            const SizedBox(height: 16),
            _PillarProgressRow(
              icon: Icons.emoji_events,
              label: _t('Leadership'),
              progress: 0.65,
              color: ScholesaColors.leadership,
            ),
            const SizedBox(height: 16),
            _PillarProgressRow(
              icon: Icons.eco,
              label: _t('Impact'),
              progress: 0.58,
              color: ScholesaColors.impact,
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
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            ),
          if (!_isLoadingActivities && _activities.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  _t('No recent activity yet'),
                  style: TextStyle(color: Colors.grey[600]),
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

  String _shortDateLabel(String rawDate) {
    final DateTime? date = DateTime.tryParse(rawDate);
    if (date == null) return rawDate;
    return '${date.month}/${date.day}';
  }

  void _exportReport() {
    bool popupCompleted = false;
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'cta': 'site_dashboard_export_report',
        'period': _selectedPeriod,
      },
    );
    TelemetryService.instance.logEvent(
      event: 'popup.shown',
      metadata: <String, dynamic>{
        'popup_id': 'site_dashboard_export_report',
        'surface': 'site_dashboard',
      },
    );
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(_t('Export Site Report')),
        content: Text(
          '${_t('Generate a')} $_selectedPeriod ${_t('summary report for this site dashboard.')}',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: const <String, dynamic>{
                  'cta': 'site_dashboard_export_cancel',
                },
              );
              TelemetryService.instance.logEvent(
                event: 'popup.dismissed',
                metadata: const <String, dynamic>{
                  'popup_id': 'site_dashboard_export_report',
                  'surface': 'site_dashboard',
                },
              );
              popupCompleted = true;
              Navigator.pop(dialogContext);
            },
            child: Text(_t('Cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: <String, dynamic>{
                  'cta': 'site_dashboard_generate_report',
                  'period': _selectedPeriod,
                },
              );
              TelemetryService.instance.logEvent(
                event: 'popup.completed',
                metadata: <String, dynamic>{
                  'popup_id': 'site_dashboard_export_report',
                  'surface': 'site_dashboard',
                  'completion_action': 'generate_report',
                  'period': _selectedPeriod,
                },
              );
              popupCompleted = true;
              Navigator.pop(dialogContext);
              _persistReportGeneratedEvent();
            },
            child: Text(_t('Generate')),
          ),
        ],
      ),
    ).then((_) {
      if (popupCompleted) {
        return;
      }
      TelemetryService.instance.logEvent(
        event: 'popup.dismissed',
        metadata: const <String, dynamic>{
          'popup_id': 'site_dashboard_export_report',
          'surface': 'site_dashboard',
          'reason': 'closed_without_action',
        },
      );
    });
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
      backgroundColor: Colors.white,
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

  Future<void> _persistReportGeneratedEvent() async {
    final AppState? appState = _maybeAppState();
    final FirestoreService? firestoreService = _maybeFirestoreService();

    if (appState == null || firestoreService == null) {
      if (!mounted) return;
      setState(() {
        _activities.insert(
          0,
          _SiteActivity(
            icon: Icons.download_done,
            title: _t('Report generated'),
            subtitle:
                '${_selectedPeriod[0].toUpperCase()}${_selectedPeriod.substring(1)} ${_t('report ready for download')}',
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
          content: Text('$_selectedPeriod ${_t('report prepared for download')}'),
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
          'createdAt': FieldValue.serverTimestamp(),
        },
      );
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$_selectedPeriod ${_t('report prepared for download')}'),
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
        _activities = _defaultFallbackActivities();
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
        final String summary = (data['title'] as String?)?.trim().isNotEmpty == true
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
        final String action = (data['action'] as String?)?.trim() ?? _t('Site operation event');
        final ({IconData icon, Color color}) visual = _mapActivityVisual(action);
        final String subtitle = action == 'Export Site Report'
            ? '${_selectedPeriod[0].toUpperCase()}${_selectedPeriod.substring(1)} ${_t('report ready for download')}'
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

      feed.sort((_TimedSiteActivity a, _TimedSiteActivity b) => b.at.compareTo(a.at));
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

  List<_SiteActivity> _defaultFallbackActivities() {
    return <_SiteActivity>[
      _SiteActivity(
        icon: Icons.person_add,
        title: 'New enrollment',
        subtitle: 'Emma Johnson joined AI Explorers',
        time: '2 hours ago',
        color: ScholesaColors.learner,
      ),
      _SiteActivity(
        icon: Icons.check_circle,
        title: 'Mission completed',
        subtitle: 'Liam Chen completed "Build a Robot"',
        time: '4 hours ago',
        color: ScholesaColors.success,
      ),
      _SiteActivity(
        icon: Icons.star,
        title: 'Achievement unlocked',
        subtitle: 'Sofia Martinez earned "Code Master" badge',
        time: '6 hours ago',
        color: ScholesaColors.warning,
      ),
    ];
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
  const _BarColumn({required this.label, required this.value});
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
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
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
      ],
    );
  }
}

class _PillarProgressRow extends StatelessWidget {
  const _PillarProgressRow({
    required this.icon,
    required this.label,
    required this.progress,
    required this.color,
  });
  final IconData icon;
  final String label;
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(label,
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: TextStyle(color: color, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
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
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
            Text(
              time,
              style: TextStyle(color: Colors.grey[400], fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
