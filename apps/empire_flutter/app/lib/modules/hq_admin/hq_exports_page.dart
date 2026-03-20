import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/models.dart';
import '../../domain/repositories.dart';
import '../../i18n/workflow_surface_i18n.dart';
import '../../services/analytics_service.dart';
import '../../services/export_service.dart';
import '../../services/telemetry_service.dart';
import '../../ui/auth/global_session_menu.dart';
import '../../ui/theme/scholesa_theme.dart';

String _tHqExports(BuildContext context, String input) {
  return WorkflowSurfaceI18n.text(context, input);
}

class HqExportsPage extends StatefulWidget {
  const HqExportsPage({
    super.key,
    this.analyticsLoader,
    this.billingLoader,
    this.auditLoader,
    this.safetyLoader,
  });

  final Future<TelemetryDashboardMetrics> Function()? analyticsLoader;
  final Future<Map<String, dynamic>> Function()? billingLoader;
  final Future<List<AuditLogModel>> Function()? auditLoader;
  final Future<Map<String, dynamic>> Function()? safetyLoader;

  @override
  State<HqExportsPage> createState() => _HqExportsPageState();
}

class _HqExportsPageState extends State<HqExportsPage> {
  final AnalyticsService _analyticsService = AnalyticsService.instance;
  AuditLogRepository? _auditLogRepository;

  TelemetryDashboardMetrics? _analyticsMetrics;
  Map<String, dynamic>? _billingPayload;
  List<AuditLogModel> _auditLogs = <AuditLogModel>[];
  Map<String, dynamic>? _safetyPayload;

  bool _isLoadingAnalytics = false;
  bool _isLoadingBilling = false;
  bool _isLoadingAudit = false;
  bool _isLoadingSafety = false;

  String? _analyticsError;
  String? _billingError;
  String? _auditError;
  String? _safetyError;

  bool get _isLoadingAny =>
      _isLoadingAnalytics || _isLoadingBilling || _isLoadingAudit || _isLoadingSafety;

  bool get _hasReadyBundle =>
      _analyticsMetrics != null ||
      _billingRecordCount > 0 ||
      _auditLogs.isNotEmpty ||
      _safetyIncidentCount > 0;

  int get _billingRecordCount {
    final Map<String, dynamic> payload = _billingPayload ?? const <String, dynamic>{};
    return _asMapList(payload['invoices']).length +
        _asMapList(payload['payments']).length +
        _asMapList(payload['subscriptions']).length;
  }

