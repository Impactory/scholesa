import 'package:flutter/material.dart';
import '../../services/telemetry_service.dart';
import '../../ui/theme/scholesa_theme.dart';

const Map<String, String> _hqSafetyEs = <String, String>{
  'Safety Overview': 'Resumen de seguridad',
  'Open': 'Abiertos',
  'Escalated': 'Escalados',
  'Critical': 'Críticos',
  'Escalated to HQ': 'Escalado a HQ',
  'All Recent Incidents': 'Todos los incidentes recientes',
  'Site': 'Sede',
  'Severity': 'Severidad',
  'Reported': 'Reportado',
  'Yes': 'Sí',
  'No': 'No',
  'Close': 'Cerrar',
  'Opening full incident report...': 'Abriendo informe completo del incidente...',
  'View Full Report': 'Ver informe completo',
  'm ago': 'min atrás',
  'h ago': 'h atrás',
  'd ago': 'd atrás',
  'Medical emergency - handled': 'Emergencia médica - atendida',
  'Minor bump during play': 'Golpe leve durante el juego',
  'Behavioral concern': 'Preocupación conductual',
  'Downtown Studio': 'Estudio Centro',
  'Westside Campus': 'Campus Oeste',
  'minor': 'leve',
  'major': 'grave',
  'critical': 'crítico',
};

String _tHqSafety(BuildContext context, String input) {
  final String locale = Localizations.localeOf(context).languageCode;
  if (locale != 'es') return input;
  return _hqSafetyEs[input] ?? input;
}

/// HQ Safety page for monitoring safety incidents across all sites
/// Based on docs/41_SAFETY_CONSENT_INCIDENTS_SPEC.md
class HqSafetyPage extends StatefulWidget {
  const HqSafetyPage({super.key});

  @override
  State<HqSafetyPage> createState() => _HqSafetyPageState();
}

enum _Severity { minor, major, critical }

class _SafetyIncident {
  const _SafetyIncident({
    required this.id,
    required this.title,
    required this.site,
    required this.severity,
    required this.reportedAt,
    required this.isEscalated,
  });

  final String id;
  final String title;
  final String site;
  final _Severity severity;
  final DateTime reportedAt;
  final bool isEscalated;
}

