import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/app_state.dart';
import '../../domain/models.dart';
import '../../domain/repositories.dart';
import '../../i18n/site_surface_i18n.dart';
import '../../services/export_service.dart';
import '../../services/telemetry_service.dart';
import '../../ui/theme/scholesa_theme.dart';

String _tSiteAudit(BuildContext context, String input) {
  return SiteSurfaceI18n.text(context, input);
}

class SiteAuditPage extends StatefulWidget {
  const SiteAuditPage({
    super.key,
    this.auditLogLoader,
  });

  final Future<List<AuditLogModel>> Function(String siteId)? auditLogLoader;

  @override
  State<SiteAuditPage> createState() => _SiteAuditPageState();
}

class _SiteAuditPageState extends State<SiteAuditPage> {
  late final AuditLogRepository _auditLogRepository = AuditLogRepository();

  List<AuditLogModel> _auditLogs = <AuditLogModel>[];
  bool _isLoading = false;
  String? _siteId;
  String? _loadError;

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
        title: Text(_tSiteAudit(context, 'Site Audit')),
        backgroundColor: ScholesaColors.siteGradient.colors.first,
        foregroundColor: Colors.white,
        actions: <Widget>[
          IconButton(
            tooltip: _tSiteAudit(context, 'Refresh'),
            onPressed: _isLoading ? null : _loadAuditLogs,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: _tSiteAudit(context, 'Export Audit Log'),
            onPressed: _isLoading || _auditLogs.isEmpty ? null : _exportAuditLogs,
            icon: const Icon(Icons.download_rounded),
          ),
          const SessionMenuButton(
            foregroundColor: Colors.white,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAuditLogs,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _auditLogs.isEmpty) {
      return Center(
        child: Text(
          _tSiteAudit(context, 'Loading...'),
          style: const TextStyle(color: ScholesaColors.textSecondary),
        ),
      );
    }

    if (_loadError != null && _auditLogs.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: <Widget>[
          _buildErrorCard(showRetry: true),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        _buildIntroCard(),
        if (_loadError != null) ...<Widget>[
          const SizedBox(height: 16),
          _buildErrorCard(showRetry: false),
        ],
        const SizedBox(height: 16),
        _buildSummaryRow(),
        const SizedBox(height: 16),
        if (_auditLogs.isEmpty)
          _buildEmptyState()
        else
          ..._auditLogs.map(_buildAuditCard),
      ],
    );
  }

