import 'package:flutter/material.dart';
import '../../services/telemetry_service.dart';
import '../../ui/theme/scholesa_theme.dart';

const Map<String, String> _siteIncidentsEs = <String, String>{
  'Safety & Incidents': 'Seguridad e incidentes',
  'Open': 'Abiertos',
  'Reviewed': 'Revisados',
  'Closed': 'Cerrados',
  'Report Incident': 'Reportar incidente',
  'No incidents': 'Sin incidentes',
  'Reported by': 'Reportado por',
  'Minor': 'Menor',
  'Major': 'Mayor',
  'Critical': 'Crítico',
  'Learner': 'Estudiante',
  'Reported By': 'Reportado por',
  'Date': 'Fecha',
  'Status': 'Estado',
  'Close': 'Cerrar',
  'Incident updated': 'Incidente actualizado',
  'Review': 'Revisar',
  'Close Incident': 'Cerrar incidente',
  'Report New Incident': 'Reportar nuevo incidente',
  'Incident Title': 'Título del incidente',
  'Severity': 'Severidad',
  'Cancel': 'Cancelar',
  'Incident reported': 'Incidente reportado',
  'Submit': 'Enviar',
  'submitted': 'enviado',
  'reviewed': 'revisado',
  'closed': 'cerrado',
};

String _tSiteIncidents(BuildContext context, String input) {
  final String locale = Localizations.localeOf(context).languageCode;
  if (locale != 'es') return input;
  return _siteIncidentsEs[input] ?? input;
}

/// Site incidents management page
/// Based on docs/41_SAFETY_CONSENT_INCIDENTS_SPEC.md
class SiteIncidentsPage extends StatefulWidget {
  const SiteIncidentsPage({super.key});

  @override
  State<SiteIncidentsPage> createState() => _SiteIncidentsPageState();
}

enum _Severity { minor, major, critical }

enum _Status { submitted, reviewed, closed }

class _Incident {
  const _Incident({
    required this.id,
    required this.title,
    required this.severity,
    required this.status,
    required this.reportedBy,
    required this.reportedAt,
    required this.learnerName,
  });

  final String id;
  final String title;
  final _Severity severity;
  final _Status status;
  final String reportedBy;
  final DateTime reportedAt;
  final String learnerName;
}

