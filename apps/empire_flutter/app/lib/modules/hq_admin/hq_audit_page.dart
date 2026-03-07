import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../services/telemetry_service.dart';
import '../../ui/theme/scholesa_theme.dart';

const Map<String, String> _hqAuditEs = <String, String>{
  'Audit Logs': 'Registros de auditoría',
  'Exporting audit logs...': 'Exportando registros de auditoría...',
  'Total': 'Total',
  'Auth': 'Auth',
  'Admin': 'Admin',
  'System': 'Sistema',
  'Filter by Category': 'Filtrar por categoría',
  'All': 'Todas',
  'Data': 'Datos',
  'Category': 'Categoría',
  'Actor': 'Actor',
  'Time': 'Hora',
  'IP Address': 'Dirección IP',
  'Details': 'Detalles',
  'Close': 'Cerrar',
  'm ago': 'min atrás',
  'h ago': 'h atrás',
  'd ago': 'd atrás',
  'User Login': 'Inicio de sesión de usuario',
  'Role Changed': 'Rol modificado',
  'Data Export': 'Exportación de datos',
  'Config Update': 'Actualización de configuración',
  'Successful login from web client':
      'Inicio de sesión exitoso desde cliente web',
  'Changed user jane@school.edu role from educator to site_lead':
      'Rol del usuario jane@school.edu cambiado de educador a site_lead',
  'Exported learner progress report for Site: Downtown':
      'Se exportó el informe de progreso de estudiantes para la sede: Centro',
  'Feature flag "new_dashboard" enabled globally':
      'Bandera de función "new_dashboard" habilitada globalmente',
  'Loading...': 'Cargando...',
  'No audit logs found': 'No se encontraron registros de auditoría',
};

String _tHqAudit(BuildContext context, String input) {
  final String locale = Localizations.localeOf(context).languageCode;
  if (locale != 'es') return input;
  return _hqAuditEs[input] ?? input;
}

/// HQ Audit page for viewing audit logs and compliance reports
/// Based on docs/43_EXPORT_RETENTION_BACKUP_SPEC.md
class HqAuditPage extends StatefulWidget {
  const HqAuditPage({super.key});

  @override
  State<HqAuditPage> createState() => _HqAuditPageState();
}

enum _AuditCategory { auth, data, admin, system }

class _AuditLog {
  const _AuditLog({
    required this.id,
    required this.action,
    required this.category,
    required this.actor,
    required this.timestamp,
    required this.details,
    this.ipAddress,
  });

  final String id;
  final String action;
  final _AuditCategory category;
  final String actor;
  final DateTime timestamp;
  final String details;
  final String? ipAddress;
}

class _HqAuditPageState extends State<HqAuditPage> {
  List<_AuditLog> _auditLogs = <_AuditLog>[];
  bool _isLoading = false;