class _HqSafetyPageState extends State<HqSafetyPage> {
  final List<_SafetyIncident> _incidents = <_SafetyIncident>[
    _SafetyIncident(
      id: '1',
      title: 'Medical emergency - handled',
      site: 'Downtown Studio',
      severity: _Severity.critical,
      reportedAt: DateTime.now().subtract(const Duration(hours: 2)),
      isEscalated: true,
    ),
    _SafetyIncident(
      id: '2',
      title: 'Minor bump during play',
      site: 'Westside Campus',
      severity: _Severity.minor,
      reportedAt: DateTime.now().subtract(const Duration(days: 1)),
      isEscalated: false,
    ),
    _SafetyIncident(
      id: '3',
      title: 'Behavioral concern',
      site: 'Downtown Studio',
      severity: _Severity.major,
      reportedAt: DateTime.now().subtract(const Duration(days: 2)),
      isEscalated: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ScholesaColors.background,
      appBar: AppBar(
        title: Text(_tHqSafety(context, 'Safety Overview')),
        backgroundColor: ScholesaColors.safetyGradient.colors.first,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _buildSafetyMetrics(),
          const SizedBox(height: 24),
          _buildEscalatedSection(),
          const SizedBox(height: 24),
          _buildRecentIncidents(),
        ],
      ),
    );
  }

  Widget _buildSafetyMetrics() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: ScholesaColors.safetyGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: <Widget>[
          _buildMetric(
            _tHqSafety(context, 'Open'),
            _incidents.length.toString(),
            Icons.warning_rounded),
          _buildMetric(
            _tHqSafety(context, 'Escalated'),
              _incidents
                  .where((_SafetyIncident i) => i.isEscalated)
                  .length
                  .toString(),
              Icons.priority_high_rounded),
          _buildMetric(
            _tHqSafety(context, 'Critical'),
              _incidents
                  .where(
                      (_SafetyIncident i) => i.severity == _Severity.critical)
                  .length
                  .toString(),
              Icons.error_rounded),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value, IconData icon) {
    return Column(
      children: <Widget>[
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 8),
        Text(value,
            style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        Text(label,
            style: TextStyle(
                fontSize: 12, color: Colors.white.withValues(alpha: 0.9))),
      ],
    );
  }

  Widget _buildEscalatedSection() {
    final List<_SafetyIncident> escalated =
        _incidents.where((_SafetyIncident i) => i.isEscalated).toList();
    if (escalated.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(Icons.priority_high_rounded,
                color: Colors.red.shade700, size: 20),
            const SizedBox(width: 8),
            Text(
              _tHqSafety(context, 'Escalated to HQ'),
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...escalated
            .map((incident) => _buildIncidentCard(incident, isEscalated: true)),
      ],
    );
  }

  Widget _buildRecentIncidents() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          _tHqSafety(context, 'All Recent Incidents'),
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: ScholesaColors.textPrimary),
        ),
        const SizedBox(height: 12),
        ..._incidents.map((incident) => _buildIncidentCard(incident)),
      ],
    );
  }

  Widget _buildIncidentCard(_SafetyIncident incident,
      {bool isEscalated = false}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isEscalated ? Colors.red.shade50 : ScholesaColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isEscalated
            ? BorderSide(color: Colors.red.shade200)
            : BorderSide.none,
      ),
      child: ListTile(
        leading: _buildSeverityIcon(incident.severity),
        title: Text(_tHqSafety(context, incident.title),
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle:
          Text('${_tHqSafety(context, incident.site)} • ${_formatTime(incident.reportedAt)}'),
        trailing: IconButton(
          icon: const Icon(Icons.chevron_right_rounded),
          onPressed: () {
            TelemetryService.instance.logEvent(
              event: 'cta.clicked',
              metadata: <String, dynamic>{
                'module': 'hq_safety',
                'cta_id': 'open_incident_details_chevron',
                'surface': 'incident_list',
                'incident_id': incident.id,
              },
            );
            _showIncidentDetails(incident);
          },
        ),
        onTap: () => _showIncidentDetails(incident),
      ),
    );
  }

  Widget _buildSeverityIcon(_Severity severity) {
    Color color;
    switch (severity) {
      case _Severity.minor:
        color = Colors.orange;
      case _Severity.major:
        color = Colors.deepOrange;
      case _Severity.critical:
        color = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8)),
      child: Icon(Icons.warning_rounded, color: color, size: 20),
    );
  }

  void _showIncidentDetails(_SafetyIncident incident) {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'module': 'hq_safety',
        'cta_id': 'open_incident_details',
        'surface': 'incident_list',
        'incident_id': incident.id,
        'severity': incident.severity.name,
      },
    );
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ScholesaColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(_tHqSafety(context, incident.title),
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildDetailRow(_tHqSafety(context, 'Site'),
              _tHqSafety(context, incident.site)),
            _buildDetailRow(
              _tHqSafety(context, 'Severity'),
              _tHqSafety(context, incident.severity.name).toUpperCase()),
            _buildDetailRow(
              _tHqSafety(context, 'Reported'), _formatTime(incident.reportedAt)),
            _buildDetailRow(_tHqSafety(context, 'Escalated'),
              incident.isEscalated
                ? _tHqSafety(context, 'Yes')
                : _tHqSafety(context, 'No')),
            const SizedBox(height: 24),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      TelemetryService.instance.logEvent(
                        event: 'cta.clicked',
                        metadata: <String, dynamic>{
                          'module': 'hq_safety',
                          'cta_id': 'close_incident_details',
                          'surface': 'incident_details_sheet',
                          'incident_id': incident.id,
                        },
                      );
                      Navigator.pop(context);
                    },
                    child: Text(_tHqSafety(context, 'Close')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      TelemetryService.instance.logEvent(
                        event: 'cta.clicked',
                        metadata: <String, dynamic>{
                          'module': 'hq_safety',
                          'cta_id': 'view_full_incident_report',
                          'surface': 'incident_details_sheet',
                          'incident_id': incident.id,
                        },
                      );
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(_tHqSafety(
                                context, 'Opening full incident report...'))),
                      );
                    },
                    child: Text(_tHqSafety(context, 'View Full Report')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(label,
              style: const TextStyle(color: ScholesaColors.textSecondary)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final Duration diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) return '${diff.inMinutes}${_tHqSafety(context, 'm ago')}';
    if (diff.inHours < 24) return '${diff.inHours}${_tHqSafety(context, 'h ago')}';
    return '${diff.inDays}${_tHqSafety(context, 'd ago')}';
  }
}