  Widget _buildIntroCard() {
    return Card(
      color: ScholesaColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          _tSiteAudit(
            context,
            'Review recent site-scoped audit activity and export it for offline review.',
          ),
          style: const TextStyle(color: ScholesaColors.textSecondary),
        ),
      ),
    );
  }

  Widget _buildSummaryRow() {
    final int actorCount = _auditLogs
        .map((AuditLogModel log) => _normalizedValue(log.actorId))
        .where((String value) => value.isNotEmpty)
        .toSet()
        .length;
    final int entityCount = _auditLogs
        .map((AuditLogModel log) => '${_normalizedValue(log.entityType)}:${_normalizedValue(log.entityId)}')
        .where((String value) => value != ':')
        .toSet()
        .length;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: <Widget>[
        _buildSummaryCard(
          _tSiteAudit(context, 'Entries'),
          _auditLogs.length.toString(),
        ),
        _buildSummaryCard(
          _tSiteAudit(context, 'Actors'),
          actorCount.toString(),
        ),
        _buildSummaryCard(
          _tSiteAudit(context, 'Entities'),
          entityCount.toString(),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String label, String value) {
    return SizedBox(
      width: 180,
      child: Card(
        color: ScholesaColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                value,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: ScholesaColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(color: ScholesaColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorCard({required bool showRetry}) {
    return Card(
      color: const Color(0xFFFEF2F2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              _loadError ??
                  _tSiteAudit(context, 'Unable to load audit logs right now'),
              style: const TextStyle(
                color: Color(0xFF991B1B),
                fontWeight: FontWeight.w600,
              ),
            ),
            if (showRetry) ...<Widget>[
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: _loadAuditLogs,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(_tSiteAudit(context, 'Retry')),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      color: ScholesaColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          _tSiteAudit(context, 'No audit logs found for this site'),
          style: const TextStyle(color: ScholesaColors.textSecondary),
        ),
      ),
    );
  }

  Widget _buildAuditCard(AuditLogModel log) {
    final List<MapEntry<String, dynamic>> detailEntries =
        log.details.entries.toList(growable: false);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: ScholesaColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              _nonEmptyOrFallback(
                log.action,
                _tSiteAudit(context, 'Action unavailable'),
              ),
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: ScholesaColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${_tSiteAudit(context, 'Actor')}: ${_actorLabel(log)} • ${_tSiteAudit(context, 'Entity')}: ${_entityLabel(log)}',
              style: const TextStyle(color: ScholesaColors.textSecondary),
            ),
            if (log.createdAt != null) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                '${_tSiteAudit(context, 'Timestamp')}: ${_formatDateTime(log.createdAt!.toDate())}',
                style: const TextStyle(color: ScholesaColors.textSecondary),
              ),
            ],
            const SizedBox(height: 12),
            if (detailEntries.isEmpty)
              Text(
                _tSiteAudit(context, 'Details unavailable'),
                style: const TextStyle(color: ScholesaColors.textSecondary),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: detailEntries
                    .take(4)
                    .map((MapEntry<String, dynamic> entry) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: ScholesaColors.background,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${entry.key}: ${_detailValue(entry.value)}',
                            style: const TextStyle(
                              color: ScholesaColors.textSecondary,
                            ),
                          ),
                        ))
                    .toList(growable: false),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadAuditLogs() async {
    final AppState appState = context.read<AppState>();
    final String? siteId = appState.activeSiteId;
    if (siteId == null || siteId.trim().isEmpty) {
      setState(() {
        _siteId = null;
        _auditLogs = <AuditLogModel>[];
        _loadError = _tSiteAudit(context, 'Site context unavailable right now');
      });
      return;
    }

    setState(() {
      _siteId = siteId;
      _isLoading = true;
      _loadError = null;
    });

    try {
      final List<AuditLogModel> logs = await (widget.auditLogLoader != null
          ? widget.auditLogLoader!(siteId)
          : _auditLogRepository.listBySite(siteId));
      if (!mounted) {
        return;
      }
      setState(() {
        _auditLogs = logs;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadError =
            _tSiteAudit(context, 'Unable to load audit logs right now');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _exportAuditLogs() async {
    if (_auditLogs.isEmpty || _siteId == null) {
      return;
    }
    final StringBuffer export = StringBuffer()
      ..writeln('Site Audit Export')
      ..writeln('Site: $_siteId')
      ..writeln(
        'Generated: ${DateTime.now().toIso8601String()}',
      )
      ..writeln('');
    for (final AuditLogModel log in _auditLogs) {
      export
        ..writeln('Action: ${_nonEmptyOrFallback(log.action, 'n/a')}')
        ..writeln('Actor: ${_actorLabel(log)}')
        ..writeln('Entity: ${_entityLabel(log)}')
        ..writeln(
          'Timestamp: ${log.createdAt?.toDate().toIso8601String() ?? 'n/a'}',
        );
      if (log.details.isNotEmpty) {
        export.writeln('Details:');
        for (final MapEntry<String, dynamic> entry in log.details.entries) {
          export.writeln('  - ${entry.key}: ${_detailValue(entry.value)}');
        }
      }
      export.writeln('');
    }

    final String fileName = _auditExportFileName();
    try {
      final String? savedLocation = await ExportService.instance.saveTextFile(
        fileName: fileName,
        content: export.toString().trim(),
      );
      if (savedLocation == null || !mounted) {
        return;
      }
      TelemetryService.instance.logEvent(
        event: 'export.downloaded',
        role: 'site',
        siteId: _siteId,
        metadata: <String, dynamic>{
          'module': 'site_audit',
          'file_name': fileName,
          'entry_count': _auditLogs.length,
        },
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tSiteAudit(context, 'Audit export downloaded.'),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tSiteAudit(context, 'Unable to export audit logs right now.'),
          ),
        ),
      );
    }
  }

  String _auditExportFileName() {
    final String dateSegment =
        DateTime.now().toIso8601String().split('T').first;
    return 'site-audit-${_siteId ?? 'site'}-$dateSegment.txt';
  }

  String _actorLabel(AuditLogModel log) {
    final String actorId = _normalizedValue(log.actorId);
    final String actorRole = _normalizedValue(log.actorRole);
    if (actorId.isEmpty && actorRole.isEmpty) {
      return _tSiteAudit(context, 'Actor unavailable');
    }
    if (actorId.isEmpty) {
      return actorRole;
    }
    if (actorRole.isEmpty) {
      return actorId;
    }
    return '$actorRole • $actorId';
  }

  String _entityLabel(AuditLogModel log) {
    final String entityType = _normalizedValue(log.entityType);
    final String entityId = _normalizedValue(log.entityId);
    if (entityType.isEmpty && entityId.isEmpty) {
      return _tSiteAudit(context, 'Entity unavailable');
    }
    if (entityType.isEmpty) {
      return entityId;
    }
    if (entityId.isEmpty) {
      return entityType;
    }
    return '$entityType • $entityId';
  }

  String _detailValue(dynamic value) {
    if (value == null) {
      return 'null';
    }
    if (value is String) {
      return value;
    }
    if (value is num || value is bool) {
      return value.toString();
    }
    if (value is List || value is Map) {
      return jsonEncode(value);
    }
    return value.toString();
  }

  String _normalizedValue(String? value) => (value ?? '').trim();

  String _nonEmptyOrFallback(String? value, String fallback) {
    final String trimmed = (value ?? '').trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }

  String _formatDateTime(DateTime value) {
    final MaterialLocalizations localizations =
        MaterialLocalizations.of(context);
    return '${localizations.formatShortDate(value)} ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(value), alwaysUse24HourFormat: true)}';
  }
}