  _AuditCategory? _filterCategory;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAuditLogs();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ScholesaColors.background,
      appBar: AppBar(
        title: Text(_tHqAudit(context, 'Audit Logs')),
        backgroundColor: ScholesaColors.hqGradient.colors.first,
        foregroundColor: Colors.white,
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: () {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: <String, dynamic>{
                  'module': 'hq_audit',
                  'cta_id': 'open_filter_dialog',
                  'surface': 'appbar',
                },
              );
              _showFilterDialog();
            },
          ),
          IconButton(
            icon: const Icon(Icons.download_rounded),
            onPressed: () {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: <String, dynamic>{
                  'module': 'hq_audit',
                  'cta_id': 'export_audit_logs',
                  'surface': 'appbar',
                },
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content:
                        Text(_tHqAudit(context, 'Exporting audit logs...'))),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          _buildSummaryHeader(),
          Expanded(child: _buildAuditList()),
        ],
      ),
    );
  }

  Widget _buildSummaryHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: ScholesaColors.surface,
      child: Row(
        children: <Widget>[
          Expanded(
              child: _buildSummaryStat(_tHqAudit(context, 'Total'),
                  _auditLogs.length.toString(), Colors.blue)),
          Expanded(
              child: _buildSummaryStat(
                  _tHqAudit(context, 'Auth'),
                  _auditLogs
                      .where((_AuditLog l) => l.category == _AuditCategory.auth)
                      .length
                      .toString(),
                  Colors.green)),
          Expanded(
              child: _buildSummaryStat(
                  _tHqAudit(context, 'Admin'),
                  _auditLogs
                      .where(
                          (_AuditLog l) => l.category == _AuditCategory.admin)
                      .length
                      .toString(),
                  Colors.orange)),
          Expanded(
              child: _buildSummaryStat(
                  _tHqAudit(context, 'System'),
                  _auditLogs
                      .where(
                          (_AuditLog l) => l.category == _AuditCategory.system)
                      .length
                      .toString(),
                  Colors.purple)),
        ],
      ),
    );
  }

  Widget _buildSummaryStat(String label, String value, Color color) {
    return Column(
      children: <Widget>[
        Text(value,
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: ScholesaColors.textSecondary)),
      ],
    );
  }

  Widget _buildAuditList() {
    if (_isLoading) {
      return Center(
        child: Text(
          _tHqAudit(context, 'Loading...'),
          style: const TextStyle(color: ScholesaColors.textSecondary),
        ),
      );
    }

    final List<_AuditLog> filtered = _filterCategory == null
        ? _auditLogs
        : _auditLogs
            .where((_AuditLog l) => l.category == _filterCategory)
            .toList();

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          _tHqAudit(context, 'No audit logs found'),
          style: const TextStyle(color: ScholesaColors.textSecondary),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (BuildContext context, int index) =>
          _buildAuditCard(filtered[index]),
    );
  }

  Widget _buildAuditCard(_AuditLog log) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: ScholesaColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: _buildCategoryIcon(log.category),
        title: Text(_tHqAudit(context, log.action),
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(_tHqAudit(context, log.details),
                style: const TextStyle(
                    fontSize: 12, color: ScholesaColors.textSecondary)),
            const SizedBox(height: 4),
            Text(
              '${log.actor} • ${_formatTime(log.timestamp)}',
              style: const TextStyle(
                  fontSize: 11, color: ScholesaColors.textSecondary),
            ),
          ],
        ),
        isThreeLine: true,
        onTap: () => _showLogDetails(log),
      ),
    );
  }

  Widget _buildCategoryIcon(_AuditCategory category) {
    IconData icon;
    Color color;
    switch (category) {
      case _AuditCategory.auth:
        icon = Icons.login_rounded;
        color = Colors.green;
      case _AuditCategory.data:
        icon = Icons.storage_rounded;
        color = Colors.blue;
      case _AuditCategory.admin:
        icon = Icons.admin_panel_settings_rounded;
        color = Colors.orange;
      case _AuditCategory.system:
        icon = Icons.settings_rounded;
        color = Colors.purple;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  void _showFilterDialog() {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: ScholesaColors.surface,
        title: Text(_tHqAudit(context, 'Filter by Category')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _buildFilterOption(_tHqAudit(context, 'All'), null),
            _buildFilterOption(_tHqAudit(context, 'Auth'), _AuditCategory.auth),
            _buildFilterOption(_tHqAudit(context, 'Data'), _AuditCategory.data),
            _buildFilterOption(
                _tHqAudit(context, 'Admin'), _AuditCategory.admin),
            _buildFilterOption(
                _tHqAudit(context, 'System'), _AuditCategory.system),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterOption(String label, _AuditCategory? category) {
    return ListTile(
      title: Text(label),
      leading: RadioGroup<_AuditCategory?>(
        groupValue: _filterCategory,
        onChanged: (_AuditCategory? value) {
          TelemetryService.instance.logEvent(
            event: 'cta.clicked',
            metadata: <String, dynamic>{
              'module': 'hq_audit',
              'cta_id': 'apply_filter',
              'surface': 'filter_dialog',
              'category': value?.name ?? 'all',
            },
          );
          setState(() => _filterCategory = value);
          Navigator.pop(context);
        },
        child: Radio<_AuditCategory?>(
          value: category,
        ),
      ),
      onTap: () {
        TelemetryService.instance.logEvent(
          event: 'cta.clicked',
          metadata: <String, dynamic>{
            'module': 'hq_audit',
            'cta_id': 'apply_filter',
            'surface': 'filter_dialog',
            'category': category?.name ?? 'all',
          },
        );
        setState(() => _filterCategory = category);
        Navigator.pop(context);
      },
    );
  }

  void _showLogDetails(_AuditLog log) {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'module': 'hq_audit',
        'cta_id': 'open_audit_log_details',
        'surface': 'audit_list',
        'log_id': log.id,
        'category': log.category.name,
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
            Text(_tHqAudit(context, log.action),
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildDetailRow(_tHqAudit(context, 'Category'),
                log.category.name.toUpperCase()),
            _buildDetailRow(_tHqAudit(context, 'Actor'), log.actor),
            _buildDetailRow(
                _tHqAudit(context, 'Time'), _formatTime(log.timestamp)),
            if (log.ipAddress != null)
              _buildDetailRow(_tHqAudit(context, 'IP Address'), log.ipAddress!),
            const SizedBox(height: 8),
            Text(_tHqAudit(context, 'Details'),
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: ScholesaColors.textSecondary)),
            const SizedBox(height: 4),
            Text(_tHqAudit(context, log.details)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  TelemetryService.instance.logEvent(
                    event: 'cta.clicked',
                    metadata: <String, dynamic>{
                      'module': 'hq_audit',
                      'cta_id': 'close_audit_log_details',
                      'surface': 'audit_log_details_sheet',
                      'log_id': log.id,
                    },
                  );
                  Navigator.pop(context);
                },
                child: Text(_tHqAudit(context, 'Close')),
              ),
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
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}${_tHqAudit(context, 'm ago')}';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours}${_tHqAudit(context, 'h ago')}';
    }
    return '${diff.inDays}${_tHqAudit(context, 'd ago')}';
  }

  Future<void> _loadAuditLogs() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final HttpsCallable callable =
          FirebaseFunctions.instance.httpsCallable('listAuditLogs');
      final HttpsCallableResult<dynamic> result =
          await callable.call(<String, dynamic>{'limit': 100});
      final Map<String, dynamic> payload = _asMap(result.data);
      final List<dynamic> rows =
          payload['logs'] as List<dynamic>? ?? <dynamic>[];

      final List<_AuditLog> loaded = rows
          .map((dynamic row) {
            final Map<String, dynamic> data = _asMap(row);
            final String id = ((data['id'] as String?) ?? '').trim();
            if (id.isEmpty) return null;
            final String actionRaw =
                ((data['action'] as String?) ?? 'unknown').trim();
            final String actionTitle = _titleFromAction(actionRaw);
            final String actor =
                ((data['actorEmail'] as String?)?.trim().isNotEmpty == true)
                    ? (data['actorEmail'] as String).trim()
                    : ((data['actorId'] as String?)?.trim().isNotEmpty == true)
                        ? (data['actorId'] as String).trim()
                        : 'system';
            final DateTime timestamp = _toDateTime(data['createdAt']) ??
                _toDateTime(data['timestamp']) ??
                _toDateTime(data['updatedAt']) ??
                DateTime.now();
            final String details = _detailsToText(data['details']);

            return _AuditLog(
              id: id,
              action: actionTitle,
              category: _categoryFromAction(actionRaw),
              actor: actor,
              timestamp: timestamp,
              details: details,
              ipAddress: data['ipAddress'] as String?,
            );
          })
          .whereType<_AuditLog>()
          .toList(growable: false);

      loaded.sort(
          (_AuditLog a, _AuditLog b) => b.timestamp.compareTo(a.timestamp));

      if (!mounted) return;
      setState(() => _auditLogs = loaded);
    } catch (_) {
      if (!mounted) return;
      setState(() => _auditLogs = <_AuditLog>[]);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  _AuditCategory _categoryFromAction(String action) {
    final String value = action.toLowerCase();
    if (value.contains('login') || value.contains('auth')) {
      return _AuditCategory.auth;
    }
    if (value.contains('export') || value.contains('data')) {
      return _AuditCategory.data;
    }
    if (value.contains('config') || value.contains('system')) {
      return _AuditCategory.system;
    }
    return _AuditCategory.admin;
  }

  String _titleFromAction(String action) {
    final String value = action.trim();
    if (value.isEmpty) return 'Unknown Action';
    final List<String> parts = value
        .replaceAll('_', ' ')
        .replaceAll('.', ' ')
        .split(' ')
        .where((String p) => p.isNotEmpty)
        .toList();
    return parts
        .map((String p) =>
            '${p[0].toUpperCase()}${p.substring(1).toLowerCase()}')
        .join(' ');
  }

  String _detailsToText(dynamic details) {
    if (details is String && details.trim().isNotEmpty) return details.trim();
    if (details is Map) {
      final Map<String, dynamic> asMap = _asMap(details);
      final Iterable<String> pairs = asMap.entries
          .where((MapEntry<String, dynamic> e) => e.value != null)
          .map((MapEntry<String, dynamic> e) => '${e.key}: ${e.value}');
      return pairs.isEmpty ? 'No additional details' : pairs.join(', ');
    }
    return 'No additional details';
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