class _SiteIncidentsPageState extends State<SiteIncidentsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String _statusLabel(_Status status) {
    switch (status) {
      case _Status.submitted:
        return _tSiteIncidents(context, 'Open');
      case _Status.reviewed:
        return _tSiteIncidents(context, 'Reviewed');
      case _Status.closed:
        return _tSiteIncidents(context, 'Closed');
    }
  }

  final List<_Incident> _incidents = <_Incident>[
    _Incident(
      id: '1',
      title: 'Minor bump during play',
      severity: _Severity.minor,
      status: _Status.closed,
      reportedBy: 'Ms. Johnson',
      reportedAt: DateTime.now().subtract(const Duration(days: 2)),
      learnerName: 'Oliver T.',
    ),
    _Incident(
      id: '2',
      title: 'Late pickup - 30 minutes',
      severity: _Severity.minor,
      status: _Status.reviewed,
      reportedBy: 'Front Desk',
      reportedAt: DateTime.now().subtract(const Duration(days: 1)),
      learnerName: 'Emma S.',
    ),
    _Incident(
      id: '3',
      title: 'Behavioral concern during class',
      severity: _Severity.major,
      status: _Status.submitted,
      reportedBy: 'Mr. Davis',
      reportedAt: DateTime.now().subtract(const Duration(hours: 3)),
      learnerName: 'Liam M.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ScholesaColors.background,
      appBar: AppBar(
        title: Text(_tSiteIncidents(context, 'Safety & Incidents')),
        backgroundColor: ScholesaColors.safetyGradient.colors.first,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          onTap: (int index) {
            final List<String> tabs = <String>['open', 'reviewed', 'closed'];
            TelemetryService.instance.logEvent(
              event: 'cta.clicked',
              metadata: <String, dynamic>{
                'module': 'site_incidents',
                'cta_id': 'switch_tab',
                'surface': 'incidents_tab_bar',
                'tab': tabs[index],
              },
            );
          },
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: <Widget>[
            Tab(text: _tSiteIncidents(context, 'Open')),
            Tab(text: _tSiteIncidents(context, 'Reviewed')),
            Tab(text: _tSiteIncidents(context, 'Closed')),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          TelemetryService.instance.logEvent(
            event: 'cta.clicked',
            metadata: <String, dynamic>{
              'module': 'site_incidents',
              'cta_id': 'open_create_incident_dialog',
              'surface': 'floating_action_button',
            },
          );
          _showCreateIncidentDialog();
        },
        backgroundColor: ScholesaColors.safetyGradient.colors.first,
        icon: const Icon(Icons.add_rounded),
        label: Text(_tSiteIncidents(context, 'Report Incident')),
      ),
      body: TabBarView(
        controller: _tabController,
        children: <Widget>[
          _buildIncidentList(_Status.submitted),
          _buildIncidentList(_Status.reviewed),
          _buildIncidentList(_Status.closed),
        ],
      ),
    );
  }

  Widget _buildIncidentList(_Status statusFilter) {
    final List<_Incident> filtered =
        _incidents.where((_Incident i) => i.status == statusFilter).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.check_circle_rounded,
              size: 64,
              color: Colors.green.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              '${_tSiteIncidents(context, 'No incidents')} ${_tSiteIncidents(context, statusFilter.name)}',
              style: const TextStyle(
                fontSize: 16,
                color: ScholesaColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (BuildContext context, int index) {
        return _buildIncidentCard(filtered[index]);
      },
    );
  }

  Widget _buildIncidentCard(_Incident incident) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: ScholesaColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          TelemetryService.instance.logEvent(
            event: 'cta.clicked',
            metadata: <String, dynamic>{
              'module': 'site_incidents',
              'cta_id': 'tap_incident_card',
              'surface': 'incident_list',
              'incident_id': incident.id,
            },
          );
          _showIncidentDetails(incident);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  _buildSeverityBadge(incident.severity),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      incident.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: ScholesaColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  const Icon(Icons.person_rounded,
                      size: 16, color: ScholesaColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    incident.learnerName,
                    style: const TextStyle(
                      fontSize: 13,
                      color: ScholesaColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.schedule_rounded,
                      size: 16, color: ScholesaColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    _formatDateTime(incident.reportedAt),
                    style: const TextStyle(
                      fontSize: 13,
                      color: ScholesaColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${_tSiteIncidents(context, 'Reported by')} ${incident.reportedBy}',
                style: const TextStyle(
                  fontSize: 12,
                  color: ScholesaColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSeverityBadge(_Severity severity) {
    Color color;
    String label;
    switch (severity) {
      case _Severity.minor:
        color = Colors.orange;
        label = _tSiteIncidents(context, 'Minor');
      case _Severity.major:
        color = Colors.deepOrange;
        label = _tSiteIncidents(context, 'Major');
      case _Severity.critical:
        color = Colors.red;
        label = _tSiteIncidents(context, 'Critical');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  void _showIncidentDetails(_Incident incident) {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'module': 'site_incidents',
        'cta_id': 'open_incident_details',
        'surface': 'incident_card',
        'incident_id': incident.id,
        'status': incident.status.name,
      },
    );
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ScholesaColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                _buildSeverityBadge(incident.severity),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    incident.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(_tSiteIncidents(context, 'Learner'), incident.learnerName),
            _buildInfoRow(_tSiteIncidents(context, 'Reported By'), incident.reportedBy),
            _buildInfoRow(_tSiteIncidents(context, 'Date'), _formatDateTime(incident.reportedAt)),
            _buildInfoRow(_tSiteIncidents(context, 'Status'), _statusLabel(incident.status).toUpperCase()),
            const SizedBox(height: 24),
            if (incident.status != _Status.closed)
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        TelemetryService.instance.logEvent(
                          event: 'cta.clicked',
                          metadata: <String, dynamic>{
                            'module': 'site_incidents',
                            'cta_id': 'close_incident_details',
                            'surface': 'incident_details_sheet',
                            'incident_id': incident.id,
                          },
                        );
                        Navigator.pop(context);
                      },
                      child: Text(_tSiteIncidents(context, 'Close')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        TelemetryService.instance.logEvent(
                          event: 'cta.clicked',
                          metadata: <String, dynamic>{
                            'module': 'site_incidents',
                            'cta_id': incident.status == _Status.submitted
                                ? 'review_incident'
                                : 'close_incident',
                            'surface': 'incident_details_sheet',
                            'incident_id': incident.id,
                          },
                        );
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(_tSiteIncidents(context, 'Incident updated'))),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            ScholesaColors.safetyGradient.colors.first,
                      ),
                      child: Text(incident.status == _Status.submitted
                          ? _tSiteIncidents(context, 'Review')
                          : _tSiteIncidents(context, 'Close Incident')),
                    ),
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    TelemetryService.instance.logEvent(
                      event: 'cta.clicked',
                      metadata: <String, dynamic>{
                        'module': 'site_incidents',
                        'cta_id': 'close_closed_incident_details',
                        'surface': 'incident_details_sheet',
                        'incident_id': incident.id,
                      },
                    );
                    Navigator.pop(context);
                  },
                  child: Text(_tSiteIncidents(context, 'Close')),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(color: ScholesaColors.textSecondary),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  void _showCreateIncidentDialog() {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: ScholesaColors.surface,
        title: Text(_tSiteIncidents(context, 'Report New Incident')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              decoration: InputDecoration(
                labelText: _tSiteIncidents(context, 'Incident Title'),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<_Severity>(
              decoration: InputDecoration(
                labelText: _tSiteIncidents(context, 'Severity'),
                border: OutlineInputBorder(),
              ),
              items: _Severity.values
                  .map((_Severity s) => DropdownMenuItem<_Severity>(
                        value: s,
                        child: Text(_tSiteIncidents(context, s.name[0].toUpperCase() + s.name.substring(1))),
                      ))
                  .toList(),
              onChanged: (_) {},
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: <String, dynamic>{
                  'module': 'site_incidents',
                  'cta_id': 'cancel_incident_report',
                  'surface': 'create_incident_dialog',
                },
              );
              Navigator.pop(context);
            },
            child: Text(_tSiteIncidents(context, 'Cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: <String, dynamic>{
                  'module': 'site_incidents',
                  'cta_id': 'submit_incident_report',
                  'surface': 'create_incident_dialog',
                },
              );
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(_tSiteIncidents(context, 'Incident reported'))),
              );
            },
            child: Text(_tSiteIncidents(context, 'Submit')),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.month}/${dt.day}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