  int get _safetyIncidentCount =>
      _asMapList((_safetyPayload ?? const <String, dynamic>{})['incidents']).length;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ScholesaColors.background,
      appBar: AppBar(
        title: Text(_tHqExports(context, 'HQ Exports')),
        backgroundColor: ScholesaColors.hqGradient.colors.first,
        foregroundColor: Colors.white,
        actions: <Widget>[
          IconButton(
            tooltip: _tHqExports(context, 'Refresh'),
            onPressed: _isLoadingAny ? null : _refreshAll,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: _tHqExports(context, 'Download Full Bundle'),
            onPressed: _isLoadingAny || !_hasReadyBundle ? null : _downloadFullBundle,
            icon: const Icon(Icons.file_download_rounded),
          ),
          const SessionMenuButton(
            foregroundColor: Colors.white,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            _buildIntroCard(),
            if (_hasPartialFailure()) ...<Widget>[
              const SizedBox(height: 16),
              _buildPartialFailureCard(),
            ],
            const SizedBox(height: 16),
            _buildBundleCard(
              title: _tHqExports(context, 'Analytics Bundle'),
              description: _tHqExports(
                context,
                'Exports the current HQ analytics metrics used by the dashboard.',
              ),
              isLoading: _isLoadingAnalytics,
              error: _analyticsError,
              countLabel: _analyticsMetrics == null
                  ? _tHqExports(context, 'Unavailable')
                  : '${_analyticsMetrics!.attendanceTrend.length} ${_tHqExports(context, 'trend points')}',
              statusLabel: _analyticsMetrics == null
                  ? _tHqExports(context, 'Unavailable')
                  : _tHqExports(context, 'Ready'),
              onDownload: _analyticsMetrics == null ? null : _downloadAnalyticsBundle,
            ),
            _buildBundleCard(
              title: _tHqExports(context, 'Billing Bundle'),
              description: _tHqExports(
                context,
                'Exports the live invoices, payments, and subscriptions returned by HQ billing records.',
              ),
              isLoading: _isLoadingBilling,
              error: _billingError,
              countLabel: '$_billingRecordCount',
              statusLabel: _billingRecordCount == 0
                  ? _tHqExports(context, 'Empty')
                  : _tHqExports(context, 'Ready'),
              onDownload: _billingRecordCount == 0 ? null : _downloadBillingBundle,
            ),
            _buildBundleCard(
              title: _tHqExports(context, 'Audit Bundle'),
              description: _tHqExports(
                context,
                'Exports recent audit log entries for offline review and incident follow-up.',
              ),
              isLoading: _isLoadingAudit,
              error: _auditError,
              countLabel: '${_auditLogs.length} ${_tHqExports(context, 'entries')}',
              statusLabel: _auditLogs.isEmpty
                  ? _tHqExports(context, 'Empty')
                  : _tHqExports(context, 'Ready'),
              onDownload: _auditLogs.isEmpty ? null : _downloadAuditBundle,
            ),
            _buildBundleCard(
              title: _tHqExports(context, 'Safety Bundle'),
              description: _tHqExports(
                context,
                'Exports recent safety incidents exactly as the HQ safety surface receives them.',
              ),
              isLoading: _isLoadingSafety,
              error: _safetyError,
              countLabel: '$_safetyIncidentCount ${_tHqExports(context, 'incidents')}',
              statusLabel: _safetyIncidentCount == 0
                  ? _tHqExports(context, 'Empty')
                  : _tHqExports(context, 'Ready'),
              onDownload: _safetyIncidentCount == 0 ? null : _downloadSafetyBundle,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntroCard() {
    return Card(
      color: ScholesaColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          _tHqExports(
            context,
            'Download live HQ bundles for analytics, billing, audit, and safety from one place.',
          ),
          style: const TextStyle(color: ScholesaColors.textSecondary),
        ),
      ),
    );
  }

  Widget _buildPartialFailureCard() {
    return Card(
      color: const Color(0xFFFFFBEB),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          _tHqExports(
            context,
            'Some export bundles are unavailable right now. Ready bundles can still be downloaded.',
          ),
          style: const TextStyle(
            color: Color(0xFF92400E),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildBundleCard({
    required String title,
    required String description,
    required bool isLoading,
    required String? error,
    required String countLabel,
    required String statusLabel,
    required Future<void> Function()? onDownload,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: ScholesaColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: ScholesaColors.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: ScholesaColors.hq.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    statusLabel,
                    style: const TextStyle(
                      color: ScholesaColors.hq,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(color: ScholesaColors.textSecondary),
            ),
            const SizedBox(height: 12),
            if (isLoading)
              Text(
                _tHqExports(context, 'Loading...'),
                style: const TextStyle(color: ScholesaColors.textSecondary),
              )
            else if (error != null)
              Text(
                error,
                style: const TextStyle(
                  color: Color(0xFF991B1B),
                  fontWeight: FontWeight.w600,
                ),
              )
            else
              Text(
                countLabel,
                style: const TextStyle(color: ScholesaColors.textSecondary),
              ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: onDownload == null
                  ? null
                  : () async {
                      await onDownload();
                    },
              icon: const Icon(Icons.download_rounded),
              label: Text(_tHqExports(context, 'Download Export')),
            ),
          ],
        ),
      ),
    );
  }

  bool _hasPartialFailure() {
    final List<String?> errors = <String?>[
      _analyticsError,
      _billingError,
      _auditError,
      _safetyError,
    ];
    return errors.any((String? error) => error != null) && _hasReadyBundle;
  }

  Future<void> _refreshAll() async {
    await Future.wait<void>(<Future<void>>[
      _loadAnalyticsBundle(),
      _loadBillingBundle(),
      _loadAuditBundle(),
      _loadSafetyBundle(),
    ]);
  }

  Future<void> _loadAnalyticsBundle() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _isLoadingAnalytics = true;
      _analyticsError = null;
    });
    try {
      final TelemetryDashboardMetrics metrics = widget.analyticsLoader != null
          ? await widget.analyticsLoader!()
          : await _analyticsService.getTelemetryDashboardMetrics(period: 'month');
      if (!mounted) {
        return;
      }
      setState(() {
        _analyticsMetrics = metrics;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _analyticsMetrics = null;
        _analyticsError =
            _tHqExports(context, 'Unable to load the analytics export bundle right now.');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAnalytics = false;
        });
      }
    }
  }

  Future<void> _loadBillingBundle() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _isLoadingBilling = true;
      _billingError = null;
    });
    try {
      final Map<String, dynamic> payload = widget.billingLoader != null
          ? await widget.billingLoader!()
          : await _loadBillingPayload();
      if (!mounted) {
        return;
      }
      setState(() {
        _billingPayload = payload;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _billingPayload = null;
        _billingError =
            _tHqExports(context, 'Unable to load the billing export bundle right now.');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingBilling = false;
        });
      }
    }
  }

  Future<void> _loadAuditBundle() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _isLoadingAudit = true;
      _auditError = null;
    });
    try {
      final List<AuditLogModel> logs = widget.auditLoader != null
          ? await widget.auditLoader!()
          : await (_auditLogRepository ??= AuditLogRepository()).listRecent();
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
        _auditLogs = <AuditLogModel>[];
        _auditError =
            _tHqExports(context, 'Unable to load the audit export bundle right now.');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAudit = false;
        });
      }
    }
  }

  Future<void> _loadSafetyBundle() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _isLoadingSafety = true;
      _safetyError = null;
    });
    try {
      final Map<String, dynamic> payload = widget.safetyLoader != null
          ? await widget.safetyLoader!()
          : await _loadSafetyPayload();
      if (!mounted) {
        return;
      }
      setState(() {
        _safetyPayload = payload;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _safetyPayload = null;
        _safetyError =
            _tHqExports(context, 'Unable to load the safety export bundle right now.');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSafety = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>> _loadBillingPayload() async {
    final HttpsCallable callable =
        FirebaseFunctions.instance.httpsCallable('listHqBillingRecords');
    final HttpsCallableResult<dynamic> result =
        await callable.call(<String, dynamic>{
      'siteId': null,
      'period': 'month',
      'limit': 500,
    });
    return _asMap(result.data);
  }

  Future<Map<String, dynamic>> _loadSafetyPayload() async {
    final HttpsCallable callable =
        FirebaseFunctions.instance.httpsCallable('listSafetyIncidents');
    final HttpsCallableResult<dynamic> result =
        await callable.call(<String, dynamic>{'limit': 150});
    return _asMap(result.data);
  }

  Future<void> _downloadAnalyticsBundle() async {
    final TelemetryDashboardMetrics? metrics = _analyticsMetrics;
    if (metrics == null) {
      return;
    }
    final StringBuffer buffer = StringBuffer()
      ..writeln('HQ Analytics Bundle')
      ..writeln('Generated: ${DateTime.now().toIso8601String()}')
      ..writeln('Weekly accountability adherence: ${metrics.weeklyAccountabilityAdherenceRate.toStringAsFixed(1)}%')
      ..writeln('Educator review SLA hours: ${metrics.educatorReviewSlaHours}')
      ..writeln('Intervention total: ${metrics.interventionTotal}')
      ..writeln('Attendance trend points: ${metrics.attendanceTrend.length}')
      ..writeln('');
    for (final AttendanceTrendPoint point in metrics.attendanceTrend) {
      buffer.writeln(
        '${point.date}: records=${point.records}, events=${point.events}, presentRate=${point.presentRate?.toStringAsFixed(1) ?? 'n/a'}%',
      );
    }
    await _saveBundle(
      module: 'hq_exports',
      bundleId: 'analytics',
      fileName: _bundleFileName('analytics'),
      content: buffer.toString().trim(),
      successMessage: _tHqExports(context, 'Analytics export downloaded.'),
      copiedMessage: _tHqExports(context, 'Analytics export copied to clipboard.'),
      failureMessage:
          _tHqExports(context, 'Unable to download the analytics export right now.'),
    );
  }

  Future<void> _downloadBillingBundle() async {
    if (_billingRecordCount == 0) {
      return;
    }
    final Map<String, dynamic> payload = _billingPayload ?? const <String, dynamic>{};
    final List<Map<String, dynamic>> invoices = _asMapList(payload['invoices']);
    final List<Map<String, dynamic>> payments = _asMapList(payload['payments']);
    final List<Map<String, dynamic>> subscriptions =
        _asMapList(payload['subscriptions']);
    final StringBuffer buffer = StringBuffer()
      ..writeln('HQ Billing Bundle')
      ..writeln('Generated: ${DateTime.now().toIso8601String()}')
      ..writeln('');
    buffer
      ..writeln('Invoices (${invoices.length})')
      ..writeln('----------------');
    for (final Map<String, dynamic> row in invoices) {
      buffer.writeln(jsonEncode(row));
    }
    buffer
      ..writeln('')
      ..writeln('Payments (${payments.length})')
      ..writeln('----------------');
    for (final Map<String, dynamic> row in payments) {
      buffer.writeln(jsonEncode(row));
    }
    buffer
      ..writeln('')
      ..writeln('Subscriptions (${subscriptions.length})')
      ..writeln('--------------------');
    for (final Map<String, dynamic> row in subscriptions) {
      buffer.writeln(jsonEncode(row));
    }
    await _saveBundle(
      module: 'hq_exports',
      bundleId: 'billing',
      fileName: _bundleFileName('billing'),
      content: buffer.toString().trim(),
      successMessage: _tHqExports(context, 'Billing export downloaded.'),
      copiedMessage: _tHqExports(context, 'Billing export copied to clipboard.'),
      failureMessage:
          _tHqExports(context, 'Unable to download the billing export right now.'),
    );
  }

  Future<void> _downloadAuditBundle() async {
    if (_auditLogs.isEmpty) {
      return;
    }
    final StringBuffer buffer = StringBuffer()
      ..writeln('HQ Audit Bundle')
      ..writeln('Generated: ${DateTime.now().toIso8601String()}')
      ..writeln('');
    for (final AuditLogModel log in _auditLogs) {
      buffer
        ..writeln('Action: ${log.action}')
        ..writeln('Actor: ${log.actorRole} / ${log.actorId}')
        ..writeln('Entity: ${log.entityType} / ${log.entityId}')
        ..writeln('Site: ${log.siteId ?? 'global'}')
        ..writeln('Created: ${log.createdAt?.toDate().toIso8601String() ?? 'n/a'}');
      if (log.details.isNotEmpty) {
        buffer.writeln('Details: ${jsonEncode(log.details)}');
      }
      buffer.writeln('');
    }
    await _saveBundle(
      module: 'hq_exports',
      bundleId: 'audit',
      fileName: _bundleFileName('audit'),
      content: buffer.toString().trim(),
      successMessage: _tHqExports(context, 'Audit export downloaded.'),
      copiedMessage: _tHqExports(context, 'Audit export copied to clipboard.'),
      failureMessage:
          _tHqExports(context, 'Unable to download the audit export right now.'),
    );
  }

  Future<void> _downloadSafetyBundle() async {
    if (_safetyIncidentCount == 0) {
      return;
    }
    final StringBuffer buffer = StringBuffer()
      ..writeln('HQ Safety Bundle')
      ..writeln('Generated: ${DateTime.now().toIso8601String()}')
      ..writeln('');
    for (final Map<String, dynamic> row
        in _asMapList((_safetyPayload ?? const <String, dynamic>{})['incidents'])) {
      buffer.writeln(jsonEncode(row));
    }
    await _saveBundle(
      module: 'hq_exports',
      bundleId: 'safety',
      fileName: _bundleFileName('safety'),
      content: buffer.toString().trim(),
      successMessage: _tHqExports(context, 'Safety export downloaded.'),
      copiedMessage: _tHqExports(context, 'Safety export copied to clipboard.'),
      failureMessage:
          _tHqExports(context, 'Unable to download the safety export right now.'),
    );
  }

  Future<void> _downloadFullBundle() async {
    final StringBuffer buffer = StringBuffer()
      ..writeln('HQ Full Export Bundle')
      ..writeln('Generated: ${DateTime.now().toIso8601String()}')
      ..writeln('');
    if (_analyticsMetrics != null) {
      buffer
        ..writeln('=== Analytics ===')
        ..writeln('Weekly accountability adherence: ${_analyticsMetrics!.weeklyAccountabilityAdherenceRate.toStringAsFixed(1)}%')
        ..writeln('Intervention total: ${_analyticsMetrics!.interventionTotal}')
        ..writeln('');
    }
    if (_billingRecordCount > 0) {
      buffer
        ..writeln('=== Billing ===')
        ..writeln('Invoices: ${_asMapList((_billingPayload ?? const <String, dynamic>{})['invoices']).length}')
        ..writeln('Payments: ${_asMapList((_billingPayload ?? const <String, dynamic>{})['payments']).length}')
        ..writeln('Subscriptions: ${_asMapList((_billingPayload ?? const <String, dynamic>{})['subscriptions']).length}')
        ..writeln('');
    }
    if (_auditLogs.isNotEmpty) {
      buffer
        ..writeln('=== Audit ===')
        ..writeln('Entries: ${_auditLogs.length}')
        ..writeln('');
    }
    if (_safetyIncidentCount > 0) {
      buffer
        ..writeln('=== Safety ===')
        ..writeln('Incidents: $_safetyIncidentCount')
        ..writeln('');
    }
    await _saveBundle(
      module: 'hq_exports',
      bundleId: 'full',
      fileName: _bundleFileName('full'),
      content: buffer.toString().trim(),
      successMessage: _tHqExports(context, 'Full export bundle downloaded.'),
      copiedMessage: _tHqExports(context, 'Full export bundle copied to clipboard.'),
      failureMessage:
          _tHqExports(context, 'Unable to download the full export bundle right now.'),
    );
  }

  Future<void> _saveBundle({
    required String module,
    required String bundleId,
    required String fileName,
    required String content,
    required String successMessage,
    required String copiedMessage,
    required String failureMessage,
  }) async {
    try {
      final String? savedLocation = await ExportService.instance.saveTextFile(
        fileName: fileName,
        content: content,
      );
      if (savedLocation == null || !mounted) {
        return;
      }
      TelemetryService.instance.logEvent(
        event: 'export.downloaded',
        metadata: <String, dynamic>{
          'module': module,
          'bundle_id': bundleId,
          'file_name': fileName,
        },
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
    } on UnsupportedError catch (_) {
      if (!mounted) {
        return;
      }
      await Clipboard.setData(ClipboardData(text: content));
      TelemetryService.instance.logEvent(
        event: 'export.copied',
        metadata: <String, dynamic>{
          'module': module,
          'bundle_id': bundleId,
          'file_name': fileName,
        },
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(copiedMessage)),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failureMessage)),
      );
    }
  }

  String _bundleFileName(String bundleId) {
    final String dateSegment =
        DateTime.now().toIso8601String().split('T').first;
    return 'hq-export-$bundleId-$dateSegment.txt';
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map(
        (dynamic key, dynamic mapValue) => MapEntry(key.toString(), mapValue),
      );
    }
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _asMapList(dynamic value) {
    if (value is! List) {
      return <Map<String, dynamic>>[];
    }
    return value.map<Map<String, dynamic>>(_asMap).toList(growable: false);
  }
}
