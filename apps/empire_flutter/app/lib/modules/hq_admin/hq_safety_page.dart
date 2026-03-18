import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../i18n/workflow_surface_i18n.dart';
import '../../services/telemetry_service.dart';
import '../../ui/theme/scholesa_theme.dart';

String _tHqSafety(BuildContext context, String input) {
  return WorkflowSurfaceI18n.text(context, input);
}

/// HQ Safety page for monitoring safety incidents across all sites
/// Based on docs/41_SAFETY_CONSENT_INCIDENTS_SPEC.md
class HqSafetyPage extends StatefulWidget {
  const HqSafetyPage({super.key, this.incidentsLoader});

  final Future<Map<String, dynamic>> Function()? incidentsLoader;

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
  List<_SafetyIncident> _incidents = <_SafetyIncident>[];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadIncidents();
    });
  }

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
          _buildMetric(_tHqSafety(context, 'Open'),
              _incidents.length.toString(), Icons.warning_rounded),
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
    if (_isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            _tHqSafety(context, 'Loading...'),
            style: const TextStyle(color: ScholesaColors.textSecondary),
          ),
        ),
      );
    }

    if (_incidents.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            _tHqSafety(context, 'No incidents found'),
            style: const TextStyle(color: ScholesaColors.textSecondary),
          ),
        ),
      );
    }

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
        subtitle: Text(
            '${_tHqSafety(context, incident.site)} • ${_formatTime(incident.reportedAt)}'),
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
      builder: (BuildContext bottomSheetContext) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
        Text(_tHqSafety(bottomSheetContext, incident.title),
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
        _buildDetailRow(_tHqSafety(bottomSheetContext, 'Site'),
          _tHqSafety(bottomSheetContext, incident.site)),
        _buildDetailRow(_tHqSafety(bottomSheetContext, 'Severity'),
          _tHqSafety(bottomSheetContext, incident.severity.name).toUpperCase()),
        _buildDetailRow(_tHqSafety(bottomSheetContext, 'Reported'),
                _formatTime(incident.reportedAt)),
            _buildDetailRow(
          _tHqSafety(bottomSheetContext, 'Escalated'),
                incident.isEscalated
            ? _tHqSafety(bottomSheetContext, 'Yes')
            : _tHqSafety(bottomSheetContext, 'No')),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                _tHqSafety(
                  bottomSheetContext,
                  'Copy the current incident summary for offline review or escalation.',
                ),
                style: const TextStyle(color: ScholesaColors.textSecondary),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _copyIncidentSummary(
                  bottomSheetContext,
                  incident,
                ),
                icon: const Icon(Icons.content_copy_rounded),
                label: Text(
                  _tHqSafety(bottomSheetContext, 'Copy Incident Summary'),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
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
                  Navigator.pop(bottomSheetContext);
                },
                child: Text(_tHqSafety(bottomSheetContext, 'Close')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyIncidentSummary(
    BuildContext context,
    _SafetyIncident incident,
  ) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String summary = _buildIncidentSummary(context, incident);
    final String copiedMessage =
        _tHqSafety(context, 'Incident summary copied to clipboard.');
    await Clipboard.setData(ClipboardData(text: summary));
    if (!mounted) return;

    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'module': 'hq_safety',
        'cta_id': 'copy_incident_summary',
        'surface': 'incident_details_sheet',
        'incident_id': incident.id,
        'severity': incident.severity.name,
      },
    );

    messenger.showSnackBar(
      SnackBar(
        content: Text(copiedMessage),
      ),
    );
  }

  String _buildIncidentSummary(BuildContext context, _SafetyIncident incident) {
    final String severity =
        _tHqSafety(context, incident.severity.name).toUpperCase();
    final String escalated = incident.isEscalated
        ? _tHqSafety(context, 'Yes')
        : _tHqSafety(context, 'No');

    return <String>[
      _tHqSafety(context, 'Incident Summary'),
      'ID: ${incident.id}',
      '${_tHqSafety(context, 'Title')}: ${incident.title}',
      '${_tHqSafety(context, 'Site')}: ${incident.site}',
      '${_tHqSafety(context, 'Severity')}: $severity',
      '${_tHqSafety(context, 'Reported')}: ${_formatTime(incident.reportedAt)}',
      '${_tHqSafety(context, 'Escalated')}: $escalated',
    ].join('\n');
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
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}${_tHqSafety(context, 'm ago')}';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours}${_tHqSafety(context, 'h ago')}';
    }
    return '${diff.inDays}${_tHqSafety(context, 'd ago')}';
  }

  Future<void> _loadIncidents() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final Map<String, dynamic> payload = await _loadIncidentPayload();
      final List<dynamic> rows =
          payload['incidents'] as List<dynamic>? ?? <dynamic>[];

      final List<_SafetyIncident> loaded = rows
          .map((dynamic row) {
            final Map<String, dynamic> data = _asMap(row);
            final String id = ((data['id'] as String?) ?? '').trim();
            if (id.isEmpty) return null;
            final DateTime reportedAt = _toDateTime(data['updatedAt']) ??
                _toDateTime(data['createdAt']) ??
                _toDateTime(data['reportedAt']) ??
                DateTime.now();
            final _Severity severity = _parseSeverity(
                (data['severity'] as String?) ?? (data['type'] as String?));
            final String title =
                (data['title'] as String?)?.trim().isNotEmpty == true
                    ? (data['title'] as String).trim()
                    : ((data['summary'] as String?)?.trim().isNotEmpty == true
                        ? (data['summary'] as String).trim()
                        : (data['description'] as String?) ?? 'Incident');
            final String siteLabel =
                (data['siteName'] as String?)?.trim().isNotEmpty == true
                    ? (data['siteName'] as String).trim()
                    : (data['siteId'] as String?)?.trim().isNotEmpty == true
                        ? (data['siteId'] as String).trim()
                  : _tHqSafety(context, 'Site unavailable');
            final String status =
                ((data['status'] as String?) ?? '').toLowerCase();
            final bool escalated = (data['isEscalated'] as bool?) ??
                severity == _Severity.critical ||
                    status == 'reviewed' ||
                    status == 'escalated';

            return _SafetyIncident(
              id: id,
              title: title,
              site: siteLabel,
              severity: severity,
              reportedAt: reportedAt,
              isEscalated: escalated,
            );
          })
          .whereType<_SafetyIncident>()
          .toList(growable: false);

      loaded.sort((_SafetyIncident a, _SafetyIncident b) =>
          b.reportedAt.compareTo(a.reportedAt));

      if (!mounted) return;
      setState(() => _incidents = loaded);
    } catch (_) {
      if (!mounted) return;
      setState(() => _incidents = <_SafetyIncident>[]);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<Map<String, dynamic>> _loadIncidentPayload() async {
    if (widget.incidentsLoader != null) {
      return widget.incidentsLoader!();
    }

    final HttpsCallable callable =
        FirebaseFunctions.instance.httpsCallable('listSafetyIncidents');
    final HttpsCallableResult<dynamic> result =
        await callable.call(<String, dynamic>{'limit': 150});
    return _asMap(result.data);
  }

  _Severity _parseSeverity(String? raw) {
    final String value = (raw ?? '').trim().toLowerCase();
    if (value == 'critical') return _Severity.critical;
    if (value == 'major' || value == 'high') return _Severity.major;
    return _Severity.minor;
  }

  DateTime? _toDateTime(dynamic value) {
    if (value is Map) {
      final dynamic secondsRaw = value['seconds'] ?? value['_seconds'];
      final dynamic nanosRaw = value['nanoseconds'] ?? value['_nanoseconds'];
      final int? seconds =
          secondsRaw is int ? secondsRaw : int.tryParse('$secondsRaw');
      final int nanos =
          nanosRaw is int ? nanosRaw : int.tryParse('$nanosRaw') ?? 0;
      if (seconds != null) {
        return DateTime.fromMillisecondsSinceEpoch(
          (seconds * 1000) + (nanos ~/ 1000000),
        );
      }
    }
    if (value != null &&
        value is Object &&
        value.runtimeType.toString().contains('Timestamp') &&
        (value as dynamic).toDate is Function) {
      return (value as dynamic).toDate() as DateTime?;
    }
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }
    return null;
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map(
        (dynamic key, dynamic mapValue) => MapEntry(key.toString(), mapValue),
      );
    }
    return <String, dynamic>{};
  }
}
